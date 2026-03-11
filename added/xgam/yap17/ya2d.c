
#include <Xm/DrawingA.h>
#include <Xm/SelectioB.h>
#include <Xm/DialogS.h>
#include <Xm/Form.h>
#include <Xm/RowColumn.h>
#include <Xm/LabelG.h>
#include <Xm/TextF.h>
#include <Xm/PushBG.h>
#include <Xm/ToggleB.h>
#include <Xm/ToggleBG.h>
#include <X11/cursorfont.h>
#include "yaconfig.h"
#include "yap.h"
#include "NXHelp.h"

extern Widgets_t *widgets;
extern World_t   *world;

static int      x_offset, y_offset, x_begin[3], y_begin[3];
static int      x_size, y_size, x_pix_size[3], y_pix_size[3];
static int      print_scale, print_mode, showpage;
static float    line_width, yoverx, psscale;
static Widget   psfile_w;

static void   (*set_color) ();

int             nX[4], nY[4], sX[4], sY[4], coeff[4];

static Widget   print_txt[7];
static FILE    *psfile;
static char     title[3][STRING1];
static int      scale_mode;
static Widget   scale_mode_w, scale_txt;

static void   scale_mode_cb(Widget                        un1,    /*F*/
                            int                           which,  /*F*/
                            XmToggleButtonCallbackStruct *un2)    /*F*/
   {
   scale_mode=which;
   }

static void   scale_set_cb(Widget                         un1,    /*F*/
                           int                            plane,  /*F*/
                           XtPointer                      un2)    /*F*/
   {
   if (scale_mode==RATIO_MODE)
      {
      char *name;
      name=XmTextFieldGetString(scale_txt);
      world->scaling[plane]=atof(name);
      XtFree(name);
      }
   else
      world->scaling[plane]=0;
   XtDestroyWidget(scale_mode_w);
   MySetSensitive((int)B_SCALE, plane, True);
   draw_plane(plane, (int)SCR_CLEAR);
   }

void   scale_cb(Widget                         w,      /*F*/
                int                            plane,  /*F*/
                XtPointer                      un1)    /*F*/
   {
   char       cstr[STRING1];
   Widget     scale_form, scale_rowc_frame, scale_rowc;
   Widget     scale_toggle, scale_toggle_ratio, scale_toggle_follow;
   Widget     scale_ok, scale_misc;

   XtSetSensitive(w, False);
   scale_mode_w=XtVaCreatePopupShell("Scaling mode",
              xmDialogShellWidgetClass, widgets->top,
              XmNmwmFunctions,          30,
              XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
              XmNdialogTitle, "Scaling mode",
              NULL);

   scale_form=XtVaCreateWidget("scale_form",
                                  xmFormWidgetClass, scale_mode_w,
                                  NULL);

   scale_rowc_frame=XtVaCreateWidget("scale_frame",
                                  xmFrameWidgetClass, scale_form,
                                  XmNtopAttachment, XmATTACH_FORM,
                                  XmNleftAttachment, XmATTACH_FORM,
                                  XmNrightAttachment, XmATTACH_FORM,
                                  NULL);

   scale_rowc=XtVaCreateWidget("scale_rowc",
                                 xmRowColumnWidgetClass, scale_rowc_frame,
                                 XmNpacking, XmPACK_COLUMN,
                                 XmNnumColumns, 2,
                                 XmNorientation, XmVERTICAL,
                                 XmNisAligned, True,
                                 NULL);

   scale_toggle=XmCreateRadioBox(scale_rowc,
                                 "scale_toggle", NULL, 0);

   switch (plane)
      {
      case X: sprintf(cstr, "Constant ratio z/y ="); break;
      case Y: sprintf(cstr, "Constant ratio z/x ="); break;
      case Z: sprintf(cstr, "Constant ratio y/x ="); break;
      }

   scale_toggle_ratio=XtVaCreateManagedWidget(cstr,
                               xmToggleButtonGadgetClass, scale_toggle,
                               NULL);

   scale_toggle_follow=XtVaCreateManagedWidget("Maximum size",
                               xmToggleButtonGadgetClass, scale_toggle,
                               NULL);

   scale_misc=XtVaCreateManagedWidget("scale_misc",
                                  xmFormWidgetClass, scale_rowc,
                                  NULL);

   scale_txt=XtVaCreateManagedWidget("scale_txt",
                               xmTextFieldWidgetClass, scale_misc,
                               XmNrows,                1,
                               XmNleftAttachment, XmATTACH_FORM,
                               XmNrightAttachment, XmATTACH_FORM,
                               XmNtopAttachment, XmATTACH_FORM,
                               NULL);

   scale_ok=XtVaCreateManagedWidget("OK",
                                   xmPushButtonGadgetClass, scale_misc,
                                   /*xmPushButtonGadgetClass, scale_form,*/
                                   XmNtopAttachment, XmATTACH_WIDGET,
                                   XmNtopWidget, scale_txt,
                                   XmNleftAttachment, XmATTACH_FORM,
                                   XmNrightAttachment, XmATTACH_FORM,
                                   XmNbottomAttachment, XmATTACH_FORM,
                                   NULL);
   if (world->scaling[plane])
      {
      sprintf(cstr, "%11.5f", world->scaling[plane]);
      XtVaSetValues(scale_txt, XmNvalue, cstr, NULL);
      XmToggleButtonSetState(scale_toggle_ratio, True, True);
      }
   else
      XmToggleButtonSetState(scale_toggle_follow, True, True);
   XtAddCallback(scale_toggle_ratio, XmNvalueChangedCallback,
                 (XtCallbackProc)scale_mode_cb, (XtPointer)RATIO_MODE);
   XtAddCallback(scale_toggle_follow, XmNvalueChangedCallback,
                 (XtCallbackProc)scale_mode_cb, (XtPointer)FOLLOW_MODE);
   XtAddCallback(scale_ok, XmNactivateCallback,
                 (XtCallbackProc)scale_set_cb, (XtPointer)plane);

   XtManageChild(scale_toggle);
   XtManageChild(scale_rowc);
   XtManageChild(scale_rowc_frame);
   XtManageChild(scale_form);
   XtManageChild(scale_mode_w);
   }

