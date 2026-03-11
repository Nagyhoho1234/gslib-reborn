
#include <malloc.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <Xm/ToggleB.h>
#include <Xm/ToggleBG.h>
#include <Xm/CascadeB.h>
#include <Xm/DialogS.h>
#include <Xm/Label.h>
#include <Xm/LabelG.h>
#include <Xm/TextF.h>
#include <Xm/PushB.h>
#include <Xm/PushBG.h>
#include <Xm/Form.h>
#include <Xm/MainW.h>
#include <Xm/DrawingA.h>
#include <Xm/Frame.h>
#include <Xm/RowColumn.h>
#include <Xm/Scale.h>
#include <Xm/SelectioB.h>
#include <Xm/MessageB.h>
#include <Xm/ArrowBG.h>

#include "yap.h"
#include "yaconfig.h"
#include "yaicon.h"
#include "NXHelp.h"

static unsigned int bit_flag;


World_t        *world;
Widgets_t      *widgets;
BOOLEAN         draw_nb[4];     /* in yastat.c */
Widget          nbclass_txt[3]; /* in yacut.c */

static Widget   b_stat[4], b_open[3], b_comp[4], b_scale[3], b_debug;
static char     pln[4][4];
static char     dir[4];

static int nb_refresh;

void            print_mem(char * msg)
   {
#ifdef DEBUG
   struct mallinfo m;

   m=mallinfo();
   printf("\n           Memory state %s\n", msg);
   printf("arena:   %7d  ", m.arena);
   printf("ordblks: %7d  ", m.ordblks);
   printf("smblks:  %7d  ", m.smblks);
   printf("usmblks: %7d\n", m.usmblks);
   printf("fsmblks: %7d  ", m.fsmblks);
   printf("uordblks:%7d  ", m.uordblks);
   printf("fordblks:%7d  ", m.fordblks);
   printf("keepcost:%7d\n", m.keepcost);
#else
   return;
#endif
   }

void            MySetSensitive(int   b_widget, int plane, BOOLEAN what)
   {
   switch(b_widget)
      {
      case B_STAT:  XtSetSensitive(b_stat[plane],  what); break;
      case B_OPEN:  XtSetSensitive(b_open[plane],  what); break;
      case B_SCALE: XtSetSensitive(b_scale[plane], what); break;
      case B_COMP:  XtSetSensitive(b_comp[plane],  what); break;
      case B_DEBUG: XtSetSensitive(b_debug,        what); break;
      }
   }

void            refresh_all(void)  /*F*/
   {
   int             plane;

   if (world->loaded)                /* Draw only if file loaded */
      {
      p_area(widgets->debug_area, "SCR  -> Refreshing all\n");
      draw_3d_cube(True);
      for (plane=0; plane<3; plane++)
         {
         if (WIN2D_MANAGED(plane)) draw_plane(plane, (int)SCR_CLEAR);
         if (WINST_MANAGED(plane)) draw_stat(plane, (int)SCR_CLEAR,
                                             draw_nb[plane]);
         }
      if (WINST_MANAGED((int)THREED))
         draw_stat((int)THREED, (int)SCR_CLEAR, draw_nb[THREED]);
      }
   }

static void     draw_win3d(Widget           un1,  /*F*/
                           XtPointer        un2,  /*F*/
                           XtPointer        un3)  /*F*/
   {
   if (!world->refresh) return;
   if (world->loaded)           /* Draw only if file loaded */
      draw_3d_cube(True);       /* clear before drawing */
   }

static void     winst_nb_cb(Widget          w,         /*F*/
                            int             plane,     /*F*/
                            XtPointer       un1)       /*F*/
   {
   draw_nb[plane]=XmToggleButtonGetState(w);
   if (WINST_MANAGED(plane)); draw_stat(plane, (int)SCR_CLEAR,
                                        draw_nb[plane]);
   }
   
static void     file_cb(Widget              un1,        /*F*/
                        int                 number,     /*F*/
                        XtPointer           un2)        /*F*/
   {
   switch (number)
      {
   case 0: open_fn();                                          break;
   case 1: if (world->file) save_fn();
           else PostDialog(widgets->top, XmDIALOG_ERROR,
                    "Error", "No file to save", "Indeed");     break;
   case 2: cmap_fn();                                          break;
   case 3: default_cmap(); refresh_all(); break;
   case 4: quit_fn();                                          break;
   default:                                                    break;
      }
   }

static void        allcut_fn(void)       /*F*/
   {
   Widget          allcut, allcut_frame, allcut_form, allcut_set;
   Widget          allcut_rowc, allcut_buttons, allcut_cancel, allcut_help;
   XmString        str;
   char            cstr1[STRING1], cstr2[STRING2];
   int             i;

   world->refresh=FALSE;
   XtSetSensitive(widgets->allcut, False);
   XtSetSensitive(widgets->cutoff, False);
   XtSetSensitive(widgets->nbcut,  False);
   str=XmStringCreateSimple("Cutoffs modification");
   allcut = XtVaCreatePopupShell("Allcut",
                      xmDialogShellWidgetClass, widgets->top,
                      XmNmwmFunctions,          30,
                      XmNdialogStyle,           XmDIALOG_FULL_APPLICATION_MODAL,
                      XmNdialogTitle,           str,
                      NULL);
   XmStringFree(str);

   allcut_frame = XtVaCreateWidget("allcut_frame",
                                   xmFrameWidgetClass, allcut,
                                   NULL);

   allcut_form = XtVaCreateManagedWidget("allcut_form",
                                         xmFormWidgetClass, allcut_frame,
                                         NULL);

   allcut_rowc = XtVaCreateManagedWidget("allcut_row",
                                         xmRowColumnWidgetClass, allcut_form,
                                         XmNbottomAttachment, XmATTACH_FORM,
                                         XmNtopAttachment, XmATTACH_FORM,
                                         XmNleftAttachment, XmATTACH_FORM,
                                         XmNrightAttachment, XmATTACH_FORM,
                                         NULL);

   sprintf(cstr2, "%g ", world->cutoffs[0]);
   for (i=1; i<world->nb_class+1; i++)
      {
      sprintf(cstr1, "%g ", world->cutoffs[i]);
      strcat(cstr2, cstr1);
      }
   widgets->allcut_txt = XtVaCreateManagedWidget("allcut_lbl",
                                        xmTextFieldWidgetClass, allcut_rowc,
                                        XmNvalue,               cstr2,
                                        XmNx,                   100,
                                        NULL);

   allcut_buttons = XtVaCreateManagedWidget("allcut_buttons",
                                   xmRowColumnWidgetClass, allcut_rowc,
                                   XmNnumColumns,          2,
                                   XmNorientation,         XmHORIZONTAL,
                                   NULL);

   allcut_set = XtVaCreateManagedWidget("Set values",
                                   xmPushButtonGadgetClass, allcut_buttons,
                                   NULL);
   allcut_cancel = XtVaCreateManagedWidget("Cancel",
                                   xmPushButtonGadgetClass, allcut_buttons,
                                   NULL);
   allcut_help = XtVaCreateManagedWidget("Help",
                                   xmPushButtonGadgetClass, allcut_buttons,
                                   NULL);

   XtAddCallback(allcut_cancel, XmNactivateCallback,
                 (XtCallbackProc)cutoff_cancel_cb, (XtPointer)allcut);
   XtAddCallback(allcut_set, XmNactivateCallback,
                 (XtCallbackProc)allcut_set_cb, (XtPointer)allcut);
   XtAddCallback(allcut_help, XmNactivateCallback,
                 (XtCallbackProc)XnHelpCB, "Change all cutoffs");
   XtManageChild(allcut_frame);
   XtManageChild(allcut);
   }

