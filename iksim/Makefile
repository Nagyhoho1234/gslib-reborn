#-----------------------------------------------------------------------
#
#                     Generic GSLIB Makefile
#                     **********************
#
progname=iksim
#
#
#-----------------------------------------------------------------------


PROG   = ../bin/$(progname)
FFLAGS = -O
SRCS   =  $(progname).f postik.f pfsimfft.f  trans.f
OBJS   =  $(progname).o postik.o pfsimfft.o  trans.o
INCS   =  $(progname).inc
LIBS   = ../gslib/libgs.a
all:$(PROG) 
$(PROG):$(OBJS)
	gfortran $(FFLAGS) -o $@ $(OBJS) $(LIBS)
.f.o:
	gfortran -c $(FFLAGS) $<
$(OBJS):$(INCS)
clean:
	/bin/rm -rf $(OBJS) $(PROG)
