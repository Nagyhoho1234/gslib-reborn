/*
 * WidgetWrap.c -- variable argument style programmer interfaces to widgets:
 *    WidgetCreate(name, class, parent, varargs...);
 *    WidgetSet(name, varargs);
 *    WidgetGet(name, varargs);
 *    GenericWidgetName(buf);
 *
 * This module was written by Dan Heller <island!argv@sun.com> or
 * <dheller@ucbcory.berkeley.edu>.
 *
 * The purpose of this module is to allow the programmer to Create
 * widgets and set/get widget attributes via a variable argument list
 * style of function call.  This eliminates the need for many local
 * variables and bothersome XtSetArg() calls and so forth.  An example
 * of usage:
 *
 *    Widget foo;
 *
 *    foo = WidgetCreate("foo", labelWidgetClass, toplevel,
 *        XtNlabel,		"Widget",
 *	  XtNforeground,	WhitePixelOfScreen(XtScreen(toplevel)),
 *	  XtNbackground,	BlackPixelOfScreen(XtScreen(toplevel)),
 *        XtNborderWidth,	1,
 *        NULL);
 *
 * As you can see, the list must be NULL terminated.  You may pass up to
 * to MAXARGS argument pairs.  Increase this number in WidgetWrap.h if
 * necessary.  There are special args availabel to the create/get/set
 * functions that are available:
 *
 *    XtNmanaged		pass "False" to create a non-managed widget.
 *    XtNargList		takes _two_ parameters.
 *    XtNpopupShell		pass "True" to create a PopupShellWidget.
 *    XtNapplicShell		pass "True" to create an applicationShellWidget
 *
 * The XtNargList makes it possible to pass attributes to the create/get/set
 * calls that are probably common to many widgets to be created or reset.
 *
 * static Arg args[] = {
 *     XtNforeground,	black,
 *     XtNbackground,   white,
 *     XtNwidth,	20,
 *     XtNheight,	10,
 * };
 * foo = WidgetCreate("bar", widgetClass, toplevel,
 *     XtNargList,	args, XtNumber(args),
 *     NULL);
 *
 * Most large applciations will create huge numbers of widgets which the
 * programmer has to think up unique names for all of them.  What's more,
 * typically, as noted by the examples above, the names are constant strings
 * which takes up memory, disk spaces, etc...  So, if WidgetCreate() gets
 * NULL as the name of the widget, then a widget name will be created
 * automatically.  Since most of the time, user's don't care what the name
 * of a widget is, this capability is available.
 *
 * Finally, a note about varargs.  Note that there are many different
 * implementations of varargs.  To maintain portability, it is important
 * to never return from a function that uses varargs without calling va_end().
 * va_start() and va_end() should always exist in the same block of {}'s.
 * There can be blocks between them, but va_end() shouldn't be in a block
 * inside of the va_start() stuff.  This is to allow support for weird
 * implementations which define va_start() to something like:  ".... { "
 * (pyramid computers for one).
 * Also, if you use varargs, never declare "known" arguments; extract them
 * from the vararg list later.
 */
#include <stdio.h>
#include <X11/Intrinsic.h>
#include <varargs.h>
#include "WidgetWrap.h"

char *
 GenericWidgetName(buf)
    char *buf;
{
    static int widget_count;

    (void) sprintf(buf, "_widget.%d", widget_count++);
    return buf;
}

/*
 * WidgetCreate()
 *	Create a widget passing it's instance attributes and other parameters
 * as variable arguments.  This removes the need to build your own Arg[]
 * lists, etc...  Terminate argument list pairs with a NULL argument.
 */
