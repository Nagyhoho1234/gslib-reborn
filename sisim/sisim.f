      program main
C%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
C                                                                      %
C Copyright (C) 1996, The Board of Trustees of the Leland Stanford     %
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
c           Conditional Simulation of a 3-D Rectangular Grid
c           ************************************************
c
c The output file will be a GEOEAS file containing the simulated values
c The file is ordered by x,y,z, and then simulation (i.e., x cycles
c fastest, then y, then z, then simulation number).
c
c OPTIMIZED: dynamic grid, multi-RHS kriging, OpenMP, I/O buffering
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
c
c Read the Parameter File and the Data:
c
      call readparm
c
c Call sisim for the simulation:
c
      call sisim
c
c Finished:
c
      close(lout)
      close(ldbg)
      write(*,9998) VERSION
 9998 format(/' SISIM - GSLIB2-OPT v',f7.1, ' Finished'/)
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
c NOTE: 1. The variables and the data are allocated in common blocks
c          (sisim.inc)
c
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
      parameter(MV=20)
      real      var(MV)
      real*8    p,acorni
      integer   ivrs(MAXCUT)
      character datafl*40,tabfl*40,softfl*40,outfl*40,dbgfl*40,
     +          str*40,title*80
      logical   testfl
c
c Fortran unit numbers needed:
c
      lin  = 1
      lout = 2
      ldbg = 3
