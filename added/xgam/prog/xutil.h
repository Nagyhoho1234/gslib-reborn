#include <stdio.h>
#include <math.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>


#include <X11/cursorfont.h>
#include <Xm/Xm.h>
#include <Xm/MainW.h>
#include <Xm/ScrolledW.h>
#include <Xm/DrawingA.h>
#include <Xm/RowColumn.h>
#include <Xm/PushB.h>
#include <Xm/PushBG.h>
#include <Xm/Separator.h>
#include <Xm/BulletinB.h>
#include <Xm/MessageB.h>
#include <Xm/SelectioB.h>
#include <Xm/Text.h>
#include <Xm/Label.h>
#include <Xm/BulletinB.h>
#include <Xm/Form.h>
#include <Xm/List.h>
#include <Xm/Scale.h>
#include <Xm/ToggleB.h>
#include <Xm/ToggleBG.h>
#include <Xm/Command.h>
#include <Xm/DialogS.h>
#include <Xm/FileSB.h>



#ifndef MAXARGS
#define MAXARGS 32
#endif

static int      nargs;
static Arg      wargs[MAXARGS];

#define startargs() nargs=0;
#define setarg(name,value) { \
	if (nargs<MAXARGS) XtSetArg(wargs[nargs], name,value),nargs++; \
	else abort();}

#define RETURN(x) {xerror(toplevel, x); fprintf(stderr, x); return;}
#define WARN(x) {xerror(toplevel, x); fprintf(stderr, x); putchar('\n'); }
#define MSGS(x) {xerror(toplevel, x); fprintf(stderr, x); putchar('\n');}

#define DEVICEX(g,xx) (g->x+((int) (((xx) - g->ax.min)/g->sx )))
#define DEVICEY(g,yy) (g->y+g->h-((int) (((yy) - g->ay.min)/g->sy + 0.5)))
#define USERX(g,xx) (g->ax.min + (float)(xx-g->x)      * g->sx)
#define USERY(g,yy) (g->ay.min + (float)(g->y+g->h-yy) * g->sy)


