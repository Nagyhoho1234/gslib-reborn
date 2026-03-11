#-----------------------------------------------------------------------
#
#                     Generic GSLIB Makefile
#                     **********************
#
progname=newbacktr
#
#
#-----------------------------------------------------------------------


PROG   = ./$(progname)
FFLAGS = -O -static-libgcc
SRCS   =  $(progname).f
OBJS   =  $(progname).o
INCS   =  
LIBS   = ../gslib/libgs.a
all:$(PROG) 
$(PROG):$(OBJS)
	gfortran -o $@ $(OBJS) $(LIBS)
.f.o:
	gfortran -c $(FFLAGS) $<
$(OBJS):$(INCS)
clean:
	/bin/rm -rf $(OBJS) $(PROG)
