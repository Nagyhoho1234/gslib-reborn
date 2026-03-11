# Makefile to build yap
# cpu:              Silicon Graphics version
# Operating system: IRIX 4.0.5
# Tested on:        slgr.stanford.edu, Sue Griesbach's personal machine

# define build flags
CC       = gcc
INCLUDES = -I/usr/include/X11
CFLAGS   = -O2 -DSYSV
LDFLAGS  = -L/usr/lib/X11
LIBS     = -lMrm -lXm -lXt -lXaw -lXau -lXmu -lX11 -lc -lPW -lm
EXEDIR   = $(HOME)/bin

OBJS     = ya2d.o \
	yacmap.o \
	yafile.o \
	yaread.o \
	yautils.o \
	ya3d.o \
	yacut.o \
	yastat.o \
	yamain.o \
	yasave.o \
	yadebug.o \
	yacompute.o \
	nxhelp.o

.SUFFIXES: .o .c

# Define rules
.c.o:
	@echo "________ Compiling $< to obj ________"
	$(CC) -c $(CFLAGS) $(INCLUDES) $<

yap:     $(OBJS)
	@echo "________ Compiling yap to exe ________"
	$(CC) -o $@ $(OBJS) $(CFLAGS) $(LDFLAGS) $< $(LIBS)

install: yap gsl2fbin gsl2cbin
	mv yap $(EXEDIR)
	mv gsl2fbin $(EXEDIR)
	mv gsl2cbin $(EXEDIR)

gsl2fbin: gsl2bin.c
	$(CC) gsl2bin.c -o gsl2fbin -DFMT=1 -lm

gsl2cbin: gsl2bin.c
	$(CC) gsl2bin.c -o gsl2cbin -DFMT=2 -lm

clean:
	rm -f $(OBJS) yap

nxhelp.o:  NXHelp.h NXHelp.icn
ya2d.o:    yap.h yaconfig.h
ya3d.o:    yap.h yaconfig.h
yacmap.o:  yap.h yaconfig.h NXHelp.h
yacut.o:   yap.h
yadebug.o: yap.h yaconfig.h
yafile.o:  yap.h NXHelp.h
yamain.o:  yap.h yaconfig.h yaicon.h
yaread.o:  yap.h
yasave.o:  yap.h
yautils.o: yap.h yaconfig.h
yavaria.o: yap.h yaconfig.h