static void        cutoff_fn(void)       /*F*/
   {
   Widget          cutoff, cutoff_frame, cutoff_form, cutoff_rowc;
   Widget          cutoff_form_arrows, cutoff_l_arrow, cutoff_r_arrow;
   Widget          cutoff_set;
   XmString        str;
   char            cstr[STRING1];

   world->refresh=FALSE;
   XtSetSensitive(widgets->allcut, False);
   XtSetSensitive(widgets->cutoff, False);
   XtSetSensitive(widgets->nbcut,  False);
   str = XmStringCreateSimple("Cutoffs modification");
   cutoff = XtVaCreatePopupShell("Cuttofs",
                      xmDialogShellWidgetClass, widgets->top,
                      XmNmwmFunctions,          30,
                      XmNdialogStyle,           XmDIALOG_FULL_APPLICATION_MODAL,
                      XmNdialogTitle,           str,
                      NULL);
   XmStringFree(str);

   cutoff_frame = XtVaCreateWidget("cutoff_frame",
                                   xmFrameWidgetClass, cutoff,
                                   NULL);

   cutoff_form = XtVaCreateManagedWidget("cutoff_form",
                                         xmFormWidgetClass, cutoff_frame,
                                         NULL);

   cutoff_rowc = XtVaCreateManagedWidget("cutoff_rowc",
                                         xmRowColumnWidgetClass, cutoff_form,
                                         XmNbottomAttachment, XmATTACH_FORM,
                                         XmNtopAttachment, XmATTACH_FORM,
                                         XmNleftAttachment, XmATTACH_FORM,
                                         XmNrightAttachment, XmATTACH_FORM,
                                         NULL);

   widgets->cutoff_lbl = XtVaCreateManagedWidget("Cutoff #   0: ",
                                        xmLabelGadgetClass, cutoff_rowc,
                                        NULL);

   sprintf(cstr, "%g", world->cutoffs[0]);
   widgets->cutoff_txt = XtVaCreateManagedWidget("cutoff_txt",
                                        xmTextFieldWidgetClass, cutoff_rowc,
                                        XmNvalue, cstr,
                                        NULL);

   cutoff_form_arrows = XtVaCreateManagedWidget("cutoff_form_arrows",
                                             xmFormWidgetClass, cutoff_rowc,
                                                XmNfractionBase, 2,
                                                NULL);

   cutoff_l_arrow = XtVaCreateManagedWidget("cutoff_l_arrow",
                               xmArrowButtonGadgetClass, cutoff_form_arrows,
                                        XmNtopAttachment, XmATTACH_POSITION,
                                            XmNtopPosition, 0,
                                     XmNbottomAttachment, XmATTACH_POSITION,
                                            XmNbottomPosition, 2,
                                       XmNleftAttachment, XmATTACH_POSITION,
                                            XmNleftPosition, 0,
                                      XmNrightAttachment, XmATTACH_POSITION,
                                            XmNrightPosition, 1,
                                            XmNarrowDirection, XmARROW_LEFT,
                                            NULL);

   cutoff_r_arrow = XtVaCreateManagedWidget("cutoff_l_arrow",
                               xmArrowButtonGadgetClass, cutoff_form_arrows,
                                        XmNtopAttachment, XmATTACH_POSITION,
                                            XmNtopPosition, 0,
                                     XmNbottomAttachment, XmATTACH_POSITION,
                                            XmNbottomPosition, 2,
                                       XmNleftAttachment, XmATTACH_POSITION,
                                            XmNleftPosition, 1,
                                      XmNrightAttachment, XmATTACH_POSITION,
                                            XmNrightPosition, 2,
                                            XmNarrowDirection, XmARROW_RIGHT,
                                            NULL);
   cutoff_set = XtVaCreateManagedWidget("Set values",
                                        xmPushButtonGadgetClass, cutoff_rowc,
                                        NULL);

   world->current_cutoff=0;
   XtAddCallback(cutoff_set, XmNactivateCallback,
                 (XtCallbackProc)cutoff_set_cb, (XtPointer) cutoff);
   XtAddCallback(cutoff_l_arrow, XmNactivateCallback,
                 (XtCallbackProc)l_arrow_cb, NULL);
   XtAddCallback(cutoff_r_arrow, XmNactivateCallback,
                 (XtCallbackProc)r_arrow_cb, NULL);

   XtManageChild(cutoff_frame);
   XtManageChild(cutoff);
   }

