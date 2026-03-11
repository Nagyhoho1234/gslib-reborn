
#include <varargs.h>
#include <ctype.h>

#include <X11/cursorfont.h>
#include <Xm/MessageB.h>
#include <Xm/LabelG.h>
#include <Xm/DrawingA.h>
#include <Xm/DialogS.h>
#include <Xm/Form.h>
#include "yap.h"
#include "yaconfig.h"

static Widget     timer_label;

extern Widgets_t *widgets;
extern World_t   *world;

void            message(char             *prgname)     /*F*/
   {
   printf("\n********* This is YAP version "); printf(VERSION);
   printf(" *********\n");
   printf("\nIn this version:\n");
   printf("  - command line arguments (type %s -h to get help)\n", prgname);
   printf("  - timer\n");
   printf("  - displays pdf & cdf\n");
   printf("  - computes simple statistics and dumps to file\n");
   printf("  - logarithmic scale    (not documented)\n");
   printf("  - lines   on 2D slices (not documented)\n");
   printf("  - scaling of 2D slices (not documented)\n\n");
   }

void            show_defaults(int all)                       /*F*/
   {
   printf("Show lines:            ");
   if (world->show_line[0]) printf("Yes\n"); else printf("No\n");
   printf("Compute statistics:    ");
   if (world->comp_stat)    printf("Yes\n"); else printf("No\n");
   printf("Compute quantiles:     ");
   if (world->comp_quant)   printf("Yes\n"); else printf("No\n");
   if (!all) return;
   
   printf("Help file:              %s\n", _HELP_FILE);
   printf("Colormap directory:     %s\n", _CMAP_DIR);
   printf("Colormap default file:  %s\n", _CMAP_DEF);
   printf("Default tmin and tmax:  %g %g\n", T_MIN, T_MAX);
   printf("Perspective angle:      %g degrees\n", ANGLE*57.29577951308);
   printf("Printing window:\n");
   printf("  Fill main title:      "); if (FILL_MAINTITLE) printf("Yes\n");
                                                      else printf("No\n");
   printf("  Fill x and y dir.:    "); if (FILL_XDIR)      printf("Yes  ");
                                                      else printf("No  ");
                                       if (FILL_YDIR)      printf("Yes\n");
                                                      else printf("No\n");
   printf("  Print scale:          "); if (PRINT_SCALE)    printf("Yes\n");
                                                      else printf("No\n");
   printf("  Default orientation:  ");
   if (ORIENTATION_DEF==PORTRAIT) printf("Portrait\n");
                             else printf("Landscape\n");
   printf("  Default x and y size: %d %d\n", XSIZE_DEF, YSIZE_DEF);
   }

void            help(char                *prgname)        /*F*/
   {
   printf("Usage:  %s [-options ...] [filename]\n", prgname);
   printf("Where options include:\n");
   printf("   -h or -help                     help\n");
   printf("   -d                              show defaults\n");
   printf("   -changetrim                     change trimming limits (GSLIB file)\n");
   printf("                   current values: %g %g\n", T_MIN, T_MAX);
   printf("   +/-stat                         compute statistics ?\n");
   printf("   +/-line                         show lines ?\n");
   printf("   +/-quant                        compute quantiles ?\n");
   printf("   -cc   nb                        number of color classes\n");
   printf("   -cmap name                      name of colormap file\n");
   printf("Plus the classical X options:\n");
   printf("   -display host:dpy               X server to contact\n");
   printf("   -geometry geom                  size of the main window\n");
   printf("   -bg color                       background color\n");
   printf("   -fg color                       foreground color\n");
   printf("For a more detailed help, run %s and see the Help menu\n", prgname);
   }

BOOLEAN         isnumber(char          *string)      /*F*/
   {
   int             i;

   for (i = 0; i < strlen(string); i++)
      if (!isspace(string[i]) && string[i]!='.' && string[i]!='-'
            && string[i]!='+' && !isdigit(string[i]))
         return (FALSE);
   return (TRUE);
   }
static void   close_post_cb(Widget           un1,       /*F*/
                            Widget           dialog,    /*F*/
                            XtPointer        un2)       /*F*/
   {
   world->refresh=TRUE;
   XtDestroyWidget(dialog);
   }

/* Possible dialog_type: XmDIALOG_MESSAGE, XmDIALOG_ERROR,
                         XmDIALOG_INFORMATION */
void            PostDialog(Widget          parent,  /*F*/
                           int             dialog_type,  /*F*/
                           char           *title,  /*F*/
                           char           *text,  /*F*/
                           char           *label)       /*F*/
   {
   Widget          dialog;
   XmString        str_title, str_text, str_label;

   world->refresh=FALSE;
   dialog = XmCreateMessageDialog(parent, "dialog", NULL, 0);
   str_title = XmStringCreateSimple(title);
   str_text = XmStringCreateSimple(text);
   str_label = XmStringCreateSimple(label);
   XtVaSetValues(dialog,
                 XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
                 XmNdialogTitle, str_title,
                 XmNmessageString, str_text,
                 XmNokLabelString, str_label,
                 XmNdialogType, dialog_type,
                 NULL);
   XmStringFree(str_title);
   XmStringFree(str_text);
   XmStringFree(str_label);
   XtUnmanageChild(XmMessageBoxGetChild(dialog, XmDIALOG_HELP_BUTTON));
   XtUnmanageChild(XmMessageBoxGetChild(dialog, XmDIALOG_CANCEL_BUTTON));
   XtAddCallback(dialog, XmNokCallback,
                 (XtCallbackProc)close_post_cb, (XtPointer)dialog);

   XtManageChild(dialog);
   }

