!======================================================================
!
!  GSLIB Unified Simulation Engine
!  ================================
!
!  A single Fortran 90 program that runs complete geostatistical
!  simulation workflows IN MEMORY without intermediate disk I/O
!  between pipeline stages.
!
!  Workflows supported:
!    SGSIM  - Sequential Gaussian Simulation
!    SISIM  - Sequential Indicator Simulation
!
!  SGSIM workflow:
!    Read data -> DECLUS -> NSCORE -> SGSIM (OpenMP parallel) ->
!    BACKTR (vectorized) -> POSTSIM (in-memory reduction) -> Write
!
!  Compilation:
!    ifx /O2 /Qopenmp /heap-arrays gslib_engine.f90 libgs.lib
!
!  The program links against the existing GSLIB library (libgs.lib)
!  for core routines: cova3, ksol, srchsupr, setrot, setsupr,
!  sqdist, sortem, acorni, gauinv, gcum, locate, powint, backtr,
!  getindx, picksup.
!
!======================================================================

!----------------------------------------------------------------------
! Module: gslib_types
!   Common type definitions used throughout the engine
!----------------------------------------------------------------------
module gslib_types
  implicit none

  integer, parameter :: dp = selected_real_kind(15)
  integer, parameter :: sp = selected_real_kind(6)

  ! Unestimated flag (matches GSLIB convention)
  real, parameter :: UNEST = -99.0
  real, parameter :: EPSLON = 1.0e-20

  ! ACORN RNG parameters
  integer, parameter :: KORDEI = 12
  integer, parameter :: MAXOP1 = KORDEI + 1
  integer, parameter :: MAXINT_RNG = 2**30

  ! Maximum variogram structures
  integer, parameter :: MAXNST = 4
  integer, parameter :: MAXROT = MAXNST + 1

  ! Super block parameters
  integer, parameter :: MAXSBX = 21, MAXSBY = 21, MAXSBZ = 11
  integer, parameter :: MAXSB  = MAXSBX * MAXSBY * MAXSBZ

  ! Covariance table half-widths (odd dimensions)
  integer, parameter :: MAXCTX = 71, MAXCTY = 71, MAXCTZ = 31
  integer, parameter :: MAXCXY = MAXCTX * MAXCTY
  integer, parameter :: MAXXYZ_CT = MAXCTX * MAXCTY * MAXCTZ

  ! Kriging limits
  integer, parameter :: MAXNOD = 96    ! max previously simulated nodes
  integer, parameter :: MAXSAM = 256   ! max data samples for kriging
  integer, parameter :: MAXKR1 = MAXNOD + MAXSAM + 1
  integer, parameter :: MAXKR2 = MAXKR1 * MAXKR1

  type :: grid_def
    integer :: nx, ny, nz
    real    :: xmn, ymn, zmn, xsiz, ysiz, zsiz
    integer :: nxy, nxyz
  end type

  type :: vario_model
    integer :: nst
    real    :: c0
    integer :: it(MAXNST)
    real    :: cc(MAXNST), aa(MAXNST)
    real    :: aa_hmax(MAXNST), aa_hmin(MAXNST), aa_vert(MAXNST)
    real    :: anis1(MAXNST), anis2(MAXNST)
    real    :: ang1(MAXNST), ang2(MAXNST), ang3(MAXNST)
    real    :: sill
  end type

  type :: search_pars
    real    :: radius, radius1, radius2
    real    :: radsqd
    real    :: sang1, sang2, sang3
    real    :: sanis1, sanis2
    integer :: ndmin, ndmax, nodmax, noct
  end type

  type :: transform_table
    integer :: nt              ! number of entries
    real, allocatable :: vr(:) ! original values (sorted)
    real, allocatable :: vrg(:)! corresponding normal scores
    real    :: zmin, zmax      ! limits for tail extrapolation
    integer :: ltail, utail    ! tail options
    real    :: ltpar, utpar    ! tail parameters
  end type

  type :: data_set
    integer :: nd
    real, allocatable :: x(:), y(:), z(:), v(:), wt(:)
  end type

end module gslib_types


!----------------------------------------------------------------------
! Module: gslib_declus
!   In-memory cell declustering
!----------------------------------------------------------------------
module gslib_declus
  use gslib_types
  implicit none
  private
  public :: declus_run

contains

  !--------------------------------------------------------------------
  ! declus_run: Cell-based declustering
  !   Finds optimal cell size and returns declustering weights.
  !   Uses a single cell size equal to the grid cell size.
  !   For a full multi-cell-size search, the grid spacing is used.
  !--------------------------------------------------------------------
  subroutine declus_run(dat, grid, wt_out)
    type(data_set), intent(in)  :: dat
    type(grid_def), intent(in)  :: grid
    real, intent(out)           :: wt_out(dat%nd)

    ! Local variables
    integer :: i, j, nd, ncell, icellx, icelly, icellz
    integer :: ncellx, ncelly, ncellz, ncellt
    real    :: xmin, xmax, ymin, ymax, zmin_d, zmax_d
    real    :: csiz, xo, yo, zo, sumw
    integer, allocatable :: cellcnt(:)
    integer, allocatable :: cellidx(:)

    nd = dat%nd
    if(nd <= 0) return

    ! Use the grid cell size for declustering
    csiz = max(grid%xsiz, grid%ysiz, grid%zsiz)
    if(csiz < EPSLON) then
      wt_out(1:nd) = 1.0
      return
    end if

    ! Find data extent
    xmin =  1.0e21;  xmax = -1.0e21
    ymin =  1.0e21;  ymax = -1.0e21
    zmin_d =  1.0e21;  zmax_d = -1.0e21
    do i = 1, nd
      if(dat%x(i) < xmin) xmin = dat%x(i)
      if(dat%x(i) > xmax) xmax = dat%x(i)
      if(dat%y(i) < ymin) ymin = dat%y(i)
      if(dat%y(i) > ymax) ymax = dat%y(i)
      if(dat%z(i) < zmin_d) zmin_d = dat%z(i)
      if(dat%z(i) > zmax_d) zmax_d = dat%z(i)
    end do

    ! Number of cells in each direction
    ncellx = max(1, int((xmax - xmin) / csiz) + 1)
    ncelly = max(1, int((ymax - ymin) / csiz) + 1)
    ncellz = max(1, int((zmax_d - zmin_d) / csiz) + 1)
    ncellt = ncellx * ncelly * ncellz

    allocate(cellcnt(ncellt))
    allocate(cellidx(nd))

    ! Origin at the data minimum
    xo = xmin - 0.5 * csiz
    yo = ymin - 0.5 * csiz
    zo = zmin_d - 0.5 * csiz

    ! Assign each datum to a cell and count
    cellcnt = 0
    do i = 1, nd
      icellx = min(ncellx, max(1, int((dat%x(i) - xo) / csiz) + 1))
      icelly = min(ncelly, max(1, int((dat%y(i) - yo) / csiz) + 1))
      icellz = min(ncellz, max(1, int((dat%z(i) - zo) / csiz) + 1))
      j = icellx + (icelly-1)*ncellx + (icellz-1)*ncellx*ncelly
      cellidx(i) = j
      cellcnt(j) = cellcnt(j) + 1
    end do

    ! Count number of non-empty cells
    ncell = 0
    do i = 1, ncellt
      if(cellcnt(i) > 0) ncell = ncell + 1
    end do
    ncell = max(ncell, 1)

    ! Weight = 1/(number_in_cell * number_of_nonempty_cells)
    ! This gives equal weight to each cell, then splits within cell
    sumw = 0.0
    do i = 1, nd
      j = cellidx(i)
      wt_out(i) = 1.0 / real(cellcnt(j))
      sumw = sumw + wt_out(i)
    end do

    ! Normalize so weights sum to nd (i.e., mean weight = 1)
    if(sumw > EPSLON) then
      do i = 1, nd
        wt_out(i) = wt_out(i) * real(nd) / sumw
      end do
    end if

    deallocate(cellcnt, cellidx)

    write(*,'(a,i8,a,f10.4)') '  Declustering: ', nd, &
         ' data, cell size = ', csiz

  end subroutine declus_run

end module gslib_declus


!----------------------------------------------------------------------
! Module: gslib_nscore
!   In-memory normal score transform
!----------------------------------------------------------------------
module gslib_nscore
  use gslib_types
  implicit none
  private
  public :: nscore_run

  ! External library routines
  interface
    subroutine gauinv(p, xp, ierr)
      real*8, intent(in)  :: p
      real, intent(out)   :: xp
      integer, intent(out):: ierr
    end subroutine
    subroutine sortem(ib,ie,a,iperm,b,c,d,e,f,g,h)
      integer, intent(in) :: ib, ie, iperm
      real :: a(*),b(*),c(*),d(*),e(*),f(*),g(*),h(*)
    end subroutine
  end interface

