#-----------------------------------------------------------------------
#
#                     Generic GSLIB Makefile
#                     **********************
#
progname=sgsim_fc
#
#
#-----------------------------------------------------------------------


PROG   =  $(progname)
FFLAGS = -O3 -static -fno-whole-file -static-libgfortran -static-libgcc
SRCS   =  $(progname).f
OBJS   =  $(progname).o
INCS   =  $(progname).inc
LIBS   = ../gslib/libgs.a
all:$(PROG) 
$(PROG):$(OBJS)
	gfortran -o $@ $(OBJS) $(LIBS)
.f.o:
	gfortran -c $(FFLAGS) $<
$(OBJS):$(INCS)
clean:
	/bin/rm -rf $(OBJS) $(PROG)