static void     write_header(int              plane,  /*F*/
                             int              x_o,    /*F*/
                             int              y_o,    /*F*/
                             int              x_s,    /*F*/
                             int              y_s)    /*F*/
   {
   int             i;
   char            d;
   float           gray;

   x_offset=x_o; y_offset=y_o;
   x_size=x_s; y_size=y_s;

   switch (plane)
     { case X: d='X'; break;
       case Y: d='Y'; break;
       case Z: d='Z'; break; }
   p_area(widgets->debug_area, "POST -> - Writting header\n");
   fprintf(psfile, "%%!PS-Adobe-2.0 EPSF 1.2\n");
   fprintf(psfile, "%%%%Title: 2D slice in %s, %c constant\n",
           world->title, d);
   fprintf(psfile, "%%%%Creator: Yap v. ");
   fprintf(psfile, VERSION);
   fprintf(psfile, "\n");
   fprintf(psfile, "%%%%CreationDate: 12:00:00 11-30-66\n");
   fprintf(psfile, "%%%%BoundingBox: %d %d %d %d\n",
           x_offset, y_offset, x_size, y_size);
   fprintf(psfile, "%%%%EndComments\n");

   fprintf(psfile, "\n%%Some definitions\n");
   fprintf(psfile, "/rtext{ dup stringwidth pop -1 div 0 rmoveto show } def\n");
   fprintf(psfile, "/ctext{ dup stringwidth pop -2 div 0 rmoveto show } def\n");
   fprintf(psfile, "/ltext{show} def\n");
   fprintf(psfile, "\n%%Color definitions\n");
   fprintf(psfile, "/color {systemdict /colorimage known} def\n");
   fprintf(psfile, "%%To force black&white printing on a color device,\n");
   fprintf(psfile, "%%uncomment the next line\n");
   fprintf(psfile, "%% /color false def\n");
   fprintf(psfile,
        "/C { color {pop setrgbcolor} {setgray pop pop pop} ifelse} def\n");
   fprintf(psfile, "/C%d {%g %g %g %g C} def\n",
           0, world->color[0].r, world->color[0].g, world->color[0].b, 1.);
   for (i = 1; i < world->nb_class + 2; i++)
      {
      gray = 1. - (float) (i - 1) / (float) (world->nb_class - 1);
      fprintf(psfile, "/C%d {%g %g %g %g C} def\n",
          i, world->color[i].r, world->color[i].g, world->color[i].b, gray);
      }
   fprintf(psfile, "/C%d {%g %g %g %g C} def\n",
           i, world->color[world->nb_class + 1].r,
           world->color[world->nb_class + 1].g,
           world->color[world->nb_class + 1].b, 1.);
   fprintf(psfile, "\n%%Fill rectangle and draw rectangle\n");
   fprintf(psfile, "/F {moveto lineto lineto lineto closepath fill} def\n");
   fprintf(psfile, "/L {moveto lineto lineto lineto closepath stroke} def\n");

   fprintf(psfile, "\n%g %g scale\n", psscale, psscale);

   if (print_mode==LANDSCAPE)
      { p_area(widgets->debug_area, "POST -> - Mode: LANDSCAPE\n");
        fprintf(psfile, "\n90 rotate\n0 -600 translate\n"); }
   else
      p_area(widgets->debug_area, "POST -> - Mode: PORTRAIT\n");
   fprintf(psfile, "\n%g %g translate\n", x_offset, y_offset);
   fprintf(psfile, "\n%%Starting of the DRAWING\n");
   }

