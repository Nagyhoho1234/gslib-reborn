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
c                Direct Sequential Simulation
c                ******************************
c
c The program is executed with no command line arguments.  The user
c will be prompted for the name of a parameter file.  The parameter
c file is described in the documentation (see the example sgsim.par)
c
c The output file will be a GEOEAS file containing the simulated values
c The file is ordered by x,y,z, and then simulation (i.e., x cycles
c fastest, then y, then z, then simulation number).  The simulation values
c can be transformed to reproduce a target histogram.
c
c
c
c-----------------------------------------------------------------------
      include  'dssim.inc'
c
c Input/Output units used:
c
      lin  = 1
      lout = 2
      ldbg = 3
      llvm = 4
      lkv  = 5
c
c Read the parameters and data (transform as required):
c
      call readparm

c     
c  setup the krige estimation variance matrix for honoring the local data 
c  (conditional simulation) if it is to be calculated in stead of read
c  from a seperate file.  
c     
      write(ldbg,*) 'icond=', icond
      if(icond.eq.1.and.ivar.eq.0) then
        call setup_krgvar
	write(*,*) 'Kriging variance calculated'
      end if 

c
c  open the output file (with large buffer for I/O optimization)
c
      open(lout,file=outfl,status='UNKNOWN')

      if(itrans.eq.1) then 
    	  write(lout,109)
      else 
          write(lout,108)
      end if 
 
 108  format('DSSIM Realizations without trans',/,'1',/,'value')  
 109  format('DSSIM Realizations with trans',/,'1',/,'value')
 


c
c  begin the actual simulation 
c

c
c Pre-read target histogram before parallel loop if needed:
c
      if(itrans.eq.1) then
            call pre_trans
      end if

      do isim =1, nsim
c
c call dssim for the simulation(s):
c
         call dssim

	 if(itrans.eq.1) then
c
c Call trans to reproduce the target histogram
c
            call trans
         end if
      end do

      close(lout)

c
c Finished:
c
      write(*,9998) VERSION
 9998 format(/' DSSIM - GSLIB2-OPT v',f7.1, ' Finished'/)
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
      include  'dssim.inc'
      real      var(50)
      real*8    p,acorni,cp,oldcp,w
      character tmpfl*40,datafl*40,btfl*40,
     +          dbgfl*40,lvmfl*40,str*40
      logical   testfl
