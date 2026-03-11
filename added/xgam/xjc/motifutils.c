/* $Id: motifutils.c,v 1.12 1992/04/05 15:35:00 pturner Exp pturner $
 *
 * utilities for Motif
 *
 */

#include <stdio.h>

#include <Xm/Xm.h>
#include <Xm/BulletinB.h>
#include <Xm/DialogS.h>
#include <Xm/Frame.h>
#include <Xm/LabelG.h>
#include <Xm/PushBG.h>
#include <Xm/RowColumn.h>
#include <Xm/Text.h>
#include <Xm/Separator.h>

#include "WidgetWrap.h"

extern Widget toplevel;
extern Display *display;

static XFontStruct *f;
XmFontList xmf;
int sw, sh;

xv_SetChoice(w, value)
    Widget *w;
    int value;
{
    Arg a;

    XtSetArg(a, XmNmenuHistory, w[value + 2]);
    XtSetValues(w[0], &a, 1);
}

int xv_GetChoice(w)
    Widget *w;
{
    Arg a;
    Widget warg;
    int i;

    XtSetArg(a, XmNmenuHistory, &warg);
    XtGetValues(w[0], &a, 1);
    i = 0;
    while ((w[i + 2] != warg) && i < 50)
	i++;
    return i;
}

#include <varargs.h>

Widget
* CreatePanelChoice(va_alist)
va_dcl
{
    va_list var;
    Arg args[MAXARGS];
    int nchoices, x, y, err = 0, nargs, i = 0, managed = 1;
    String argstr;
    XmString str;
    XtArgVal argval;
    char *name, *labelstr, *s, buf[32];
    WidgetClass class;
    Widget parent, lab, w[50], *retval;
    int wid;

    va_start(var);
    parent = va_arg(var, Widget);
    labelstr = va_arg(var, char *);
    x = va_arg(var, int);
    y = va_arg(var, int);
    nchoices = va_arg(var, int) -1;
    retval = (Widget *) XtMalloc((nchoices + 2) * sizeof(Widget));

    name = GenericWidgetName(buf);
    w[1] = XmCreatePulldownMenu(parent, name, NULL, 0);

    i = 0;
    while ((s = va_arg(var, char *)) != NULL) {
	w[i + 2] = XmCreatePushButtonGadget(w[1], s, NULL, 0);
	i++;
    }
    XtManageChildren(w + 2, nchoices);
    va_end(var);

    name = GenericWidgetName(buf);

    str = XmStringCreate(labelstr, XmSTRING_DEFAULT_CHARSET);
    wid = XmStringWidth(xmf, str);

    nargs = 0;
    XtSetArg(args[nargs], XmNlabelString, str);
    nargs++;
    XtSetArg(args[nargs], XmNsubMenuId, w[1]);
    nargs++;
    XtSetArg(args[nargs], XmNentryBorder, 2);
    nargs++;
    XtSetArg(args[nargs], XmNwhichButton, 1);
    nargs++;
    XtSetArg(args[nargs], XmNx, x - wid);
    nargs++;
    XtSetArg(args[nargs], XmNy, y);
    nargs++;
    w[0] = XmCreateOptionMenu(parent, name, args, nargs);
    XtManageChild(w[0]);
    for (i = 0; i < nchoices + 2; i++) {
	retval[i] = w[i];
    }
    return retval;
}

