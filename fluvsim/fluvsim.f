      program main
c-----------------------------------------------------------------------
c
c              Hierarchical Fluvial Reservoir Modeling
c              ***************************************
c
c The program is executed with no command line arguments.  The user
c will be prompted for the name of a parameter file.  The parameter
c file is described in the documentation (see the example fluvsim.par)
c
c The output file will be a GEOEAS file containing the simulated facies
c codes.  The file is ordered by x,y,z, and then simulation (i.e., x
c cycles fastest, then y, then z, then realization number).
c
c Although somewhat odd, the facies coding is as follows (for input well
c conditioning...):
c
c                    0 = floodplain shale
c                    1 = channel sand (2 reserved for channel margin)
c                    3 = levee sand
c                    4 = crevasse sand
c
c
c Modified with T. T. Tran in May/June 1997 to generalize orientation,
c net-to-gross conditioning, perturbation mechanism, ...
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
c
c Read the parameters and data:
c
      call readparm
c
c Call fluvsim for the simulation:
c
      do isim=1,nsim
            write(*,*)
            write(*,*) 'Working on realization number ',isim
            call fluvsim
      end do
      close(ldbg)
      close(lout)
      close(lgeo)
      close(lpv)
      close(lpa)
      close(lwd)
c
c Finished:
c
      write(*,*)
      write(*,9998) VERSION
 9998 format(/' FLUVSIM - GSLIB2-OPT v',f7.1, ' Finished'/)
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
      include  'fluvsim.inc'
      integer   icolv(3),icola(3)
      real      var(50),proptest(3)
      real*8    p,acorni
      character datafl*40,dbgfl*40,geofl*40,outfl*40,pcurout*40,
     +          pmapout*40,wellout*40,pcurvefl*40,pmapfl*40,str*40
      logical   testfl
c
c Input/Output units used:
c
      lin  = 1
      ldbg = 2
      lgeo = 3
      lout = 4
      lpv  = 7
      lpa  = 8
      lwd  = 9
