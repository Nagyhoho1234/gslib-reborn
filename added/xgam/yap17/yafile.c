
#include <Xm/FileSB.h>
#include <Xm/Form.h>
#include <Xm/RowColumn.h>
#include <Xm/LabelG.h>
#include <Xm/TextF.h>
#include <Xm/ToggleB.h>
#include <Xm/ToggleBG.h>
#include <Xm/DialogS.h>
#include <Xm/PushBG.h>
#include <X11/cursorfont.h>
#include "yap.h"
#include "NXHelp.h"

extern World_t   *world;
extern Widgets_t *widgets;

static int      f_type;
static Widget   savew_txt;

static void     cancel_read_fn(Widget                       dialog,      /*F*/
                        XtPointer                           un1,         /*F*/
                        XmFileSelectionBoxCallbackStruct   *cbs)         /*F*/
   {
   world->refresh=TRUE;
   XtUnmanageChild(dialog);
   }

static void     read_fn(Widget                              dialog,      /*F*/
                        XtPointer                           un1,         /*F*/
                        XmFileSelectionBoxCallbackStruct   *cbs)         /*F*/
   {
   char           *fn=NULL;
   char            cstr[STRING1];

   if (cbs)
      {
      if (!XmStringGetLtoR(cbs->value, XmSTRING_DEFAULT_CHARSET, &fn))
         return;
      if (!file_check(fn))
         {
         sprintf(cstr, "Sorry, i can't read %s (see info window)", fn);
         PostDialog(widgets->top, XmDIALOG_ERROR, "File", cstr, "Stupid");
         world->refresh=FALSE;
         NewCursor(dialog, None);
         return;
         }
      }
   XtUnmanageChild(dialog);
   XtSetSensitive(widgets->cutoff, True);
   XtSetSensitive(widgets->nbcut,  True);
   XtSetSensitive(widgets->allcut, True);
   varia_fn();
   }

static void     toggle_changed(Widget                         un1,    /*F*/
                               int                            which,  /*F*/
                               XmToggleButtonCallbackStruct  *un2)    /*F*/
   {
   char           *name;
   char            base[STRING1];

   f_type = which;
   name = XmTextFieldGetString(savew_txt);
   strncpy(base, name, strcspn(name, "."));
   base[strcspn(name, ".")]='\0';
   switch(f_type)
      {
      case GSLIB:    strcat(base, ".gsl");
                     break;
      case FBINARY:  strcat(base, ".fbin");
                     break;
      case CLASSBIN: strcat(base, ".lbin");
                     break;
      case CBINARY:  strcat(base, ".cbin");
                     break;
      }
   XtVaSetValues(savew_txt, XmNvalue, base, NULL);
   free(name);
   }

static void     save_cancel_cb(Widget           un1,       /*F*/
                               Widget           dialog,    /*F*/
                               XtPointer        un2)       /*F*/
   {
   p_area(widgets->debug_area, "SAVE -> Cancelled\n");
   world->refresh=TRUE;
   XtDestroyWidget(dialog);
   }

static void     save_ok_cb(Widget               un1,       /*F*/
                           Widget               dialog,    /*F*/
                           XtPointer            un2)       /*F*/
   {
   char           *name;
   char            cstr[STRING1];

   name=XmTextFieldGetString(savew_txt);
   p_area(widgets->debug_area, "SAVE -> Saving the file in ");
   switch (f_type)
      {
      case GSLIB:
         p_area(widgets->debug_area, "gslib format\n");              break;
      case FBINARY:
        p_area(widgets->debug_area, "float binary format\n");        break;
      case CLASSBIN:
        p_area(widgets->debug_area, "char binary format (class)\n"); break;
      case CBINARY:
        p_area(widgets->debug_area, "char binary format\n");         break;
      }
   if (!file_save(name, f_type))
      {
      sprintf(cstr, "Couldn't write to %s", name);
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error", cstr, "That's strange");
      free(name);
      return;
      }
   sprintf(cstr, "File %s written", name);
   PostDialog(widgets->top, XmDIALOG_INFORMATION, "Saving successful",
              cstr, "Right");
   world->refresh=TRUE;
   XtDestroyWidget(dialog);
   free(name);
   }