static void        nbclass_fn(void)      /*F*/
   {
   Widget          nbclass, nbclass_frame, nbclass_form, nbclass_rowc;
   Widget          nbclass_rowc_frame, nbclass_buttons, nbclass_set;
   Widget          nbclass_cancel, nbclass_lbl[3], nbclass_toggle_mode;
   Widget          nbclass_help;
   Widget          nbclass_mode_ari, nbclass_mode_log, nbclass_mode_qua;
   char            cstr[STRING1];
   int             count;
   Arg             args[12];

   world->refresh=FALSE;
   XtSetSensitive(widgets->allcut, False);
   XtSetSensitive(widgets->cutoff, False);
   XtSetSensitive(widgets->nbcut, False);
   nbclass = XtVaCreatePopupShell("Nb classes",
                      xmDialogShellWidgetClass, widgets->top,
                      XmNmwmFunctions,          30,
                      XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
                      XmNdialogTitle, cstr,
                      NULL);

   nbclass_frame = XtVaCreateWidget("nbclass_frame",
                                    xmFrameWidgetClass, nbclass,
                                    NULL);

   nbclass_form = XtVaCreateManagedWidget("nbclass_form",
                                          xmFormWidgetClass, nbclass_frame,
                                          NULL);

   nbclass_rowc_frame = XtVaCreateWidget("nbclass_rowc_frame",
                                         xmFrameWidgetClass, nbclass_form,
                                         XmNtopAttachment, XmATTACH_FORM,
                                         XmNleftAttachment, XmATTACH_FORM,
                                         XmNrightAttachment, XmATTACH_FORM,
                                         NULL);

   nbclass_rowc = XtVaCreateWidget("nbclass_rowc",
                                   xmRowColumnWidgetClass, nbclass_rowc_frame,
                                   XmNpacking, XmPACK_COLUMN,
                                   XmNnumColumns, 3,
                                   XmNorientation, XmHORIZONTAL,
                                   XmNisAligned, True,
                                   NULL);

   sprintf(cstr, "%d", world->nb_class);
   nbclass_lbl[0] = XtVaCreateManagedWidget("Number of classes: ",
                                            xmLabelGadgetClass, nbclass_rowc,
                                            NULL);
   nbclass_txt[0] = XtVaCreateManagedWidget("nbclass_nb",
                                         xmTextFieldWidgetClass, nbclass_rowc,
                                         XmNvalue, cstr,
                                         NULL);
   sprintf(cstr, "%g", world->show_min);
   nbclass_lbl[1] = XtVaCreateManagedWidget("Minimum to display: ",
                                            xmLabelGadgetClass, nbclass_rowc,
                                            NULL);
   nbclass_txt[1] = XtVaCreateManagedWidget("nbclass_min",
                                         xmTextFieldWidgetClass, nbclass_rowc,
                                         XmNvalue, cstr,
                                         NULL);
   sprintf(cstr, "%g", world->show_max);
   nbclass_lbl[2] = XtVaCreateManagedWidget("Maximum to display: ",
                                            xmLabelGadgetClass, nbclass_rowc,
                                            NULL);
   nbclass_txt[2] = XtVaCreateManagedWidget("nbclass_max",
                                         xmTextFieldWidgetClass, nbclass_rowc,
                                         XmNvalue, cstr,
                                         NULL);

   nbclass_toggle_mode = XmCreateRadioBox(nbclass_form,
                                 "nbclass_toggle_mode", NULL, 0);

   count=0;
   XtSetArg(args[count], XmNpacking,         XmPACK_COLUMN);      count++;
   XtSetArg(args[count], XmNnumColumns,      3);                  count++;
   XtSetArg(args[count], XmNorientation,     XmHORIZONTAL);       count++;
   XtSetArg(args[count], XmNisAligned,       True);               count++;
   XtSetArg(args[count], XmNtopAttachment,   XmATTACH_WIDGET);    count++;
   XtSetArg(args[count], XmNtopWidget,       nbclass_rowc_frame); count++;
   XtSetArg(args[count], XmNleftAttachment,  XmATTACH_FORM);      count++;
   XtSetArg(args[count], XmNrightAttachment, XmATTACH_FORM);      count++;
   XtSetValues(nbclass_toggle_mode, args, count);

   nbclass_buttons = XtVaCreateManagedWidget("nbclass_buttons",
                                    xmRowColumnWidgetClass, nbclass_form,
                                    XmNtopAttachment,       XmATTACH_WIDGET,
                                    XmNtopWidget,           nbclass_toggle_mode,
                                    XmNnumColumns,          2,
                                    XmNorientation,         XmHORIZONTAL,
                                    NULL);

   nbclass_set = XtVaCreateManagedWidget("Set values",
                                   xmPushButtonGadgetClass, nbclass_buttons,
                                   NULL);
   nbclass_cancel = XtVaCreateManagedWidget("Cancel",
                                   xmPushButtonGadgetClass, nbclass_buttons,
                                   NULL);
   nbclass_help = XtVaCreateManagedWidget("Help",
                                   xmPushButtonGadgetClass, nbclass_buttons,
                                   NULL);

   nbclass_mode_ari = XtVaCreateManagedWidget("Arithmetic",
                                 xmToggleButtonGadgetClass, nbclass_toggle_mode,
                                 NULL);
   nbclass_mode_log = XtVaCreateManagedWidget("Logarithmic",
                                 xmToggleButtonGadgetClass, nbclass_toggle_mode,
                                 NULL);
   if (world->comp_quant)
      nbclass_mode_qua = XtVaCreateManagedWidget("Quantiles",
                                 xmToggleButtonGadgetClass, nbclass_toggle_mode,
                                 NULL);

   XtAddCallback(nbclass_mode_ari, XmNvalueChangedCallback,
                 (XtCallbackProc)nbclass_mode_cb, (XtPointer) ARITHMETIC);
   XtAddCallback(nbclass_mode_log, XmNvalueChangedCallback,
                 (XtCallbackProc)nbclass_mode_cb, (XtPointer) LOGARITHMIC);
   if (world->comp_quant)
      XtAddCallback(nbclass_mode_qua, XmNvalueChangedCallback,
                    (XtCallbackProc)nbclass_mode_cb, (XtPointer) QUANTILES);
   switch (world->mode)
      {
      case ARITHMETIC:
         XmToggleButtonSetState(nbclass_mode_ari, True, False);  break;
      case LOGARITHMIC:
         XmToggleButtonSetState(nbclass_mode_log, True, False); break;
      case QUANTILES:
         if (world->comp_quant)
            XmToggleButtonSetState(nbclass_mode_qua, True, False); break;
      }

   XtAddCallback(nbclass_set, XmNactivateCallback,
                 (XtCallbackProc)nbclass_set_cb, (XtPointer) nbclass);
   XtAddCallback(nbclass_cancel, XmNactivateCallback,
                 (XtCallbackProc)cutoff_cancel_cb, (XtPointer) nbclass);
   XtAddCallback(nbclass_help, XmNactivateCallback,
                 (XtCallbackProc)XnHelpCB, "Number of classes");

   XtManageChild(nbclass_toggle_mode);
   XtManageChild(nbclass_rowc);
   XtManageChild(nbclass_rowc_frame);
   XtManageChild(nbclass_frame);
   XtManageChild(nbclass);
   }

static void     edit_cb(Widget           un1,        /*F*/
                        int              number,     /*F*/
                        XtPointer        un2)        /*F*/
   {
   switch (number)
      {
   case 0: debug_fn();   break;
   case 1: nbclass_fn(); break;
   case 2: cutoff_fn();  break;
   case 3: allcut_fn();  break;
   default:              break;
      }
   }

static void     slide_cb(Widget                 un1,    /*F*/
                         int                    plane,  /*F*/
                         XmScaleCallbackStruct *cbs)    /*F*/
   {
   int i;
   world->sld[plane]=cbs->value-1;
   for (i=0; i<3; i++)
      if (world->show_line[i] || i==plane)
         if (WIN2D_MANAGED(i)) draw_plane(i, (int)SCR_NOCLEAR);
   }

static void     win2d_line_cb(Widget            w,         /*F*/
                              int               plane,     /*F*/
                              XtPointer         un1)       /*F*/
   {
   world->show_line[plane]=XmToggleButtonGetState(w);
   if (WIN2D_MANAGED(plane)) draw_plane(plane, (int)SCR_NOCLEAR);
   }

static void     close_winst(Widget              un1,       /*F*/
                            int                 plane,     /*F*/
                            XtPointer           un2)       /*F*/
   {
   MySetSensitive((int)B_STAT, plane, True);
   XtUnmanageChild(widgets->winst[plane]);
   }

static void     close_win2d(Widget              un1,       /*F*/
                            int                 plane,     /*F*/
                            XtPointer           un2)       /*F*/
   {
   MySetSensitive((int)B_OPEN, plane, True);
   XtUnmanageChild(widgets->win2d[plane]);
   }

static void     draw_winst(Widget               un1,       /*F*/
                           int                  plane,     /*F*/
                           XtPointer            un2)       /*F*/
   {
/* This function is very strange. Try to find out what i wanted to do... */
   /*int             beg=plane, end=plane, i;*/
  
   if (!world->refresh) return;
   if (WINST_MANAGED(plane)) draw_stat(plane, (int)SCR_CLEAR, draw_nb[plane]);
   /*if (plane == 4) { beg=0; end=3; }*/
   /*for (i=beg; i<end+1; i++)*/
      /*if (WINST_MANAGED(i)) draw_stat(plane, (int)SCR_CLEAR, draw_nb[i]);*/
   }

static void     refresh_win2d(Widget               un1,       /*F*/
                           int                  plane,     /*F*/
                           XtPointer            un2)       /*F*/
   {
   int             beg = plane, end = plane, i;

   if (!world->refresh) return;
/*printf("refresh_win2d called for %d (%d)\n", plane, nb_refresh++);*/
   if (plane==3) { beg=0; end=2; }
   for (i=beg; i<end+1; i++)
      if (WIN2D_MANAGED(i)) draw_plane(i, (int)SCR_CLEAR);
   }

#define EV_MASK (PointerMotionMask   \
               | ExposureMask        \
               | ButtonPressMask     \
               | KeyPressMask        \
               | KeymapStateMask     \
               | EnterWindowMask     \
               | LeaveWindowMask     \
               | ResizeRedirectMask  \
               | StructureNotifyMask)