c
c Note VERSION number:
c
      write(*,9999) VERSION
 9999 format(/' SISIM - GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)
c
c Get the name of the parameter file - try the default name if no input:
c
      write(*,*) 'Which parameter file do you want to use?'
      read (*,'(a40)') str
      if(str(1:1).eq.' ')str='sisim.par                               '
      inquire(file=str,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR - the parameter file does not exist,'
            write(*,*) '        check for the file and try again  '
            write(*,*)
            if(str(1:20).eq.'sisim.par           ') then
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

      read(lin,*,err=98) ivtype
      write(*,*) ' variable type (1=continuous, 0=categorical)= ',ivtype

      read(lin,*,err=98) ncut
      write(*,*) ' number of thresholds / categories = ',ncut
      if(ncut.gt.MAXCUT) stop 'ncut is too big - modify .inc file'

      read(lin,*,err=98) (thres(i),i=1,ncut)
      write(*,*) ' thresholds / categories = ',(thres(i),i=1,ncut)

      read(lin,*,err=98) (cdf(i),i=1,ncut)
      write(*,*) ' global cdf / pdf        = ',(cdf(i),i=1,ncut)

      read(lin,'(a40)',err=98) datafl
      call chknam(datafl,40)
      write(*,*) ' data file = ',datafl

      read(lin,*,err=98) ixl,iyl,izl,ivrl
      write(*,*) ' input columns = ',ixl,iyl,izl,ivrl

      read(lin,'(a40)',err=98) softfl
      call chknam(softfl,40)
      write(*,*) ' soft data file = ',softfl
      inquire(file=softfl,exist=testfl)

      if(testfl) then
            read(lin,*,err=98) ixs,iys,izs,(ivrs(i),i=1,ncut)
            write(*,*) ' columns = ',ixs,iys,izs,(ivrs(i),i=1,ncut)
            read(lin,*,err=98) imbsim
            write(*,*) ' Markov-Bayes simulation = ',imbsim
            if(imbsim.eq.1) then
                  read(lin,*,err=98) (beez(i),i=1,ncut)
            else
                  read(lin,*,err=98)
            end if
      else
            read(lin,*,err=98)
            read(lin,*,err=98)
            read(lin,*,err=98)
      end if

      read(lin,*,err=98) tmin,tmax
      write(*,*) ' trimming limits      ',tmin,tmax

      read(lin,*,err=98) zmin,zmax
      write(*,*) ' data limits (tails)  ',zmin,zmax

      read(lin,*,err=98) ltail,ltpar
      write(*,*) ' lower tail = ',ltail,ltpar

      read(lin,*,err=98) middle,mpar
      write(*,*) ' middle = ',middle,mpar

      read(lin,*,err=98) utail,utpar
      write(*,*) ' upper tail = ',utail,utpar

      read(lin,'(a40)',err=98) tabfl
      call chknam(tabfl,40)
      write(*,*) ' file for tab. quant. ',tabfl

      read(lin,*,err=98) itabvr,itabwt
      write(*,*) ' columns for vr wt = ',itabvr,itabwt

      read(lin,*,err=98) idbg
      write(*,*) ' debugging level = ',idbg

      read(lin,'(a40)',err=98) dbgfl
      call chknam(dbgfl,40)
      write(*,*) ' debugging file = ',dbgfl

      read(lin,'(a40)',err=98) outfl
      call chknam(outfl,40)
      write(*,*) ' output file = ',outfl

      read(lin,*,err=98) nsim
      write(*,*) ' number of simulations = ',nsim

      read(lin,*,err=98) nx,xmn,xsiz
      write(*,*) ' X grid specification = ',nx,xmn,xsiz

      read(lin,*,err=98) ny,ymn,ysiz
      write(*,*) ' Y grid specification = ',ny,ymn,ysiz

      read(lin,*,err=98) nz,zmn,zsiz
      write(*,*) ' Z grid specification = ',nz,zmn,zsiz
      nxy  = nx*ny
      nxyz = nx*ny*nz
c
c Check grid size against static limit:
c
      if(nxyz.gt.MXYZ) then
            write(*,*) 'ERROR: nxyz=',nxyz,' exceeds MXYZ=',MXYZ
            write(*,*) '  Increase MXYZ in sisim.inc'
            stop
      endif
c
c (results allocation moved to sisim subroutine - allocatable not shared via include)
c
      read(lin,*,err=98) ixv(1)
      write(*,*) ' random number seed = ',ixv(1)
      do i=1,1000
             p = acorni(idum)
      end do

      read(lin,*,err=98) ndmax
      write(*,*) ' ndmax = ',ndmax

      read(lin,*,err=98) nodmax
      write(*,*) ' max prev sim nodes = ',nodmax

      read(lin,*,err=98) maxsec
      write(*,*) ' max soft indicator data = ',maxsec

      read(lin,*,err=98) sstrat
      write(*,*) ' search strategy = ',sstrat

      read(lin,*,err=98) mults,nmult
      write(*,*) ' multiple grid search flag = ',mults,nmult

      read(lin,*,err=98) noct
      write(*,*) ' max per octant = ',noct

      read(lin,*,err=98) radius,radius1,radius2
      write(*,*) ' search radii = ',radius,radius1,radius2
      if(radius.lt.EPSLON) stop 'radius must be greater than zero'
      radsqd = radius  * radius
      sanis1 = radius1 / radius
      sanis2 = radius2 / radius

      read(lin,*,err=98) sang1,sang2,sang3
      write(*,*) ' search anisotropy angles = ',sang1,sang2,sang3

      read(lin,*,err=98) mik,cutmik
      write(*,*) ' median IK switch = ',mik,cutmik

      read(lin,*,err=98) ktype
      write(*,*) ' kriging type switch = ',ktype

c
c Output now goes to debugging file:
c
      open(ldbg,file=dbgfl,status='UNKNOWN')
      do i=1,ncut
            read(lin,*,err=98) nst(i),c0(i)
            if(ivtype.eq.0)
     +      write(ldbg,100)  i,thres(i),cdf(i),nst(i),c0(i)
            if(ivtype.eq.1)
     +      write(ldbg,101)  i,thres(i),cdf(i),nst(i),c0(i)
            if(nst(i).gt.MAXNST) stop 'nst is too big'
            istart = 1 + (i-1)*MAXNST
            do j=1,nst(i)
                  index = istart + j - 1
                  read(lin,*,err=98) it(index),cc(index),ang1(index),
     +                               ang2(index),ang3(index)
                  if(it(index).eq.3) STOP 'Gaussian Model Not Allowed!'
                  read(lin,*,err=98) aa(index),aa1,aa2
                  write(ldbg,102)  j,it(index),aa(index),cc(index)
                  anis1(index) = aa1 / max(EPSLON,aa(index))
                  anis2(index) = aa2 / max(EPSLON,aa(index))
                  write(ldbg,103) ang1(index),ang2(index),ang3(index),
     +                            anis1(index),anis2(index)
            end do
      end do
      close(lin)
 100  format(/,' Category  number ',i2,' = ',f12.3,/,
     +         '           global prob value = ',f8.4,/,
     +         '           number of structures = ',i3,/,
     +         '           nugget effect        = ',f8.4)
 101  format(/,' Threshold number ',i2,' = ',f12.3,/,
     +         '           global prob value = ',f8.4,/,
     +         '           number of structures = ',i3,/,
     +         '           nugget effect        = ',f8.4)
 102  format(  '           type of structure ',i3,' = ',i3,/,
     +         '           aa parameter         = ',f12.4,/,
     +         '           cc parameter         = ',f12.4)
 103  format(  '           ang1, ang2, ang3     = ',3f6.2,/,
     +         '           anis1, anis2         = ',2f12.4)
c
c Check to make sure the data file exists, then either read in the
c data or write a warning:
c
      title = 'SISIM SIMULATIONS:                      '//
     +        '                                        '
      nd = 0
      inquire(file=datafl,exist=testfl)
      if(.not.testfl) then
            write(*,113) datafl
 113        format('WARNING data file ',a40,' does not exist!',/,
     +             ' Hope your intention was to create an',
     +             ' unconditional simulation.')
      else
c
c The data file exists so open the file and read in the header
c information.
c
            write(*,*) 'Reading input data'
            av = 0.0
            ss = 0.0
            open(lin,file=datafl,status='OLD')
            read(lin,'(a60)',err=99) title(21:80)
            read(lin,*,err=99)       nvari
            do i=1,nvari
                  read(lin,'()',err=99)
            end do
c
c Read all the data until the end of the file:
c
 5          read(lin,*,end=6,err=99) (var(j),j=1,nvari)
            vrt = var(ivrl)
            if(vrt.lt.tmin.or.vrt.ge.tmax) go to 5
            nd  = nd + 1
            if(nd.gt.MAXDAT) then
                  write(*,*) ' ERROR exceeded MAXDAT - check inc file'
                  stop
            end if
            x(nd) = xmn
            y(nd) = ymn
            z(nd) = zmn
            if(ixl.gt.0) x(nd) = var(ixl)
            if(iyl.gt.0) y(nd) = var(iyl)
            if(izl.gt.0) z(nd) = var(izl)
            av = av + vrt
            ss = ss + vrt*vrt
c
c The indicator data are constructed knowing the thresholds and the
c data value.
c
            if(ivtype.eq.0) then
                  do ic=1,ncut
                        vr(nd,ic) = 0.0
                        if(int(vrt+0.5).eq.int(thres(ic)+0.5))
     +                  vr(nd,ic) = 1.0
                  end do
            else
                  do ic=1,ncut
                        vr(nd,ic) = 1.0
                        if(vrt.gt.thres(ic)) vr(nd,ic) = 0.0
                  end do
            end if
            vr(nd,MXCUT) = vrt
            go to 5
 6          close(lin)
c
c Compute the averages and variances as an error check for the user:
c
            xd = max(real(nd),1.0)
            av = av / xd
            ss =(ss / xd ) - av * av
            write(*,120)    ivrl,nd,av,ss
            write(ldbg,120) ivrl,nd,av,ss
 120        format(/,'Data for SISIM: Variable number ',i2,
     +             /,'  Number of acceptable data  = ',i8,
     +             /,'  Equal Weighted Average     = ',f12.4,
     +             /,'  Equal Weighted Variance    = ',f12.4,/)
c
c Check to make sure that the grid is compatible with the data:
c
            if(ixl.le.0.and.nx.gt.1) then
               write(*,*) 'ERROR there is no X coordinate in data file'
               write(*,*) '      nx must be set to 1'
               stop
            end if
            if(iyl.le.0.and.ny.gt.1) then
               write(*,*) 'ERROR there is no Y coordinate in data file'
               write(*,*) '      ny must be set to 1'
               stop
            end if
            if(izl.le.0.and.nz.gt.1) then
               write(*,*) 'ERROR there is no Z coordinate in data file'
               write(*,*) '      nz must be set to 1'
               stop
            end if
      endif
c
c Now, if required, read in the tabulated values for details of the dist
c
      if(ltail.eq.3.or.middle.eq.3.or.utail.eq.3) then
            ng = 0
            inquire(file=tabfl,exist=testfl)
            if(.not.testfl) stop 'ERROR tabfl does not exist'
            open(lin,file=tabfl,status='OLD')
            read(lin,*,err=97)
            read(lin,*,err=97) nvari
            do i=1,nvari
                  read(lin,*,err=97)
            end do
            tcdf = 0.0
            ng   = 0
 21         read(lin,*,end=22,err=97) (var(j),j=1,nvari)
            if(var(itabvr).lt.tmin.or.var(itabvr).ge.tmax) go to 21
            ng = ng + 1
            if(ng.gt.MAXTAB) then
                  write(*,*) ' ERROR exceeded MAXTAB - check inc file'
                  stop
            end if
            gcut(ng) = var(itabvr)
            gcdf(ng) = 1.0
            if(itabwt.gt.0) gcdf(ng) = var(itabwt)
            tcdf = tcdf + gcdf(ng)
            go to 21
 22         close(lin)
c
c Sort in ascending order and keep track of where the tabulated values
c switch classes:
c
            if(tcdf.le.0.0) then
                  write(*,*) 'ERROR: either the weights are zero or'
                  write(*,*) '       there are no tabulated data.'
                  stop
            endif
            call sortem(1,ng,gcut,1,gcdf,c,d,e,f,g,h)
c
c Set up gcdf for tabulated quantiles:
c
            oldcp = 0.0
            cp    = 0.0
            tcdf  = 1.0 / tcdf
            do i=1,ng
                  cp      = cp + gcdf(i) * tcdf
                  gcdf(i) =(cp + oldcp) * 0.5
                  oldcp   = cp
            end do
      end if
c
c Direct input of indicator data:
c
      nhd = nd
      inquire(file=softfl,exist=testfl)
      if(testfl) then
            write(*,*)
            write(*,*) 'Reading soft indicator data'
            open(lin,file=softfl,status='OLD')
            read(lin,*,err=97)
            read(lin,*,err=97) nvari
            if(ivrs(ncut).gt.nvari) then
                  write(*,*) ' ERROR: too few variables in ',softfl
                  write(*,*) '        inconsistent with parameters'
                  stop
            end if
            do i=1,nvari
                  read(lin,*,err=97)
            end do
 12         read(lin,*,end=13,err=96) (var(j),j=1,nvari)
c
c Don't keep soft data co-located with hard data:
c
            xx = xmn
            yy = ymn
            zz = zmn
            if(ixs.gt.0) xx = var(ixs)
            if(iys.gt.0) yy = var(iys)
            if(izs.gt.0) zz = var(izs)
            do i=1,nhd
                  test = abs(xx-x(i)) + abs(yy-y(i)) + abs(zz-z(i))
                  if(test.le.EPSLON) go to 12
            end do
c
c Accept this data:
c
            nd = nd + 1
            if(nd.gt.MAXDAT) then
                  write(*,*) ' ERROR: Exceeded memory for data'
                  write(*,*) '        have ',MAXDAT,' available'
                  stop
            end if
            x(nd) = xx
            y(nd) = yy
            z(nd) = zz
            do j=1,ncut
                  i = ivrs(j)
                  vr(nd,j) = var(i)
                  ccdf(j)  = var(i)
            end do
c
c Draw a value for this soft distribution (in case the distribution is
c co-located with a grid node and Markov-Bayes is not used):
c
            cdfval = real(acorni(idum))
            call ordrel(ivtype,ncut,ccdf,ccdfo,nviol,aviol,xviol)
            zval = UNEST
            call beyond(ivtype,ncut,thres,ccdfo,ng,gcut,gcdf,zmin,zmax,
     +                  ltail,ltpar,middle,mpar,utail,utpar,zval,
     +                  cdfval,ierr)
            vr(nd,MXCUT) = zval
c
c If performing median IK then check for missing values:
c
            if(mik.eq.1) then
                  do ic=1,ncut
                        if(vr(nd,ic).lt.0.0) then
                              write(*,150) softfl
                              stop
                        endif
                  end do
 150              format(' Since the median IK approach is being',
     +                   ' considered no missing values are',
     +                   ' allowed',/,' Check file ',a40)
            endif
            go to 12
 13         close(lin)
      endif
c
c Load the right variogram as the first one if performing median IK:
c
      if(mik.eq.1) then
            icut = 1
            clos = abs(cutmik-thres(1))
            do ic=2,ncut
                  test = abs(cutmik-thres(ic))
                  if(test.lt.clos) then
                        icut = ic
                        clos = test
                  end if
            end do
            c0(1)   = c0(icut)
            nst(1)  = nst(icut)
            istart1 = 1
            istarti = 1 + (icut-1)*MAXNST
            do ist=1,nst(1)
                  index1        = istart1 + ist - 1
                  indexi        = istarti + ist - 1
                  it(index1)    = it(indexi)
                  aa(index1)    = aa(indexi)
                  cc(index1)    = cc(indexi)
                  ang1(index1)  = ang1(indexi)
                  ang2(index1)  = ang2(indexi)
                  ang3(index1)  = ang3(indexi)
                  anis1(index1) = anis1(indexi)
                  anis2(index1) = anis2(indexi)
            end do
      end if
c
c Initialize I/O buffer:
c
      nbuf = 0
c
c Open the output file and return:
c
      open(lout,file=outfl,status='UNKNOWN')
      write(lout,104) title
 104  format(a80,/,'1',/,'Simulated Value')
      return
c
c Error in an Input File Somewhere:
c
 96   stop 'ERROR in soft data file!'
 97   stop 'ERROR in table look up file!'
 98   stop 'ERROR in parameter file!'
 99   stop 'ERROR in data file!'
      end



      subroutine sisim
c-----------------------------------------------------------------------
c
c           Conditional Simulation of a 3-D Rectangular Grid
c           ************************************************
c
c This subroutine generates 3-D conditional simulations of a continuous
c variable with sequential indicator simulation.
c
c OPTIMIZED: Multi-RHS kriging, OpenMP realization loop, I/O buffering
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
      real      ntviol,atviol
      real*8    acorni,p
      integer   ixvsav(MAXOP1)
      integer   nviolr(MAXCUT,nsim)
      real      aviolr(MAXCUT,nsim),xviolr(MAXCUT,nsim)
c
c Allocate results array (must be here - allocatable not shared via include):
c
      allocate(results(nxyz,nsim),stat=ierr)
      if(ierr.ne.0) stop 'ERROR allocating results array'
c
c Set up the rotation/anisotropy matrices that are needed for the
c variogram and search:
c
      write(*,*) 'Setting up rotation matrices for variogram and search'
      do ic=1,ncut
      do is=1,nst(ic)
            ind = is + (ic-1)*MAXNST
            call setrot(ang1(ind),ang2(ind),ang3(ind),anis1(ind),
     +                  anis2(ind),ind,MAXROT,rotmat)
      end do
      end do
      isrot = MAXNST*MAXCUT + 1
      call setrot(sang1,sang2,sang3,sanis1,sanis2,isrot,MAXROT,rotmat)
c
c Set up for super block searching:
c
            do i=1,nd
                  actloc(i) = real(i)
            end do
      if(sstrat.eq.0) then
            write(*,*) 'Setting up super block search strategy'
            nsec = 0
            call setsupr(nx,xmn,xsiz,ny,ymn,ysiz,nz,zmn,zsiz,nd,x,y,z,
     +             actloc,tmp,nsec,sec1,sec2,sec3,MAXSBX,MAXSBY,MAXSBZ,
     +             nisb,nxsup,xmnsup,xsizsup,nysup,ymnsup,ysizsup,nzsup,
     +             zmnsup,zsizsup)
            call picksup(nxsup,xsizsup,nysup,ysizsup,nzsup,zsizsup,
     +             isrot,MAXROT,rotmat,radsqd,nsbtosr,ixsbtosr,
     +             iysbtosr,izsbtosr)
      end if
c
c Set up the covariance table and the spiral search:
c
      call ctable
c
c Save the master RNG state for deterministic per-thread seeding:
c
      do i=1,MAXOP1
            ixvsav(i) = ixv(i)
      end do
c
c Initialize per-realization violation accumulators:
c
      do isim=1,nsim
            do icut=1,ncut
                  nviolr(icut,isim) = 0
                  aviolr(icut,isim) = 0.0
                  xviolr(icut,isim) = -1.0
            end do
      end do
c
c =====================================================================
c MAIN LOOP OVER ALL THE SIMULATIONS (OpenMP parallel):
c =====================================================================
c
!$OMP PARALLEL DO SCHEDULE(DYNAMIC,1)
!$OMP+PRIVATE(isim,ind,in,imult,nnx,nny,nnz,jx,jy,jz,
!$OMP+        ix,iy,iz,id,id2,index,index2,ind2,xx,yy,zz,
!$OMP+        test,test2,testind,TINY,irepo,ntviol,atviol,
!$OMP+        icut,ic,is,zval,cdfval,ierr,nxysim,p,i,j,k)
      do isim=1,nsim
c
c Initialize per-thread RNG with deterministic seed based on realization:
c
            ixv(1) = ixvsav(1) + (isim-1) * 131071
            do i=2,MAXOP1
                  ixv(i) = 0
            end do
            do i=1,1000
                  p = acorni(idum)
            end do
c
c Work out a random path for this realization:
c
            do ind=1,nxyz
                  sim(ind)   = real(acorni(idum))
                  order(ind) = ind
            end do
c
c The multiple grid search works with multiples of 4:
c
            if(mults.eq.1) then
                  do imult=1,nmult
                        nnz = max(1,nz/(imult*4))
                        nny = max(1,ny/(imult*4))
                        nnx = max(1,nx/(imult*4))
                        jz  = 1
                        jy  = 1
                        jx  = 1
                        do iz=1,nnz
                           if(nnz.gt.1) jz = iz*imult*4
                           do iy=1,nny
                              if(nny.gt.1) jy = iy*imult*4
                              do ix=1,nnx
                                 if(nnx.gt.1) jx = ix*imult*4
                                 index = jx + (jy-1)*nx + (jz-1)*nxy
                                 sim(index) = sim(index) - imult
                              end do
                           end do
                        end do
                  end do
            end if
            call sortem(1,nxyz,sim,1,order,c,d,e,f,g,h)
c
c Initialize the simulation:
c
            do i=1,nxyz
                  sim(i) = UNEST
                  tmp(i) = 0.0
            end do
!$OMP CRITICAL(progress)
            write(*,*)
            write(*,*) ' Working on realization number: ',isim
!$OMP END CRITICAL(progress)
c
c Assign the data to the closest grid node:
c
            TINY = 0.0001
            do id=1,nd
                  call getindx(nx,xmn,xsiz,x(id),ix,testind)
                  call getindx(ny,ymn,ysiz,y(id),iy,testind)
                  call getindx(nz,zmn,zsiz,z(id),iz,testind)
                  ind  = ix + (iy-1)*nx + (iz-1)*nxy
                  xx   = xmn + real(ix-1)*xsiz
                  yy   = ymn + real(iy-1)*ysiz
                  zz   = zmn + real(iz-1)*zsiz
                  test = abs(xx-x(id)) + abs(yy-y(id)) + abs(zz-z(id))
c
c Assign this data to the node (unless there is a closer data):
c
                  atnode(id) = .false.
                  if(sstrat.eq.1)                  atnode(id) = .true.
                  if(sstrat.eq.0.and.test.le.TINY) atnode(id) = .true.
                  if(atnode(id)) then
                        if(sim(ind).ge.0.0) then
                              id2 = int(sim(ind)+0.5)
                              index=int(actloc(id)+0.5)
                              index2=int(actloc(id2)+0.5)
                              if((index.le.nhd.and.index2.le.nhd).or.
     +                            (index.gt.nhd.and.index2.gt.nhd)) then
                              test2 = abs(xx-x(id2)) + abs(yy-y(id2))
     +                                               + abs(zz-z(id2))
                              if(test.le.test2) sim(ind) = real(id)
                            else if(index.le.nhd.and.index2.gt.nhd) then
                                 sim(ind) = real(id)
                              endif
                        else
                              sim(ind) = real(id)
                        end if
                  end if
            end do
c
c Now, enter the hard data values into the "sim" array and keep the
c data number in the "tmp" array (to be reset when a hard value
c is assigned to that node):
c
            do i=1,nxyz
                  id = int(sim(i)+0.5)
                  if(id.gt.0) then
                     ind=int(actloc(id)+0.5)
                        if(ind.le.nhd) then
                              sim(i) = vr(ind,MXCUT)
                        else
                              tmp(i) = sim(i)
                              sim(i) = UNEST
                        end if
                  end if
            end do
c
c Reset violation counters for this realization:
c
            nclose = 0
            irepo  = max(1,min((nxyz/10),10000))
            ntviol = 0.0
            atviol = 0.0
            do icut=1,ncut
                  nviol(icut) =  0
                  aviol(icut) =  0.0
                  xviol(icut) = -1.0
            end do
c
c MAIN LOOP OVER ALL THE NODES:
c
            do in=1,nxyz
                  if((int(in/irepo)*irepo).eq.in) then
!$OMP CRITICAL(progress)
                        write(*,104) in,isim
 104                    format('   node ',i9,' sim ',i4)
!$OMP END CRITICAL(progress)
                  end if
                  index = int(order(in)+0.5)
c
c Do we really need to simulate this grid node location?
c
                  if(sim(index).ne.UNEST) go to 20
                  if(imbsim.eq.0.and.tmp(index).ne.0.0) then
                        id = int(tmp(index)+0.5)
                        ind=int(actloc(id)+0.5)
                        sim(index) = vr(ind,MXCUT)
                        go to 20
                  end if
c
c Location of the node we are currently working on:
c
                  iz = int((index-1)/nxy) + 1
                  iy = int((index-(iz-1)*nxy-1)/nx) + 1
                  ix = index - (iz-1)*nxy - (iy-1)*nx
                  xx = xmn + real(ix-1)*xsiz
                  yy = ymn + real(iy-1)*ysiz
                  zz = zmn + real(iz-1)*zsiz
c
c Now, we'll simulate the point ix,iy,iz.  First, get the close data
c and make sure that there are enough to actually simulate a value,
c we'll only keep the closest "ndmax" data, and look for previously
c simulated grid nodes:
c
                  if(sstrat.eq.0) then
                        call srchsuprsisim(xx,yy,zz,radsqd,isrot,
     +                       MAXROT,
     +                       rotmat,nsbtosr,ixsbtosr,iysbtosr,
     +                       izsbtosr,noct,nd,x,y,z,tmpdat,nisb,nxsup,
     +                       xmnsup,xsizsup,nysup,ymnsup,ysizsup,
     +                       nzsup,zmnsup,zsizsup,nclose,close,
     +                       infoct,maxsec,nhd,actloc)
                        if(nclose.gt.ndmax) nclose = ndmax
                  endif
                  call srchnd(ix,iy,iz)
c
c What cdf value are we looking for?
c
                  zval   = UNEST
                  cdfval = real(acorni(idum))
c
c Use the global distribution?
c
                  if((nclose+ncnode).le.0) then
                        call beyond(ivtype,ncut,thres,cdf,ng,gcut,gcdf,
     +                              zmin,zmax,ltail,ltpar,middle,mpar,
     +                              utail,utpar,zval,cdfval,ierr)
                  else
c
c Estimate the local distribution by indicator kriging:
c
                        call krigeall(ix,iy,iz,xx,yy,zz)
c
c Correct order relations:
c
                        call ordrel(ivtype,ncut,ccdf,ccdfo,nviol,aviol,
     +                              xviol)
c
c Draw from the local distribution:
c
                        call beyond(ivtype,ncut,thres,ccdfo,ng,gcut,
     +                              gcdf,zmin,zmax,ltail,ltpar,middle,
     +                              mpar,utail,utpar,zval,cdfval,ierr)
                  endif
                  sim(index) = zval
c
c END MAIN LOOP OVER NODES:
c
 20         continue
            tmp(index) = 0.0
            end do
c
c Store results for this realization and violation stats:
c
            do ind=1,nxyz
                  results(ind,isim) = sim(ind)
            end do
            do icut=1,ncut
                  nviolr(icut,isim) = nviol(icut)
                  aviolr(icut,isim) = aviol(icut)
                  xviolr(icut,isim) = xviol(icut)
            end do
c
c END PARALLEL LOOP OVER SIMULATIONS:
c
      end do
!$OMP END PARALLEL DO
c
c =====================================================================
c Sequential output: write all realizations in order
c =====================================================================
c
      nbuf = 0
      do isim=1,nsim
c
c Write this simulation to the output file (buffered):
c
            nxysim = 0
            do ic=1,ncut
                  ccdf(ic) = 0.0
            end do
            do ind=1,nxyz
                  call bufwrite(lout,results(ind,isim))
c
c Calculate the cdf of the simulated values (for error checking):
c
                  if(results(ind,isim).gt.UNEST) then
                        nxysim = nxysim + 1
                        do ic=1,ncut
                              if(ivtype.eq.0) then
                                    if(results(ind,isim).eq.thres(ic))
     +                                ccdf(ic)=ccdf(ic)+1.
                              else
                                    if(results(ind,isim).le.thres(ic))
     +                                ccdf(ic)=ccdf(ic)+1.
                              end if
                        end do
                  endif
            end do
c
c Flush any remaining buffer:
c
            call flushbuf(lout)
c
c Report on the reproduction of the cdf and order relations violations:
c
            write(*,203)    isim
            write(ldbg,203) isim
            do icut=1,ncut
                  ccdf(icut) = ccdf(icut) / max(real(nxysim),1.0)
                  write(*,204)    icut,cdf(icut),ccdf(icut)
                  write(ldbg,204) icut,cdf(icut),ccdf(icut)
            end do
 203        format(/,' Finished simulation ',i2)
 204        format('     threshold ',i3,' input cdf = ',f6.4,
     +                 ' realization cdf = ',f6.4)
            write(*,   300)
            write(ldbg,300)
 300        format(/,' Summary of order relations: ')
            ntot = 0
            atot = 0.0
            do icut=1,ncut
               ntot = ntot + nviolr(icut,isim)
               atot = atot + aviolr(icut,isim)
               aviolr(icut,isim) = aviolr(icut,isim)
     +              / real(max(1,nviolr(icut,isim)))
               write(*,302)    icut,nviolr(icut,isim),
     +                         aviolr(icut,isim),xviolr(icut,isim)
               write(ldbg,302) icut,nviolr(icut,isim),
     +                         aviolr(icut,isim),xviolr(icut,isim)
 302           format('     threshold',i2,' number = ',i6,
     +                ' average = ',f8.4,' maximum = ',f8.4)
            end do
            atot = atot / real(max(1,ntot))
            btot =(ntot / real(ncut*max(nxysim,1))) * 100.0
            write(ldbg,303) btot,atot
            write(*,   303) btot,atot
 303        format(/,' total of ',f18.6,'% with average of ',f8.4)
c
c END SEQUENTIAL OUTPUT LOOP:
c
      end do
c
c Free results array:
c
      deallocate(results)
c
c Return to the main program:
c
      return
      end



      subroutine ctable
c-----------------------------------------------------------------------
c
c               Establish the Covariance Look up Table
c               **************************************
c
c The idea is to establish a 3-D network that contains the covariance
c value for a range of grid node offsets that should be at as large
c as twice the search radius in each direction.  The reason it has to
c be twice as large as the search radius is because we want to use it
c to compute the data covariance matrix as well as the data-block
c covariance matrix.
c
c Secondly, we want to establish a search for nearby nodes that
c in order of closeness as defined by the variogram.
c
c-----------------------------------------------------------------------
      parameter(TINY=1.0e-10)
      include  'sisim.inc'
      real*8    sqdist,hsqd
c
c Size of the look-up table:
c
      nctx = min(((MAXCTX-1)/2),(nx-1))
      ncty = min(((MAXCTY-1)/2),(ny-1))
      nctz = min(((MAXCTZ-1)/2),(nz-1))
c
c Initialize the covariance subroutine and cbb at the same time:
c
      call cova3(0.,0.,0.,0.,0.,0.,1,nst,MAXNST,c0,it,cc,aa,1,
     +           MAXROT,rotmat,cmax,cbb)
c
c Now, set up the table and keep track of the node offsets that are
c within the search radius:
c
      ilooku = max((ncut/2),1)
      nlooku = 0
      do icut=1,ncut
      irot = 1 + (icut-1)*MAXNST
      do i=-nctx,nctx
      xx = i * xsiz
      ic = nctx + 1 + i
      do j=-ncty,ncty
      yy = j * ysiz
      jc = ncty + 1 + j
      do k=-nctz,nctz
      zz = k * zsiz
      kc = nctz + 1 + k
            call cova3(0.,0.,0.,xx,yy,zz,icut,nst,MAXNST,c0,it,cc,aa,
     +                 irot,MAXROT,rotmat,cmax,cov)
            covtab(ic,jc,kc,icut) = cov
            if(icut.eq.ilooku) then
               hsqd = sqdist(0.0,0.0,0.0,xx,yy,zz,isrot,MAXROT,rotmat)
               if(real(hsqd).le.radsqd) then
                  nlooku = nlooku + 1
c
c We subtract the covariance from a large value so that the ascending
c sort subroutine will accomplish the sort we want.  Furthermore, a
c fraction of the distance is also taken off so that we search by
c anisotropic distance once we are beyond the range:
c
                  tmp(nlooku)   =-(covtab(ic,jc,kc,icut)-TINY*hsqd)
                  order(nlooku) =real((kc-1)*MAXCXY+(jc-1)*MAXCTX+ic)
               endif
            endif
      end do
      end do
      end do
      end do
c
c Finished setting up the look-up table, now order the nodes such
c that the closest ones, according to variogram distance, are searched
c first. Note: the "loc" array is used because I didn't want to make
c special allowance for 2 byte integers in the sorting subroutine:
c
      call sortem(1,nlooku,tmp,1,order,c,d,e,f,g,h)
      do il=1,nlooku
            loc = int(order(il))
            iz  = int((loc-1)/MAXCXY) + 1
            iy  = int((loc-(iz-1)*MAXCXY-1)/MAXCTX) + 1
            ix  = loc-(iz-1)*MAXCXY - (iy-1)*MAXCTX
            iznode(il) = iz
            iynode(il) = iy
            ixnode(il) = ix
      end do
      if(nodmax.gt.MAXNOD) then
            write(ldbg,*)
            write(ldbg,*) 'The maximum number of close nodes = ',nodmax
            write(ldbg,*) 'this was reset from your specification due '
            write(ldbg,*) 'to storage limitations.'
            nodmax = MAXNOD
      endif
c
c Debugging output if requested:
c
      if(idbg.le.2) return
      write(ldbg,*)
      write(ldbg,*) 'There are ',nlooku,' nearby nodes that will be '
      write(ldbg,*) 'checked until enough close data are found.'
      write(ldbg,*)
      if(idbg.lt.4) return
      do i=1,nlooku
            xx = (ixnode(i) - nctx - 1) * xsiz
            yy = (iynode(i) - ncty - 1) * ysiz
            zz = (iznode(i) - nctz - 1) * zsiz
            write(ldbg,100) i,xx,yy,zz
      end do
 100  format('Point ',i6,' at ',3f18.6)
c
c All finished:
c
      return
      end



      subroutine srchnd(ix,iy,iz)
c-----------------------------------------------------------------------
c
c               Search for nearby Simulated Grid nodes
c               **************************************
c
c The idea is to spiral away from the node being simulated and note all
c the nearby nodes that have been simulated.
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
c
c Consider all the nearby nodes until enough have been found:
c
      ncnode = 0
      ncsec  = 0
      do il=1,nlooku
            if(ncnode.eq.nodmax) return
            i = ix + (int(ixnode(il))-nctx-1)
            if(i.lt.1.or.i.gt.nx) go to 1
            j = iy + (int(iynode(il))-ncty-1)
            if(j.lt.1.or.j.gt.ny) go to 1
            k = iz + (int(iznode(il))-nctz-1)
            if(k.lt.1.or.k.gt.nz) go to 1
c
c Check this potentially informed grid node:
c
            index = (k-1)*nx*ny + (j-1)*nx + i
            if(sim(index).gt.UNEST.or.tmp(index).gt.0.5) then
                  if(sim(index).le.UNEST.and.tmp(index).gt.0.5) then
                        ncsec  = ncsec + 1
                        if(ncsec.gt.maxsec) go to 1
                  end if
                  ncnode         = ncnode + 1
                  icnode(ncnode) = il
                  cnodex(ncnode) = xmn + real(i-1)*xsiz
                  cnodey(ncnode) = ymn + real(j-1)*ysiz
                  cnodez(ncnode) = zmn + real(k-1)*zsiz
                  cnodev(ncnode) = sim(index)
                  cnodet(ncnode) = tmp(index)
            endif
 1          continue
      end do
c
c Return to calling program:
c
      return
      end



      subroutine krigeall(ix,iy,iz,xx,yy,zz)
c-----------------------------------------------------------------------
c
c        Multi-RHS Indicator Kriging for All Thresholds
c        **********************************************
c
c For mik=1 (median IK): builds the LHS kriging matrix ONCE, factors
c it, then solves for each threshold using different RHS vectors via
c back-substitution. This eliminates redundant O(n^3) factorizations.
c
c For mik=0 (full IK): each threshold has its own variogram, so the
c LHS differs. We krige each threshold separately but efficiently
c by caching the data neighborhood structure.
c
c OUTPUT: ccdf(1..ncut) filled with kriged indicator estimates
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
      integer   aclose(MAXKR1)
      logical   somesoft,bothsoft
c
c Multi-RHS arrays for storing per-threshold RHS and solutions:
c
      real*8    afact(MAXKR2)
      real*8    rhsall(MAXKR1,MAXCUT)
      real*8    rrall(MAXKR1,MAXCUT)
      real      vraall(MAXKR1,MAXCUT)
c
c ===================================================================
c For mik=1: build LHS once using icut=1 variogram, solve all RHS
c ===================================================================
c
      if(mik.eq.1) then
c
c Build data neighborhood for icut=1 (all thresholds share same
c neighborhood in median IK since no missing values allowed):
c
            mclose = 0
            do i=1,nclose
                  index     =  int(close(i))
                  ind=int(actloc(index)+0.5)
                  if(.not.atnode(index).and.vr(ind,1).ge.0.0) then
                        mclose = mclose + 1
                        aclose(mclose) = index
                  endif
            end do
            na  = mclose + ncnode
            neq = na + ktype
            if(neq.le.0) then
                  do ic=1,ncut
                        ccdf(ic) = cdf(ic)
                  end do
                  return
            endif
c
c Build LHS matrix using icut=1 variogram (irot=1 for mik):
c
            irot = 1
            somesoft = .false.
            in = 0
            do j=1,na
                  softdat(j) = .false.
                  if(j.le.mclose) then
                        index  = aclose(j)
                        ind=int(actloc(index)+0.5)
                        x1     = x(index)
                        y1     = y(index)
                        z1     = z(index)
                        if(ind.gt.nhd) softdat(j) = .true.
                  else
                        index  = j-mclose
                        x1     = cnodex(index)
                        y1     = cnodey(index)
                        z1     = cnodez(index)
                        if(cnodet(index).gt.0.5) then
                              softdat(j) = .true.
                        end if
                        ind    = icnode(index)
                        ix1    = ix + (int(ixnode(ind))-nctx-1)
                        iy1    = iy + (int(iynode(ind))-ncty-1)
                        iz1    = iz + (int(iznode(ind))-nctz-1)
                  endif
c
c Build LHS row/column for point j:
c
                  do i=1,j
                        if(i.le.mclose) then
                              index  = aclose(i)
                              x2     = x(index)
                              y2     = y(index)
                              z2     = z(index)
                        else
                              index  = i-mclose
                              x2     = cnodex(index)
                              y2     = cnodey(index)
                              z2     = cnodez(index)
                              ind    = icnode(index)
                              ix2    = ix+(int(ixnode(ind))-nctx-1)
                              iy2    = iy+(int(iynode(ind))-ncty-1)
                              iz2    = iz+(int(iznode(ind))-nctz-1)
                        endif
                        in = in + 1
                        if(j.le.mclose.or.i.le.mclose) then
                              call cova3(x1,y1,z1,x2,y2,z2,1,nst,
     +                             MAXNST,c0,it,cc,aa,irot,MAXROT,
     +                             rotmat,cmax,cov)
                              afact(in) = dble(cov)
                        else
                              ii = nctx+1+(ix1-ix2)
                              jj = ncty+1+(iy1-iy2)
                              kk = nctz+1+(iz1-iz2)
                              if(ii.lt.1.or.ii.gt.MAXCTX.or.
     +                           jj.lt.1.or.jj.gt.MAXCTY.or.
     +                           kk.lt.1.or.kk.gt.MAXCTZ) then
                                    call cova3(x1,y1,z1,x2,y2,z2,1,
     +                                   nst,MAXNST,c0,it,cc,aa,irot,
     +                                   MAXROT,rotmat,cmax,cov)
                                    afact(in) = dble(cov)
                              else
                                    afact(in) = dble(covtab(ii,jj,kk,
     +                                   1))
                              endif
                        endif
                  end do
c
c Build RHS using icut=1 covariance for location:
c
                  if(j.le.mclose) then
                        index = aclose(j)
                        call cova3(xx,yy,zz,x(index),y(index),
     +                       z(index),1,nst,MAXNST,c0,it,cc,aa,
     +                       irot,MAXROT,rotmat,cmax,cov)
                        r(j) = dble(cov)
                  else
                        ii = nctx+1+(ix-ix1)
                        jj = ncty+1+(iy-iy1)
                        kk = nctz+1+(iz-iz1)
                        if(ii.lt.1.or.ii.gt.MAXCTX.or.
     +                     jj.lt.1.or.jj.gt.MAXCTY.or.
     +                     kk.lt.1.or.kk.gt.MAXCTZ) then
                              call cova3(xx,yy,zz,x1,y1,z1,1,nst,
     +                             MAXNST,c0,it,cc,aa,irot,MAXROT,
     +                             rotmat,cmax,cov)
                              r(j) = dble(cov)
                        else
                              r(j) = dble(covtab(ii,jj,kk,1))
                        endif
                  endif
                  rr(j) = r(j)
                  if(softdat(j)) somesoft = .true.
            end do
c
c Apply Markov-Bayes corrections to LHS if needed:
c
            if(imbsim.eq.1.and.somesoft) then
                  in = 0
                  do j=1,na
                        do i=1,j
                              in = in + 1
                              bothsoft = .false.
                              if(softdat(j).and.softdat(i))
     +                             bothsoft = .true.
                              if(bothsoft) then
                                    afact(in) = afact(in)*
     +                                   dble(beez(1))
                                    if(i.ne.j) afact(in) = afact(in)*
     +                                   dble(beez(1))
                              else
                                    if(softdat(j).or.softdat(i))
     +                              afact(in) = afact(in)*dble(beez(1))
                              end if
                        end do
                        if(softdat(j)) then
                              r(j)  = r(j)*dble(beez(1))
                              rr(j) = r(j)
                        end if
                  end do
            end if
c
c Add OK constraint if needed:
c
            if(ktype.eq.1) then
                  do i=1,na
                        in    = in + 1
                        afact(in) = 1.0d0
                  end do
                  in      = in + 1
                  afact(in) = 0.0d0
                  r(neq)  = 1.0d0
                  rr(neq) = 1.0d0
            endif
c
c Factor the matrix ONCE (solve with first RHS):
c
            if(neq.eq.1.and.ktype.eq.0) then
                  s(1)  = r(1) / afact(1)
                  ising = 0
            else
                  call ksol(1,neq,1,afact,r,s,ising)
            endif
c
            if(ising.ne.0) then
                  do ic=1,ncut
                        ccdf(ic) = cdf(ic)
                  end do
                  return
            endif
c
c Now assemble RHS data for ALL thresholds and compute estimates.
c The weights s() are the same for all thresholds in mik=1 mode.
c We just need to gather the indicator data values per threshold.
c
            do ic=1,ncut
                  cmean = 0.0
                  sumwt = 0.0
                  do j=1,na
                        if(j.le.mclose) then
                              index = aclose(j)
                              ind=int(actloc(index)+0.5)
                              vraic = vr(ind,ic)
                        else
                              index = j-mclose
                              if(cnodet(index).le.0.5) then
                                    if(ivtype.eq.0) then
                                       vraic = 0.0
                                       if(int(cnodev(index)+0.5).eq.
     +                                    int(thres(ic)+0.5))
     +                                    vraic = 1.0
                                    else
                                       vraic = 1.0
                                       if(cnodev(index).gt.thres(ic))
     +                                    vraic = 0.0
                                    end if
                              else
                                    iii   = int(cnodet(index)+0.5)
                                    ind=int(actloc(iii)+0.5)
                                    vraic = vr(ind,ic)
                              end if
                        endif
                        cmean = cmean + real(s(j)) * vraic
                        sumwt = sumwt + real(s(j))
                  end do
                  if(ktype.eq.0) cmean = cmean+(1.0-sumwt)*cdf(ic)
                  ccdf(ic) = cmean
            end do
c
c ===================================================================
c For mik=0 (full IK): each threshold has its own variogram
c ===================================================================
c
      else
c
c Call per-threshold krige for each cutoff:
c
            do ic=1,ncut
                  call krige(ix,iy,iz,xx,yy,zz,ic,cdf(ic),ccdf(ic))
            end do
      endif
c
      return
      end



      subroutine krige(ix,iy,iz,xx,yy,zz,icut,gmean,cmean)
c-----------------------------------------------------------------------
c
c            Builds and Solves the SK or OK Kriging System
c            *********************************************
c
c INPUT VARIABLES:
c
c   ix,iy,iz        index of the point currently being simulated
c   xx,yy,zz        location of the point currently being simulated
c   icut            cutoff number to use for either the covariance look
c                     up table or the covariance calculation
c
c OUTPUT VARIABLES:
c
c   cmean           kriged estimate
c
c EXTERNAL REFERENCES: ksol   Gaussian elimination system solution
c
c NOTE: 1. the array "aclose" is used to flag those samples which exist
c          at the cutoff currently being kriged.
c
c-----------------------------------------------------------------------
      include 'sisim.inc'
      integer aclose(MAXKR1)
      logical krig,somesoft,bothsoft
c
c Size of the kriging system:
c
      somesoft = .false.
      krig     = .true.
      if(mik.eq.1.and.icut.gt.1) krig = .false.
      if(krig) then
            mclose = 0
            do i=1,nclose
                  index     =  int(close(i))
                  ind=int(actloc(index)+0.5)
                  if(.not.atnode(index).and.vr(ind,icut).ge.0.0) then
                        mclose = mclose + 1
                        aclose(mclose) = index
                  endif
            end do
            na  = mclose + ncnode
            neq = na + ktype
      endif
c
c There are no data yet:
c
      irot   = 1 + (icut-1)*MAXNST
c
c Set up kriging matrices:
c
      in = 0
      j1 = 0
      do 1 j=1,na
            softdat(j) = .false.
c
c Sort out the actual location of point "j"
c
            if(j.le.mclose) then
                  index  = aclose(j)
                  ind=int(actloc(index)+0.5)
                  vra(j) = vr(ind,icut)
                  x1     = x(index)
                  y1     = y(index)
                  z1     = z(index)
                  if(ind.gt.nhd) softdat(j) = .true.
            else
c
c It is a previously simulated node (keep index for table look-up):
c
                  index  = j-mclose
                  x1     = cnodex(index)
                  y1     = cnodey(index)
                  z1     = cnodez(index)
c
c Is this node informed by a hard datum or a soft datum?
c
                  if(cnodet(index).le.0.5) then
                        if(ivtype.eq.0) then
                           vra(j) = 0.0
                           if(int(cnodev(index)+0.5).eq.
     +                        int(thres(icut)+0.5)) vra(j) = 1.0
                        else
                           vra(j) = 1.0
                           if(cnodev(index).gt.thres(icut)) vra(j)=0.0
                        end if
                  else
                        iii    = int(cnodet(index)+0.5)
                        ind=int(actloc(iii)+0.5)
                        vra(j) = vr(ind,icut)
                        softdat(j) = .true.
                  end if
                  ind    = icnode(index)
                  ix1    = ix + (int(ixnode(ind))-nctx-1)
                  iy1    = iy + (int(iynode(ind))-ncty-1)
                  iz1    = iz + (int(iznode(ind))-nctz-1)
            endif
c
c Only set up the matrix and the RHS if kriging:
c
            if(krig) then
               do 2 i=1,j
c
c Sort out the actual location of point "i"
c
                  if(i.le.mclose) then
                        index  = aclose(i)
                        x2     = x(index)
                        y2     = y(index)
                        z2     = z(index)
                  else
c
c It is a previously simulated node (keep index for table look-up):
c
                        index  = i-mclose
                        x2     = cnodex(index)
                        y2     = cnodey(index)
                        z2     = cnodez(index)
                        ind    = icnode(index)
                        ix2    = ix + (int(ixnode(ind))-nctx-1)
                        iy2    = iy + (int(iynode(ind))-ncty-1)
                        iz2    = iz + (int(iznode(ind))-nctz-1)
                  endif
c
c Now, get the covariance value:
c
                  in = in + 1
c
c Decide whether or not to use the covariance look-up table:
c
                  if(j.le.mclose.or.i.le.mclose) then
                        call cova3(x1,y1,z1,x2,y2,z2,icut,nst,MAXNST,
     +                       c0,it,cc,aa,irot,MAXROT,rotmat,cmax,cov)
                        a(in) = dble(cov)
                  else
c
c Try to use the covariance look-up (if the distance is in range):
c
                        ii = nctx + 1 + (ix1 - ix2)
                        jj = ncty + 1 + (iy1 - iy2)
                        kk = nctz + 1 + (iz1 - iz2)
                        if(ii.lt.1.or.ii.gt.MAXCTX.or.
     +                     jj.lt.1.or.jj.gt.MAXCTY.or.
     +                     kk.lt.1.or.kk.gt.MAXCTZ) then
                              call cova3(x1,y1,z1,x2,y2,z2,icut,nst,
     +                                   MAXNST,c0,it,cc,aa,irot,
     +                                   MAXROT,rotmat,cmax,cov)
                              a(in) = dble(cov)
                        else
                              a(in) = dble(covtab(ii,jj,kk,icut))
                        endif
                  endif
 2          continue
c
c Get the RHS value (possibly with covariance look-up table):
c
            if(j.le.mclose) then
                  call cova3(xx,yy,zz,x1,y1,z1,icut,nst,MAXNST,
     +                       c0,it,cc,aa,irot,MAXROT,rotmat,cmax,cov)
                  r(j) = dble(cov)
            else
c
c Try to use the covariance look-up (if the distance is in range):
c
                  ii = nctx + 1 + (ix - ix1)
                  jj = ncty + 1 + (iy - iy1)
                  kk = nctz + 1 + (iz - iz1)
                  if(ii.lt.1.or.ii.gt.MAXCTX.or.
     +               jj.lt.1.or.jj.gt.MAXCTY.or.
     +               kk.lt.1.or.kk.gt.MAXCTZ) then
                        call cova3(xx,yy,zz,x1,y1,z1,icut,nst,MAXNST,
     +                       c0,it,cc,aa,irot,MAXROT,rotmat,cmax,cov)
                        r(j) = dble(cov)
                  else
                        r(j) = dble(covtab(ii,jj,kk,icut))
                  endif
            endif
            rr(j) = r(j)
c
c End ``if'' block (true if kriging)
c
         endif
c
c End loop over all of the nearby data
c
      if(softdat(j)) somesoft = .true.
 1    continue
c
c If we are doing Markov-Bayes are there are soft data we need to
c correct some of the covariance values in the kriging matrix:
c
      if(imbsim.eq.1.and.somesoft) then
            in = 0
            do j=1,na
                  do i=1,j
                        in = in + 1
                        bothsoft = .false.
                        if(softdat(j).and.softdat(i)) bothsoft = .true.
c
c Correct for soft-soft covariance or soft-hard covariance:
c
                        if(bothsoft) then
                              a(in) = a(in)*dble(beez(icut))
                              if(i.ne.j) a(in) = a(in)*dble(beez(icut))
                        else
                              if(softdat(j).or.softdat(i))
     +                        a(in) = a(in)*dble(beez(icut))
                        end if
                  end do
c
c Correct the right hand side for soft-hard covariance:
c
                  if(softdat(j)) then
                        r(j)  = r(j)*dble(beez(icut))
                        rr(j) = r(j)
                  end if
            end do
      end if
c
c Addition of OK constraint:
c
      if(krig.and.ktype.eq.1) then
            do i=1,na
                  in    = in + 1
                  a(in) = 1.0
            end do
            in      = in + 1
            a(in)   = 0.0
            r(neq)  = 1.0
            rr(neq) = 1.0
      endif
c
c Write out the kriging Matrix if Seriously Debugging:
c
      if(krig.and.idbg.ge.4) then
            write(ldbg,101) ix,iy,iz
            is = 1
            do i=1,neq
                  ie = is + i - 1
                  write(ldbg,102) i,r(i),(a(j),j=is,ie)
                  is = is + i
            end do
 101        format(/,'Kriging Matrices for Node: ',3i4,
     +               ' RHS first')
 102        format('    r(',i2,') =',f7.4,'  a= ',9(10f7.4))
      endif
c
c Solve the Kriging System:
c
      if(krig) then
            if(neq.eq.1.and.ktype.eq.0) then
                  s(1)  = r(1) / a(1)
                  ising = 0
            else
                  call ksol(1,neq,1,a,r,s,ising)
            endif
      endif
c
c Write a warning if the matrix is singular:
c
      if(ising.ne.0) then
            if(idbg.ge.1) then
                  write(ldbg,*) 'WARNING SISIM: singular matrix'
                  write(ldbg,*) '              for block',ix,iy,iz
            endif
            cmean  = 0.0
            return
      endif
c
c Write out the kriging Matrix if Seriously Debugging:
c
      if(krig.and.idbg.ge.4) then
            do i=1,na
                  write(ldbg,140) i,s(i)
            end do
 140        format(' Kriging weight for data: ',i4,' = ',f8.4)
      endif
c
c Compute the estimate, the sum of weights, correct for SK, and return:
c
      cmean = 0.0
      sumwt = 0.0
      do i=1,na
            cmean = cmean + real(s(i)) * vra(i)
            sumwt = sumwt + real(s(i))
      end do
      if(ktype.eq.0) cmean = cmean + (1.0-sumwt)*gmean
      return
      end



      subroutine bufwrite(lunit,val)
c-----------------------------------------------------------------------
c
c           Buffered Write for I/O Optimization
c           ************************************
c
c Accumulates output values into a buffer and writes them in batch
c to reduce I/O system call overhead.
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
c
      nbuf = nbuf + 1
      write(outbuf(nbuf),'(f8.4)') val
      if(nbuf.ge.MAXBUF) then
            do ib=1,nbuf
                  write(lunit,'(a)') outbuf(ib)(1:8)
            end do
            nbuf = 0
      endif
      return
      end



      subroutine flushbuf(lunit)
c-----------------------------------------------------------------------
c
c           Flush remaining buffered output
c           *******************************
c
c-----------------------------------------------------------------------
      include  'sisim.inc'
c
      if(nbuf.gt.0) then
            do ib=1,nbuf
                  write(lunit,'(a)') outbuf(ib)(1:8)
            end do
            nbuf = 0
      endif
      return
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
      open(lun,file='sisim.par',status='UNKNOWN')
      write(lun,10)
 10   format('                  Parameters for SISIM',/,
     +       '                  ********************',/,/,
     +       'START OF PARAMETERS:')

      write(lun,11)
 11   format('1                             ',
     +       '-1=continuous(cdf), 0=categorical(pdf)')
      write(lun,12)
 12   format('5                             ',
     +       '-number thresholds/categories')
      write(lun,13)
 13   format('0.5   1.0   2.5   5.0   10.0  ',
     +       '-   thresholds / categories')
      write(lun,14)
 14   format('0.12  0.29  0.50  0.74  0.88  ',
     +       '-   global cdf / pdf')
      write(lun,15)
 15   format('../data/cluster.dat           ',
     +       '-file with data')
      write(lun,16)
 16   format('1   2   0   3                 ',
     +       '-   columns for X,Y,Z, and variable')
      write(lun,17)
 17   format('direct.ik                     ',
     +       '-file with soft indicator input')
      write(lun,18)
 18   format('1   2   0   3 4 5 6 7         ',
     +       '-   columns for X,Y,Z, and indicators')
      write(lun,19)
 19   format('0                             ',
     +       '-   Markov-Bayes simulation (0=no,1=yes)')
      write(lun,20)
 20   format('0.61  0.54  0.56  0.53  0.29  ',
     +       '-      calibration B(z) values')
      write(lun,21)
 21   format('-1.0e21    1.0e21             ',
     +       '-trimming limits')
      write(lun,22)
 22   format('0.0   30.0                    ',
     +       '-minimum and maximum data value')
      write(lun,23)
 23   format('1      0.0                    ',
     +       '-   lower tail option and parameter')
      write(lun,24)
 24   format('1      1.0                    ',
     +       '-   middle     option and parameter')
      write(lun,25)
 25   format('1     30.0                    ',
     +       '-   upper tail option and parameter')
      write(lun,26)
 26   format('cluster.dat                   ',
     +       '-   file with tabulated values')
      write(lun,27)
 27   format('3   0                         ',
     +       '-      columns for variable, weight')
      write(lun,28)
 28   format('0                             ',
     +       '-debugging level: 0,1,2,3')
      write(lun,29)
 29   format('sisim.dbg                     ',
     +       '-file for debugging output')
      write(lun,30)
 30   format('sisim.out                     ',
     +       '-file for simulation output')
      write(lun,31)
 31   format('1                             ',
     +       '-number of realizations')
      write(lun,32)
 32   format('50   0.5    1.0               ',
     +       '-nx,xmn,xsiz')
      write(lun,33)
 33   format('50   0.5    1.0               ',
     +       '-ny,ymn,ysiz')
      write(lun,34)
 34   format('1    1.0   10.0               ',
     +       '-nz,zmn,zsiz')
      write(lun,35)
 35   format('69069                         ',
     +       '-random number seed')
      write(lun,36)
 36   format('12                            ',
     +       '-maximum original data  for each kriging')
      write(lun,37)
 37   format('12                            ',
     +       '-maximum previous nodes for each kriging')
      write(lun,38)
 38   format('1                             ',
     +       '-maximum soft indicator nodes for kriging')
      write(lun,39)
 39   format('1                             ',
     +       '-assign data to nodes? (0=no,1=yes)')
      write(lun,40)
 40   format('0     3                       ',
     +       '-multiple grid search? (0=no,1=yes),num')
      write(lun,41)
 41   format('0                             ',
     +       '-maximum per octant    (0=not used)')
      write(lun,42)
 42   format('20.0  20.0  20.0              ',
     +       '-maximum search radii')
      write(lun,43)
 43   format(' 0.0   0.0   0.0              ',
     +       '-angles for search ellipsoid')
      write(lun,47)
 47   format('0    2.5                      ',
     +       '-0=full IK, 1=median approx. (cutoff)')
      write(lun,48)
 48   format('0                             ',
     +       '-0=SK, 1=OK')
      write(lun,49)
 49   format('1    0.15                     ',
     +       '-One   nst, nugget effect')
      write(lun,50)
 50   format('1    0.85 0.0   0.0   0.0     ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,51)
 51   format('         10.0  10.0  10.0     ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,52)
 52   format('1    0.10                     ',
     +       '-Two   nst, nugget effect')
      write(lun,53)
 53   format('1    0.90 0.0   0.0   0.0     ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,54)
 54   format('         10.0  10.0  10.0     ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,55)
 55   format('1    0.10                     ',
     +       '-Three nst, nugget effect')
      write(lun,56)
 56   format('1    0.90 0.0   0.0   0.0     ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,57)
 57   format('         10.0  10.0  10.0     ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,58)
 58   format('1    0.10                     ',
     +       '-Four  nst, nugget effect')
      write(lun,59)
 59   format('1    0.90 0.0   0.0   0.0     ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,60)
 60   format('         10.0  10.0  10.0     ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,61)
 61   format('1    0.15                     ',
     +       '-Five  nst, nugget effect')
      write(lun,62)
 62   format('1    0.85 0.0   0.0   0.0     ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,63)
 63   format('         10.0  10.0  10.0     ',
     +       '-      a_hmax, a_hmin, a_vert')

      close(lun)
      return
      end
