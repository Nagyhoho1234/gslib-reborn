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
c               CoKriging of a 3-D Rectangular Grid
c               ***********************************
c
c This program estimates the value of a "primary" variable with primary
c and secondary data.  The program could be modified to jointly predict
c primary and secondary data.
c
c
c
c-----------------------------------------------------------------------
      include  'newcokb3d.inc'
c
c Read the Parameter File and the Data:
c
      call readparm
c
c Call cokb3d to krige the grid:
c
      call cokb3d
c
c Finished:
c
      write(*,9998) VERSION
 9998 format(/' COKB3D - GSLIB2-OPT v',f7.1, ' Finished'/)
      stop
      end



      subroutine readparm
c-----------------------------------------------------------------------
c
c                  Initialization and Read Parameters
c                  **********************************
c
c The input parameters and data are read, some quick error checking is
c performed, and the statistics of all the variables being considered
c are written to standard output.
c
c
c
c-----------------------------------------------------------------------
      include  'newcokb3d.inc'
      parameter(MV=20)
      real      var(MV),av(MV),ss(MV)
      integer   ivrl(MV),nn(MV)
      character datafl*40,outfl*40,dbgfl*40,secfl*40,str*40, lvmfl*40
      logical   testfl,linmod,posdef
      common /varpar2/ssec,gvar
      common /sill123/c11,c12,c22,crr
      
c
c I/O units:
c
      lin  = 1
      lout = 2
      ldbg = 3
      llsec=4
