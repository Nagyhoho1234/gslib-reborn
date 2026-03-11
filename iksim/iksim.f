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
c        Indicator Kriging and Simulation of a 3-D Rectangular Grid
c              *******************************************
c
c This is a template driver program for GSLIB's "iksim" subroutine. The
c input data must be entered with coordinates in a GEOEAS format file.
c Author: Zhanjun Ying, 12-30-98
c This code is based on GSLIB program IK3d.
c
c
c-----------------------------------------------------------------------
      include  'iksim.inc'
      lin  = 1
      ldbg = 3
      lout = 4
c
c     Read the Parameters and Data
c
      call readparm
c
c     Call ik3d to krige the grid:
c
      call ik3d
      close(ldbg)
      close(lout)
c
c     Do POSTIK if asked by user
c
      if(ipostik.eq.1)   call postik
      
c
c     Do PFSIMFFT if asked by user
c
      if(idosim.eq.1) call pfsimfft

c
c     Do TRANS if asked by user
c
      if(identhist.eq.1) call trans

c
c     All jobs are done
c
      write(*,9998) VERSION
 9998 format(/' IKSIM - GSLIB2-OPT v',f7.1, ' Finished'/)
      stop
      end
 
 
 
      subroutine readparm
c-----------------------------------------------------------------------
c
c                  Initialization and Read Parameters
c                  **********************************
c
c The input parameters and data are read in from their files. Some limited
c error checking is performed and the statistics of all the variables
c being considered are written to standard output.
c
c
c
c-----------------------------------------------------------------------
      include  'iksim.inc'
      parameter(MV=100)
      real      var(MV)
      character datafl*40,str*40
      logical   testfl
      integer dataft,  replaceMiss
      real previousDistance(MAXX*MAXY*MAXZ)
      real tmpcdf(MAXCUT),tmppdf(MAXCUT)

c     Declare the type of called functions
      logical HasMissingValue
      real GetHardData
