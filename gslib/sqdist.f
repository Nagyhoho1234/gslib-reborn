      real*8 function sqdist(x1,y1,z1,x2,y2,z2,ind,MAXROT,rotmat)
c-----------------------------------------------------------------------
c
c    Squared Anisotropic Distance Calculation Given Matrix Indicator
c    ***************************************************************
c
c OPTIMIZED VERSION:
c   - Unrolled i=1,3 loop to eliminate loop overhead
c   - Local variables for dx,dy,dz and rotmat elements
c   - Fused multiply-add pattern for better pipelining
c   - Thread-safe: no saved state, all locals on stack
c
c This routine calculates the anisotropic distance between two points
c  given the coordinates of each point and a definition of the
c  anisotropy.
c
c
c INPUT VARIABLES:
c
c   x1,y1,z1         Coordinates of first point
c   x2,y2,z2         Coordinates of second point
c   ind              The rotation matrix to use
c   MAXROT           The maximum number of rotation matrices dimensioned
c   rotmat           The rotation matrices
c
c
c
c OUTPUT VARIABLES:
c
c   sqdist           The squared distance accounting for the anisotropy
c                      and the rotation of coordinates (if any).
c
c
c NO EXTERNAL REFERENCES
c
c
c-----------------------------------------------------------------------
      real*8 rotmat(MAXROT,3,3),dx,dy,dz,cont1,cont2,cont3
c
c Compute component distance vectors:
c
      dx = dble(x1 - x2)
      dy = dble(y1 - y2)
      dz = dble(z1 - z2)
c
c Unrolled loop: compute rotated components and squared distance
c in one pass without loop overhead. This is the single hottest
c function in GSLIB — every cycle counts.
c
      cont1 = rotmat(ind,1,1)*dx + rotmat(ind,1,2)*dy
     +      + rotmat(ind,1,3)*dz
      cont2 = rotmat(ind,2,1)*dx + rotmat(ind,2,2)*dy
     +      + rotmat(ind,2,3)*dz
      cont3 = rotmat(ind,3,1)*dx + rotmat(ind,3,2)*dy
     +      + rotmat(ind,3,3)*dz
      sqdist = cont1*cont1 + cont2*cont2 + cont3*cont3
      return
      end