contains

  !--------------------------------------------------------------------
  ! nscore_run: In-memory normal score transform
  !   Input:  dat%v (original values), wt (declustering weights)
  !   Output: dat%v overwritten with normal scores
  !           tbl   filled with transform table for back-transform
  !--------------------------------------------------------------------
  subroutine nscore_run(dat, wt, tmin, tmax, tbl)
    type(data_set), intent(inout) :: dat
    real, intent(in)              :: wt(:)
    real, intent(in)              :: tmin, tmax
    type(transform_table), intent(inout) :: tbl

    integer :: i, nd, nt, ierr
    real    :: twt, cp, oldcp
    real*8  :: pd
    real, allocatable :: vr_sort(:), wt_sort(:), vrg_sort(:), idx(:)
    real :: dum(1)

    nd = dat%nd

    ! Count valid data
    nt = 0
    twt = 0.0
    do i = 1, nd
      if(dat%v(i) >= tmin .and. dat%v(i) < tmax) then
        nt = nt + 1
        twt = twt + wt(i)
      end if
    end do

    if(nt < 2) then
      write(*,*) 'ERROR: too few data for normal score transform'
      stop
    end if

    ! Copy valid data into sort arrays
    allocate(vr_sort(nt), wt_sort(nt), vrg_sort(nt), idx(nt))
    nt = 0
    do i = 1, nd
      if(dat%v(i) >= tmin .and. dat%v(i) < tmax) then
        nt = nt + 1
        vr_sort(nt)  = dat%v(i)
        wt_sort(nt)  = wt(i)
        idx(nt)      = real(i)  ! remember original index
      end if
    end do

    ! Sort by value (carry weight and index)
    call sortem(1, nt, vr_sort, 2, wt_sort, idx, dum, dum, dum, &
                dum, dum)

    ! Build transform table: cumulative probability -> normal score
    allocate(tbl%vr(nt), tbl%vrg(nt))
    tbl%nt = nt

    oldcp = 0.0
    cp    = 0.0
    do i = 1, nt
      cp = cp + wt_sort(i) / twt
      pd = dble((cp + oldcp) * 0.5)
      call gauinv(pd, vrg_sort(i), ierr)
      tbl%vr(i)  = vr_sort(i)
      tbl%vrg(i) = vrg_sort(i)
      oldcp = cp
    end do

    ! Now transform the original data values using the table
    do i = 1, nd
      if(dat%v(i) >= tmin .and. dat%v(i) < tmax) then
        call ns_forward(dat%v(i), tbl, dat%v(i))
      end if
    end do

    write(*,'(a,i8,a)') '  Normal score transform: ', nt, ' data transformed'

    deallocate(vr_sort, wt_sort, vrg_sort, idx)

  end subroutine nscore_run

  !--------------------------------------------------------------------
  ! ns_forward: Forward transform a single value using the table
  !--------------------------------------------------------------------
  subroutine ns_forward(val_in, tbl, val_out)
    real, intent(in)                    :: val_in
    type(transform_table), intent(in)   :: tbl
    real, intent(out)                   :: val_out
    integer :: j
    real :: vrg
    real :: powint
    external :: powint

    ! Locate in sorted original values
    call locate_val(tbl%vr, tbl%nt, val_in, j)
    j = max(1, min(j, tbl%nt - 1))

    vrg = powint(tbl%vr(j), tbl%vr(j+1), tbl%vrg(j), tbl%vrg(j+1), &
                 val_in, 1.0)
    if(vrg < tbl%vrg(1))    vrg = tbl%vrg(1)
    if(vrg > tbl%vrg(tbl%nt)) vrg = tbl%vrg(tbl%nt)
    val_out = vrg

  end subroutine ns_forward

  !--------------------------------------------------------------------
  ! locate_val: Binary search in sorted array
  !--------------------------------------------------------------------
  subroutine locate_val(xx, n, x, j)
    real, intent(in)    :: xx(:)
    integer, intent(in) :: n
    real, intent(in)    :: x
    integer, intent(out):: j
    integer :: jl, ju, jm

    jl = 0
    ju = n + 1
    do while(ju - jl > 1)
      jm = (ju + jl) / 2
      if((xx(n) > xx(1)) .eqv. (x > xx(jm))) then
        jl = jm
      else
        ju = jm
      end if
    end do
    j = jl
  end subroutine locate_val

end module gslib_nscore


!----------------------------------------------------------------------
! Module: gslib_backtr
!   In-memory vectorized back transform of simulation array
!----------------------------------------------------------------------
module gslib_backtr_mod
  use gslib_types
  implicit none
  private
  public :: backtr_array

  interface
    real function backtr(vrgs,nt,vr,vrg,zmin,zmax,ltail,ltpar, &
                         utail,utpar)
      real, intent(in)    :: vrgs
      integer, intent(in) :: nt
      real, intent(in)    :: vr(nt), vrg(nt)
      real, intent(in)    :: zmin, zmax
      integer, intent(in) :: ltail, utail
      real, intent(in)    :: ltpar, utpar
    end function
  end interface

contains

  !--------------------------------------------------------------------
  ! backtr_array: Back-transform the entire sim array in-place
  !   OpenMP vectorized over all elements
  !--------------------------------------------------------------------
  subroutine backtr_array(sim, nxyz, nsim, tbl)
    integer, intent(in)                 :: nxyz, nsim
    real, intent(inout)                 :: sim(nxyz, nsim)
    type(transform_table), intent(in)   :: tbl

    integer :: i, isim
    real    :: val

    !$OMP PARALLEL DO PRIVATE(i, isim, val) SCHEDULE(STATIC)
    do isim = 1, nsim
      do i = 1, nxyz
        val = sim(i, isim)
        if(val > (UNEST + EPSLON)) then
          val = backtr(val, tbl%nt, tbl%vr, tbl%vrg, tbl%zmin, &
                        tbl%zmax, tbl%ltail, tbl%ltpar, &
                        tbl%utail, tbl%utpar)
          if(val < tbl%zmin) val = tbl%zmin
          if(val > tbl%zmax) val = tbl%zmax
          sim(i, isim) = val
        end if
      end do
    end do
    !$OMP END PARALLEL DO

    write(*,'(a)') '  Back-transform complete'

  end subroutine backtr_array

end module gslib_backtr_mod


!----------------------------------------------------------------------
! Module: gslib_sgsim
!   In-memory Sequential Gaussian Simulation with OpenMP
!----------------------------------------------------------------------
module gslib_sgsim
  use gslib_types
  implicit none
  private
  public :: sgsim_run

  ! External library routines
  interface
    subroutine cova3(x1,y1,z1,x2,y2,z2,ivarg,nst,MAXNST_,c0,it,cc,aa, &
                     irot,MAXROT_,rotmat,cmax,cova)
      integer, intent(in) :: ivarg, MAXNST_, irot, MAXROT_
      integer, intent(in) :: nst(*), it(*)
      real, intent(in)    :: x1,y1,z1,x2,y2,z2
      real, intent(in)    :: c0(*), cc(*), aa(*)
      real*8, intent(in)  :: rotmat(MAXROT_,3,3)
      real, intent(out)   :: cmax, cova
    end subroutine

    subroutine ksol(nright,neq,nsb,a,r,s,ising)
      integer, intent(in)    :: nright, neq, nsb
      real*8, intent(inout)  :: a(*), r(*)
      real*8, intent(out)    :: s(*)
      integer, intent(out)   :: ising
    end subroutine

    subroutine srchsupr(xloc,yloc,zloc,radsqd,irot,MAXROT_,rotmat, &
                        nsbtosr,ixsbtosr,iysbtosr,izsbtosr,noct,nd, &
                        x,y,z,tmp,nisb,nxsup,xmnsup,xsizsup, &
                        nysup,ymnsup,ysizsup,nzsup,zmnsup,zsizsup, &
                        nclose,close,infoct)
      integer, intent(in)  :: irot, MAXROT_, nsbtosr, noct, nd
      integer, intent(in)  :: nxsup, nysup, nzsup
      real, intent(in)     :: xloc, yloc, zloc, radsqd
      real*8, intent(in)   :: rotmat(MAXROT_,3,3)
      integer, intent(in)  :: ixsbtosr(*), iysbtosr(*), izsbtosr(*)
      real, intent(in)     :: x(*), y(*), z(*)
      real, intent(inout)  :: tmp(*)
      integer, intent(in)  :: nisb(*)
      real, intent(in)     :: xmnsup, xsizsup, ymnsup, ysizsup
      real, intent(in)     :: zmnsup, zsizsup
      integer, intent(out) :: nclose, infoct
      real, intent(out)    :: close(*)
    end subroutine

    subroutine setrot(ang1,ang2,ang3,anis1,anis2,ind,MAXROT_,rotmat)
      real, intent(in)      :: ang1, ang2, ang3, anis1, anis2
      integer, intent(in)   :: ind, MAXROT_
      real*8, intent(inout) :: rotmat(MAXROT_,3,3)
    end subroutine

    subroutine setsupr(nx,xmn,xsiz,ny,ymn,ysiz,nz,zmn,zsiz,nd,x,y,z, &
                       vr,tmp,nsec,sec1,sec2,sec3,MAXSBX_,MAXSBY_, &
                       MAXSBZ_,nisb,nxsup,xmnsup,xsizsup,nysup,ymnsup, &
                       ysizsup,nzsup,zmnsup,zsizsup)
      integer, intent(in)  :: nx, ny, nz, nd, nsec
      integer, intent(in)  :: MAXSBX_, MAXSBY_, MAXSBZ_
      real, intent(in)     :: xmn, xsiz, ymn, ysiz, zmn, zsiz
      real, intent(inout)  :: x(*), y(*), z(*), vr(*), tmp(*)
      real, intent(inout)  :: sec1(*), sec2(*), sec3(*)
      integer, intent(out) :: nisb(*)
      integer, intent(out) :: nxsup, nysup, nzsup
      real, intent(out)    :: xmnsup, xsizsup, ymnsup, ysizsup
      real, intent(out)    :: zmnsup, zsizsup
    end subroutine

    subroutine picksup(nxsup,xsizsup,nysup,ysizsup,nzsup,zsizsup, &
                       irot,MAXROT_,rotmat,radsqd,nsbtosr,ixsbtosr, &
                       iysbtosr,izsbtosr)
      integer, intent(in)  :: nxsup, nysup, nzsup, irot, MAXROT_
      real, intent(in)     :: xsizsup, ysizsup, zsizsup, radsqd
      real*8, intent(in)   :: rotmat(MAXROT_,3,3)
      integer, intent(out) :: nsbtosr
      integer, intent(out) :: ixsbtosr(*), iysbtosr(*), izsbtosr(*)
    end subroutine

    subroutine sortem(ib,ie,a,iperm,b,c,d,e,f,g,h)
      integer, intent(in) :: ib, ie, iperm
      real :: a(*),b(*),c(*),d(*),e(*),f(*),g(*),h(*)
    end subroutine

    subroutine gauinv(p, xp, ierr)
      real*8, intent(in)  :: p
      real, intent(out)   :: xp
      integer, intent(out):: ierr
    end subroutine

    subroutine getindx(n, min, siz, loc, index, inflag)
      integer, intent(in)  :: n
      real, intent(in)     :: min, siz, loc
      integer, intent(out) :: index
      logical, intent(out) :: inflag
    end subroutine
  end interface