static void     draw_win2d(Widget               un1,       /*F*/
                           int                  plane,     /*F*/
                           XtPointer            un2)       /*F*/
   {
   XEvent          event;
   int             beg = plane, end = plane, i;

   if (!world->refresh) return;
   if (world->xflush)
      {
      XFlush(widgets->dpy);
      while(XCheckMaskEvent(widgets->dpy, EV_MASK, &event))
         {
         printf("%d %d %d %d", Expose, ButtonPress, MapNotify, ResizeRequest);
         printf("  -> %d\n", event.type);
         }
      }
   if (plane==3) { beg=0; end=2; }
   for (i=beg; i<end+1; i++)
      if (WIN2D_MANAGED(i)) draw_plane(i, (int)SCR_CLEAR);
   }

static void     open_winst(Widget               un1,       /*F*/
                           int                  plane,     /*F*/
                           XtPointer            un2)       /*F*/
   {
   Widget          stat_win, winst_frame, winst_butt, winst_close;
   Widget          winst_refresh, winst_loc_frame;
   Widget          winst_mode_toggle;
   Widget          winst_pdf[4], winst_cdf[4], winst_nb[4];
   char            title[STRING1];
   Arg             args[6];
   XmString        xs;

   MySetSensitive((int)B_STAT, plane, False);

   if (!widgets->winst[plane])
      {
      sprintf(title, "Statistics for %s", pln[plane]);

      p_area(widgets->debug_area,
             "STAT -> Opening new stat in %s plane\n", pln[plane]);
      widgets->winst[plane] = XtVaCreatePopupShell("stat",
                      xmDialogShellWidgetClass, widgets->top,
                      XmNdialogStyle,           XmDIALOG_FULL_APPLICATION_MODAL,
                      XmNmwmFunctions,          30,
                      XmNtitle,                 title,
                      NULL);

      stat_win = XtVaCreateWidget("stat_win",
                      xmFormWidgetClass,        widgets->winst[plane],
                      XmNtopAttachment,         XmATTACH_FORM,
                      XmNbottomAttachment,      XmATTACH_FORM,
                      XmNleftAttachment,        XmATTACH_FORM,
                      XmNrightAttachment,       XmATTACH_FORM,
                      NULL);

      winst_loc_frame=XtVaCreateWidget("winst_loc_frame",
                      xmFrameWidgetClass,       stat_win,
                      XmNleftAttachment,        XmATTACH_FORM,
                      XmNtopAttachment,         XmATTACH_FORM,
                      XmNrightAttachment,       XmATTACH_FORM,
                      NULL);

      widgets->winst_loc[plane]=XtVaCreateWidget("Proportion_Class",
                      xmLabelGadgetClass,       winst_loc_frame,
                      NULL);

      winst_butt=XtVaCreateManagedWidget("winst_butt",
                      xmRowColumnWidgetClass,   stat_win,
                      XmNnumColumns,            2,
                      XmNpacking,               XmPACK_COLUMN,
                      XmNorientation,           XmHORIZONTAL,
                      XmNleftAttachment,        XmATTACH_FORM,
                      XmNrightAttachment,       XmATTACH_FORM,
                      XmNbottomAttachment,      XmATTACH_FORM,
                      NULL);

      winst_close = XtVaCreateManagedWidget("Close",
                      xmPushButtonGadgetClass, winst_butt,
                      NULL);

      winst_refresh = XtVaCreateManagedWidget("Refresh",
                      xmPushButtonGadgetClass, winst_butt,
                      NULL);

      winst_nb[plane] = XtVaCreateManagedWidget("Prop",
                      xmToggleButtonGadgetClass, winst_butt,
                      NULL);

      sprintf(title, "mode_toggle_%s",       pln[plane]);
      XtSetArg(args[0], XmNorientation,      XmHORIZONTAL);
      winst_mode_toggle = XmCreateRadioBox(winst_butt, title, args, 1);

      winst_pdf[plane] = XtVaCreateManagedWidget("pdf",
                              xmToggleButtonGadgetClass, winst_mode_toggle,
                              NULL);

      winst_cdf[plane] = XtVaCreateManagedWidget("cdf",
                              xmToggleButtonGadgetClass, winst_mode_toggle,
                              NULL);

      winst_frame = XtVaCreateWidget("winst_frame",
                                   xmFrameWidgetClass,  stat_win,
                                   XmNtopAttachment,    XmATTACH_WIDGET,
                                   XmNtopWidget,        winst_loc_frame,
                                   XmNleftAttachment,   XmATTACH_FORM,
                                   XmNrightAttachment,  XmATTACH_FORM,
                                   XmNbottomAttachment, XmATTACH_WIDGET,
                                   XmNbottomWidget,     winst_butt,
                                   NULL);

      sprintf(title, "winst_area_%s", pln[plane]);
      widgets->winst_area[plane] = XtVaCreateWidget(title,
                                   xmDrawingAreaWidgetClass, winst_frame,
                                   XmNbackground,            widgets->white,
                                   NULL);

      XtAddCallback(winst_pdf[plane], XmNvalueChangedCallback,
                    (XtCallbackProc)winst_pdf_cb, (XtPointer) plane);
      XtAddCallback(winst_cdf[plane], XmNvalueChangedCallback,
                    (XtCallbackProc)winst_cdf_cb, (XtPointer) plane);
      XtAddCallback(winst_nb[plane], XmNvalueChangedCallback,
                    (XtCallbackProc)winst_nb_cb,  (XtPointer) plane);
      XtAddCallback(winst_close, XmNactivateCallback,
                    (XtCallbackProc)close_winst,  (XtPointer) plane);
      XtAddCallback(winst_refresh, XmNactivateCallback,
                    (XtCallbackProc)draw_winst,   (XtPointer) plane);

      XtAddCallback(widgets->winst_area[plane], XmNexposeCallback,
                    (XtCallbackProc)draw_winst, (XtPointer) plane);
      XtAddEventHandler(widgets->winst_area[plane],
               ButtonPressMask, False,
               (XtEventHandler)winst_label, (XtPointer) plane) ;

      XtManageChild(widgets->winst[plane]);
      XtManageChild(widgets->winst_area[plane]);
      XtManageChild(winst_frame);
      XtManageChild(winst_butt);
      XtManageChild(winst_mode_toggle);
      XtManageChild(widgets->winst_loc[plane]);
      XtManageChild(winst_loc_frame);
      XtManageChild(stat_win);

      XmToggleButtonSetState(winst_nb[plane], False, False);
      draw_nb[plane]=False;
      XmToggleButtonSetState(winst_pdf[plane], True, False);
      }
   else
      {
      p_area(widgets->debug_area,
             "STAT -> Re-opening old stat window in %s plane\n", pln[plane]);
      XtManageChild(widgets->winst[plane]);
      }
   XtVaSetValues(widgets->winst_loc[plane],
                 XtVaTypedArg, XmNlabelString, XmRString,
                 "Proportion/Class (click on histogram bar)", 42,
                 NULL);
   }