static void dialog_yes_cb(Widget    dialog,   /*F*/
                          XtPointer un1,      /*F*/
                          XtPointer un2)      /*F*/
   {
   XtUnmanageChild(dialog); XtDestroyWidget(dialog);
   XtDestroyWidget(widgets->top);
   print_mem("before quitting program");
   printf("\nBye\n");
   exit(0);
   }

static void dialog_no_cb(Widget    dialog,    /*F*/
                         XtPointer un1,       /*F*/
                         XtPointer un2)       /*F*/
   {
   world->refresh=TRUE;
   XtUnmanageChild(dialog); XtDestroyWidget(dialog);
   }

void     quit_fn(void)     /* F */
   {
   Widget       dialog;
   XmString     str_title, str_text, str_yes, str_no;

   world->refresh=FALSE;
   str_title=XmStringCreateSimple("Quit Yap");
   str_text=XmStringCreateSimple("              Are you sure?");
   str_yes=XmStringCreateSimple("Definitely");
   str_no=XmStringCreateSimple("No, after all");
   dialog=XmCreateMessageDialog(widgets->top, "yes_no", NULL, 0);
   XtVaSetValues(dialog,
                    XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
                    XmNdialogTitle, str_title,
                    XmNmessageString, str_text,
                    XmNokLabelString, str_yes,
                    XmNcancelLabelString, str_no,
                    XmNdialogType, XmDIALOG_MESSAGE,
                    NULL);
   XmStringFree(str_title);
   XmStringFree(str_text);
   XmStringFree(str_yes);
   XmStringFree(str_no);
   XtUnmanageChild(XmMessageBoxGetChild(dialog, XmDIALOG_HELP_BUTTON));
   XtAddCallback(dialog, XmNokCallback,
                 (XtCallbackProc)dialog_yes_cb, NULL);
   XtAddCallback(dialog, XmNcancelCallback,
                 (XtCallbackProc)dialog_no_cb,  NULL);
   XtManageChild(dialog);
   return;
   }

void    set_timer(float             prop)     /*F*/
   {
   Dimension       width, height;

   XtVaGetValues(widgets->timer_area, XmNwidth, &width,
                 XmNheight, &height, NULL);
   XSetForeground(widgets->dpy, widgets->gc, widgets->black);
   XFillRectangle(widgets->dpy, XtWindow(widgets->timer_area), widgets->gc,
                       0, 0, (int)(prop*width), height);
   XFlush(widgets->dpy);
   }

Widget  CreateTimerForm(Widget          parent)     /*F*/
   {
   Widget    timer_form;

   timer_form = XtVaCreateManagedWidget("timer_form",
                      xmFormWidgetClass, parent,
                      NULL);
   timer_label = XtVaCreateManagedWidget("Ready",
                      xmLabelGadgetClass, timer_form,
                      XmNtopAttachment,         XmATTACH_FORM,
                      XmNbottomAttachment,      XmATTACH_FORM,
                      XmNleftAttachment,        XmATTACH_FORM,
                      NULL);
   widgets->timer_area = XtVaCreateManagedWidget("timer_area",
                      xmDrawingAreaWidgetClass, timer_form,
                      XmNtopAttachment,         XmATTACH_FORM,
                      XmNbottomAttachment,      XmATTACH_FORM,
                      XmNrightAttachment,       XmATTACH_FORM,
                      XmNleftAttachment,        XmATTACH_WIDGET,
                      XmNleftWidget,            timer_label,
                      NULL);
   return(timer_form);
   }

void UpdateDisplay(void)  /*F*/
{
 /*
  * Updates the screen before callbacks that
  * take a lot of CPU.
  */

  XmUpdateDisplay(widgets->top); XFlush(widgets->dpy);
  XmUpdateDisplay(widgets->top); XFlush(widgets->dpy);
}

void  init_timer(char            *title)     /*F*/
   {
   XmString   xs;
   Arg        args[1];

   XClearArea(widgets->dpy, XtWindow(widgets->timer_area), 0, 0, 0, 0, False);
   xs=XmStringCreateSimple(title);
   /*XtVaSetValues(timer_label, XmNlabelString, xs, NULL);*/
   XtSetArg(args[0],   XmNlabelString, xs);
   XtSetValues(timer_label, args, 1);
   XmStringFree(xs);
   UpdateDisplay();
   }

void NewCursor(Widget       w,      /*F*/
               unsigned int shape) /*F*/
/* Examples: XC_left_ptr XC_crosshair XC_watch None(normal)*/
   {
   Cursor newCursor;

   newCursor=XCreateFontCursor(widgets->dpy, shape ) ;
   if (w) XDefineCursor(widgets->dpy, XtWindow(w), newCursor );
   else   XDefineCursor(widgets->dpy, XtWindow(widgets->top), newCursor );
   UpdateDisplay();
   }