contains

  !--------------------------------------------------------------------
  ! sgsim_run: Main SGSIM driver
  !   Runs nsim realizations with OpenMP parallelism
  !   Returns results in sim_all(nxyz, nsim)
  !--------------------------------------------------------------------
  subroutine sgsim_run(dat, grid, vmodel, srch, nsim, seed, &
                       sim_all)
    type(data_set), intent(inout)     :: dat
    type(grid_def), intent(in)        :: grid
    type(vario_model), intent(in)     :: vmodel
    type(search_pars), intent(in)     :: srch
    integer, intent(in)               :: nsim, seed
    real, intent(out)                 :: sim_all(grid%nxyz, nsim)

    ! Variogram arrays in library format (1-element outer arrays)
    integer :: nst_arr(1), it_arr(MAXNST)
    real    :: c0_arr(1), cc_arr(MAXNST), aa_arr(MAXNST)
    real    :: ang1_arr(MAXNST), ang2_arr(MAXNST), ang3_arr(MAXNST)
    real    :: anis1_arr(MAXNST), anis2_arr(MAXNST)
    real*8  :: rotmat(MAXROT, 3, 3)

    ! Super block search data
    integer :: nisb(MAXSB)
    integer :: nxsup, nysup, nzsup
    real    :: xmnsup, ymnsup, zmnsup, xsizsup, ysizsup, zsizsup
    integer :: nsbtosr
    integer :: ixsbtosr(8*MAXSB), iysbtosr(8*MAXSB), izsbtosr(8*MAXSB)

    ! Covariance table
    real    :: covtab(MAXCTX, MAXCTY, MAXCTZ)
    integer :: nctx, ncty, nctz
    real    :: cbb, cmax_val

    ! Spiral search node list
    integer :: nlooku
    integer(2) :: ixnode(MAXXYZ_CT), iynode(MAXXYZ_CT), iznode(MAXXYZ_CT)

    ! Per-realization ACORN seed arrays
    integer :: ixvseed(MAXOP1, nsim)

    ! Search rotation index
    integer :: isrot

    ! Working copies of data for setsupr (it sorts in place)
    real, allocatable :: xd(:), yd(:), zd(:), vrd(:), wtd(:), sec1(:)

    integer :: nd, nxyz, nx, ny, nz, nxy
    integer :: is, isim, i
    real*8  :: p

    ! ACORN common block for sequential seed generation
    common /iaco/ ixv(MAXOP1)
    integer :: ixv

    nd   = dat%nd
    nx   = grid%nx;  ny = grid%ny;  nz = grid%nz
    nxy  = nx * ny;  nxyz = grid%nxyz

    ! ----------------------------------------------------------------
    ! Setup variogram arrays in library format
    ! ----------------------------------------------------------------
    nst_arr(1) = vmodel%nst
    c0_arr(1)  = vmodel%c0
    do is = 1, vmodel%nst
      it_arr(is)    = vmodel%it(is)
      cc_arr(is)    = vmodel%cc(is)
      aa_arr(is)    = vmodel%aa_hmax(is)
      ang1_arr(is)  = vmodel%ang1(is)
      ang2_arr(is)  = vmodel%ang2(is)
      ang3_arr(is)  = vmodel%ang3(is)
      anis1_arr(is) = vmodel%anis1(is)
      anis2_arr(is) = vmodel%anis2(is)
    end do

    ! ----------------------------------------------------------------
    ! Setup rotation matrices for variogram structures
    ! ----------------------------------------------------------------
    write(*,'(a)') '  Setting up rotation matrices'
    do is = 1, vmodel%nst
      call setrot(ang1_arr(is), ang2_arr(is), ang3_arr(is), &
                  anis1_arr(is), anis2_arr(is), is, MAXROT, rotmat)
    end do
    ! Search rotation matrix
    isrot = MAXNST + 1
    call setrot(srch%sang1, srch%sang2, srch%sang3, &
                srch%sanis1, srch%sanis2, isrot, MAXROT, rotmat)

    ! ----------------------------------------------------------------
    ! Setup super block search (data search)
    ! ----------------------------------------------------------------
    if(nd > 0 .and. srch%ndmax > 0) then
      write(*,'(a)') '  Setting up super block search'

      ! Allocate working copies (setsupr sorts in place)
      allocate(xd(nd), yd(nd), zd(nd), vrd(nd), wtd(nd), sec1(nd))
      xd(1:nd)   = dat%x(1:nd)
      yd(1:nd)   = dat%y(1:nd)
      zd(1:nd)   = dat%z(1:nd)
      vrd(1:nd)  = dat%v(1:nd)
      wtd(1:nd)  = dat%wt(1:nd)
      sec1(1:nd) = 0.0

      call setsupr(nx, grid%xmn, grid%xsiz, ny, grid%ymn, grid%ysiz, &
                   nz, grid%zmn, grid%zsiz, nd, xd, yd, zd, vrd, wtd, &
                   0, sec1, sec1, sec1, MAXSBX, MAXSBY, MAXSBZ, &
                   nisb, nxsup, xmnsup, xsizsup, nysup, ymnsup, &
                   ysizsup, nzsup, zmnsup, zsizsup)

      call picksup(nxsup, xsizsup, nysup, ysizsup, nzsup, zsizsup, &
                   isrot, MAXROT, rotmat, srch%radsqd, nsbtosr, &
                   ixsbtosr, iysbtosr, izsbtosr)

      ! Copy sorted data back (setsupr reorders them)
      dat%x(1:nd)  = xd(1:nd)
      dat%y(1:nd)  = yd(1:nd)
      dat%z(1:nd)  = zd(1:nd)
      dat%v(1:nd)  = vrd(1:nd)
      dat%wt(1:nd) = wtd(1:nd)

      deallocate(xd, yd, zd, vrd, wtd, sec1)
    else
      nsbtosr = 0
    end if

    ! ----------------------------------------------------------------
    ! Build covariance lookup table and spiral search
    ! ----------------------------------------------------------------
    write(*,'(a)') '  Building covariance table and spiral search'
    call build_ctable(grid, vmodel, nst_arr, c0_arr, it_arr, cc_arr, &
                      aa_arr, rotmat, isrot, srch%radsqd, &
                      covtab, nctx, ncty, nctz, cbb, &
                      nlooku, ixnode, iynode, iznode, nxyz)

    ! ----------------------------------------------------------------
    ! Pre-generate per-realization RNG seeds (sequential)
    ! ----------------------------------------------------------------
    write(*,'(a)') '  Generating per-realization RNG seeds'
    ixv(1) = seed
    do i = 2, MAXOP1
      ixv(i) = 0
    end do
    ! Warm up
    do i = 1, 1000
      p = acorni_func(ixv)
    end do

    do isim = 1, nsim
      ixvseed(1:MAXOP1, isim) = ixv(1:MAXOP1)
      ! Advance RNG to create unique seed for next realization
      do i = 1, nxyz + 1000
        p = acorni_func(ixv)
      end do
    end do

    ! ----------------------------------------------------------------
    ! MAIN LOOP: Parallel over realizations
    ! ----------------------------------------------------------------
    write(*,'(a,i6,a)') '  Running ', nsim, ' realizations'

    !$OMP PARALLEL DO SCHEDULE(DYNAMIC,1) &
    !$OMP PRIVATE(isim)
    do isim = 1, nsim

      call sgsim_one_real(isim, dat, grid, vmodel, srch, &
                          nst_arr, c0_arr, it_arr, cc_arr, aa_arr, &
                          rotmat, isrot, &
                          nisb, nxsup, xmnsup, xsizsup, &
                          nysup, ymnsup, ysizsup, &
                          nzsup, zmnsup, zsizsup, &
                          nsbtosr, ixsbtosr, iysbtosr, izsbtosr, &
                          covtab, nctx, ncty, nctz, cbb, &
                          nlooku, ixnode, iynode, iznode, &
                          ixvseed(1,isim), &
                          sim_all(1,isim))

    end do
    !$OMP END PARALLEL DO

    write(*,'(a)') '  SGSIM complete'

  end subroutine sgsim_run


  !--------------------------------------------------------------------
  ! sgsim_one_real: Simulate one realization
  !   Thread-safe: all mutable state is local
  !--------------------------------------------------------------------
  subroutine sgsim_one_real(isim, dat, grid, vmodel, srch, &
                            nst_arr, c0_arr, it_arr, cc_arr, aa_arr, &
                            rotmat, isrot, &
                            nisb, nxsup, xmnsup, xsizsup, &
                            nysup, ymnsup, ysizsup, &
                            nzsup, zmnsup, zsizsup, &
                            nsbtosr, ixsbtosr, iysbtosr, izsbtosr, &
                            covtab, nctx, ncty, nctz, cbb, &
                            nlooku, ixnode, iynode, iznode, &
                            ixvseed_in, &
                            sim_out)
    integer, intent(in)               :: isim
    type(data_set), intent(in)        :: dat
    type(grid_def), intent(in)        :: grid
    type(vario_model), intent(in)     :: vmodel
    type(search_pars), intent(in)     :: srch
    integer, intent(in)               :: nst_arr(1)
    real, intent(in)                  :: c0_arr(1)
    integer, intent(in)               :: it_arr(MAXNST)
    real, intent(in)                  :: cc_arr(MAXNST), aa_arr(MAXNST)
    real*8, intent(in)                :: rotmat(MAXROT, 3, 3)
    integer, intent(in)               :: isrot
    integer, intent(in)               :: nisb(MAXSB)
    integer, intent(in)               :: nxsup, nysup, nzsup
    real, intent(in)                  :: xmnsup, xsizsup
    real, intent(in)                  :: ymnsup, ysizsup
    real, intent(in)                  :: zmnsup, zsizsup
    integer, intent(in)               :: nsbtosr
    integer, intent(in)               :: ixsbtosr(8*MAXSB)
    integer, intent(in)               :: iysbtosr(8*MAXSB)
    integer, intent(in)               :: izsbtosr(8*MAXSB)
    real, intent(in)                  :: covtab(MAXCTX, MAXCTY, MAXCTZ)
    integer, intent(in)               :: nctx, ncty, nctz
    real, intent(in)                  :: cbb
    integer, intent(in)               :: nlooku
    integer(2), intent(in)            :: ixnode(MAXXYZ_CT)
    integer(2), intent(in)            :: iynode(MAXXYZ_CT)
    integer(2), intent(in)            :: iznode(MAXXYZ_CT)
    integer, intent(in)               :: ixvseed_in(MAXOP1)
    real, intent(out)                 :: sim_out(grid%nxyz)

    ! Local thread-private state
    integer :: ixv_local(MAXOP1)
    real, allocatable :: sim(:), order_r(:), tmp_srch(:), close_arr(:)
    real    :: dum_arr(1)

    ! Kriging work arrays
    real*8  :: a_kr(MAXKR2), r_kr(MAXKR1), rr_kr(MAXKR1), s_kr(MAXKR1)
    real    :: vra(MAXKR1)

    ! Node search work
    integer :: icnode_l(MAXNOD)
    real    :: cnodex(MAXNOD), cnodey(MAXNOD), cnodez(MAXNOD)
    real    :: cnodev(MAXNOD)
    integer :: ncnode

    integer :: nd, nxyz, nx, ny, nz, nxy
    integer :: ind, in_node, index, id, ix, iy, iz
    integer :: nclose_dat, infoct
    real    :: xx, yy, zz, test, test2, TINY_val
    real    :: cmean, cstdev
    real*8  :: p
    real    :: xp
    integer :: ierr
    integer :: ne
    real    :: av, ss
    logical :: inflag_dum

    nd   = dat%nd
    nx   = grid%nx;  ny = grid%ny;  nz = grid%nz
    nxy  = nx * ny;  nxyz = grid%nxyz

    ! Initialize local RNG
    ixv_local = ixvseed_in

    ! Allocate thread-local work arrays
    allocate(sim(nxyz), order_r(nxyz))
    allocate(tmp_srch(max(nd, 1)))
    allocate(close_arr(max(nd, 1)))

    ! ----------------------------------------------------------------
    ! Generate random path
    ! ----------------------------------------------------------------
    do ind = 1, nxyz
      sim(ind)     = real(acorni_func(ixv_local))
      order_r(ind) = real(ind)
    end do
    call sortem(1, nxyz, sim, 1, order_r, dum_arr, dum_arr, dum_arr, &
                dum_arr, dum_arr, dum_arr)

    ! ----------------------------------------------------------------
    ! Initialize simulation array to unestimated
    ! ----------------------------------------------------------------
    do ind = 1, nxyz
      sim(ind) = UNEST
    end do

    ! ----------------------------------------------------------------
    ! Assign data to closest grid nodes
    ! ----------------------------------------------------------------
    TINY_val = 0.0001
    if(nd > 0 .and. srch%ndmax > 0) then
      do id = 1, nd
        call getindx(nx, grid%xmn, grid%xsiz, dat%x(id), ix, inflag_dum)
        call getindx(ny, grid%ymn, grid%ysiz, dat%y(id), iy, inflag_dum)
        call getindx(nz, grid%zmn, grid%zsiz, dat%z(id), iz, inflag_dum)
        ind = ix + (iy-1)*nx + (iz-1)*nxy
        xx  = grid%xmn + real(ix-1)*grid%xsiz
        yy  = grid%ymn + real(iy-1)*grid%ysiz
        zz  = grid%zmn + real(iz-1)*grid%zsiz
        test = abs(xx - dat%x(id)) + abs(yy - dat%y(id)) + &
               abs(zz - dat%z(id))
        ! Assign if this is closer than any previously assigned datum
        if(test <= TINY_val) then
          sim(ind) = 10.0 * UNEST  ! flag: don't simulate
        end if
      end do

      ! Now enter data values for flagged nodes
      do id = 1, nd
        call getindx(nx, grid%xmn, grid%xsiz, dat%x(id), ix, inflag_dum)
        call getindx(ny, grid%ymn, grid%ysiz, dat%y(id), iy, inflag_dum)
        call getindx(nz, grid%zmn, grid%zsiz, dat%z(id), iz, inflag_dum)
        ind = ix + (iy-1)*nx + (iz-1)*nxy
        xx  = grid%xmn + real(ix-1)*grid%xsiz
        yy  = grid%ymn + real(iy-1)*grid%ysiz
        zz  = grid%zmn + real(iz-1)*grid%zsiz
        test = abs(xx - dat%x(id)) + abs(yy - dat%y(id)) + &
               abs(zz - dat%z(id))
        if(test <= TINY_val) then
          sim(ind) = dat%v(id)
        end if
      end do
    end if

    !$OMP CRITICAL(progress)
    write(*,'(a,i4)') '    Working on realization ', isim
    !$OMP END CRITICAL(progress)

    ! ----------------------------------------------------------------
    ! MAIN LOOP OVER ALL NODES (random path)
    ! ----------------------------------------------------------------
    do in_node = 1, nxyz

      ! Get the node index from the random path
      index = int(order_r(in_node) + 0.5)

      ! Skip if already assigned (data node or out of range)
      if(sim(index) > (UNEST + EPSLON) .or. &
         sim(index) < (UNEST * 2.0)) cycle

      ! Compute ix, iy, iz from linear index
      iz = (index - 1) / nxy + 1
      iy = (index - (iz-1)*nxy - 1) / nx + 1
      ix = index - (iz-1)*nxy - (iy-1)*nx
      xx = grid%xmn + real(ix-1) * grid%xsiz
      yy = grid%ymn + real(iy-1) * grid%ysiz
      zz = grid%zmn + real(iz-1) * grid%zsiz

      ! ----------------------------------------------------------
      ! Search for nearby original data (super block search)
      ! ----------------------------------------------------------
      nclose_dat = 0
      if(nd > 0 .and. srch%ndmax > 0) then
        call srchsupr(xx, yy, zz, srch%radsqd, isrot, MAXROT, rotmat, &
                      nsbtosr, ixsbtosr, iysbtosr, izsbtosr, &
                      srch%noct, nd, &
                      dat%x, dat%y, dat%z, tmp_srch, &
                      nisb, nxsup, xmnsup, xsizsup, &
                      nysup, ymnsup, ysizsup, &
                      nzsup, zmnsup, zsizsup, &
                      nclose_dat, close_arr, infoct)
        if(nclose_dat < srch%ndmin) cycle
        if(nclose_dat > srch%ndmax) nclose_dat = srch%ndmax
      end if

      ! ----------------------------------------------------------
      ! Search for nearby previously simulated nodes (spiral)
      ! ----------------------------------------------------------
      call srchnd_local(ix, iy, iz, sim, nx, ny, nz, nxy, &
                        grid%xmn, grid%ymn, grid%zmn, &
                        grid%xsiz, grid%ysiz, grid%zsiz, &
                        srch%nodmax, srch%noct, &
                        nlooku, ixnode, iynode, iznode, &
                        nctx, ncty, nctz, &
                        ncnode, icnode_l, &
                        cnodex, cnodey, cnodez, cnodev)

      ! ----------------------------------------------------------
      ! Kriging (Simple Kriging with zero mean)
      ! ----------------------------------------------------------
      if((nclose_dat + ncnode) < 1) then
        cmean  = 0.0
        cstdev = 1.0
      else
        call krige_local(ix, iy, iz, xx, yy, zz, &
                         nclose_dat, close_arr, dat, &
                         ncnode, icnode_l, cnodex, cnodey, cnodez, cnodev, &
                         nst_arr, c0_arr, it_arr, cc_arr, aa_arr, &
                         rotmat, nctx, ncty, nctz, covtab, cbb, &
                         nx, ny, nz, nxy, &
                         ixnode, iynode, iznode, &
                         a_kr, r_kr, rr_kr, s_kr, vra, &
                         cmean, cstdev)
      end if

      ! ----------------------------------------------------------
      ! Draw from N(cmean, cstdev^2)
      ! ----------------------------------------------------------
      p = acorni_func(ixv_local)
      call gauinv(p, xp, ierr)
      sim(index) = xp * cstdev + cmean

    end do

    ! ----------------------------------------------------------------
    ! Reassign data to ensure exact conditioning
    ! ----------------------------------------------------------------
    if(nd > 0 .and. srch%ndmax > 0) then
      do id = 1, nd
        call getindx(nx, grid%xmn, grid%xsiz, dat%x(id), ix, inflag_dum)
        call getindx(ny, grid%ymn, grid%ysiz, dat%y(id), iy, inflag_dum)
        call getindx(nz, grid%zmn, grid%zsiz, dat%z(id), iz, inflag_dum)
        ind = ix + (iy-1)*nx + (iz-1)*nxy
        xx  = grid%xmn + real(ix-1)*grid%xsiz
        yy  = grid%ymn + real(iy-1)*grid%ysiz
        zz  = grid%zmn + real(iz-1)*grid%zsiz
        test = abs(xx - dat%x(id)) + abs(yy - dat%y(id)) + &
               abs(zz - dat%z(id))
        if(test <= TINY_val) sim(ind) = dat%v(id)
      end do
    end if

    ! ----------------------------------------------------------------
    ! Copy result and report statistics
    ! ----------------------------------------------------------------
    ne = 0; av = 0.0; ss = 0.0
    do ind = 1, nxyz
      sim_out(ind) = sim(ind)
      if(sim(ind) > -9.0 .and. sim(ind) < 9.0) then
        ne = ne + 1
        av = av + sim(ind)
        ss = ss + sim(ind)*sim(ind)
      end if
    end do
    av = av / max(real(ne), 1.0)
    ss = (ss / max(real(ne), 1.0)) - av * av

    !$OMP CRITICAL(stats)
    write(*,'(a,i4,a,i8,a,f8.4,a,f8.4)') &
         '    Realization ', isim, ': n=', ne, &
         ' mean=', av, ' var=', ss
    !$OMP END CRITICAL(stats)

    deallocate(sim, order_r, tmp_srch, close_arr)

  end subroutine sgsim_one_real


  !--------------------------------------------------------------------
  ! build_ctable: Build covariance lookup table and spiral search order
  !--------------------------------------------------------------------
  subroutine build_ctable(grid, vmodel, nst_arr, c0_arr, it_arr, &
                          cc_arr, aa_arr, rotmat, isrot, radsqd, &
                          covtab, nctx, ncty, nctz, cbb, &
                          nlooku, ixnode, iynode, iznode, nxyz)
    type(grid_def), intent(in)    :: grid
    type(vario_model), intent(in) :: vmodel
    integer, intent(in)           :: nst_arr(1)
    real, intent(in)              :: c0_arr(1)
    integer, intent(in)           :: it_arr(MAXNST)
    real, intent(in)              :: cc_arr(MAXNST), aa_arr(MAXNST)
    real*8, intent(in)            :: rotmat(MAXROT, 3, 3)
    integer, intent(in)           :: isrot
    real, intent(in)              :: radsqd
    real, intent(out)             :: covtab(MAXCTX, MAXCTY, MAXCTZ)
    integer, intent(out)          :: nctx, ncty, nctz
    real, intent(out)             :: cbb
    integer, intent(out)          :: nlooku
    integer(2), intent(out)       :: ixnode(MAXXYZ_CT)
    integer(2), intent(out)       :: iynode(MAXXYZ_CT)
    integer(2), intent(out)       :: iznode(MAXXYZ_CT)
    integer, intent(in)           :: nxyz

    real    :: xx, yy, zz, cmax_v, cov_v
    real*8  :: hsqd, sqdist
    external :: sqdist
    integer :: i, j, k, ic, jc, kc, il, loc_idx
    real    :: TINY_ct
    real, allocatable :: tmp_ct(:), order_ct(:)
    real    :: dum_arr(1)

    TINY_ct = 1.0e-10

    ! Size of lookup table
    nctx = min(((MAXCTX-1)/2), (grid%nx - 1))
    ncty = min(((MAXCTY-1)/2), (grid%ny - 1))
    nctz = min(((MAXCTZ-1)/2), (grid%nz - 1))

    ! Get cbb (covariance at zero distance)
    call cova3(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, nst_arr, MAXNST, &
               c0_arr, it_arr, cc_arr, aa_arr, 1, MAXROT, rotmat, &
               cmax_v, cbb)

    ! Build the table and identify nodes within search radius
    allocate(tmp_ct(MAXXYZ_CT), order_ct(MAXXYZ_CT))
    nlooku = 0

    do i = -nctx, nctx
      xx = real(i) * grid%xsiz
      ic = nctx + 1 + i
      do j = -ncty, ncty
        yy = real(j) * grid%ysiz
        jc = ncty + 1 + j
        do k = -nctz, nctz
          zz = real(k) * grid%zsiz
          kc = nctz + 1 + k

          call cova3(0.0, 0.0, 0.0, xx, yy, zz, 1, nst_arr, MAXNST, &
                     c0_arr, it_arr, cc_arr, aa_arr, 1, MAXROT, rotmat, &
                     cmax_v, covtab(ic, jc, kc))

          hsqd = sqdist(0.0, 0.0, 0.0, xx, yy, zz, isrot, MAXROT, rotmat)
          if(real(hsqd) <= radsqd) then
            nlooku = nlooku + 1
            ! Sort key: negative covariance (highest cov first),
            ! tie-break by distance
            tmp_ct(nlooku) = -(covtab(ic,jc,kc) - TINY_ct*real(hsqd))
            order_ct(nlooku) = real((kc-1)*MAXCXY + (jc-1)*MAXCTX + ic)
          end if
        end do
      end do
    end do

    ! Sort nodes by variogram distance (closest first)
    call sortem(1, nlooku, tmp_ct, 1, order_ct, dum_arr, dum_arr, &
                dum_arr, dum_arr, dum_arr, dum_arr)

    do il = 1, nlooku
      loc_idx = int(order_ct(il))
      kc = (loc_idx - 1) / MAXCXY + 1
      jc = (loc_idx - (kc-1)*MAXCXY - 1) / MAXCTX + 1
      ic = loc_idx - (kc-1)*MAXCXY - (jc-1)*MAXCTX
      ixnode(il) = int(ic, 2)
      iynode(il) = int(jc, 2)
      iznode(il) = int(kc, 2)
    end do

    deallocate(tmp_ct, order_ct)

    write(*,'(a,i8,a)') '    Covariance table built, ', nlooku, &
         ' nodes in spiral search'

  end subroutine build_ctable


  !--------------------------------------------------------------------
  ! srchnd_local: Search for nearby simulated grid nodes (spiral)
  !   Thread-safe version with all local state
  !--------------------------------------------------------------------
  subroutine srchnd_local(ix, iy, iz, sim, nx, ny, nz, nxy, &
                          xmn, ymn, zmn, xsiz, ysiz, zsiz, &
                          nodmax, noct, &
                          nlooku, ixnode, iynode, iznode, &
                          nctx, ncty, nctz, &
                          ncnode, icnode, &
                          cnodex, cnodey, cnodez, cnodev)
    integer, intent(in)      :: ix, iy, iz, nx, ny, nz, nxy
    real, intent(in)         :: sim(*)
    real, intent(in)         :: xmn, ymn, zmn, xsiz, ysiz, zsiz
    integer, intent(in)      :: nodmax, noct, nlooku
    integer(2), intent(in)   :: ixnode(*), iynode(*), iznode(*)
    integer, intent(in)      :: nctx, ncty, nctz
    integer, intent(out)     :: ncnode
    integer, intent(out)     :: icnode(MAXNOD)
    real, intent(out)        :: cnodex(MAXNOD), cnodey(MAXNOD)
    real, intent(out)        :: cnodez(MAXNOD), cnodev(MAXNOD)

    integer :: il, i, j, k, ind, iq, idx, idy, idz
    integer :: ninoct(8)

    ncnode = 0
    if(noct > 0) ninoct = 0

    do il = 2, nlooku
      if(ncnode == nodmax) return

      i = ix + (int(ixnode(il)) - nctx - 1)
      j = iy + (int(iynode(il)) - ncty - 1)
      k = iz + (int(iznode(il)) - nctz - 1)

      if(i < 1 .or. j < 1 .or. k < 1) cycle
      if(i > nx .or. j > ny .or. k > nz) cycle

      ind = i + (j-1)*nx + (k-1)*nxy
      if(sim(ind) > UNEST) then

        ! Octant check
        if(noct > 0) then
          idx = ix - i
          idy = iy - j
          idz = iz - k
          if(idz > 0) then
            iq = 4
            if(idx <= 0 .and. idy > 0) iq = 1
            if(idx > 0 .and. idy >= 0) iq = 2
            if(idx < 0 .and. idy <= 0) iq = 3
          else
            iq = 8
            if(idx <= 0 .and. idy > 0) iq = 5
            if(idx > 0 .and. idy >= 0) iq = 6
            if(idx < 0 .and. idy <= 0) iq = 7
          end if
          ninoct(iq) = ninoct(iq) + 1
          if(ninoct(iq) > noct) cycle
        end if

        ncnode = ncnode + 1
        icnode(ncnode) = il
        cnodex(ncnode) = xmn + real(i-1)*xsiz
        cnodey(ncnode) = ymn + real(j-1)*ysiz
        cnodez(ncnode) = zmn + real(k-1)*zsiz
        cnodev(ncnode) = sim(ind)
      end if
    end do

  end subroutine srchnd_local


  !--------------------------------------------------------------------
  ! krige_local: Build and solve Simple Kriging system
  !   Thread-safe: all work arrays passed in
  !--------------------------------------------------------------------
  subroutine krige_local(ix, iy, iz, xx, yy, zz, &
                         nclose, close_arr, dat, &
                         ncnode, icnode, cnodex, cnodey, cnodez, cnodev, &
                         nst_arr, c0_arr, it_arr, cc_arr, aa_arr, &
                         rotmat, nctx, ncty, nctz, covtab, cbb, &
                         nx, ny, nz, nxy, &
                         ixnode, iynode, iznode, &
                         a, r, rr, s, vra, &
                         cmean, cstdev)
    integer, intent(in)    :: ix, iy, iz
    real, intent(in)       :: xx, yy, zz
    integer, intent(in)    :: nclose
    real, intent(in)       :: close_arr(*)
    type(data_set), intent(in) :: dat
    integer, intent(in)    :: ncnode
    integer, intent(in)    :: icnode(MAXNOD)
    real, intent(in)       :: cnodex(MAXNOD), cnodey(MAXNOD)
    real, intent(in)       :: cnodez(MAXNOD), cnodev(MAXNOD)
    integer, intent(in)    :: nst_arr(1)
    real, intent(in)       :: c0_arr(1)
    integer, intent(in)    :: it_arr(MAXNST)
    real, intent(in)       :: cc_arr(MAXNST), aa_arr(MAXNST)
    real*8, intent(in)     :: rotmat(MAXROT, 3, 3)
    integer, intent(in)    :: nctx, ncty, nctz
    real, intent(in)       :: covtab(MAXCTX, MAXCTY, MAXCTZ)
    real, intent(in)       :: cbb
    integer, intent(in)    :: nx, ny, nz, nxy
    integer(2), intent(in) :: ixnode(*), iynode(*), iznode(*)
    real*8, intent(out)    :: a(MAXKR2), r(MAXKR1), rr(MAXKR1), s(MAXKR1)
    real, intent(out)      :: vra(MAXKR1)
    real, intent(out)      :: cmean, cstdev

    integer :: na, neq, i_kr, j_kr, in_kr, ising
    integer :: index_d, ind_node
    real    :: x1, y1, z1, x2, y2, z2
    real    :: cov_val, cmax_v
    integer :: ii, jj, kk, ix1, iy1, iz1, ix2, iy2, iz2

    na  = nclose + ncnode
    neq = na   ! Simple Kriging

    ! Build kriging matrices (upper triangular storage)
    in_kr = 0
    do j_kr = 1, na

      ! Location and value of point j
      if(j_kr <= nclose) then
        index_d = int(close_arr(j_kr))
        x1 = dat%x(index_d)
        y1 = dat%y(index_d)
        z1 = dat%z(index_d)
        vra(j_kr) = dat%v(index_d)
      else
        ind_node  = j_kr - nclose
        x1 = cnodex(ind_node)
        y1 = cnodey(ind_node)
        z1 = cnodez(ind_node)
        vra(j_kr) = cnodev(ind_node)
        ! Compute grid indices for covariance table lookup
        ix1 = ix + (int(ixnode(icnode(ind_node))) - nctx - 1)
        iy1 = iy + (int(iynode(icnode(ind_node))) - ncty - 1)
        iz1 = iz + (int(iznode(icnode(ind_node))) - nctz - 1)
      end if

      do i_kr = 1, j_kr
        in_kr = in_kr + 1

        if(i_kr <= nclose) then
          index_d = int(close_arr(i_kr))
          x2 = dat%x(index_d)
          y2 = dat%y(index_d)
          z2 = dat%z(index_d)
        else
          ind_node = i_kr - nclose
          x2 = cnodex(ind_node)
          y2 = cnodey(ind_node)
          z2 = cnodez(ind_node)
          ix2 = ix + (int(ixnode(icnode(ind_node))) - nctx - 1)
          iy2 = iy + (int(iynode(icnode(ind_node))) - ncty - 1)
          iz2 = iz + (int(iznode(icnode(ind_node))) - nctz - 1)
        end if

        ! Compute covariance between points i and j
        if(j_kr <= nclose .or. i_kr <= nclose) then
          ! At least one is original data - use cova3
          call cova3(x1, y1, z1, x2, y2, z2, 1, nst_arr, MAXNST, &
                     c0_arr, it_arr, cc_arr, aa_arr, 1, MAXROT, &
                     rotmat, cmax_v, cov_val)
          a(in_kr) = dble(cov_val)
        else
          ! Both are simulated nodes - try covariance table lookup
          ii = nctx + 1 + (ix1 - ix2)
          jj = ncty + 1 + (iy1 - iy2)
          kk = nctz + 1 + (iz1 - iz2)
          if(ii >= 1 .and. ii <= MAXCTX .and. &
             jj >= 1 .and. jj <= MAXCTY .and. &
             kk >= 1 .and. kk <= MAXCTZ) then
            cov_val = covtab(ii, jj, kk)
          else
            call cova3(x1, y1, z1, x2, y2, z2, 1, nst_arr, MAXNST, &
                       c0_arr, it_arr, cc_arr, aa_arr, 1, MAXROT, &
                       rotmat, cmax_v, cov_val)
          end if
          a(in_kr) = dble(cov_val)
        end if
      end do

      ! Right-hand side: covariance between estimation point and j
      if(j_kr <= nclose) then
        call cova3(xx, yy, zz, x1, y1, z1, 1, nst_arr, MAXNST, &
                   c0_arr, it_arr, cc_arr, aa_arr, 1, MAXROT, &
                   rotmat, cmax_v, cov_val)
        r(j_kr) = dble(cov_val)
      else
        ! Try covariance table lookup
        ii = nctx + 1 + (ix - ix1)
        jj = ncty + 1 + (iy - iy1)
        kk = nctz + 1 + (iz - iz1)
        if(ii >= 1 .and. ii <= MAXCTX .and. &
           jj >= 1 .and. jj <= MAXCTY .and. &
           kk >= 1 .and. kk <= MAXCTZ) then
          cov_val = covtab(ii, jj, kk)
        else
          call cova3(xx, yy, zz, x1, y1, z1, 1, nst_arr, MAXNST, &
                     c0_arr, it_arr, cc_arr, aa_arr, 1, MAXROT, &
                     rotmat, cmax_v, cov_val)
        end if
        r(j_kr) = dble(cov_val)
      end if
      rr(j_kr) = r(j_kr)
    end do

    ! Solve the SK system
    if(neq == 1) then
      s(1) = r(1) / a(1)
      ising = 0
    else
      call ksol(1, neq, 1, a, r, s, ising)
    end if

    ! Handle singular matrix
    if(ising /= 0) then
      cmean  = 0.0
      cstdev = 1.0
      return
    end if

    ! Compute SK estimate and variance
    cmean  = 0.0
    cstdev = cbb
    do i_kr = 1, na
      cmean  = cmean  + real(s(i_kr)) * vra(i_kr)
      cstdev = cstdev - real(s(i_kr) * rr(i_kr))
    end do

    ! Clamp negative variance
    if(cstdev < 0.0) cstdev = 0.0
    cstdev = sqrt(cstdev)

  end subroutine krige_local


  !--------------------------------------------------------------------
  ! acorni_func: Thread-safe ACORN RNG (local state version)
  !--------------------------------------------------------------------
  real*8 function acorni_func(ixv_l)
    integer, intent(inout) :: ixv_l(MAXOP1)
    integer :: i

    do i = 1, KORDEI
      ixv_l(i+1) = ixv_l(i+1) + ixv_l(i)
      if(ixv_l(i+1) >= MAXINT_RNG) ixv_l(i+1) = ixv_l(i+1) - MAXINT_RNG
    end do
    acorni_func = dble(ixv_l(KORDEI+1)) / dble(MAXINT_RNG)
  end function acorni_func

