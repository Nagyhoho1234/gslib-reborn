#include <Xm/DialogS.h>
#include <Xm/DrawingA.h>
#include <Xm/Form.h>
#include <Xm/LabelG.h>
#include <Xm/PushBG.h>
#include <Xm/RowColumn.h>
#include <Xm/ScrolledW.h>
#include <Xm/SelectioB.h>
#include <Xm/Text.h>
#include <Xm/TextF.h>
#include <Xm/ToggleBG.h>
#include <X11/cursorfont.h>
#include "yaconfig.h"
#include "yap.h"

extern Widgets_t   *widgets;
extern World_t     *world;

extern int      nX[4], nY[4], sX[4], sY[4], coeff[4];
extern BOOLEAN  draw_nb[4];
extern Stat_t   stat_THREED;

static Widget   compute, comp_close, comp_print, comp_win;
static int      x_begin[4], y_begin[4], wid[4];
static int      sum;

static int    (*get_h[4])();

void            winst_label(Widget            un1,    /*F*/
                            int               plane,  /*F*/
                            XEvent           *event)  /*F*/
   {
   BOOLEAN  in;
   int      x_area, class;
   char     str1[STRING1], str2[STRING1];
   XmString xs;
   Arg      args[3];

   x_area=event->xbutton.x;
   class=(int)floor((float)(x_area-x_begin[plane])/wid[plane]);
   if (class<0)                            class= -1;
   else if (class>world->nb_class+1)       class= -2;
        else if (class==world->nb_class+1) class= -3;
   in=TRUE;
   switch(class)
      {
      case     0: sprintf(str1, "<%g", world->cutoffs[0]);               break;
      case    -1: sprintf(str1, "<%g", world->t_min); in=FALSE;          break;
      case    -2: sprintf(str1, ">%g", world->t_max); in=FALSE;          break;
      case    -3: sprintf(str1, ">%g", world->cutoffs[world->nb_class]); break;
      default   : sprintf(str1, "%g to %g", world->cutoffs[class-1],
                                            world->cutoffs[class]);
      }
   if (in) sprintf(str2, "Class %s -> %.2f %% (%d/%d)",
                   str1,
                   (float)world->nbpc[plane][class]/nX[plane]/nY[plane]*100,
                   world->nbpc[plane][class], nX[plane]*nY[plane]);
   else sprintf(str2, "Out");
      
   xs = XmStringCreateSimple(str2);
   XtSetArg(args[0], XmNlabelString, xs);
   XtSetValues(widgets->winst_loc[plane], args, 1);
   XmStringFree(xs);
   }

int      get_h_pdf(int              y,  /*F*/
                   int              h_cl,  /*F*/
                   int              h_max,  /*F*/
                   int              un1)    /*F*/
   {
   return((int)((float)y*h_cl/h_max));
   }

int      get_h_cdf(int              y,  /*F*/
                   int              h_cl,  /*F*/
                   int              un1,    /*F*/
                   int              plane)  /*F*/
   {
   sum+=h_cl;
   return((int)((float)y*sum/nX[plane]/nY[plane]));
   }

void           set_get_hs(void)                         /*F*/
   {
   int         plane;
   for (plane=0; plane<4; plane++) get_h[plane]=get_h_pdf;
   }

void           winst_pdf_cb(Widget          un1,        /*F*/
                            int             plane,      /*F*/
                            XtPointer       un2)        /*F*/
   {
   get_h[plane]=get_h_pdf;
   if (WINST_MANAGED(plane)) draw_stat(plane, (int)SCR_CLEAR, draw_nb[plane]);
   }

void           winst_cdf_cb(Widget          un1,        /*F*/
                            int             plane,      /*F*/
                            XtPointer       un2)        /*F*/
   {
   get_h[plane] = get_h_cdf;
   if (WINST_MANAGED(plane)) draw_stat(plane, (int)SCR_CLEAR, draw_nb[plane]);
   }