c
c Note VERSION number:
c
      write(*,9999) VERSION
 9999 format(/' DSSIM - GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)
c
c Get the name of the parameter file - try the default name if no input:
c
      write(*,*) 'Which parameter file do you want to use?'
      read (*,'(a40)') str
      if(str(1:1).eq.' ')str='dssim.par                               '
      inquire(file=str,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR - the parameter file does not exist,'
            write(*,*) '        check for the file and try again  '
            write(*,*)
            if(str(1:20).eq.'dssim.par           ') then
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

      read(lin,*,err=98) icond
      write(*,*) ' conditional simulation = ', icond

      read(lin,'(a40)',err=98) datafl
      call chknam(datafl,40)
      write(*,*) ' data file = ',datafl

      read(lin,*,err=98) ixl,iyl,izl,ivrl,iwt,isecvr
      write(*,*) ' input columns = ',ixl,iyl,izl,ivrl,iwt,isecvr

      read(lin,*,err=98) tmin,tmax
      write(*,*) ' trimming limits = ',tmin,tmax

      read(lin,*,err=98) idbg
      write(*,*) ' debugging level = ',idbg

      read(lin,'(a40)',err=98) dbgfl
      call chknam(dbgfl,40)
      write(*,*) ' debugging file = ',dbgfl
      open(ldbg,file=dbgfl,status='UNKNOWN')

      read(lin,'(a40)',err=98) outfl
      call chknam(outfl,40)
      write(*,*) ' output file ',outfl

      read(lin,*,err=98) nsim
      write(*,*) ' number of realizations = ',nsim

      read(lin,*,err=98) idrawopt
      write(*,*) ' Conditional distribution type = ', idrawopt

      read(lin,'(a40)',err=98) btfl
      if (idrawopt .eq. 2) then
        call chknam(btfl,40)
      	write(*,*) ' Bootstrap file = ',btfl
      end if

      read(lin,*,err=98) ibt,ibtw
      write(*,*) ' input columns for bootstrap file = ',ibt,ibtw

      read(lin,*,err=98) nx,xmn,xsiz
      write(*,*) ' X grid specification = ',nx,xmn,xsiz

      read(lin,*,err=98) ny,ymn,ysiz
      write(*,*) ' Y grid specification = ',ny,ymn,ysiz

      read(lin,*,err=98) nz,zmn,zsiz
      write(*,*) ' Z grid specification = ',nz,zmn,zsiz

      nxy  = nx*ny
      nxyz = nx*ny*nz

      read(lin,*,err=98) ixv(1)
      write(*,*) ' random number seed = ',ixv(1)
            p = real(acorni(idum))
      do i=1,1000
             p = real(acorni(idum))
      end do


      if(idbg.ge.2) then
         write(ldbg,*) 'The random seed value p=', p
      end if 

      read(lin,*,err=98) ndmin,ndmax
      write(*,*) ' min and max data = ',ndmin,ndmax

      read(lin,*,err=98) nodmax
      write(*,*) ' maximum previous nodes = ',nodmax

      read(lin,*,err=98) sstrat
      write(*,*) ' two-part search flag = ',sstrat
      if(sstrat.eq.1) ndmax = 0

      read(lin,*,err=98) mults,nmult
      write(*,*) ' multiple grid search flag = ',mults,nmult

      read(lin,*,err=98) noct
      write(*,*) ' number of octants = ',noct

      read(lin,*,err=98) radius,radius1,radius2
      write(*,*) ' search radii = ',radius,radius1,radius2
      if(radius.lt.EPSLON) stop 'radius must be greater than zero'
      radsqd = radius  * radius
      sanis1 = radius1 / radius
      sanis2 = radius2 / radius

      read(lin,*,err=98) sang1,sang2,sang3
      write(*,*) ' search anisotropy angles = ',sang1,sang2,sang3

      read(lin,*,err=98) ktype 
      write(*,*) ' kriging type = ',ktype
      
      colocorr = 1.0
      if(ktype.eq.4) then
            backspace lin
            read(lin,*,err=98) ktype,colocorr
            varred = 1.0
            backspace lin
            read(lin,*,err=9990) i,xx,varred
 9990       continue
            write(*,*) ' correlation coefficient = ',colocorr
            write(*,*) ' secondary variable varred = ',varred
      end if
	
      read(lin,*,err=98) skgmean, gvar 
      write(*,*) ' kriging type = ',ktype

	
      read(lin,'(a40)',err=98) lvmfl
      call chknam(lvmfl,40)
      write(*,*) ' secondary model file = ',lvmfl

      read(lin,*,err=98) icollvm
      write(*,*) ' column in secondary model file = ',icollvm

      read(lin,*,err=98) nst(1),c0(1)
      sill = c0(1)
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
            sill     = sill + cc(i)
            if(it(i).eq.4) then
                  write(*,*) ' A power model is NOT allowed '
                  write(*,*) ' Choose a different model and re start '
                  stop
            endif
            write(*,*) ' it,cc,ang[1,2,3]; ',it(i),cc(i),
     +                   ang1(i),ang2(i),ang3(i)
            write(*,*) ' a1 a2 a3: ',aa(i),aa1,aa2
      end do


      read(lin, *, err=98) itrans
      write(*,*) ' Use trans after simulation ? ', itrans

      
      if(itrans.eq.1) then 
        read(lin,'(a40)',err=98) distin
        call chknam(distin,40)
        write(*,*) ' reference distribution = ',distin

        read(lin, * ,err=98) ivrr, iwtr
        write(*,*) ' columns = ',ivrr,iwtr

        write(*,*) ' columns = ',ivrr,iwtr 
 
c        read(lin,*,err=98) wx, wy, wz
c        write(*,*) ' window size of model to transform = ',wx,wy,wz

        read(lin,*,err=98) zmin,zmax
        write(*,*) ' data limits (tails) = ',zmin,zmax

        read(lin,*,err=98) ltail,ltpar
        write(*,*) ' lower tail option = ',ltail,ltpar
 
        read(lin,*,err=98) utail,utpar
        write(*,*) ' upper tail option = ',utail,utpar
	 
c  
c  If conditional simulation is specified, read in the krg. var mvar
    
        if(icond.eq.1) then
            read(lin,*,err=98) ivar
            write(*,*) 'read in the estimation variance=', ivar 
      
            read(lin,'(a40)',err=98) localfl
            call chknam(localfl,40)
            write(*,*) ' local file = ',localfl
      
            read(lin,*,err=98) icoll
            write(*,*) ' column for kriging variance = ',icoll
      
            read(lin,*,err=98) wtfac
            write(*,*) ' scaling factor = ',wtfac

	    
	    read(lin,*,err=98) pkr
            write(*,*) ' Adding local accuracy % = ',100*pkr

c
c Scale from 0 to 1  --> 0.33 to 3.0
c   
c            wtfac = 0.33 + wtfac*(3.0-0.33)
        end if 
c
c  End of reading in for honoring local data (conditional simulation)
c

      end if      
c 
c  End of reading in for trans after direct sequential simulation
c  


      close(lin)

c
c Perform some quick error checking for grid size and tail option:
c
      testfl = .false.
      if(nx.gt.MAXX.or.ny.gt.MAXY.or.nz.gt.MAXZ) then
            write(*,*) 'ERROR: available grid size: ',MAXX,MAXY,MAXZ
            write(*,*) '       you have asked for : ',nx,ny,nz
            testfl = .true.
      end if
      if(itrans.eq.1) then 
        if(ltail.ne.1.and.ltail.ne.2) then
            write(*,*) 'ERROR invalid lower tail option ',ltail
            write(*,*) '      only allow 1 or 2 - see manual '
            testfl = .true.
        endif
        if(utail.ne.1.and.utail.ne.2.and.utail.ne.4) then
            write(*,*) 'ERROR invalid upper tail option ',ltail
            write(*,*) '      only allow 1,2 or 4 - see manual '
            testfl = .true.
        endif
        if(utail.eq.4.and.utpar.lt.1.0) then
            write(*,*) 'ERROR invalid power for hyperbolic tail',utpar
            write(*,*) '      must be greater than 1.0!'
            testfl = .true.
        endif
        if(ltail.eq.2.and.ltpar.lt.0.0) then
            write(*,*) 'ERROR invalid power for power model',ltpar
            write(*,*) '      must be greater than 0.0!'
            testfl = .true.
        endif
        if(utail.eq.2.and.utpar.lt.0.0) then
            write(*,*) 'ERROR invalid power for power model',utpar
            write(*,*) '      must be greater than 0.0!'
            testfl = .true.
        endif
      endif
      if(testfl) stop


c
c If conditional simulation,  check to make sure the data file exists if
c If unconditional simulation, set necessary parameters 
c
      nd = 0
      av = 0.0
      ss = 0.0
      if(icond.eq.1) then 
        inquire(file=datafl,exist=testfl)
        if(.not.testfl) then
             write(*,*) 'WARNING data file ',datafl,' does not exist!'
             write(*,*) 'If you want to create conditional simulation',   
     +                  'please check whether you have specified ', 
     +                  'the correct filename '
	     write(*,*) 'If you want to create an unconditional simulation ',
     +                  'please reset icond = 0'
	      stop
        end if
      else
        inquire(file=datafl,exist=testfl) 
        datafl='nodata'
	if(testfl) then
	   write(*,*) 
	   write(*,*) 'WARNING: You are doing unconditional simulation',
     + 		      ' the filename of conditioning data has been reset',
     +  	      ' to be nodata. Next time, please set it to nodata',
     +                ' if you are doing unconditioning simulation.' 
	endif 
	ndmin  = 0
        ndmax  = 0 
        sstrat = 1
      end if 		


c
c Read in the conditioning data for the simulation: 
c 
c

c
c Now, read the data if conditional simulation is specified:
c

        inquire(file=datafl,exist=testfl)
        if(testfl) then
            write(*,*) 'Reading input data'
            open(lin,file=datafl,status='OLD')
            read(lin,*,err=99)
            read(lin,*,err=99) nvari
            do i=1,nvari
                  read(lin,*,err=99)
            end do
            if(ixl.gt.nvari.or.iyl.gt.nvari.or.izl.gt.nvari.or.
     +         ivrl.gt.nvari.or.isecvr.gt.nvari.or.iwt.gt.nvari) then
                  write(*,*) 'ERROR: you have asked for a column number'
                  write(*,*) '       greater than available in file'
                  stop
            end if


         write(*,*) 'read data '
c
c Read all the conditioning data until the end of the file:
c
            twt = 0.0
            nd  = 0
            nt  = 0
 5          read(lin,*,end=6,err=99) (var(j),j=1,nvari)
            if(var(ivrl).lt.tmin.or.var(ivrl).ge.tmax) then
                  nt = nt + 1
                  go to 5
            end if
            nd = nd + 1

            if(nd.gt.MAXDAT) then
                  write(*,*) ' ERROR exceeded MAXDAT - check inc file'
                  stop
            end if
c
c Acceptable data, assign the value, X, Y, Z coordinates, and weight:
c
            vr(nd) = var(ivrl)
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


            if(iwt.le.0) then
                  wt(nd) = 1.0
            else
                  wt(nd) = var(iwt)
            endif


            if(isecvr.le.0) then
                  sec(nd) = UNEST
            else
                  sec(nd) = var(isecvr)
            endif

            twt = twt + wt(nd)
            av  = av  + var(ivrl)*wt(nd)
            ss  = ss  + var(ivrl)*var(ivrl)*wt(nd)
            go to 5
 6          close(lin)

c
c Compute the averages and variances as an error check for the user:
c
            av = av / max(twt,EPSLON)
            ss =(ss / max(twt,EPSLON)) - av * av
            write(ldbg,111) nd,nt,av,ss
            write(*,   111) nd,nt,av,ss
 111  format(/,' Conditioning Data for DSSIM: ', 
     +         'Number of acceptable data = ',i8,/,
     +         '                 Number trimmed             = ',i8,/,
     +         '                 Weighted Average           = ',f12.4,/,
     +         '                 Weighted Variance          = ',f12.4,/)
      endif


c
c In case the local conditional distribution is obtained from bootstrap (idrawopt=2)
c  read the file that is used in the bootstrap 
c


      if(idrawopt .eq. 2) then
	    nbt = 0
	    twt = 0.0
	    av = 0.0
 	    ss = 0.0
            inquire(file=btfl,exist=testfl)
            if(.not.testfl) then
                  write(*,1004) btfl
 1004             format('WARNING bootstrap file ',a40,
     +             ' does not exist!')
                  stop
            end if

	    open(lin,file=btfl,status='OLD')
            read(lin,*,err=999)
            read(lin,*,err=999) nvarbt
            do i=1,nvarbt
                  read(lin,*,err=999)
            end do

		

55          read(lin,*,end=66,err=999) (var(j),j=1,nvarbt)


	    nbt = nbt + 1
            if(nbt.gt.MAXDAT) then
            write(*,*) ' ERROR exceeded MAXDAT for bootstrap'
            stop
            end if

	    bootvar(nbt) = var(ibt)
	    if (ibtw .eq. 0) then 
			bootwt(nbt) = 1.0
	    else
			bootwt(nbt) = var(ibtw)
	    end if

            twt = twt + bootwt(nbt)
            av  = av  + bootvar(nbt)*bootwt(nbt)
            ss  = ss  + bootvar(nbt)*bootvar(nbt)*bootwt(nbt)
		
	    go to 55
66	    close(lin)


            btmean = av / max(twt,EPSLON)
            btvar = (ss / max(twt,EPSLON)) - btmean*btmean
            write(ldbg,1111) nbt,btmean,btvar
            write(*,   1111) nbt,btmean,btvar

 1111    format(/,' Bootstrap Data for DSSIM: ', 
     +         'Number of bootstrap data = ',i8,/,
     +         '        Bootstrap Weighted Average           = ',f12.4,/,
     +         '        Bootstrap Weighted Variance          = ',f12.4)

	    call sortem(1,nbt,bootvar,1,bootwt,c,d,e,f,g,h)

	    sumwt = 0.0
	    do i = 1, nbt
		bootwt(i) = bootwt(i)/(twt+1)
		sumwt = sumwt + bootwt(i)
		bootcdf(i) = sumwt 
	    end do

      end if	



c
c Read secondary attribute model if lvm, exdr and colc kriging is used:
c Please note that secondary variable file must be gridded with secondary
c variable values at each grid node. 
 
      if(ktype.ge.2) then
            write(*,*) 'Reading secondary attribute file'
            inquire(file=lvmfl,exist=testfl)
            if(.not.testfl) then
                  write(*,104) lvmfl
 104              format('WARNING secondary attribute file ',a40,
     +             ' does not exist!')
                  stop
            end if
            open(llvm,file=lvmfl,status='OLD')
            read(llvm,*,err=97)
            read(llvm,*,err=97) nvaril
            do i=1,nvaril
                  read(llvm,*,err=97)
            end do
            index = 0
             
            av = 0.0
            ss = 0.0
            do iz=1,nz
                  do iy=1,ny
                        do ix=1,nx
                           index = index + 1
                           read(llvm,*,err=97) (var(j),j=1,nvaril)
                           lvm(index) = var(icollvm)
                           sim(index) = real(index)
                           av = av + var(icollvm)
                           ss = ss + var(icollvm)*var(icollvm)
                        end do
                  end do
            end do
            av = av / max(real(nxyz),1.0)
            ss =(ss / max(real(nxyz),1.0)) - av * av
            write(ldbg,112) nxyz,av,ss
            write(*,   112) nxyz,av,ss
 112  format(/,' Secondary Data: Number of data             = ',i8,/,
     +         '                 Equal Weighted Average     = ',f12.4,/,
     +         '                 Equal Weighted Variance    = ',f12.4,/)


cc When using kriging with locally varying mean (LVM, ktype=2), the
cc array lvm() denotes the mean m(u) at every grid node, while sec() 
cc denotes the mean at sample data location u_{alpha}.  In order to do
cc kriging, we need the mean m(u_{alpha}) at sample data location
cc u_{alpha}. In lvm, m(u_{alpha}) is usually not given
cc at sample data location, but m(u) is available at a regular 
cc grid. That is why we copy nearest m(u) to  m(u_{alpha}) 
cc given in the lvmfl file. 

            if(ktype.eq.2) then
                  do i=1,nd
                        call getindx(nx,xmn,xsiz,x(i),ix,testind)
                        call getindx(ny,ymn,ysiz,y(i),iy,testind)
                        call getindx(nz,zmn,zsiz,z(i),iz,testind)
                        index = ix + (iy-1)*nx + (iz-1)*nxy
                        sec(i) = lvm(index)
c
c Calculation of residual moved to krige subroutine: vr(i)=vr(i)-sec(i)
c
                  end do
            end if



cc When using kriging with external drift (EXDR, ktype=3), lvm()
cc usually denotes a smoothly varying secondary variable at grid 
cc locations u given in the file lvmfl, while sec() denotes  sec. 
cc variable at sample data location u_{alpha}. In order to do kriging
cc with EXDR, you need to know the sec. variable information both at 
cc grid node u and sample data location u_{alpha}. In the case when sec.
cc variable info. sec() at sample data location u_{alpha} is not read
cc from the sample data file datafl, i.e. (sec(i)=UNEST), it will copy
cc the secondary variable information from the nearest grid node to this
cc sample location.

            if(ktype.eq.3) then
                  do i=1,nd
                        if(sec(i).eq.UNEST) then
                              call getindx(nx,xmn,xsiz,x(i),ix,testind)
                              call getindx(ny,ymn,ysiz,y(i),iy,testind)
                              call getindx(nz,zmn,zsiz,z(i),iz,testind)
                              index = ix + (iy-1)*nx + (iz-1)*nxy
                              sec(i) = lvm(index)
                        end if
                  end do
            end if


c 
c In the case of collocated kriging(COLC, ktype=4), we need secondary
c variable information at the gridded node. It must be provided by the
c sec. attribute model file lvmfl at each grid node. 
c           


      end if

      return

c
c Error in an Input File Somewhere:
c
 97   stop 'ERROR in secondary data file!'
 98   stop 'ERROR in parameter file!'
 99   stop 'ERROR in data file!'
 999  stop 'ERROR in bootstrap file!'
      end





      subroutine setup_krgvar
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c    								    c	
c								    c	
c          Set up the Kriging Variance Matrix 
c          ***********************************
c 
c If conditional simulation is made and the kriging variance 
c matrix is calculated in stead of being read from a user specified 
c file(localfl), then the kriging variance matrix is set up for future
c use in trans. 
c
c inovar:  number of grid node that can not be reached by kriging
c          radius search
c zmaxvar: max kriging variance that can be obtained.
c novar(): location index for those grid node that can not be reached.
c
c
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      include  'dssim.inc'

      real*8   acorni
      logical testind

c
c The variogram model specified in the parameter file is used for
c simulation. The radius for search of neighboring data points is usually
c small in the case of because both sample data and previously simulated 
c nodes are available for conditioning. However we need a larger radius to do
c kriging search to set up the kriging variance matrix if needed.  Hence
c in calculating the kriging variance for use in trans, we will
c increase the radius by 1.5. This will decrease the possibility that
c remote unknown location is not reached by the kriging search.   
c 

      radsqd = radsqd * 1.5 * 1.5


c   
c Set up the rotation/anisotropy matrices that are needed for the
c variogram and search.
c

      write(*,*) 'Setting up kriging variance'
	
                  
      write(ldbg,*) 'Setting up rotation matrices',
     +              ' for variogram and search'
      do is=1,nst(1)
            call setrot(ang1(is),ang2(is),ang3(is),anis1(is),anis2(is),
     +                  is,MAXROT,rotmat)
      end do
      isrot = MAXNST + 1
      call setrot(sang1,sang2,sang3,sanis1,sanis2,isrot,MAXROT,rotmat)  

c
c Set up the super block search:
c
      if(sstrat.eq.0) then
            write(ldbg,*) 'Setting up super block search strategy'
            nsec = 1
            call setsupr(nx,xmn,xsiz,ny,ymn,ysiz,nz,zmn,zsiz,nd,x,y,z,
     +                   vr,wt,nsec,sec,sec2,sec3,MAXSBX,MAXSBY,MAXSBZ,
     +                   nisb,nxsup,xmnsup,xsizsup,nysup,ymnsup,ysizsup,
     +                   nzsup,zmnsup,zsizsup)
            call picksup(nxsup,xsizsup,nysup,ysizsup,nzsup,zsizsup,
     +                   isrot,MAXROT,rotmat,radsqd,nsbtosr,ixsbtosr,
     +                   iysbtosr,izsbtosr)
      end if

c
c Set up the covariance table and the spiral search:
c
      call ctable

c
c Initialize the grid:
c
            do ind=1,nxyz
                  sim(ind) = UNEST
            end do


c 
c Assign sample data to the closest grid node if it is specified:
c

            TINY = 0.0001

            do id=1,nd
                  call getindx(nx,xmn,xsiz,x(id),ix,testind)
                  call getindx(ny,ymn,ysiz,y(id),iy,testind)
                  call getindx(nz,zmn,zsiz,z(id),iz,testind)
                  ind = ix + (iy-1)*nx + (iz-1)*nxy
                  xx  = xmn + real(ix-1)*xsiz
                  yy  = ymn + real(iy-1)*ysiz   
                  zz  = zmn + real(iz-1)*zsiz
                  test = abs(xx-x(id)) + abs(yy-y(id)) + abs(zz-z(id))

c
c Assign this sample data to the nearest node unless there is a closer
c sample data:
c 
            
                  if(sstrat.eq.1) then
                        if(sim(ind).ge.0.0) then
                              id2 = int(sim(ind)+0.5)
                              test2 = abs(xx-x(id2)) + abs(yy-y(id2))
     +                                               + abs(zz-z(id2))
                              if(test.le.test2) sim(ind) = real(id)
                              write(ldbg,102) id,id2
                        else
                              sim(ind) = real(id)
                        end if
                  end if

c
c In the case of not assigning data to nearest grid node, if it
c is too close to a grid node (<TINY) then assign flag with very negative
c value. The kriging variance at this node will be 0    
c
                  if(sstrat.eq.0.and.test.le.TINY) sim(ind)=10.0*UNEST
            end do
c
c          finish the loop over all the sample data
c


 102        format(' WARNING data values ',2i5,' are both assigned to ',
     +           /,'         the same node - taking the closest')

c
c Now, enter data values into the grid:
c

            do ind=1,nxyz
                  id = int(sim(ind)+0.5)
                  if(id.gt.0) sim(ind) = vr(id)
c
c If the case when no data are assgned to grid node, then nclose = 0.    
c

            end do
            irepo = max(1,min((nxyz/10),10000))

c
c MAIN LOOP OVER ALL THE NODES TO GET THE KRIGING VARIANCE:
c
c
c In this part of the code, each grid node is accessed by its spatial
c order without any random path. At each grid node, the kriging variance 
c is calculated.  If no data are assigned to the grid node, the kriging
c variance will still be calculated but the result will be none zero
c unless the grid is very close to the sample data location (<TINY). If 
c data are assigned to the nearest location, then at that grid node
c location the kriging variance will be zero.  
c

            if (idbg.ge.3) then
	       write(ldbg, *) 'Sample data location and grid search'    
	    end if   


            inovar = 0
            zmaxvar = 0                        
            do in=1,nxyz
                  index = int(in+0.5)
	          if (idbg.ge.3) then 
                    WRITE(ldbg, *) 'SIM(', INDEX, ')=', SIM(INDEX)
		  end if 
c
c (sim(index).gt.(UNEST+EPSLON)) is satisfied when data are assigned to
c the nearest grid node as specified by sstrat=1 option. 
c (sim(index).lt.(UNEST*2.0)) is satisfied when data is too close to grid
c node in the case when data are not assign to the grid node(sstrat=0)
c

                  if(sim(index).gt.(UNEST+EPSLON).or.
     +               sim(index).lt.(UNEST*2.0)) then
                     krgvar(index) = 0.0 
                     go to 5
                  end if 
                  iz = int((index-1)/nxy) + 1  
                  iy = int((index-(iz-1)*nxy-1)/nx) + 1
                  ix = index - (iz-1)*nxy - (iy-1)*nx
                  xx = xmn + real(ix-1)*xsiz
                  yy = ymn + real(iy-1)*ysiz
                  zz = zmn + real(iz-1)*zsiz
            
c
c Now we will do the neighboring data location and grid node search. 
c In the case when data are not assigned to grid node (sstrat=0),
c srchsupr is only conducted to find the nearest sample data. 
c In the case when data are assigned to grid node (sstrat=1), 
c srchnd is conducted to find the nearest grid node data. 

                  if(sstrat.eq.0) then
                        call srchsupr(xx,yy,zz,radsqd,isrot,MAXROT,
     +                          rotmat,nsbtosr,ixsbtosr,iysbtosr,
     +                          izsbtosr,noct,nd,x,y,z,wt,nisb,nxsup,
     +                          xmnsup,xsizsup,nysup,ymnsup,ysizsup,
     +                          nzsup,zmnsup,zsizsup,nclose,close,
     +                          infoct)
                        WRITE(ldbg, *) 'There are nclose=', nclose, 
     +                                 ' in the search radius.'

c When there are less than 2 data within the search radius, the kriging
c system will not give a correct variance calculation. Instead, we assign
c the max variance value from those grid node where kriging variance can
c be calculated. 

                        if(nclose.lt.2) then
                           inovar = inovar + 1
                           novar(inovar) = in
                           go to 5
                        endif
                        if(nclose.gt.ndmax) nclose = ndmax
                     else
                        call srchnd(ix,iy,iz)
                        if(idbg.ge.3) then
                           WRITE(ldbg, *) 'There are ncnode=', ncnode,
     +                          ' in the search radius.'
                        end if
                        if(ncnode.lt.2) then
                           inovar = inovar + 1
                           novar(inovar) = in
                           go to 5
                        endif
                        if(ncnode.gt.nodmax) ncnode = nodmax 
                     end if 
                     
                  
                     if(ktype.eq.2) then
                        gmean = lvm(index)
                     else
                        gmean = skgmean   
                     end if
                     

                     
                     
c     
c     Perform the kriging.  Note that if there are fewer than four data
c     in the case of ordinary kriging, then simple kriging is prefered so that
c     the variance of the realization does not become artificially inflated:
c     
                     lktype = ktype 
                     if(ktype.eq.1.and.(nclose+ncnode).lt.4)lktype=0   
c     
c     global mean (skgmean) is still needed for OK when there are fewer than 4
c     data within the search radius
c     
                     call krige(ix,iy,iz,xx,yy,zz,lktype,
     +                    gmean,cmean,cstdev)
                     
                     
                     krgvar(index) = cstdev * cstdev 
                     if (krgvar(index).ge.zmaxvar) zmaxvar=krgvar(index)                  
 5                   continue
                  end do 
c     
c     MAIN LOOP OVER ALL THE NODES TO GET THE KRIGING VARIANCE:
c     
c     
c     For those nodes that have not been visited, the previous max variance
c     will be assigned.
c 
                  
                  
                  do in=1, inovar
                     index= novar(in)
                     krgvar(index) = zmaxvar
                  end do
                  
                  if(idbg.ge.3) then 
                     write(*,*) 'The kriging variance at',
     +                    ' each grid node is', 
     +                    ' given as follows'
                  do itt=1, nxyz
                  write(ldbg,*) 'node index =', itt, 'kriging variace', 
     +               ' =', krgvar(itt) 
                  end do 
                  end if 
                  
                  radsqd = radsqd/1.5/1.5
                  
c     
c     At the end of kriging variance calculation, the radius is decreased back
c     to the original radius intended for simulation.
c     
                  return
                  end               
      
      
      
      
      
      subroutine dssim
c-----------------------------------------------------------------------
c     
c     Conditional Simulation of a 3-D Rectangular Grid
c     ************************************************
c     
c     This subroutine generates 3-D realizations of a sequential process with
c     a given autocovariance model, and conditional to input sample data.
c     The conditional simulation is achieved by sequential simulation of all
c     the nodes visited by a random path.
c     
c     
c
c     PROGRAM NOTES:
c     
c     1. The three dimensional anisotropy parameters, i.e., of the search
c     ellipse and variogram ranges are described in section 2.3 of the
c     manual.   The variogram parameters are described in the same place
c     
c     2. The original data and previously simulated grid nodes can be
c     searched separately.  There can be a different maximum number of
c     each and a minimum number of original data can be specified
c     to restrict simulation beyond the limits of the data.  The
c     closeness of previously simulated grid nodes is measured according
c     to the variogram structural distance.
c     
c     
c     
c     INPUT VARIABLES:
c     
c     nd               Number of data (no missing values)
c     x,y,z(nd)        coordinates of the data
c     vr(nd)           sample data 
c     
c     nx,ny,nz         Number of blocks in X,Y, and Z
c     xmn,ymn,zmn      Coordinate at the center of the first Block
c     xsiz,ysiz,zsiz   spacing of the grid nodes (block size)
c     
c     nsim             number of simulations
c     sim              the current realization across the field
c     idbg             integer debugging level (0=none,2=normal,4=serious)
c     ldbg             unit number for the debugging output
c     lout             unit number for the output
c     
c     radius           Maximum search radius
c     sang1            Azimuth angle of the principal search direction
c     sang2            Dip angle of the principal search direction
c     sang3            Third rotation angle of the search ellipse
c     sanis1           Anisotropy for the dip angle
c     sanis2           Anisotropy for the plunge angle
c     ndmin            Minimum number of data required before sim
c     ndmax            Maximum number of samples for simulation
c     noct             Maximum number per octant if an octant search is
c     desired (if <= 0, then no octant search)
c     
c     nodmax           Maximum number of previously simulated grid nodes
c     to consider in the simulation.  The structural
c                      variogram distance is used to identify close ones
c     
c     c0               Nugget constant (isotropic).
c     cc(nst)          Multiplicative factor of each nested structure.
c     aa(nst)          Parameter "a" of each nested structure.
c     it(nst)          Type of nested structures (1=sph,2=exp,3=gau,4=pow)
c     ang1(nst)        Azimuth angle for the principal direction
c     ang2(nst)        Dip angle for the principal direction
c     ang3(nst)        Third rotation angle to rotate the two minor
c     directions around the principal direction
c     anis1(nst)       Anisotropy (radius in minor direction at 90
c     degrees from "ang1" divided by the principal
c     radius in direction "ang1")
c     anis2(nst)       Anisotropy (radius in minor direction at 90 degrees
c     vertical from "ang1" divided by the principal
c     radius in direction "ang1")
c     
c     
c OUTPUT VARIABLES:  Simulated Values are written to "lout"
c     
c     
c
c EXTERNAL REFERENCES:
c
c     super            Sets up the super block search of original data
c     search           Search for nearby data values
c     ctable           Builds a covariance table and "spiral" search
c     srchnd           Search for nearby simulated grid nodes
c     sqdist           computes anisotropic squared distance
c     sortem           sorts multiple arrays in ascending order (separate)
c     cova3            Calculates the covariance given a variogram model
c     krige            Sets up and solves either the SK or OK system
c     ksol             Linear system solver using Gaussian elimination
c
c     
c     
c     Concepts taken from F. Alabert and E. Isaaks
c     
c-----------------------------------------------------------------------
      include  'dssim.inc'
      real      randnu(1),var(10)
      real*8    p,acorni,cp,oldcp,w
      logical   testind

c
      open(8, file='checkord.dat', status = 'unknown')


c
c Set up the rotation/anisotropy matrices that are needed for the
c variogram and search.
c
                  
      write(ldbg,*) 'Setting up rotation matrices',
     +     ' for variogram and search'
      do is=1,nst(1)
         call setrot(ang1(is),ang2(is),ang3(is),anis1(is),anis2(is), 
     +        is,MAXROT,rotmat)   
      end do
      isrot = MAXNST + 1
      call setrot(sang1,sang2,sang3,sanis1,sanis2,isrot,MAXROT,rotmat)
      
c     
c     Set up the super block search:
c     
      if(sstrat.eq.0) then
         write(ldbg,*) 'Setting up super block search strategy'
         nsec = 1
         call setsupr(nx,xmn,xsiz,ny,ymn,ysiz,nz,zmn,zsiz,nd,x,y,z,
     +        vr,wt,nsec,sec,sec2,sec3,MAXSBX,MAXSBY,MAXSBZ,
     +        nisb,nxsup,xmnsup,xsizsup,nysup,ymnsup,ysizsup,
     +        nzsup,zmnsup,zsizsup)
         call picksup(nxsup,xsizsup,nysup,ysizsup,nzsup,zsizsup,
     +        isrot,MAXROT,rotmat,radsqd,nsbtosr,ixsbtosr,
     +        iysbtosr,izsbtosr)
      end if
      
c     
c     Set up the covariance table and the spiral search:
c     
      call ctable
      
      
c     In the case of a collocated cokriging, secondary variable is avalaible
c     at every grid for each realization.  Read in the secondary data
c     distribution for realization number larger than 1. The secondary data
c     for the first relization has already been read in read_par subroutine. 
      
      if(isim.gt.1.and.ktype.eq.4) then
         write(*,*)
         write(*,*) ' Reading next secondary model'
         index = 0
         do iz=1,nz
            do iy=1,ny
               do ix=1,nx
                  index = index + 1
                  read(llvm,*,end=977)(var(j),j=1,nvaril)
                  lvm(index) = var(icollvm)
                  sim(index) = real(index)
               end do
            end do
         end do
         write(*,*) ' Building CDF from secondary model'
         call sortem(1,nxyz,lvm,1,sim,c,d,e,f,g,h)
         oldcp = 0.0
         cp    = 0.0
         do i=1,nxyz
            cp =  cp + dble(1.0/real(nxyz))
            w  = (cp + oldcp)/2.0
            lvm(i) = lvm(i) * w 
            oldcp  =  cp
         end do
         write(*,*) ' Restoring order of secondary model'
         call sortem(1,nxyz,sim,1,lvm,c,d,e,f,g,h)
 977     continue
      end if
c     
c     Work out a random path for this realization:
c     
      do ind=1,nxyz
         sim(ind)   = real(acorni(idum))
         order(ind) = ind
      end do
      p=real(acorni(idum))

c
c     The multiple grid search works with multiples of 4 (yes, that is
c     somewhat arbitrary):
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
c     Initialize the simulation:
c     
      do ind=1,nxyz
         sim(ind) = UNEST
      end do
      write(*,*)
      write(*,*) 'Working on realization number ',isim
c     
c     Assign the sample data to the closest grid node:
c     
      TINY = 0.0001
c      write(ldbg,*) nd
      do id=1,nd
         call getindx(nx,xmn,xsiz,x(id),ix,testind)
         call getindx(ny,ymn,ysiz,y(id),iy,testind)
         call getindx(nz,zmn,zsiz,z(id),iz,testind)
         ind = ix + (iy-1)*nx + (iz-1)*nxy
         xx  = xmn + real(ix-1)*xsiz
         yy  = ymn + real(iy-1)*ysiz
         zz  = zmn + real(iz-1)*zsiz
         
c         WRITE(ldbg,*) X(ID), Y(ID), Z(ID)
c         WRITE(ldbg,*) IX, IY, IZ
c         WRITE(ldbg,*) XX, YY, ZZ
         
c   coordinates of x, y and z
c     
                test = abs(xx-x(id)) + abs(yy-y(id)) + abs(zz-z(id))
c     
c     Assign sample data to the closest grid node unles there is a close data:
c     
                
                if(sstrat.eq.1) then
                   if(sim(ind).ge.0.0) then
                      id2 = int(sim(ind)+0.5)
                      test2 = abs(xx-x(id2)) + abs(yy-y(id2))
     +                     + abs(zz-z(id2))
                      if(test.le.test2) sim(ind) = real(id)
                      write(ldbg,102) id,id2
                   else
                      sim(ind) = real(id)
                   end if
                end if
                
                
c     
c     In case when data are not assigned to grid node, Assign a
c     flag(10.0*UNEST) with a very negative value, so that this node does not
c     get simulated:
c     
                if(sstrat.eq.0.and.test.le.TINY) sim(ind)=10.0*UNEST
             end do
c     c This is the end of loop over all sample data id=1,nd
             
             
 102         format(' WARNING data values ',2i5,' are both assigned to ',
     +            /,'         the same node - taking the closest')
             
c     
c     Now, enter data values into the simulated grid in the case when data
c     are assigned to grid node, when (id.gt.0) satisfies.  
c     
             do ind=1,nxyz
                id = int(sim(ind)+0.5)
                if(id.gt.0) sim(ind) = vr(id)
             end do
             irepo = max(1,min((nxyz/10),10000))
             
             
c     
c     MAIN LOOP OVER ALL THE NODES:
c     
             
             print*, 'ok before the main loop?'
             
             neg = 0
             nsmall0 = 0
             nsmall = 0
            nlarge = 0
            

            do in=1,nxyz
               if(in/1000*1000 .eq.in) write(*,103)in
 103           format('   currently on node ',i9)
               
c     WRITE(ldbg, *) 'currently on ', in
               
c     
c     Figure out the location of this point and make sure it has
c     not been assigned a value already:
c     
               
c     order() keeps the simulation random path
               
               index = int(order(in)+0.5)
               WRITE(ldbg, *) 'SIM(', INDEX, ')=', SIM(INDEX)
                  if(sim(index).gt.(UNEST+EPSLON).or.
     +              sim(index).lt.(UNEST*2.0)) go to 5
c     If data are not assigned to grid node (sstrat=0), grid that is too close
c     to data will be skipped by (sim(index).lt.(UNEST*2.0)). Later it will
c     be reassigned by the very close grid node  
c     If data assigned to grid node (sstrat=1), grid node that has been 
c     a positive value will be the grid node that has received the sample
c     valeu or a grid node that has been visited. 
                  
c                  write(ldbg,*) nxy, nx 
                  iz = int((index-1)/nxy) + 1
                  iy = int((index-(iz-1)*nxy-1)/nx) + 1
                  ix = index - (iz-1)*nxy - (iy-1)*nx
                  xx = xmn + real(ix-1)*xsiz
                  yy = ymn + real(iy-1)*ysiz
                  zz = zmn + real(iz-1)*zsiz
                  
c     write(ldbg,*) iz, iy, ix
c     write(ldbg,*) zz, yy, xx
                  
c     
c     Now, we'll simulate the point ix,iy,iz.  First, get the close data
c     and make sure that there are enough to actually simulate a value,
c     we'll only keep the closest "ndmax" data, and look for previously
c     simulated grid nodes:
c     
                  if(sstrat.eq.0) then
c     write(ldbg,*) 'call srchsupr'
                     call srchsupr(xx,yy,zz,radsqd,isrot,MAXROT,
     +                    rotmat,nsbtosr,ixsbtosr,iysbtosr,
     +                    izsbtosr,noct,nd,x,y,z,wt,nisb,nxsup,
     +                    xmnsup,xsizsup,nysup,ymnsup,ysizsup,
     +                    nzsup,zmnsup,zsizsup,nclose,close,
     +                    infoct)
                     if (idbg.ge.3) then
                        WRITE(ldbg, *) 'There are nclose=',nclose,
     +                       ' in the search radius',
     +                       ' for grid ', index 
                     end if 
                     if(nclose.lt.ndmin) then
c     assign global mean and variance.
                        cmean = skgmean   
                        cstdev = sqrt(gvar)
                        go to 51
                     endif 
                     if(nclose.gt.ndmax) nclose = ndmax
                  endif
                  call srchnd(ix,iy,iz)
                  if (idbg.ge.0) then
                     WRITE(ldbg, *) 'There are ncnode=', ncnode,
     +                    ' in the search radius',
     +                    ' for grid ', index
                  end if
                  
                  
c     
c     Calculate the conditional mean and standard deviation.  This will be
c     done with kriging if there are enough data, otherwise, the global mean
c     and standard deviation will be used:
c     
                  if(ktype.eq.2) then
                     gmean = lvm(index)
                  else
                     gmean = skgmean
                  end if
                  
 51	    	  continue
                  
                  
c     double check for not enough data with search radius. 
                  
                  if((nclose+ncnode).lt.1) then
            WRITE(ldbg,*) ' WARNING: neighboring data points and',
     +                    ' grid node have not been found.', 
     +                    ' Global mean and variance is assigned.'
                     cmean  = gmean 
                     cstdev = sqrt(gvar)
                  else
                     
                     if (idbg.ge.3) then
                        WRITE(ldbg,*) 'cmean=', cmean, 'cstdev=', cstdev   
                     end if
                     
                     
c     
c     Perform the kriging.  Note that if there are fewer than four data 
c     in the case of ordinary kriging, then simple kriging is prefered so
c     that the variance of the realization does not become artificially
c     inflated:
c     
                     lktype = ktype
                     if(ktype.eq.1.and.(nclose+ncnode).lt.4)lktype=0
                     call krige(ix,iy,iz,xx,yy,zz,lktype,
     +                    gmean,cmean,cstdev)
                  endif
                  
c     WRITE(ldbg,*) 'cmean=', cmean, 'cstdev=', cstdev
                  
c     
c     Draw a value from the uniform distribution having conditional mean and
c     variance and assign a value to this node:
c     
                  

                 p = acorni(idum)
                  
		if (p .ge. pkr) then 
		  sim(index) = simu(cmean,cstdev)
		else
		  sim(index) = cmean
		end if

                  
                  
 111              format(1x, 6(f10.5, 1x))
 141              format(' random number ',f6.4,' realization ',f7.4)
c     
c     Quick check for far out results:
c     
                  
c     
c     END MAIN LOOP OVER NODES:
c     
 5                continue
               end do
               
               write(8,*)neg, nsmall0, nsmall, nlarge
               
               print*, 'negative is ', neg
               print*, 'nsmall0 is ', nsmall0
               print*, 'nsmall is ', nsmall
               print*, 'nlarge is ', nlarge
               
c     
c     In the case when no data assigned to grid, the grid node that is too
c     close to the data location will be reassigned the sample data value. 
c     
               if(sstrat.eq.0) then
                  do id=1,nd
                     call getindx(nx,xmn,xsiz,x(id),ix,testind)
                     call getindx(ny,ymn,ysiz,y(id),iy,testind)
                     call getindx(nz,zmn,zsiz,z(id),iz,testind)
                     xx  = xmn + real(ix-1)*xsiz
                     yy  = ymn + real(iy-1)*ysiz
                     zz  = zmn + real(iz-1)*zsiz
                     ind = ix + (iy-1)*nx + (iz-1)*nxy
                     test=abs(xx-x(id))+abs(yy-y(id))+abs(zz-z(id))
                     if(test.le.TINY) sim(ind) = vr(id)
                  end do
               end if
c     
c     Write results:
c     
               ne = 0
               av = 0.0
               ss = 0.0
c
c Buffered I/O: collect values then write in blocks
c
               do ind=1,nxyz
                  simval = sim(ind)
                  ne = ne + 1
                  av = av + simval
                  ss = ss + simval*simval
                  if(idbg.ge.3) write(ldbg, *) simval
                  if(itrans.eq.0) then
                     write(lout,'(f12.4)') simval
                  end if
               end do
               av = av / max(real(ne),1.0)
               ss =(ss / max(real(ne),1.0)) - av * av
               write(ldbg,112) isim,ne,av,ss
               write(*,   112) isim,ne,av,ss
 112           format(/,' Realization ',i3,': number   = ',i8,/,
     +              '                  mean     = ',f12.4,
     +              ' (close to global mean)',/,
     +              '                  variance = ',f12.4,
     +              ' (close to global variance)',/)
               
c     
c     END MAIN LOOP OVER SIMULATIONS:
c     
               
               
c     
c     Return to the main program:
c     
               return
               end

      
      real function  simu(cmean1, cstdev1)
      
c
c     This function draws from the local conditional distribution and return
c     the value simu. The drawing depends on the type of local distribution 
c     specified in idrawopt
c     
      
      include  'dssim.inc'
      real*8   acorni 
      real p  
      real cmean1, cstdev1
      real aunif, bunif   
      real cvarn, cmn, zt, cvar
      
      
      p = acorni(idum)
      
      
      if(idrawopt.eq.0) then
        aunif = cmean1 - sqrt(3.)*cstdev1
        bunif = cmean1 + sqrt(3.)*cstdev1
        simu = aunif + p*(bunif-aunif)
      else if(idrawopt.eq.1) then
c     write(*,*) 'lognormal'
         cvar = cstdev1**2
         if(cmean1.le.0) then 
            write(ldbg, *) 'One minus cmean'
            write(*, *) 'One minus cmean'
            cmean1=0.000001
         endif
         cvarn = log(cvar/cmean1**2+1)
         cmn = log(cmean1)-cvarn/2
         call gauinv(dble(p),zt,ierr)
         simu = exp(sqrt(cvarn)*zt+cmn)
      else if(idrawopt.eq.2) then
         if(ibtw .eq. 0) then
            indexbt = min(nbt,max(1,int((nbt+1)*p)))
            
            
         else 
            
            
            if (p .le. bootcdf(1)) then
               indexbt = 1
            else if (p .gt. bootcdf(nbt)) then
               indexbt = nbt
            else
               call locate(bootcdf,nbt,1,nbt,p,indexbt)
c     write(*,*)       "indexbt=", indexbt           
            endif
         end if
         
c     write(*,*)       "indexbt=", indexbt 
         simu = 	(bootvar(indexbt)-btmean)/
     +        sqrt(btvar)*cstdev1+cmean1
         
         
      else	
         write(*,*) 'Error: drawing option larger than 1'     
         write(*,*) 'No implementation for this option'
      endif
      
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
c to compute the data covariance matrix as well as the data-point
c covariance matrix.
c
c Secondly, we want to establish a search for nearby nodes that
c in order of closeness as defined by the variogram.
c
c
c
c INPUT VARIABLES:
c
c   xsiz,ysiz,zsiz  Definition of the grid being considered
c   MAXCTX,Y,Z      Number of blocks in covariance table
c
c   covariance table parameters
c
c
c
c OUTPUT VARIABLES:  covtab()         Covariance table
c
c EXTERNAL REFERENCES:
c
c   sqdist          Computes 3-D anisotropic squared distance
c   sortem          Sorts multiple arrays in ascending order
c   cova3           Computes the covariance according to a 3-D model
c
c
c
c-----------------------------------------------------------------------
      parameter(TINY=1.0e-10)
      include  'dssim.inc'
      real*8    hsqd,sqdist
      logical   first
c     
c     Size of the look-up table:
c     
      nctx = min(((MAXCTX-1)/2),(nx-1))
      ncty = min(((MAXCTY-1)/2),(ny-1))
      nctz = min(((MAXCTZ-1)/2),(nz-1))
c
c     Debugging output:
c     
      write(ldbg,*)
      write(ldbg,*) 'Covariance Look up table and search for previously'
      write(ldbg,*) 'simulated grid nodes.  The maximum range in each '
      write(ldbg,*) 'coordinate direction for covariance look up is:'
      write(ldbg,*) '          X direction: ',nctx*xsiz
      write(ldbg,*) '          Y direction: ',ncty*ysiz
      write(ldbg,*) '          Z direction: ',nctz*zsiz
      write(ldbg,*) 'Node Values are not searched beyond this distance!'
      write(ldbg,*)
c     
c NOTE: If dynamically allocating memory, and if there is no shortage
c       it would a good idea to go at least as far as the radius and
c       twice that far if you wanted to be sure that all covariances
c       in the left hand covariance matrix are within the table look-up.
c
c Initialize the covariance subroutine and cbb at the same time:
c
      call cova3(0.0,0.0,0.0,0.0,0.0,0.0,1,nst,MAXNST,c0,it,cc,aa,
     +           1,MAXROT,rotmat,cmax,cbb)
c
c     Now, set up the table and keep track of the node offsets that are
c     within the search radius:
c     
      nlooku = 0
      do i=-nctx,nctx
         xx = i * xsiz
         ic = nctx + 1 + i
         do j=-ncty,ncty
            yy = j * ysiz
            jc = ncty + 1 + j
            do k=-nctz,nctz
               zz = k * zsiz
      kc = nctz + 1 + k
      call cova3(0.0,0.0,0.0,xx,yy,zz,1,nst,MAXNST,c0,it,cc,aa,
     +     1,MAXROT,rotmat,cmax,covtab(ic,jc,kc))
      hsqd = sqdist(0.0,0.0,0.0,xx,yy,zz,isrot,
     +     MAXROT,rotmat)
      if(real(hsqd).le.radsqd) then
         nlooku         = nlooku + 1
c     
c     We want to search by closest variogram distance (and use the
c     anisotropic Euclidean distance to break ties:
c     
         tmp(nlooku)   = - (covtab(ic,jc,kc)-TINY*real(hsqd))
         order(nlooku) = real((kc-1)*MAXCXY+(jc-1)*MAXCTX+ic)
      endif
      end do
      end do
      end do
c     
c     Finished setting up the look-up table, now order the nodes such
c     that the closest ones, according to variogram distance, are searched
c     first. Note: the "loc" array is used because I didn't want to make
c     special allowance for 2 byte integers in the sorting subroutine:
c     
      call sortem(1,nlooku,tmp,1,order,c,d,e,f,g,h)
      do il=1,nlooku
         loc = int(order(il))
         iz  = int((loc-1)/MAXCXY) + 1
         iy  = int((loc-(iz-1)*MAXCXY-1)/MAXCTX) + 1
         ix  = loc-(iz-1)*MAXCXY - (iy-1)*MAXCTX
         iznode(il) = int(iz)
         iynode(il) = int(iy)
         ixnode(il) = int(ix)
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
      if(idbg.lt.2) return
      write(ldbg,*)
      write(ldbg,*) 'There are ',nlooku,' nearby nodes that will be '
      write(ldbg,*) 'checked until enough close data are found.'
      write(ldbg,*)
      if(idbg.lt.14) return
      do i=1,nlooku
         xx = (ixnode(i) - nctx - 1) * xsiz
         yy = (iynode(i) - ncty - 1) * ysiz
         zz = (iznode(i) - nctz - 1) * zsiz
         write(ldbg,100) i,xx,yy,zz
      end do
 100  format('Point ',i3,' at ',3f12.4)
c     
c     All finished:
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
c
c
c INPUT VARIABLES:
c
c   ix,iy,iz        index of the point currently being simulated
c   sim             the realization so far
c   nodmax          the maximum number of nodes that we want
c   nlooku          the number of nodes in the look up table
c   i[x,y,z]node    the relative indices of those nodes.
c   [x,y,z]mn       the origin of the global grid netwrok
c   [x,y,z]siz      the spacing of the grid nodes.
c
c
c
c OUTPUT VARIABLES:
c
c   ncnode          the number of close nodes
c   icnode()        the number in the look up table
c   cnode[x,y,z]()  the location of the nodes
c   cnodev()        the values at the nodes
c
c
c
c-----------------------------------------------------------------------
      include  'dssim.inc'
      integer   ninoct(8)
c
c Consider all the nearby nodes until enough have been found:
c
      ncnode = 0
      if(noct.gt.0) then
            do i=1,8
                  ninoct(i) = 0
            end do
      end if
      do 2 il=2,nlooku
            if(ncnode.eq.nodmax) return
            i = ix + (int(ixnode(il))-nctx-1)
            j = iy + (int(iynode(il))-ncty-1)
            k = iz + (int(iznode(il))-nctz-1)
            if(i.lt. 1.or.j.lt. 1.or.k.lt. 1) go to 2
            if(i.gt.nx.or.j.gt.ny.or.k.gt.nz) go to 2
            ind = i + (j-1)*nx + (k-1)*nxy
            if(sim(ind).gt.UNEST) then
c
c Check the number of data already taken from this octant:
c
                  if(noct.gt.0) then
                        idx = ix - i
                        idy = iy - j
                        idz = iz - k
                        if(idz.gt.0) then
                              iq = 4
                              if(idx.le.0 .and. idy.gt.0) iq = 1
                              if(idx.gt.0 .and. idy.ge.0) iq = 2
                              if(idx.lt.0 .and. idy.le.0) iq = 3
                        else
                              iq = 8
                              if(idx.le.0 .and. idy.gt.0) iq = 5
                              if(idx.gt.0 .and. idy.ge.0) iq = 6
                              if(idx.lt.0 .and. idy.le.0) iq = 7
                        end if
                        ninoct(iq) = ninoct(iq) + 1
                        if(ninoct(iq).gt.noct) go to 2
                  end if
                  ncnode = ncnode + 1
                  icnode(ncnode) = il
                  cnodex(ncnode) = xmn + real(i-1)*xsiz
                  cnodey(ncnode) = ymn + real(j-1)*ysiz
                  cnodez(ncnode) = zmn + real(k-1)*zsiz
                  cnodev(ncnode) = sim(ind)
            endif
 2    continue
c
c Return to calling program:
c
      return
      end




      subroutine krige(ix,iy,iz,xx,yy,zz,lktype,gmean,cmean,cstdev)
c-----------------------------------------------------------------------
c
c            Builds and Solves the SK or OK Kriging System
c            *********************************************
c
c INPUT VARIABLES:
c
c   ix,iy,iz        index of the point currently being simulated
c   xx,yy,zz        location of the point currently being simulated
c
c
c
c OUTPUT VARIABLES:
c
c   cmean           kriged estimate
c   cstdev          kriged standard deviation
c
c
c
c EXTERNAL REFERENCES: ksol   Gaussian elimination system solution
c
c
c
c ORIGINAL: C.V. Deutsch                               DATE: August 1990
c-----------------------------------------------------------------------
      include 'dssim.inc'
      logical first
      real	spos(MAXKR1)

c
c Size of the kriging system:
c
      first = .false.
      na    = nclose + ncnode
      if(lktype.eq.0) neq = na
      if(lktype.eq.1) neq = na + 1
      if(lktype.eq.2) neq = na
      if(lktype.eq.3) neq = na + 2
      if(lktype.eq.4) neq = na + 1
c
c Set up kriging matrices:
c
      in=0
      do j=1,na
c
c Sort out the actual location of point "j"
c
            if(j.le.nclose) then
                  index  = int(close(j))
                  x1     = x(index)
                  y1     = y(index)
                  z1     = z(index)
                  vra(j) = vr(index)
                  vrea(j)= sec(index)
            else
c
c It is a previously simulated node (keep index for table look-up):
c
                  index  = j-nclose
                  x1     = cnodex(index)
                  y1     = cnodey(index)
                  z1     = cnodez(index)
                  vra(j) = cnodev(index)
                  ind    = icnode(index)
                  ix1    = ix + (int(ixnode(ind))-nctx-1)
                  iy1    = iy + (int(iynode(ind))-ncty-1)
                  iz1    = iz + (int(iznode(ind))-nctz-1)
                  index  = ix1 + (iy1-1)*nx + (iz1-1)*nxy
                  vrea(j)= lvm(index)
            endif
            do i=1,j
c
c Sort out the actual location of point "i"
c
                  if(i.le.nclose) then
                        index  = int(close(i))
                        x2     = x(index)
                        y2     = y(index)
                        z2     = z(index)
                  else
c
c It is a previously simulated node (keep index for table look-up):
c
                        index  = i-nclose
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
                  if(j.le.nclose.or.i.le.nclose) then
                        call cova3(x1,y1,z1,x2,y2,z2,1,nst,MAXNST,c0,it,
     +                             cc,aa,1,MAXROT,rotmat,cmax,cov)
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
                              call cova3(x1,y1,z1,x2,y2,z2,1,nst,MAXNST,
     +                             c0,it,cc,aa,1,MAXROT,rotmat,cmax,cov)
                        else
                              cov = covtab(ii,jj,kk)
                        endif
                        a(in) = dble(cov)
                  endif
            end do
c
c Get the RHS value (possibly with covariance look-up table):
c
            if(j.le.nclose) then
                  call cova3(xx,yy,zz,x1,y1,z1,1,nst,MAXNST,c0,it,cc,aa,
     +                       1,MAXROT,rotmat,cmax,cov)
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
                        call cova3(xx,yy,zz,x1,y1,z1,1,nst,MAXNST,c0,it,
     +                             cc,aa,1,MAXROT,rotmat,cmax,cov)
                  else
                        cov = covtab(ii,jj,kk)
                  endif
                  r(j) = dble(cov)
            endif
            rr(j) = r(j)
      end do
c
c Addition of OK constraint:
c
      if(lktype.eq.1.or.lktype.eq.3) then
            do i=1,na
                  in    = in + 1
c gvar???
                  a(in) = 1.0
            end do
            in       = in + 1
            a(in)    = 0.0
            r(na+1)  = 1.0
            rr(na+1) = 1.0
      endif
c
c Addition of the External Drift Constraint:
c
      if(lktype.eq.3) then
            edmin =  999999.
            edmax = -999999.
            do i=1,na
                  in    = in + 1
                  a(in) = vrea(i)
                  if(a(in).lt.edmin) edmin = a(in)
                  if(a(in).gt.edmax) edmax = a(in)
            end do
            in       = in + 1
            a(in)    = 0.0
            in       = in + 1
            a(in)    = 0.0
            ind      = ix + (iy-1)*nx + (iz-1)*nxy
            r(na+2)  = dble(lvm(ind))
            rr(na+2) = r(na+2)
            if((edmax-edmin).lt.EPSLON) neq = neq - 1
      endif
c
c Addition of Collocated Cosimulation Constraint:
c

      if(lktype.eq.4) then
            sfmin =  1.0e21
            sfmax = -1.0e21
            do i=1,na
                  in    = in + 1
                  a(in) = colocorr*r(i)
                  if(a(in).lt.sfmin) sfmin = a(in)
                  if(a(in).gt.sfmax) sfmax = a(in)
            end do
            in    = in + 1
            a(in) = 1.0
            ii    = na + 1
            r(ii) = dble(colocorr)
            rr(ii)= r(ii)
c           if((sfmax-sfmin).lt.EPSLON) neq = neq - 1
      end if
c
c Write out the kriging Matrix if Seriously Debugging:
c

c	do i = 1, neq*neq
c		a(i) = a(i)/gvar
c	end do
c	do i = 1, neq
c                r(i) = r(i)/gvar
c        end do


      if(idbg.ge.3) then
            write(ldbg,100) ix,iy,iz
            is = 1
            do i=1,neq
                  ie = is + i - 1
                  write(ldbg,101) i,r(i),(a(j),j=is,ie)
                  is = is + i
            end do
 100        format(/,'Kriging Matrices for Node: ',3i4,' RHS first')
 101        format('    r(',i2,') =',f7.4,'  a= ',99f7.4)
      endif
c
c Solve the Kriging System:
c

      if(neq.eq.1.and.lktype.ne.3) then
            s(1)  = r(1) / a(1)
            ising = 0
      else

            call ksol(1,neq,1,a,r,s,ising)
      endif
c
c Write a warning if the matrix is singular:
c
      if(ising.ne.0) then
            if(idbg.ge.1) then
                  write(ldbg,*) 'WARNING : singular matrix'
                  write(ldbg,*) '          for node',ix,iy,iz
            endif
            cmean  = gmean
            cstdev = sqrt(gvar)
            return
      endif
c
c Compute the estimate and kriging variance.  Recall that kriging type
c     0 = Simple Kriging:
c     1 = Ordinary Kriging:
c     2 = Locally Varying Mean:
c     3 = External Drift:
c     4 = Collocated Cosimulation:
c
      cmean  = 0.0
      cstdev = cbb
      sumwts = 0.0
      do i=1,na
            cmean  = cmean  + real(s(i))*vra(i)
            cstdev = cstdev - real(s(i)*rr(i))
            sumwts = sumwts + real(s(i))
      end do

      if(lktype.eq.0) cmean = cmean +(1.0-sumwts)*gmean

      if(lktype.eq.1) cstdev = cstdev - real(s(na+1))

      if(lktype.eq.2) cmean  = cmean + gmean

      if(lktype.eq.4) then
            ind    = ix + (iy-1)*nx + (iz-1)*nxy
            cmean  = cmean  + real(s(na+1))*lvm(ind)
            cstdev = cstdev - real(s(na+1) *rr(na+1))
      end if


c     
c     if cmean negative, and in case the local conditional distribution
c     is lognormal (idrawopt=1), than the weights s(1....na+1) are shifted
c     such that cmean is recalculated to be positive
c     
      
      if (cmean .le. 0.0) then
         
         write(ldbg,*) 'Before changing : cmean, cstdev ',cmean,cstdev
         if (idrawopt .eq. 1) then
            
            wmin = 9999.9
            do i = 1, neq
               if (s(i) .le. wmin) wmin = real(s(i))
            end do
            if (lktype.eq.0) then
               if ((1-sumwts) .le. wmin) wmin = 1-sumwts
            end if
            
            do i = 1, neq
               spos(i) = real(s(i))+abs(wmin)
            end do	
            
            if (lktype.eq.0) then
               wmean = 1-sumwts+abs(wmin)
            end if
            
            
            cmean  = 0.0
            sumwts = 0.0
            
            do i=1,na
               cmean  = cmean  + spos(i)*vra(i)
               sumwts = sumwts + real(s(i))
            end do
            
            if(lktype.eq.0) cmean = cmean + wmean*gmean
            
            if(lktype.eq.2) cmean  = cmean + gmean
            
            if(lktype.eq.4) then
               ind    = ix + (iy-1)*nx + (iz-1)*nxy
               cmean  = cmean  + spos(na+1)*lvm(ind)
            end if
            
            do i = 1, neq
               write(ldbg,*) real(s(i)),spos(i)
            end do
            
c     write(ldbg,*) cmean
            
         end if
      end if
      

c     
c     Error message if negative variance:
c     
      if(cstdev.lt.0.0) then
         write(ldbg,*) 'ERROR: Negative Variance: ',cstdev
         cstdev = 0.0
      endif
      
      cstdev = sqrt(cstdev)
c     
c     Write out the kriging Weights if Seriously Debugging:
c     
      if(idbg.ge.3) then
         do i=1,na
            write(ldbg,140) i,vra(i),s(i)
         end do
 140     format(' Data ',i4,' value ',f8.4,' weight ',f8.4)
         if(lktype.eq.4) write(ldbg,141) lvm(ind),s(na+1)
 141     format(' Sec Data  value ',f8.4,' weight ',f8.4)
         write(ldbg,142) gmean,cmean,cstdev
 142     format(' Global mean ',f8.4,' conditional ',f8.4,
     +        ' std dev ',f8.4)
      end if
c     
c     Finished Here:
c
      return
      end
      
      
      real function getz(pval,nt,vr,cdf,zmin,zmax,ltail,ltpar,
     +     utail,utpar)
c-----------------------------------------------------------------------
c     
c     
c     
c     INPUT VARIABLES:
c     
c   pval             probability value to use
c   nt               number of values in the back transform tbale
c   vr(nt)           original data values that were transformed
c   cdf(nt)          the corresponding transformed values
c   zmin,zmax        limits possibly used for linear or power model
c   ltail            option to handle values less than cdf(1)
c   ltpar            parameter required for option ltail
c   utail            option to handle values greater than cdf(nt)
c   utpar            parameter required for option utail
c
c
c
c-----------------------------------------------------------------------
      parameter(EPSLON=1.0e-20)
      dimension vr(nt),cdf(nt)
      real      ltpar,utpar,lambda
      integer   ltail,utail
c
c Value in the lower tail?    1=linear, 2=power, (3 and 4 are invalid):
c 
      if(pval.le.cdf(1)) then
                  getz = vr(1)
            if(ltail.eq.1) then
                  getz = powint(0.0,cdf(1),zmin,vr(1),pval,1.0)  
            else if(ltail.eq.2) then
                  cpow = 1.0 / ltpar
                  getz = powint(0.0,cdf(1),zmin,vr(1),pval,cpow)
            endif
c
c Value in the upper tail?     1=linear, 2=power, 4=hyperbolic:
c
      else if(pval.ge.cdf(nt)) then
                  cdfhi  = cdf(nt)
                  getz   = vr(nt)
c                WRITE(*,*) 'nt=', nt, 'cdfhi=', cdfhi, 'vr(nt)=', vr(nt)
            if(utail.eq.1) then
                  getz   = powint(cdfhi,1.0,vr(nt),zmax,pval,1.0)
            else if(utail.eq.2) then
                  cpow   = 1.0 / utpar
                  getz   = powint(cdfhi,1.0,vr(nt),zmax,pval,cpow)
            else if(utail.eq.4) then
                  lambda = (vr(nt)**utpar)*(1.0-cdf(nt))
c                  write(*,*) 'lambda=', lambda
c                  write(*,*) '(lambda/(1.0-pval))=', lambda/(1.0-pval)
c                  write(*,*) '(lambda/(1.0-pval))**(1.0/utpar)=',
c     +                        (lambda/(1.0-pval))**(1.0/utpar)
                  getz   =(lambda/(1.0-pval))**(1.0/utpar)
c                  write(*,*) 'getz=', getz

            endif
      else
c
c Value within the transformation table:
c
            call locate(cdf,nt,1,nt,pval,j)
            j    = max(min((nt-1),j),1)
            getz = powint(cdf(j),cdf(j+1),vr(j),vr(j+1),pval,1.0)
      endif
      if(getz.lt.zmin) getz = zmin
      if(getz.gt.zmax) getz = zmax
      return      
      end   
                  





      subroutine pre_trans 
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c 
c The subroutine is called to read in the target histogram from another
c file. It is only called once when doing multiple times of realization
c
c INPUT/OUTPUT Parameters
c
c  distin	file with target histogram  
c  ivrr,iwtr   	columns for variable and weight(0=none)
c  tmin,tmax   	trimming limits
c
c
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      include 'dssim.inc'
      real var(50) 
      logical testfl
      
c
c     read in the target histogram
c     
      inquire(file=distin,exist=testfl)
      if(.not.testfl) then
         write(*,*) 'ERROR: No reference distribution file'
         stop
      endif
      open(lin,file=distin,status='UNKNOWN')
      
c     
c     Proceed with reading in distribution:
c     
      read(lin,'(a)',err=198) str
      read(lin,*,err=198)     nvari
      do i=1,nvari
         read(lin,'()',err=198)
      end do
      
c     
c     Read as much data for target histogram as possible:
c     
      
      ncut = 0
      tcdf = 0
 2    read(lin,*,end=3,err=198) (var(j),j=1,nvari)
      
      
      if(var(ivrr).lt.tmin.or.var(ivrr).ge.tmax) go to 2
      
      vrt = var(ivrr) 
      wtt = 1.0
      if(iwtr.ge.1) wtt = var(iwtr)
      
      ncut = ncut + 1
      if(ncut.gt.MAXREF) then
         write(*,*) 'ERROR: exceeded available storage for'
         write(*,*) '       reference, available: ',MAXREF
         stop
      endif
      rvr(ncut)  = vrt
      rcdf(ncut) = wtt
      tcdf = tcdf + wtt

c     
c     Go back for another data?
c
      go to 2
 3    close(lin)
      
            
c     write(ldbg,*) 'ncut=', ncut, 'icut=', icut
c     write(ldbg, *) (rvr(i), i=1, ncut)
c     write(ldbg, *) (rcdf(i), i=1, ncut)
      
      
c        
c     Sort the Reference Distribution and Check for error situation:
c     
      call sortem(1,ncut,rvr,1,rcdf,c,d,e,f,g,h)
      if(ncut.le.1.or.tcdf.le.EPSLON) then
         write(*,*) 'ERROR: too few data or too low weight'
            stop
         endif
         if(utail.eq.4.and.rvr(ncut).le.0.0) then

            write(*,*) 'ERROR can not use hyperbolic tail with '
            write(*,*) '      negative values! - see manual '
            stop
         endif
c     
c     Turn the (possibly weighted) distribution into a cdf that is useful:
c     
      tcdf  = 1.0 / tcdf
      oldcp = 0.0
      cp    = 0.0
      do i=1,ncut
         cp     = cp + rcdf(i) * tcdf
            rcdf(i) =(cp + oldcp) * 0.5
            oldcp  = cp
         end do
         
      IF(IDBG.GE.3) then       
         write(ldbg, *) 'after sortem and calcthe correct rcdf rvr='
         write(ldbg, *) (rvr(i), i=1, ncut)
         write(ldbg, *) 'after sortem and calc the correct rcdf rcdf='
         write(ldbg, *) (rcdf(i), i=1, ncut)
      end if 
      
c
c     Write Some of the Statistics to the screen:
c     
      call locate(rcdf,ncut,1,ncut,0.5,j)
      gmedian = powint(rcdf(j),rcdf(j+1),rvr(j),rvr(j+1),0.5,1.0)
      write(*,900) ncut,gmedian
 900  format(/' There are ',i8,' data in reference dist,',/,
     +     '   median value        = ',f12.5)
      
      IF(IDBG.GE.3) then
         write(ldbg, *) 'ncut=', ncut
         write(ldbg, *) 'in pre_trans rvr='
         write(ldbg, *) (rvr(i), i=1, ncut)
         write(ldbg, *) 'in pre_trans rcdf='
         write(ldbg, *) (rcdf(i), i=1, ncut)
      end if 
      
      return 
      
 198  stop 'ERROR in global data file!'
      
      end 
      





      subroutine trans

c-----------------------------------------------------------------------
c
c                      Univariate Transformation
c                      *************************
c
c Transforms the values in each of the sequential simu;ation 
c such that their histograms match that of the reference distribution.
c
c
c
c INPUT/OUTPUT Parameters:
c
c   sim         dataset with uncorrected distributions
c   tmin,tmax   trimming limits
c   outfl       file for output distributions
c   nsim        size to transform, number of realizations
c   nx, ny, nz  size of categorical variable realizations to transform
c   nxyz        size to of continuous variable data set to transform
c   zmin,zmax   minimum and maximum data values
c   ltail,ltpar lower tail: option, parameter
c   utail,utpar upper tail: option, parameter
c   icond       honor local data (1=yes, 0=no)
c   localfl     file with estimation variance
c   ikv         column number
c   wtfac       control parameter
c
c
c
c The following Parameters control static dimensioning:
c
c   MAXREF    maximum number of data for reference distribution
c   MAXDAT    maximum number of data to transform (e.g., max. nx*ny*nz)
c   MAXCAT    maximum number of categories
c
c
c
c-----------------------------------------------------------------------

      include 'dssim.inc'
 
      character str*40
      real var(20)
      logical   testfl

	print *,'Transforming data '
      
      if(idbg.ge.3) then
         write(*,*) 'The simulation resuls from dssim is shown below'
         write(ldbg, *) (sim(i), i=1, nxyz)  
      end if 
      
    
      if(idbg.ge.3) then      	
         write(ldbg,*) 'isim=', isim, 'nsim=' , nsim
      end if 
      
      ivrd=1
      iwtd=0
ccccccccccccccccccccccccccccccccc
      
      
      
c     
c     transfer the data values from dssim simulation sim() to dvr():
c     keep this block unchanged 
c     
         
            tcdf = 0.0
            num  = 0
            do i=1,nxyz     
               num = num + 1 
               dvr(num)  = sim(i) 
               indx(num) = real(num)
               wtd = 1.0
               dcdf(num) = wtd
               tcdf      = tcdf + wtd
            end do  
            
            if(tcdf.le.EPSLON) then
               write(*,*) 'ERROR: no data'
               stop
            endif
            
            

c     
c     Turn the (possibly weighted) data distribution into a useful cdf:
c     
            
            call sortem(1,num,dvr,2,dcdf,indx,d,e,f,g,h)

        
            oldcp = 0.0
            cp    = 0.0
            tcdf  = 1.0 / tcdf
            
            do i=1,num
               cp     = cp + dcdf(i)*tcdf     
               dcdf(i) =(cp + oldcp) /2.
               if(dcdf(i).ge.1) dcdf(i) = 0.99
               
c     
c     The above algorithm theoretically garantee that dcdf should not be 
c     larger than 1 
c     However it happens only when n is very large, so that 
c     the machine numerical acuracy is not enough to get the correct dcdf value. 
c     
               oldcp  = cp
            end do
            
            
            
c     
c     Now, get the right order back:
c
            call sortem(1,num,indx,2,dcdf,dvr,d,e,f,g,h)
 
            

c   	    WRITE(ldbg,*) 'OK after sortem dcdf'

c
c Get the kriging variance to array "indx" if we have to honor
c local data: The kriging variance matrix is either read in or 
c calculated
c 
            if(icond.eq.1) then
	       if(ivar.eq.1) then 	
                  open(lkv,file=localfl,err=195,status='OLD')
                  read(lkv,'()',err=195)
                  read(lkv,*,   err=195) nvarik
                  do i=1,nvarik
                     read(lkv,'()',err=195)
                  end do
                  evmax = -1.0e21
                  do i=1,num
                     read(lkv,*,err=195) (var(j),j=1,nvarik)
                     indx(i) = var(icoll)
                     indx(i) = sqrt(max(indx(i),0.0)) 
                     if(indx(i).gt.evmax) evmax = indx(i)
                  end do
                  close(lkv)
	       else 
                  evmax = -1.0e21
                  do i=1,num
                     indx(i) = krgvar(i)
                     indx(i) = sqrt(max(indx(i),0.0))
                     if(indx(i).gt.evmax) evmax = indx(i)
                  end do
               end if                  
            end if
            
c     WRITE(ldbg,*) 'after icond.eq.1, whether to honor local data'
            

c     
c     Go through all the data back transforming them to the reference CDF:
c     
            
            ne = 0  
            av = 0.0
            ss = 0.0
            


            do i=1,num 

c		print *,'start getz'
c		print *,dcdf(i),num
               zval = getz(dcdf(i),ncut,rvr,rcdf,zmin,
     +              zmax,ltail,ltpar,utail,utpar)
c      		print *,'finished getz'
               
c     
c Now, do we have to honor local data?
c     
               if(icond.eq.1) then
                  
                  if(indx(i).eq.0) then 
                     wtw = 0.
                  else
                     wtw = (indx(i)/evmax)**wtfac
                  end if
                  zval = dvr(i)+wtw*(zval-dvr(i))
               end if
               
               ne = ne + 1   
               av = av + zval
               ss = ss + zval*zval
               write(ldbg, *) 'The transformed value is :'
               write(ldbg, *) zval
               call numtext(zval,str(1:12))
               write(lout,'(a12)') str(1:12)
            end do
            
c     
c     calculate some statistics
c     
 
	print *,'Finished trans'           
            av = av / max(real(ne),1.0)
            ss =(ss / max(real(ne),1.0)) - av * av
            write(ldbg,112) isim,ne,av,ss
            write(*,   112) isim,ne,av,ss
 112        format(/,' Realization ',i3,': number   = ',i8,/,
     +           '                  mean     = ',f12.4,
     +           ' (close to target mean)',/,
     +           '                  variance = ',f12.4,
     +           ' (close to target variance)',/)
            
            
c     
c     Finished:
c     
            
c     write(*,9998) VERSION
c     9998 format(/' DSSIM - GSLIB2-OPT v',f7.1, ' Finished'/)
            return

            

 195        stop 'ERROR in kriging variance file!'
            


            end
      

      

      subroutine makepar
c-----------------------------------------------------------------------
c     
c     Write a Parameter File
c     **********************
c     
c
c
c-----------------------------------------------------------------------
      lun = 99
      open(lun,file='dssim.par',status='UNKNOWN')
      write(lun,10)
 10   format('                  Parameters for DSSIM',/,
     +       '                  ********************',/,/,
     +       'START OF PARAMETERS:')

      write(lun,11)
 11   format('1                             ',
     +       '- conditional simulation (1=yes, 0=no)')
      write(lun,12)
 12   format('../data/cluster.dat           ',
     +       '- file with conditioning data')
      write(lun,13)
 13   format('1  2  0  3  5  0              ',
     +       '-  columns for X,Y,Z,vr,wt,sec.var.')
      write(lun,14)
 14   format('-1.0       1.0e21             ',
     +       '-  trimming limits for conditioning data')
      write(lun,15)
 15   format('1                             ',
     +       '-debugging level: 0,1,2,3')
      write(lun,16)
 16   format('dssim.dbg                     ',   
     +       '-file for debugging output')
      write(lun,17)
 17   format('dssim.out                     ',
     +       '-file for output')
      write(lun,18)
 18   format('1                             ',
     +       '-number of realizations to generate')
      write(lun,185)
 185  format('0                             ',
     +       '-ccdf. type: 0-unif, 1-lognorm, 2-bootstrap')
      write(lun,186)
 186  format('cluster.dat                             ',
     +       '- bootstrap file')
      write(lun,187)
 187  format('3    5                              ',
     +       '- columes for variable and weights')
      write(lun,19)
 19   format('50    0.5    1.0              ',
     +       '-nx,xmn,xsiz')
      write(lun,20)
 20   format('50    0.5    1.0              ',
     +       '-ny,ymn,ysiz')
      write(lun,21)
 21   format('1     0.5    1.0              ',  
     +       '-nz,zmn,zsiz')
      write(lun,22)
 22   format('69069                         ', 
     +       '-random number seed')
      write(lun,23)
 23   format('0     8                       ', 
     +       '-min and max original data for sim')
      write(lun,24)
 24   format('12                            ',
     +       '-number of simulated nodes to use')
      write(lun,25)
 25   format('1                             ',
     +       '-assign data to nodes (0=no, 1=yes)')
      write(lun,26)
 26   format('1     3                       ',
     +       '-multiple grid search (0=no, 1=yes),num')
      write(lun,27)
 27   format('0                             ',
     +       '-maximum data per octant (0=not used)')
      write(lun,28)
 28   format('10.0  10.0  10.0              ',
     +       '-maximum search radii (hmax,hmin,vert)')
      write(lun,29)
 29   format(' 0.0   0.0   0.0              ',
     +       '-angles for search ellipsoid')
      write(lun,30)
 30   format('0   0.5  0.8                        ',
     +       '-ktype: 0=SK,1=OK,2=LVM,3=EXDR,4=COLC')
      write(lun, 305)
 305  format('2.52     20.88                      ',
     +       '- global mean and variance')
      write(lun,31)
 31   format('../data/ydata.dat             ',
     +       '-  file with LVM, EXDR, or COLC variable')
      write(lun,32)
 32   format('4                             ',
     +       '-  column for secondary variable')
      write(lun,33)
 33   format('1    0.1                      ',   
     +       '-nst, nugget effect')
      write(lun,34)
 34   format('1    0.9  0.0   0.0   0.0     ',
     +       '-it,cc,ang1,ang2,ang3')
      write(lun,35)
 35   format('         10.0  10.0  10.0     ',
     +       '-a_hmax, a_hmin, a_vert')
      write(lun,36)
 36   format('1                             ',
     +       '-trans 1=yes,0=no. if 1,following lines defined')
      write(lun,37)
 37   format('../data/cluster.dat                     ',
     +       '-  file with target histogram')
      write(lun,38)
 38   format('1   0                          ',
     +       '-  columns for variable and weight(0=none)')
      write(lun,40)
 40   format('0   110.                          ',
     +       '- zmin,zmax (tail extrapolation for trans)')
      write(lun,41)
 41   format('1       0.0                   ',
     +       '-  lower tail option, parameter')
      write(lun,42)
 42   format('4      3.0                   ',
     +       '-  upper tail option, parameter')
      write(lun,43)
 43   format('0                             ',
     +       '-if conditional,read or calc. est. var.(1=r,0=c)')
      write(lun,44)
 44   format('kt3d.out                      ',
     +       '-file with estimation variance')
      write(lun,45)
 45   format('2                     ',
     +       '-column number for estimation variance')
      write(lun,46)
 46   format('0.05                             ',
     +       '-control parameter ( 0.33 < w < 3.0 )')
      close(lun)
      return
      end