end module gslib_sgsim


!----------------------------------------------------------------------
! Module: gslib_sisim
!   In-memory Sequential Indicator Simulation (stub)
!----------------------------------------------------------------------
module gslib_sisim
  use gslib_types
  implicit none
  private
  public :: sisim_run

contains

  subroutine sisim_run(dat, grid, nsim, seed, nthresh, thresholds, &
                       gcdf, sim_all)
    type(data_set), intent(inout) :: dat
    type(grid_def), intent(in)    :: grid
    integer, intent(in)           :: nsim, seed, nthresh
    real, intent(in)              :: thresholds(:), gcdf(:)
    real, intent(out)             :: sim_all(grid%nxyz, nsim)

    write(*,'(a)') 'WARNING: SISIM workflow not yet implemented'
    sim_all = 0.0

  end subroutine sisim_run

end module gslib_sisim


!----------------------------------------------------------------------
! Module: gslib_postsim
!   In-memory post-processing of simulation results
!----------------------------------------------------------------------
module gslib_postsim
  use gslib_types
  implicit none
  private
  public :: postsim_run

contains

  !--------------------------------------------------------------------
  ! postsim_run: Compute E-type (mean), variance, and quantiles
  !   OpenMP parallel over grid nodes
  !--------------------------------------------------------------------
  subroutine postsim_run(sim, nxyz, nsim, etype, variance, &
                         p10, p50, p90)
    integer, intent(in)  :: nxyz, nsim
    real, intent(in)     :: sim(nxyz, nsim)
    real, intent(out)    :: etype(nxyz), variance(nxyz)
    real, intent(out)    :: p10(nxyz), p50(nxyz), p90(nxyz)

    integer :: i, j, ne
    real    :: av, ss
    real, allocatable :: vals(:)
    integer :: idx10, idx50, idx90

    ! Quantile indices (nearest rank method)
    idx10 = max(1, nint(0.10 * real(nsim)))
    idx50 = max(1, nint(0.50 * real(nsim)))
    idx90 = max(1, nint(0.90 * real(nsim)))

    !$OMP PARALLEL DO PRIVATE(i, j, ne, av, ss, vals) SCHEDULE(STATIC)
    do i = 1, nxyz
      allocate(vals(nsim))
      ne = 0; av = 0.0; ss = 0.0

      do j = 1, nsim
        if(sim(i,j) > (UNEST + EPSLON)) then
          ne = ne + 1
          vals(ne) = sim(i,j)
          av = av + sim(i,j)
          ss = ss + sim(i,j) * sim(i,j)
        end if
      end do

      if(ne > 0) then
        av = av / real(ne)
        ss = ss / real(ne) - av * av
        etype(i)    = av
        variance(i) = ss

        ! Sort for quantiles
        call sort_real(vals, ne)
        p10(i) = vals(max(1, nint(0.10 * real(ne))))
        p50(i) = vals(max(1, nint(0.50 * real(ne))))
        p90(i) = vals(max(1, nint(0.90 * real(ne))))
      else
        etype(i)    = UNEST
        variance(i) = UNEST
        p10(i)      = UNEST
        p50(i)      = UNEST
        p90(i)      = UNEST
      end if

      deallocate(vals)
    end do
    !$OMP END PARALLEL DO

    write(*,'(a)') '  Post-processing (E-type, variance, quantiles) complete'

  end subroutine postsim_run

  !--------------------------------------------------------------------
  ! sort_real: Simple insertion sort for small arrays
  !--------------------------------------------------------------------
  subroutine sort_real(a, n)
    real, intent(inout) :: a(*)
    integer, intent(in) :: n
    integer :: i, j
    real    :: key

    do i = 2, n
      key = a(i)
      j = i - 1
      do while(j >= 1 .and. a(j) > key)
        a(j+1) = a(j)
        j = j - 1
      end do
      a(j+1) = key
    end do
  end subroutine sort_real