static void     set_color_ps(int         class)        /*F*/
   {
   fprintf(psfile, "C%d\n", class);
   }

static void     fill_rectangle_ps(Window         un1,  /*F*/
                                  int            x,    /*F*/
                                  int            y,    /*F*/
                                  int            dx,   /*F*/
                                  int            dy)   /*F*/
   {
   fprintf(psfile, "%d %d %d %d %d %d %d %d F\n",
           x, y, x+dx, y, x+dx, y+dy, x, y+dy);
   }

static void     draw_string_ps(int           angle,      /*F*/
                               int           x,          /*F*/
                               int           y,          /*F*/
                               char         *font_type,  /*F*/
                               float         font_size,  /*F*/
                               char          alignment,  /*F*/
                               char         *str)        /*F*/
   {
   fprintf(psfile, "/Helvetica%s findfont %g scalefont setfont\n",
           font_type, font_size);
   fprintf(psfile, "%d %d moveto\n", x, y);
   if (angle)
      fprintf(psfile, "%d rotate\n", angle);
   fprintf(psfile, "(%s) %ctext\n", str, alignment);
   if (angle)
      fprintf(psfile, "%d rotate\n", -angle);
   }

static void     draw_rectangle_ps(Window          un1,  /*F*/
                                  int             x,    /*F*/
                                  int             y,    /*F*/
                                  int             dx,   /*F*/
                                  int             dy)   /*F*/
   {
   fprintf(psfile, "%g setlinewidth\n", line_width);
   fprintf(psfile, "0 0 0 setrgbcolor\n");
   fprintf(psfile, "%d %d %d %d %d %d %d %d L\n",
           x, y, x+dx, y, x+dx, y+dy, x, y+dy);
   }

static void     draw_scale_ps(int                 x,     /*F*/
                              int                 y,     /*F*/
                              int                 w,     /*F*/
                              int                 h,     /*F*/
                              int                 draw)  /*F*/
   {
   int             i, height;
   int             step_pos;
   float           sy, val;
   char            str[STRING1];
   char            format[20];

   p_area(widgets->debug_area, "POST -> - Printing color scale\n");
   fprintf(psfile, "\n%% Beginning of the SCALE\n");
   sy=(float)(h-2)/(world->nb_class+2);
   height=h;

   if (world->type==CBINARY
    && world->nb_class==world->show_max-world->show_min+1
    && world->mode==ARITHMETIC)
      {
      for (i=1; i<world->nb_class+1; i++)
         {
         val=world->cutoffs[i];
         sprintf(str, "%d", (int)floor(val));
         draw_string_ps(0, x+w+2, (int)(y+(i+.5)*sy),
                        "", (float)(0.02*draw), 'l', str);
         }
      }
   else
      {
      step_pos=(int)ceil((float)world->nb_class/MMIN(world->nb_class, NB_LABEL));
      sprintf(format, "%%.%df",
              MMAX(0, (int)(3-floor(log10(world->show_max-world->show_min)))));
   
      for (i=0; i<world->nb_class; i+=step_pos)
         {
         val = world->cutoffs[i];
         sprintf(str, format, val);
         draw_string_ps(0, x+w+2, (int)(y+(i+1)*sy),
                        "", (float)(0.02*draw), 'l', str);
         }
      sprintf(str, format, world->show_max);
      draw_string_ps(0, x + w + 2, (int) (y + (world->nb_class + 1) * sy),
                     "", (float)(0.02*draw), 'l', str);
      }

   for (i=0; i<world->nb_class+2; i++)
      {
      set_color_ps(i);
      fill_rectangle_ps(NULL, x, (int)(y+sy*i), w, (int)ceil(sy));
      }
   draw_rectangle_ps(NULL, x, y - 1, w, height);
   fprintf(psfile, "\n%% End of the SCALE\n\n");
   }

static void     close_psfile(char       *name)  /*F*/
   {
   char         cstr[STRING1];
   p_area(widgets->debug_area, "POST -> Closing postscript file\n");
   if (print_mode == LANDSCAPE)
      fprintf(psfile, "0 600 translate\n-90 rotate\n");

   fprintf(psfile, "\n%g %g scale\n", 1/psscale, 1/psscale);

   fprintf(psfile, "\n%% End of the %s\n\n", world->title);
   if (showpage)
     { fprintf(psfile, "showpage\n");
       sprintf(cstr, "File %s written", name); }
   else { sprintf(cstr, "File %s written (GSLIB format, no showpage)", name); }
   PostDialog(widgets->top, XmDIALOG_INFORMATION, "Print successful",
              cstr, "Right");
   fclose(psfile);
   }