static void     open_win2d(Widget               un1,       /*F*/
                           int                  plane,     /*F*/
                           XtPointer            un2)       /*F*/
   {
   Widget          twod_win, win2d_frame, win2d_butt, win2d_close;
   Widget          win2d_print, win2d_refresh, win2d_loc_frame;
   Widget          win2d_toggle_line[3];
   char            title[STRING1];
   Arg             args[2];
   XmString        xs;

   MySetSensitive((int)B_OPEN, plane, False);

   if (!widgets->win2d[plane])
      {
      sprintf(title, "%s plane (%c is constant)", pln[plane], dir[plane]);

      p_area(widgets->debug_area,
             "SCR2 -> Opening new 2d window in %s plane\n", pln[plane]);
      widgets->win2d[plane] = XtVaCreatePopupShell("win2d",
                      xmDialogShellWidgetClass, widgets->top,
                      XmNdialogStyle,           XmDIALOG_FULL_APPLICATION_MODAL,
                      XmNmwmFunctions,          30,
                      XmNtitle,                 title,
                      NULL);

      sprintf(title, "2d_win_%s", pln[plane]);
      twod_win = XtVaCreateWidget("twod_win",
                      xmFormWidgetClass,        widgets->win2d[plane],
                      XmNtopAttachment,         XmATTACH_FORM,
                      XmNbottomAttachment,      XmATTACH_FORM,
                      XmNleftAttachment,        XmATTACH_FORM,
                      XmNrightAttachment,       XmATTACH_FORM,
                      NULL);

      win2d_loc_frame = XtVaCreateWidget("win2d_loc_frame",
                                 xmFrameWidgetClass,    twod_win,
                                 XmNtopAttachment,   XmATTACH_FORM,
                                 XmNleftAttachment,     XmATTACH_FORM,
                                 XmNrightAttachment,     XmATTACH_FORM,
                                 NULL);

      widgets->win2d_loc[plane]=
         XtVaCreateWidget("Location",
                      xmLabelGadgetClass,    win2d_loc_frame,
                      XmNbottomAttachment,   XmATTACH_FORM,
                      XmNrightAttachment,    XmATTACH_FORM,
                      XmNleftAttachment,     XmATTACH_FORM,
                      XmNtopAttachment,      XmATTACH_FORM,
                      NULL);

      sprintf(title, "slide_%s", pln[plane]);
      widgets->slide[plane] = XtVaCreateWidget(title,
                      xmScaleWidgetClass,       twod_win,
                      XmNshowValue,             True,
                      XmNscaleMultiple,         1,
                      XmNorientation,           XmVERTICAL,
                      XmNtopAttachment,         XmATTACH_WIDGET,
                      XmNtopWidget,             win2d_loc_frame,
                      XmNrightAttachment,       XmATTACH_FORM,
                      XmNbottomAttachment,      XmATTACH_FORM,
                      NULL);
      if (world->n[plane] > 1)
         XtVaSetValues(widgets->slide[plane],
                      XmNminimum,               1,
                      XmNmaximum,               world->n[plane],
                      XmNvalue,                 1,
                      NULL);
      else
         XtVaSetValues(widgets->slide[plane],
                      XmNminimum,               1,
                      XmNmaximum,               2,
                      XmNvalue,                 1,
                      XmNsensitive,             False,
                      NULL);

      win2d_butt = XtVaCreateWidget("win2d_butt",
                      xmRowColumnWidgetClass, twod_win,
                      XmNnumColumns,          2,
                      XmNpacking,             XmPACK_COLUMN,
                      XmNorientation,         XmHORIZONTAL,
                      XmNleftAttachment,      XmATTACH_FORM,
                      XmNrightAttachment,     XmATTACH_WIDGET,
                      XmNrightWidget,         widgets->slide[plane],
                      XmNbottomAttachment,    XmATTACH_FORM,
                      NULL);

      win2d_close = XtVaCreateWidget("Close",
                                    xmPushButtonGadgetClass, win2d_butt,
                                    NULL);

      win2d_refresh = XtVaCreateWidget("Refresh",
                                   xmPushButtonGadgetClass, win2d_butt,
                                   NULL);

      b_scale[plane] = XtVaCreateWidget("Scaling",
                                   xmPushButtonGadgetClass, win2d_butt,
                                   NULL);

      win2d_toggle_line[plane] = XtVaCreateWidget("Lines",
                              xmToggleButtonGadgetClass, win2d_butt,
                              NULL);

      win2d_print = XtVaCreateWidget("Print",
                                    xmPushButtonGadgetClass, win2d_butt,
                                    NULL);

      b_stat[plane] = XtVaCreateWidget("Stat",
                                   xmPushButtonGadgetClass, win2d_butt,
                                   NULL);

      b_comp[plane] = XtVaCreateWidget("Compute",
                                   xmPushButtonGadgetClass, win2d_butt,
                                   NULL);

      win2d_frame = XtVaCreateWidget("win2d_frame",
                                 xmFrameWidgetClass,  twod_win,
                                 XmNresizePolicy,     XmRESIZE_NONE,
                                 XmNtopAttachment,    XmATTACH_WIDGET,
                                 /*XmNtopWidget,        widgets->win2d_loc[plane],*/
                                 XmNtopWidget,        win2d_loc_frame,
                                 XmNbottomAttachment, XmATTACH_WIDGET,
                                 XmNbottomWidget,     win2d_butt,
                                 XmNleftAttachment,   XmATTACH_FORM,
                                 XmNrightAttachment,  XmATTACH_WIDGET,
                                 XmNrightWidget,      widgets->slide[plane],
                                 NULL);

      widgets->win2d_area[plane] = XtVaCreateWidget("win2d_area",
                                      xmDrawingAreaWidgetClass, win2d_frame,
                                      XmNbackground, widgets->white,
                                      NULL);
      XtAddCallback(win2d_close,    XmNactivateCallback,
                   (XtCallbackProc)close_win2d,   (XtPointer)plane);
      XtAddCallback(win2d_print,    XmNactivateCallback,
                   (XtCallbackProc)print_win2d,   (XtPointer)plane);
      XtAddCallback(win2d_refresh,  XmNactivateCallback,
                   (XtCallbackProc)refresh_win2d, (XtPointer)plane);
      XtAddCallback(b_scale[plane], XmNactivateCallback,
                   (XtCallbackProc)scale_cb,      (XtPointer)plane);
      XtAddCallback(b_stat[plane],  XmNactivateCallback,
                   (XtCallbackProc)open_winst,    (XtPointer)plane);
      XtAddCallback(b_comp[plane],  XmNactivateCallback,
                   (XtCallbackProc)comp_cb,       (XtPointer)plane);

      XtAddCallback(widgets->win2d_area[plane], XmNexposeCallback,
                    (XtCallbackProc)draw_win2d,     (XtPointer) plane);
      XtAddEventHandler(widgets->win2d_area[plane],
               ButtonPressMask, FALSE,
               (XtEventHandler)win2d_location, (XtPointer) plane);
      XtAddEventHandler(widgets->win2d_area[plane],
               LeaveWindowMask|EnterWindowMask, FALSE,
               (XtEventHandler)win2d_inout, (XtPointer) plane);
      XtAddCallback(widgets->slide[plane], XmNvalueChangedCallback,
                    (XtCallbackProc)slide_cb,      (XtPointer) plane);

      XtAddCallback(widgets->win2d_area[plane], XmNexposeCallback,
                    (XtCallbackProc)draw_winst,    (XtPointer) plane);
      XtAddCallback(widgets->slide[plane], XmNvalueChangedCallback,
                    (XtCallbackProc)draw_winst,    (XtPointer) plane);
      XtAddCallback(win2d_toggle_line[plane], XmNvalueChangedCallback,
                    (XtCallbackProc)win2d_line_cb, (XtPointer)plane);

      XtManageChild(widgets->win2d_area[plane]);
      XtManageChild(win2d_frame);
      XtManageChild(b_comp[plane]);
      XtManageChild(b_stat[plane]);
      XtManageChild(win2d_print);
      XtManageChild(win2d_toggle_line[plane]);
      XtManageChild(b_scale[plane]);
      XtManageChild(win2d_refresh);
      XtManageChild(win2d_close);
      XtManageChild(win2d_butt);
      XtManageChild(widgets->slide[plane]);
      XtManageChild(widgets->win2d_loc[plane]);
      XtManageChild(win2d_loc_frame);
      XtManageChild(twod_win);

      if (world->show_line[plane])
         XmToggleButtonSetState(win2d_toggle_line[plane], True, False);
      else
         XmToggleButtonSetState(win2d_toggle_line[plane], False, False);
      if (!world->comp_stat)
         {
         MySetSensitive((int)B_COMP, plane, False);
         MySetSensitive((int)B_STAT, plane, False);
         }
      }
   else
      {
      p_area(widgets->debug_area,
             "SCR2 -> Re-opening old 2d window in %s plane\n", pln[plane]);
      }
   xs=XmStringCreateSimple("Location (click on slice)");
   XtSetArg(args[0], XmNlabelString, xs);
   XtSetValues(widgets->win2d_loc[plane], args, 1);
   XmStringFree(xs);
   XtManageChild(widgets->win2d[plane]);
   }