end module gslib_postsim


!----------------------------------------------------------------------
! Module: gslib_engine
!   Orchestrates simulation workflows
!----------------------------------------------------------------------
module gslib_engine
  use gslib_types
  use gslib_declus
  use gslib_nscore
  use gslib_backtr_mod
  use gslib_sgsim
  use gslib_sisim
  use gslib_postsim
  implicit none
  private
  public :: engine_run

contains

  !--------------------------------------------------------------------
  ! engine_run: Main workflow orchestrator
  !--------------------------------------------------------------------
  subroutine engine_run(parfile)
    character(len=*), intent(in) :: parfile

    ! Workflow parameters
    character(len=40) :: workflow, datafl, outfl
    integer :: ixl, iyl, izl, ivrl, iwl
    real    :: tmin, tmax

    ! Engine objects
    type(grid_def)        :: grid
    type(vario_model)     :: vmodel
    type(search_pars)     :: srch
    type(data_set)        :: dat
    type(transform_table) :: tbl

    integer :: nsim, seed, iout
    integer :: nxyz

    ! SGSIM arrays
    real, allocatable :: sim_all(:,:)
    real, allocatable :: wt(:)
    real, allocatable :: etype(:), var_map(:), p10(:), p50(:), p90(:)

    ! SISIM parameters
    integer :: nthresh
    real, allocatable :: thresholds(:), gcdf(:)

    ! Locals
    real    :: var(50)
    integer :: i, j, lin, lout, nvari, nd, nt
    character(len=256) :: str
    logical :: testfl
    real    :: av, ss, twt

    lin  = 10
    lout = 20

    ! ================================================================
    ! READ PARAMETER FILE
    ! ================================================================
    write(*,'(/,a,/)') '==========================================='
    write(*,'(a)')     '  GSLIB Unified Simulation Engine'
    write(*,'(a,/)')   '==========================================='

    inquire(file=parfile, exist=testfl)
    if(.not. testfl) then
      write(*,*) 'ERROR: parameter file does not exist: ', trim(parfile)
      stop
    end if

    open(lin, file=parfile, status='OLD')

    ! Skip to START OF PARAMETERS
    do
      read(lin, '(a)', end=900) str
      if(str(1:4) == 'STAR') exit
    end do

    ! Read workflow type
    read(lin, '(a40)', err=900) workflow
    call trim_comment(workflow)
    write(*,'(a,a)') '  Workflow: ', trim(workflow)

    ! Read data file
    read(lin, '(a40)', err=900) datafl
    call trim_comment(datafl)
    write(*,'(a,a)') '  Data file: ', trim(datafl)

    ! Read column indices
    read(lin, *, err=900) ixl, iyl, izl, ivrl, iwl
    write(*,'(a,5i4)') '  Columns: ', ixl, iyl, izl, ivrl, iwl

    ! Read trimming limits
    read(lin, *, err=900) tmin, tmax
    write(*,'(a,2f12.4)') '  Trimming limits: ', tmin, tmax

    ! Read grid definition
    read(lin, *, err=900) grid%nx, grid%xmn, grid%xsiz
    read(lin, *, err=900) grid%ny, grid%ymn, grid%ysiz
    read(lin, *, err=900) grid%nz, grid%zmn, grid%zsiz
    grid%nxy  = grid%nx * grid%ny
    grid%nxyz = grid%nx * grid%ny * grid%nz
    nxyz = grid%nxyz
    write(*,'(a,3i6)') '  Grid: ', grid%nx, grid%ny, grid%nz
    write(*,'(a,i12)') '  Total nodes: ', nxyz

    ! Read simulation parameters
    read(lin, *, err=900) nsim
    write(*,'(a,i6)') '  Realizations: ', nsim

    read(lin, *, err=900) seed
    write(*,'(a,i12)') '  Seed: ', seed

    ! Read search parameters
    read(lin, *, err=900) srch%ndmin, srch%ndmax
    read(lin, *, err=900) srch%nodmax
    read(lin, *, err=900) srch%radius, srch%radius1, srch%radius2
    srch%radsqd = srch%radius * srch%radius
    srch%sanis1 = srch%radius1 / max(srch%radius, EPSLON)
    srch%sanis2 = srch%radius2 / max(srch%radius, EPSLON)
    srch%noct   = 0  ! no octant search by default

    read(lin, *, err=900) srch%sang1, srch%sang2, srch%sang3
    write(*,'(a,3f8.2)') '  Search radii: ', srch%radius, &
         srch%radius1, srch%radius2
    write(*,'(a,3f8.2)') '  Search angles: ', srch%sang1, &
         srch%sang2, srch%sang3

    ! Read back-transform parameters
    read(lin, *, err=900) tbl%zmin, tbl%zmax
    read(lin, *, err=900) tbl%ltail, tbl%ltpar
    read(lin, *, err=900) tbl%utail, tbl%utpar
    write(*,'(a,2f10.2)') '  Zmin/Zmax: ', tbl%zmin, tbl%zmax

    ! Read variogram model
    read(lin, *, err=900) vmodel%nst, vmodel%c0
    vmodel%sill = vmodel%c0
    write(*,'(a,i3,f8.4)') '  Variogram: nst, c0 = ', &
         vmodel%nst, vmodel%c0

    do i = 1, vmodel%nst
      read(lin, *, err=900) vmodel%it(i), vmodel%cc(i), &
           vmodel%ang1(i), vmodel%ang2(i), vmodel%ang3(i)
      read(lin, *, err=900) vmodel%aa_hmax(i), vmodel%aa_hmin(i), &
           vmodel%aa_vert(i)
      vmodel%aa(i)    = vmodel%aa_hmax(i)
      vmodel%anis1(i) = vmodel%aa_hmin(i) / max(vmodel%aa_hmax(i), EPSLON)
      vmodel%anis2(i) = vmodel%aa_vert(i) / max(vmodel%aa_hmax(i), EPSLON)
      vmodel%sill     = vmodel%sill + vmodel%cc(i)
      write(*,'(a,i2,a,i2,a,f8.4,a,3f8.2)') '    Structure ', i, &
           ': type=', vmodel%it(i), ' cc=', vmodel%cc(i), &
           ' ranges=', vmodel%aa_hmax(i), vmodel%aa_hmin(i), &
           vmodel%aa_vert(i)
    end do

    if(abs(vmodel%sill - 1.0) > EPSLON) then
      write(*,'(a,f8.4)') '  WARNING: variogram sill is not 1.0: ', &
           vmodel%sill
    end if

    ! Read output parameters
    read(lin, '(a40)', err=900) outfl
    call trim_comment(outfl)
    read(lin, *, err=900) iout
    write(*,'(a,a)') '  Output file: ', trim(outfl)
    write(*,'(a,i2)') '  Output option: ', iout

    ! SISIM extra parameters (if applicable)
    if(trim(workflow) == 'sisim') then
      read(lin, *, err=900) nthresh
      allocate(thresholds(nthresh), gcdf(nthresh))
      read(lin, *, err=900) (thresholds(i), i=1,nthresh)
      read(lin, *, err=900) (gcdf(i), i=1,nthresh)
    end if

    close(lin)

    ! ================================================================
    ! READ DATA
    ! ================================================================
    write(*,'(/,a)') '--- Reading Data ---'
    call read_data(datafl, ixl, iyl, izl, ivrl, iwl, tmin, tmax, &
                   grid, dat)
    write(*,'(a,i8,a)') '  Read ', dat%nd, ' data'

    ! ================================================================
    ! RUN WORKFLOW
    ! ================================================================
    select case(trim(workflow))

    ! ----------------------------------------------------------------
    case('sgsim')
    ! ----------------------------------------------------------------
      write(*,'(/,a)') '--- SGSIM Workflow ---'

      ! Step 1: Declustering
      write(*,'(/,a)') '--- Step 1: Declustering ---'
      allocate(wt(dat%nd))
      if(dat%nd > 0) then
        call declus_run(dat, grid, wt)
      end if

      ! Step 2: Normal Score Transform
      write(*,'(/,a)') '--- Step 2: Normal Score Transform ---'
      if(dat%nd > 0) then
        call nscore_run(dat, wt, tmin, tmax, tbl)
      else
        ! No data: empty transform table
        tbl%nt = 0
      end if

      ! Step 3: SGSIM (OpenMP parallel realizations)
      write(*,'(/,a)') '--- Step 3: Sequential Gaussian Simulation ---'
      allocate(sim_all(nxyz, nsim))
      call sgsim_run(dat, grid, vmodel, srch, nsim, seed, sim_all)

      ! Step 4: Back-transform (vectorized)
      write(*,'(/,a)') '--- Step 4: Back Transform ---'
      if(tbl%nt > 0) then
        call backtr_array(sim_all, nxyz, nsim, tbl)
      end if

      ! Step 5: Post-processing
      write(*,'(/,a)') '--- Step 5: Post-Processing ---'
      allocate(etype(nxyz), var_map(nxyz))
      allocate(p10(nxyz), p50(nxyz), p90(nxyz))
      call postsim_run(sim_all, nxyz, nsim, etype, var_map, p10, p50, p90)

      ! Step 6: Write results
      write(*,'(/,a)') '--- Step 6: Writing Output ---'
      call write_output(outfl, iout, grid, nsim, sim_all, &
                        etype, var_map, p10, p50, p90)

      ! Cleanup
      deallocate(wt, sim_all, etype, var_map, p10, p50, p90)

    ! ----------------------------------------------------------------
    case('sisim')
    ! ----------------------------------------------------------------
      write(*,'(/,a)') '--- SISIM Workflow ---'

      ! Step 1: Declustering
      allocate(wt(dat%nd))
      if(dat%nd > 0) call declus_run(dat, grid, wt)

      ! Step 2: SISIM
      allocate(sim_all(nxyz, nsim))
      call sisim_run(dat, grid, nsim, seed, nthresh, thresholds, &
                     gcdf, sim_all)

      ! Step 3: Post-processing
      allocate(etype(nxyz), var_map(nxyz))
      allocate(p10(nxyz), p50(nxyz), p90(nxyz))
      call postsim_run(sim_all, nxyz, nsim, etype, var_map, p10, p50, p90)

      ! Step 4: Write results
      call write_output(outfl, iout, grid, nsim, sim_all, &
                        etype, var_map, p10, p50, p90)

      deallocate(wt, sim_all, etype, var_map, p10, p50, p90)
      deallocate(thresholds, gcdf)

    case default
      write(*,*) 'ERROR: unknown workflow: ', trim(workflow)
      write(*,*) '  Valid workflows: sgsim, sisim'
      stop
    end select

    write(*,'(/,a,/)') '==========================================='
    write(*,'(a)')     '  GSLIB Engine: Workflow complete'
    write(*,'(a,/)')   '==========================================='

    return