Widget
* CreatePanelChoice0(va_alist)
va_dcl
{
    va_list var;
    Arg args[MAXARGS];
    int nchoices, x, y, ncols, err = 0, nargs, i = 0, managed = 1;
    XmString str;
    String argstr;
    XtArgVal argval;
    char *name, *labelstr, *s, buf[32];
    WidgetClass class;
    Widget parent, lab, w[50], *retval;
    int wid;

    va_start(var);
    parent = va_arg(var, Widget);
    x = va_arg(var, int);
    y = va_arg(var, int);
    labelstr = va_arg(var, char *);
    ncols = va_arg(var, int);
    nchoices = va_arg(var, int) -1;
    retval = (Widget *) XtMalloc((nchoices + 2) * sizeof(Widget));

    name = GenericWidgetName(buf);
    nargs = 0;
    XtSetArg(args[nargs], XmNorientation, XmVERTICAL);
    nargs++;
    XtSetArg(args[nargs], XmNpacking, XmPACK_COLUMN);
    nargs++;
    XtSetArg(args[nargs], XmNnumColumns, ncols);
    nargs++;
    w[1] = XmCreatePulldownMenu(parent, name, args, nargs);

    i = 0;
    while ((s = va_arg(var, char *)) != NULL) {
	w[i + 2] = XmCreatePushButtonGadget(w[1], s, NULL, 0);
	i++;
    }
    XtManageChildren(w + 2, nchoices);
    va_end(var);

    name = GenericWidgetName(buf);

    str = XmStringCreate(labelstr, XmSTRING_DEFAULT_CHARSET);
    wid = XmStringWidth(xmf, str);

    nargs = 0;
    XtSetArg(args[nargs], XmNlabelString, str);
    nargs++;
    XtSetArg(args[nargs], XmNsubMenuId, w[1]);
    nargs++;
    XtSetArg(args[nargs], XmNentryBorder, 2);
    nargs++;
    XtSetArg(args[nargs], XmNwhichButton, 1);
    nargs++;
    XtSetArg(args[nargs], XmNx, x - wid);
    nargs++;
    XtSetArg(args[nargs], XmNy, y);
    nargs++;
    w[0] = XmCreateOptionMenu(parent, name, args, nargs);
    XtManageChild(w[0]);
    for (i = 0; i < nchoices + 2; i++) {
	retval[i] = w[i];
    }
    return retval;
}

Widget CreateTextItem(parent, x, y, len, s)
    Widget parent;
    int x, y, len;
    char *s;
{
    static Widget w;
    XmString str;
    char buf[256];
    int wid;
    Dimension ww, wh;

    GenericWidgetName(buf);
    str = XmStringCreateLtoR(s, XmSTRING_DEFAULT_CHARSET);
    wid = XmStringWidth(xmf, str);
    w = WidgetCreate(buf, xmLabelGadgetClass, parent,
		     XmNlabelString, str,
		     XmNx, x - wid,
		     XmNy, y,
		     NULL);
    GenericWidgetName(buf);
    w = WidgetCreate(buf, xmTextWidgetClass, parent,
		     XmNx, x,
		     XmNy, y,
		     XmNtraversalOn, True,
		     XmNcolumns, len,
		     NULL);
    return w;
}

void CreateDialogBottomLine(parent, wid, y, 
ok_proc, ok_data, dismiss_proc, dismiss_data, help_proc, help_data)
Widget parent;
int wid, y;
void (*ok_proc)(), (*dismiss_proc)(), (*help_proc)();
caddr_t *ok_data,dismiss_data,help_data;
{
	Widget sep, ok, dismiss, help;
	int m, n;
	char buf[256];
	GenericWidgetName(buf);
	sep = WidgetCreate(buf, xmSeparatorWidgetClass, parent, 
		XmNx, 0,
		XmNy, xv_row(parent, y),
		XmNwidth, xv_col(parent, wid),
		XmNorientation, XmHORIZONTAL,
		NULL);
	n=0;
	if (ok_proc) n++;
	if (dismiss_proc) n++;
	if (help_proc) n++;
	m=0;
	if (ok_proc) {
		ok = WidgetCreate("Apply", xmPushButtonGadgetClass, parent,
                     XmNx, xv_col(parent, (++m)*wid/(n+1)),
                     XmNy, xv_row(parent, y) + 5,
                     NULL);
		if (ok_proc) XtAddCallback(ok, XmNactivateCallback, ok_proc, ok_data);
	}
	if (dismiss_proc) {
		dismiss = WidgetCreate("Dismiss", xmPushButtonGadgetClass, parent,
                     XmNx, xv_col(parent, (++m)*wid/(n+1)),
                     XmNy, xv_row(parent, y) + 5,
                     NULL);
		XtAddCallback(dismiss, XmNactivateCallback, dismiss_proc, dismiss_data);
	}
	if (help_proc) {
	   help = WidgetCreate("Dismiss", xmPushButtonGadgetClass, parent,
                     XmNx, xv_col(parent, (++m)*wid/(n+1)),
                     XmNy, xv_row(parent, y) + 5,
                     NULL);
		XtAddCallback(help, XmNactivateCallback, help_proc, help_data);
	}
}

