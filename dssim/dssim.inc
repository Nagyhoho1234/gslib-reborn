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
c
c-----------------------------------------------------------------------
c
c User Adjustable Parameters:
c
      parameter(MAXX   =   500, MAXY   = 500, MAXZ   = 100,
     +          MAXCTX =    71, MAXCTY =  71, MAXCTZ = 21,
     +          MAXSBX =    21, MAXSBY =  21, MAXSBZ = 11,
     +          MAXDAT =5000000,MAXNOD =  96, MAXSAM = 256,
     +          MAXNST =     4, MAXREF=100000,MAXCAT=24,
     +          MV=20  )
c
c Fixed Parameters:
c
      parameter(MAXKR1=MAXNOD+MAXSAM+1,MAXKR2=MAXKR1*MAXKR1,
     +          MAXROT=MAXNST+1,MAXCXY=MAXCTX*MAXCTY,
     +          MAXXYZ=MAXCTX*MAXCTY*MAXCTZ,MAXSB=MAXSBX*MAXSBY*MAXSBZ,
     +          MXYZ=MAXX*MAXY*MAXZ,UNEST=-99.0,EPSLON=1.0e-20,
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
     +          c0(1),cc(MAXNST),aa(MAXNST),ang1(MAXNST),ang2(MAXNST),
     +          ang3(MAXNST),anis1(MAXNST),anis2(MAXNST),
     +          covtab(MAXCTX,MAXCTY,MAXCTZ), avepor(MAXX,MAXY),
     +          porvar(MAXX, MAXY),
     +          cnodex(MAXNOD),cnodey(MAXNOD),cnodez(MAXNOD),
     +          cnodev(MAXNOD),vra(MAXKR1),vrea(MAXKR1),ltpar,
     +          krgvar(MXYZ), utpar, pkr
      real      rcdf(MAXREF),rvr(MAXREF),dcdf(MAXDAT),dvr(MXYZ),
     +          indx(MAXDAT),fuzzcat(MAXDAT),catcdf(MAXCAT)

      real*8    rotmat(MAXROT,3,3),r(MAXKR1),rr(MAXKR1),s(MAXKR1),
     +          a(MAXKR2)
      integer   ltail,utail,sstrat,mults,nisb(MAXSB),nst(1),
     +          it(MAXNST),icnode(MAXNOD), novar(MXYZ)
      integer   category(MAXDAT), ncut, inovar
      integer*2 ixnode(MAXXYZ),iynode(MAXXYZ),iznode(MAXXYZ),
     +          ixsbtosr(8*MAXSB),iysbtosr(8*MAXSB),izsbtosr(8*MAXSB)
      real      wtt, vrt, wtd, vrd
      real	ckurt, colocorr, zmaxvar
      integer   wx, wy, wz,  isim, idrawopt   
      character distin*40, localfl*40, outfl*40, transoutfl*40
      

      integer   ibt,ibtw,nbt
      real	bootvar(MAXDAT),bootwt(MAXDAT),btmean,btvar
      real	bootcdf(MAXDAT)	

c
c Common Blocks:
c

      common /kurto/  ckurt, idrawopt, pkr
	
      common /iaco/   ixv(MAXOP1), itr(MAXOP1)

      common /generl/ nx,ny,nz,xsiz,ysiz,zsiz,xmn,ymn,zmn,nxy,nxyz,
     +                nd,x,y,z,vr,wt,ntr,vrtr,vrgtr,sec,idbg,
     +                lin,lout,ldbg,llvm,lkv,icollvm,nvaril,ktype,
     +                colocorr, ivar,  
     +                ltail,ltpar,utail,utpar,zmin,zmax,varred,skgmean,
     +                avepor, porvar, icond, gvar

      common /simula/ isim, nsim,sim,lvm

      common /search/ radius,radsqd,sang1,sang2,sang3,sanis1,sanis2,
     +                noct,nclose,close,ndmin,ndmax,sstrat,mults,nmult

      common /cova3d/ nst,it,cmax,c0,cc,aa,ang1,ang2,ang3,
     +                anis1,anis2,isrot

      common /clooku/ nctx,ncty,nctz,covtab,nlooku,ncnode,icnode,
     +                cnodex,cnodey,cnodez,cnodev,nodmax,ixnode,iynode,
     +                iznode

      common /krigev/ rotmat,r,rr,s,a,vra,cbb, krgvar, inovar, novar
     +                ,zmaxvar
      common /transcon/  ivrr, iwtr, wx,wy, wz, 
     +		      icoll, wtfac, rn, distin, 
     +		      localfl, outfl, tmin, tmax,transoutfl, itrans,
     +                ivrd, iwtd, rcdf, rvr, dcdf, dvr, indx, fuzzcat, 
     +                catcdf,  category, wtt, vrt, wtd, vrd, ncut

      common /bt/   ibt,ibtw,nbt,bootvar,bootwt,btmean,btvar,bootcdf