900 continue
    write(*,*) 'ERROR reading parameter file!'
    stop

  end subroutine engine_run


  !--------------------------------------------------------------------
  ! read_data: Read a GEOEAS-format data file into data_set
  !--------------------------------------------------------------------
  subroutine read_data(datafl, ixl, iyl, izl, ivrl, iwl, &
                       tmin, tmax, grid, dat)
    character(len=*), intent(in) :: datafl
    integer, intent(in)          :: ixl, iyl, izl, ivrl, iwl
    real, intent(in)             :: tmin, tmax
    type(grid_def), intent(in)   :: grid
    type(data_set), intent(out)  :: dat

    integer :: lin, nvari, nd, nt, i, j
    real    :: var(50)
    character(len=256) :: str
    logical :: testfl

    lin = 11

    dat%nd = 0
    inquire(file=datafl, exist=testfl)
    if(.not. testfl) then
      write(*,*) 'WARNING: data file not found: ', trim(datafl)
      write(*,*) '  Proceeding with unconditional simulation'
      allocate(dat%x(1), dat%y(1), dat%z(1), dat%v(1), dat%wt(1))
      return
    end if

    ! First pass: count valid data
    open(lin, file=datafl, status='OLD')
    read(lin, '(a)', end=50, err=50) str
    read(lin, *, end=50, err=50) nvari
    do i = 1, nvari
      read(lin, *, end=50, err=50)
    end do

    nd = 0
    nt = 0
    do
      read(lin, *, end=10, err=50) (var(j), j=1,nvari)
      if(var(ivrl) < tmin .or. var(ivrl) >= tmax) then
        nt = nt + 1
        cycle
      end if
      nd = nd + 1
    end do
