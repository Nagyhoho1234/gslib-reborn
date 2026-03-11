module anneal_mod
! ======================================================================
!  ANNEAL Module - Fortran 90 module replacing COMMON blocks
!  Converts large var() grid array to allocatable for small exe size.
!  GSLIB2-OPT v2026.1
! ======================================================================
  implicit none
  save

! --- General parameters ---
  integer, parameter :: MAXX   = 500, MAXY = 500, MAXZ = 100
  integer, parameter :: MAXLAG = 24,  MAXDIR = 4, MAXRC = 3
  integer, parameter :: MAXROC = MAXRC+1
  real,    parameter :: VERSION = 2026.1

! --- ACORN parameters (ixv stays in COMMON /iaco/, not here) ---
  integer, parameter :: KORDEI = 12, MAXOP1 = KORDEI+1
  integer, parameter :: MAXINT = 2**30

! ======================================================================
! Allocatable array (the big one: was 100 MB static)
! ======================================================================
  integer, allocatable :: var(:,:,:)

! ======================================================================
! Small static arrays and scalars (from old COMMON /genral/)
! ======================================================================
  real    :: prop(MAXROC)
  integer :: ntrain(MAXROC,MAXROC,MAXDIR,MAXLAG)
  integer :: nact(MAXROC,MAXROC,MAXDIR,MAXLAG)
  integer :: ntry(MAXRC,MAXROC,MAXROC,MAXDIR,MAXLAG)
  integer :: num(MAXDIR,MAXLAG), seed, report
  integer :: ixl(MAXDIR), iyl(MAXDIR), izl(MAXDIR)
  integer :: nlag(MAXDIR), icross(MAXDIR)
  integer :: icat(MAXROC)

! Scalars from /genral/:
  integer :: nsim, nx, ny, nz, nr, np, nv, lout, idbg
  integer :: ldbg, maxit, ndir, mlag, ncat
  real    :: tol

! From /charac/:
  character(40) :: datafl, trainfl, outfl, dbgfl

contains

  subroutine anneal_alloc(inx, iny, inz)
! ------------------------------------------------------------------
!   Allocate the var grid array. Call after reading nx,ny,nz.
! ------------------------------------------------------------------
    integer, intent(in) :: inx, iny, inz

    if (.not. allocated(var)) then
      allocate(var(inx, iny, inz))
    end if

  end subroutine anneal_alloc

end module anneal_mod