/* VARARGS */
Widget
WidgetCreate(va_alist)
va_dcl
{
    va_list var;
    Arg args[MAXARGS];
    int err = 0, nargs, i = 0, managed = 1;
    String argstr;
    XtArgVal argval;
    char *name, buf[32];
    WidgetClass class;
    Widget parent, (*create_func) () = NULL;

    va_start(var);

    if (!(name = va_arg(var, char *)))
	name = GenericWidgetName(buf);
    class = va_arg(var, WidgetClass);
    parent = va_arg(var, Widget);

    while (argstr = va_arg(var, char *)) {
	if (i == MAXARGS) {
	    fprintf(stderr, "WidgetCreate: too many arguments: %d\n", i);
	    err++;
	    break;
	}
	if (!strcmp(argstr, XtNargList)) {
	    ArgList list = va_arg(var, ArgList);
	    int numargs = va_arg(var, int);
	    for (numargs--; i < MAXARGS && numargs >= 0; i++, numargs--)
		XtSetArg(args[i], list[numargs].name, list[numargs].value);
	    if (i == MAXARGS) {
		fprintf(stderr, "WidgetCreate: too many arguments: %d\n", i);
		err++;
		break;
	    }
	} else if (!strcmp(argstr, XtNmanaged))
	    managed = va_arg(var, int);
	else if (!strcmp(argstr, XtNpopupShell)) {
	    if (va_arg(var, int))
		create_func = XtCreatePopupShell;
	} else if (!strcmp(argstr, XtNapplicShell)) {
	    if (va_arg(var, int))
		create_func = XtCreateApplicationShell;
	} else {
	    argval = va_arg(var, XtArgVal);
	    XtSetArg(args[i], argstr, argval);
	    ++i;
	}
    }
    va_end(var);

    if (err)
	return NULL;

    if (create_func == XtCreateApplicationShell)
	return XtCreateApplicationShell(name, class, args, i);

    if (!create_func)
	create_func = managed ? XtCreateManagedWidget : XtCreateWidget;
    return (create_func) (name, class, parent, args, i);
}

/*
 * WidgetSet()
 *	Once a widget has been created, you may use this routine to
 * add or change a varaible number of attributes on it.
 */
/*VARARGS*/
void
 WidgetSet(va_alist)
 va_dcl
{
    String argstr;
    Arg args[MAXARGS];
    XtArgVal argval;
    int i = 0, managed = -1;
    va_list var;
    Widget w;

    va_start(var);

    w = va_arg(var, Widget);

    while (argstr = va_arg(var, char *)) {
	if (i == MAXARGS) {
	    fprintf(stderr, "Warning: increase MAXARGS! (%d)\n", i);
	    XtSetValues(w, args, i);
	    i = 0;
	}
	if (!strcmp(argstr, XtNmanaged))
	    managed = va_arg(var, int);
	else if (!strcmp(argstr, XtNargList)) {
	    ArgList list = va_arg(var, ArgList);
	    XtArgVal numargs = va_arg(var, Cardinal);
	    XtSetValues(w, list, numargs);
	} else {
	    argval = va_arg(var, XtArgVal);
	    XtSetArg(args[i], argstr, argval);
	    ++i;
	}
    }
    va_end(var);
    if (i > 0)
	XtSetValues(w, args, i);
    if (managed > -1)
	if (managed == True)
	    XtManageChild(w);
	else
	    XtUnmanageChild(w);
}

/*
 * WidgetGet()
 *     Get the values of a widget via an interface identical to WidgetSet
 */
/*VARARGS*/
void
 WidgetGet(va_alist)
 va_dcl
{
    String argstr;
    Arg args[MAXARGS];
    XtArgVal argval;
    int i = 0;
    va_list var;
    Widget w;

    va_start(var);

    w = va_arg(var, Widget);

    while (argstr = va_arg(var, char *)) {
	argval = va_arg(var, XtArgVal);
	if (i == MAXARGS) {
	    fprintf(stderr, "Warning: increase MAXARGS! (%d)\n", i);
	    XtGetValues(w, args, i);
	    i = 0;
	}
	if (!strcmp(argstr, XtNargList)) {
	    ArgList list = va_arg(var, ArgList);
	    XtArgVal numargs = va_arg(var, Cardinal);
	    XtGetValues(w, list, numargs);
	} else
	    XtSetArg(args[i], argstr, argval);
	++i;
    }
    va_end(var);
    if (i > 0)
	XtGetValues(w, args, i);
}
