#include "version.h"
#include "xgam.h"
#include "xgam.xbm"
 
Window window;
GC xgc, xorgc;

Display *display;
Widget toplevel,Panel,swindow;
XFontStruct *large_font, *small_font;

#define LARGE_FONT1 "-adobe-courier-bold-r-normal--24-*"
#define SMALL_FONT1 "-adobe-helvetica-medium-r-*-12-*"

#define LARGE_FONT2 "variable"
#define SMALL_FONT2 "variable"

extern void v_enlarge(), v_reduce(), v_maximize();
static XtActionsRec actionsTable [] = {
    {"v_reduce", v_reduce},
    {"v_enlarge", v_enlarge},
    {"v_maximize", v_maximize},
};

main(argc, argv)
int argc;
char *argv[];
{

  Widget Form,StatusW,Logo;
  XmString   logolabel;
  int is;



   toplevel=XtInitialize(argv[0], "Xgam",NULL,0,&argc,argv);

   display=XtDisplay(toplevel);
   init_rowcol();
  
    nargs=0;
    Form = XmCreateForm (toplevel, "form", wargs, nargs);
    XtManageChild(Form);

    nargs=0;
    setarg(XmNwidth, 500);
    setarg(XmNalignment, XmALIGNMENT_BEGINNING);
    setarg(XmNrecomputeSize, False);
    setarg(XmNleftAttachment, XmATTACH_FORM);
    setarg(XmNbottomAttachment, XmATTACH_FORM);
    StatusW = XmCreateLabel(Form, "Status", wargs, nargs);
    XtManageChild(StatusW);
    
    nargs=0;
    setarg(XmNresizePolicy, XmRESIZE_GROW);
    setarg(XmNscrollingPolicy, XmAUTOMATIC);
    setarg(XmNscrollBarDisplayPolicy, XmAS_NEEDED);
    setarg(XmNleftAttachment, XmATTACH_FORM);
    setarg(XmNtopAttachment, XmATTACH_FORM);
    setarg(XmNbottomAttachment, XmATTACH_WIDGET);
    setarg(XmNbottomWidget, StatusW);
    swindow = XmCreateScrolledWindow(Form, "swindow", wargs, nargs);
    XtManageChild(swindow);
    
    XtAddActions(actionsTable, XtNumber(actionsTable));

    /* create right panel */

    nargs=0;
    setarg(XmNtopAttachment, XmATTACH_FORM);
    setarg(XmNbottomAttachment, XmATTACH_FORM);
    setarg(XmNleftAttachment, XmATTACH_WIDGET);
    setarg(XmNleftWidget, swindow);
    setarg(XmNrightAttachment, XmATTACH_FORM);
     Panel=XmCreateForm(Form, "right", wargs, nargs);
    XtManageChild(Panel);

    create_panels(Panel);

    nargs=0;
    setarg(XmNleftAttachment, XmATTACH_FORM);
    setarg(XmNrightAttachment, XmATTACH_FORM);
    logolabel=XmStringCreateLocalized("XGAM3d 1.0");
    setarg(XmNlabelString, logolabel);
    Logo=XmCreateLabel(Panel, "logo", wargs, nargs);
    
    XtManageChild(Logo);


     XtRealizeWidget(toplevel);
     
      {
    Pixmap icon_pixmap = XCreateBitmapFromData(display, 
            XtScreen(toplevel)->root,
            (char *)xgam_bits, xgam_width, xgam_height);
    nargs=0;
    setarg(XtNiconPixmap, icon_pixmap);
    XtSetValues(toplevel, wargs, nargs);
    }
 
    window  = XtWindow(swindow);
    xorgc=create_xor_gc(swindow);
    xgc = DefaultGC(display, DefaultScreen(display));

    large_font=initFont(display, xgc, LARGE_FONT1);
    if (!large_font)
    large_font=initFont(display, xgc, LARGE_FONT2);

    small_font=initFont(display, xgc, SMALL_FONT1);
    if (!small_font)
    small_font=initFont(display, xgc, SMALL_FONT2);

    XSetFont(display, xorgc, small_font->fid);
    

   XtMainLoop();
}

      
      
