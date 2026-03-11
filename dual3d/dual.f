      program main
C%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
C                                                                      %
C Copyright (C) 1998, The Board of Trustees of the Leland Stanford     %
C Junior University.  All rights reserved.                             %
C                                                                      %
C The programs in GSLIB are distributed in the hope that they will be  %
C useful, but WITHOUT ANY WARRANTY.  No author or distributor accepts  %
C responsibility to anyone for the consequences of using them or for   %
C whether they serve any particular purpose or work at all, unless he  %
C says so in writing.  Everyone is granted permission to copy, modify  %
C and redistribute the programs in GSLIB, but only under the condition %
C that this notice and the above copyright notice remain intact.       %
C                                                                      %
C%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
c-----------------------------------------------------------------------
c
c            Dual Kriging (SK,OK) of a 3-D Rectangular Grid
c            *********************************************
c
c The program is executed with no command line arguments.  The user
c will be prompted for the name of a parameter file.  The parameter
c file is described in the documentation (see the example dual.par)
c and should contain the following information:
c
c
c
c-----------------------------------------------------------------------
      include  'dual.inc'
c
c Read the parameters, the data, and open the output files:
c
      call readparm
c
c Call kt3d to krige the grid:
c
      call dual 
c
c Finished:
c
      close(ldbg)
      close(lout)
      write(*,9998) VERSION
 9998 format(/' DUAL3D - GSLIB2-OPT v',f7.1, ' Finished'/)
      stop
      end
 
 
 
      subroutine readparm
c-----------------------------------------------------------------------
c
c                  Initialization and Read Parameters
c                  **********************************
c
c The input parameters and data are read in from their files. Some quick
c error checking is performed and the statistics of all the variables
c being considered are written to standard output.
c
c
c
c-----------------------------------------------------------------------
      include  'dual.inc'
      parameter(MV=20)
      real      var(MV)
      character datafl*40,jackfl*40,extfl*40,outfl*40,dbgfl*40,
     +          str*40,title*80
      logical   testfl
c
c FORTRAN Units:
c
      lin   = 1
      ldbg  = 3
      lout  = 4
      lext  = 7
      ljack = 8