/* BEGIN This is taken from motifgif.c */
/***********************************************************/
static Widget   CreateCascade(char       *label,     /*F*/
                              char        mnemonic,  /*F*/
                              Widget      submenu,   /*F*/
                              Widget      parent)    /*F*/
   {
   Widget          widget;
   int             n;
   Arg             args[20];
   XmString        tcs;

   n = 0;
   tcs = XmStringLtoRCreate(label, XmSTRING_DEFAULT_CHARSET);
   XtSetArg(args[n], XmNlabelString, tcs); n++;
   XtSetArg(args[n], XmNmnemonic, mnemonic); n++;
   XtSetArg(args[n], XmNsubMenuId, submenu); n++;
   widget = XmCreateCascadeButton(parent, "cascade", args, n);
   XtManageChild(widget);
   XmStringFree(tcs);

   return (widget);
   }

/***********************************************************/
static Widget   CreatePushButton(char    *label,     /*F*/
                                 char     mnemonic,  /*F*/
                                 Widget   parent)    /*F*/
   {
   static Widget   widget;
   int             n;
   Arg             args[20];
   XmString        tcs, acc_text;

   n = 0;
   tcs = XmStringLtoRCreate(label, XmSTRING_DEFAULT_CHARSET);
   acc_text = XmStringLtoRCreate("^A", XmSTRING_DEFAULT_CHARSET);
   XtSetArg(args[n], XmNmnemonic, mnemonic); n++;
   /* if default, extra border */
   if (bit_flag & 0x02)
      {
      XtSetArg(args[n], XmNshowAsDefault, 1); n++;
      }
   /* if there is an accelerator associated with the button */
   if (bit_flag & 0x01)
      {
      XtSetArg(args[n], XmNaccelerator, "Ctrl<Key>A"); n++;
      XtSetArg(args[n], XmNacceleratorText, acc_text); n++;
      }
   /* if the button is inactive; greyed out */
   if (bit_flag & 0x04)
      {
      XtSetArg(args[n], XmNsensitive, False); n++;
      }

   widget = XmCreatePushButton(parent, label, args, n);
   XtManageChild(widget);
   XmStringFree(tcs);
   if (bit_flag & 0x01)
      XmStringFree(acc_text);
   bit_flag = 0x00;

   bit_flag = 0x00;
   return (widget);
   }

/* END This is taken from motifgif.c */

static Widget   CreateMenuBar(Widget    parent)     /*F*/
   {
   Widget          MFile, MEdit, MWin, MHelp;
   Widget          BOpen, BSave, BCmap, BDef, BQuit;
   Widget          BHelp, BAbout;
   Widget          menubar;
   Arg             args[20];
   char            title[STRING1];
   int             plane;

   menubar = (Widget) XmCreateMenuBar((Widget) parent, "MenuBar", args, 0);
   XtManageChild(menubar);

   MFile = XmCreatePulldownMenu(menubar, "File",       args, 0);
   MEdit = XmCreatePulldownMenu(menubar, "Edit",       args, 0);
   MWin  = XmCreatePulldownMenu(menubar, "2d slices",  args, 0);
   MHelp = XmCreatePulldownMenu(menubar, "Help",       args, 0);

   CreateCascade("File",       'F', MFile, menubar);
   CreateCascade("Edit",       'E', MEdit, menubar);
   CreateCascade("2d slices ", '2', MWin,  menubar);
   CreateCascade("Help",       'H', MHelp, menubar);

   BOpen = CreatePushButton("Open", 'O', MFile);
   XtAddCallback(BOpen, XmNactivateCallback,
                 (XtCallbackProc)file_cb, (XtPointer) 0);
   BSave = CreatePushButton("Save as", 'S', MFile);
   XtAddCallback(BSave, XmNactivateCallback,
                 (XtCallbackProc)file_cb, (XtPointer) 1);
   BCmap = CreatePushButton("Load colormap", 'L', MFile);
   XtAddCallback(BCmap, XmNactivateCallback,
                 (XtCallbackProc)file_cb, (XtPointer) 2);
   BDef  = CreatePushButton("Default colormap", 'D', MFile);
   XtAddCallback(BDef, XmNactivateCallback,
                 (XtCallbackProc)file_cb, (XtPointer) 3);
   BQuit = CreatePushButton("Quit", 'Q', MFile);
   XtAddCallback(BQuit, XmNactivateCallback,
                 (XtCallbackProc)file_cb, (XtPointer) 4);

   b_debug = CreatePushButton("Information window", 'I', MEdit);
   XtAddCallback(b_debug, XmNactivateCallback,
                 (XtCallbackProc)edit_cb, (XtPointer) 0);
   widgets->nbcut = CreatePushButton("Number of classes, min/max", 'N', MEdit);
   XtAddCallback(widgets->nbcut, XmNactivateCallback,
                 (XtCallbackProc)edit_cb, (XtPointer) 1);
   widgets->cutoff = CreatePushButton("Cutoffs values", 'C', MEdit);
   XtAddCallback(widgets->cutoff, XmNactivateCallback,
                 (XtCallbackProc)edit_cb, (XtPointer) 2);
   widgets->allcut = CreatePushButton("Change All cutoffs", 'A', MEdit);
   XtAddCallback(widgets->allcut, XmNactivateCallback,
                 (XtCallbackProc)edit_cb, (XtPointer) 3);
   XtSetSensitive(widgets->allcut, False);
   XtSetSensitive(widgets->cutoff, False);
   XtSetSensitive(widgets->nbcut, False);

   for (plane=0; plane<3; plane++)
      {
      sprintf(title, "%c=cst (%s plane)", dir[plane], pln[plane]);
      b_open[plane] = CreatePushButton(title, dir[plane], MWin);
      XtAddCallback(b_open[plane], XmNactivateCallback,
                    (XtCallbackProc)open_win2d, (XtPointer)plane);
      MySetSensitive((int)B_OPEN, plane, False);
      }

   BHelp = CreatePushButton("Help", 'H', MHelp);
   XtAddCallback(BHelp, XmNactivateCallback,
                 (XtCallbackProc)XnHelpCB, "Index");
   BAbout = CreatePushButton("About", 'A', MHelp);
   XtAddCallback(BAbout, XmNactivateCallback,
                 (XtCallbackProc)XnHelpCB, "About");
   if (!world->help_file)
      {
      XtSetSensitive(BAbout, False);
      XtSetSensitive(BHelp, False);
      }
   return (menubar);
   }