init_rowcol()
{
    int nargs;
    Arg args[3];

        sw = sh = 0;
        f = (XFontStruct *) XLoadQueryFont(display, "-adobe-helvetica-bold-r-normal--14-*-*-*-*-*-iso8859-1");
        if (f == NULL) {
            if (f == NULL) {
                fprintf(stderr, "Can't load font fixed in init_rowcol, using default\n");
                f = (XFontStruct *) XLoadQueryFont(display, XtDefaultFont);
            }
            if (f == NULL) {
                fprintf(stderr, "Can't load font in init_rowcol, using fixed\n");
                f = (XFontStruct *) XLoadQueryFont(display, "fixed");
            }
            if (f == NULL) {
                fprintf(stderr, "Giving up in init_rowcol(), taking a guess 15x20\n");
                sw = 15;
                sh = 20;
            }
        }
        xmf = XmFontListCreate(f, XmSTRING_DEFAULT_CHARSET);
        if (!sw) {
            sw = XmStringWidth(xmf, XmStringCreateLtoR("M", XmSTRING_DEFAULT_CHARSET));
            sh = XmStringHeight(xmf, XmStringCreateLtoR("My", XmSTRING_DEFAULT_CHARSET));
        }
}

char *xv_getstr(w)
    Widget w;
{
    char *s;
    static char buf[256];

    strcpy(buf, s = XmTextGetString(w));
    XtFree(s);
    return buf;
}

xv_setstr(w, s)
    Widget w;
    char *s;
{
    XmTextSetString(w, s);
}

int xv_row(w, r)
    Widget w;
    int r;
{
    return 2 * (5 + sh) * r;
}

int xv_col(w, c)
    Widget w;
    int c;
{
    return sw * c;
}

/*
 * set position
 */
void XmGetPos(w, type, x, y)
    Widget w;
    int type;
    int *x, *y;
{
    Arg a[4];
    int ac = 0;
    static int curpos = 0;
    Position xt, yt;
    Dimension wt, ht;

/*
 * get the location of the whole app
 */
    ac = 0;
    XtSetArg(a[ac], XmNx, &xt);
    ac++;
    XtSetArg(a[ac], XmNy, &yt);
    ac++;
    XtSetArg(a[ac], XmNheight, &ht);
    ac++;
    XtSetArg(a[ac], XmNwidth, &wt);
    ac++;
    XtGetValues(w, a, ac);

    switch (type) {
    case 0:			/* position at upper left */
	*x = xt - 50;
	*y = yt + ht / 4 + (curpos % 5) * 50;
	curpos++;
	if (*x < 0) {
	    *x = 0;
	}
	if (*y < 0) {
	    *y = 0;
	}
	break;
    case 1:			/* position at upper right */
	*x = xt + 50 + wt;
	*y = yt + (curpos % 5 + 1) * 50;
	break;
    case 2:			/* center on w */
	*x = xt + wt / 2;
	*y = yt + ht / 2;
	break;
    }
}

void GetWH(w, ww, wh)
    Widget w;
    Dimension *ww, *wh;
{
    Arg args;

    XtSetArg(args, XmNwidth, ww);
    XtGetValues(w, &args, 1);
    XtSetArg(args, XmNheight, wh);
    XtGetValues(w, &args, 1);
}

void GetXY(w, x, y)
    Widget w;
    Position *x, *y;
{
    Arg args;

    XtSetArg(args, XmNx, x);
    XtGetValues(w, &args, 1);
    XtSetArg(args, XmNy, y);
    XtGetValues(w, &args, 1);
}

/**********************************************************************
 * XtFlush - Flushes all Xt events.
 **********************************************************************/
void XtFlush()
{
    extern Widget toplevel;

    XtAppContext app;

    app = XtWidgetToApplicationContext(toplevel);
    while (XtAppPending(app) & XtIMXEvent) {
	XtAppProcessEvent(app, XtIMXEvent);
	XFlush(XtDisplay(toplevel));
    }
}