static void  psfile_toggle_mode_cb(Widget                        un1,    /*F*/
                                   int                           which,  /*F*/
                                   XmToggleButtonCallbackStruct *un2)    /*F*/
   {
   char           *field;
   char            cstr[STRING1];
   int             x, y;

   if (which != print_mode)
      {
      field=XmTextFieldGetString(print_txt[5]);
      sscanf(field, "%d%d", &x, &y);
      if (x && y)
         {
         sprintf(cstr, "%d %d", y, x);
         XtVaSetValues(print_txt[5] , XmNvalue, cstr, NULL);
         }
      XtFree(field);
      }
   print_mode = which;
   }

static void psfile_toggle_scale_cb(Widget                        un1,    /*F*/
                                   int                           which,  /*F*/
                                   XmToggleButtonCallbackStruct *un2)    /*F*/
   {
   print_scale = which;
   }

static void     psfile_cancel_cb(Widget                  un1,          /*F*/
                                 XtPointer               un2,          /*F*/
                                 XtPointer               un3)          /*F*/
   {
   p_area(widgets->debug_area, "POST -> Printing cancelled\n");
   XtDestroyWidget(psfile_w);
   }

static void     psfile_print_cb(Widget                   un1,          /*F*/
                                int                      plane,        /*F*/
                                XtPointer                un2)          /*F*/
   {
   char           *name;
   char           *cstr[4];
   char            msg[STRING1];
   int             i, j;

   name = XmTextFieldGetString(print_txt[0]); /* File name */
   if (!strlen(name))
      {
      p_area(widgets->debug_area, "POST -> No postscript file name\n");
      return;
      }
   psfile = fopen(name, "w");
   if (!psfile)
      {
      sprintf(msg, "Cannot write to file %s", name);
      PostDialog(widgets->top, XmDIALOG_ERROR, "Output file", msg, "   OK   ");
      p_area(widgets->debug_area,
             "POST -> Couldn't open postscript file %s\n", name);
      XtFree(name);
      XtDestroyWidget(psfile_w);
      return;
      }
   p_area(widgets->debug_area, "POST -> Opening postscript file %s\n", name);
   for (i=1; i<4; i++)
      {
      cstr[i] = XmTextFieldGetString(print_txt[i]);
      strcpy(title[i-1], cstr[i]);
      free(cstr[i]);
      }

   for (i=4; i<7; i++)
      {
      cstr[i-4]=XmTextFieldGetString(print_txt[i]);
      if (!strlen(cstr[i-4]))
         { for (j=4; j<i; j++) free(cstr[j-4]);
           free(name); return; }
      }

   if (sscanf(cstr[0], "%d%d", &x_offset, &y_offset)!=2
    || sscanf(cstr[1], "%d%d", &x_size, &y_size)!=2
    || sscanf(cstr[2], "%g", &yoverx)!=1)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please check that you entered numbers!", "Let's see");
      for (i=0; i<3; i++) free(cstr[i]);
      free(name);
      return;
      }
   for (i=0; i<3; i++) free(cstr[i]);

   if (!x_size || !y_size)
      { x_offset=0; y_offset=0; psscale=.24; showpage=FALSE; }
   else
      {
      double ratio=MMIN((float)x_size/1143, (float)y_size/954);
      showpage=TRUE;
      psscale=ratio/437*1143;
      }
   x_size=1143; y_size=954;
   if (!yoverx) yoverx=1;
   XtDestroyWidget(psfile_w);
   write_header(plane, x_offset, y_offset, x_size, y_size);
   draw_plane(plane, (int)PSFILE);
   close_psfile(name);
   free(name);
   return;
   }

