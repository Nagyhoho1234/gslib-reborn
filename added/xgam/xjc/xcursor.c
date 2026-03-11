/*
two things:
1 - define the cursor to be a watch
2 - add a grab for an unrealized widget

When done, XUndefineCursor for the window, rather than change to YOUR
decision of what is the 'normal' cursor.
*/

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/Shell.h>
#include <X11/cursorfont.h>
#include <Xm/Xm.h>
#include <Xm/PushB.h>

extern Widget toplevel;
static Boolean grabbed = False;			/* is the grab in effect? */
static Widget grabWidget = (Widget) 0;		/* target of the grab */

void
busyCursor()
{
    static Cursor BusyCursor = (Cursor) 0;
    
    /* define an appropriate busy cursor */
    if (BusyCursor == (Cursor) 0) {
	BusyCursor = XCreateFontCursor(XtDisplay(toplevel), XC_watch);
	grabWidget = XtCreateWidget("grabWidget", xmPushButtonWidgetClass,
				    toplevel, NULL, 0);
    }
    XDefineCursor(XtDisplay(toplevel), XtWindow(toplevel), BusyCursor);
    if (!grabbed) {
	XtAddGrab(grabWidget, True, False);
	grabbed = True;
    }
    XFlush(XtDisplay(toplevel));
    
    return;
}

void
unbusyCursor()
{
    XUndefineCursor(XtDisplay(toplevel), XtWindow(toplevel));
    if (grabbed) {
	XtRemoveGrab(grabWidget);
    }
    grabbed = False;
    XFlush(XtDisplay(toplevel));
    
    return;
}

