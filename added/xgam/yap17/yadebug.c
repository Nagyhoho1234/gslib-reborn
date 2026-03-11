
#include <varargs.h>

#include <Xm/Form.h>
#include <Xm/DialogS.h>
#include <Xm/SelectioB.h>
#include <Xm/Text.h>
#include <Xm/ScrolledW.h>
#include <Xm/PushBG.h>

#include "yap.h"
#include "yaconfig.h"

static Widget     debug, debug_form;

extern Widgets_t *widgets;
extern World_t   *world;

static void  hide_debug();

void create_debug(void)          /*F*/
   {
   Widget debug_hide;
   Arg    args[12];
   char   title[STRING1];

   strcpy(title, "Information");

   debug = XtVaCreatePopupShell("info_window",
           xmDialogShellWidgetClass, widgets->top,
           XmNmwmFunctions,          30,
           XmNtitle,                 title,
           NULL);
   debug_form = XtVaCreateWidget("debug_form",
                   xmFormWidgetClass,   debug,
                   XmNtopAttachment,    XmATTACH_FORM,
                   XmNbottomAttachment, XmATTACH_FORM,
                   XmNleftAttachment,   XmATTACH_FORM,
                   XmNrightAttachment,  XmATTACH_FORM,
                   NULL);

   debug_hide = XtVaCreateManagedWidget("Hide",
                xmPushButtonGadgetClass, debug_form,
                XmNbottomAttachment,     XmATTACH_FORM,
                XmNleftAttachment,       XmATTACH_FORM,
                XmNrightAttachment,      XmATTACH_FORM,
                NULL);

   XtSetArg(args[0], XmNeditable,         False);
   XtSetArg(args[1], XmNeditMode,         XmMULTI_LINE_EDIT);
   XtSetArg(args[2], XmNscrollingPolicy,  XmAUTOMATIC);
   XtSetArg(args[3], XmNtopAttachment,    XmATTACH_FORM);
   XtSetArg(args[4], XmNleftAttachment,   XmATTACH_FORM);
   XtSetArg(args[5], XmNrightAttachment,  XmATTACH_FORM);
   XtSetArg(args[6], XmNbottomAttachment, XmATTACH_WIDGET);
   XtSetArg(args[7], XmNbottomWidget,     debug_hide);
   widgets->debug_area=XmCreateScrolledText(debug_form, "debug_msg", args, 8);

   XtAddCallback(debug_hide, XmNactivateCallback,
                    (XtCallbackProc)hide_debug, NULL);
   /*XtPopdown(debug);*/
   }

void debug_fn(void)
   {
   if (!debug) create_debug();
   /*XtManageChild(widgets->debug_area);*/
   /*XtPopup(debug, XtGrabNone);*/
   XtManageChild(widgets->debug_area);
   XtManageChild(debug_form);
   XtManageChild(debug);
   MySetSensitive((int)B_DEBUG, 0, False);
   }

static void  hide_debug(Widget               un1,       /*F*/
                        XtPointer            un2,       /*F*/
                        XtPointer            un3)       /*F*/
   {
   /*if (world->nb_var==1)*/
      MySetSensitive((int)B_DEBUG, 0, True);
/* Because bug if more than one variable */
   XtUnmanageChild(debug);
   /*XtPopdown(debug);*/
   }

void p_area(va_alist)
va_dcl
{
    char    msgbuf[STRING2];
    char   *fmt;
    va_list args;
    Widget  area;
    XmTextPosition  position;

    va_start(args);
    area = (Widget)va_arg(args, Widget);
if (!area) return;
    fmt = (char *)va_arg(args, char *);
#ifndef NO_VPRINTF
    (void) vsprintf(msgbuf, fmt, args);
#else /* !NO_VPRINTF */
    {
        FILE foo;
        foo._cnt = BUFSIZ;
        foo._base = foo._ptr = msgbuf; /* (unsigned char *) ?? */
        foo._flag = _IOWRT+_IOSTRG;
        (void) _doprnt(fmt, args, &foo);
        *foo._ptr = '\0'; /* plant terminating null character */
    }
#endif /* NO_VPRINTF */
    va_end(args);

   position=XmTextGetLastPosition(area);
   XmTextInsert(area, position, msgbuf);
   XmTextShowPosition(area, position+strlen(msgbuf));
}