void            print_win2d(Widget              un1,    /*F*/
                            int                 plane,  /*F*/
                            XtPointer           un2)    /*F*/
   {
   char            cstr[STRING1];
   char            axis[6];
   XmString        str = XmStringCreateSimple("Postscript output");
   Widget          psfile_form, psfile_frame, psfile_label_rowc;
   Widget          psfile_lbl[9], psfile_toggle_scale, psfile_toggle_scale_on;
   Widget          psfile_toggle_scale_off, psfile_button, psfile_print;
   Widget          psfile_cancel, psfile_help, psfile_toggle_mode;
   Widget          psfile_toggle_mode_po, psfile_toggle_mode_ls;

   strcpy(axis, "yxxzzy");
   psfile_w = XtVaCreatePopupShell("Postscript output",
                                   xmDialogShellWidgetClass, widgets->top,
              XmNmwmFunctions,          30,
                            XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
                                   XmNdialogTitle, str,
                                   NULL);

   psfile_frame = XtVaCreateWidget("psfile_frame",
                                   xmFrameWidgetClass, psfile_w,
                                   NULL);
   psfile_form = XtVaCreateManagedWidget("psfile_form",
                                         xmFormWidgetClass, psfile_frame,
                                         XmNbottomAttachment, XmATTACH_FORM,
                                         XmNtopAttachment, XmATTACH_FORM,
                                         XmNleftAttachment, XmATTACH_FORM,
                                         XmNrightAttachment, XmATTACH_FORM,
                                         NULL);

   psfile_label_rowc = XtVaCreateWidget("psfile_label_rowc",
                                  xmRowColumnWidgetClass, psfile_form,
                                  XmNpacking, XmPACK_COLUMN,
                                  XmNnumColumns, 11,
                                  XmNorientation, XmHORIZONTAL,
                                  XmNisAligned, True,
                                  XmNtopAttachment, XmATTACH_FORM,
                                  XmNleftAttachment, XmATTACH_FORM,
                                  XmNrightAttachment, XmATTACH_FORM,
                                  NULL);

   sprintf(cstr, "%s_%c%c.ps", world->base, axis[plane], axis[plane+3]);
   psfile_lbl[0] = XtVaCreateManagedWidget("File name: ",
                                  xmLabelGadgetClass, psfile_label_rowc,
                                  NULL);
   print_txt[0] = XtVaCreateManagedWidget("file_name",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                  XmNvalue, cstr,
                                  NULL);
   psfile_lbl[1] = XtVaCreateManagedWidget("Main title: ",
                                  xmLabelGadgetClass, psfile_label_rowc,
                                  NULL);
   if (FILL_MAINTITLE) strcpy(cstr, world->title);
   else                sprintf(cstr, "");
   print_txt[1] = XtVaCreateManagedWidget("main_title",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                  XmNvalue, cstr,
                                  NULL);
   psfile_lbl[2] = XtVaCreateManagedWidget("x axis title: ",
                                  xmLabelGadgetClass, psfile_label_rowc,
                                  NULL);
   if (FILL_XDIR) sprintf(cstr, "%c direction", axis[plane]);
   else           strcpy(cstr, "");
   print_txt[2] = XtVaCreateManagedWidget("xaxis_title",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                  XmNvalue, cstr,
                                  NULL);
   psfile_lbl[3] = XtVaCreateManagedWidget("y axis title: ",
                                  xmLabelGadgetClass, psfile_label_rowc,
                                  NULL);
   if (FILL_XDIR) sprintf(cstr, "%c direction", axis[plane+3]);
   else           strcpy(cstr, "");
   print_txt[3] = XtVaCreateManagedWidget("yaxis_title",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                  XmNvalue, cstr,
                                  NULL);
   sprintf(cstr, "%d %d", 50, 50);
   psfile_lbl[4] = XtVaCreateManagedWidget("Offset x and y: ",
                                      xmLabelGadgetClass, psfile_label_rowc,
                                           NULL);
   print_txt[4] = XtVaCreateManagedWidget("offset",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                         XmNvalue, cstr,
                                         NULL);
   sprintf(cstr, "%d %d", XSIZE_DEF, YSIZE_DEF);
   psfile_lbl[5] = XtVaCreateManagedWidget("Size x and y: ",
                                      xmLabelGadgetClass, psfile_label_rowc,
                                      NULL);
   print_txt[5] = XtVaCreateManagedWidget("x_size",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                  XmNvalue, cstr,
                                  NULL);
   switch (plane)
      {
      case X: sprintf(cstr, "z/y ratio: "); break;
      case Y: sprintf(cstr, "z/x ratio: "); break;
      case Z: sprintf(cstr, "y/x ratio: "); break;
      }
   psfile_lbl[6] = XtVaCreateManagedWidget(cstr,
                                      xmLabelGadgetClass, psfile_label_rowc,
                                      NULL);
   if (world->scaling[plane])
      sprintf(cstr, "%g", world->scaling[plane]);
   else
      sprintf(cstr, "1");
   print_txt[6] = XtVaCreateManagedWidget("yoverx",
                                  xmTextFieldWidgetClass, psfile_label_rowc,
                                  XmNvalue, cstr,
                                  NULL);

   psfile_lbl[7] = XtVaCreateManagedWidget("Scale: ",
                                      xmLabelGadgetClass, psfile_label_rowc,
                                      NULL);
   psfile_toggle_scale = XmCreateRadioBox(psfile_label_rowc,
                                    "psfile_toggle_scale", NULL, 0);
   XtVaSetValues(psfile_toggle_scale, XmNorientation, XmHORIZONTAL, NULL);
   psfile_toggle_scale_on = XtVaCreateManagedWidget("ON",
                                 xmToggleButtonGadgetClass, psfile_toggle_scale,
                                 NULL);
   psfile_toggle_scale_off = XtVaCreateManagedWidget("OFF",
                                 xmToggleButtonGadgetClass, psfile_toggle_scale,
                                 NULL);

   psfile_lbl[8] = XtVaCreateManagedWidget("Orientation: ",
                                      xmLabelGadgetClass, psfile_label_rowc,
                                      NULL);
   psfile_toggle_mode = XmCreateRadioBox(psfile_label_rowc,
                                    "psfile_toggle_mode", NULL, 0);
   XtVaSetValues(psfile_toggle_mode, XmNorientation, XmHORIZONTAL, NULL);
   psfile_toggle_mode_po = XtVaCreateManagedWidget("Portrait",
                                 xmToggleButtonGadgetClass, psfile_toggle_mode,
                                 NULL);
   psfile_toggle_mode_ls = XtVaCreateManagedWidget("Landscape",
                                 xmToggleButtonGadgetClass, psfile_toggle_mode,
                                 NULL);

   psfile_button = XtVaCreateManagedWidget("psfile_button",
                                        xmRowColumnWidgetClass, psfile_form,
                                        XmNtopAttachment, XmATTACH_WIDGET,
                                        XmNtopWidget, psfile_label_rowc,
                                        XmNleftAttachment, XmATTACH_FORM,
                                        XmNrightAttachment, XmATTACH_FORM,
                                        XmNnumColumns, 1,
                                        XmNorientation, XmHORIZONTAL,
                                        NULL);
   psfile_print = XtVaCreateManagedWidget("Print",
                                     xmPushButtonGadgetClass, psfile_button,
                                     NULL);
   psfile_cancel = XtVaCreateManagedWidget("Cancel",
                                     xmPushButtonGadgetClass, psfile_button,
                                     NULL);
   psfile_help = XtVaCreateManagedWidget("Help",
                                     xmPushButtonGadgetClass, psfile_button,
                                     NULL);

   XtAddCallback(psfile_toggle_mode_po, XmNvalueChangedCallback,
                 (XtCallbackProc)psfile_toggle_mode_cb, (XtPointer) PORTRAIT);
   XtAddCallback(psfile_toggle_mode_ls, XmNvalueChangedCallback,
                 (XtCallbackProc)psfile_toggle_mode_cb, (XtPointer) LANDSCAPE);
   if (ORIENTATION_DEF==PORTRAIT) 
      XmToggleButtonSetState(psfile_toggle_mode_po, True, False);
   else
      XmToggleButtonSetState(psfile_toggle_mode_ls, True, False);

   XtAddCallback(psfile_toggle_scale_on, XmNvalueChangedCallback,
                 (XtCallbackProc)psfile_toggle_scale_cb, (XtPointer) TRUE);
   XtAddCallback(psfile_toggle_scale_off, XmNvalueChangedCallback,
                 (XtCallbackProc)psfile_toggle_scale_cb, (XtPointer) FALSE);
   if (PRINT_SCALE)
      XmToggleButtonSetState(psfile_toggle_scale_on, True, False);
   else
      XmToggleButtonSetState(psfile_toggle_scale_off, True, False);

   XtAddCallback(psfile_cancel, XmNactivateCallback,
                 (XtCallbackProc)psfile_cancel_cb, NULL);
   XtAddCallback(psfile_print, XmNactivateCallback,
                 (XtCallbackProc)psfile_print_cb, (XtPointer) plane);
   XtAddCallback(psfile_help, XmNactivateCallback,
                 (XtCallbackProc)XnHelpCB, "Print");
   print_scale = PRINT_SCALE;
   print_mode  = ORIENTATION_DEF;
   XtManageChild(psfile_label_rowc);
   XtManageChild(psfile_toggle_mode);
   XtManageChild(psfile_toggle_scale);
   XtManageChild(psfile_frame);
   XtManageChild(psfile_w);
   XtPopup(XtParent(psfile_w), XtGrabNone);
   }