static Widget   CreateWin3dForm(Widget       parent)   /*F*/
   {
   Widget          win3d_form, win3d_frame;

   win3d_form = XtVaCreateWidget("win3d_form",
                                 xmFormWidgetClass, parent,
                                 NULL);

   win3d_frame = XtVaCreateWidget("win3d_frame",
                                  xmFrameWidgetClass,  win3d_form,
                                  XmNleftAttachment,   XmATTACH_FORM,
                                  XmNtopAttachment,    XmATTACH_FORM,
                                  XmNrightAttachment,  XmATTACH_FORM,
                                  XmNbottomAttachment, XmATTACH_FORM,
                                  NULL);


   widgets->win3d_area = XtVaCreateWidget("win3d_area",
                                  xmDrawingAreaWidgetClass, win3d_frame,
                                  XmNbackground,            widgets->white,
                                  NULL);

   XtAddCallback(widgets->win3d_area, XmNresizeCallback,
                 (XtCallbackProc)draw_win3d, NULL);
   XtManageChild(win3d_frame);
   XtManageChild(widgets->win3d_area);
   return (win3d_form);         /* return it unmanaged */
   }

static Widget   CreateCommandForm(Widget       parent)         /*F*/
   {
   Widget          command_form, refresh_3d, refresh_2ds;

   command_form = XtVaCreateWidget("command_form",
                                   xmFormWidgetClass, parent,
                                   XmNfractionBase, 4,
                                   NULL);

   refresh_3d = XtVaCreateManagedWidget("Refresh 3D",
                                      xmPushButtonGadgetClass, command_form,
                                      XmNleftAttachment,  XmATTACH_POSITION,
                                      XmNleftPosition,    0,
                                      XmNrightAttachment, XmATTACH_POSITION,
                                      XmNrightPosition,   1,
                                      NULL);
   refresh_2ds = XtVaCreateManagedWidget("Refresh 2Ds",
                                      xmPushButtonGadgetClass, command_form,
                                      XmNleftAttachment,  XmATTACH_POSITION,
                                      XmNleftPosition,    1,
                                      XmNrightAttachment, XmATTACH_POSITION,
                                      XmNrightPosition,   2,
                                      NULL);
   b_stat[THREED] = XtVaCreateManagedWidget("Statistics",
                                      xmPushButtonGadgetClass, command_form,
                                      XmNleftAttachment,  XmATTACH_POSITION,
                                      XmNleftPosition,    2,
                                      XmNrightAttachment, XmATTACH_POSITION,
                                      XmNrightPosition,   3,
                                      NULL);
   b_comp[THREED] = XtVaCreateManagedWidget("Compute",
                                      xmPushButtonGadgetClass, command_form,
                                      XmNleftAttachment,  XmATTACH_POSITION,
                                      XmNleftPosition,    3,
                                      XmNrightAttachment, XmATTACH_POSITION,
                                      XmNrightPosition,   4,
                                      NULL);

   XtAddCallback(refresh_3d,  XmNactivateCallback,
                 (XtCallbackProc)draw_win3d, NULL);
   XtAddCallback(refresh_2ds, XmNactivateCallback,
                 (XtCallbackProc)draw_win2d, (XtPointer)THREED);
   XtAddCallback(refresh_2ds, XmNactivateCallback,
                 (XtCallbackProc)draw_winst, (XtPointer)4);
   XtAddCallback(b_stat[THREED], XmNactivateCallback,
                 (XtCallbackProc)open_winst, (XtPointer)THREED);
   XtAddCallback(b_comp[THREED], XmNactivateCallback,
                 (XtCallbackProc)comp_cb, (XtPointer)THREED);
   MySetSensitive((int)B_STAT, THREED, False);
   MySetSensitive((int)B_COMP, THREED, False);

   return (command_form);       /* return it unmanaged */
   }

static void        Set_Default(void)     /*F*/
   {
   int             plane;

   world->mode    = ARITHMETIC;
   for (plane=0; plane<3; plane++)
      world->show_line[plane]=SHOW_LINE;
   world->change_trim=FALSE;
   world->comp_stat=COMP_STAT;
   world->comp_quant=COMP_QUANT;
   world->xflush=XFLUSH;
   }

static void        Create_World(void)    /*F*/
   {
   int             plane;

   world = (World_t *)malloc(sizeof(World_t));
   if (!world)   CANTALLOC(1, world, "Create_World");
   widgets = (Widgets_t *)malloc(sizeof(Widgets_t));
   if (!widgets) CANTALLOC(1, widgets, "Create_World");
   world->file    = NULL;
   world->values  = NULL;
   world->nb_var  = 0;
   world->cutoffs = NULL;
   world->nb_data = 0;
   widgets->debug_area = NULL;
   for (plane=0; plane<3; plane++)
      {
      widgets->win2d[plane]=NULL;
      widgets->win2d_area[plane]=NULL;
      world->scaling[plane]=1;
      }
   world->nb_class = 0;
   world->nb_col_int = -1; /* To show no colormap loaded */
   world->loaded = FALSE;  /* To show no file loaded     */
   set_get_hs();
   strcpy(pln[0], "yz"); strcpy(pln[1], "xz");
   strcpy(pln[2], "xy"); strcpy(pln[3], "3D");
   strcpy(dir, "XYZ");
   }

static void     bug_found(int sig,                  /* F */
                          int code,                 /* F */
                          struct sigcontext *scp,   /* F */
                          char *addr)               /* F */
   {
   printf("\nThat's Yet Another Bug in yap ... ");
   switch(sig)
      {
      case SIGFPE:   printf("Floating point error\n");  break;
      case SIGILL:   printf("Illegal instruction\n");  break;
      case SIGSEGV:  printf("Segmentation violation\n");  break;
      case SIGBUS:   printf("Bus error\n");  break;
      }
   /*printf("\nInformation:");*/
   /*printf("\n  sig:   %d", sig);*/
   /*printf("\n  code:  %d", code);*/
   signal(SIGFPE, 0); signal(SIGILL, 0); signal(SIGSEGV, 0); signal(SIGBUS, 0);
   abort();
   }