10  continue
    close(lin)

    if(nd == 0) then
      write(*,*) 'WARNING: no valid data found'
      dat%nd = 0
      allocate(dat%x(1), dat%y(1), dat%z(1), dat%v(1), dat%wt(1))
      return
    end if

    ! Allocate and second pass: read data
    allocate(dat%x(nd), dat%y(nd), dat%z(nd), dat%v(nd), dat%wt(nd))

    open(lin, file=datafl, status='OLD')
    read(lin, '(a)') str
    read(lin, *) nvari
    do i = 1, nvari
      read(lin, *)
    end do

    nd = 0
    do
      read(lin, *, end=20, err=50) (var(j), j=1,nvari)
      if(var(ivrl) < tmin .or. var(ivrl) >= tmax) cycle
      nd = nd + 1

      if(ixl > 0) then
        dat%x(nd) = var(ixl)
      else
        dat%x(nd) = grid%xmn
      end if
      if(iyl > 0) then
        dat%y(nd) = var(iyl)
      else
        dat%y(nd) = grid%ymn
      end if
      if(izl > 0) then
        dat%z(nd) = var(izl)
      else
        dat%z(nd) = grid%zmn
      end if
      dat%v(nd)  = var(ivrl)
      if(iwl > 0) then
        dat%wt(nd) = var(iwl)
      else
        dat%wt(nd) = 1.0
      end if
    end do