void            init_2d_indexes(void)         /*F*/
/* We'll also initialize some 3d values used in 3D stat */
   {
   int          plane;

   nX[YZ]    =world->n[Y]; nY[YZ]    =world->n[Z];
   nX[XZ]    =world->n[X]; nY[XZ]    =world->n[Z];
   nX[XY]    =world->n[X]; nY[XY]    =world->n[Y];
   nX[THREED]=world->n[Z]; nY[THREED]=world->n[X]*world->n[Y];

   sX[YZ]=world->n[X];                 sY[YZ]=world->n[X]*world->n[Y];
   sX[XZ]=1;                           sY[XZ]=world->n[X]*world->n[Y];
   sX[XY]=1;                           sY[XY]=world->n[X];
   sX[THREED]=world->n[X]*world->n[Y]; sY[THREED]=1;

   coeff[YZ]=1; coeff[XZ]=world->n[X];
   coeff[XY]=world->n[X]*world->n[Y];
   coeff[THREED]=1;
   world->sld[THREED]=0;
   if (world->nbpc[0])
      for (plane=0; plane<4; plane++) /* Remember: 3 is for 3D stat */
         free(world->nbpc[plane]);
   for (plane=0; plane<4; plane++)
      world->nbpc[plane]=CALLOC(world->nb_class+2, int);
   }

void            draw_rectangle_scr(Window               win,  /*F*/
                                   int                  x,  /*F*/
                                   int                  y,  /*F*/
                                   int                  dx,  /*F*/
                                   int                  dy)  /*F*/
   {
   XSetForeground(widgets->dpy, widgets->gc, widgets->black);
   if (dy<0) { y+=dy; dy*= -1; }
   if (dx<0) { x+=dx; dx*= -1; }
   XDrawRectangle(widgets->dpy, win, widgets->gc, x, y, dx, dy);
   }