void            save_fn(void)         /*F*/
   {
   char            cstr[STRING1];
   XmString        str;
   Widget          savew, savew_form, savew_radiobox;
   Widget          toggle_gsl, toggle_bin, toggle_cbin, toggle_class;
   Widget          savew_button, savew_rowc_frame, savew_rowc;
   Widget          savew_ok, savew_help, savew_radiobox_form, savew_cancel;

   world->refresh=FALSE;
   str = XmStringCreateSimple("Save file");
   savew = XtVaCreatePopupShell("Save",
                            xmDialogShellWidgetClass, widgets->top,
                            XmNmwmFunctions,   30,
                            XmNdialogStyle,    XmDIALOG_FULL_APPLICATION_MODAL,
                            XmNdialogTitle,    str,
                            NULL);

   savew_form = XtVaCreateWidget("savew_form",
                                 xmFormWidgetClass, savew,
                                 NULL);
   savew_rowc_frame = XtVaCreateManagedWidget("savew_rowc_frame",
                                          xmFrameWidgetClass, savew_form,
                                          XmNtopAttachment,   XmATTACH_FORM,
                                          XmNleftAttachment,  XmATTACH_FORM,
                                          XmNrightAttachment, XmATTACH_FORM,
                                          NULL);

   savew_rowc = XtVaCreateWidget("savew_rowc",
                                 xmRowColumnWidgetClass, savew_rowc_frame,
                                 XmNpacking, XmPACK_COLUMN,
                                 XmNnumColumns, 1,
                                 XmNorientation, XmHORIZONTAL,
                                 XmNisAligned, True,
                                 NULL);
   sprintf(cstr, "%s.gsl", world->base);
   savew_txt = XtVaCreateManagedWidget("savew_txt",
                                       xmTextFieldWidgetClass, savew_rowc,
                                       XmNvalue, cstr,
                                       NULL);
   savew_radiobox_form = XtVaCreateManagedWidget("savew_radiobox",
                                       xmRowColumnWidgetClass, savew_form,
                                       XmNpacking,             XmPACK_COLUMN,
                                       XmNnumColumns,          3,
                                       XmNorientation,         XmHORIZONTAL,
                                       XmNisAligned,           True,
                                       XmNtopAttachment,       XmATTACH_WIDGET,
                                       XmNtopWidget,           savew_rowc_frame,
                                       XmNleftAttachment,      XmATTACH_FORM,
                                       XmNrightAttachment,     XmATTACH_FORM,
                                       NULL);

   savew_radiobox = XmCreateRadioBox(savew_radiobox_form, "savew_radiobox",
                                      NULL, 0);
   toggle_gsl = XtVaCreateManagedWidget("GSLIB format",
                                      xmToggleButtonGadgetClass, savew_radiobox,
                                      NULL);
   toggle_bin = XtVaCreateManagedWidget("BINARY float format",
                                      xmToggleButtonGadgetClass, savew_radiobox,
                                      NULL);
   toggle_cbin = XtVaCreateManagedWidget("BINARY char format",
                                      xmToggleButtonGadgetClass, savew_radiobox,
                                      NULL);
   toggle_class = XtVaCreateManagedWidget("BINARY char format (class)",
                                      xmToggleButtonGadgetClass, savew_radiobox,
                                      NULL);
   savew_button = XtVaCreateManagedWidget("savew_button",
                                      xmRowColumnWidgetClass, savew_form,
                                      XmNtopAttachment, XmATTACH_WIDGET,
                                      XmNtopWidget, savew_radiobox_form,
                                      XmNleftAttachment, XmATTACH_FORM,
                                      XmNrightAttachment, XmATTACH_FORM,
                                      XmNnumColumns, 1,
                                      XmNorientation, XmHORIZONTAL,
                                      NULL);

   savew_ok = XtVaCreateManagedWidget("Save",
                                      xmPushButtonGadgetClass, savew_button,
                                      NULL);
   savew_cancel = XtVaCreateManagedWidget("Cancel",
                                      xmPushButtonGadgetClass, savew_button,
                                      NULL);
   savew_help = XtVaCreateManagedWidget("Help",
                                      xmPushButtonGadgetClass, savew_button,
                                      NULL);

   XtAddCallback(toggle_gsl, XmNvalueChangedCallback,
                 (XtCallbackProc)toggle_changed, (XtPointer) GSLIB);
   XtAddCallback(toggle_bin, XmNvalueChangedCallback,
                 (XtCallbackProc)toggle_changed, (XtPointer) FBINARY);
   XtAddCallback(toggle_class, XmNvalueChangedCallback,
                 (XtCallbackProc)toggle_changed, (XtPointer) CLASSBIN);
   XtAddCallback(toggle_cbin, XmNvalueChangedCallback,
                 (XtCallbackProc)toggle_changed, (XtPointer) CBINARY);
   XtAddCallback(savew_cancel, XmNactivateCallback,
                 (XtCallbackProc)save_cancel_cb, (XtPointer) savew);
   XtAddCallback(savew_ok, XmNactivateCallback,
                 (XtCallbackProc)save_ok_cb, (XtPointer) savew);
   XtAddCallback(savew_help, XmNactivateCallback,
                 (XtCallbackProc)XnHelpCB, "Save as");

   XmToggleButtonSetState(toggle_gsl, True, False);
   f_type = GSLIB;
   XtManageChild(savew_radiobox);
   XtManageChild(savew_rowc);
   XtManageChild(savew_form);
   XtManageChild(savew);
   }

void            open_fn(void)         /*F*/
   {
   static Widget   dialog;
   XmString        title;

   title=XmStringCreateSimple("File selection");

   world->refresh=FALSE;
   if (!dialog)
      {
      dialog = XmCreateFileSelectionDialog(widgets->top, "File selection",
                                           NULL, 0);
      XtAddCallback(dialog, XmNokCallback, (XtCallbackProc)read_fn, NULL);
      XtAddCallback(dialog, XmNcancelCallback,
                    (XtCallbackProc)cancel_read_fn, NULL);
      XtAddCallback(dialog, XmNhelpCallback, (XtCallbackProc)XnHelpCB, "Open");
      XtVaSetValues(dialog, XmNdialogTitle, title,
                    XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
                    NULL);
      }
   XtManageChild(dialog);
   XtPopup(XtParent(dialog), XtGrabNone);
   XmStringFree(title);
   }