c
c
c     Note VERSION number:
c
      write(*,9999) VERSION
 9999 format(/' IKSIM - GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)
c
c     Get the name of the parameter file - try the default name if no
c     input:
c
      write(*,*) 'Which parameter file do you want to use?'
      read (*,'(a40)') str
      if(str(1:1).eq.' ')str='iksim.par                                '
      inquire(file=str,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR - the parameter file does not exist,'
            write(*,*) '        check for the file and try again  '
            write(*,*)
            if(str(1:20).eq.'iksim.par           ') then
                  write(*,*) '        creating a blank parameter file'
                  call makepar
                  write(*,*)
            end if
            stop
      endif
      open(lin,file=str,status='OLD')
c
c     Find Start of Parameters:
c
 1    read(lin,'(a4)',end=98) str(1:4)
      if(str(1:4).ne.'STAR') go to 1
c
c     Read Input Parameters:
c

      read(lin,*,err=98) ivtype
      write(*,*) ' variable type (1=continuous, 0=categorical)= ',ivtype

      read(lin,*,err=98) ncut
      write(*,*) ' number of thresholds / categories = ',ncut
      if(ncut.gt.MAXCUT) stop 'ncut is too big - modify .inc file'

      read(lin,*,err=98) (thres(i),i=1,ncut)
      write(*,*) ' thresholds / categories = ',(thres(i),i=1,ncut)

      read(lin,*,err=98) (gcdf(i),i=1,ncut)
      write(*,*) ' global cdf / pdf        = ',(gcdf(i),i=1,ncut)

      read(lin,'(a40)',err=98) datafl
      call chknam(datafl,40)
      write(*,*) ' data file = ',datafl

      
      read(lin,*,err=98) dataft
      write(*,*) ' Is the data indicator format? (1=yes)', dataft
      
      read(lin,*,err=98) ixl,iyl,izl,ivrLowerl,ivrUpperl
      write(*,*) ' columns = ',ixl,iyl,izl,ivrLowerl,ivrUpperl

      read(lin,*,err=98) replaceMiss
      write(*,*) ' Replace missing value?',
     +     '(1=yes)', replaceMiss
     
      if(dataft.eq.1
     +     .and. (ivrLowerl+ncut-1).ne.ivrUpperl) then
         write(*,*) 'ivrUpperl  must equal to',
     +        ' (ivrLowerl+ncut-1)'
         stop
      endif

      read(lin,*,err=98) tmin,tmax
      write(*,*) ' trimming limits = ',tmin,tmax

      read(lin,*,err=98) ikidbg
      write(*,*) ' debugging level in IK3D = ',ikidbg

      read(lin,'(a40)',err=98) ikdbgfl
      call chknam(ikdbgfl,40)
      write(*,*) ' IK3D debug file = ',ikdbgfl
      open(ldbg,file=ikdbgfl,status='UNKNOWN')


      read(lin,'(a40)',err=98) ikoutfl
      call chknam(ikoutfl,40)
      write(*,*) ' kriging output file = ',ikoutfl

      read(lin,*,err=98) nx,xmn,xsiz
      write(*,*) ' nx, xmn, xsiz = ',nx,xmn,xsiz
      if(nx.gt.MAXX) stop 'nx is too big - modify .inc file'

      read(lin,*,err=98) ny,ymn,ysiz
      write(*,*) ' ny, ymn, ysiz = ',ny,ymn,ysiz
      if(ny.gt.MAXY) stop 'ny is too big - modify .inc file'

      read(lin,*,err=98) nz,zmn,zsiz
      write(*,*) ' nz, zmn, zsiz = ',nz,zmn,zsiz
      if(nz.gt.MAXZ) stop 'nz is too big - modify .inc file'
c
c     Allocate all large arrays now that grid size is known:
c
      call iksim_alloc(MAXDAT, nx*ny*nz)

      read(lin,*,err=98) ndmin,ndmax
      write(*,*) ' ndmin, ndmax = ',ndmin,ndmax

      read(lin,*,err=98) radius,radius1,radius2
      write(*,*) ' search radii = ',radius,radius1,radius2
      if(radius.lt.EPSLON) stop 'radius must be greater than zero'
      radsqd = radius  * radius
      sanis1 = radius1 / radius
      sanis2 = radius2 / radius

      read(lin,*,err=98) sang1,sang2,sang3
      write(*,*) ' search anisotropy angles = ',sang1,sang2,sang3

      read(lin,*,err=98) noct
      write(*,*) ' number per octant = ',noct

      read(lin,*,err=98) mik
      write(*,*) ' median IK option = ',mik

      read(lin,*,err=98) ktype
      write(*,*) ' ktype (0=SK, 1=OK) = ',ktype
c
c     If full IK, read all  variograms and write the debugging  file:
c
      if(mik.eq.0) then
        do i=1,ncut
            read(lin,*,err=98) nst(i),c0(i)
            if(ivtype.eq.0)
     +      write(ldbg,100)  i,thres(i),gcdf(i),nst(i),c0(i)
            if(ivtype.eq.1)
     +      write(ldbg,101)  i,thres(i),gcdf(i),nst(i),c0(i)
            if(nst(i).gt.MAXNST) stop 'nst is too big'
            istart = 1 + (i-1)*MAXNST
            do j=1,nst(i)
                  index = istart + j - 1
                  read(lin,*,err=98) it(index),cc(index),ang1(index),
     +                               ang2(index),ang3(index)
                  if(it(index).eq.3) STOP 'Gaussian Model Not Allowed!'
                  read(lin,*,err=98) aa(index),aa1,aa2
                  write(ldbg,102)  j,it(index),aa(index),cc(index)
                  anis1(index) = aa1 / aa(index)
                  anis2(index) = aa2 / aa(index)
                  write(ldbg,103) ang1(index),ang2(index),ang3(index),
     +                            anis1(index),anis2(index)
            end do
        end do
      else
c     Median IK. Just input one  variogram and set the other same as
c     this
        do i=1,1
            read(lin,*,err=98) nst(i),c0(i)
            if(ivtype.eq.0)
     +      write(ldbg,100)  i,thres(i),gcdf(i),nst(i),c0(i)
            if(ivtype.eq.1)
     +      write(ldbg,101)  i,thres(i),gcdf(i),nst(i),c0(i)
            if(nst(i).gt.MAXNST) stop 'nst is too big'
            istart = 1 + (i-1)*MAXNST
            do j=1,nst(i)
                  index = istart + j - 1
                  read(lin,*,err=98) it(index),cc(index),ang1(index),
     +                               ang2(index),ang3(index)
                  if(it(index).eq.3) STOP 'Gaussian Model Not Allowed!'
                  read(lin,*,err=98) aa(index),aa1,aa2
                  write(ldbg,102)  j,it(index),aa(index),cc(index)
                  anis1(index) = aa1 / aa(index)
                  anis2(index) = aa2 / aa(index)
                  write(ldbg,103) ang1(index),ang2(index),ang3(index),
     +                            anis1(index),anis2(index)
            end do
        end do
c     Set the variograms for the other cutoffs equivalent to the first one
        do i=2,ncut
            nst(i) = nst(1)
            c0(i) = c0(1)
            if(ivtype.eq.0)
     +      write(ldbg,100)  i,thres(i),gcdf(i),nst(i),c0(i)
            if(ivtype.eq.1)
     +      write(ldbg,101)  i,thres(i),gcdf(i),nst(i),c0(i)
            istart = 1 + (i-1)*MAXNST
            istartfirstcut = 1 + (1-1)*MAXNST
            do j=1,nst(i)
                  index = istart + j - 1
                  indfirstcut = istartfirstcut + j - 1
                  it(index) = it(indfirstcut)
                  cc(index) = cc(indfirstcut)
                  ang1(index) = ang1(indfirstcut)
                  ang2(index) = ang2(indfirstcut)
                  ang3(index) = ang3(indfirstcut)
                  aa(index) = aa(indfirstcut) 
                  write(ldbg,102)  j,it(index),aa(index),cc(index)
                  anis1(index) = anis1(indfirstcut)
                  anis2(index) = anis2(indfirstcut)
                  write(ldbg,103) ang1(index),ang2(index),ang3(index),
     +                            anis1(index),anis2(index)
            end do
         end do
      endif 
      
C     Read in parameters for POSTIK
      read(lin,*,err=98) ipostik
      write(*,*) ' post-process the IK result? (1=yes, 0=no)'
     + , ipostik

      read(lin,'(a40)',err=98) postoutfl
      call chknam(postoutfl,40)
      write(*,*) ' POSTIK output file = ',postoutfl
      

      read(lin,*,err=98) zmin,zmax
      write(*,*) ' minimum and maximum = ',zmin,zmax    
      read(lin,*,err=98) ietype
      write(*,*) ' e-type? (1=yes, 0=no) = ', ietype
      read(lin,*,err=98) iprob, parlim
      write(*,*) ' prob. & mean above threshold? (1=yes, 0=no)=', iprob
      write(*,*) ' threshold = ', parlim
      if(iprob.eq.1.and.parlim.lt.zmin)
     +  stop 'Invalid z-value for prob. & mean above threshold'
      if(iprob.eq.1.and.parlim.gt.zmax)
     +  stop 'Invalid z-value for prob. & mean above threshold'
      read(lin,*,err=98) ipercentile, parprob
      write(*,*) ' p-percentile corresponding to p-value?(1=yes, 0=no)='
     +,  ipercentile
      write(*,*) ' parprob = ', parprob
      if(ipercentile.eq.1.and.parprob.lt.0.0) 
     + stop 'Invalid p-value'
      if(ipercentile.eq.1.and.parprob.gt.1.0)
     +  stop 'Invalid p-value'
      read(lin,*,err=98) icondvar
      write(*,*) ' conditional variance?(1=yes, 0=no) = ', icondvar
      read(lin,*,err=98) idefault
      write(*,*) ' default tail options & max discretization?', idefault
      read(lin,*,err=98) ltail,ltpar
      read(lin,*,err=98) middle,mpar
      read(lin,*,err=98) utail,utpar
      read(lin,*,err=98) maxdis 
      if(idefault.eq.1) then
        ltail=2 
        ltpar=2.5
        middle=1
        mpar=1.0
        utail=4
        utpar=2.5 
        maxdis=100
      end if
      write(*,*) ' ltail, ltpar = ',ltail,ltpar
      write(*,*) ' middle, mpar = ',middle,mpar
      write(*,*) ' utail, utpar = ',utail, utpar
      write(*,*) ' discretization = ',maxdis  

 
c     Read parameters for simulation
      read(lin,*,err=98) idosim, nsim
      write(*,*) ' do simulation using pfsimfft?((1=yes, 0=no)'
     + , idosim
      write(*,*) ' number of  simulation = ', nsim
      read(lin,*,err=98) ixv(1)
      write(*,*) ' random seed = ',ixv(1)

      
      read(lin,*,err=98) simidbg
      write(*,*) ' debug level for PFSIMFFT = ',simidbg

      read(lin,'(a40)',err=98) simdbgfl
      call chknam(simdbgfl,40)
      write(*,*) ' simulation debug output file = ',simdbgfl
      
      read(lin,*,err=98) nstz(1),c0z(1)
      if(nstz(1).le.0) then
            write(*,9997) nstz(1)
9997       format(' nst must be at least 1, it has been set to ',i4,/,
     +             ' The c or a values can be set to zero')
            stop
      endif
      write(*,*) ' nst,c0: ',nstz(1),c0z(1)
 
      do i=1,nstz(1)
            read(lin,*,err=98) itz(i),ccz(i),ang1z(i),ang2z(i),ang3z(i)
            read(lin,*,err=98) aaz(i),aa1z,aa2z
            anis1z(i) = aa1z / max(aaz(i),EPSLON)
            anis2z(i) = aa2z / max(aaz(i),EPSLON)
            write(*,*) ' it,cc,ang[1,2,3]; ',itz(i),ccz(i),
     +                   ang1z(i),ang2z(i),ang3z(i)
            write(*,*) ' a1 a2 a3: ',aaz(i),aa1z,aa2z
      end do
    

      read(lin,'(a40)',err=98) simoutfl
      call chknam(simoutfl,40)
      write(*,*) ' simulation result file = ',simoutfl


c read parameter for trans
      read(lin,*,err=98) identhist
      write(*,*) ' Identify target distribution? ( 1=yes, 0=no) '
     + , identhist

      if(identhist.eq.1 .and. idosim.eq.0) then
         write(*,*) 'You can not do transform unless you do simulation'
         stop
      end if

      read(lin,*,err=98) itarget
      write(*,*) ' Which distribution is target? ( 1=reference dist.,',
     +'0= data dist.)',  itarget

      read(lin,'(a40)',err=98) distin
      

      read(lin,*,err=98) transivr, transiwt

c if itarget = 0, use data histogram as target distribution.
      if(itarget.eq.0)  then 
         distin = '__harddata.dat'
         transivr = 4
         transiwt = 0
      end if
      call chknam(distin,40)
      write(*,*) ' target distribution (depends on itarget) = ',distin
      write(*,*) ' columns = ',transivr, ' weight = ', transiwt

      read(lin,*,err=98) wx,wy,wz
      write(*,*) ' window size of model to transform = ',wx,wy,wz

      read(lin,*,err=98) omega
      write(*,*) ' scaling factor = ',omega

      read(lin,'(a40)',err=98) transoutfl
      call chknam(transoutfl,40)
      write(*,*) ' output file for trans = ',transoutfl

c     Finished reading parameter file
      close(lin)

c     If identhist = 1,  write out the parameter file for trans
      if (identhist.eq.1) call makeparForTrans

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
c     Check  the data file exists, then either read in the
c     data or write an error message and stop:
c
      nd = 0
      numAllData = 0
      inquire(file=datafl,exist=testfl)
      if(.not.testfl) then
            write(*,*) ' ERROR: data file ',datafl,' does not exist!'
            stop
      end if
c
c     Open the file and read in the header information. Initialize the
c     storage that will be used to summarize the data found in the file:
c
      open(lin,file=datafl,status='OLD')
      read(lin,'(a40)')  str
      read(lin,*,err=99) nvari
      do i=1,nvari
            read(lin,*,err=99)
      end do
c
c     Read all the data until the end of the file:
c
      write(*,*) 
      write(*,*) 'Reading data ...'
 2    read(lin,*,end=3,err=99) (var(j),j=1,nvari)
      numAllData = numAllData +1
C     If the data value is out of tmin and tmax, ignore this data
      if(var(ivrLowerl).lt.tmin.or.var(ivrUpperl).ge.tmax) go to 2
      
      nd = nd + 1
      if(nd.gt.MAXDAT) then
         write(*,*) ' ERROR: Exceeded available memory for data'
         stop
      end if
         
c     Acceptable data, save X, Y, Z coordinates. Hard data are saved in
c     hardData(). Those info will be used in subroutine pfsimfft to
c     ensure that conditonal  data are honored in the simulation result.

      if(ixl.le.0) then
         x(nd)  = xmn
      else
         x(nd)  = var(ixl)
      endif
      if(iyl.le.0) then
         y(nd)  = ymn
      else
         y(nd)  = var(iyl)
      endif
      if(izl.le.0) then
         z(nd)  = zmn
      else
         z(nd)  = var(izl)
      endif

      
      hasMissValue(nd)=.false.
c
c     Begin to get ccdf ( for continous variable) or cpdf (categorical
c     variable) from input data.  

c     If the data is (in)equality constraint, build the indicator data
      if(dataft.eq.0) then

c     Build cdf from the  (in)equality constraint. The cdf may contain
c     missing values.
         call Buildcdf(var(ivrLowerl),var(ivrUpperl),ncut,thres,tmpcdf)

c     Get the pdf from the cdf
         call  cdf2pdf(ncut,tmppdf,tmpcdf,1)

c     Record the indicator data. The indicator data may be
c     modified later if replaceMiss=1
         do ic=1,ncut
            if(ivtype.eq.1) then
               vr(nd,ic)=tmpcdf(ic)
            else
               vr(nd,ic)=tmppdf(ic)
            end if
         end do

c     If it's hard data, record it
         if(var(ivrLowerl).eq.var(ivrUpperl)) then
            hardData(nd)=var(ivrLowerl)
         else 
            hardData(nd)=MISSVALUE
         end if

   
      else
c     The data is in the format of indicator, read in the indicator
c     directly
         do ic=1,ncut
            vr(nd,ic)=var(ivrLowerl+ic-1)
            if (ivtype.eq.1) then 
               tmpcdf(ic)=vr(nd,ic)
            else
               tmppdf(ic)=vr(nd,ic)
            end if
         end do

c     Check the validity of the indicator data vectors
         if(ivtype.eq.1) then
            call Checkcdf(numAllData, ncut, tmpcdf)
         else 
            call Checkpdf(numAllData, ncut, tmppdf)
         end if

c     Get the pdf from cdf if continuous variable in order to check if
c     we have hard data.
         if(ivtype.eq.1) call cdf2pdf(ncut,tmppdf,tmpcdf,1)
c     Get the hard data. If no hard data, then  hardData(nd)=MISSVALUE
         hardData(nd)=GetHardData(ncut, tmppdf, thres)
      end if

c
c     now the ccdf/cpdf is ready. Next we will check if we have missing value
c

c     Check if this indicator data vector has missing values.
      if(HasMissingValue(ncut,tmppdf)) then
         
c     Construct the missing values if the replaceMiss option is 1. 
         if(replaceMiss.eq.0) then
            hasMissValue(nd)=.true.
         else
            if (ivtype.eq.1) then 
               call fillcdf(ncut,gcdf,tmpcdf)
            else 
               call fillpdf(ncut,gcdf,tmppdf)
            end if

c     Pass the constructed tmpcdf or tmppdf back to  vr(nd,ic)
            do ic=1,ncut
               if(ivtype.eq.1) then
                  vr(nd,ic)=tmpcdf(ic)
               else
                  vr(nd,ic)=tmppdf(ic)
               end if
            end do

         end if
      end if
c     Finished check and reconstruct missing values


c     Return for another data:
c     
      go to 2
 3    close(lin)
c     Remind the total number of valid data
      write(*,*) ' Total number of valid data  = ',nd

c     Write all hard data into a temporary file "__harddata.dat".
c     Needed by trans.
      if(identhist.eq.1 .and. itarget.eq.0) then
         open(lin, file='__harddata.dat', status='UNKNOWN')
         write(lin,*) 'temporary hard data file'
         write(lin,*) '4'
         write(lin,*) 'x'
         write(lin,*) 'y'
         write(lin,*) 'z'
         write(lin,*) 'hard data'
         do id=1,nd
            if(hardData(id) .ne. MISSVALUE) then 
               write(lin,*) x(id), y(id), z(id), hardData(id)
            end if
         end do
         close(lin)
      end if

c     The  pfsim honors hard  data only  within classes.  The
c     program checks for the closest datum (if any) within each node
c     grid cell. If the datum is hard, then the node value is reset to
c     that datum. The following code is to find the closest datum for
c     each node. The actual resetting is done in subroutine pfsimfft. 

c     Initialize 
      index=0
      do k=1,nz
         do j=1,ny
            do i=1,nx
               index=index+1
               closestData(ind)=0
            end do
         end do
      end do
      
c     loop over each data
      do id=1,nd
         call getindx(nx,xmn,xsiz,x(id),ix,testind)
         call getindx(ny,ymn,ysiz,y(id),iy,testind)
         call getindx(nz,zmn,zsiz,z(id),iz,testind)
         ind = ix + (iy-1)*nx + (iz-1)*nx*ny
         xx  = xmn + real(ix-1)*xsiz
         yy  = ymn + real(iy-1)*ysiz
         zz  = zmn + real(iz-1)*zsiz
         distance = abs(xx-x(id)) + abs(yy-y(id)) + abs(zz-z(id))
         

c     If the current datum  is the first data detected within the node
c     grid cell, record it
         if(closestData(ind).eq.0) then
            closestData(ind)=id
            previousDistance(ind)=distance
         else
c     Within the node grid cell, a  datum has been detected before.
c     Check if current datum is closer then that one.
            if(distance.lt.previousDistance(ind)) then
               previousDistance(ind)=distance
               closestData(ind)=id
            endif
         end if
      end do

c
c     Open the output file and write a header:
c
      open(lout,file=ikoutfl,status='UNKNOWN')
      write(lout,200) str,ncut
 200  format('IK3D Estimates with:',a40,/,i3)
      do i=1,ncut
            if(ivtype.eq.0) write(lout,201) i,thres(i)
            if(ivtype.eq.1) write(lout,202) i,thres(i)
 201        format('Category:  ',i2,' = ',f12.5)
 202        format('Threshold: ',i2,' = ',f12.5)
      end do
c
c
c
      return
c
c     Error in an Input File Somewhere:
c
 98   stop 'ERROR in parameter file!'
 99   stop 'ERROR in data file!'
c     End of subroutine readpar()
      end



      subroutine ik3d
c-----------------------------------------------------------------------
c
c                   Multiple Indicator Kriging
c                   **************************
c
c     This subroutine is based on GSLIB program IK3D. It is
c     modified  to allow median IK in presence of missing values. 
c
c
c
c-----------------------------------------------------------------------
      include   'iksim.inc'
      integer    infoct(8)
      real       var(100)
      logical    krig,accept

c
c     Set up the rotation/anisotropy matrices that are needed for the
c     variogram and search:
c
      write(*,*) 'Setting up rotation matrices for variogram and search'
      radsqd = radius * radius
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
c     Set up for super block searching:
c
      do i=1,nd
            actloc(i) = real(i)
      end do
      write(*,*) 'Setting up super block search strategy'
      nsec = 0
      call setsupr(nx,xmn,xsiz,ny,ymn,ysiz,nz,zmn,zsiz,nd,x,y,z,actloc,
     +             tmp,nsec,sec1,sec2,sec3,MAXSBX,MAXSBY,MAXSBZ,nisb,
     +             nxsup,xmnsup,xsizsup,nysup,ymnsup,ysizsup,nzsup,
     +             zmnsup,zsizsup)
      call picksup(nxsup,xsizsup,nysup,ysizsup,nzsup,zsizsup,
     +             isrot,MAXROT,rotmat,radsqd,nsbtosr,ixsbtosr,
     +             iysbtosr,izsbtosr)
c
c     Initialize accumulators:
c
      nk = 0
      xk = 0.0
      vk = 0.0
      do icut=1,ncut
            nviol(icut) =  0
            aviol(icut) =  0.0
            xviol(icut) = -1.0
      end do
      nxy   = nx*ny
      nxyz  = nx*ny*nz
      write(*,*)
      write(*,*) 'Working on the kriging '
c
c
c     Report on progress from time to time:
c
      nxy   = nx*ny
      nxyz  = nx*ny*nz
      nloop = nxyz
      irepo = max(1,min((nxyz/10),10000))

c
c     MAIN LOOP OVER ALL THE BLOCKS IN THE GRID:
c
      do index=1,nxyz
         if((int(index/irepo)*irepo).eq.index) write(*,103) index
 103     format('   currently on estimate ',i9)
c
c     Where are we making an estimate?
c
         iz   = int((index-1)/nxy) + 1
         iy   = int((index-(iz-1)*nxy-1)/nx) + 1
         ix   = index - (iz-1)*nxy - (iy-1)*nx
         xloc = xmn + real(ix-1)*xsiz
         yloc = ymn + real(iy-1)*ysiz
         zloc = zmn + real(iz-1)*zsiz
c
c     Find the nearest samples:
c
         call srchsupr(xloc,yloc,zloc,radsqd,isrot,MAXROT,rotmat,
     +        nsbtosr,ixsbtosr,iysbtosr,izsbtosr,noct,
     +        nd,x,y,z,tmp,nisb,nxsup,xmnsup,xsizsup,nysup,
     +        ymnsup,ysizsup,nzsup,zmnsup,zsizsup,nclose,
     +        close,infoct)
c
c     Test number of samples found and octants informed:
c     
         if(nclose.lt.ndmin) then
            if(ikidbg.ge.2) write(ldbg,*) 'Too few data:',ix,iy,iz
            do i=1,ncut
               ccdfo(i) = UNEST
            end do
c     record the kriging variance in estimating cutoff 1 
c     (needed by trans).
            variance(index) = -1.0*MISSVALUE
            go to 1
         endif
c
c     Multi-RHS optimization: For median IK, factor LHS matrix once
c     and solve for all cutoffs with the same neighbor set.
c     For full IK with different variograms per cutoff, solve separately.
c
c     Loop over all the thresholds/categories:
c
         do 2 ic=1,ncut
            krig = .true.
            if(mik.eq.1.and.ic.ge.2) krig = .false.
c
c     Identify the close data (there may be a different number of data
c     at each threshold because of inequality constraint intervals).
c
            nca = 0
            do ia=1,nclose
               j  = int(close(ia)+0.5)
               ii = actloc(j)
c
c     If there is missing values nearby, do kriging for all
c     thresholds/categories  even median IK option is selected.
c
               if(hasMissValue(ii))  krig = .true.

               accept = .true.
               if(vr(ii,ic).eq.MISSVALUE) accept = .false.
               if(accept) then
                  nca = nca + 1
                  vra(nca) = vr(ii,ic)
                  xa(nca)  = x(j)
                  ya(nca)  = y(j)
                  za(nca)  = z(j)
               endif
               if(nca.eq.ndmax) go to 3
            end do
 3          continue
c
c     If there are no samples at this threshold then use the global cdf:
c
            if(nca.eq.0) then
               ccdf(ic) = gcdf(ic)
c     record the kriging variance in estimating cutoff 1
c     (needed by trans).
               if(ic.eq.1) variance(index) = -1.0*MISSVALUE
               go to 2
            endif
c
c     Now, only load the variogram, build the matrix,... if kriging:
c
            if(krig) then
               neq   = nca + ktype
c
c     Solve the Kriging System with more than one sample:
c
               in   = 0
               irot = 1 + (ic-1)*MAXNST
               do j=1,nca
                  do i=1,j
                     in  = in + 1
                     call cova3(xa(i),ya(i),za(i),xa(j),ya(j),
     +                    za(j),ic,nst,MAXNST,c0,it,cc,aa,irot,
     +                    MAXROT,rotmat,cmax,cov)
                     a(in) = dble(cov)
                  end do
                  call cova3(xa(j),ya(j),za(j),xloc,yloc,
     +                 zloc,ic,nst,MAXNST,c0,it,cc,aa,irot,
     +                 MAXROT,rotmat,cmax,cov)
                  r(j)  = dble(cov)
               end do
c
c     Ordinary Kriging unbiasedness constraint:
c
               if(ktype.eq.1) then
                  do i=1,nca
                     in    = in + 1
                     a(in) = 1.0
                  end do
                  in      = in + 1
                  a(in)   = 0.0
                  r(neq)  = 1.0
               endif
c
c     Write out the kriging Matrix if Seriously Debugging:
c
               if(ikidbg.ge.3) then
                  write(ldbg,101) ix,iy,iz
                  is = 1
                  do i=1,neq
                     ie = is + i - 1
                     write(ldbg,102) i,r(i),(a(j),j=is,ie)
                     is = is + i
                  end do
 101              format(/,'Kriging Matrices for Node: ',3i4)
 102              format('    r(',i2,') =',f7.4,'  a= ',9(10f7.4))
               endif
c
c     Solve the system:
c
               call ksol(1,neq,1,a,r,s,ising)
c
c     More Debugging Information:
c
               if(ikidbg.eq.3) then
                  do k=1,nca
                     write(ldbg,98) xa(k),ya(k),za(k),vra(k),s(k)
 98                  format('Loc: x y z ',3f9.1,' val wt ',2f12.5)
                  end do
               endif
c
c     Handle singular case:
c
               if(ising.ne.0) then
                  write(ldbg,*) 'Singular at ',ix,iy,iz,ic
                  if(ikidbg.ge.3) stop
                  do i=1,ncut
                     ccdfo(i) = UNEST
                  end do
c     record the kriging variance in estimating cutoff 1
c     (needed by trans).
                  if(ic.eq.1) variance(index) = -1.0*MISSVALUE
                  go to 1
               endif
c
c     Finished kriging (if it was necessary):
c
            end if
c
c     Compute Kriged estimate of cumulative probability:
c
            sumwts   = 0.0
            ccdf(ic) = 0.0
            do i=1,nca
               ccdf(ic) = ccdf(ic) + vra(i)*real(s(i))
               sumwts   = sumwts   + real(s(i))
            end do
            if(ktype.eq.0)
     +           ccdf(ic) = ccdf(ic) + (1.0-sumwts)*gcdf(ic)

c     record the kriging variance in estimating cutoff 1
c     (needed by trans). Reference: P.G. p.130, p136.
            if(ic.eq.1) then
c     first, calculate C(0).
               variance(index) = c0(1)
               do i=1,nst(1)
                  variance(index) = variance(index) + cc(i)
               end do
c     now, calculate the summation
               do i=1,nca
                  variance(index) = variance(index)
     +                 - r(i)*real(s(i))
               end do
c     if OK, one more term in  kriging variance:
               if (ktype.eq.1) then
                  variance(index) = variance(index)
     +                 - real(s(neq))
               end if
            end if

c
c     Keep looping until all the thresholds are estimated:
c
 2       continue
c
c     Correct and write the distribution to the output file:
c
         nk = nk + 1
         call ordrel(ivtype,ncut,ccdf,ccdfo,nviol,aviol,xviol)
c
c     Debugging information:
c
         if(ikidbg.ge.3) then
            write(ldbg,104) (ccdf(i),i=1,ncut)
            write(ldbg,105) (ccdfo(i),i=1,ncut)
 104        format('Uncorrected: ',30(f8.4))
 105        format('Corrected:   ',30(f8.4))
         endif
c     
c     Write the IK CCDF for this grid node:
c
 1       continue
         write(lout,'(30(f8.4))') (ccdfo(i),i=1,ncut)



c     write the ccdf to  a matrix  which will be passed to postik and
c     simulation.
        
         do i=1,ncut
            pass(index,i)=ccdfo(i)
         end do
c
c     END OF MAIN KRIGING LOOP:
c
      end do
c
c     Write summary of order relations corrections:
c
 22   continue
      ntot = 0
      atot = 0.0
      write(ldbg,300) 
 300  format(/,' Summary of order relations (number and magnitude): ')
      do icut=1,ncut
         ntot = ntot + nviol(icut)
         atot = atot + aviol(icut)
         aviol(icut) = aviol(icut) / real(max(1,nviol(icut)))
         if(ivtype.eq.0)
     +        write(ldbg,301) icut,nviol(icut),aviol(icut),xviol(icut)
         if(ivtype.eq.1)
     +        write(ldbg,302) icut,nviol(icut),aviol(icut),xviol(icut)
 301     format('   Category ',i2,' Number = ',i6,' Average = ',f8.4,
     +        ' Maximum = ',f8.4)
 302     format('   Threshold',i2,' Number = ',i6,' Average = ',f8.4,
     +        ' Maximum = ',f8.4)
      end do
      atot = atot / real(max(1,ntot))
      btot =(ntot / max(1.0,real(ncut*nk))) * 100.0
      write(ldbg,303) btot,atot
 303  format(/,' Total of ',f7.2,'% with an average magnitude of ',f8.4)
      write(*,*)
      write(*,*)'  Finished kriging ',nk,' out of ',nxyz,' locations'

c     write a temporary file "__variance.out" for trans
      if(identhist.eq.1) then
         open(33, file='__variance.out',status='UNKNOWN')
         write(*,*) 
         write(33,*) 'temporary file: kriging variance'
         write(33,*) '1'
         write(33,*) 'kriging variance'
         do index=1,nxyz
            write(33,*) variance(index)
         end do
         close(33)
      end if


c
c     All finished the kriging:
c 
      write(*,*)
      write(*,*) 'ik3D finished'
      write(*,*)
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
      open(lun,file='iksim.par',status='UNKNOWN')
      write(lun,10)
 10   format('                  Parameters for IKSIM',/,
     +       '                  *******************',/,/,
     +       'START OF PARAMETERS:')

      write(lun,11)
 11   format('1                                ',
     +       '-1=continuous(cdf), 0=categorical(pdf)')
      write(lun,12)
 12   format('5                                ',
     +       '-number thresholds/categories')

      write(lun,16)
 16   format('0.5   1.0   2.5   5.0   10.0     ',
     +       '-   thresholds / categories')
      write(lun,17)
 17   format('0.12  0.29  0.50  0.74  0.88     ',
     +       '-   global cdf / pdf')
      write(lun,18)
 18   format('../data/cluster.dat              ',
     +       '-file with data')
      write(lun,19)
 19   format('0                                ',
     +     '-1=indicator vector data in data file')
      write(lun,20)
 20   format('1   2   0    3  4                ',
     +       '-columns for X,Y,Z and lower & upper bound value')

      write(lun,21)
 21   format('1                                ',
     +     '-Replace missing values? (1=yes, recommended for speed)')
      write(lun,22)
 22   format('-1.0e21   1.0e21                 ',
     +     '-trimming limits')
      write(lun,23)
 23   format('2                                ',
     +     '-IK debugging level: 0,1,2,3')
      write(lun,24)
 24   format('ik3d.dbg                         ',
     +     '-file for IK debugging output')
      write(lun,25)
 25   format('ik3d.out                         ',
     +     '-file for kriging output')
      write(lun,26)
 26   format('50   0.5     1.0                 ',
     +       '-nx,xmn,xsiz')
      write(lun,27)
 27   format('50   0.5     1.0                 ',
     +       '-ny,ymn,ysiz')
      write(lun,28)
 28   format('1    0.5     1.0                 ',
     +       '-nz,zmn,zsiz')
      write(lun,29)
 29   format('1    16                          ',
     +       '-min, max data for kriging')
      write(lun,30)
 30   format('25.0  25.0  25.0                 ',
     +       '-maximum search radii')
      write(lun,31) 
 31   format(' 0.0   0.0   0.0                 ',
     +       '-angles for search ellipsoid')
      write(lun,32)
 32   format('0                                ',
     +       '-max per octant (0-> not used)')
      write(lun,33)
 33   format('0                                ',
     +       '-0=full IK, 1=Median IK               ')
      write(lun,34)
 34   format('1                                ',
     +       '-0=SK, 1=OK')
      write(lun,35)
 35   format('1    0.15                        ',
     +       '-One   nst, nugget effect')
      write(lun,36)
 36   format('1    0.85 0.0   0.0   0.0        ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,37)
 37   format('         10.0  10.0  10.0        ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,38)
 38   format('1    0.1                         ',
     +       '-Two   nst, nugget effect')
      write(lun,39)
 39   format('1    0.9  0.0   0.0   0.0        ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,40)
 40   format('         10.0  10.0  10.0        ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,41)
 41   format('1    0.1                         ',
     +       '-Three nst, nugget effect')
      write(lun,42)
 42   format('1    0.9  0.0   0.0   0.0        ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,43)
 43   format('         10.0  10.0  10.0        ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,44)
 44   format('1    0.1                         ',
     +       '-Four  nst, nugget effect')
      write(lun,45)
 45   format('1    0.9  0.0   0.0   0.0        ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,46)
 46   format('         10.0  10.0  10.0        ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,47)
 47   format('1    0.15                        ',
     +       '-Five  nst, nugget effect')
      write(lun,48)
 48   format('1    0.85 0.0   0.0   0.0        ',
     +       '-      it,cc,ang1,ang2,ang3')
      write(lun,49)
 49   format('         10.0  10.0  10.0        ',
     +       '-      a_hmax, a_hmin, a_vert')
      write(lun,50)
 50   format('1                                ',
     +       '-call for postik? 1=yes')
      write(lun,51)
 51   format('postik.out                       ',
     +       '-file for postik output')  
      write(lun,52)
 52   format('0.0    100.0                     ',
     +     '-minimum and maximum Z value')
      write(lun,53)
 53   format('1                                ',
     +       '-E-type? 1=yes, 0=no')
      write(lun,54)
 54   format('1  1.5                           ',
     +       '-Prob.&mean above threshold? 1=yes, par')
      write(lun,55)
 55   format('1   0.5                          ',
     +     '-percentile corresponding to par? 1=yes, par')
      write(lun,56)
 56   format('1                                ',
     +       '-conditonal variance? 1=yes, 0=no')
      write(lun,57)
 57   format('0                                ',
     +     '-default? 1=yes. If no, enter following.')
      write(lun,58)
 58   format('2   2.5                          ',
     +     '-lower tail: option, parameter')
      write(lun,59)
 59   format('1   1.0                          ',
     +     '-middle    : option, parameter')
      write(lun,60)
 60   format('4   2.5                          ',
     +     '-upper tail: option, parameter')
      write(lun,61)
 61   format('100                              ',
     +     '-maximum discretization')
      write(lun,62)
 62   format('1      1                         ',
     +     '-do simulation? 1=yes;number of simulations')
      write(lun,63)
 63   format('31991429                         ',
     +     '-random number seed')
      write(lun,64)
 64   format('3                                ',
     +     '-debugging level for PFSIMFFT: 0,1,2,3')
      write(lun,65)
 65   format('pfsim.dbg                        ',
     +     '-output file for debugging PFSIMFFT')
      write(lun,66)
 66   format('1    0.30                        ',
     +     '-nst, nugget effect')
      write(lun,67)
 67   format('1    0.70 0.0   0.0   0.0        ',
     +     '-      it,cc,ang1,ang2,ang3')
      write(lun,68)
 68   format('         10.0  10.0  10.0        ',
     +     '-      a_hmax, a_hmin, a_vert')
      write(lun,69)
 69   format('iksim.out                        ',
     +     '-output file of simulations')
      write(lun,70)
 70   format('0                                ',
     +     '-identify target distribution? 1=yes')
      write(lun,71)
 71    format('1                                ',
     +     '-1=use target distribution, 0=use data distribution')
      write(lun,72)
 72   format('true.dat                         ',
     +     '-file with reference distribution')
      write(lun,73)
 73   format('1 0                              ',
     +     '-columns for value and weight')
      write(lun,74)
 74   format('2 2 0                            ',
     +     '-wx, wy, wz: window size for tie-breaking')
     
      write(lun,75)
 75   format('0.5                              ',
     +     '-control parameter ( 0 <= w <= 1)')

      write(lun,76)
 76   format('trans.out                        ',
     +     'output file for transformed distribution')

      close(lun)
      return
      end




      subroutine makeparForTrans
      include 'iksim.inc'
c-----------------------------------------------------------------------
c
c              Write a Temporary Parameter File for Trans
c                      **********************
c
c
c
c-----------------------------------------------------------------------
      lun = 99
      open(lun,file='__trans.par',status='UNKNOWN')
      write(lun,10)
 10   format('                  Parameters for TRANS',/,
     +       '                  ********************',/,/,
     +       'START OF PARAMETERS:')

      write(lun,*) ivtype
      write(lun,*) distin
      write(lun,*) transivr, transiwt
      write(lun,*) simoutfl
      write(lun,*) '1  0'
      write(lun,*) tmin, tmax
      write(lun,*) transoutfl
      write(lun,*) nsim
      write(lun,*) nx, ny, nz
      write(lun,*) wx, wy, wz
c the number to transform per "set" is set to nx*ny*nz
      write(lun,*) nx*ny*nz
      write(lun,*) zmin, zmax
      write(lun,*) ltail, ltpar
      write(lun,*) utail, utpar
      write(lun,*) '1'
      write(lun,*) '__variance.out'
      write(lun,*) '1'
      write(lun,*) omega
      write(lun,*) ixv(1)
      close(lun)
      return
      end

c-------------------------------------------------------------------
c
c     subroutine: Checkpdf
c     check the validity  of the pdf
c
c-----------------------------------------------------------------

      subroutine Checkpdf(number,ncut,pdf)
      integer number,ncut
      real  pdf(ncut)

      real MISSVALUE
      parameter (MISSVALUE = -999.0)
      integer ic
      logical HasMissingValue
      real cdf

      cdf=0.0

      do ic=1,ncut

c     Check the pdf \in [0.0, 1.0] or is MISSVALUE
         if( (pdf(ic) .lt. 0.0 .and. pdf(ic) .ne. MISSVALUE)
     +        .or. pdf(ic) .gt. 1.0 ) then
            write(*,*) 'Error: invalid pdf in entry', number
            stop
         end if

         if(pdf(ic) .ne. MISSVALUE) cdf = cdf + pdf(ic)
      end do

c     Check the cdf 
      if(HasMissingValue(ncut, pdf) )  then
         if(cdf .gt. 1.0) then
            write(*,*) 'Error: cdf .gt. 1.0 in entry', number
            stop
         end if
      else 
         if(cdf .ne. 1.0) then
             write(*,*) 'Error: cdf .ne. 1.0  in entry', number
            stop
         end if
      endif

      end
     

c-------------------------------------------------------------------
c
c     subroutine: Checkcdf
c     check the validity  of the cdf
c
c-----------------------------------------------------------------

      subroutine checkcdf(number,ncut,cdf)
      integer number,ncut
      real  cdf(ncut)

      real MISSVALUE
      parameter (MISSVALUE = -999.0)
      integer ic
      real previouscdf

      previouscdf=MISSVALUE
      
      do ic=1,ncut
c     Check the cdf \in [0.0, 1.0] or is MISSVALUE
         if( (cdf(ic) .lt. 0.0 .and. cdf(ic) .ne. MISSVALUE)
     +        .or. cdf(ic) .gt. 1.0 ) then
            write(*,*) 'Error: invalid cdf in entry', number
            stop
         end if
c     Check non-decreasing property         
         if(cdf(ic) .ne. MISSVALUE) then
            if(cdf(ic) .lt. previouscdf  ) then
               write(*,*) 'Error: cdf must be non-decreasing', number
               stop
            end if
            previouscdf=cdf(ic)
         end if
      end do

      end



c----------------------------------------------------------------------
c
c     subroutine: cdf2pdf
c
c     Derive pdf from cdf when flag=1, derive cdf from pdf when flag=0
c
c----------------------------------------------------------------------
      subroutine  cdf2pdf(ncut,pdf, cdf,  flag)
      integer ncut
      real pdf(ncut), cdf(ncut)
      integer flag
      
      real MISSVALUE
      parameter (MISSVALUE = -999.0)
      integer ic
      logical HasMissingValue

      

c     flag=1: from cdf to  pdf
      if(flag.eq.1) then
         pdf(1)=cdf(1)
         do ic=2,ncut
            if(cdf(ic).ne.MISSVALUE .and. cdf(ic-1).ne.MISSVALUE) then
               pdf(ic)=cdf(ic)-cdf(ic-1)
            else
               pdf(ic)=MISSVALUE
            end if
         enddo
c     flag=0: from pdf to cdf. Assume the pdf has no missing values
      else if (flag.eq.0) then

         if(HasMissingValue(ncut, pdf)) then
            write(*,*) 'Error: can not get cdf from pdf with missing',
     +           'values'
            stop
         end if

         cdf(1)=pdf(1)
         do ic=2,ncut
            cdf(ic)=cdf(ic-1)+pdf(ic)
         end do
      else
         write(*,*)
     +        'Error: in subroutine cdf2pdf, the flag must be 0 or 1'
         stop
      end if
      
      end

c-------------------------------------------------------------------
c
c     subroutine: fillpdf
c
c     Fill the missing values in pdf by  valid values derived from
c     global pdf
c
c-----------------------------------------------------------------

      subroutine fillpdf(ncut,globalpdf,pdf)
      integer ncut
      real globalpdf(ncut), pdf(ncut)

      real leftcdf,leftgloabalcdf,MISSVALUE
      parameter (MISSVALUE = -999.0)
      integer ic
      
      leftcdf=1.0
      leftgloabalcdf=1.0

      do ic=1,ncut
         if(pdf(ic).ne.MISSVALUE) then
            leftcdf=leftcdf-pdf(ic)
            leftgloabalcdf=leftgloabalcdf-globalpdf(ic)
         endif
      enddo

      do ic=1,ncut
         if(pdf(ic).eq.MISSVALUE) then
            if(leftgloabalcdf.eq.0.0) then
               pdf(ic)=0.0
            else 
               pdf(ic)=globalpdf(ic)/leftgloabalcdf*leftcdf
            end if
         end if
      end do
      
      end

c-------------------------------------------------------------------
c     subroutine: fillcdf
c
c     Fill the missing values in cdf by  valid values derived from
c     global cdf
c
c-----------------------------------------------------------------

      subroutine fillcdf(ncut,globalcdf,cdf)
      integer ncut
      real globalcdf(ncut), cdf(ncut)

      real MISSVALUE
      parameter (MISSVALUE = -999.0)
      integer ic,jc, lastCutoff
      real lastcdf, lastglobalcdf

      lastCutoff=0
      lastcdf=0.0
      lastglobalcdf=0.0

      do ic=1,ncut
         if (cdf(ic).ne.MISSVALUE) then
            do jc=lastCutoff+1,ic-1
               cdf(jc)=lastcdf+(cdf(ic)-lastcdf)
     +              /(globalcdf(ic)-lastglobalcdf)
     +              *(globalcdf(jc)-lastglobalcdf)
            end do
            lastcdf=cdf(ic)
            lastglobalcdf=globalcdf(ic)
            lastCutoff=ic
         end if
      end do

c     If the cdf(ncut) is MISSVALUE, then we havn't finished the job

      if(cdf(ncut).eq.MISSVALUE) then
         do jc=lastCutoff+1,ncut
            cdf(jc)=lastcdf+(1.0-lastcdf)
     +              /(1.0-lastglobalcdf)
     +              *(globalcdf(jc)-lastglobalcdf)
         end do
      end if

      end

c-------------------------------------------------------------------
c
c     function:  HasMissingValue(ncut, pdf)
c
c     Check if missing values are present in the pdf or cdf
c      
c
c-----------------------------------------------------------------

      logical function HasMissingValue(ncut, pdf)
      integer ncut
      real pdf(ncut),MISSVALUE

      parameter (MISSVALUE = -999.0)
      integer ic

      HasMissingValue=.false.
       do ic=1,ncut
         if(pdf(ic).eq.MISSVALUE)  then
            HasMissingValue=.true.
            return
         end if
      end do

      end

            
c-------------------------------------------------------------------
c
c     function: HasHardData(ncut, pdf)
c     Check if hard data are present in the pdf. If pdf(i)=1, then
c     thres(i) is treated as hard data.
c
c-----------------------------------------------------------------

      logical function HasHardData(ncut, pdf)
      integer ncut
      real pdf(ncut)

      real MISSVALUE
      parameter (MISSVALUE = -999.0)
      integer ic

      HasHardData=.false.
       do ic=1,ncut
         if(pdf(ic).eq.1.0)  then
            HasHardData=.true.
            return
         end if
      end do

      end

c-------------------------------------------------------------------
c
c     function GetHardData(ncut, pdf, thres)
c      
c     The function GetHardData will return the hard data if hard data
c     is present. If no hard data, it will return MISSVALUE
c-----------------------------------------------------------------

      real function GetHardData(ncut, pdf, thres)
      integer ncut
      real pdf(ncut), thres(ncut)

      real MISSVALUE
      parameter (MISSVALUE = -999.0)      
      integer ic
      logical HasHardData

      GetHardData=MISSVALUE
      if(HasHardData(ncut,pdf)) then
         do ic=1,ncut
            if(pdf(ic).eq.1.0)  then
               GetHardData=thres(ic)
               return
            end if
         end do
      endif
      
      end
         

c----------------------------------------------------------------------
c
c     subroutine Buildcdf( lower, upper, ncut,thres, cdf)
c
c     Buld cdf from inequaliity constraints or  equality constraints 
c
c----------------------------------------------------------------------
      subroutine Buildcdf( lower, upper, ncut,thres, cdf)
      integer ncut
      real lower, upper, thres(ncut), cdf(ncut)

      real MISSVALUE
      parameter (MISSVALUE = -999.0)      
      integer ic

      if (lower.gt.upper) then
         write(*,*) 'Error: lower limit is larger than upper limit'
         stop
      end if

      do ic=1,ncut
         if(thres(ic) .lt. lower )  then
            cdf(ic)=0.0
         else if(thres(ic) .ge. upper) then
            cdf(ic)=1.0
         else
            cdf(ic)=MISSVALUE
         end if
      end do


      end


