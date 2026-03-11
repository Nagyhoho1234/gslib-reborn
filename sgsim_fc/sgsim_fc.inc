! Optimized version: dynamic allocation, OpenMP parallel realizations
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
c The following Parameters control static dimensioning for SGSIM:
c
c   MAXX      maximum nodes in X
c   MAXY      maximum nodes in Y
c   MAXZ      maximum nodes in Z
c   MAXCTX    maximum X points in covariance table (ODD number)
c   MAXCTY    maximum Y points in covariance table (ODD number)
c   MAXCTZ    maximum Z points in covariance table (ODD number)
c   MAXSBX    maximum super block nodes in X direction
c   MAXSBY    maximum super block nodes in Y direction
c   MAXSBZ    maximum super block nodes in Z direction
c   MAXDAT    maximum number of data
c   MAXNOD    maximum number of previously simulated nodes to use
c   MAXSAM    maximum number of data for one simulation
c   MAXNST    maximum number of nested structures for variogram
c   MAXSEC    maximum number of secondary data to use in LMC
c
c-----------------------------------------------------------------------
c
c User Adjustable Parameters (generous limits):
c
      parameter(MAXX   = 2000, MAXY   = 2000, MAXZ   = 500,
     +          MAXCTX =  301, MAXCTY =  301, MAXCTZ =   1,
     +          MAXSBX =   21, MAXSBY =   21, MAXSBZ =   1,
     +          MAXDAT = 5000000, MAXNOD = 96, MAXSAM = 256,
     +          MAXNST =     4, MAXSEC = 20, NODATV = -50  )
c
c Fixed Parameters:
c
      parameter(MAXKR1=MAXNOD+MAXSAM+1,MAXKR2=MAXKR1+MAXSEC,
     +          MAXKR3=MAXKR2*MAXKR2,
     +          MAXROT=MAXNST+1,MAXCXY=MAXCTX*MAXCTY,
     +          MAXXYZ=MAXCTX*MAXCTY*MAXCTZ,MAXSB=MAXSBX*MAXSBY*MAXSBZ,
     +          MXYZ=20000000,UNEST=-45.0,EPSLON=1.0e-20,
     +          VERSION=2026.1)
c
c ACORN parameters:
c
      parameter(KORDEI=12,MAXOP1=KORDEI+1,MAXINT=2**30)
c
c Variable Declaration:
c
      real      x(MAXDAT),y(MAXDAT),z(MAXDAT),vr(MAXDAT),wt(MAXDAT),
     +          vrtr(MAXDAT),vrgtr(MAXDAT),close(MAXDAT),sec(MAXDAT),
     +          sim(MXYZ),lvm(MXYZ),tmp(MXYZ),order(MXYZ),
     +          c0(3),cc(3*MAXNST),aa(3*MAXNST),ang1(3*MAXNST),
     +          ang2(3*MAXNST),ang3(3*MAXNST),
     +          anis1(3*MAXNST),anis2(3*MAXNST),
     +          covtr(MAXCTX,MAXCTY,MAXCTZ),
     +          covtab(MAXCTX,MAXCTY,MAXCTZ),cnodey(MAXNOD),
     +          covtSec(MAXCTX,MAXCTY,MAXCTZ),cnodex(MAXNOD),
     +          cnodez(MAXNOD),
     +          cnodev(MAXNOD),vra(MAXKR1),vrea(MAXKR1),ltpar
      real*8    rotmat(MAXROT,3,3),r(MAXKR2),rr(MAXKR2),s(MAXKR2),
     +          rb(MAXKR2),a(MAXKR3)
      integer   ltail,utail,sstrat,mults,nisb(MAXSB),nst(3),
     +          it(3*MAXNST),icnode(MAXNOD)
      integer*2 ixnode(MAXXYZ),iynode(MAXXYZ),iznode(MAXXYZ),
     +          ixsbtosr(8*MAXSB),iysbtosr(8*MAXSB),izsbtosr(8*MAXSB)
c
c Common Blocks:
c
c --- OMP: Thread-private RNG state ---
      common /iaco/   ixv(MAXOP1)
!$OMP THREADPRIVATE(/iaco/)
c
c --- Shared: general parameters and input data (read-only in sim) ---
      common /generl/ nx,ny,nz,xsiz,ysiz,zsiz,xmn,ymn,zmn,nxy,nxyz,
     +                nd,x,y,z,vr,wt,itrans,ntr,iend,
     +                vrtr,vrgtr,sec,idbg,
     +                lin,lout,ldbg,llvm,icollvm,nvaril,ktype,colocorr,
     +                ltail,ltpar,utail,utpar,zmin,zmax,varred,maxNsec
c
c --- Shared: nsim count and read-only lvm ---
c --- OMP: sim is per-realization (thread-private) ---
      common /lvmdat/ nsim,lvm
      common /simwrk/ sim,tmp,order
!$OMP THREADPRIVATE(/simwrk/)
c
c --- OMP: Thread-private output buffer for buffered I/O ---
      real      outbuf(MXYZ)
      common /iobuf/ outbuf
!$OMP THREADPRIVATE(/iobuf/)
c
c --- OMP: Thread-private search results ---
      common /search/ radius,radsqd,sang1,sang2,sang3,sanis1,sanis2,
     +                noct,nclose,close,ndmin,ndmax,sstrat,mults,nmult
!$OMP THREADPRIVATE(/search/)
c
c --- Shared: variogram model parameters (read-only during simulation) ---
      common /cova3d/ nst,it,cmax,c0,cc,aa,ang1,ang2,ang3,
     +                anis1,anis2,isrot
c
c --- OMP: Thread-private covariance lookup and node search state ---
      common /clooku/ nctx,ncty,nctz,covtab,covtr,covtSec,nlooku,ncnode,
     +                icnode,cnodex,cnodey,cnodez,cnodev,nodmax,ixnode,
     +                iynode,iznode
!$OMP THREADPRIVATE(/clooku/)
c
c --- OMP: Thread-private kriging work arrays ---
      common /krigev/ rotmat,r,rr,s,a,vra,cbb
!$OMP THREADPRIVATE(/krigev/)