c
c Note VERSION number:
c
      write(*,9999) VERSION
 9999 format(/' COKB3D - GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)
c
c Get the name of the parameter file - try the default name if no input:
c
      write(*,*) 'Which parameter file do you want to use?'
      read (*,'(a40)') str
      if(str(1:1).eq.' ')str='newcokb3d.par                  '
      inquire(file=str,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR - the parameter file does not exist,'
            write(*,*) '        check for the file and try again  '
            write(*,*)
            if(str(1:20).eq.'newcokb3d.par          ') then
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

      read(lin,*,err=98) nvr
      write(*,*) ' number of variables = ',nvr
      if(nvr.gt.MAXVAR) stop 'nvr is too big - modify .inc file'
      if(nvr.gt.4) stop 'can not use more than 3 secondary variables'

      read(lin,*,err=98) ixl,iyl,izl,(ivrl(i),i=1,nvr)
      write(*,*) ' columns = ',ixl,iyl,izl,(ivrl(i),i=1,nvr)

      read(lin,*,err=98) tmin,tmax
      write(*,*) ' trimming limits = ',tmin,tmax


      read(lin,*,err=98) icoloc
      write(*,*) ' co-located cokriging flag = ',icoloc      
            

      read(lin,'(a40)',err=98) secfl
      call chknam(secfl,40)
      write(*,*) ' collocated cokriging file = ',secfl

      read(lin,*,err=98) icoll
      write(*,*) ' column for covariate = ',icoll

      
      read(lin,*,err=98)ilvm
      write(*,*)' local varying mean flag=',ilvm

      read(lin,'(a40)',err=98) lvmfl
      call chknam(lvmfl,40)
      write(*,*) ' Local varing mean file = ',lvmfl
      read(lin,*,err=98) icollvm
      write(*,*) ' column for local varying mean = ',icollvm

      read(lin,*,err=98) idbg
      write(*,*) ' debug level = ',idbg

      read(lin,'(a40)',err=98) dbgfl
      call chknam(dbgfl,40)
      write(*,*) ' debug file = ',dbgfl
      write(*,*)
      write(*,*) ' Some input parameters are now echoed to debug file'
      write(*,*)

      open(ldbg,file=dbgfl,status='UNKNOWN')

      read(lin,'(a40)',err=98) outfl
      call chknam(outfl,40)
      write(*,*) ' output file = ',outfl

      read(lin,*,err=98) nx,xmn,xsiz
      write(*,*) ' nx, xmn, xsiz = ',nx,xmn,xsiz

      read(lin,*,err=98) ny,ymn,ysiz
      write(*,*) ' ny, ymn, ysiz = ',ny,ymn,ysiz

      read(lin,*,err=98) nz,zmn,zsiz
      write(*,*) ' nz, zmn, zsiz = ',nz,zmn,zsiz

      read(lin,*,err=98) nxdis,nydis,nzdis
      write(*,*) ' nxdis,nydis,nzdis = ',nxdis,nydis,nzdis
      if((nxdis*nydis*nzdis).gt.MAXDIS) then
            write(*,*) 'ERROR COKB3D: Too many discretization points '
            write(*,*) '              Increase MAXDIS or lower n[xy]dis'
            stop
      endif

      read(lin,*,err=98) ndmin,ndmaxp,ndmaxs
      write(*,*) ' ndmin,ndmaxp,ndmaxs = ',ndmin,ndmaxp,ndmaxs

      read(lin,*,err=98) radiusp,radius1,radius2
      write(*,*) ' primary search radii = ',radiusp,radius1,radius2
      if(radiusp.lt.EPSLON) stop 'radius must be greater than zero'
      radsqdp = radiusp * radiusp
      sanisp1 = radius1 / radiusp
      sanisp2 = radius2 / radiusp

      read(lin,*,err=98) radiuss,radius1,radius2
      write(*,*) ' secondary search radii = ',radiuss,radius1,radius2
      if(radiuss.lt.EPSLON) stop 'radius must be greater than zero'
      radsqds = radiuss * radiuss
      saniss1 = radius1 / radiuss
      saniss2 = radius2 / radiuss

      read(lin,*,err=98) sang1,sang2,sang3
      write(*,*) ' search anisotropy angles = ',sang1,sang2,sang3

      read(lin,*,err=98) ktype
      write(*,*) ' kriging type = ',ktype
      if(ktype.lt.0.or.ktype.gt.2) stop ' ERROR: invalid kriging type'
      if(icoloc.eq.1 .and. ktype.eq.2) stop'ERROR: invalid kriging type'
      if(ilvm.eq.1 .and. ktype.ne.0) stop' ERROR: LVM must be SK'
      
      if(icoloc.eq.1) then
        read(lin,*,err=98) (vmean(i),i=1,2)
        write(*,*) ' variable means = ',(vmean(i),i=1,2)
      else if( icoloc.eq.0)then 
        
      read(lin,*,err=98) (vmean(i),i=1,nvr)
      write(*,*) ' variable means = ',(vmean(i),i=1,nvr)
      
      endif

      read(lin,*,err=98)imodel
      write(*,*)'imodel type=',imodel
      
      read(lin,*,err=98)colocorr
      write(*,*) ' correlation coefficient=', colocorr
      
      read(lin,*,err=98)var2
      write(*,*) ' variance of secondary variable=', var2
      
      read(lin,*,err=98)var1      
      write(*,*) 'variance of primary variable=', var1
      
      if(imodel.eq.1) then
         read(lin,*,err=98)i,j
         write(*,*)' i,  j=',i,j  
         if(i.gt.MAXVAR.or.j.gt.MAXVAR) then
          write(*,*) ' Variogram specified for variable beyond MAXVAR'
             stop
         end if    
         read(lin,*,err=98) nst(1),c0(1)
         c11  = c0(1)
         write(*,*) ' nst, c0 = ',nst(1),c0(1)

c
c   Calculating the C11 for MM1
c
         do i=1,nst(1)
            read(lin,*,err=98) it(i),cc(i),ang1(i),ang2(i),ang3(i)
            read(lin,*,err=98) aa(i),aa1,aa2
            anis1(i) = aa1 / max(aa(i),EPSLON)
            anis2(i) = aa2 / max(aa(i),EPSLON)
            c11     = c11 + cc(i)
            
            write(*,*) ' it,cc,ang[1,2,3]; ',it(i),cc(i),
     +                   ang1(i),ang2(i),ang3(i)
            write(*,*) ' a1 a2 a3: ',aa(i),aa1,aa2
          end do
c
c C22 equals to the variance of the secondary variable 
c          
         
          c22=var2
                  
      endif
      
      if (imodel.eq.2) then
      
c reading secondary attribute's structure
         read(lin,*,err=98)i,j
         write(*,*)' i,  j=',i,j 
         if(i.gt.MAXVAR.or.j.gt.MAXVAR) then
          write(*,*) ' Variogram specified for variable beyond MAXVAR'
             stop
         end if 
     
         read(lin,*,err=98) nst(1),c0(1)
         c22 = c0(1)
         write(*,*) ' nst, c0 = ',nst(1),c0(1)
c
c Calculating the C22 for MM2
c
         do i=1,nst(1)
            read(lin,*,err=98) it(i),cc(i),ang1(i),ang2(i),ang3(i)
            read(lin,*,err=98) aa(i),aa1,aa2
            anis1(i) = aa1 / max(aa(i),EPSLON)
            anis2(i) = aa2 / max(aa(i),EPSLON)
            c22     = c22 + cc(i)
            if(it(i).eq.4) then
                  write(*,*) ' A power model is NOT allowed '
                  write(*,*) ' Choose a different model and re start '
                  stop
            endif
            write(*,*) ' it,cc,ang[1,2,3]; ',it(i),cc(i),
     +                   ang1(i),ang2(i),ang3(i)
            write(*,*) ' a1 a2 a3: ',aa(i),aa1,aa2
          end do
c
c C11 equals to the variance of the primary variable
c          
           c11=var1
          
c
c  reading  the residual's structure
c
           read(lin,*,err=98)i,j
           write(*,*)' i,  j=',i,j           
           read(lin,*,err=98) nst(2),c0(2)
           crr=c0(2)
           write(*,*) ' nst, c0 = ',nst(2),c0(2)
           
           do i=MAXNST+1,MAXNST+nst(2)
         
              read(lin,*,err=98) it(i),cc(i),ang1(i),ang2(i),ang3(i)
              read(lin,*,err=98) aa(i),aa1,aa2
              crr=crr+cc(i)
              anis1(i) = aa1 / max(aa(i),EPSLON)
              anis2(i) = aa2 / max(aa(i),EPSLON)
              write(*,*) ' it,cc,ang[1,2,3]; ',it(i),cc(i),
     +                   ang1(i),ang2(i),ang3(i) 
              write(*,*) ' a1 a2 a3: ',aa(i),aa1,aa2
 
           end do
           
      endif

          
c  imodel=1 for MM1, =2 for MM2, =3 for LMC
      if(imodel.eq.3) then  
c
c Now, initialize nst value to -1 to flag all missing variograms:
c
         if(icoloc.eq.1) nvr=2
         do i=1,nvr
            do j=1,nvr
                  ind = i + (j-1)*MAXVAR
                  nst(ind) = -1
            end do
         end do
c
c Read as many variograms as are in the parameter file:
c
         
 3       read(lin,*,end=4,err=98) i,j
   
         if(i.gt.MAXVAR.or.j.gt.MAXVAR) then
          write(*,*) ' Variogram specified for variable beyond MAXVAR'
             stop
         end if
         ind = i + (j-1)*MAXVAR
         read(lin,*,err=98) nst(ind),c0(ind)
         write(ldbg,103) i,j,nst(ind),c0(ind)
      
         istart = 1 + (ind-1)*MAXNST
         do i=1,nst(ind)
            index = istart + i - 1
           
            read(lin,*,err=98) it(index),cc(index),ang1(index),
     +                         ang2(index),ang3(index)
            
            read(lin,*,err=98) aa(index),aa1,aa2
            
            anis1(index) = aa1 / max(aa(index),EPSLON)
            anis2(index) = aa2 / max(aa(index),EPSLON)
            if(it(index).eq.4.and.ktype.eq.0) 
     +                         stop 'No Power model with SK'
         end do
         write(ldbg,104) (it(istart+i-1),   i=1,nst(ind))
         write(*,104)(it(istart+i-1),   i=1,nst(ind))
         write(ldbg,105) (aa(istart+i-1),   i=1,nst(ind))
         write(ldbg,106) (cc(istart+i-1),   i=1,nst(ind))
         write(ldbg,107) (ang1(istart+i-1), i=1,nst(ind))
         write(ldbg,108) (ang2(istart+i-1), i=1,nst(ind))
         write(ldbg,109) (ang3(istart+i-1), i=1,nst(ind))
         write(ldbg,110) (anis1(istart+i-1),i=1,nst(ind))
         write(ldbg,111) (anis2(istart+i-1),i=1,nst(ind))
 103     format(/,' USER input variogram for variables ',i2,' and ',i2,/,
     +       '      number of structures=',i2,' nugget effect=',f12.4)
 104     format('      types of structures: ',10i2)
 105     format('      aa values:           ',10f12.4)
 106     format('      cc values:           ',10f12.4)
 107     format('      ang1 values:         ',10f12.4)
 108     format('      ang2 values:         ',10f12.4)
 109     format('      ang3 values:         ',10f12.4)
 110     format('      anis1 values:        ',10f12.4)
 111     format('      anis2 values:        ',10f12.4)
         go to 3
 4      close(lin)
c
c calculating sill for colocated cokriging[c12(0)]{LMC}
c
        if(icoloc.eq.1) then
           ind=1+MAXVAR
           istart = 1 + (ind-1)*MAXNST
           c12=c0(ind)
           do i=1,nst(ind)
             index = istart + i - 1
             c12=c12+cc(index)
           end do 
            
           ind=2+MAXVAR
           istart = 1 + (ind-1)*MAXNST
           c22=c0(ind)
           do i=1,nst(ind)
              index = istart + i - 1  
              c22=c22+cc(index)       
           end do
         endif     
c
c Fill in cross variograms j=i if they have not been explicitly entered:
c
         do i=1,nvr
         do j=1,nvr
            ind1 = i + (j-1)*MAXVAR
            ind2 = j + (i-1)*MAXVAR
            if(nst(ind1).eq.-1.and.nst(ind2).eq.-1) then
                  write(*,*) ' Need variogram between variables ',i,j
                  stop
            end if
            if(nst(ind1).eq.-1) then
                  nst(ind1) = nst(ind2)
                  c0(ind1)  = c0(ind2)
                  istart1   = 1 + (ind1-1)*MAXNST
                  istart2   = 1 + (ind2-1)*MAXNST
                  do ist=1,nst(ind1)
                        index2        = istart2 + ist - 1
                        index1        = istart1 + ist - 1
                        it(index1)    = it(index2)
                        cc(index1)    = cc(index2)
                        aa(index1)    = aa(index2)
                        ang1(index1)  = ang1(index2)
                        ang2(index1)  = ang2(index2)
                        ang3(index1)  = ang3(index2)
                        anis1(index1) = anis1(index2)
                        anis2(index1) = anis2(index2)
                  end do
               else if(nst(ind2).eq.-1) then
                  nst(ind2) = nst(ind1)
                  c0(ind2)  = c0(ind1)
                  istart1   = 1 + (ind1-1)*MAXNST
                  istart2   = 1 + (ind2-1)*MAXNST
                  do ist=1,nst(ind2)
                        index2        = istart2 + ist - 1
                        index1        = istart1 + ist - 1
                        it(index2)    = it(index1)
                        cc(index2)    = cc(index1)
                        aa(index2)    = aa(index1)
                        ang1(index2)  = ang1(index1)
                        ang2(index2)  = ang2(index1)
                        ang3(index2)  = ang3(index1)
                        anis1(index2) = anis1(index1)
                        anis2(index2) = anis2(index1)
                  end do
               end if
          end do
          end do
c
c Has the linear model of coregionalization been used?
c
c   Check for LMC
     
      
      	linmod = .true.
      	do i=1,nvr
      	do j=1,nvr
            ind1 = i + (j-1)*MAXVAR
            do i2=1,nvr
            do j2=1,nvr
                  ind2 = i2 + (j2-1)*MAXVAR
                  if(nst(ind1).ne.nst(ind2)) linmod = .false.
                  istart1 = 1 + (ind1-1)*MAXNST
                  istart2 = 1 + (ind2-1)*MAXNST
                  do ist=1,nst(ind1)
                     index2 = istart2 + ist - 1
                     index1 = istart1 + ist - 1
                     if(it(index1).ne.it(index2).or.
     +                abs(aa(index1)    - aa(index2)).gt.EPSLON.or.
     +                abs(ang1(index1)  - ang1(index2)).gt.EPSLON.or.
     +                abs(ang2(index1)  - ang2(index2)).gt.EPSLON.or.
     +                abs(ang3(index1)  - ang3(index2)).gt.EPSLON.or.
     +                abs(anis1(index1) - anis1(index2)).gt.EPSLON.or.
     +                abs(anis2(index1) - anis2(index2)).gt.EPSLON)
     +                linmod = .false.
                  end do
            end do
            end do
      end do
      end do
      if(linmod) then
c
c Yes, the linear model of coregionalization has been used, now check
c to ensure positive definiteness:
c
            posdef = .true.
            do i=1,nvr
            do j=1,nvr
               if(i.ne.j) then
                  ii = i+(i-1)*MAXVAR
                  jj = j+(j-1)*MAXVAR
                  ij = i+(j-1)*MAXVAR
                  ji = j+(i-1)*MAXVAR
                  istartii = 1 + (ii-1)*MAXNST
                  istartjj = 1 + (jj-1)*MAXNST
                  istartij = 1 + (ij-1)*MAXNST
                  istartji = 1 + (ji-1)*MAXNST
c
c First check the nugget effects:
c
                  if(c0(ii).le.0.0.or.c0(jj).le.0.0.or.
     +              (c0(ii)*c0(jj)).lt.(c0(ij)*c0(ji)) ) then
                        posdef = .false.
                        write(ldbg,120) i,j
                  endif
                  do ist=1,nst(ii)
                        indexii = istartii + ist - 1
                        indexjj = istartjj + ist - 1
                        indexij = istartij + ist - 1
                        indexji = istartji + ist - 1
                        if(cc(indexii).le.0.0.or.cc(indexjj).le.0.0.or.
     +                    (cc(indexii)*cc(indexjj)).lt.
     +                    (cc(indexij)*cc(indexji)) ) then
                              posdef = .false.
                              write(ldbg,121) ist,i,j
                        endif
                  end do
               end if
            end do
            end do
 120        format(/,'Positive definiteness violation on nugget effects'
     +            ,/,' between ',i2,' and ',i2)
 121        format(/,'Positive definiteness violation on structure ',i2
     +            ,/,' between ',i2,' and ',i2)
c
c The model is not positive definite:
c
            if(.not.posdef) then
               write(*,*)
             write(*,*) ' The linear model of coregionalization is NOT'
           write(*,*) ' positive definite! This could lead to singular'
               write(*,*) ' matrices and unestimated points.'
               write(*,*)
               write(*,*) ' Do you want to proceed? (y/n)'
               read (*,'(a40)') str
               if(str(1:1).ne.'y'.and.str(1:1).ne.'Y') stop
            end if
            else
c
c No linear model of coregionalization:
c
            write(*,*)
            write(*,*) ' A linear model of coregionalization has NOT'
            write(*,*) ' been used!!  This could lead to many singular'
            write(*,*) ' matrices and unestimated points.'
            write(*,*)
            write(*,*) ' Do you want to proceed? (y/n)'
            read (*,'(a40)') str
            if(str(1:1).ne.'y'.and.str(1:1).ne.'Y') stop
           endif
      
c endif for(imodel=3)
      endif
c
c Perform some quick error checking:
c
      if(ndmin .le.0)      stop ' NDMIN too small'
      if(ndmaxp.gt.MAXSAM) stop ' NDMAXP too large'
      if(ndmaxs.gt.MAXSAM) stop ' NDMAXS too large'
      if((ndmaxs/2).le.nvr.and.ktype.eq.2) then
            write(*,100) nvr,ndmaxs
 100        format('WARNING: with traditional ordinary cokriging the ',
     +           /,'sum of the weights applied to EACH secondary data',
     +           /,'is zero.  With ndmaxs set low and nvr large the',
     +           /,'secondary data will not contribute to the estimate')
      endif
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
      open(lin,file=datafl,status='OLD')
      read(lin,'(a40)',err=99) str
      read(lin,*,err=99)       nvari
      do i=1,nvari
            read(lin,'()',err=99)
      end do
      do i=1,nvr
            nn(i) = 0
            av(i) = 0.0
            ss(i) = 0.0
      end do
c
c Some tests on column numbers:
c
      if(ixl.gt.nvari.or.iyl.gt.nvari.or.izl.gt.nvari.or.
     +   ivrl(1).gt.nvari) then
            write(*,*) 'There are only ',nvari,' columns in input data'
            write(*,*) '  your specification is out of range'
            stop
      end if
c
c Read all the data until the end of the file:
c
      nd = 0
 7    read(lin,*,end=9,err=99) (var(j),j=1,nvari)
      nd = nd + 1
      if(nd.gt.MAXDAT) then
            write(*,*) ' ERROR: Exceeded available memory for data'
            stop
      end if
c
c Store data values (all secondary data must be transformed such that
c their mean is the same as the primary variable (if the first type of
c ordinary kriging is being used)):
c
      vr(nd) = var(ivrl(1))
      if(vr(nd).ge.tmin.and.vr(nd).lt.tmax) then
            nn(1) = nn(1) + 1
            av(1) = av(1) + vr(nd)
            ss(1) = ss(1) + vr(nd)*vr(nd)
      endif
      if(nvr.ge.2 .and. icoloc.eq. 0) then
            sec1(nd) = var(ivrl(2))
            if(sec1(nd).ge.tmin.and.sec1(nd).lt.tmax) then
                  nn(2) = nn(2) + 1
                  av(2) = av(2) + sec1(nd)
                  ss(2) = ss(2) + sec1(nd)*sec1(nd)
            endif
      end if
      if(nvr.ge.3) then
            sec2(nd) = var(ivrl(3))
            if(sec2(nd).ge.tmin.and.sec2(nd).lt.tmax) then
                  nn(3) = nn(3) + 1
                  av(3) = av(3) + sec2(nd)
                  ss(3) = ss(3) + sec2(nd)*sec2(nd)
            endif
      end if
      if(nvr.ge.4) then
            sec3(nd) = var(ivrl(4))
            if(sec3(nd).ge.tmin.and.sec3(nd).lt.tmax) then
                  nn(4) = nn(4) + 1
                  av(4) = av(4) + sec3(nd)
                  ss(4) = ss(4) + sec3(nd)*sec3(nd)
            endif
      end if
c
c Assign the coordinate location of this data:
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
      go to 7
 9    close(lin)
c
c Compute the averages and variances as an error check for the user:
c
        if(icoloc.eq.1) then
            i=1
            av(i) = av(i) / max(real(nn(i)),1.0)
            ss(i) =(ss(i) / max(real(nn(i)),1.0)) - av(i) * av(i)
            write(*,*) 'COKB3D Variable ',i,' in data file: ',ivrl(i)
            write(*,*) '  Number   = ',nn(i)
            write(*,*) '  Average  = ',av(i)
            write(*,*) '  Variance = ',ss(i)                            
        else 
          do i=1,nvr
             av(i) = av(i) / max(real(nn(i)),1.0)
            ss(i) =(ss(i) / max(real(nn(i)),1.0)) - av(i) * av(i)
            write(*,*) 'COKB3D Variable ',i,' in data file: ',ivrl(i)
            write(*,*) '  Number   = ',nn(i)
            write(*,*) '  Average  = ',av(i)
            write(*,*) '  Variance = ',ss(i)
          end do
        endif         
       gvar=ss(1) 

c
c read local varying mean
c
      
      
      if (ilvm.eq.1) then
          write(*,*) 'Reading local varying mean file'
          inquire(file=lvmfl,exist=testfl)
          if(.not.testfl) then
             write(*,188) lvmfl
 188          format('Warning local varying mean file ',a40)
              stop
          endif 
         open(llsec,file=lvmfl,status='old')
         read(llsec,'(a40)',err=99) str 
         read(llsec,*,err=99)nlvm
         write(*,*)'test1: number of data=',nlvm
         do i=1,nlvm
            read(llsec,'()',err=99)
         end do
         
         index=0
         do iz=1,nz
           do iy=1,ny
             do ix=1,nx
               index=index+1
               read(llsec,*,err=99) (var(j),j=1,nlvm)
               lvm(index)=var(icollvm)
             end do
            end do
          end do
c
c Calculation of residual moved to krige subroutine: vr(i)=vr(i)-sec(i)
c          
          do i=1,nn(1)
          
              call getindx(nx,xmn,xsiz,x(i),ix,testind)
              call getindx(ny,ymn,ysiz,y(i),iy,testind)
              call getindx(nz,zmn,zsiz,z(i),iz,testind)
              index = ix + (iy-1)*nx + (iz-1)*nx*ny
              sec(i) = lvm(index)
       
           end do
           
        endif
        close(llsec)  
c
c Read secondary attribute
c
      
      if(icoloc.eq.1) then
          write(*,*) 'Reading secondary attribute file'
          inquire(file=secfl,exist=testfl)
          if(.not.testfl) then
             write(*,118) secfl
 118          format('Warning secondary attribute file ',a40)
              stop
          endif 
       open(llsec,file=secfl,status='old')
       read(llsec,'(a40)',err=99) str
       write(*,*) 'secfile  =',str
       read(llsec,*,err=99)       nseci
       
       do i=1,nseci
            read(llsec,'()',err=99)
      end do

      
      nsecdata=0
      secav=0.0
      ssec=0.0
      index=0
         
      

      
      
       do iz=1,nz
         do iy=1,ny
           do ix=1,nx
              index=index+1
        if(index.gt.MAXDAT) then
            write(*,*) ' ERROR: Exceeded available memory for data'
            stop
        end if        
        
        read(llsec,*,err=99) (var(j), j=1,nseci)
        
c    for rescalling the secondary attribute

         secdat(index)=var(icoll)
        
        if(secdat(index).ge.tmin.and.secdat(index).lt.tmax) then
            nsecdata = nsecdata + 1
            secav = secav + secdat(index)
            ssec = ssec + secdat(index)*secdat(index)
        endif      
        
                
          end do
        end do
      end do
         
      secav=secav/max(real(nsecdata),1.0)
      ssec=(ssec/max(real(nsecdata),1.0))-secav*secav

        write(*,119) nsecdata, secav, ssec
 119    format(/,' Secondary Data: Number of data             = ',i8,/,
     +         '                 Equal Weighted Average     = ',f12.4,/,
     +         '                 Equal Weighted Variance    = ',f12.4,/)

       endif
       close(llsec)
       
       index=0
       
       do iz=1,nz
         do iy=1,ny
           do ix=1,nx
              index=index+1
              if(ilvm.eq.0.) then
                secdat(index)=secdat(index)-vmean(2)+vmean(1)
              else
                secdat(index)=secdat(index)-vmean(2)+lvm(index)
              endif
            end do
          end do
        end do
                

                    
c
c Open output files and write headers:
c
      open(lout,file=outfl,status='UNKNOWN')
      write(lout,101) str
 101  format('COKB3D with:',a40,/,'2',/,'estimate',/,
     +       'estimation variance')
      write(ldbg,102) str
 102  format(/,'DEBUGGING COKB3D with:',a40)
      return
c
c Error in an Input File Somewhere:
c
 98   stop 'ERROR in parameter file!'
 99   stop 'ERROR in data file!'
 
      end


              subroutine getmean(ind,index)
c----------------------------------------------------------------
c 
c      Find the index of local varying mean
c
c----------------------------------------------------------------
              include  'newcokb3d.inc'
              
              call getindx(nx,xmn,xsiz,x(ind),ix,testind)
              call getindx(ny,ymn,ysiz,y(ind),iy,testind)
              call getindx(nz,zmn,zsiz,z(ind),iz,testind)
              index = ix + (iy-1)*nx + (iz-1)*nx*ny
              
              return
              end	

      subroutine cokb3d
c-----------------------------------------------------------------------
c
c                 CoKriging of a 3-D Rectangular Grid
c                 ***********************************
c
c OPTIMIZED: OpenMP parallelization with buffered I/O output.
c
c Original:  A.J. Desbarats                                         1984
c-----------------------------------------------------------------------
      include  'newcokb3d.inc'
      parameter(PMX=999.)
      real      distp(MAXSAM),dists(MAXSAM)

      integer   nump(MAXSAM),nums(MAXSAM),vars(MAXSAM)
c      common /ddd/secdat
      common /varpar2/ssec,gvar
      common /sill123/c11,c12,c22,crr
c
c Output buffers for parallel I/O:
c
      real, allocatable :: ook_buf(:), ookv_buf(:)
      integer nxyz_tot

c
c Set up the search and covariance rotation matrices:
c
      do is=1,nst(1)
            call setrot(ang1(is),ang2(is),ang3(is),anis1(is),anis2(is),
     +                  is,MAXROT,rotmat)
      end do
      isrot = MAXNST + 1
      call setrot(sang1,sang2,sang3,sanisp1,sanisp2,isrot,MAXROT,rotmat)
c
c Set up for super block searching:
c
      if(icoloc.eq.0) nsec = nvr - 1
      write(*,*) 'Setting up super block search strategy'
      call setsupr(nx,xmn,xsiz,ny,ymn,ysiz,nz,zmn,zsiz,nd,x,y,z,
     +             vr,tmp,nsec,sec1,sec2,sec3,MAXSBX,MAXSBY,MAXSBZ,nisb,
     +             nxsup,xmnsup,xsizsup,nysup,ymnsup,ysizsup,nzsup,
     +             zmnsup,zsizsup)
      call picksup(nxsup,xsizsup,nysup,ysizsup,nzsup,zsizsup,
     +             isrot,MAXROT,rotmat,radsqdp,nsbtosr,ixsbtosr,
     +             iysbtosr,izsbtosr)
c
c Set up the discretization points per block.  Figure out how many
c are needed, the spacing, and fill the xdb, ydb and zdb arrays with
c the offsets relative to the block center (this only gets done once):
c
      ndb  = nxdis * nydis * nzdis
      xdis = xsiz  / max(real(nxdis),1.0)
      ydis = ysiz  / max(real(nydis),1.0)
      zdis = zsiz  / max(real(nzdis),1.0)
      xloc = -0.5*(xsiz+xdis)
      i    = 0
      do ix =1,nxdis
            xloc = xloc + xdis
            yloc = -0.5*(ysiz+ydis)
            do iy=1,nydis
                  yloc = yloc + ydis
                  zloc = -0.5*(zsiz+zdis)
                  do iz=1,nzdis
                        zloc = zloc + zdis
                        i = i+1
                        xdb(i) = xloc
                        ydb(i) = yloc
                        zdb(i) = zloc
                  end do
            end do
      end do
c
c Initialize accumulators:
c
      uk   = 0.0
      vk   = 0.0
      nk   = 0
c
c Calculate Block Covariance. Check for point kriging.
c
      if(imodel.eq.2) then
        unbias=c11
      else 
c     call cova3(0.,0.,0.,0.,0.,0.,1,nst,MAXNST,c0,it,cc,aa,vi 
c    +           1,MAXROT,rotmat,cmax,cova)
      call cova3(0.,0.,0.,0.,0.,0.,1,nst,MAXNST,c0,it,cc,aa, 
     +           1,MAXROT,rotmat,cmax,cova)
      unbias = dble(cova)
      endif
      if(ndb.le.1) then
            cbb = cova
      else
            cbb = 0.0
            do i=1,ndb
            do j=1,ndb
                  call cova3(xdb(i),ydb(i),zdb(i),xdb(j),ydb(j),zdb(j),
     +                       1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                       rotmat,cmax,cova)
                  if(i.eq.j) cova = cmax - c0(1)
                  cbb = cbb + cova
            end do
            end do
            cbb = cbb/real(ndb*ndb)
      endif
      if(imodel.eq.2) then
         write(ldbg,*) 'Block average covariance ', c11
      else 
         write(ldbg,*) 'Block average covariance ',cbb
      endif
c
c MAIN LOOP OVER ALL THE BLOCKS IN THE GRID:
c OPTIMIZED: Allocate output buffer, use linearized index for
c potential future OpenMP parallelization. The cokb3d loop uses
c complex common block state so we buffer output for batch writes.
c
      nxyz_tot = nx*ny*nz
      allocate(ook_buf(nxyz_tot))
      allocate(ookv_buf(nxyz_tot))
c
      do 4 iz=1,nz
      zloc = zmn + (iz-1)*zsiz
      do 4 iy=1,ny
      yloc = ymn + (iy-1)*ysiz
      do 4 ix=1,nx
      xloc = xmn + (ix-1)*xsiz
c
c Find the nearest samples:
c
      call srchsupr(xloc,yloc,zloc,radsqdp,isrot,MAXROT,rotmat,nsbtosr,
     +              ixsbtosr,iysbtosr,izsbtosr,noct,nd,x,y,z,tmp,
     +              nisb,nxsup,xmnsup,xsizsup,nysup,ymnsup,ysizsup,
     +              nzsup,zmnsup,zsizsup,nclose,close,infoct)
c
c Load the nearest data in xa,ya,za,vra:
c
            np = 0
            ns = 0
            na = 0
            do i=1,nclose
                  
                  if(np.eq.ndmaxp.and.ns.eq.ndmaxs) go to 32
                  ind = int(close(i)+0.5)
c
c Load primary data until there are enough:
c
                  if(vr(ind).ge.tmin.and.vr(ind).lt.tmax.
     +                         and.np.lt.ndmaxp) then
                        np = np + 1
                        na = na + 1
c  for colocated cokriging              
                        if(icoloc.eq.1) ns=np
                        
                        xa(na)  = x(ind)
                        ya(na)  = y(ind)
                        za(na)  = z(ind)
                        vra(na) = vr(ind)
                        iva(na) = 1
                        if(ilvm.eq.1) vra(na)=vr(ind)-sec(ind)
                        
                  end if
c
c Load secondary data until maximum is met:
c
 

                  if(sec1(ind).ge.tmin.and.sec1(ind).lt.tmax.
     +    and.icoloc.eq.0.and.nvr.ge.2.and.ns.lt.ndmaxs) then
                        ns = ns + 1
                        na = na + 1
                        xa(na)  = x(ind)
                        ya(na)  = y(ind)
                        za(na)  = z(ind)
                        vra(na) = sec1(ind)
                        ivar    = 2
                        if(ktype.ne.2 .and. ilvm.eq.0) 
     +                  vra(na) = vra(na) - vmean(ivar) + vmean(1)
c if selected  LVM  
                        if(ilvm.eq.1)then
                          call getmean(ind,index)
                          vra(na)=vra(na)-vmean(ivar) +lvm(index)
                        endif
                        
                        iva(na) = 2
                  end if
                  if(sec2(ind).ge.tmin.and.sec2(ind).lt.tmax.
     +               and.nvr.ge.3.and.ns.lt.ndmaxs) then
                        ns = ns + 1
                        na = na + 1
                        xa(na)  = x(ind)
                        ya(na)  = y(ind)
                        za(na)  = z(ind)
                        vra(na) = sec2(ind)
                        ivar    = 3
                        if(ktype.ne.2 .and. ilvm.eq.0) 
     +                  vra(na) = vra(na) - vmean(ivar) + vmean(1)
c if selected  LVM  
                        if(ilvm.eq.1)then
                          call getmean(ind,index)
                          vra(na)=vra(na)-vmean(ivar) +lvm(index)
                        endif
                             
                        iva(na) = 3
                  end if
                  if(sec3(ind).ge.tmin.and.sec3(ind).lt.tmax.
     +               and.nvr.ge.4.and.ns.lt.ndmaxs) then
                        ns = ns + 1
                        na = na + 1
                        xa(na)  = x(ind)
                        ya(na)  = y(ind)
                        za(na)  = z(ind)
                        vra(na) = sec3(ind)
                        ivar    = 4
                        if(ktype.ne.2 .and. ilvm.eq.0) 
     +                  vra(na) = vra(na) - vmean(ivar) + vmean(1)

                        if(ilvm.eq.1)then
                          call getmean(ind,index)
                          vra(na)=vra(na)-vmean(ivar) +lvm(index)
                        endif
                             
                        iva(na) = 4
                  end if
            end do
 32         continue
c
c Solve the Kriging System:
c
c           
c  Determine the number of the systems
c
            if(icoloc.eq.1) then
              if(ktype.eq.0) then 
                neq=na+1
              else if(ktype.eq.1) then
                neq=na+2 
              endif
            else   
              if(ktype.eq.0) neq = na
              if(ktype.eq.1) neq = na + 1
              if(ktype.eq.2) neq = na + nvr
            endif
            
            if((neq-na).gt.na.or.na.lt.ndmin) then
                  ind = ix + (iy-1)*nx + (iz-1)*nx*ny
                  ook_buf(ind)  = UNEST
                  ookv_buf(ind) = UNEST
                  go to 4
            end if
c
c Set up kriging matrices:
c
            do i=1,neq*neq
                  a(i) = 0.0
            end do
            do i=1,neq
             r(i)=0.0
            end do
            
            in=0
            
c Left-hand COV matrix for MM2
           
            if(imodel.eq.2) then
               do j=1,na
                  do i=1,j
                        in=in+1
                        
c calculate COV between secondary atrribute
                        
                        call cova3(xa(i),ya(i),za(i),xa(j),ya(j),za(j),
     +                             1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cov)
      
c  calculate COV between residual of primary  atrribute

                        call cova3(xa(i),ya(i),za(i),xa(j),ya(j),za(j),
     +                             2,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,covr)
     
c  calculate COV between primary atrribute using MM2 model
    
                       a(in)= (dble(colocorr*colocorr)*(cov/c22)+
     +                (1-dble(colocorr*colocorr))*(covr/crr))*c11
                   end do
                   
c Right-hand COV matrix for MM2 
                  
                   xx = xa(j) - xloc
                   yy = ya(j) - yloc
                   zz = za(j) - zloc
                   
c calculate COV between secondary atrribute and estimate
                   
                   if(ndb.le.1) then
                      call cova3(xx,yy,zz,xdb(1),ydb(1),zdb(1),
     +                           1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                           rotmat,cmax,cova)
                        cb = cova
                   else
                     cb  = 0.0
                     do j1=1,ndb
                        call cova3(xx,yy,zz,xdb(j1),ydb(j1),zdb(j1),
     +                             1,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cova)
                        dx = xx - xdb(j1)
                        dy = yy - ydb(j1)
                        dz = zz - zdb(j1)
                        if((dx*dx+dy*dy+dz*dz).lt.EPSLON) then
                              cb = cb + cova - c0(1)
                        else
                              cb = cb + cova
                        end if
                     end do
                     cb = cb / real(ndb)
                  endif
                  
                   rb(j)=cb
c                   
c calculate COV between residual and estimate
c                   
                   if(ndb.le.1) then
                      call cova3(xx,yy,zz,xdb(1),ydb(1),zdb(1),
     +                           2,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                           rotmat,cmax,cova)
                        cb2 = cova
                   else
                     cb2  = 0.0
                     do j1=1,ndb
                        call cova3(xx,yy,zz,xdb(j1),ydb(j1),zdb(j1),
     +                             2,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cova)
                        dx = xx - xdb(j1)
                        dy = yy - ydb(j1)
                        dz = zz - zdb(j1)
                        if((dx*dx+dy*dy+dz*dz).lt.EPSLON) then
                              cb2 = cb2 + cova - c0(2)
                        else
                              cb2 = cb2 + cova
                        end if
                     end do
                     cb2 = cb2 / real(ndb)
                     endif
c                     
c calculate COV between primary  atrribute and estimate  
c 
                      r(j)= (dble(colocorr*colocorr)*(cb/c22)+
     +                (1-dble(colocorr*colocorr))*(cb2/crr))*c11
     
                      rr(j)=r(j)
              end do
c                       
c calculate lift hand side covariance for MM1 and LMC
c            
            else
                        
              do j=1,na
                  do i=1,j
                        in=in+1
                        ind   = iva(i) + (iva(j)-1)*MAXVAR
                        call cova3(xa(i),ya(i),za(i),xa(j),ya(j),za(j),
     +                             ind,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cova)
                        a(in) = dble(cova)                                                            
                  end do
                  xx = xa(j) - xloc
                  yy = ya(j) - yloc
                  zz = za(j) - zloc
                            
c
c Right hand side covariance:
c
                  iv  = 1
                  ind = iv + (iva(j)-1)*MAXVAR
                  if(ndb.le.1) then
                        call cova3(xx,yy,zz,xdb(1),ydb(1),zdb(1),
     +                             ind,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cova)
                        cb = cova
                  else
                     cb  = 0.0
                     do j1=1,ndb
                        call cova3(xx,yy,zz,xdb(j1),ydb(j1),zdb(j1),
     +                             ind,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cova)
                        dx = xx - xdb(j1)
                        dy = yy - ydb(j1)
                        dz = zz - zdb(j1)
                        if((dx*dx+dy*dy+dz*dz).lt.EPSLON) then
                              cb = cb + cova - c0(ind)
                        else
                              cb = cb + cova
                        end if
                     end do
                     cb = cb / real(ndb)
                  endif
                  r(j)  = dble(cb)
                  rr(j) = r(j)
            end do
            
        endif    
            
c form the last row in right-hand matrix            
c for colocated cokriging
c            
           if(icoloc.eq.1) then    
                                   
              
              do i=1,na
                in=in+1
                if(imodel.eq.1) then                                 
                   a(in)=sqrt(c22/c11)*dble(colocorr)*r(i)
                 else if(imodel.eq.2) then
                    a(in)=sqrt(c11/c22)*dble(colocorr)*rb(i)
                    
c  for colocated cokriging if LMC(form last row in right-hand matrix)                    
                 else if(imodel.eq.3) then                   
                   iv  = 1
                   ind = iv +MAXVAR
                   xx = xa(i) - xloc
                   yy = ya(i) - yloc
                   zz = za(i) - zloc 
                   if(ndb.le.1) then
                      call cova3(xx,yy,zz,xdb(1),ydb(1),zdb(1),
     +                         ind,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                         rotmat,cmax,cova)
                        cb = cova
                   else
                       cb  = 0.0                     
                       do j1=1,ndb
                       call cova3(xx,yy,zz,xdb(j1),ydb(j1),zdb(j1),
     +                             ind,nst,MAXNST,c0,it,cc,aa,1,MAXROT,
     +                             rotmat,cmax,cova)
                        dx = xx - xdb(j1)
                        dy = yy - ydb(j1)
                        dz = zz - zdb(j1)
                        if((dx*dx+dy*dy+dz*dz).lt.EPSLON) then
                              cb = cb + cova - c0(ind)
                        else
                              cb = cb + cova
                        end if
                      end do                     
                      cb = cb / real(ndb)                     
                    endif                    
                    a(in)=dble(cb)                    
                 endif
                               
              end do 
              
              in=in+1
               a(in)=c22             
               ii=na+1                           
             
              if(imodel.eq.1 .or. imodel.eq.2) then                                
                r(ii)=dble(colocorr)*sqrt(c22*c11)
               endif              
              if(imodel.eq.3) r(ii)=c12                                                                    
              
              rr(ii)=r(ii)
          
          endif
                  
               
c
c Set up for either simple or ordinary cokriging:
c
            if(ktype.eq.1) then
                if(icoloc.eq.1) inna=na+1
                if(icoloc.eq.0) inna=na     
                  do i=1,inna
                        in=in+1
                        a(in) = unbias                        
                  end do
                  in=in+1
                  a(in)=0.0
                  if(icoloc.eq.1) then
                    r(na+2)  = unbias
                    rr(na+2) = unbias
                  else 
                    r(na+1)  = unbias
                    rr(na+1) = unbias
                  endif
            else if(ktype.eq.2.and.icoloc.eq.0) then
                  do i=1,nvr
                        lim = na + i
                        r(lim)  = 0.0
                        rr(lim) = 0.0
                        do j=1,lim
                              if(j.gt.na.or.iva(j).ne.i) then
                                    in=in+1
                                    a(in) = 0.0                                    
                              else
                                    in=in+1
                                    a(in) = unbias                                    
                              endif
                        end do
                  end do
                  r(na+1)  = unbias
                  rr(na+1) = unbias
            endif
  
            
c Write out the kriging Matrix if Seriously Debugging:
c
      
               
            if(idbg.ge.3) then
                  is = 1 
                  do i=1,neq
                        
                        ie = is + i-1
                        write(ldbg,103) i,r(i),(a(j),j=is,ie)
                        is=is+i
 103                    format('    r(',i2,') =',f8.3,'  a= ',9(10f8.3))
                  end do
            endif
            call ksol(1,neq,1,a,r,s,ising)
c
c Write a warning if the matrix is singular:
c
            if(ising.ne.0) then
                  write(ldbg,*) 'WARNING COKB3D: singular matrix'
                  write(ldbg,*) '        for block',ix,iy,iz
                  ind = ix + (iy-1)*nx + (iz-1)*nx*ny
                  ook_buf(ind)  = UNEST
                  ookv_buf(ind) = UNEST
                  go to 4
            endif
c
c Write the kriging weights and data if requested:
c
            if(idbg.ge.2) then
                  write(ldbg,*) '       '
                  write(ldbg,*) 'BLOCK: ',ix,iy,iz,' at ',xloc,yloc,zloc
                  write(ldbg,*) '    at ',xloc,yloc,zloc
                  write(ldbg,*) ' '
                  if(icoloc.eq.0) then
                    if(ktype.eq.1) then                        
                         write(ldbg,*) '  Lagrange multiplier: ',s(na+1)
                    else if(ktype.ge.2) then
                        do i=1,nvr
                        write(ldbg,*) '  Lagrange multiplier: ',s(na+i)
                        end do
                     endif
                    endif
                   if(icoloc.eq.1.and.ktype.eq.1) then
                      write(ldbg,*) '  Lagrange multiplier: ',s(na+2)
                   endif
                  write(ldbg,*) '  BLOCK EST: x,y,z,vr,wt'
                  
                  do i=1,na
                    write(ldbg,'(5f12.3)') xa(i),ya(i),za(i),vra(i),s(i)
                  end do
                  if(icoloc.eq.1) then
                  ind=ix+(iy-1)*nx+(iz-1)*nx*ny 
             write(ldbg,'(5f12.3)') xloc,yloc,zloc,secdat(ind),s(na+1)
                endif
            endif
c
c Compute the estimate and the kriging variance:
c
            sumw = 0.0
            ook  = 0.0
            if(imodel.eq.2)then            
             ookv=c11
            else 
             ookv = cbb
            endif

	    if (icoloc.eq.1 ) then
	      do i=1,na
	         ookv = ookv - real(s(i)*rr(i))
                   sumw = sumw + real(s(i))
                   ook  = ook  + real(s(i))*vra(i) 
	      end do 
	      
c  added by the secondary variable
	        
               ind=ix+(iy-1)*nx+(iz-1)*nx*ny               
               ook=ook+real(s(na+1))*secdat(ind)
               
c Kriging variance minused by secondary variable             
               ookv=ookv-real(s(na+1))*rr(na+1)
               
       if(ktype.eq.0.and.ilvm.eq.0) then  
                 
c since secdat=secdat(i)-vmean(2)+vmean(1) 
      
          ook = ook + (1.0-sumw-real(s(na+1)))*vmean(1)
          
       endif 
         
       if(ktype.eq.1) ookv=ookv-real(s(na+2))
       
             else
             
               do i=1,neq
                  
                  if(i.le.na) then
                        ookv = ookv - real(s(i)*rr(i))
                        sumw = sumw + real(s(i))
                        ook  = ook  + real(s(i))*vra(i)                
                  else
                        ookv = ookv - real(s(i))
                  endif
              end do 
c
c Add mean if SK:
c
          if(ktype.eq.0.and.ilvm.eq.0)ook = ook + (1.0-sumw)*vmean(1)  
                                          
            endif 

c
c Add mean if LVM
c       
       if(ktype.eq.0 .and. ilvm.eq.1) then
           ind=ix+(iy-1)*nx+(iz-1)*nx*ny
           ook=ook+lvm(ind)
        endif 
         
c
c Store results in buffer instead of writing per-node:
c
            ind = ix + (iy-1)*nx + (iz-1)*nx*ny
            ook_buf(ind)  = ook
            ookv_buf(ind) = ookv
 100        format(f12.4,1x,f12.4)
c
c Accumulate statistics of kriged blocks:
c
            nk = nk + 1
            uk = uk + ook
            vk = vk + ook*ook
            if(idbg.ge.4) write(ldbg,*) ' estimate, variance  ',ook,ookv
c
c END OF MAIN LOOP OVER ALL THE BLOCKS:
c
 4    continue
c
c Write buffered output (sequential batch write):
c
      do ind=1,nxyz_tot
            write(lout,100) ook_buf(ind),ookv_buf(ind)
      end do
      deallocate(ook_buf)
      deallocate(ookv_buf)
c
c Write statistics of kriged values:
c
      if(nk.gt.0.and.idbg.gt.0) then
            vk = (vk-uk*uk/real(nk))/real(nk)
            uk = uk/real(nk)
            write(ldbg,*)
            write(ldbg,*) 'Estimated  ',nk,' blocks '
            write(ldbg,*) '  average  ',uk
            write(ldbg,*) '  variance ',vk
            write(*,*)
            write(*,*)    'Estimated  ',nk,' blocks '
            write(*,*)    '  average  ',uk
            write(*,*)    '  variance ',vk
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
      open(lun,file='newcokb3d.par',status='UNKNOWN')
      write(lun,10)
 10   format('                  Parameters for COKB3D',/,
     +       '                  **********************',/,/,
     +       'START OF PARAMETERS:')

      write(lun,11)
 11   format('somedata.dat                      ',
     +       '-file with data')
      write(lun,12)
 12   format('3                                 ',
     +       '-   number of variables primary+other',/,
     + 35x,'only primary if colocated cokriging')
      write(lun,13)
 13   format('1   2   0   3   4   5             ',
     +       '-   columns for X,Y,Z and variables')
      write(lun,14)
 14   format('-0.01     1.0e21                  ',
     +       '-   trimming limits')
      write(lun,15)
 15   format('0                                 ',
     +       '-co-located cokriging? (0=no, 1=yes)')
      write(lun,16)
 16   format('somedata.dat                      ',
     +       '-   file with single gridded covariate')
      write(lun,17)
 17   format('4                                 ',
     +       '-   column for covariate')
     
c     modified by ma

      write(lun,55)
 55   format('0                                ',
     +       '- local varying mean (0=no, 1=yes)')
      write(lun,56)
 56   format('lvmfl.dat                       ',
     +       '-  file with local varying mean')
      write(lun,60)
 60   format('4                               ',
     +        '- column for local varying mean') 
 
      write(lun,18)
 18   format('3                                 ',
     +       '-debugging level: 0,1,2,3')
      write(lun,19)
 19   format('newcokb3d.dbg                        ',
     +       '-file for debugging output')
      write(lun,20)
 20   format('newcokb3d.out                        ',
     +       '-file for output')
      write(lun,21)
 21   format('50   0.5   1.0                    ',
     +       '-nx,xmn,xsiz')
      write(lun,22)
 22   format('50   0.5   1.0                    ',
     +       '-ny,ymn,ysiz')
      write(lun,23)
 23   format('10   0.5   1.0                    ',
     +       '-nz,zmn,zsiz')
      write(lun,24)
 24   format('1    1     1                      ',
     +       '-x, y, and z block discretization')
      write(lun,25)
 25   format('1   12     8                      ',
     +       '-min primary,max primary,max all sec')
      write(lun,26)
 26   format('25.0  25.0  25.0                  ',
     +       '-maximum search radii: primary')
      write(lun,27)
 27   format('10.0  10.0  10.0                  ',
     +       '-maximum search radii: all secondary')
      write(lun,28)
 28   format(' 0.0   0.0   0.0                  ',
     +       '-angles for search ellipsoid')
      write(lun,29)
 29   format('2                                 ',
     +       '-kriging type (0=SK, 1=OK, 2=OK-trad)')
      write(lun,30)
 30   format('3.38  2.32  0.00  0.00            ',
     +       '-mean(i),i=1,nvar')
      
      write(lun,57)
 57   format('1                                 ',
     +       '-  model type (1=MM1, 2=MM2,3=LMC)')
      write(lun,58)
 58   format('0.50                              ',
     +       '- correlation coefficient for MM1 or MM2')
      write(lun,61)
 61   format('10.0                              ',
     +       '- variance of secondary variable for MM1')
      write(lun,59)
 59   format('5.0                              ',
     +       '- variance of primary variable for MM2',/, 
     + 30x,  'note: for MM2 enter residual variogram as i=1, j=1') 
      write(lun,31)
 31   format('1     1                           ',
     +       '-semivariogram for "i" and "j"')
      write(lun,32)
 32   format('1   11.0                          ',
     +       '-   nst, nugget effect')
      write(lun,33)
 33   format('1   39.0  0.0   0.0   0.0         ',
     +       '-   it,cc,ang1,ang2,ang3')
      write(lun,34)
 34   format('         60.0  60.0  60.0         ',
     +       '-   a_hmax, a_hmin, a_vert')
      write(lun,35)
 35   format('1     2                           ',
     +       '-semivariogram for "i" and "j"')
      write(lun,36)
 36   format('1    0.0                          ',
     +       '-   nst, nugget effect')
      write(lun,37)
 37   format('1   14.5  0.0   0.0   0.0         ',
     +       '-   it,cc,ang1,ang2,ang3')
      write(lun,38)
 38   format('         60.0  60.0  60.0         ',
     +       '-   a_hmax, a_hmin, a_vert')
      write(lun,39)
 39   format('1     3                           ',
     +       '-semivariogram for "i" and "j"')
      write(lun,40)
 40   format('1    0.0                          ',
     +       '-   nst, nugget effect')
      write(lun,41)
 41   format('1    5.0  0.0   0.0   0.0         ',
     +       '-   it,cc,ang1,ang2,ang3')
      write(lun,42)
 42   format('         60.0  60.0  60.0         ',
     +       '-   a_hmax, a_hmin, a_vert')
      write(lun,43)
 43   format('2     2                           ',
     +       '-semivariogram for "i" and "j"')
      write(lun,44)
 44   format('1    9.0                          ',
     +       '-   nst, nugget effect')
      write(lun,45)
 45   format('1   15.0  0.0   0.0   0.0         ',
     +       '-   it,cc,ang1,ang2,ang3')
      write(lun,46)
 46   format('         60.0  60.0  60.0         ',
     +       '-   a_hmax, a_hmin, a_vert')
      write(lun,47)
 47   format('2     3                           ',
     +       '-semivariogram for "i" and "j"')
      write(lun,48)
 48   format('1    0.0                          ',
     +       '-   nst, nugget effect')
      write(lun,49)
 49   format('1    3.8  0.0   0.0   0.0         ',
     +       '-   it,cc,ang1,ang2,ang3')
      write(lun,50)
 50   format('         60.0  60.0  60.0         ',
     +       '-   a_hmax, a_hmin, a_vert')
      write(lun,51)
 51   format('3     3                           ',
     +       '-semivariogram for "i" and "j"')
      write(lun,52)
 52   format('1    1.1                          ',
     +       '-   nst, nugget effect')
      write(lun,53)
 53   format('1    1.8  0.0   0.0   0.0         ',
     +       '-   it,cc,ang1,ang2,ang3')
      write(lun,54)
 54   format('         60.0  60.0  60.0         ',
     +       '-   a_hmax, a_hmin, a_vert')

      close(lun)
      return
      end