void            fill_rectangle_scr(Window               win, /*F*/
                                   int                  x,   /*F*/
                                   int                  y,   /*F*/
                                   int                  dx,  /*F*/
                                   int                  dy)  /*F*/
   {
   XFillRectangle(widgets->dpy, win, widgets->gc, x, y, dx, dy);
   }

void            set_color_scr(int                       class)  /*F*/
   {
   XSetForeground(widgets->dpy, widgets->gc, widgets->pixels[class]);
   }

void            draw_plane(int                          plane,  /*F*/
                           int                          device) /*F*/
   {
   Dimension       width, height;
   int             x_draw, y_draw;
   int             draw, x_scale, y_scale, dx_scale, dy_scale;
   int             x_mtitle, y_mtitle, x_xtitle, y_xtitle, x_ytitle, y_ytitle;
   int             i, j;
   unsigned char class;
   int             direction, idx_beg;
   void            (*draw_rectangle) ();
   void            (*fill_rectangle) ();
   Window          win;

   NewCursor(widgets->win2d_area[plane], XC_watch);
   win = XtWindow(widgets->win2d_area[plane]);

   switch (device)
      {
   case PSFILE:
      direction = 1;
      width = x_size * 0.735;
      height = y_size * 0.88;
      x_pix_size[plane] = (int)MMIN((float)width  / nX[plane],
                                   (float)height / nY[plane] / yoverx);
      y_pix_size[plane] = (int)((float)x_pix_size[plane] * yoverx);
      width  = x_pix_size[plane] * nX[plane];
      height = y_pix_size[plane] * nY[plane];
      x_draw = width / 0.735;
      y_draw = height / 0.88;
      draw = MMAX(x_draw, y_draw);
      x_begin[plane] = draw * 0.04;
      y_begin[plane] = draw * 0.04;
      x_mtitle = x_begin[plane] + width / 2;
      y_mtitle = y_begin[plane] + height + draw * 0.01;
      x_xtitle = x_begin[plane] + width / 2;
      y_xtitle = draw * 0.01;
      x_ytitle = x_begin[plane] - draw * 0.01;
      y_ytitle = y_begin[plane] + height / 2;
      line_width = draw * 0.002;
      x_scale = x_draw * 0.83;
      y_scale = y_begin[plane];
      dx_scale = draw * 0.07;
      dy_scale = height;

      set_color = set_color_ps;
      fill_rectangle = fill_rectangle_ps;
      draw_rectangle = draw_rectangle_ps;
      p_area(widgets->debug_area, "POST -> - Writting slice\n");
      break;
   case SCR_CLEAR:
      XClearArea(widgets->dpy, XtWindow(widgets->win2d_area[plane]), 0, 0, 0, 0, False);
   case SCR_NOCLEAR:
      XtVaGetValues(widgets->win2d_area[plane],
                    XmNwidth, &width,
                    XmNheight, &height, NULL);
      x_offset = 0;
      y_offset = 0;
      direction = -1;
      set_color = set_color_scr;
      draw_rectangle = draw_rectangle_scr;
      fill_rectangle = fill_rectangle_scr;
      if (!world->scaling[plane]) /* ratio is 0, follow borders */
        {x_pix_size[plane]=width/nX[plane];y_pix_size[plane]=height/nY[plane];}
      else
         {
         x_pix_size[plane]=MMIN((float)width/nX[plane],
                               (float)height/nY[plane]/world->scaling[plane]);
         y_pix_size[plane]=world->scaling[plane]*x_pix_size[plane];
         }
      if (width>nX[plane] && height>nY[plane]
       && (!x_pix_size[plane] || !y_pix_size[plane]))
         x_pix_size[plane]=y_pix_size[plane]=1;

      x_begin[plane] = (width - nX[plane] * x_pix_size[plane]) / 2;
      y_begin[plane] = (height + nY[plane] * y_pix_size[plane]) / 2
                     - y_pix_size[plane];
      }  /* End switch on output */

   idx_beg=world->sld[plane]*coeff[plane];

   if (!x_pix_size[plane] || !y_pix_size[plane])
      for (class=0; class<world->nb_class+2; class++)
         {
         world->nbpc[plane][class]=0;
         for (i=0; i<nX[plane]; i++)
            for (j=0; j<nY[plane]; j++)
               if (world->class_table[idx_beg+i*sX[plane]+j*sY[plane]]==class)
                  world->nbpc[plane][class]++;
         }
   else
      {
      for (class=0; class<world->nb_class+2; class++)
         {
         world->nbpc[plane][class]=0;
         set_color(class);
         for (i=0; i<nX[plane]; i++)
            for (j=0; j<nY[plane]; j++)
               {
               if (world->class_table[idx_beg+i*sX[plane]+j*sY[plane]]==class)
                  {
                  fill_rectangle(win, x_begin[plane]+x_pix_size[plane]*i,
                                y_begin[plane]+direction*y_pix_size[plane]*j,
                                x_pix_size[plane], y_pix_size[plane]);
                  world->nbpc[plane][class]++;
                  }
               }
         }
/* Draw the rectangle around the plane,
                this term vvvvvvvvvvvvvvvvvvvvvvvv for screen only */
      draw_rectangle(win, x_begin[plane],
                          y_pix_size[plane]*(1-direction)/2+y_begin[plane],
                          x_pix_size[plane]*nX[plane],
                          direction*y_pix_size[plane]*nY[plane]);
       }

   if (device == PSFILE)
      {
      if (print_scale)
         draw_scale_ps(x_scale, y_scale, dx_scale, dy_scale, draw);
      p_area(widgets->debug_area, "POST -> - Writting titles\n");
      draw_string_ps(0, x_mtitle, y_mtitle,
                     "-BoldOblique", (float)(0.03*draw), 'c', title[0]);
      draw_string_ps(0, x_xtitle, y_xtitle, "", (float)(0.025*draw),
                     'c', title[1]);
      draw_string_ps(90, x_ytitle, y_ytitle, "", (float)(0.025*draw),
                     'c', title[2]);
      }
   else if (world->show_line[plane])
      {
      switch(plane)
         {
         case XY:
          i=x_begin[plane]+x_pix_size[plane]*world->sld[X]+x_pix_size[plane]/2;
          j=y_begin[plane]-y_pix_size[plane]*world->sld[Y]+y_pix_size[plane]/2;
          break;
         case XZ:
          i=x_begin[plane]+x_pix_size[plane]*world->sld[X]+x_pix_size[plane]/2;
          j=y_begin[plane]-y_pix_size[plane]*world->sld[Z]+y_pix_size[plane]/2; 
         break;
         case YZ:
          i=x_begin[plane]+x_pix_size[plane]*world->sld[Y]+x_pix_size[plane]/2;
          j=y_begin[plane]-y_pix_size[plane]*world->sld[Z]+y_pix_size[plane]/2; 
         break;
         }
      XSetForeground(widgets->dpy, widgets->gc, widgets->white);
      XDrawLine(widgets->dpy, win, widgets->gc, x_begin[plane], j, 
                              x_begin[plane]+x_pix_size[plane]*nX[plane], j);
      XDrawLine(widgets->dpy, win, widgets->gc,   i,
                y_begin[plane]+y_pix_size[plane], i,
                y_begin[plane]-y_pix_size[plane]*(nY[plane]-1));
      }

   NewCursor(widgets->win2d_area[plane], XC_left_ptr);
   }

