C%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
C                                                                      %
C Copyright (C) 1996, The Board of Trustees of the Leland Stanford     %
C Junior University.  All rights reserved.                             %
C                                                                      %
C%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
c-----------------------------------------------------------------------
c  ANNEAL include file - GSLIB2-OPT v2026.1
c  Now uses Fortran 90 module for all shared data.
c  Large var() grid array is dynamically allocated at runtime.
c-----------------------------------------------------------------------
      use anneal_mod
c
c     ACORN random number generator common block
c     (shared with gslib library acorni function)
c
      common /iaco/   ixv(MAXOP1)
