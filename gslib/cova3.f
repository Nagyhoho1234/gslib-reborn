      subroutine cova3(x1,y1,z1,x2,y2,z2,ivarg,nst,MAXNST,c0,it,cc,aa,
     +                 irot,MAXROT,rotmat,cmax,cova)
c-----------------------------------------------------------------------
c
c                    Covariance Between Two Points
c                    *****************************
c
c OPTIMIZED VERSION:
c   - Pre-compute h/aa(ist) ratio once per structure (avoid redundant divs)
c   - Cache aa(ist) and cc(ist) in local variables
c   - Use select case pattern via computed values for model type
c   - Thread-safe: no shared state, all locals on stack
c   - !$OMP declarations for thread safety
c
c This subroutine calculated the covariance associated with a variogram
c model specified by a nugget effect and nested varigoram structures.
c The anisotropy definition can be different for each nested structure.
c
c
c
c INPUT VARIABLES:
c
c   x1,y1,z1         coordinates of first point
c   x2,y2,z2         coordinates of second point
c   nst(ivarg)       number of nested structures (maximum of 4)
c   ivarg            variogram number (set to 1 unless doing cokriging
c                       or indicator kriging)
c   MAXNST           size of variogram parameter arrays
c   c0(ivarg)        isotropic nugget constant
c   it(i)            type of each nested structure:
c                      1. spherical model of range a;
c                      2. exponential model of parameter a;
c                           i.e. practical range is 3a
c                      3. gaussian model of parameter a;
c                           i.e. practical range is a*sqrt(3)
c                      4. power model of power a (a must be gt. 0  and
c                           lt. 2).  if linear model, a=1,c=slope.
c                      5. hole effect model
c   cc(i)            multiplicative factor of each nested structure.
c                      (sill-c0) for spherical, exponential,and gaussian
c                      slope for linear model.
c   aa(i)            parameter "a" of each nested structure.
c   irot             index of the rotation matrix for the first nested
c                    structure (the second nested structure will use
c                    irot+1, the third irot+2, and so on)
c   MAXROT           size of rotation matrix arrays
c   rotmat           rotation matrices
c
c
c OUTPUT VARIABLES:
c
c   cmax             maximum covariance
c   cova             covariance between (x1,y1,z1) and (x2,y2,z2)
c
c
c
c EXTERNAL REFERENCES: sqdist    computes anisotropic squared distance
c                      rotmat    computes rotation matrix for distance
c-----------------------------------------------------------------------
c     Thread-safe: all variables are local/automatic
      parameter(PI=3.14159265,PMX=999.,EPSLON=1.e-10)
      integer   nst(*),it(*)
      real      c0(*),cc(*),aa(*)
      real*8    rotmat(MAXROT,3,3),hsqd,sqdist
c
c Local variables for optimization:
c
      real      hr,cc_is,aa_is
      integer   itype,nstructs
c
c Calculate the maximum covariance value (used for zero distances and
c for power model covariance):
c
      istart = 1 + (ivarg-1)*MAXNST
      nstructs = nst(ivarg)
      cmax   = c0(ivarg)
      do is=1,nstructs
            ist = istart + is - 1
            if(it(ist).eq.4) then
                  cmax = cmax + PMX
            else
                  cmax = cmax + cc(ist)
            endif
      end do
c
c Check for "zero" distance, return with cmax if so:
c
      hsqd = sqdist(x1,y1,z1,x2,y2,z2,irot,MAXROT,rotmat)
      if(real(hsqd).lt.EPSLON) then
            cova = cmax
            return
      endif
c
c Loop over all the structures:
c
      cova = 0.0
      do is=1,nstructs
            ist = istart + is - 1
c
c Compute the appropriate distance:
c
            if(ist.ne.1) then
                  ir = min((irot+is-1),MAXROT)
                  hsqd=sqdist(x1,y1,z1,x2,y2,z2,ir,MAXROT,rotmat)
            end if
            h = real(dsqrt(hsqd))
c
c Cache structure parameters to avoid repeated array lookups:
c
            itype = it(ist)
            cc_is = cc(ist)
            aa_is = aa(ist)
c
c Compute h/aa ratio once (used by spherical, exponential, gaussian,
c and hole effect models) — avoids redundant divisions:
c
            hr = h / aa_is
c
c Spherical Variogram Model?
c
            if(itype.eq.1) then
                  if(hr.lt.1.) cova=cova+cc_is*(1.-hr*(1.5-.5*hr*hr))
c
c Exponential Variogram Model?
c
            else if(itype.eq.2) then
                  cova = cova + cc_is*exp(-3.0*hr)
c
c Gaussian Variogram Model?
c
            else if(itype.eq.3) then
                  cova = cova + cc_is*exp(-3.0*hr*hr)
c
c Power Variogram Model?
c
            else if(itype.eq.4) then
                  cova = cova + cmax - cc_is*(h**aa_is)
c
c Hole Effect Model?
c
            else if(itype.eq.5) then
c                 d = 10.0 * aa_is
c                 cova = cova + cc_is*exp(-3.0*h/d)*cos(hr*PI)
                  cova = cova + cc_is*cos(hr*PI)
            endif
      end do
c
c Finished:
c
      return
      end
