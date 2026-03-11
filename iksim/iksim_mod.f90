module iksim_mod
! ======================================================================
!  IKSIM Module - Fortran 90 module replacing COMMON blocks
!  Converts large static arrays to allocatable for small exe size.
!  GSLIB2-OPT v2026.1
! ======================================================================
  implicit none
  save

! --- User Adjustable Parameters ---
  integer, parameter :: MAXDAT  = 5000000
  integer, parameter :: MAXSAM  = 256
  integer, parameter :: MAXCUT  = 11
  integer, parameter :: MAXNST  = 4
  integer, parameter :: MAXX    = 500, MAXY = 500, MAXZ = 100
  integer, parameter :: MAXSBX  = 21,  MAXSBY = 21, MAXSBZ = 11
  integer, parameter :: MAXCLSX = 513, MAXCLSY = 513, MAXCLSZ = 2
  integer, parameter :: MAXLIM  = 26
  real,    parameter :: DEG2RAD = 3.14159265/180.0
  real,    parameter :: MISSVALUE = -999.0, UNEST = -999.0

! --- Fixed Parameters ---
  integer, parameter :: MAXSB  = MAXSBX*MAXSBY*MAXSBZ
  real,    parameter :: EPSLON = 0.000001
  integer, parameter :: MAXROT = MAXNST*MAXCUT+1
  integer, parameter :: MAXEQ  = MAXSAM+1
  real,    parameter :: VERSION = 2026.1
  integer, parameter :: NUMSCL = 100
  real,    parameter :: PI = 3.1415926

! --- ACORN parameters (ixv stays in COMMON /iaco/, not here) ---
  integer, parameter :: KORDEI = 12, MAXOP1 = KORDEI+1
  integer, parameter :: MAXINT = 2**30

! ======================================================================
! Allocatable arrays (large, heap-allocated at runtime)
! These were the cause of the 1.5 GB exe size in COMMON blocks.
! ======================================================================

! From old COMMON /datcom/:
  real,     allocatable :: x(:), y(:), z(:)
  real,     allocatable :: hardData(:)
  real,     allocatable :: vr(:,:)
  real,     allocatable :: pass(:,:)
  logical,  allocatable :: hasMissValue(:)
  integer,  allocatable :: closestData(:)

! From old COMMON /srccom/:
  real,     allocatable :: sb(:), tmp(:)
  real,     allocatable :: sdis(:), close(:), actloc(:)

! From old COMMON /transdata/:
  real,     allocatable :: variance(:)

! ======================================================================
! Small static arrays (kept as fixed-size module variables)
! ======================================================================

! Superblock search arrays
  integer :: nisb(MAXSB)
  integer :: ixsbtosr(8*MAXSB), iysbtosr(8*MAXSB), izsbtosr(8*MAXSB)

! Search / kriging workspace
  real    :: xa(MAXSAM), ya(MAXSAM), za(MAXSAM), vra(MAXSAM)

! CDF arrays
  real    :: gcdf(MAXCUT), ccdf(MAXCUT), ccdfo(MAXCUT)
  real    :: aviol(MAXCUT), xviol(MAXCUT)
  integer :: nviol(MAXCUT)

! Variogram parameters
  real    :: thres(MAXCUT), c0(MAXCUT), cc(MAXCUT*MAXNST)
  real    :: aa(MAXCUT*MAXNST), ang1(MAXCUT*MAXNST)
  real    :: ang2(MAXCUT*MAXNST), ang3(MAXCUT*MAXNST)
  real    :: anis1(MAXCUT*MAXNST), anis2(MAXCUT*MAXNST)
  integer :: it(MAXCUT*MAXNST), nst(MAXCUT)

! Kriging system arrays
  real(8) :: r(MAXEQ), s(MAXEQ), a(MAXEQ*MAXEQ)
  real(8) :: rotmat(MAXROT,3,3)

! PFSIMFFT arrays (small with MAXCLSZ=2)
  real    :: coefarray(2*MAXCLSX*MAXCLSY*MAXCLSZ)
  real    :: covmap(2,MAXCLSX,MAXCLSY,MAXCLSZ)
  real    :: phase(2,MAXCLSX,MAXCLSY,MAXCLSZ)
  real    :: coef(2,MAXCLSX,MAXCLSY,MAXCLSZ)

! ======================================================================
! Scalar variables (from old COMMON blocks)
! ======================================================================

! From /datcom/:
  integer :: nd, nx, ny, nz
  integer :: ndmax, ndmin, isrot, ivrot, mik, ktype
  integer :: noct, ikidbg, ldbg, iout, lout
  integer :: ivtype, koption, lin
  real    :: xmn, ymn, zmn, xsiz, ysiz, zsiz
  real    :: radius, sang1, sang2, sang3, sanis1, sanis2
  real    :: tmin, tmax

! From /srccom/:
  integer :: na, ljack, ixlj, iylj, izlj, ivrlj, nvarij

! From /vargdt/:
  integer :: ncut

! From /ik3ddata/:
  character(40) :: ikoutfl, ikdbgfl

! From /postikdata/:
  integer :: ipostik, ietype, iprob, ipercentile, icondvar, idefault
  integer :: ltail, middle, utail, maxdis
  real    :: zmin, zmax, parlim, parprob, ltpar, mpar, utpar
  character(40) :: postoutfl

! From /pfsimdata/:
  character(40) :: simoutfl, simdbgfl
  integer :: idosim, simidbg, nsim, nn(3)
  integer :: nstz(1), itz(MAXNST)
  real    :: c0z(1), ccz(MAXNST)
  real    :: aaz(MAXNST), ang1z(MAXNST)
  real    :: ang2z(MAXNST), ang3z(MAXNST)
  real    :: anis1z(MAXNST), anis2z(MAXNST)

! From /transdata/:
  character(40) :: distin, transoutfl
  integer :: identhist, itarget, transivr, transiwt, wx, wy, wz
  real    :: omega

contains

  subroutine iksim_alloc(mxdat, nxyz)
! ------------------------------------------------------------------
!   Allocate all large arrays. Call after reading nx,ny,nz from
!   parameter file, with nxyz = nx*ny*nz and mxdat = MAXDAT.
! ------------------------------------------------------------------
    integer, intent(in) :: mxdat, nxyz

    if (.not. allocated(x)) then
      allocate(x(mxdat), y(mxdat), z(mxdat), hardData(mxdat))
      allocate(vr(mxdat, MAXCUT+1))
      allocate(hasMissValue(mxdat))
      allocate(sb(mxdat), tmp(mxdat))
      allocate(sdis(mxdat), close(mxdat), actloc(mxdat))
    end if

    if (.not. allocated(pass)) then
      allocate(pass(nxyz, MAXCUT))
      allocate(closestData(nxyz))
      allocate(variance(nxyz))
    end if

  end subroutine iksim_alloc

end module iksim_mod