20  continue
    close(lin)

    dat%nd = nd
    write(*,'(a,i8,a,i8,a)') '  Loaded ', nd, ' data (', nt, ' trimmed)'
    return

50  continue
    write(*,*) 'ERROR reading data file!'
    stop

  end subroutine read_data


  !--------------------------------------------------------------------
  ! write_output: Write results to GEOEAS-format file
  !   iout: 1=etype only, 2=all realizations, 3=both
  !--------------------------------------------------------------------
  subroutine write_output(outfl, iout, grid, nsim, sim_all, &
                          etype, var_map, p10, p50, p90)
    character(len=*), intent(in) :: outfl
    integer, intent(in)          :: iout
    type(grid_def), intent(in)   :: grid
    integer, intent(in)          :: nsim
    real, intent(in)             :: sim_all(grid%nxyz, nsim)
    real, intent(in)             :: etype(grid%nxyz), var_map(grid%nxyz)
    real, intent(in)             :: p10(grid%nxyz), p50(grid%nxyz)
    real, intent(in)             :: p90(grid%nxyz)

    integer :: lout, ind, isim, ncols, nxyz

    lout = 21
    nxyz = grid%nxyz

    open(lout, file=outfl, status='UNKNOWN')

    if(iout == 1) then
      ! E-type, variance, p10, p50, p90
      write(lout, '(a)') 'GSLIB Engine Output - Summary Statistics'
      write(lout, '(i2)') 5
      write(lout, '(a)') 'E-type Mean'
      write(lout, '(a)') 'Variance'
      write(lout, '(a)') 'P10'
      write(lout, '(a)') 'P50'
      write(lout, '(a)') 'P90'
      do ind = 1, nxyz
        write(lout, '(5(f14.6,1x))') etype(ind), var_map(ind), &
             p10(ind), p50(ind), p90(ind)
      end do

    else if(iout == 2) then
      ! All realizations
      write(lout, '(a)') 'GSLIB Engine Output - All Realizations'
      write(lout, '(i6)') nsim
      do isim = 1, nsim
        write(lout, '(a,i4)') 'Realization_', isim
      end do
      do ind = 1, nxyz
        write(lout, '(999(f14.6,1x))') (sim_all(ind,isim), isim=1,nsim)
      end do

    else if(iout == 3) then
      ! Both: summary + all realizations
      ncols = 5 + nsim
      write(lout, '(a)') 'GSLIB Engine Output - Summary + Realizations'
      write(lout, '(i6)') ncols
      write(lout, '(a)') 'E-type Mean'
      write(lout, '(a)') 'Variance'
      write(lout, '(a)') 'P10'
      write(lout, '(a)') 'P50'
      write(lout, '(a)') 'P90'
      do isim = 1, nsim
        write(lout, '(a,i4)') 'Realization_', isim
      end do
      do ind = 1, nxyz
        write(lout, '(999(f14.6,1x))') etype(ind), var_map(ind), &
             p10(ind), p50(ind), p90(ind), &
             (sim_all(ind,isim), isim=1,nsim)
      end do
    end if

    close(lout)
    write(*,'(a,a)') '  Output written to: ', trim(outfl)

  end subroutine write_output


  !--------------------------------------------------------------------
  ! trim_comment: Remove everything after backslash in parameter line
  !--------------------------------------------------------------------
  subroutine trim_comment(str)
    character(len=*), intent(inout) :: str
    integer :: i

    do i = 1, len(str)
      if(str(i:i) == '\' .or. str(i:i) == '!') then
        str(i:) = ' '
        exit
      end if
    end do

    ! Left-justify and trim
    str = adjustl(str)

  end subroutine trim_comment

end module gslib_engine


!======================================================================
! MAIN PROGRAM
!======================================================================
program gslib_unified
  use gslib_engine
  implicit none

  character(len=256) :: parfile

  ! Get parameter file from command line or prompt
  call get_command_argument(1, parfile)
  if(len_trim(parfile) == 0) then
    write(*,*) 'Which parameter file do you want to use?'
    read(*, '(a)') parfile
  end if
  if(len_trim(parfile) == 0) parfile = 'gslib_engine.par'

  call engine_run(parfile)

end program gslib_unified
