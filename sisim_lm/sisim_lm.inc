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
c The following Parameters control static dimensioning for SISIM_LM:
c
c   MAXDAT    maximum number of data
c   MAXCUT    maximum number of cutoffs
c   MAXTAB    maximum number of data in tabulated values for detail
c   MAXSAM    maximum number of data for one simulation
c   MAXNOD    maximum number of previously simulated nodes to use
c   MAXNST    maximum number of nested structures for variogram
c   MAXROT    maximum number of rotation matrices to store
c   MAXCTX    maximum X points in covariance table (ODD number)
c   MAXCTY    maximum Y points in covariance table (ODD number)
c   MAXCTZ    maximum Z points in covariance table (ODD number)
c   MAXSBX    maximum super block nodes in X direction
c   MAXSBY    maximum super block nodes in Y direction
c   MAXSBZ    maximum super block nodes in Z direction
c
c-----------------------------------------------------------------------
c
c User Adjustable Parameters:
c
      parameter(MAXCTX=   151, MAXCTY=   151, MAXCTZ=  51,
     +          MAXSBX=    41, MAXSBY=    41, MAXSBZ=  21,
     +          MAXDAT= 500000,MAXTAB=  5000, MAXCUT=  50,
     +          MAXNOD=    96, MAXSAM=   256, MAXNST=   4)
c
c Fixed Parameters:
c
      parameter(MAXKR1=2*MAXNOD+2*MAXSAM+1,
     +          MAXKR2=MAXKR1*MAXKR1,MAXROT=MAXCUT*MAXNST+1,
     +          MAXCXY=MAXCTX*MAXCTY,MAXXYZ=MAXCTX*MAXCTY*MAXCTZ,
     +          MAXSBX2=MAXSBX,MAXSBY2=MAXSBY,MAXSBZ2=MAXSBZ,
     +          MAXSB=MAXSBX2*MAXSBY2*MAXSBZ2,
     +          MXSXY=4*MAXSBX*MAXSBY,
     +          MXSX=2*MAXSBX,MXCUT=MAXCUT+1,MXYZ=  500000,
     +          EPSLON=1.0e-20,UNEST=-99.0,VERSION=2026.1)
c
c ACORN parameters:
c
      parameter(KORDEI=12,MAXOP1=KORDEI+1,MAXINT=2**30)
c
c Grid dimensions are now dynamic (allocated at runtime).
c
c =====================================================================
c Static Array Dimensioning
c =====================================================================
c
c --- Read-only data and model arrays (SHARED across threads) ---
c
      integer ixnode(MAXXYZ),iynode(MAXXYZ),iznode(MAXXYZ),nisb(MAXSB),
     +        ixsbtosr(8*MAXSB),iysbtosr(8*MAXSB),izsbtosr(8*MAXSB),
     +        it(MAXCUT*MAXNST),nst(MAXCUT),ltail,middle,utail,
     +        ivtype,sstrat

      real    ltpar,mpar,utpar,x(MAXDAT),y(MAXDAT),z(MAXDAT),
     +        vr(MAXDAT,MXCUT),actloc(MAXDAT),
     +        tmpdat(MAXDAT),
     +        gcut(MAXTAB),gcdf(MAXTAB),
     +        thres(MAXCUT),cdf(MAXCUT),
     +        c0(MAXCUT),cmax(MAXCUT),cc(MAXNST*MAXCUT),
     +        aa(MAXNST*MAXCUT),ang1(MAXNST*MAXCUT),
     +        ang2(MAXNST*MAXCUT),
     +        ang3(MAXNST*MAXCUT),anis1(MAXNST*MAXCUT),
     +        anis2(MAXNST*MAXCUT)
      real*8  rotmat(MAXROT,3,3)
c
c --- Per-thread mutable workspace (THREADPRIVATE) ---
c
      integer inoct(8),icnode(MAXNOD),nviol(MAXCUT)
      real    close(MAXDAT),ccdf(MAXCUT),ccdfo(MAXCUT),
     +        aviol(MAXCUT),xviol(MAXCUT),
     +        cnodex(MAXNOD),cnodey(MAXNOD),cnodez(MAXNOD),
     +        cnodev(MAXNOD),cnodet(MAXNOD),vra(MAXKR1)
      real*8  r(MAXKR1),rr(MAXKR1),s(MAXKR1),a(MAXKR2)
      logical atnode(MAXDAT)
c
c Fixed-size grid arrays (MXYZ) and covariance table:
c
      real    sim(MXYZ),order(MXYZ),tmp(MXYZ)
      real    covtab(MAXCTX,MAXCTY,MAXCTZ,MAXCUT)
c
c Dynamic arrays: primn and results (allocated at runtime)
c
      real, allocatable :: primn(:,:)
      real, allocatable :: results(:,:)
c
c I/O buffer for batched output:
c
      parameter(MAXBUF=8192)
      character*20 outbuf(MAXBUF)
      integer      nbuf
c
c =====================================================================
c Common Blocks: SHARED (read-only after initialization)
c =====================================================================
c
      common /grid3d/ nx,ny,nz,nxy,nxyz,xsiz,ysiz,zsiz,xmn,ymn,zmn

      common /data3d/ ivtype,nd,x,y,z,vr,zmin,zmax,ltail,middle,
     +                utail,ltpar,mpar,utpar,tmin,tmax

      common /params/ nsim,lin,lout,idbg,ldbg,mik,sstrat,
     +                mults,nmult

      common /srchpr/ radius,radsqd,sang1,sang2,sang3,sanis1,sanis2,
     +                noct,ndmax,infoct

      common /indict/ ncut,thres,cdf,ng,gcut,gcdf

      common /covmod/ nst,c0,it,cmax,cc,aa,ang1,ang2,ang3,anis1,
     +                anis2,isrot,ivrot,rotmat,cbb

      common /lookup/ covtab,nctx,ncty,nctz,nlooku,ixnode,iynode,
     +                iznode,nodmax

      common /supblk/ nisb,ixsbtosr,iysbtosr,izsbtosr,actloc,tmpdat

c     (primn and results are allocatable, not in common blocks)
c
c =====================================================================
c Common Blocks: THREADPRIVATE (per-thread mutable workspace)
c =====================================================================
c
      common /iaco/   ixv(MAXOP1)

      common /tpsim/  sim,tmp,order

      common /tpkrig/ r,rr,s,a,vra,nviol,aviol,xviol,ccdf,ccdfo

      common /tpnode/ nclose,close,ncnode,icnode,cnodex,cnodey,cnodez,
     +                cnodev,cnodet,inoct

      common /tplogk/ atnode

      common /tpiobf/ outbuf,nbuf
c
!$OMP THREADPRIVATE(/iaco/,/tpsim/,/tpkrig/,/tpnode/,
!$OMP+              /tplogk/,/tpiobf/)