c
c Note VERSION number:
c
      write(*,9999) VERSION
 9999 format(/' FLUVSIM - GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)
c
c Get the name of the parameter file - try the default name if no input:
c
      write(*,*) 'Which parameter file do you want to use?'
      read (*,'(a40)') str
      if(str(1:1).eq.' ')str='fluvsim.par                             '
      inquire(file=str,exist=testfl)
      if(.not.testfl) then
            write(*,*) 'ERROR - the parameter file does not exist,'
            write(*,*) '        check for the file and try again  '
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

      read(lin,*,err=98) iwl,ixl,iyl,izl,ifl
      write(*,*) ' input columns = ',iwl,ixl,iyl,izl,ifl

      read(lin,*,err=98) tmin,tmax
      write(*,*) ' trimming limits = ',tmin,tmax

      read(lin,*,err=98) idbg
      write(*,*) ' debugging level = ',idbg

      read(lin,'(a40)',err=98) dbgfl
      call chknam(dbgfl,40)
      write(*,*) ' debugging file = ',dbgfl
      open(ldbg,file=dbgfl,status='UNKNOWN')

      read(lin,'(a40)',err=98) geofl
      call chknam(geofl,40)
      write(*,*) ' geometry file = ',geofl

      read(lin,'(a40)',err=98) outfl
      call chknam(outfl,40)
      write(*,*) ' output file = ',outfl

      read(lin,'(a40)',err=98) pcurout
      call chknam(pcurout,40)
      write(*,*) ' output file for vertical proportions= ',pcurout

      read(lin,'(a40)',err=98) pmapout
      call chknam(pmapout,40)
      write(*,*) ' output file for areal proportions= ',pmapout

      read(lin,'(a40)',err=98) wellout
      call chknam(wellout,40)
      write(*,*) ' output file for well data= ',wellout

      read(lin,*,err=98) nsim
      write(*,*) ' number of realizations = ',nsim

      read(lin,*,err=98) nx,xmn,xsiz
      write(*,*) ' X grid specification = ',nx,xmn,xsiz

      read(lin,*,err=98) ny,ymn,ysiz
      write(*,*) ' Y grid specification = ',ny,ymn,ysiz

      read(lin,*,err=98) nz,avgthick
      write(*,*) ' Z grid specification = ',nz,avgthick
      zsiz = 1.0 / real(nz)
      zmn  = 0.5 * zsiz

      read(lin,*,err=98) ixv(1)
      write(*,*) ' random number seed = ',ixv(1)
      do i=1,1000
             p = acorni(idum)
      end do

      read(lin,*,err=98) i1,i2,i3,i4
      write(*,*) ' Components in objective func = ',i1,i2,i3,i4
                  lglob = .false.
                  lvert = .false.
                  larea = .false.
                  lwell = .false.
      if(i1.ge.1) lglob = .true.
      if(i2.ge.1) lvert = .true.
      if(i3.ge.1) larea = .true.
      if(i4.ge.1) lwell = .true.

      read(lin,*,err=98) sclglob,sclvert,sclarea,sclwell
      write(*,*) ' scaling of objective func = ',sclglob,sclvert,
     +                                           sclarea,sclwell
      totwt = sclglob + sclvert + sclarea + sclwell
      if(totwt.le.0.0) stop 'Weights must be greater than zero'
      sclglob = sclglob / totwt
      sclvert = sclvert / totwt
      sclarea = sclarea / totwt
      sclwell = sclwell / totwt

      read(lin,*,err=98) niter,mnoc,objmin
      write(*,*) ' Number of iterations, min obj = ',niter,mnoc,objmin

      read(lin,*,err=98) t0,redfac,kasas,ksas,numred
      write(*,*) ' annealing schedule = ',t0,redfac,kasas,ksas,numred

      read(lin,*,err=98) cumprob(1),cumprob(2),cumprob(3)
      write(*,*) ' perturbation probabilities = ',
     +                   cumprob(1),cumprob(2),cumprob(3)
      cumprob(2) = cumprob(1) + cumprob(2)
      cumprob(3) = cumprob(2) + cumprob(3)

      read(lin,*,err=98) ichan,ilev,icre
      write(*,*) ' Facies types = ',ichan,ilev,icre

      read(lin,*,err=98) tarprop(1),tarprop(3),tarprop(4)
      if(ilev.eq.0) tarprop(3) = 0.0
      if(icre.eq.0) tarprop(4) = 0.0
      write(*,*) ' Reference proportions = ',(tarprop(i),i=1,4)
      tarprop(0) = 1.0 - ( tarprop(1) + tarprop(3) + tarprop(4) )
      tarprop(2) = 0.0

      read(lin,'(a40)',err=98) pcurvefl
      call chknam(pcurvefl,40)
      write(*,*) ' vertical proportion curve file = ',pcurvefl

      read(lin,*,err=98) itest
      write(*,*) ' net-to-gross or all facies = ',itest
      lvertng = .true.
      if(itest.eq.1) lvertng = .false.

      read(lin,*,err=98) (icolv(i),i=1,3)
      write(*,*) ' column numbers = ',(icolv(i),i=1,3)

      read(lin,'(a40)',err=98) pmapfl
      call chknam(pmapfl,40)
      write(*,*) ' areal proportion map file = ',pmapfl

      read(lin,*,err=98) itest
      write(*,*) ' net-to-gross or all facies = ',itest
      lareang = .true.
      if(itest.eq.1) lareang = .false.

      read(lin,*,err=98) (icola(i),i=1,3)
      write(*,*) ' column numbers = ',(icola(i),i=1,3)

      read(lin,*,err=98) mxc
      write(*,*) ' maximum number of channels = ',mxc

      read(lin,*,err=98) (fco(i),i=1,3)
      write(ldbg,*) ' channel orientation = ',(fco(i),i=1,3)

      read(lin,*,err=98) (fcad(i),i=1,3)
      write(ldbg,*) ' channel sinuosity dep = ',(fcad(i),i=1,3)

      read(lin,*,err=98) (fcal(i),i=1,3)
      write(ldbg,*) ' channel sinuosity len = ',(fcal(i),i=1,3)

      read(lin,*,err=98) (fct(i),i=1,3)
      write(ldbg,*) ' channel thickness = ',(fct(i),i=1,3)

      read(lin,*,err=98) (fctu(i),i=1,3)
      write(ldbg,*) ' channel thickness undulation = ',(fctu(i),i=1,3)

      read(lin,*,err=98) (fctul(i),i=1,3)
      write(ldbg,*) ' channel thickness undul len=',(fctul(i),i=1,3)

      read(lin,*,err=98) (fcwt(i),i=1,3)
      write(ldbg,*) ' channel W/T ratio = ',(fcwt(i),i=1,3)

      read(lin,*,err=98) (fcwu(i),i=1,3)
      write(ldbg,*) ' channel width undulation = ',(fcwu(i),i=1,3)

      read(lin,*,err=98) (fcwul(i),i=1,3)
      write(ldbg,*) ' channel width undulation len = ',(fcwul(i),i=1,3)

      read(lin,*,err=98) (flw(i),i=1,3)
      write(ldbg,*) ' levee width = ',(flw(i),i=1,3)
      do iz=1,nz
            flwz(iz,1) = flw(1)
            flwz(iz,2) = flw(2)
            flwz(iz,3) = flw(3)
      end do

      read(lin,*,err=98) (flh(i),i=1,3)
      write(ldbg,*) ' levee height = ',(flh(i),i=1,3)

      read(lin,*,err=98) (fld(i),i=1,3)
      write(ldbg,*) ' levee depth below channel top = ',(fld(i),i=1,3)

      read(lin,*,err=98) (fcrlen(i),i=1,3)
      write(ldbg,*) ' crevasse attachment length = ',(fcrlen(i),i=1,3)

      read(lin,*,err=98) (fcrt(i),i=1,3)
      write(ldbg,*) ' crevasse thickness = ',(fcrt(i),i=1,3)

      read(lin,*,err=98) (fcrwl(i),i=1,3)
      write(ldbg,*) ' crevasse areal dimension = ',(fcrwl(i),i=1,3)

      write(*,*)
      close(lin)
c
c Perform some quick error checking:
c
      testfl = .false.
      if(nx.gt.MAXX.or.ny.gt.MAXY.or.nz.gt.MAXZ) then
            write(*,*) 'ERROR: available grid size: ',MAXX,MAXY,MAXZ
            write(*,*) '       you have asked for : ',nx,ny,nz
            testfl = .true.
      end if
      if(mxc.gt.(MAXC-1)) then
            write(*,*) 'ERROR: available number of C: ',MAXC
            write(*,*) '       you have asked for   : ',mxc
            testfl = .true.
      end if
      if(testfl) stop
c
c Initialization.  Rescale vertical coordinates to average thickness.
c Scale annealing parameters by maximum number of channels.
c
      do i=1,3
            fct(i)  = fct(i)  / avgthick
            fcwt(i) = fcwt(i) * avgthick
            fcrt(i) = fcrt(i) / avgthick
      end do
      nfct2 = 1 + int(fct(2)*0.5/zsiz)
      kasas = kasas * mxc
      ksas  = ksas  * mxc
c
c Make sure the angles are in the right direction:
c
      if(fco(1).gt.135.0) fco(1) = fco(1) - 180.0
      if(fco(2).gt.135.0) fco(2) = fco(2) - 180.0
      if(fco(3).gt.135.0) fco(3) = fco(3) - 180.0
      if(fco(1).lt.-45.0) fco(1) = fco(1) + 180.0
      if(fco(2).lt.-45.0) fco(2) = fco(2) + 180.0
      if(fco(3).lt.-45.0) fco(3) = fco(3) + 180.0
c
c The limits of interest for the channels and the spacing of the slices
c that make up the channels:
c
      xmx    = xmn + (real(nx)-0.5)*xsiz
      ymx    = ymn + (real(ny)-0.5)*ysiz
      xadd   = 0.5*xsiz + min((0.15*(xmx-xmn)),(0.7071*fct(2)*fcwt(2)))
      cxmin  = xmn - (0.5*xsiz + xadd)
      cxmax  = xmx + xadd
      yadd   = 0.5*ysiz + min((0.15*(ymx-ymn)),(0.7071*fct(2)*fcwt(2)))
      cymin  = ymn - (0.5*ysiz + yadd)
      cymax  = ymx + yadd
      cdy    = 0.7071*min(xsiz,ysiz)
      ndymax = sqrt((cxmax-cxmin)**2+(cymax-cymin)**2) / cdy
      write(ldbg,120) (xmn-0.5*xsiz),xmx,(ymn-0.5*ysiz),ymx,
     +                cxmin,cxmax,cymin,cymax,cdy,ndymax
      write(*,120)    (xmn-0.5*xsiz),xmx,(ymn-0.5*ysiz),ymx,
     +                cxmin,cxmax,cymin,cymax,cdy,ndymax
 120  format(/,'Limits of model X: ',2f10.2,
     +       /,'                Y: ',2f10.2,
     +       /,'   outer limits X: ',2f10.2,
     +       /,'                Y: ',2f10.2,
     +       /,'       channel dy: ',f10.4,
     +       /,'       maximum ny: ',i10)
c
c Set up the crevasse templates and figure out the probability of
c one per channel:
c
      if(icre.eq.1) then
            write(*,*)
            write(*,*) 'Establishing ',MAXCRE,' crevasse templates'
c
c - scale input to grid units (and hard code some parameters):
c
            fcrlen(1) = int(fcrlen(1)/cdy+0.5)
            fcrlen(2) = int(fcrlen(2)/cdy+0.5)
            fcrlen(3) = int(fcrlen(3)/cdy+0.5)
            fcrnw(1)  =  5
            fcrnw(2)  = 10
            fcrnw(3)  = 15
            fcrlat(1) = 0.5
            fcrlat(2) = 0.5
            fcrlat(3) = 0.5
            fcrwl(1)  = int(1.5*fcrwl(1)/cdy+0.5)
            fcrwl(2)  = int(1.5*fcrwl(2)/cdy+0.5)
            fcrwl(3)  = int(1.5*fcrwl(3)/cdy+0.5)
c
c - establish the crevasse templates and the number of crevasses:
c
            call getcre
            cresize = 0.0
            do ic=1,MAXCRE
                  do ix=0,MAXCRX
                  do iy=-MAXCRY,MAXCRY
                        if(cre(ic,ix,iy)) cresize = cresize +
     +                  cdy*cdy*fcrt(2)*(MAXCRX-real(ix))/MAXCRX
                  end do
                  end do
            end do
            cresize = cresize / MAXCRE
            chsize  = 0.55*fct(2)*fct(2)*fcwt(2)*real(ny)*cdy
            creprob(2) = tarprop(4) / tarprop(1) * (chsize / cresize)
c
c Scale the number of crevasses so that the proportion works out.
c
            creprob(2) = creprob(2) / 2.0

            creprob(1) = creprob(2) / 1.5
            creprob(3) = creprob(2) * 1.5
            write(*,*) 'Average channel  size: ',chsize
            write(*,*) 'Average crevasse size: ',cresize
            write(*,*) 'There will be about ',int(creprob(2)+0.5),
     +                 ' crevasses per channel'
            do iz=1,nz
                  creprz(iz,1) = creprob(1)
                  creprz(iz,2) = creprob(2)
                  creprz(iz,3) = creprob(3)
            end do
      end if
c
c Read the well data (if the file exists):
c
      nwd   = 0
      nwint = 0
      inquire(file=datafl,exist=testfl)
      if(testfl.and.lwell) then
            write(*,*)
            write(*,*) 'Reading input well data'
            open(lin,file=datafl,status='OLD')
            read(lin,*,err=99)
            read(lin,*,err=99) nvari
            do i=1,nvari
                  read(lin,*,err=99)
            end do
            if(ixl.gt.nvari.or.iyl.gt.nvari.or.izl.gt.nvari.or.
     +         ifl.gt.nvari) then
                  write(*,*) 'ERROR: you have asked for a column number'
                  write(*,*) '       greater than number in well data'
                  stop
            end if
            if(ixl.le.0.or.iyl.le.0.or.izl.le.0.or.ifl.le.0) then
                  write(*,*) 'ERROR: you must have coordinates and'
                  write(*,*) '       facies in well data'
                  stop
            end if
c
c Read all the data until the end of the file:
c
            iwold = -1
            ifold = -1
 5          read(lin,*,end=6,err=99) (var(j),j=1,nvari)
            if(var(ifl).lt. tmin.or.var(ifl).ge. tmax.or.
     +         var(ixl).lt.cxmin.or.var(ixl).ge.cxmax.or.
     +         var(iyl).lt.cymin.or.var(iyl).ge.cymax.or.
     +         var(izl).lt.  0.0.or.var(izl).ge.  1.0)    go to 5
            nwd = nwd + 1
            if(nwd.gt.MAXDAT) then
                  write(*,*) ' ERROR exceeded MAXDAT - check inc file'
                  stop
            end if
c
c Acceptable data, assign the value, X, Y, Z coordinates, and weight:
c
            iwell   = var(iwl)
            fw(nwd) = var(ifl)
            call getindx(nx,xmn,xsiz,var(ixl),ii,inflag)
            xw(nwd) = max(min(ii,nx),1)
            call getindx(ny,ymn,ysiz,var(iyl),ii,inflag)
            yw(nwd) = max(min(ii,ny),1)
            call getindx(nz,zmn,zsiz,var(izl),ii,inflag)
            zw(nwd) = max(min(ii,nz),1)
c
c Keep track of well intervals:
c
            if(iwell.ne.iwold.or.fw(nwd).ne.ifold) then
                  nwint           = nwint + 1
                  if(nwint.gt.MAXWIN) then
                        write(*,*) ' ERROR exceeded MAXWIN'
                        stop
                  end if
                  iwold           = iwell
                  ifold           = fw(nwd)
                  ninwint(nwint)  = 1
                  facint(nwint)   = ifold
                  ixint(nwint,1)  = xw(nwd)
                  iyint(nwint,1)  = yw(nwd)
                  izint(nwint,1)  = zw(nwd)
            else
                  ninwint(nwint)  = ninwint(nwint) + 1
                  if(ninwint(nwint).gt.MAXWIN) then
                        write(*,*) ' ERROR exceeded MAXWIN'
                        stop
                  end if
                  ii              = ninwint(nwint)
                  ixint(nwint,ii) = xw(nwd)
                  iyint(nwint,ii) = yw(nwd)
                  izint(nwint,ii) = zw(nwd)
            end if
c
c Return for new well data:
c
            go to 5
 6          close(lin)
            write(ldbg,109) nwd,nwint
            write(*,   109) nwd,nwint
 109        format(/,' Number of acceptable well data  = ',i8,/,
     +               ' Number of intervals for pert.   = ',i8)
            wfac = 20 / max(real(nwd),1.0)
c
c Now, establish the well intervals for the perturbation mechanism:
c
            iwold = -1


      endif
c
c Read the vertical proportion curve (if the file exists):
c
      do iz=1,nz
            do i=1,3
                  pcurve(iz,i) = 0.0
            end do
      end do
      inquire(file=pcurvefl,exist=testfl)
      if(testfl.and.lvert) then
            write(*,*)
            write(*,*) 'Reading vertical proportion curve data'
            open(lin,file=pcurvefl,status='OLD')
            read(lin,*,err=97)
            read(lin,*,err=97) nvari
            do i=1,nvari
                  read(lin,*,err=97)
            end do
            do i=1,3
                  proptest(i) = 0.0
            end do
            do iz=1,nz
                  do i=1,3
                        pcurve(iz,i) = 0.0
                  end do
                  read(lin,*,err=97) (var(i),i=1,nvari)
                  if(lvertng) then
                        ii = icolv(1)
                        pcurve(iz,1) = var(ii)
                        proptest(1)  = proptest(1) + pcurve(iz,1)
                  else
                        do i=1,3
                              ii = icolv(i)
                              if(i.eq.1) pcurve(iz,i) = var(ii)
                              if(i.eq.2.and.ilev.eq.1) 
     +                                   pcurve(iz,i) = var(ii)
                              if(i.eq.3.and.icre.eq.1) 
     +                                   pcurve(iz,i) = var(ii)
                              proptest(i)  = proptest(i) + pcurve(iz,i)
                        end do
                  end if
            end do
            close(lin)
            do i=1,3
                  proptest(i) = proptest(i) / real(nz)
                  if(proptest(i).lt.0.001) proptest(i) = 0.001
            end do
            do iz=1,nz
                  if(lvertng) then
                        pcurve(iz,1) = pcurve(iz,1) *
     +                  (tarprop(1)+tarprop(3)+tarprop(4)) / proptest(1)
                  else
                        pcurve(iz,1) = pcurve(iz,1) *
     +                                 tarprop(1) / proptest(1)
                        if(ilev.eq.1)  pcurve(iz,2) = pcurve(iz,2) *
     +                                 tarprop(3) / proptest(2)
                        if(icre.eq.1)  pcurve(iz,3) = pcurve(iz,3) *
     +                                 tarprop(4) / proptest(3)
                  end if
            end do
      end if
c
c Read the areal proportion map (if the file exists):
c
      do iy=1,ny
      do ix=1,nx
            do i=1,3
                  pmap(ix,iy,i) = 0.0
            end do
      end do
      end do
      inquire(file=pmapfl,exist=testfl)
      if(testfl.and.larea) then
            write(*,*)
            write(*,*) 'Reading areal proportion map data'
            open(lin,file=pmapfl,status='OLD')
            read(lin,*,err=97)
            read(lin,*,err=97) nvari
            do i=1,nvari
                  read(lin,*,err=97)
            end do
            do i=1,3
                  proptest(i) = 0.0
            end do
            do iy=1,ny
            do ix=1,nx
                  do i=1,3
                        pmap(ix,iy,i) = 0.0
                  end do
                  read(lin,*,err=97) (var(i),i=1,nvari)
                  if(lareang) then
                        ii = icola(1)
                        pmap(ix,iy,1) = var(ii)
                        proptest(1)   = proptest(1) + pmap(ix,iy,1)
                  else
                        do i=1,3
                              ii = icola(i)
                              if(i.eq.1) pmap(ix,iy,i) = var(ii)
                              if(i.eq.2.and.ilev.eq.1)
     +                                   pmap(ix,iy,i) = var(ii)
                              if(i.eq.3.and.icre.eq.1)
     +                                   pmap(ix,iy,i) = var(ii)
                              proptest(i) = proptest(i) + pmap(ix,iy,i)
                        end do
                  end if
            end do
            end do
            close(lin)
            do i=1,3
                  proptest(i) = proptest(i) / real(nx*ny)
                  if(proptest(i).lt.0.001) proptest(i) = 0.001
            end do
            do iy=1,ny
            do ix=1,nx
                  if(lareang) then
                        pmap(ix,iy,1) = pmap(ix,iy,1) *
     +                  (tarprop(1)+tarprop(3)+tarprop(4)) / proptest(1)
                  else
                        pmap(ix,iy,1) = pmap(ix,iy,1) *
     +                                 tarprop(1) / proptest(1)
                        if(ilev.eq.1) pmap(ix,iy,2) = pmap(ix,iy,2) *
     +                                 tarprop(3) / proptest(2)
                        if(icre.eq.1) pmap(ix,iy,3) = pmap(ix,iy,3) *
     +                                 tarprop(4) / proptest(3)
                  end if
            end do
            end do
      end if
c
c Open the output files and write header information:
c
      open(lout,file=outfl,status='UNKNOWN')
      write(lout,110)
 110  format('FLUVSIM Realizations',/,'1',/,'facies code')

      open(lgeo,file=geofl,status='UNKNOWN')
      write(lgeo,130) nx,xmn,xsiz,ny,ymn,ysiz,nz,avgthick,ilev,icre
 130  format(i3,1x,f10.2,1x,f6.3,' -X: nx, xmn, xsiz',/,
     +       i3,1x,f10.2,1x,f6.3,' -Y: ny, ymn, ysiz',/,
     +       i3,        12x,f6.3,' -Z: number and average thickness',/,
     +       i2,i2,          17x,' -levee and crevasse (0=no, 1=yes)')

      if(lvert) then
            open(lpv,file=pcurout,status='UNKNOWN')
            write(lpv,111)
 111        format('FLUVSIM Vertical Proportion Curve Output',/,'7',/,
     +             'Z index',/,'target 1',/,'actual 1',/,
     +                         'target 2',/,'actual 2',/,
     +                         'target 3',/,'actual 3')
      end if

      if(larea) then
            open(lpa,file=pmapout,status='UNKNOWN')
            write(lpa,112)
 112        format('FLUVSIM Areal Proportion Map Output',/,'6',/,
     +             'target 1',/,'actual 1',/,
     +             'target 2',/,'actual 2',/,
     +             'target 3',/,'actual 3')
      end if

      if(lwell) then
            open(lwd,file=wellout,status='UNKNOWN')
            write(lwd,113)
 113        format('FLUVSIM Well Data Output',/,'5',/,
     +             'x',/,'y',/,'z',/,'well data',/,'realization')
      end if

      return
c
c Error in an Input File Somewhere:
c
 97   stop 'ERROR in proportion files!'
 98   stop 'ERROR in parameter file!'
 99   stop 'ERROR in data file!'
      end



      subroutine fluvsim
c-----------------------------------------------------------------------
c
c Main subroutine that establishes the initial set of channels (and
c associated levee and crevasse sands), perturbs them until one of the
c stopping criteria is met, and then writes output files.
c
c
c
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
      real*8    acorni
      logical   accept,lreport,flong
c
c Initialize:
c
      flong = .false.
      do ic=1,mxc
            chanon(ic) = .false.
      end do
      nc = 0
      modprop(0) = 1.0
      do i=1,4
            modprop(i) = 0.0
      end do
c
c Get 10 channels to calibrate the size of levees and frequency of
c crevasses.
c
      if(ilev.eq.1.or.icre.eq.1) then
            write(*,*)
            write(*,*) 'Getting a set of channels to calibrate size of',
     +                 ' levees and crevasses'
            do i=1,10
                  call getchpar(i,flong)
            end do
            call rasterc
            if(ilev.eq.1) then
                  if(tarprop(1).gt.0.001.and.modprop(3).gt.0.001) then
                  sclf = tarprop(3)/tarprop(1) / (modprop(3)/modprop(1))
                  write(*,*)
                  write(*,*) '   Levee width: ',flw(2)
                  write(*,*) '   Scaled   by: ',sclf
                  if(lvert.and..not.lvertng) then
                        do iz=1,nz
                              sclf = pcurve(iz,2)/pcurve(iz,1) 
     +                             /  (modprop(3)/modprop(1))
                              flwz(iz,1) = flw(1) * sclf
                              flwz(iz,2) = flw(2) * sclf
                              flwz(iz,3) = flw(3) * sclf
                        end do
                  else
                        flw(1) = flw(1) * sclf
                        flw(2) = flw(2) * sclf
                        flw(3) = flw(3) * sclf
                        write(*,*) '   New   width: ',flw(2)
                  end if
                  end if
            end if
            if(icre.eq.1) then
                  if(tarprop(1).gt.0.001.and.modprop(4).gt.0.001) then
                  sclf = tarprop(4)/tarprop(1) / (modprop(4)/modprop(1))
                  write(*,*)
                  write(*,*) '   Crevasse   Prob: ',creprob(2)
                  write(*,*) '   Scaled       by: ',sclf
                  if(lvert.and..not.lvertng) then
                        do iz=1,nz
                              sclf = pcurve(iz,3)/pcurve(iz,1) 
     +                             /  (modprop(4)/modprop(1))
                              creprz(iz,1) = creprob(1) * sclf
                              creprz(iz,2) = creprob(2) * sclf
                              creprz(iz,3) = creprob(3) * sclf
                        end do
                  else
                        creprob(1) = creprob(1) * sclf
                        creprob(2) = creprob(2) * sclf
                        creprob(3) = creprob(3) * sclf
                        write(*,*) '   New probability:',creprob(2)
                  end if
                  end if
            end if
            write(*,*)
      end if
c
c Reset the channel indicators for the starting set of channels:
c
      do ic=1,mxc
            chanon(ic) = .false.
      end do
      nc = 0
      modprop(0) = 1.0
      do i=1,4
            modprop(i) = 0.0
      end do
c
c Get a starting set of channels (until channel proportion is met):
c
      write(*,*)
      write(*,*) 'Getting a starting set of channels'
 1    if(modprop(0).le.(1.05*tarprop(0))) go to 2
      do i=1,10
            nc = nc + 1
            if(nc.eq.mxc) go to 2

            call getchpar(nc,flong)
      end do
      call rasterc

      write(*,500) nc,modprop(1),modprop(3),modprop(4)
 500  format('   channel ',i3,' channel: ',f6.4,
     +                        ' levee: ',f6.4,
     +                        ' crevasse: ',f6.4)
      go to 1
 2    continue
      do i=1,10
            if(modprop(0).gt.tarprop(0)) go to 3
            chanon(nc) = .false.
            nc = nc - 1
            if(nc.le.1) go to 3
            call rasterc
      end do
 3    continue
      write(*,500) nc,modprop(1),modprop(3),modprop(4)
c
c Save a good copy of the channum and chanind arrays:
c
      do iz=1,nz
            do iy=1,ny
                  do ix=1,nx
                        chanind(ix,iy,iz) = tchanind(ix,iy,iz)
                        channum(ix,iy,iz) = tchannum(ix,iy,iz)
                  end do
            end do
      end do
c
c Establish the initial objective function and scaling:
c
      if(niter.le.0.or.objmin.ge.1.0) go to 5
      write(*,*)
      write(*,*) 'Starting to iterate set of channels'
      if(lwell) write(*,502)
 502  format(/,'     Note that a well mismatch of 10% is considered ',
     +                 'good.',/)
      lreport = .true.

      call getobj(objcur,lreport)

      wellmis = welltry
      lreport = .false.
      objscl = objcur
      if(objcur.lt.EPSLON) go to 5
      objscl = 1.0 / objscl
      write(*,99) 0,objcur*objscl,wellmis
c
c MAIN Loop until convergence:
c
      npert     = 0
      iend      = 0
      temp      = t0
      nnochange = 0
 10   naccept   = 0
      ntry      = 0
c
c Keep perturbing system until we exceed some limit:
c
 20   ntry      = ntry  + 1
      npert     = npert + 1
      nnochange = nnochange + 1
c
c Perturb the set of fluvial geo-objects, get a raster image, and
c update the objective function:
c
 
      call getpert

      call rasterc
      call getobj(objtry,lreport)

c
c Simulated annealing-based rule to accept the perturbation:
c
      accept = .false.
      if(objtry.ge.objcur) then
            if(temp.gt.0.0) then
                  unif = max(EPSLON,real(acorni(idum)))
                  if(objtry*objscl.lt.
     +              (objcur*objscl-dble(temp*alog(unif))))
     +              accept = .true.
            end if
      else
            accept = .true.
      endif
c
c Accept perturbation: reset objective function and update a copy of
c                      the chanind/channum arrays.
c

      if(accept) then
            objcur    = objtry
            wellmis   = welltry
            nnochange = 0
            naccept   = naccept + 1
            do iz=1,nz
                  do iy=1,ny
                        do ix=1,nx
                              chanind(ix,iy,iz) = tchanind(ix,iy,iz)
                              channum(ix,iy,iz) = tchannum(ix,iy,iz)
                        end do
                  end do
            end do
      else
c
c Reject perturbation: undo all channels turned on, turn on channels
c                      that were turned off, and vertically shift those
c                      channels that were moved
c

            do i=1,nonp
                  ic = icon(i)
                  if(ic.ne.0) chanon(ic) = .false.
            end do


            do i=1,noffp
                  ic = icoff(i)
                  if(ic.ne.0) chanon(ic) = .true.
            end do

            do i=1,nvshift
                  ic = shiftc(i)
               if(ic.ne.0) then
                  if(chanon(ic)) then
                        ndelz = -int(shiftp(i))
                        call vshift(ic,ndelz)
                  end if
               endif
            end do
            nc = 0
            do ic=1,mxc
                  if(chanon(ic)) nc = nc + 1
            end do
      end if
c
c Report on status:
c
      write(ldbg,'(i6,f10.6)') npert,objcur*objscl
      if(accept) then
            write(*,100)       npert,objcur*objscl,wellmis
      else
            write(*,101)       npert,objcur*objscl,wellmis
      end if
  99  format('     iteration ',i5,' obj: ',f8.5,
     +                         '  well mismatch: ',f7.2,'%')
 100  format('     iteration ',i5,' obj: ',f8.5,
     +                         '  well mismatch: ',f7.2,'%',
     +                         '  (accept)')
 101  format('     iteration ',i5,' obj: ',f8.5,
     +                         '  well mismatch: ',f7.2,'%',
     +                         '  (reject)')
c
c Are we finished yet?
c
      if(objcur*objscl.lt.objmin.or.iend.ge.numred.or.
     +   npert.eq.niter.or.nnochange.gt.mnoc) then
            if(objcur*objscl.lt.objmin)       write(*,401)
            if(iend.ge.numred)                write(*,402)
            if(npert.eq.niter)                write(*,403)
            if(nnochange.gt.mnoc)             write(*,404)
 401        format(' Stopped because of obj lt objmin')
 402        format(' Stopped because of iend gt num')
 403        format(' Stopped because of npert gt niter')
 404        format(' Stopped because of number of perturbations without'
     +            ,' a change')
            go to 5
      endif
c
c Tried too many at this "temperature"?
c
      if(ntry.gt.kasas.and.temp.gt.1.0e-16) then
            iend = iend + 1
            temp = redfac * temp
            write(*,430) temp
            go to 10
      endif
c
c Accepted enough at this "temperature"?
c
      if(naccept.ge.ksas.and.temp.gt.1.0e-16) then
            temp = redfac * temp
            write(*,430) temp
            iend = 0
            go to 10
      endif
 430  format('  lowering temperature to ',f10.8)
c
c Go back for another attempted swap:
c
      go to 20
c
c Finished with this realization:
c
 5    continue
      lreport = .true.
      call getobj(objtry,lreport)
      write(*,100) npert,objcur*objscl,wellmis
      write(*,500) nc,modprop(1),modprop(3),modprop(4)
      write(ldbg,'(i6,f10.6)') npert,objcur*objscl
c
c Write this realization to the output file:
c
      write(*,*)
      write(*,*) 'Writing this realization to output files'
      do i=0,4
            modprop(i) = 0.0
      end do
      do iz=1,nz
      do iy=1,ny
      do ix=1,nx
            icode = chanind(ix,iy,iz)
c
c Determine if this is an "edge" cell:
c
            if(icode.eq.1) then 
                  ichan = channum(ix,iy,iz)
                  ixl   = max((ix-1), 1)
                  ixu   = min((ix+1),nx)
                  iyl   = max((iy-1), 1)
                  iyu   = min((iy+1),ny)
                  izl   = max((iz-1), 1)
                  if(channum(ixl,iy ,iz ).ne.ichan)icode =2 
                  if(channum(ixu,iy ,iz ).ne.ichan)icode =2
                  if(channum(ix ,iyl,iz ).ne.ichan)icode =2
                  if(channum(ix ,iyu,iz ).ne.ichan)icode =2
                  if(channum(ix ,iy ,izl).ne.ichan)icode =2
            end if
            modprop(icode) = modprop(icode) + 1.
c
c Write this cell to file (buffered output)
c
            write(lout,'(i2)')       icode
c           write(lout,'(i2,1x,i4)') icode,channum(ix,iy,iz)
      end do
      end do
      end do
      do i=0,4
            modprop(i) = modprop(i) / real(nx*ny*nz)
      end do
      write(*,600) modprop(0),tarprop(0),
     +             modprop(1)+modprop(2),tarprop(1),
     +             modprop(3),tarprop(3),
     +             modprop(4),tarprop(4)
 600  format(/,' Proportion of floodplain shale = ',f6.4,
     +         ' (target = ',f6.4,')',/,
     +         ' Proportion of channel sand     = ',f6.4,
     +         ' (target = ',f6.4,')',/,
     +         ' Proportion of levee sand       = ',f6.4,
     +         ' (target = ',f6.4,')',/,
     +         ' Proportion of crevasse sand    = ',f6.4,
     +         ' (target = ',f6.4,')',/)
c
c Write the geometry data:
c
      do ic=1,mxc
            if(chanon(ic)) then
                  write(lgeo,511) ic,cz(ic),nyc(ic)
 511              format(' Channel ',i3,' Z ',f6.1,' ny ',i4)
                  do iy=1,nyc(ic)
                        write(lgeo,512)cx(ic,iy,4),cw(ic,iy),ct(ic,iy,4)
 512                    format(12(f12.3,1x))
                  end do
            end if
      end do
c
c Write the proportion data:
c
      if(lvert) then
            do iz=1,nz
                  write(lpv,515) iz,pcurve(iz,1),pcurvea(iz,1),
     +                              pcurve(iz,2),pcurvea(iz,2),
     +                              pcurve(iz,3),pcurvea(iz,3)
 515              format(i3,1x,3(1x,f7.4,1x,f7.4))
            end do
      end if
      if(larea) then
            do iy=1,ny
                  do ix=1,nx
                        write(lpa,516) pmap(ix,iy,1),pmapa(ix,iy,1),
     +                                 pmap(ix,iy,2),pmapa(ix,iy,2),
     +                                 pmap(ix,iy,3),pmapa(ix,iy,3)
 516                    format(3(1x,f7.4,1x,f7.4))
                  end do
            end do
      end if
c
c Write the well data:
c
      if(lwell) then
            do i=1,nwd
                  ix = xw(i)
                  iy = yw(i)
                  iz = zw(i)
                  ii = 0
                  if(channum(ix,iy,iz).ne.0) 
     +                ii = chanind(xw(i),yw(i),zw(i)) 
                  write(lwd,520) xw(i),yw(i),zw(i),fw(i),ii,
     +                           channum(ix,iy,iz)
 520              format(3i4,1x,2i2,1x,i4)
            end do
            write(*,*)
            write(*,*) ' Percent Mismatch at Well = ',wellmis
      end if
c
c Return to the main program:
c
      return
      end



      subroutine getchpar(ic,flong)
c-----------------------------------------------------------------------
c
c Establish a set of legitimate parameters for channel "ic" given input
c triangular distributions
c
c
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
      real*8    acorni
      real      testx(4),testy(4)
      logical   testpt(4),flong
c
c Turn channel on and get Z position:
c
      if(ic.le.0.or.ic.gt.mxc) ic = 1
      chanon(ic) = .true.
      cz(ic)     = real(acorni(idum))
c
c Get orientation angle within -45 to 135 and not exactly 90.0:
c
      cang(ic)   = getval(fco)
 1    if(cang(ic).gt.135.0) cang(ic) = cang(ic) - 180.0
      if(cang(ic).lt.-45.0) cang(ic) = cang(ic) + 180.0
      if(cang(ic).lt.-45.0.or.cang(ic).gt.135.0) go to 1
      if(abs(cang(ic)-90.0).lt.0.001) cang(ic) = 89.99
      ccosa(ic)  = cos(cang(ic)*DEGTOR)
      csina(ic)  = sin(cang(ic)*DEGTOR)
      ctana(ic)  = tan(cang(ic)*DEGTOR)
      if(abs(ctana(ic)).lt.0.001) ctana(ic) = 0.001
c
c Establish a first estimate of the origin of the channel line depending
c on whether the channel is aligned closer to the X or Y axis:
c
      if(abs(csina(ic)).gt.abs(ccosa(ic))) then
            cxorigin(ic) = cxmin
            if(ccosa(ic).le.0.0) then
                  cyl = cymin
                  cyu = cxmax - ccosa(ic)*(cxmax-cxmin)
            else
                  cyl = cymin - 0.5*ysiz - ccosa(ic)*(xmx-cxmin)
                  cyu = cymax
            end if
            cyorigin(ic) = cyl + real(acorni(idum))*(cyu-cyl)
      else
            cyorigin(ic) = cymin
            if(csina(ic).le.0.0) then
                  cxl = cxmin
                  cxu = cxmax - csina(ic)*(ymx-cymin)
            else
                  cxl = cxmin - 0.5*xsiz - csina(ic)*(ymx-cymin)
                  cxu = cxmax
            end if
            cxorigin(ic) = cxl + real(acorni(idum))*(cxu-cxl)
      end if
c
c Settle on an origin (as close as possible to the area of interest) and
c length (nyc) that keeps channel in area of interest:
c
      testx(1)  = cxmin
      testy(1)  = cyorigin(ic) - (cxorigin(ic)-testx(1))/ctana(ic)
      testpt(1) = .false.
      if(testy(1).ge.cymin.and.testy(1).le.cymax) testpt(1) = .true.

      testx(2)  = cxmax
      testy(2)  = cyorigin(ic) - (cxorigin(ic)-testx(2))/ctana(ic)
      testpt(2) = .false.
      if(testy(2).ge.cymin.and.testy(2).le.cymax) testpt(2) = .true.

      testy(3)  = cymin
      testx(3)  = cxorigin(ic) - (cyorigin(ic)-testy(3))*ctana(ic)
      testpt(3) = .false.
      if(testx(3).ge.cxmin.and.testx(3).le.cxmax) testpt(3) = .true.

      testy(4)  = cymax
      testx(4)  = cxorigin(ic) - (cyorigin(ic)-testy(4))*ctana(ic)
      testpt(4) = .false.
      if(testx(4).ge.cxmin.and.testx(4).le.cxmax) testpt(4) = .true.
c
c Get origin that is in the grid (recall that the origin may be outside
c to allow a sinuous channel to cut the edge of the model):
c
      testmax = 1.0e20
      iorigin = 1
      do i=1,4
            if(testpt(i)) then
                  testdis = (cxorigin(ic)-testx(i))**2
     +                    + (cyorigin(ic)-testy(i))**2
                  if(testdis.lt.testmax) then
                        iorigin = i
                        testmax = testdis
                  end if
            end if
      end do
      cxorigin(ic) = testx(iorigin)
      cyorigin(ic) = testy(iorigin)
c
c Establish how long the channel must be to keep it in the grid:
c
      testmax = 0.0
      do i=1,4
            if(testpt(i)) then
                  testlen = sqrt( (cxorigin(ic)-testx(i))**2 +
     +                            (cyorigin(ic)-testy(i))**2 )
                  if(testlen.gt.testmax) testmax = testlen
            end if
      end do
      nyc(ic) = testmax / cdy
      if(nyc(ic).lt.10)   nyc(ic) = 10
      if(nyc(ic).gt.MAXL) then
            write(*,*) 'WARNING: attempting a channel ',nyc(ic),'long'
            write(*,*) '                    only have ',MAXL
            nyc(ic) = MAXL
      end if
c
c Force the channel to be long? (because it may get moved around)
c
      if(flong) nyc(ic) = MAXL
c
c Channel center line:
c
      range      = getval(fcal)
      avgdep     = getval(fcad)
      call get1d(nyc(ic),cdy,range,rarray)
      do iy=1,nyc(ic)
            ccent(ic,iy) = rarray(iy)*avgdep
            chx(iy)      = ccent(ic,iy)
      end do
c
c Channel thickness:
c
      avgthick   = getval(fct)
      avgdep     = getval(fctu)
      if(avgdep.ge.0.95.and.avgdep.le.1.05) then
            do iy=1,nyc(ic)
                  rarray(iy) = 0.0
            end do
      else
            range = getval(fctul)
            call get1d(nyc(ic),cdy,range,rarray)
      end if
      do iy=1,nyc(ic)
            ct(ic,iy,1) = 0.0
            ct(ic,iy,4) = avgthick * (1.0+rarray(iy))*avgdep
            ct(ic,iy,7) = 0.0
      end do
c
c Channel width:
c
      cwtr   = getval(fcwt)
      avgdep = getval(fcwu)
      if(avgdep.ge.0.95.and.avgdep.le.1.05) then
            do iy=1,nyc(ic)
                  rarray(iy) = 0.0
            end do
      else
            range = getval(fcwul)
            call get1d(nyc(ic),cdy,range,rarray)
      end if
      do iy=1,nyc(ic)
            width = (1.0+rarray(iy)) * cwtr * ct(ic,iy,4)
            cx(ic,iy,1) = chx(iy) - 0.5*width
            cx(ic,iy,7) = chx(iy) + 0.5*width
      end do
c
c Channel curvature and relative position:
c
      do i=1,nyc(ic)-2
            tt = sqrt(1.0+(chx(i+1)-chx(i))**2)
            p1 = atan(chx(i+1)-chx(i))
            p2 = atan(chx(i+2)-chx(i+1))
            rarray(i) = (p2-p1)/max(tt,EPSLON)
      end do
      rarray(nyc(ic)-1) = rarray(nyc(ic)-2)
      rarray(nyc(ic))   = rarray(nyc(ic)-2)
      curmaxn = -1.0e20
      curmaxp = -1.0e20
      do i=1,nyc(ic)
            sval = 0.0
            nsm  = 0
            do j=-5,5
                  k = i + j
                  if(k.ge.1.and.k.le.nyc(ic)) then
                        sval = sval + rarray(k)
                        nsm  = nsm + 1
                  end if
            end do
            chx(i) = sval / max(real(nsm),EPSLON)
            if(chx(i).lt.0.0) then
                  if(abs(chx(i)).gt.curmaxn) curmaxn = abs(chx(i))
            else
                  if(chx(i).gt.curmaxp) curmaxp = chx(i)
            end if
      end do
      curmaxp = max((2.5 * curmaxp),EPSLON)
      curmaxn = max((2.5 * curmaxn),EPSLON)
      do i=1,nyc(ic)
            if(abs(0.5-chx(i)).eq.EPSLON) then
                  chx(i) = 0.5
            else if(chx(i).lt.0.0) then
                  chx(i) = 0.5 * (1.0-abs(chx(i))/curmaxn)
            else
                  chx(i) = 0.5 * (1.0+chx(i)/curmaxp)
            end if
      end do
c
c Now, finish the channel cross section arrays cx and ct using chx as
c the position of maximum thickness:
c
      do iy=1,nyc(ic)

            cx(ic,iy,4) = cx(ic,iy,1)+chx(iy)*(cx(ic,iy,7)-cx(ic,iy,1))

            cx(ic,iy,2) = cx(ic,iy,1)+1.0/3.0*(cx(ic,iy,4)-cx(ic,iy,1))
            call csect(cx(ic,iy,1),cx(ic,iy,7),chx(iy),ct(ic,iy,4),
     +                 cx(ic,iy,2),ct(ic,iy,2))
            cx(ic,iy,3) = cx(ic,iy,1)+2.0/3.0*(cx(ic,iy,4)-cx(ic,iy,1))
            call csect(cx(ic,iy,1),cx(ic,iy,7),chx(iy),ct(ic,iy,4),
     +                 cx(ic,iy,3),ct(ic,iy,3))

            cx(ic,iy,5) = cx(ic,iy,4)+1.0/3.0*(cx(ic,iy,7)-cx(ic,iy,4))
            call csect(cx(ic,iy,1),cx(ic,iy,7),chx(iy),ct(ic,iy,4),
     +                 cx(ic,iy,5),ct(ic,iy,5))
            cx(ic,iy,6) = cx(ic,iy,4)+2.0/3.0*(cx(ic,iy,7)-cx(ic,iy,4))
            call csect(cx(ic,iy,1),cx(ic,iy,7),chx(iy),ct(ic,iy,4),
     +                 cx(ic,iy,6),ct(ic,iy,6))

      end do
c
c Build the template for this channel:
c
      call getindx(nz,zmn,zsiz,cz(ic),izhi,inflag)
      izhitem(ic) = izhi
      do iy=1,nyc(ic)
            if(cx(ic,iy,1).lt.0.0) then
                  ixlotem(ic,iy) = int(cx(ic,iy,1)/cdy-0.5)
            else
                  ixlotem(ic,iy) = int(cx(ic,iy,1)/cdy+0.5)
            end if
            if(cx(ic,iy,7).lt.0.0) then
                  ixhitem(ic,iy) = int(cx(ic,iy,7)/cdy-0.5)
            else
                  ixhitem(ic,iy) = int(cx(ic,iy,7)/cdy+0.5)
            end if

            if(ixlotem(ic,iy).lt.-MAXW.or.ixhitem(ic,iy).gt.MAXW) then
                  write(*,*) 'WARNING: channel too wide '
                  if(ixlotem(ic,iy).lt.-MAXW) ixlotem(ic,iy) = -MAXW
                  if(ixhitem(ic,iy).gt. MAXW) ixhitem(ic,iy) =  MAXW
            end if

            zbot = cz(ic) - ct(ic,iy,4)
            call getindx(nz,zmn,zsiz,zbot,izbot,inflag)

            xx = real(ixlotem(ic,iy)-1)*cdy
            do ix=ixlotem(ic,iy),ixhitem(ic,iy)

                  xx = xx + cdy
                  izlotem(ic,iy,ix) = izhi+1

                  if(xx.gt.cx(ic,iy,1).and.xx.lt.cx(ic,iy,7)) then

                  do i=2,7
                        if(xx.le.cx(ic,iy,i)) then
                              zl = cz(ic) - ( ct(ic,iy,i-1) +
     +              (xx-cx(ic,iy,i-1))/(cx(ic,iy,i)-cx(ic,iy,i-1))
     +                   * (ct(ic,iy,i)-ct(ic,iy,i-1)) )
                              go to 2
                        end if
                  end do
 2                continue

                  if(zl.gt.1.0) then
                        izlotem(ic,iy,ix) = izhi + 1
                  else
                        call getindx(nz,zmn,zsiz,zl,izlo,inflag)
                        izlotem(ic,iy,ix) = izlo
                  end if

                  end if

            end do

      end do
c
c Do we need to build levee template?
c

      if(ilev.eq.1) then
            range   = 0.5*real(nyc(ic))*ysiz

            if(lvert.and..not.lvertng) then
                  iiz    = izhitem(ic)
                  flw(1) = flwz(iiz,1)
                  flw(2) = flwz(iiz,2)
                  flw(3) = flwz(iiz,3)
            end if
            awidth  = getval(flw)
            htfac   = getval(flh)
            redfac  = getval(fld)
            call get1d(nyc(ic),cdy,range,rarray)
            do iy=1,nyc(ic)
                  dep = cz(ic) - redfac*ct(ic,iy,4)
                  call getindx(nz,zmn,zsiz,dep,idep,inflag)
                  llzlo(ic,iy) = idep
                  llwid(ic,iy) = 1 + int((awidth+0.25*rarray(iy))/cdy)
                  if(llwid(ic,iy).gt.MAXBW) llwid(ic,iy) = MAXBW
                  wid = real(llwid(ic,iy))
                  nbw = min(llwid(ic,iy),MAXBW)
                  ht  = htfac*ct(ic,iy,4)
                  do ix=1,nbw
                        call csect(0.0,wid,0.25,ht,real(ix),thick)
                        dep = cz(ic) + thick
                        call getindx(nz,zmn,zsiz,dep,idep,inflag)
                        llbh(ic,iy,ix) = idep
                  end do
            end do

            awidth  = getval(flw)
            htfac   = getval(flh)
            redfac  = getval(fld)
            call get1d(nyc(ic),cdy,range,rarray)
            do iy=1,nyc(ic)
                  dep     = cz(ic) - redfac*ct(ic,iy,4)
                  call getindx(nz,zmn,zsiz,dep,idep,inflag)
                  rlzlo(ic,iy) = idep
                  rlwid(ic,iy) = 1 + int((awidth+0.25*rarray(iy))/cdy)
                  if(rlwid(ic,iy).gt.MAXBW) rlwid(ic,iy) = MAXBW
                  wid = real(rlwid(ic,iy))
                  nbw = min(rlwid(ic,iy),MAXBW)
                  ht  = htfac*ct(ic,iy,4)
                  do ix=1,nbw
                        call csect(0.0,wid,0.25,ht,real(ix),thick)
                        dep = cz(ic) + thick
                        call getindx(nz,zmn,zsiz,dep,idep,inflag)
                        rlbh(ic,iy,ix) = idep
                  end do
            end do

      end if
c
c Consider adding crevasse splays?
c

      if(icre.eq.1) then
            if(lvert.and..not.lvertng) then
                  iiz        = izhitem(ic)
                  creprob(1) = creprz(iiz,1)
                  creprob(2) = creprz(iiz,2)
                  creprob(3) = creprz(iiz,3)
            end if
            ncre(ic)  = int(getval(creprob)+0.5)
            if(creprob(3).lt.1.0.and.
     +         real(acorni(idum)).lt.creprob(2)) ncre(ic) = 1
            if(ncre(ic).gt.MAXCRE) ncre(ic) = MAXCRE
            if(ncre(ic).gt.0) then
c
c Get a 1-D array of crevasse occurence probability along the channel:
c
                  sumprob = 0.0
                  do iy=1,nyc(ic)
                        rarray(iy) = 0.25 - chx(iy)*(1.0-chx(iy))
                        sumprob    = sumprob + rarray(iy)
                  end do
                  sumprob   =   1.0     / sumprob
                  rarray(1) = rarray(1) * sumprob
                  do iy=2,nyc(ic)
                        rarray(iy) = rarray(iy-1) + rarray(iy)*sumprob
                  end do
            end if
c
c Establish the locations of the crevasses:
c
            do icrev=1,ncre(ic)
                  cdf = real(acorni(idum))
                  plo = 0.0
                  do iy=1,nyc(ic)
                        if(cdf.ge.plo.and.cdf.le.rarray(iy)) then
                              jy = iy
                              go to 4
                        end if
                  end do
 4                cryloc(ic,icrev)  = jy
                  if(chx(jy).lt.0.5) then
                        crright(ic,icrev) = .true.
                        crxloc(ic,icrev)  = ixhitem(ic,jy) - 1
                  else
                        crright(ic,icrev) = .false.
                        crxloc(ic,icrev)  = ixlotem(ic,jy)
                  end if
                  crnum(ic,icrev) = 1 + int(real(acorni(idum))*MAXCRE)
                  crt(ic,icrev)  = getval(fcrt)
            end do
      end if
c
c Finished assigning parameters for this channel:
c
      return
      end



      subroutine rasterc
c-----------------------------------------------------------------------
c
c Go through all channels and their associated levees and crevasses
c creating a raster image of the lithofacies types
c
c
c
c-----------------------------------------------------------------------
      parameter(DEG2RAD=3.141592654/180.0)
      include  'fluvsim.inc'
      real      tmpcn(MAXC),tmpcz(MAXC)
      logical   inflag
c
c Get time order of channels:
c
      nc = 0
      do ic=1,mxc
            if(chanon(ic)) then
                  nc = nc + 1
                  tmpcn(nc) = real(ic)
                  tmpcz(nc) = cz(ic)
            end if
      end do
      call sortem(1,nc,tmpcz,1,tmpcn,c,d,e,f,g,h)
c
c Reset channel arrays:
c
      do iz=1,nz
            do iy=1,ny
                  do ix=1,nx
                        tchanind(ix,iy,iz) =  0
                        tchannum(ix,iy,iz) =  0
                  end do
            end do
      end do
c
c Loop over all channels:
c
      do iloopc=1,nc
            ic  = int(tmpcn(iloopc)+0.5)
            do iy=1,nyc(ic)
                  do ix=ixlotem(ic,iy),ixhitem(ic,iy)
c
c Get position in "real" coordinates (not channel coordinates):
c
                        yalongc = real(iy)*cdy
                        xalongc = real(ix)*cdy
                        yy = -csina(ic)*xalongc + ccosa(ic)*yalongc
     +                                          + cyorigin(ic)
                        call getindx(ny,ymn,ysiz,yy,iiy,inflag)
                        if(.not.inflag) go to 30
                        xx =  ccosa(ic)*xalongc + csina(ic)*yalongc
     +                                          + cxorigin(ic)
                        call getindx(nx,xmn,xsiz,xx,iix,inflag)
                        if(.not.inflag) go to 30
c
c Code this stack if it is in the grid:
c
                        do iz=izlotem(ic,iy,ix),izhitem(ic)
                              tchanind(iix,iiy,iz) =  1
                              tchannum(iix,iiy,iz) = ic
                        end do
 30                     continue
                  end do
c
c Add levees?
c
                  if(ilev.eq.1) then
c
c Left side:
c
                  ix       = min((ixlotem(ic,iy)-llwid(ic,iy)-1),MAXBW)
                  ixfinish = (ixlotem(ic,iy)+ixhitem(ic,iy))/2
                  nloop    = ixfinish - ix
                  do iloop=1,nloop
                        ix = ix + 1
c
c - get position in "real" coordinates (not channel coordinates):
c
                        yalongc = real(iy)*cdy
                        xalongc = real(ix)*cdy
                        yy = -csina(ic)*xalongc + ccosa(ic)*yalongc
     +                                          + cyorigin(ic)
                        call getindx(ny,ymn,ysiz,yy,iiy,inflag)
                        if(.not.inflag) go to 31
                        xx =  ccosa(ic)*xalongc + csina(ic)*yalongc
     +                                          + cxorigin(ic)
                        call getindx(nx,xmn,xsiz,xx,iix,inflag)
                        if(.not.inflag) go to 31
c
c - get Z limits:
c
                        iztop = izhitem(ic)
                        kx    = min(iloop,MAXBW)
                        if(iloop.le.llwid(ic,iy)) 
     +                  iztop = llbh(ic,iy,llwid(ic,iy)+1-kx)
                        izbot = iztop + 1
                        kx = min((ix + llwid(ic,iy)),ixhitem(ic,iy))
                        do iz=llzlo(ic,iy),izhitem(ic)
                              if(izlotem(ic,iy,kx).le.iz) then
                                    izbot = iz
                                    go to 10
                              end if
                        end do
 10                     continue
c
c - assign levee codes (if needed):
c
                        do iz=izbot,iztop
                              if(tchannum(iix,iiy,iz).ne.ic) then
                                    tchanind(iix,iiy,iz) =  3
                                    tchannum(iix,iiy,iz) = -ic
                              end if
                        end do
 31               continue
                  end do
c
c Right side:
c
                  ix       = ixhitem(ic,iy)+rlwid(ic,iy) + 1
                  ixfinish = (ixlotem(ic,iy)+ixhitem(ic,iy))/2
                  nloop    = ix - ixfinish
                  do iloop=1,nloop
                        ix = ix - 1
c
c - get position in "real" coordinates (not channel coordinates):
c
                        yalongc = real(iy)*cdy
                        xalongc = real(ix)*cdy
                        yy = -csina(ic)*xalongc + ccosa(ic)*yalongc
     +                                          + cyorigin(ic)
                        call getindx(ny,ymn,ysiz,yy,iiy,inflag)
                        if(.not.inflag) go to 32
                        xx =  ccosa(ic)*xalongc + csina(ic)*yalongc
     +                                          + cxorigin(ic)
                        call getindx(nx,xmn,xsiz,xx,iix,inflag)
                        if(.not.inflag) go to 32
c
c - get Z limits:
c
                        iztop = izhitem(ic)
                        if(iloop.le.rlwid(ic,iy)) then
                              kx    = min((rlwid(ic,iy)-iloop+1),MAXBW)
                              iztop = rlbh(ic,iy,kx)
                        end if
                        izbot = iztop + 1
                        kx = max((ix - rlwid(ic,iy)),ixlotem(ic,iy))
                        do iz=rlzlo(ic,iy),izhitem(ic)
                              if(izlotem(ic,iy,kx).le.iz) then
                                    izbot = iz
                                    go to 11
                              end if
                        end do
 11                     continue
         if(iztop.lt.0.0.or.iztop.gt.nz) then
              write(*,*) 'oops'
         end if
c
c - assign levee codes (if needed):
c
                        do iz=izbot,iztop
                              if(tchannum(iix,iiy,iz).ne.ic) then
                                    tchanind(iix,iiy,iz) =  3
                                    tchannum(iix,iiy,iz) = -ic
                              end if
                        end do
 32               continue
                  end do
c
c Finished adding levees.
c
                  end if
c
c Finished looping over y slices along channel.
c
            end do
c
c Consider adding crevasses:
c
            if(icre.eq.1) then

            do icrev=1,ncre(ic)
                  kcre = crnum(ic,icrev)
                  iz   = izhitem(ic)
                  iy   = cryloc(ic,icrev)
                  do jx=0,MAXCRX
                  do jy=-MAXCRY,MAXCRY
                     if(cre(kcre,jx,jy)) then
                        iy = cryloc(ic,icrev) + jy
                        ix = crxloc(ic,icrev) - jx
                        if(crright(ic,icrev)) ix = crxloc(ic,icrev)+jx
c
c - get position in "real" coordinates (not channel coordinates):
c
                        yalongc = real(iy)*cdy
                        xalongc = real(ix)*cdy
                        yy = -csina(ic)*xalongc + ccosa(ic)*yalongc
     +                                          + cyorigin(ic)
                        call getindx(ny,ymn,ysiz,yy,iiy,inflag)
                        if(.not.inflag) go to 1
                        xx =  ccosa(ic)*xalongc + csina(ic)*yalongc
     +                                          + cxorigin(ic)
                        call getindx(nx,xmn,xsiz,xx,iix,inflag)
                        if(.not.inflag) go to 1
c
c - do we need to erase the levee (bank above channel) at this location?
c
                        if(ilev.eq.1) then
                              do iz=izhitem(ic),nz
                                    if(tchannum(iix,iiy,iz).eq.-ic) then
                                          tchannum(iix,iiy,iz) = 0
                                          tchanind(iix,iiy,iz) = 0
                                    end if
                              end do
                        end if
c
c - get thickness and code crevasse:
c
                        thick  = crt(ic,icrev)*(MAXCRX-real(jx))/MAXCRX
                        nthick = 1 + int(thick/zsiz)
                        do iz=izhitem(ic),izhitem(ic)-nthick,-1
                              if(iz.ge.1) then
                                    tchannum(iix,iiy,iz) = ic
                                    tchanind(iix,iiy,iz) = 4
                              end if
                        end do
 1                      continue 
                     end if
                  end do
                  end do
c
c - finish crevasse templates:
c
            end do

            end if
      end do
c
c Calculate global proportion:
c
      do i=0,4
            modprop(i) = 0.0
      end do
      do iz=1,nz
            do iy=1,ny
                  do ix=1,nx
                        ii = tchanind(ix,iy,iz)
                        modprop(ii) = modprop(ii) + 1.
                  end do
            end do
      end do
      do i=0,4
            modprop(i) = modprop(i) / real(nx*ny*nz)
      end do
c
c Calculate vertical proportion curves if needed:
c
      if(lvert) then
            do iz=1,nz
                  do i=1,3
                        pcurvea(iz,i) = 0.0
                  end do
                  do iy=1,ny
                        do ix=1,nx
                              if(lvertng) then
                                    if(tchannum(ix,iy,iz).ne.0)
     +                              pcurvea(iz,1) = pcurvea(iz,1) + 1.
                              else
                                    if(tchanind(ix,iy,iz).eq.1)
     +                              pcurvea(iz,1) = pcurvea(iz,1) + 1.
                                    if(tchanind(ix,iy,iz).eq.3)
     +                              pcurvea(iz,2) = pcurvea(iz,2) + 1.
                                    if(tchanind(ix,iy,iz).eq.4)
     +                              pcurvea(iz,3) = pcurvea(iz,3) + 1.
                              end if
                        end do
                  end do
                  do i=1,3
                        pcurvea(iz,i) = pcurvea(iz,i) / real(nx*ny)
                  end do
            end do
      end if
c
c Calculate areal proportion maps if needed:
c
      if(larea) then
            do iy=1,ny
                  do ix=1,nx
                        do i=1,3
                              pmapa(ix,iy,i) = 0.0
                        end do
                        do iz=1,nz
                              if(lareang) then
                                    if(tchannum(ix,iy,iz).ne.0)
     +                              pmapa(ix,iy,1) = pmapa(ix,iy,1)+1.
                              else
                                    if(tchanind(ix,iy,iz).eq.1)
     +                              pmapa(ix,iy,1) = pmapa(ix,iy,1)+1.
                                    if(tchanind(ix,iy,iz).eq.3)
     +                              pmapa(ix,iy,2) = pmapa(ix,iy,2)+1.
                                    if(tchanind(ix,iy,iz).eq.4)
     +                              pmapa(ix,iy,3) = pmapa(ix,iy,3)+1.
                              end if
                        end do
                        do i=1,3
                              pmapa(ix,iy,i) = pmapa(ix,iy,i) / real(nz)
                        end do
                  end do
            end do
      end if
c
c Return with raster image of channels:
c
      return
      end



      subroutine getobj(obj,lreport)
c-----------------------------------------------------------------------
c
c Get the component objective functions for simulated annealing
c
c
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
      logical lreport
c
c Matrix of objective function values for well:
c
      real wobjfun(0:4,0:4)
      data wobjfun/ 0.0, 1.0, 1.0, 1.0, 1.0,
     +              1.0, 0.0, 1.0, 1.0, 1.0,
     +              1.0, 1.0, 0.0, 1.0, 1.0,
     +              1.0, 1.0, 1.0, 0.0, 1.0,
     +              1.0, 1.0, 1.0, 1.0, 0.0 /
c      data wobjfun/ 0.0, 1.0, 1.0, 0.5, 0.5,
c     +              1.0, 0.0, 0.0, 0.2, 0.2,
c     +              1.0, 0.0, 0.0, 0.2, 0.2,
c     +              0.5, 0.2, 0.2, 0.0, 0.2,
c     +              0.5, 0.2, 0.2, 0.2, 0.0  /
c
c Establish total objective function:
c
      obj = 0.0
c
c Global proportions?
c
      if(lglob) then
            obj = obj + sclglob * (tarprop(0)-modprop(0))
     +                          * (tarprop(0)-modprop(0))
            obj = obj + sclglob * (tarprop(1)-modprop(1))
     +                          * (tarprop(1)-modprop(1))
            if(ilev.eq.1) obj = obj + sclglob * (tarprop(3)-modprop(3))
     +                                        * (tarprop(3)-modprop(3))
            if(icre.eq.1) obj = obj + sclglob * (tarprop(4)-modprop(4))
     +                                        * (tarprop(4)-modprop(4))

            if(lreport) write(ldbg,101) tarprop(0),modprop(0),
     +                                  tarprop(1),modprop(1),
     +                                  tarprop(3),modprop(3),
     +                                  tarprop(4),modprop(4)
 101        format(/,' Target shale    proportion = ',f6.4,
     +               ' actual proportion = ',f6.4,/,
     +               ' Target channel  proportion = ',f6.4,
     +               ' actual proportion = ',f6.4,/,
     +               ' Target levee    proportion = ',f6.4,
     +               ' actual proportion = ',f6.4,/,
     +               ' Target crevasse proportion = ',f6.4,
     +               ' actual proportion = ',f6.4,/)
           
      end if
c
c Vertical proportion curves?
c
      if(lvert) then
            objt = 0.0
            do iz=1,nz
                  if(lvertng) then
                        objt = objt + (pcurve(iz,1)-pcurvea(iz,1))
     +                              * (pcurve(iz,1)-pcurvea(iz,1))
                  else
                        objt = objt + (pcurve(iz,1)-pcurvea(iz,1))
     +                              * (pcurve(iz,1)-pcurvea(iz,1))
                        if(ilev.eq.1)
     +                  objt = objt + (pcurve(iz,2)-pcurvea(iz,2))
     +                              * (pcurve(iz,2)-pcurvea(iz,2))
                        if(icre.eq.1)
     +                  objt = objt + (pcurve(iz,3)-pcurvea(iz,3))
     +                              * (pcurve(iz,3)-pcurvea(iz,3))
                  end if
            end do
            obj = obj + sclvert*objt
c
c Report current values if requested:
c
            if(lreport) then
               write(ldbg,102)
 102           format(/,'Vertical proportion curve reproduction')
               do iz=1,nz
                  write(ldbg,103) iz,pcurve(iz,1),pcurvea(iz,1),
     +                               pcurve(iz,2),pcurvea(iz,2),
     +                               pcurve(iz,3),pcurvea(iz,3)
 103              format(i3,1x,3(1x,f7.4,1x,f7.4))
               end do
            end if
      end if
c
c Areal proportion maps?
c
      if(larea) then
            objt = 0.0
            do iy=1,ny
                  do ix=1,nx
                     if(lareang) then
                        objt = objt + (pmap(ix,iy,1)-pmapa(ix,iy,1))
     +                              * (pmap(ix,iy,1)-pmapa(ix,iy,1))
                     else
                        objt = objt + (pmap(ix,iy,1)-pmapa(ix,iy,1))
     +                              * (pmap(ix,iy,1)-pmapa(ix,iy,1))
                        if(ilev.eq.1)
     +                  objt = objt + (pmap(ix,iy,2)-pmapa(ix,iy,2))
     +                              * (pmap(ix,iy,2)-pmapa(ix,iy,2))
                        if(icre.eq.1)
     +                  objt = objt + (pmap(ix,iy,3)-pmapa(ix,iy,3))
     +                              * (pmap(ix,iy,3)-pmapa(ix,iy,3))
                     end if
                  end do
            end do
            obj = obj + sclarea*objt
c
c Report current values if requested:
c
            if(lreport) then
               write(ldbg,105)
 105           format(/,'Areal proportion map reproduction')
               do iy=1,ny
                  do ix=1,nx
                     write(ldbg,106) pmap(ix,iy,1),pmapa(ix,iy,1),
     +                               pmap(ix,iy,2),pmapa(ix,iy,2),
     +                               pmap(ix,iy,3),pmapa(ix,iy,3)
 106                 format(3(1x,f7.4,1x,f7.4))
                  end do
               end do
            end if
      end if
c
c Well data?
c
      welltry = 0.
      if(lwell) then
            objt = 0.0
            do iwc=1,nwd
                  ix   = xw(iwc)
                  iy   = yw(iwc)
                  iz   = zw(iwc)
                  imod = tchanind(ix,iy,iz)
                  iwel = fw(iwc)
                  objt = objt + wobjfun(imod,iwel)*wfac
                  if(iwel.ne.imod) welltry = welltry + 1.
            end do
            welltry = welltry / real(max(nwd,1)) * 100.0
            obj     = obj + sclwell*objt
      end if
c
c Finished with objective function:
c
      return
      end



      subroutine getpert
c-----------------------------------------------------------------------
c
c Specify a perturbation for the iterative procedure used for
c conditioning
c
c Probabilities:  1.  cumprob(1)               --> one on and one off
c                 2.  cumprob(2) - cumprob(1)  --> one on
c                 3.  cumprob(3) - cumprob(2)  --> one off
c                 4.     1.0     - cumprob(3)  --> fix well intersection
c
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
      real*8    acorni
      logical   flong
c
c Initialize counters of changes made this perturbation:
c
      flong   = .false.
      nonp    = 0
      noffp   = 0
      nvshift = 0
c
c Find a place to turn a channel on (don't want to overwrite a channel
c that has been turned off and that may need to be turned on again).
c
      ion  =-1
      do i=1,mxc+1
            if(.not.chanon(i).and.ion.le.0) ion = i
      end do
      if(ion.le.0.or.ion.gt.MAXC) ion = 1
      icon(1) = ion
c
c Decide what to do:
c
 10   pval = real(acorni(idum))
      if(pval.le.cumprob(1)) go to 1
      if(pval.le.cumprob(2)) go to 2
      if(pval.le.cumprob(3)) go to 3
                             go to 4
c
c Option 1: turn a channel off and turn another on:
c
 1    continue
      ioff = 1 + real(acorni(idum))*nc
      non  = 0
      do i=1,mxc+1
            if(chanon(i)) then
                  non = non + 1 
                  if(non.eq.ioff) then
                        noffp        = noffp + 1
                        icoff(noffp) = i
                        chanon(i)    = .false.
                  end if
            end if
      end do
      nonp = 1
      ion  = icon(1)
      call getchpar(ion,flong)
      return
c
c Option 2: turn a channel on:
c
 2    continue
      nonp = 1
      ion  = icon(1)
      call getchpar(ion,flong)
      return
c
c Option 3: turn a channel off:
c
 3    continue
      ioff = 1 + real(acorni(idum))*nc
      non  = 0
      do i=1,mxc+1
            if(chanon(i)) then
                  non = non + 1 
                  if(non.eq.ioff) then
                        noffp        = noffp + 1
                        icoff(noffp) = i
                        chanon(i)    = .false.
                  end if
            end if
      end do
      return
c
c Option 4: go to a well intersection and try to fix up:
c
 4    continue
      if(nwint.le.0) go to 10
 11   ipick = 1 + int(real(acorni(idum))*nwint)
      if(facint(ipick).eq.3.or.facint(ipick).eq.4) go to 11
      if(facint(ipick).eq.0) then
c
c Shale interval - see what can be done.  Note that in an early
c implementation we limited the size of shale that would be considered.
c
            nsize = ninwint(ipick)
            nmm   = 0
            do i=1,nsize
                  iix = ixint(ipick,i)
                  iiy = iyint(ipick,i)
                  iiz = izint(ipick,i)
                  rarray(i) = abs(tchannum(iix,iiy,iiz))
                  if(tchanind(iix,iiy,iiz).ne.0) nmm = nmm + 1
            end do
c
c - see if there is one channel cutting across this entire interval:
c
            if(nmm.eq.0) go to 10

            tcheck = rarray(1)
            do i=2,nsize
                  if(abs(rarray(i)-tcheck).gt.1.0e-5) go to 20
            end do
            ioff         = int(tcheck+0.5)
            noffp        = noffp + 1
            icoff(noffp) = ioff
            chanon(ioff) = .false.
            return
c
c - check for a violation at top, middle, and bottom:
c
 20         itop = 0
            imid = 0
            ibot = 0
            if(rarray(1).gt.0.0) itop = 1
            if(rarray(nsize).gt.0.0) ibot = 1
            i1check = 0
            tcheck  = rarray(1)
            do i=2,nsize
                  if(i1check.eq.0.and.rarray(i).gt.0.5.and.
     +                                rarray(i).ne.tcheck) then
                        i1check = 1
                        tcheck  = rarray(i)
                  end if
                  if(i1check.eq.1.and.abs(rarray(i)-tcheck).gt.
     +                1.0e-5) then
                        ioff  = int(tcheck+0.5)
                        imid  = 1
                        go to 21
                  end if
            end do
 21         if(imid.eq.1) then
                  noffp        = noffp + 1
                  icoff(noffp) = ioff
                  chanon(ioff) = .false.
            end if
c
c - see what can be done at the top:
c
            if(itop.eq.1) then
                  nthk   = 1
                  tcheck = rarray(1)
                  do i=2,nsize
                        if(rarray(i).ne.tcheck) then
                              nthk = i - 1
                              go to 23
                        end if
                  end do
 23               continue
                  if(nthk.ge.nfct2) then
                        ioff         = int(tcheck+0.5)
                        noffp        = noffp + 1
                        icoff(noffp) = ioff
                        chanon(ioff) = .false.
                  else
                        ic     = int(tcheck+0.5)
                        iiztop = izint(ipick,1)
                        iizbot = izint(ipick,nthk)
                        if(iiztop.lt.iizbot) then
C                              ndelz = -(iizbot-iiztop)
                              ndelz  = (iizbot-iiztop)
                        else
                              ndelz  =  (iiztop-iizbot)
                        end if
                        call vshift(ic,ndelz)
                        nvshift         = nvshift + 1
                        shiftc(nvshift) = ic
                        shiftp(nvshift) = real(ndelz)+0.5
                  end if
            end if
c
c - see what can be done at the bottom:
c
            if(ibot.eq.1) then
                  nthk   = 1
                  tcheck = rarray(nsize)
                  do i=nsize-1,1,-1
                        if(rarray(i).ne.tcheck) then
                              nthk = nsize - i
                              go to 24
                        end if
                  end do
 24               continue
                  if(nthk.ge.nfct2) then
                        ioff         = int(tcheck+0.5)
                        noffp        = noffp + 1
                        icoff(noffp) = ioff
                        chanon(ioff) = .false.
                  else
                        ic     = int(tcheck+0.5)
                        iindx  = nsize - nthk
                        iiztop = izint(ipick,iindx)
                        iizbot = izint(ipick,nsize)
                        if(iiztop.lt.iizbot) then
C                              ndelz = iizbot - iiztop
                              ndelz  = (iizbot-iiztop)
                        else
                              ndelz  =  (iiztop-iizbot)
                        end if
                        ndelz = -ndelz
                        call vshift(ic,ndelz)
                        nvshift         = nvshift + 1
                        shiftc(nvshift) = ic
                        shiftp(nvshift) = real(ndelz)+0.5
                  end if
            end if
c
c - return from checking over a shale interval:
c
            return            
      else if(facint(ipick).eq.1) then
c
c Channel sand interval - see what can be done:
c
            nsize = ninwint(ipick)
            nmm = 0
            do i=1,nsize
                  iix = ixint(ipick,i)
                  iiy = iyint(ipick,i)
                  iiz = izint(ipick,i)
                  rarray(i) = abs(tchannum(iix,iiy,iiz))
                  if(tchanind(iix,iiy,iiz).ne.1) nmm = nmm + 1
            end do
c
c - don't do anything if there is no mismatch; otherwise, get a channel:
c
            if(nmm.eq.0) go to 10
            nonp = nonp + 1
            ion  = icon(1)
c
c - decide where it should go
c
            maxtop  = 0
            maxbot  = 0
            maxthk  = 0
            itop    = 0
            if(rarray(1).le.0.5) itop = 1
            do i=2,nsize
                  if(itop.eq.0.and.rarray(i).le.0.5) itop = i
                  if(itop.ne.0.and.(rarray(i).gt.0.5.or.i.eq.nsize))then
                        ithk = i-itop+1
                        if(ithk.gt.maxthk) then
                              maxtop  = itop
                              maxbot  = i
                              maxthk  = ithk
                              itop    = 0
                        end if
                  end if
            end do
            if(nsize.eq.1) then
                  maxtop  = 1
                  maxbot  = 1
                  maxthk  = 1
            end if
            if(maxthk.le.0) go to 10
c
c - get a channel of the thickness we need:
c
            rarray(1) = fct(1)
            rarray(2) = fct(2)
            rarray(3) = fct(3)
            iiztop = izint(ipick,maxtop)
            iizbot = izint(ipick,maxbot)
            if(iiztop.lt.iizbot) then
                  thk = min(real(iizbot-iiztop+1)*zsiz,fct(3))
            else
                  thk = min(real(iiztop-iizbot+1)*zsiz,fct(3))
            end if
            fct(1) = thk
            fct(2) = thk
            fct(3) = thk
            flong  = .true.
            call getchpar(ion,flong)
            flong  = .false.
            fct(1) = rarray(1)
            fct(2) = rarray(2)
            fct(3) = rarray(3)
c
c - translate it to approximately cover the well intersection:
c
            ztop = iiztop * zsiz
            if(iizbot*zsiz.gt.ztop) ztop = iizbot * zsiz
            deltaz = ztop - cz(ion)
            if(deltaz.gt.0.0) then
                  ndelz  = int(deltaz / zsiz + 0.5)
            else
                  ndelz  = int(deltaz / zsiz - 0.5)
            end if
            xx = xmn + real(ixint(ipick,maxtop)-1)*xsiz
            yy = ymn + real(iyint(ipick,maxtop)-1)*ysiz
c
c - decide how much to shift the channel areally:
c
            if(abs(csina(ion)).gt.abs(ccosa(ion))) then
                  ysold = cyorigin(ion)                   
                  do iy=1,nyc(ion)
                        xxp   = ccent(ion,iy)
                        yyp   = real(iy)*cdy
                        xxtry =  ccosa(ion)*xxp + csina(ion)*yyp
     +                                          + cxorigin(ion)
                        yytry = -csina(ion)*xxp + ccosa(ion)*yyp
     +                                          + cyorigin(ion)
                        if(xxtry.gt.xx) then
                              ycl = (ysold+yytry)/2.
                              go to 601
                        end if
                        ysold = yytry
                  end do
                  ycl = yytry
 601              cyorigin(ion) = cyorigin(ion) - (ycl-yy)
            else
                  xsold = cxorigin(ion)
                  do iy=1,nyc(ion)
                        xxp   = ccent(ion,iy)
                        yyp   = real(iy)*cdy
                        xxtry =  ccosa(ion)*xxp + csina(ion)*yyp
     +                                          + cxorigin(ion)
                        yytry = -csina(ion)*xxp + ccosa(ion)*yyp
     +                                          + cyorigin(ion)
                        if(yytry.gt.yy) then
                              xcl = (xsold+xxtry)/2.
                              go to 602
                        end if
                        xsold = xxtry
                  end do
                  xcl = xxtry
 602              cxorigin(ion) = cxorigin(ion) - (xcl-xx)
            end if
c
c - shift channel vertically and force acceptance:
c
            call vshift(ion,ndelz)
            nvshift         = nvshift + 1
            shiftc(nvshift) = ion
            shiftp(nvshift) = real(ndelz)+0.5
      end if
c
c Return to fluvsim to raster, calculate objective function, ...
c
      return
      end



      subroutine vshift(ic,ndelz)
c-----------------------------------------------------------------------
c
c Shift channel "ic" by ndelz grid units, i.e., reset all arrays for
c the channel.
c
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
c
c Shift, but make sure the integer pointers stay in the model:
c
      cz(ic)      = cz(ic) + real(ndelz)*zsiz
      izhitem(ic) = izhitem(ic) + ndelz
      izhitem(ic) = min(max(1,izhitem(ic)),nz)
      do iy=1,nyc(ic)
            rlzlo(ic,iy) = rlzlo(ic,iy) + ndelz
            rlzlo(ic,iy) = min(max(1,rlzlo(ic,iy)),nz)
            llzlo(ic,iy) = llzlo(ic,iy) + ndelz
            llzlo(ic,iy) = min(max(1,llzlo(ic,iy)),nz)
            do ix=ixlotem(ic,iy),ixhitem(ic,iy)
                  izlotem(ic,iy,ix) = izlotem(ic,iy,ix) + ndelz
                  izlotem(ic,iy,ix) = min(max(1,izlotem(ic,iy,ix)),nz)
            end do
            do ix=1, llwid(ic,iy)
                  llbh(ic,iy,ix) = llbh(ic,iy,ix) + ndelz
                  llbh(ic,iy,ix) = min(max(1,llbh(ic,iy,ix)),nz)
            end do
            do ix=1, rlwid(ic,iy)
                  rlbh(ic,iy,ix) = rlbh(ic,iy,ix) + ndelz
                  rlbh(ic,iy,ix) = min(max(1,rlbh(ic,iy,ix)),nz)
            end do
      end do
c
c All finished:
c
      return
      end



      real function getval(fdist)
c-----------------------------------------------------------------------
c
c
c
c-----------------------------------------------------------------------
      real      fdist(3)
      real*8    acorni
c
c ACORN parameters:
c
      parameter(KORDEI=12,MAXOP1=KORDEI+1,MAXINT=2**30)
      common /iaco/ ixv(MAXOP1)
c
c Draw a value from triangular distribution:
c
      cdf = real(acorni(idum))
      if(cdf.lt.0.5) then
            getval = fdist(1) + 2.0 *    cdf    * (fdist(2)-fdist(1))
      else
            getval = fdist(2) + 2.0 * (cdf-0.5) * (fdist(3)-fdist(2))
      end if

      return
      end



      subroutine csect(xleft,xright,relpos,tmax,xpos,thick)
c-----------------------------------------------------------------------
c
c
c
c
c
c-----------------------------------------------------------------------
      parameter(EPSLON=0.0001)
      width = xright - xleft
      xx    = xpos   - xleft
      if(width.le.EPSLON.or.relpos.le.EPSLON
     +   .or.(1.-relpos).le.EPSLON.or.xx.le.0.0.or.xx.ge.width) then
            thick = 0.0
            return
      end if
      if(relpos.le.0.5) then
            b     = -log(2.)/log(relpos)
            thick = 4.*tmax*((xx/width)**b)*((1.-(xx/width)**b))
      else
            b     = -log(2.)/log(1.-relpos)
            thick = 4.*tmax*((1.-xx/width)**b)*(1.-((1.-xx/width)**b))
      end if
      return
      end



      subroutine get1d(ny,ysiz,range,array)
c-----------------------------------------------------------------------
c
c            Stochastic Averaging Simulation for 1-D String
c            **********************************************
c
c
c
c
c-----------------------------------------------------------------------
      parameter(KORDEI=12,MAXOP1=KORDEI+1,MAXINT=2**30)
      common /iaco/   ixv(MAXOP1)
c
c Variable Declaration:
c
      parameter(MAXY=750,MAXLEN=250)
      real      tarray(MAXY+2*MAXLEN),array(*)
      real*8    p,acorni
c
c Do we have enough storage?
c
      if(ny.gt.MAXY) then
            write(*,*) ' requested too large simulation in get1d ',ny
            write(*,*) ' available size is ',MAXY
            stop
      end if
c
c Size of smoothing window:
c
      n1 = min( int( (range*0.10)/ysiz + 0.5 ) , MAXLEN )
      n2 = min( int( (range*0.50)/ysiz + 0.5 ) , MAXLEN )
c
c Generate ny Gaussian random numbers:
c
      do i = 1,ny+2*n2
 1          p = acorni(idum)
            call gauinv(p,xp,ierr)
            if(xp.lt.(-6.).or.xp.gt.(6.)) go to 1
            tarray(i) = xp
      end do
c
c Compute the simulation at each grid point:
c
      do i=1,ny
            loc   = i + n2
            value = 0.0
            llo   = loc-n2
            lhi   = loc-n1
            do j=llo,lhi
                  value = value + tarray(j)*real((j  -llo+1))/
     +                                      real((lhi-llo+1))
            end do
            llo = lhi + 1
            lhi = loc + n1 - 1
            do j=llo,lhi
                  value = value + tarray(j)
            end do
            llo = lhi + 1
            lhi = loc + n2
            do j=llo,lhi
                  value = value + tarray(j)*real((lhi-j  +1))/
     +                                      real((lhi-llo+1))
            end do
            array(i) = value
      end do
c
c A smoothing pass:
c
      tarray(1)  = 3.0*array(1)
      do i=2,ny-1
            tarray(i) = array(i-1) + array(i) + array(i+1)
      end do
      tarray(ny) = 3.0*array(ny)
c
c Restandardize the results to mean 0 and variance 1
c
      xmean = 0.0
      xvar  = 0.0
      do i=1,ny
            xmean = xmean + tarray(i)
            xvar  = xvar  + tarray(i)*tarray(i)
      end do
      xmean = xmean / real(ny)
      xvar  = xvar  / real(ny) - xmean*xmean
      xstd  = sqrt(xvar)
      do i=1,ny
            array(i) = (tarray(i)-xmean) / xstd
      end do
c
c Return with this realization:
c
      return
      end



      subroutine getcre
c-----------------------------------------------------------------------
c
c
c
c
c-----------------------------------------------------------------------
      include  'fluvsim.inc'
      real*8    acorni
c
c Loop over all crevasses:
c
      do ic=1,MAXCRE
            do ix=0,MAXCRX
            do iy=-MAXCRY,MAXCRY
                  cre(ic,ix,iy) = .false.
            end do
            end do
c
c Draw values for the crevasse parameters:
c
            lenxc  = 1 + int(getval(fcrlen))
            lencr  = 1 + int(getval(fcrwl))
            nwalk  = 1 + int(getval(fcrnw))
            dlat   =         getval(fcrlat)
            if(lenxc.gt.(MAXCRY/2)) lenxc = MAXCRY / 2
c
c Send out the random walkers and get the crevasse shape:
c
            dlatlo =       0.5 * dlat
            dlathi = 1.0 - 0.5 * dlat
            do jy=-lenxc,lenxc
                  do iwalk = 1,nwalk
                        ix = 0
                        iy = jy
                        cre(ic,ix,iy) = .true.
                        do ilen = 1,lencr
                              rtmp = real(acorni(idum))
                              if(rtmp.le.dlatlo) then
                                    iy = iy - 1
                                    if(iy.lt.-MAXCRY) iy = -MAXCRY
                              else if(rtmp.ge.dlathi) then
                                    iy = iy + 1
                                    if(iy.gt. MAXCRY) iy =  MAXCRY
                              else
                                    ix = ix + 1
                                    if(ix.gt. MAXCRX) ix =  MAXCRX
                              end if
                              cre(ic,ix,iy) = .true.
                        end do
                  end do
            end do
c
c End loop over all crevasses:
c
      end do
c
c Finished:
c
      return
      end
