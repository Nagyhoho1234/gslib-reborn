c-----------------------------------------------------------------------
c
c The following Parameters control static dimensioning for FLUVSIM:
c
c   MAXX      maximum nodes in X
c   MAXY      maximum nodes in Y
c   MAXZ      maximum nodes in Z
c   MAXL      maximum length of channel: 2*max(MAXX,MAXY)
c   MAXW      maximum 1/2 width of channel (depends on width)
c   MAXDAT    maximum number of well data
c   MAXWIN    maximum number of well intervals
c   MAXC      maximum number of channels
c   MAXBW     maximum levee bank width
c   MAXCRE    maximum number of crevasse templates
c   MAXCRX    maximum crevasse template size in X
c   MAXCRY    maximum crevasse template size in Y
c   MAXCPERT  maximum number of channels turned on/off/revised during 
c             a perturbation iteration
c
c-----------------------------------------------------------------------
c
c User Adjustable Parameters:
c
      parameter(MAXX   = 500, MAXY   = 500, MAXZ   =100, MAXL   =1000,
     +          MAXW   =  275, MAXDAT=5000000,MAXWIN= 300, MAXC   = 200,
     +          MAXBW  =  100, MAXCRE =  100, MAXCRX =  25, MAXCRY =15,
     +          MAXCPERT= 50)

c
c Fixed Parameters:
c
      parameter(EPSLON=1.0e-05,DEGTOR=3.14159/180.0,VERSION=2026.1)
c
c ACORN parameters:
c
      parameter(KORDEI=12,MAXOP1=KORDEI+1,MAXINT=2**30)
c
c Variable Declaration:
c
      real      cx(MAXC,MAXL,7),cz(MAXC),cw(MAXC,MAXL),ct(MAXC,MAXL,7),
     +          ccent(MAXC,MAXL),
     +          cang(MAXC),ccosa(MAXC),csina(MAXC),ctana(MAXC),
     +          cxorigin(MAXC),cyorigin(MAXC),chx(MAXL),
     +          fco(3),fcad(3),fcal(3),fct(3),fctu(3),fctul(3),fcwt(3),
     +          fcwu(3),fcwul(3),pcurvea(MAXZ,3),pmapa(MAXX,MAXY,3),
     +          tarprop(0:4),modprop(0:4),pcurve(MAXZ,3),
     +          pmap(MAXX,MAXY,3),rarray(MAXL),
     +          flw(3),flwz(MAXZ,3),flh(3),fld(3),fcrlen(3),fcrt(3),
     +          fcrnw(3),fcrwl(3),fcrlat(3),creprob(3),creprz(MAXZ,3),
     +          crt(MAXC,MAXCRE),cumprob(3),shiftp(MAXCPERT)

      integer   xw(MAXDAT),yw(MAXDAT),zw(MAXDAT),fw(MAXDAT),
     +          nwint,ninwint(MAXWIN),facint(MAXWIN),
     +          ixint(MAXWIN,MAXWIN),iyint(MAXWIN,MAXWIN),
     +          izint(MAXWIN,MAXWIN),
     +          nc,lin,ldbg,lgeo,lout,lpv,lpa,lwd,nyc(MAXC),ncre(MAXC),
     +          crxloc(MAXC,MAXCRE),cryloc(MAXC,MAXCRE),
     +          crnum(MAXC,MAXCRE),icon(MAXCPERT),icoff(MAXCPERT),
     +          shiftc(MAXCPERT)

      integer*2 ixlotem(MAXC,MAXL),ixhitem(MAXC,MAXL),
     +          izlotem(MAXC,MAXL,-MAXW:MAXW),izhitem(MAXC),
     +          llwid(MAXC,MAXL),rlwid(MAXC,MAXL),llzlo(MAXC,MAXL),
     +          rlzlo(MAXC,MAXL),
     +          llbh(MAXC,MAXL,MAXBW),rlbh(MAXC,MAXL,MAXBW),
     +           chanind(MAXX,MAXY,MAXZ), channum(MAXX,MAXY,MAXZ),
     +          tchanind(MAXX,MAXY,MAXZ),tchannum(MAXX,MAXY,MAXZ)

      logical   lglob,lvert,lvertng,larea,lareang,lwell,chanon(MAXC),
     +          cre(MAXCRE,0:MAXCRX,-MAXCRY:MAXCRY),
     +          crright(MAXC,MAXCRE)
c
c Common Blocks:
c
      common /iaco/   ixv(MAXOP1)

      common /generl/ nx,ny,nz,xsiz,ysiz,zsiz,xmn,xmx,ymn,ymx,zmn,
     +                nwd,xw,yw,zw,nwint,ninwint,facint,ixint,iyint,
     +                izint,wellmis,welltry,ichan,ilev,icre,fw,
     +                avgthick,idbg,nc,lin,ldbg,lgeo,lout,lpv,lpa,lwd,
     +                tarprop,modprop,cumprob

      common /simul/  nsim,sclglob,sclvert,sclarea,sclwell,wfac,pcurve,
     +                pmap,pcurvea,pmapa,niter,mnoc,objmin,creprob,
     +                creprz,t0,redfac,kasas,ksas,numred

      common /cmodel/ chanind,channum,tchanind,tchannum

      common /crevx/  ncre,crxloc,cryloc,crnum,crt

      common /pertp/  nonp,icon,noffp,icoff,nvshift,shiftc,shiftp

      common /chpar/  mxc,cxmin,cxmax,cymin,cymax,cdy,cx,cz,cw,ct,ccent,
     +                cang,ccosa,csina,ctana,cxorigin,cyorigin,chx,nyc,
     +                fco,fcad,fcal,fct,fctu,fctul,fcwt,fcwu,fcwul,
     +                flw,flwz,flh,fld,fcrlen,fcrt,fcrnw,fcrwl,fcrlat,
     +                nfct2

      common /templa/ ixlotem,ixhitem,izlotem,izhitem,
     +                llwid,rlwid,llzlo,rlzlo,llbh,rlbh

      common /logics/ lglob,lvert,lvertng,larea,lareang,lwell,chanon,
     +                cre,crright
