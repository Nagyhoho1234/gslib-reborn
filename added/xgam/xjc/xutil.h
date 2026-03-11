#ifndef _XUTIL_H
#define _XUTIL_H 1
#define HUGE 1.0e21

#include <stdio.h>
#include <math.h>
#include <util.h>

#include <X11/Xlib.h>
#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>

#include <X11/Shell.h>   /* required for AIX3.1 */

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
#include <Xm/Command.h>
#include <Xm/DialogS.h>

#include "WidgetWrap.h"

#ifndef MAXARGS
#define MAXARGS 32
#endif
static int      nargs;
static Arg      wargs[MAXARGS];
#define startargs() nargs=0;
#define setarg(name,value) { \
	if (nargs<MAXARGS) XtSetArg(wargs[nargs], name,value),nargs++; \
	else abort();}

extern Display *display;
extern Window window;
extern GC xgc;

#define         maxPixels   170
#define MAXCOLOR 65535
#define NCLASS 10

#define FREE_ON_EXIT 1
#define KEEP_ON_EXIT 0

extern GC create_xor_gc();

extern Widget toplevel;
extern XFontStruct *initFont();
extern Widget create_main_window();
extern Widget create_ok_cancel_widget();
extern Widget create_table();
extern Widget create_table_widget();
extern Widget create_table_labels();
extern Widget create_option_menu();
extern Widget WidgetCreate();
extern Widget *CreatePanelChoice();
extern float **matrix();
extern int **imatrix();
extern FILE *open_file_for_write();
extern char *get_localtime();
extern void InitHelp(), ShowHelp();
extern void not_ready();
extern void DialogDismissCB();


/*
   number of basic colors: r, g, b and gray, used in ../util/xt.c
   used in ../xt.c, ../image.h 
   also change in ps_image.c
*/
#define BASIC_COLORS 5

/* AIX3.1 does not have XmStringCreateSimple() defined, make one here */
#ifndef XmStringCreateSimple
#define XmStringCreateSimple(x) XmStringCreate(x, XmSTRING_DEFAULT_CHARSET)
#endif

#define RED 0
#define GREEN 1
#define BLUE 2
#define GRAY 3

extern void okCB();

extern Widget StatusW;
extern void CancelCB();
extern int xv_row(), xv_col();

#define RETURN(x) {xerror(toplevel, x); fprintf(stderr, x); return;}
#define WARN(x) {xerror(toplevel, x); fprintf(stderr, x); putchar('\n'); }
#define MSGS(x) {xerror(toplevel, x); fprintf(stderr, x); putchar('\n');}

/* W is predefined on DEC */
#ifdef W
#undef W
#endif
typedef struct _graph_t {
	int id;
	char title[256];
	XFontStruct *titleFont, *numberFont, *labelFont;
	Window win;
	int x, y, w, h, W, H;
	float sx, sy;
	axinfo ax, ay;
	Boolean active;
	/*
	struct _graph_t *next;
	*/
} graph_t;
/*
#define DEVICEX(g,xx) (g->x+ ((xx) - (g)->ax.min)/(g)->sx )
#define DEVICEY(g,yy) (g->y+(g)->h-((yy) - (g)->ay.min)/(g)->sy + 0.5)
#define USERX(g,xx) ((g)->ax.min + (float)(xx-(g)->x)      * (g)->sx)
#define USERY(g,yy) ((g)->ay.min + (float)((g)->y+(g)->h-yy)*(g)->sy)
*/
#define DEVICEX(g,xx) (g->x+((int) (((xx) - g->ax.min)/g->sx )))
#define DEVICEY(g,yy) (g->y+g->h-((int) (((yy) - g->ay.min)/g->sy + 0.5)))
#define USERX(g,xx) (g->ax.min + (float)(xx-g->x)      * g->sx)
#define USERY(g,yy) (g->ay.min + (float)(g->y+g->h-yy) * g->sy)

#ifdef HELP_ON_ENTER

static Widget Wtmp;
extern void ShowHelp();
/*
#define XtCreateWidget(a,b,c,d,e) \
Wtmp = XtCreateWidget(a,b,c,d,e); \
XtAddEventHandler(Wtmp, (EventMask) (EnterWindowMask|LeaveWindowMask), False, \
ShowHelp, NULL);
*/
#define XtCreateManagedWidget(a,b,c,d,e) \
Wtmp = XtCreateManagedWidget(a,b,c,d,e); \
XtAddEventHandler(Wtmp, (EventMask) (EnterWindowMask|LeaveWindowMask), False, \
ShowHelp, NULL);
#define XmCreatePushButton(a,b,c,d)  \
Wtmp = XmCreatePushButton(a, b, c, d); \
XtAddEventHandler(Wtmp, (EventMask) (EnterWindowMask|LeaveWindowMask), False, \
ShowHelp, NULL);
#define XmCreateLabel(a,b,c,d)  \
Wtmp = XmCreateLabel(a, b, c, d); \
XtAddEventHandler(Wtmp, (EventMask) (EnterWindowMask|LeaveWindowMask), False, \
ShowHelp, NULL);
#define XmCreateText(a,b,c,d)  \
Wtmp = XmCreateText(a, b, c, d); \
XtAddEventHandler(Wtmp, (EventMask) (EnterWindowMask|LeaveWindowMask), False, \
ShowHelp, NULL);
#define XmCreateOptionMenu(a,b,c,d)  \
Wtmp = XmCreateOptionMenu(a, b, c, d); \
XtAddEventHandler(Wtmp, (EventMask) (EnterWindowMask|LeaveWindowMask), False, \
ShowHelp, NULL);

#endif /* HELP_ON_ENTER */

/* Callback definitions and prototypes. */
#define XjcCallback(name)                             \
  void name (Widget w, XtPointer client_data, XtPointer call_data)
#define XjcCallbackPrototype(name) \
  extern void name (Widget, XtPointer, XtPointer)

/* Event handler functions and prototypes. */
#define XmxEventHandler(name)                             \
  void name (Widget w, XtPointer client_data, XEvent *event, Boolean *cont)
#define XmxEventHandlerPrototype(name)                            \
  extern void name (Widget, XtPointer, XEvent *, Boolean *)

#endif