void            main(int       argc,  /*F*/
                     char      **argv)        /*F*/
   {
   Widget          main_form, menu_bar, timer_form;
   Widget          command_form, win3d_form;
   Pixmap          yaicon;
   XFontStruct    *font;
   XtAppContext    app_con;
   XGCValues       gcv;
   char            cstr[STRING1], *arg;
   int             arg_file, i, plane;
/* arg_file: 0 if no file name on command line
             1 if file on command line but doesn't exist
             2 if existing file on command line
*/

#ifdef CATCH_SIGNAL
   signal(SIGFPE,  bug_found);
   signal(SIGILL,  bug_found);
   signal(SIGSEGV, bug_found);
   signal(SIGBUS,  bug_found);
#endif

nb_refresh=1;
   print_mem("before create world");
   Create_World();              /* I'm God */
   print_mem("after create world");
   Set_Default();

   widgets->top = XtVaAppInitialize(&app_con, "Yap",
                                    NULL, 0, &argc, argv, NULL, NULL);

   arg_file=0;
/* Clean it just it case */
   sprintf(world->cmap_name, "");
   strcpy(world->prg_name, argv[0]);
/* Display info about current version,
   can be disabled by commenting next line */
   message(argv[0]);
/* Parsing command line arguments */
   if (argc > 1)
      for (i=1; i<argc; i++)
         { 
         arg=argv[i];
         if (arg[0]!='-' && (arg[0]!='+'))
            /* Not an option, should be the file name */
            {
            strcpy(world->name, argv[i]);
            printf("Input file: %s...", world->name);
/* Check if the file exists. Might be a smarter way to do that */
            if (access(world->name, R_OK)==0) /* File found and can be read */
               { arg_file=2; printf(" found\n"); 
                 strncpy(world->base, world->name, strcspn(world->name, "."));
                 world->base[strcspn(world->name, ".")]='\0';
               }
            else
               {
               arg_file=1;
               printf(" not found\n");
               }
            }
         else if (strcmp(arg, "-cc") == 0)
            {
            world->nb_class=atoi(argv[++i]);
            if (world->nb_class<0) world->nb_class=0;
                     printf("Nb classes: %d\n", world->nb_class);
            }
         else if (strcmp(arg, "-cmap") == 0)
            {
            if (getenv("CMAP_DIR"))
               {
               if (argv[i+1][0]!='/' && argv[i+1][0]!='.')
                 sprintf(world->cmap_name, "%s/%s",
                         getenv("CMAP_DIR"), argv[++i]);
               else
                 strcpy(world->cmap_name, argv[++i]);
               }

            else if (strlen(_CMAP_DIR))
                 {
                 if (argv[i+1][0]!='/' && argv[i+1][0]!='.')
                   sprintf(world->cmap_name, "%s/%s", _CMAP_DIR, argv[++i]);
                 else
                   strcpy(world->cmap_name, argv[++i]);
                 }
            else sprintf(world->cmap_name, "%s", argv[++i]);
            printf("Colormap:   %s\n", world->cmap_name);
            }
         else if (strcmp(arg, "-changetrim") == 0)
            {
            world->change_trim=TRUE;
            printf("Change trimming limits (if GSLIB file) (current: %g %g)\n",
                   T_MIN, T_MAX);
            }

         else if (strcmp(arg, "+line")==0)
            { for (plane=0; plane<3; plane++) world->show_line[plane]=TRUE; }
         else if (strcmp(arg, "-line")==0)
            { for (plane=0; plane<3; plane++) world->show_line[plane]=FALSE; }

         else if (strcmp(arg, "+quant")==0)
            { world->comp_quant=TRUE; }
         else if (strcmp(arg, "-quant")==0)
            { world->comp_quant=FALSE; }

         else if (strcmp(arg, "+stat")==0)
            { world->comp_stat=TRUE; }
         else if (strcmp(arg, "-stat")==0)
            { world->comp_stat=FALSE; }

         else if (strcmp(arg, "+xflush")==0)
            { world->xflush=TRUE; }
         else if (strcmp(arg, "-xflush")==0)
            { world->xflush=FALSE; }

         else if (strcmp(arg, "-h")==0 || strcmp(arg, "-help")==0)
            { help(argv[0]); exit(0); }
         else if (strcmp(arg, "-d")==0)
            { printf("         Default values\n"); show_defaults(1); exit(0); }
         else
            { printf("Unknown option %s\n\n", arg); help(argv[0]); exit(1); }
         }
   else
      printf("No command line arguments to parse\n");
   if (world->comp_quant) world->comp_stat=TRUE;
   show_defaults(0);
   /* Initialize Xt and create a shell widget */

   widgets->main_win = XtVaCreateWidget("main_win", xmMainWindowWidgetClass,
                               widgets->top,
                               XmNshadowThickness, 0,
                               NULL);

   /* Initialize global colors */

   widgets->white = XWhitePixel(XtDisplay(widgets->top),
                       XDefaultScreen(XtDisplay(widgets->top)));
   widgets->black = XBlackPixel(XtDisplay(widgets->top),
                       XDefaultScreen(XtDisplay(widgets->top)));

   /* Force keyboard focus policy to pointer, to get right of focus highlight */

   XtVaSetValues(widgets->top,
                 XmNkeyboardFocusPolicy, XmPOINTER,
                 NULL);

   main_form = XtVaCreateWidget("main_form",
                                xmFormWidgetClass, widgets->main_win,
                                NULL);

   world->help_file = True;
   if (!XnInitializeHelp(app_con, widgets->top, _HELP_FILE, True))
      world->help_file = False;

   menu_bar = CreateMenuBar(main_form);
   XtVaSetValues(menu_bar,
                 XmNleftAttachment, XmATTACH_FORM,
                 XmNtopAttachment, XmATTACH_FORM,
                 XmNrightAttachment, XmATTACH_FORM,
                 NULL);

   command_form = CreateCommandForm(main_form);
   XtVaSetValues(command_form,
                 XmNbottomAttachment, XmATTACH_FORM,
                 XmNleftAttachment, XmATTACH_FORM,
                 XmNrightAttachment, XmATTACH_FORM,
                 NULL);

   timer_form = CreateTimerForm(main_form);
   XtVaSetValues(timer_form,
                 XmNleftAttachment,   XmATTACH_FORM,
                 XmNrightAttachment,  XmATTACH_FORM,
                 XmNbottomAttachment, XmATTACH_WIDGET,
                 XmNbottomWidget,     command_form,
                 NULL);

   win3d_form = CreateWin3dForm(main_form);
   XtVaSetValues(win3d_form,
                 XmNtopAttachment, XmATTACH_WIDGET,
                 XmNtopWidget, menu_bar,
                 XmNleftAttachment, XmATTACH_FORM,
                 XmNrightAttachment, XmATTACH_FORM,
                 XmNbottomAttachment, XmATTACH_WIDGET,
                 XmNbottomWidget, timer_form,
                 NULL);


   XtManageChild(command_form);
   XtManageChild(win3d_form);
   XtManageChild(timer_form);
   XtManageChild(menu_bar);
   XtManageChild(main_form);
   XtManageChild(widgets->main_win);

   XtRealizeWidget(widgets->top);

   widgets->dpy = XtDisplay(widgets->top);

   yaicon = XCreateBitmapFromData(XtDisplay(widgets->top),
                                DefaultRootWindow(XtDisplay(widgets->top)),
                                yaicon_bits, yaicon_width, yaicon_height);
   XtVaSetValues(widgets->top, XtNiconPixmap, yaicon, XtNiconMask, yaicon, NULL);

   font = XLoadQueryFont(widgets->dpy, "fixed");
   if (!font)
      {
      fprintf(stderr, "Couldn't find font fixed");
      exit(0);
      }
   gcv.font = font->fid;
   widgets->gc = XCreateGC(widgets->dpy, XtWindow(widgets->top),
                  GCFont | GCForeground | GCBackground, &gcv);

   if (!world->help_file)
      PostDialog(widgets->top, XmDIALOG_ERROR, "Warning",
                 "Help file not found", "OK");

   /*create_debug();*/

   if (arg_file==1) /* asked but not found */
      {
      sprintf(cstr, "Data file %s not found", world->name);
      PostDialog(widgets->top, XmDIALOG_ERROR, "Warning",
                 cstr, "OK");
      }
   if (arg_file==2)
      if (!file_check(world->name))
         {
         sprintf(cstr, "Sorry, i can't read %s (see info window)", world->name);
         PostDialog(widgets->top, XmDIALOG_ERROR, "File", cstr, "Stupid");
         }
      else
         {
         XtSetSensitive(widgets->allcut, True);
         XtSetSensitive(widgets->cutoff, True);
         XtSetSensitive(widgets->nbcut, True);
         varia_fn();
         }
   else world->change_trim=TRUE;

   print_mem("before main loop");

   /* Go into the event loop */

   XtAppMainLoop(app_con);
   }
