#ifndef WidgetWrap
#define WidgetWrap
/*
 * WidgetWrap.h -- header file for the WidgetWrap library.
 *
 * This module was written by Dan Heller <island!argv@sun.com> or
 * <dheller@ucbcory.berkeley.edu>.
 */

#ifndef MAXARGS
#define MAXARGS		10
#endif
#define XtNargList	"Arglist"
#define XtNmanaged	"Managed"
#define XtNpopupShell	"popupShell"
#define XtNapplicShell	"applicationShell"

extern void WidgetSet(), WidgetGet();
extern Widget WidgetCreate();
extern char *GenericWidgetName();

extern Widget CreateTextItem();
extern Widget *CreatePanelChoice();
#endif /* WidgetWrap */