c
c Note VERSION number:
c
      write(*,9999) VERSION
 9999 format(/' DUAL3D - GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)
c
c Get the name of the parameter file - try the default name if no input:
c
      write(*,*) 'Which parameter file do you want to use?'
      read (*,'(a40)') str
      if(str(1:1).eq.' ')str='dual.par                                 '
      inquire(file=str,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR - the parameter file does not exist,'
            write(*,*) '        check for the file and try again  '
            write(*,*)
            if(str(1:20).eq.'dual.par            ') then
                  write(*,*) '        creating a blank parameter file'
                  call makepar
                  write(*,*)
            end if
            stop
      endif
      open(lin,file=str,status='OLD')
c
c Find Start of Parameters:
c
 1    read(lin,'(a4)',end=98) str(1:4)
      if(str(1:4).ne.'STAR') go to 1
c
c Read Input Parameters:
c
      read(lin,'(a40)',err=98) datafl
      call chknam(datafl,40)
      write(*,*) ' data file = ',datafl

      read(lin,*,err=98) ixl,iyl,izl,ivrl
      write(*,*) ' columns = ',ixl,iyl,izl,ivrl

      read(lin,*,err=98) tmin,tmax
      write(*,*) ' trimming limits = ',tmin,tmax

      read(lin,*,err=98) koption
      write(*,*) ' kriging option = ',koption

      read(lin,'(a40)',err=98) jackfl
      call chknam(jackfl,40)
      write(*,*) ' jackknife data file = ',jackfl

      read(lin,*,err=98) ixlj,iylj,izlj,ivrlj
      write(*,*) ' columns = ',ixlj,iylj,izlj,ivrlj

      read(lin,*,err=98) idbg
      write(*,*) ' debugging level = ',idbg

      read(lin,'(a40)',err=98) dbgfl
      call chknam(dbgfl,40)
      write(*,*) ' debugging file = ',dbgfl

      read(lin,'(a40)',err=98) outfl
      call chknam(outfl,40)
      write(*,*) ' output file = ',outfl

      read(lin,*,err=98) nx,xmn,xsiz
      write(*,*) ' nx, xmn, xsiz = ',nx,xmn,xsiz

      read(lin,*,err=98) ny,ymn,ysiz
      write(*,*) ' ny, ymn, ysiz = ',ny,ymn,ysiz

      read(lin,*,err=98) nz,zmn,zsiz
      write(*,*) ' nz, zmn, zsiz = ',nz,zmn,zsiz

      read(lin,*,err=98) ktype,skmean
      write(*,*) ' ktype, skmean =',ktype,skmean

      read(lin,*,err=98) nst(1),c0(1)
      write(*,*) ' nst, c0 = ',nst(1),c0(1)

      if(nst(1).le.0) then
            write(*,9997) nst(1)
 9997       format(' nst must be at least 1, it has been set to ',i4,/,
     +             ' The c or a values can be set to zero')
            stop
      endif

      do i=1,nst(1)
            read(lin,*,err=98) it(i),cc(i),ang1(i),ang2(i),ang3(i)
            read(lin,*,err=98) aa(i),aa1,aa2
            anis1(i) = aa1 / max(aa(i),EPSLON)
            anis2(i) = aa2 / max(aa(i),EPSLON)
            write(*,*) ' it,cc,ang[1,2,3]; ',it(i),cc(i),
     +                   ang1(i),ang2(i),ang3(i)
            write(*,*) ' a1 a2 a3: ',aa(i),aa1,aa2
            if(it(i).eq.4) then
                  if(aa(i).lt.0.0) stop ' INVALID power variogram'
                  if(aa(i).gt.2.0) stop ' INVALID power variogram'
            end if
      end do

      close(lin)
      write(*,*)
c
c Perform some quick error checking:
c
      if(ixl.le.0.and.nx.gt.1) write(*,*) ' WARNING: ixl=0 and nx>1 ! '
      if(iyl.le.0.and.ny.gt.1) write(*,*) ' WARNING: iyl=0 and ny>1 ! '
      if(izl.le.0.and.nz.gt.1) write(*,*) ' WARNING: izl=0 and nz>1 ! '
c
c Check to make sure the data file exists, then either read in the
c data or write an error message and stop:
c
      inquire(file=datafl,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR data file ',datafl,' does not exist!'
            stop
      endif
c
c The data file exists so open the file and read in the header
c information. Initialize the storage that will be used to summarize
c the data found in the file:
c
      title(1:22) = 'KT3D ESTIMATES WITH: '
      open(lin,file=datafl,status='OLD')
      read(lin,'(a58)') title(23:80)
      read(lin,*,err=99)       nvari
      nd = 0
      av = 0.0
      ss = 0.0
      do i=1,nvari
            read(lin,'(a40)',err=99) str
      end do
c
c Some tests on column numbers:
c
      if(ixl.gt.nvari.or.iyl.gt.nvari.or.izl.gt.nvari.or.ivrl.gt.nvari)
     +      then
            write(*,*) 'There are only ',nvari,' columns in input data'
            write(*,*) '  your specification is out of range'
            stop
      end if
c
c Read all the data until the end of the file:
c
 2    read(lin,*,end=3,err=99) (var(j),j=1,nvari)
      vrt = var(ivrl)
      if(vrt.lt.tmin.or.vrt.ge.tmax) go to 2
      nd = nd + 1
      if(nd.gt.MAXEQ) then
            write(*,*) ' ERROR: too much data for dual kriging'
            stop
      end if
c
c Establish the location of this datum:
c
      if(ixl.le.0) then
            x(nd) = xmn
      else
            x(nd) = var(ixl)
      endif
      if(iyl.le.0) then
            y(nd) = ymn
      else
            y(nd) = var(iyl)
      endif
      if(izl.le.0) then
            z(nd) = zmn
      else
            z(nd) = var(izl)
      endif
      vr(nd) = vrt     
      av     = av + vrt
      ss     = ss + vrt*vrt
      go to 2
 3    close(lin)
c
c Compute the averages and variances as an error check for the user:
c
      av = av / max(real(nd),1.0)
      ss =(ss / max(real(nd),1.0)) - av * av
      write(*,*) 'Data for KT3D: Variable number ',ivrl
      write(*,*) '  Number   = ',nd
      write(*,*) '  Average  = ',av
      write(*,*) '  Variance = ',ss
      if(nd.lt.1) then
            write(*,*) ' ERROR: there are no data'
            stop
      end if
c
c Open the debugging and output files:
c
      
      open(ldbg,file=dbgfl,status='UNKNOWN')
      open(lout,file=outfl,status='UNKNOWN')
c
c Open the file with the jackknife data?
c
      if(koption.gt.0) then
            inquire(file=jackfl,exist=testfl)
            if(.not.testfl) then
                  write(*,*) 'ERROR file ',jackfl,' does not exist!'
                  stop
            endif
            open(ljack,file=jackfl,status='OLD')
            read(ljack,*,err=96)
            read(ljack,*,err=96) nvarij
            do i=1,nvarij
                  read(ljack,*,err=96)
            end do
      end if
   

      return
c
c Error in an Input File Somewhere:
c
 96   stop 'ERROR in jackknife file!'
 98   stop 'ERROR in parameter file!'
 99   stop 'ERROR in data file!'
      end



      subroutine dual
c-----------------------------------------------------------------------
c
c                Krige a 3-D Grid of Rectangular Blocks
c                **************************************
c
c OPTIMIZED: OpenMP parallelization of grid evaluation loop,
c            buffered I/O output.
c
c Original:  A.G. Journel and C. Lemmer                             1981
c Revisions: A.G. Journel and C. Kostov                             1984
c-----------------------------------------------------------------------
      include   'dual.inc'
c
      real       var(20)
      real, allocatable :: est_buf(:)
      integer    nxyz
c
      neq=nd
      if(ktype .ge. 1) neq=nd+1

      do i=1,neq*neq
          a(i) = 0.0
      end do
      do i=1,nd
       r(i)=dble(vr(i))
       if(ktype .eq. 0) r(i)=r(i)-dble(skmean)
      end do

      PMX    = 999.0
      covmax = c0(1)
      do is=1,nst(1)
            call setrot(ang1(is),ang2(is),ang3(is),anis1(is),anis2(is),
     +                  is,MAXROT,rotmat)
            if(it(is).eq.4) then
                  covmax = covmax + PMX
            else
                  covmax = covmax + cc(is)
            endif
      end do

       in=0
       do j=1,nd
         do i=1,j
           in=in+1
           call cova3(x(i),y(i),z(i),x(j),y(j),z(j),
     +                1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                    rotmat,cmax,cov)
          a(in)= dble(cov)
       end do
      end do

      if( ktype .ge. 1) then
         do i=1,nd
           in = in + 1
           a(in) = dble(1.0)
         end do
         in = in + 1
         a(in)   = 0.0
      end if

      do i=1,nd
      write(ldbg,100) x(i),y(i), z(i),vr(i)
 100  format(1x,4(f8.3))
      end do

      is = 1
      do i=1,neq
         ie = is + i-1
         write(ldbg,103) i,r(i),(a(j),j=is,ie)
         is=is+i
 103     format('    r(',i2,') =',f8.3,'  a= ',9(10f8.3))
      end do

      call ksol(1,neq,1,a,r,s,ising)
      if(ising.ne.0) then
         write(ldbg,*) 'WARNING : singular matrix'
      endif

      if(koption.eq.0) then
c
c Allocate output buffer and evaluate in parallel:
c
      nxyz = nx*ny*nz
      allocate(est_buf(nxyz))
c
!$OMP PARALLEL DO DEFAULT(SHARED) SCHEDULE(DYNAMIC,64)
!$OMP+PRIVATE(index,ix,iy,iz,xloc,yloc,zloc,est,cov,cmax,i)
      do index=1,nxyz
            iz   = int((index-1)/(nx*ny)) + 1
            iy   = int((index-(iz-1)*nx*ny-1)/nx) + 1
            ix   = index - (iz-1)*nx*ny - (iy-1)*nx
            xloc = xmn + (ix-1)*xsiz
            yloc = ymn + (iy-1)*ysiz
            zloc = zmn + (iz-1)*zsiz
            est  = 0.0
            do i=1,nd
               call cova3(x(i),y(i),z(i),xloc,yloc,zloc,
     +               1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,rotmat,
     +               cmax,cov)
               est = est + real(s(i))*cov
            end do
            if(ktype .eq. 0) est = est + skmean
            if(ktype.ge.1) est = est + s(neq)
            est_buf(index) = est
      end do
!$OMP END PARALLEL DO
c
c Write buffered output (sequential):
c
      do index=1,nxyz
            write(lout,*) est_buf(index)
      end do
      deallocate(est_buf)
c
      end if

      if(koption.gt.0) then
 106        read(ljack,*,err=96,end=2) (var(i),i=1,nvarij)
         xloc = xmn
         yloc = ymn
         zloc = zmn
         if(ixlj.gt.0)   xloc   = var(ixlj)
         if(iylj.gt.0)   yloc   = var(iylj)
         if(izlj.gt.0)   zloc   = var(izlj)
         if(ivrlj.gt.0)  true   = var(ivrlj)
         est=0.0
         do i=1,nd
            call cova3(x(i),y(i),z(i),xloc,yloc,zloc,
     +               1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,rotmat,
     +               cmax,cov)
            est=est+real(s(i))*cov
         end do
         if(ktype .eq. 0) est=est+skmean
         if(ktype.ge.1) est=est+s(neq)
         write(lout,*) xloc,yloc,zloc,est,true
      goto 106
 2    continue
      end if

      if (idbg.gt.1) then
        write(ldbg,*)' covariance'
      end if

      return
 96   stop 'ERROR in jackknife file!'
      end



      subroutine makepar
c-----------------------------------------------------------------------
c
c                      Write a Parameter File
c                      **********************
c
c
c
c-----------------------------------------------------------------------
      lun = 99
      open(lun,file='dual.par',status='UNKNOWN')
      write(lun,10)
 10   format('                  Parameters for KT3D',/,
     +       '                  *******************',/,/,
     +       'START OF PARAMETERS:')

      write(lun,11)
 11   format('../data/cluster.dat              ',
     +       '-file with data')
      write(lun,12)
 12   format('1   2   0    3                  ',
     +       '-   columns for X, Y, Z, var')
      write(lun,13)
 13   format('-1.0e21   1.0e21                 ',
     +       '-   trimming limits')
      write(lun,14)
 14   format('0                                ',
     +       '-option: 0=grid, 1=jackknife')
      write(lun,15)
 15   format('xvk.dat                          ',
     +       '-file with jackknife data')
      write(lun,16)
 16   format('1   2   0    3                  ',
     +       '-   columns for X,Y,Z,vr')
      write(lun,17)
 17   format('3                                ',
     +       '-debugging level: 0,1,2,3')
      write(lun,18)
 18   format('kt3d.dbg                         ',
     +       '-file for debugging output')
      write(lun,19)
 19   format('kt3d.out                         ',
     +       '-file for kriged output')
      write(lun,20)
 20   format('50   0.5    1.0                  ',
     +       '-nx,xmn,xsiz')
      write(lun,21)
 21   format('50   0.5    1.0                  ',
     +       '-ny,ymn,ysiz')
      write(lun,22)
 22   format('1    0.5    1.0                  ',
     +       '-nz,zmn,zsiz')
      write(lun,28)
 28   format('0     2.302                      ',
     +       '-0=SK,1=OK')
      write(lun,33)
 33   format('1    0.2                         ',
     +       '-nst, nugget effect')
      write(lun,34)
 34   format('1    0.8  0.0   0.0   0.0        ',
     +       '-it,cc,ang1,ang2,ang3')
      write(lun,35)
 35   format('         10.0  10.0  10.0        ',
     +       '-a_hmax, a_hmin, a_vert')

      close(lun)
      return
      end