void            draw_stat(int       plane,  /*F*/
                          int       device,  /*F*/
                          BOOLEAN   draw_prop)         /*F*/
   {
   Dimension       width, height;
   int             x_draw, y_draw, h;
   unsigned char   class;
   Window          win;
   char            str[STRING1];
   int            *x, *y;

   NewCursor(widgets->winst_area[plane], XC_watch);
   win=XtWindow(widgets->winst_area[plane]);
   if (device==SCR_CLEAR) XClearArea(widgets->dpy, win, 0, 0, 0, 0, False);
   x=(int *)calloc(world->nb_class+2, sizeof(int));
   y=(int *)calloc(world->nb_class+2, sizeof(int));

   XtVaGetValues(widgets->winst_area[plane],
                 XmNwidth,  &width,
                 XmNheight, &height,
                 NULL);

   x_draw  = (int)(0.92*width);
   y_draw  = (int)(0.86*height);
   x_begin[plane] = (int)(0.04*width);
   y_begin[plane] = (int)(0.96*height);
   wid[plane]     = (int)(float)x_draw/(world->nb_class+2);

   sum=0;
   for (class=0; class<world->nb_class+2; class++)
      {
      h=get_h[plane](y_draw, world->nbpc[plane][class], world->nbmax[plane], plane);
      set_color_scr(class);
      x[class]=x_begin[plane]+class*wid[plane];
      y[class]=y_begin[plane]-h;
      fill_rectangle_scr(win, x[class], y[class], wid[plane], h);
      draw_rectangle_scr(win, x[class], y[class], wid[plane], h);
      }

   if (draw_prop)
      for (class=0; class<world->nb_class+2; class++)
         {
         sprintf(str, "%.2f",
                 (float)world->nbpc[plane][class]/nX[plane]/nY[plane]*100);
         if (strcmp(str, "0.00"))
            XDrawString(widgets->dpy, win, widgets->gc, x[class]+2, y[class]-2,
               str, strlen(str));
         }
   
   free(x); free(y);
   NewCursor(widgets->winst_area[plane], XC_left_ptr);
   }

static void  comp_close_cb(Widget          un1,       /*F*/
                           int             un2,       /*F*/
                           XtPointer       un3)       /*F*/
   {
   XtUnmanageChild(compute);
   }

static void  comp_print_cb(Widget          un1,       /*F*/
                           int             un2,       /*F*/
                           XtPointer       un3)       /*F*/
   {
   char  name[STRING1];
   char *text;
   FILE *file;

   if (!widgets->comp_area)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Nothing to print", "Right");
      return;
      }
   text=XmTextGetString(widgets->comp_area);
   sprintf(name, "%s.stat", world->base);
   file=fopen(name, "w");
   if (!file)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Couldn't open file", "Strange");
      return;
      }
   fprintf(file, text); fclose(file);
   XtFree(text);
   sprintf(name, "%s written", name);
   PostDialog(widgets->top, XmDIALOG_INFORMATION, "Dump successful",
              name, "Right");
   }

void   display_info(Widget        area)  /*F*/
   {
   XmTextSetString(area, "");
   p_area(area, "                   General information\n");
   p_area(area, "**********************************************************\n");
   p_area(area, "File:            %s\nFormat:          ", world->name);
   switch(world->type)
      {
      case FBINARY: p_area(area, "float    BINARY\n"); break;
      case CBINARY: p_area(area, "char     BINARY\n"); break;
      case STEVE:   p_area(area, "STEVE\n");           break;
      case GSLIB:   p_area(area, "standard GSLIB\n");  break;
      case EXTGSL:  p_area(area, "extended GSLIB\n");  break;
      }
   p_area(area, "Title:           %s\n", world->title);
   p_area(area, "Variable:        %s\n", world->var_name);
   p_area(area, "Size:            %d x %d x %d\n",
                world->n[X], world->n[Y], world->n[Z]);
   p_area(area, "Trimming limits: %g %g\n", world->t_min, world->t_max);
   p_area(area, "Showing limits:  %g %g\n", world->show_min, world->show_max);
   }