void        win2d_inout(Widget              un1,    /*F*/
                        int                 plane,  /*F*/
                        XEvent             *event)  /*F*/
   {
   switch (event->type)
      {
      case LeaveNotify: NewCursor(widgets->win2d_area[plane], None); break;
      /*case EnterNotify: NewCursor(widgets->win2d_area[plane], XC_crosshair);*/
      case EnterNotify: NewCursor(widgets->win2d_area[plane], 24);
      }
   }

void        win2d_location(Widget              un1,    /*F*/
                           int                 plane,  /*F*/
                           XEvent             *event)  /*F*/
   {
   BOOLEAN  in;
   int      x_area, y_area, x, y, coord[3];
   char     str[STRING1];
   XmString xs;
   Arg      args[3];

   x_area=event->xbutton.x;
   y_area=event->xbutton.y;
   if (!x_area || !y_area) return;
   x=(int)floor((float)(x_area-x_begin[plane])/(float)x_pix_size[plane]);
   y=(int)floor((float)(y_begin[plane]-y_area)/(float)y_pix_size[plane])+1;
   in=TRUE;
   if (x>=nX[plane] || x<0) in=FALSE;
   if (y>=nY[plane] || y<0) in=FALSE;
   if (in==TRUE)
      {
      switch(plane)
         {
         case XY: coord[X]=x; coord[Y]=y; coord[Z]=world->sld[plane]; break;
         case XZ: coord[X]=x; coord[Y]=world->sld[plane]; coord[Z]=y; break;
         case YZ: coord[X]=world->sld[plane]; coord[Y]=x; coord[Z]=y; break;
         }
      sprintf(str, "%d, %d, %d, %g", coord[X]+1, coord[Y]+1, coord[Z]+1,
                   world->values[coord[X]+coord[Y]*world->n[X]
                                +coord[Z]*world->n[X]*world->n[Y]]);
      }
   else sprintf(str, "Out");
   xs = XmStringCreateSimple(str);
   XtSetArg(args[0], XmNlabelString, xs);
   XtSetValues(widgets->win2d_loc[plane], args, 1);
   XmStringFree(xs);
   }
