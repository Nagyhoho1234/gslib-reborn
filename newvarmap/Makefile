#-----------------------------------------------------------------------
#
#                     Generic GSLIB Makefile
#                     **********************
#
progname=newvarmap
#
#
#-----------------------------------------------------------------------


PROG   = $(progname)
FFLAGS = -O
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