static void  display_stat(Widget           area,     /*F*/
                          Stat_t           statval)  /*F*/
   {
   p_area(area, "\n            %s\n", statval.name);
   p_area(area, "*********************************************\n");
   p_area(area, "Number:          %d\n", statval.nb);
   p_area(area, "Mean:            ");
   if (statval.nb)
      p_area(area, "%g\n", statval.mean);
   else
      p_area(area, "undefined\n\n");

   p_area(area, "Std. dev.:       %g\n", statval.std_dev);

   p_area(area, "Coeff. of var:   ");
   if (statval.coef_var<0)
      p_area(area, "undefined\n\n");
   else
      p_area(area, "%g\n\n", statval.coef_var);
   p_area(area, "Minimum:         %g\n", statval.min);
   if (world->comp_quant)
      {
      p_area(area, "Lower quartile:  %g\n", statval.lower_q);
      p_area(area, "Median:          %g\n", statval.median);
      p_area(area, "Upper quartile:  %g\n", statval.upper_q);
      }
   p_area(area, "Maximum:         %g\n", statval.max);
   }

static void create_comp(void)                   /*F*/
   {
   Arg    args[12];
   char   title[STRING1];
   Widget comp_butt;

   strcpy(title, "Statistics");

   compute = XtVaCreatePopupShell("comp_win",
           xmDialogShellWidgetClass, widgets->top,
           XmNmwmFunctions,          30,
           XmNtitle,                 title,
           NULL);

   comp_win = XtVaCreateWidget("comp_win",
                   xmFormWidgetClass,      compute,
                   XmNtopAttachment,       XmATTACH_FORM,
                   XmNbottomAttachment,    XmATTACH_FORM,
                   XmNleftAttachment,      XmATTACH_FORM,
                   XmNrightAttachment,     XmATTACH_FORM,
                   NULL);

   comp_butt = XtVaCreateManagedWidget("comp_butt",
                   xmRowColumnWidgetClass, comp_win,
                   XmNnumColumns,          1,
                   XmNpacking,             XmPACK_COLUMN,
                   XmNorientation,         XmHORIZONTAL,
                   XmNbottomAttachment,    XmATTACH_FORM,
                   XmNleftAttachment,      XmATTACH_FORM,
                   XmNrightAttachment,     XmATTACH_FORM,
                   NULL);

   comp_close = XtVaCreateManagedWidget("Close",
                   xmPushButtonGadgetClass, comp_butt,
                   NULL);

   comp_print = XtVaCreateManagedWidget("Dump to file",
                   xmPushButtonGadgetClass, comp_butt,
                   NULL);

   XtSetArg(args[0], XmNeditable,         False);
   XtSetArg(args[1], XmNeditMode,         XmMULTI_LINE_EDIT);
   XtSetArg(args[2], XmNscrollingPolicy,  XmAUTOMATIC);
   XtSetArg(args[3], XmNtopAttachment,    XmATTACH_FORM);
   XtSetArg(args[4], XmNleftAttachment,   XmATTACH_FORM);
   XtSetArg(args[5], XmNrightAttachment,  XmATTACH_FORM);
   XtSetArg(args[6], XmNbottomAttachment, XmATTACH_WIDGET);
   XtSetArg(args[7], XmNbottomWidget,     comp_butt);
   widgets->comp_area = XmCreateScrolledText(comp_win, "comp_msg", args, 8);

   XtAddCallback(comp_close, XmNactivateCallback,
                 (XtCallbackProc)comp_close_cb, NULL);
   XtAddCallback(comp_print, XmNactivateCallback,
                 (XtCallbackProc)comp_print_cb, NULL);
   XtManageChild(widgets->comp_area);
   XtManageChild(comp_win);
   display_info(widgets->comp_area);
   }

void   comp_cb(Widget                un1,    /*F*/
               int                   plane,  /*F*/
               XtPointer             un2)    /*F*/
   {
   if (!widgets->comp_area)
      create_comp();
   XtManageChild(compute);
   if (plane<3) display_stat(widgets->comp_area, compute_stat(plane));
           else display_stat(widgets->comp_area, stat_THREED);
   }
