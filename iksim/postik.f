      subroutine postik
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
c                   Post Process IK Distributions
c                   *****************************
c
c Post processes IK-generated distributions.
c See the text for detailed discussion of parameters to extrapolate the
c discrete cdf values.
c This subroutine is based on GSLIB program POSTIK
c Author: Zhanjun Ying, 12-30-98
c
c
c-----------------------------------------------------------------------
c
c
c     Fixed parameters:
c
      include 'iksim.inc'
      parameter(MV=20)
      real      ccut(MAXCUT),
     +          cdf(MAXDAT),cut(MAXDAT),val(MV)
      data      lpostout/12/
      real maxpdf, pdf
      integer unestFlag
c
c
c     Open the output file:
c
      open(lpostout,file=postoutfl,status='UNKNOWN')
      write(lpostout,*) 'results of postik within IKSIM'
      if(ivtype.eq.1) then
         write(lpostout,100) parlim,parlim,parlim,parprob
      else
         write(lpostout,101) 
      end if
 100  format('6',/,'E-type mean',/,
     +'prob > cutoff= ',f12.4/,'mean > cutoff= ',f12.4/,
     +'mean < cutoff= ',f12.4/,
     +'Z value corresponding to CDF = ',f5.3/,
     +'Conditional Variance')
 101  format('1',/,"local uncertainty (1-max(pdf))")

      write(*,*)
      write(*,*) 'Post-processing Ik3d result ...'
      write(*,*)

c
c
c     BIG LOOP OVER ALL CCDFS
c
      nxyz=nx*ny*nz
      do 9,index=1,nxyz
      
      nccut=ncut
      do i=1,nccut 
         ccdf(i)= pass(index,i)
      end do

c    In case of categorical variable, just output 1-max(prob(u_\alpha, a)
      if (ivtype.eq.0) then
         maxpdf = ccdf(1)
         do i=2, nccut
            if( ccdf(i) .gt. maxpdf ) maxpdf = ccdf(i)
         end do
c     if maxpdf < -0.1, then we have maximum  uncertainty, i.e. 
c     (1-maxpdf) should = 1 
         if(maxpdf .lt. -0.1) maxpdf = 0 
         write(lpostout,'(f12.4)') 1.0-maxpdf

      else 
c     Continuous variable. Calculate etype, conditional variance, etc
c
c     Check for unestimated  values:
c
         if(ccdf(nccut).lt.-0.1) then
            write(lpostout,110) UNEST,UNEST,UNEST,UNEST,UNEST,UNEST
 110        format(6f12.4)
            go to 9
         end if
c
c
c     
c     Compute mean of local distribution if E-type , or need the
c     mean above (below) a cutoff, or need conditional variance:
c
         if(ietype.eq.1 .or. iprob .eq. 1 .or. icondvar .eq. 1) then
            dis    = 1.0 / real(maxdis)
            cdfval = -0.5*dis
            eabove = 0.0
            nabove = 0
            ebelow = 0.0
            nbelow = 0
            etype  = 0.0
            ecv    = 0.0
            do i=1,maxdis
               cdfval  = cdfval + dis
               zval    = -1.0
               call beyond(1,nccut,thres,ccdf,ncut,thres,gcdf,zmin,
     +              zmax,ltail,ltpar,middle,mpar,utail,
     +              utpar,zval,cdfval,ierr)
               if(ierr.ne.0) then
                  write(*,*) 'ERROR: ',ierr,' continuing'
               endif
               etype = etype + zval
               ecv   = ecv   + zval*zval
               if(zval.le.parlim) then
                  nbelow = nbelow + 1
                  ebelow = ebelow + zval
               else
                  nabove = nabove + 1
                  eabove = eabove + zval
               end if
            end do
c     
c     e-type and conditional variance:
c     
            etype = etype / real(maxdis)
            ecv   = ecv/real(maxdis)-etype*etype
         endif
c     
c     
c
c     Do we need probability and mean value above a threshold?
c     
         if(iprob.eq.1) then
c     
c     Get probability:
c     
            cdfval  = -1.0
            call beyond(1,nccut,thres,ccdf,ncut,thres,gcdf,zmin,
     +           zmax,ltail,ltpar,middle,mpar,utail,
     +           utpar,parlim,cdfval,ierr)
            if(ierr.ne.0) then
               write(*,*) 'ERROR: ',ierr,' continuing'
            endif
            prob   = 1.0 - cdfval
            eabove = eabove / real(max(1,nabove))
            ebelow = ebelow / real(max(1,nbelow))
         endif
c     
c     Do we need the "Z" value corresponding to a particular CDF?
c
         if(ipercentile.eq.1) then
            zval    = -1.0
            call beyond(1,nccut,thres,ccdf,ncut,thres,gcdf,zmin,
     +           zmax,ltail,ltpar,middle,mpar,utail,
     +           utpar,zval,parprob,ierr)
            if(ierr.ne.0) then
               write(*,*) 'ERROR: ',ierr,' continuing'
            endif
         endif
         
         if(ietype.eq.0) etype=UNEST
         if(iprob.eq.0) then
            prob=UNEST
            eabove=UNEST
            ebelow=UNEST
         endif
         if(ipercentile.eq.0) zval=UNEST
         if(icondvar.eq.0) ecv=UNEST
         write(lpostout,202) etype,prob,eabove,ebelow,zval,ecv
 202     format(f12.4,f12.4,f12.4,f12.4,f12.4,f12.4)

      end if
c     Return for another:

 9    continue
c
c     Finished:
      close(lpostout)

c
c     All Finished postik:
c
      write(*,*) 'Post-processing (POSTIK) finished'
      return
      end




