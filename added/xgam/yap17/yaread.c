#include <Xm/ToggleB.h>
#include <Xm/ToggleBG.h>
#include <Xm/Form.h>
#include <Xm/Frame.h>
#include <Xm/DialogS.h>
#include <Xm/RowColumn.h>
#include <Xm/LabelG.h>
#include <Xm/TextF.h>
#include <Xm/PushBG.h>
#include <X11/cursorfont.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "yap.h"
#include "yaconfig.h"

extern World_t   *world;
extern Widgets_t *widgets;

static Widget     misc_txt[6];

static char **var_names;

static void     varia_select_cb(Widget        un1,       /*F*/
                                Widget        dialog,    /*F*/
                                XtPointer     un2)       /*F*/
   {
   char           *string[2];
   int             i;
   float           t_min, t_max;

   string[0] = XmTextFieldGetString(misc_txt[0]);
   string[1] = XmTextFieldGetString(misc_txt[1]);

   if (sscanf(string[0], "%f", &t_min)!=1
    || sscanf(string[1], "%f", &t_max)!=1)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please check that you entered numbers!", "I'll do that");
      free(string[0]); free(string[1]);
      return;
      }
   p_area(widgets->debug_area, "READ -> tmin:     %g\n        tmax:     %g\n", t_min, t_max);

   if (t_min>=t_max)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Try tmax > tmin!", "OK");
      free(string[0]); free(string[1]);
      return;
      }
   world->t_min = t_min;
   world->t_max = t_max;
   strcpy(world->var_name, var_names[world->var_no]);
   p_area(widgets->debug_area, "READ -> Variable: %s\n", world->var_name);
   for (i=0; i<world->nb_var; i++) free(var_names[i]);
   XtDestroyWidget(dialog);
   free(string[0]); free(string[1]);
   p_area(widgets->debug_area, "READ -> Reading the file\n");
   file_read();
   param_fn();
   }


static void     param_set_cb(Widget        un1,       /*F*/
                             Widget        dialog,    /*F*/
                             XtPointer     un2)       /*F*/
   {
   int             i, nb_color = world->nb_class + 2;   /* set value in case we
                                                         * don't have to change
                                                         * the colormap */
   int             ival[3], nb_class;
   float           fval[2];
   char            msg[STRING1], *string[6];

   for (i=0; i<6; i++) string[i]=XmTextFieldGetString(misc_txt[i]);
   if (sscanf(string[0], "%d", &ival[0])!=1
    || sscanf(string[1], "%d", &ival[1])!=1
    || sscanf(string[2], "%d", &ival[2])!=1
    || sscanf(string[3], "%d", &nb_class)!=1
    || sscanf(string[4], "%f", &fval[0])!=1
    || sscanf(string[5], "%f", &fval[1])!=1)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please check that you entered numbers!", "I'll do that");
      for (i=0; i<6; i++) free(string[i]);
      return;
      }

   for (i=0; i<6; i++) free(string[i]);

   if (ival[0]<1 || ival[1]<1 || ival[2]<1)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please check that you entered numbers > 0", "Good idea");
      return;
      }

   if (nb_class<2)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please give a number of classes > 1", "OK");
      return;
      }

/* Could check also that fval[0] not > max, etc */
   if (fval[0]>=fval[1])
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
          "Let's try to have a maximum greater than the minimum", "Indeed");
      return;
      }

   p_area(widgets->debug_area, "READ -> Nb_data=%d, %dx%dx%d=%d\n",
          world->nb_data, ival[0], ival[1], ival[2], ival[0]*ival[1]*ival[2]);

   if (ival[0]*ival[1]*ival[2]>world->nb_data)
      {
      sprintf(msg, "Number of data = %d < %d x %d x %d ...",
              world->nb_data, ival[0], ival[1], ival[2]);
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error", msg, "Maybe");
      return;
      }
   for (i=0; i<3; i++)
      { world->n[i]=ival[i]; world->sld[i]=0; }

   world->show_min=fval[0];
   world->show_max=fval[1];
   nb_color=Get_Colormap(0, nb_class, world->nb_col_int);
   XtUnmanageChild(dialog); XtDestroyWidget(dialog);
   for (i=0; i<3; i++)
      {
      if (widgets->slide[i])
         {
         XtVaSetValues(widgets->slide[i],
                          XmNminimum,   1,
                          XmNvalue,     1,
                          NULL);
         if (world->n[i]>1)
            XtVaSetValues(widgets->slide[i],
                          XmNmaximum, world->n[i],
                          XmNsensitive, True,
                          NULL);
         else
            XtVaSetValues(widgets->slide[i],
                          XmNmaximum,   2,
                          XmNsensitive, False,
                          NULL);
         }
       else MySetSensitive((int)B_OPEN, i, True);
      }
   world->nb_class = nb_color-2;      /* really allocated */
   NewCursor(widgets->win3d_area, XC_watch);
   init_2d_indexes(); init_3d_indexes();
   if (world->nb_col_int < 0)
      {
      if (strlen(world->cmap_name) != 0)
         { if (!read_cmap(world->cmap_name)) read_cmap(NULL); }
      else default_cmap();
      }
   else
      {
      set_default_cutoffs();
      get_class_table();
      }
   if (world->comp_stat) init_compute();
   if (nb_color!=nb_class+2)
      {
      sprintf(string[0], "Could only allocate %d colors out of %d",
                    nb_color, nb_class+2);
      PostDialog(widgets->top, XmDIALOG_ERROR, "Warning",
                 string[0], "Too bad");
      }
   world->loaded=TRUE;
   world->refresh=TRUE;
   refresh_all();
   }

static void     varia_cb(Widget                          un1,   /*F*/
                         int                             which, /*F*/
                         XmToggleButtonCallbackStruct   *un2)   /*F*/
   {
   world->var_no = which;
   }

static BOOLEAN  steve_check(void)        /*F*/
   {
   rewind(world->file);
   p_area(widgets->debug_area, "READ -> File checked, seems OK\n");
   return (TRUE);
   }

static BOOLEAN  steve_read(void)         /*F*/
   {
   FILE           *file = world->file;
   int            *v, i;
   int             an_int;
   float           a_float;

   rewind(world->file);
   fread(&an_int, sizeof(int), 1, file);
   fread(&an_int, sizeof(int), 1, file);
   fread(&an_int, sizeof(int), 1, file);
   fread(&world->n[X], sizeof(int), 1, file);
   fread(&world->n[Y], sizeof(int), 1, file);
   fread(&world->n[Z], sizeof(int), 1, file);
   if (world->n[X]<=0 || world->n[Y]<=0 || world->n[Z]<=0)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a STEVE file\n");
        return (FALSE); }
   p_area(widgets->debug_area,
          "READ -> %dx%dx%d\n", world->n[X], world->n[Y], world->n[Z]);
   for (i=0; i<8; i++)
      fread(&a_float, sizeof(float), 1, file);
   world->nb_data = world->n[X] * world->n[Y] * world->n[Z];
   if (world->values) free(world->values);
   world->values=(float *)calloc(world->nb_data, sizeof(float));
   if (!world->values)
      {
      p_area(widgets->debug_area,
             "READ -> After all, it doesn't seem to be a STEVE file");
      p_area(widgets->debug_area,
             "        Couldn't allocate memory for %d data\n", world->nb_data);
      world->file=NULL;
      return (FALSE);
      }
   v=(int *)calloc(world->nb_data, sizeof(int));
   if (!v)
      {
      p_area(widgets->debug_area,
             "READ -> After all, it doesn't seem to be a STEVE file");
      p_area(widgets->debug_area,
             "        Couldn't allocate memory for %d data\n", world->nb_data);
      free(world->values);
      world->file = NULL;
      return (FALSE); }

   if (!fread(v, world->nb_data * sizeof(int), 1, file))
      {
      p_area(widgets->debug_area,
             "READ -> After all, it doesn't seem to be a STEVE file");
      p_area(widgets->debug_area,
             "        Couldn't read data\n");
      free(world->values);
      free(v);
      return (FALSE); }

   world->min=  VERYBIG;
   world->max= -VERYBIG;
   for (i=0; i<world->nb_data; i++)
      {
      world->values[i]=(float)v[i];
      if (world->values[i]>world->max) world->max=world->values[i];
      if (world->values[i]<world->min) world->min=world->values[i];
      }
   world->nb_var=1;
   world->var_no=0;
   /*free(world->values);*/     /* What's that ? */
   free(v);
   return(TRUE);
   }

static BOOLEAN  bin_check(void)     /*F*/
   {
   rewind(world->file);
   /* Simple check could be: length of the file */
   p_area(widgets->debug_area, "READ -> File checked, seems OK\n");
   return (TRUE);
   }

static BOOLEAN  cbin_read(void)   /*F*/
   {
   FILE           *file=world->file;
   int             magic, i;
   signed char    *tmp_val;

   rewind(file);
   fread(&magic, sizeof(int), 1, file);
   fread(world->title, sizeof(world->title), 1, file);
   fread(world->var_name, sizeof(world->var_name), 1, file);
   fread(&world->min, sizeof(world->min), 1, file);
   fread(&world->max, sizeof(world->max), 1, file);
   fread(world->n, sizeof(world->n), 1, file);
   if (world->n[X]<=0 || world->n[Y]<=0 || world->n[Z]<=0)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a CBINARY file\n");
        p_area(widgets->debug_area,
               "        Grid dimensions not correct (%d %d %d)\n",
               world->n[X], world->n[Y], world->n[Z]);
        return (FALSE); }
   fread(&world->nb_saved, sizeof(int), 1, file);
   p_area(widgets->debug_area,
          "READ -> Title:      %s\nREAD -> Variable: %s\n",
          world->title, world->var_name);
   p_area(widgets->debug_area,
          "READ -> Minimum:    %g\n        Maximum:    %g\n",
          world->min, world->max);
   p_area(widgets->debug_area, "READ -> Dimensions: %dx%dx%d, %d saved\n",
                 world->n[X], world->n[Y], world->n[Z], world->nb_saved);
   world->nb_data = world->n[X] * world->n[Y] * world->n[Z] * world->nb_saved;
   tmp_val=(signed char *)calloc(world->nb_data, sizeof(signed char));

   if (world->values) free(world->values);
   world->values =(float *)calloc(world->nb_data, sizeof(float));
   if (!world->values)
      { p_area(widgets->debug_area,
              "READ -> After all, it doesn't seem to be a CBINARY file\n");
        p_area(widgets->debug_area,
              "        Couldn't allocate memory for %d data\n", world->nb_data);
        free(tmp_val);
        return (FALSE); }
   fread(tmp_val, world->nb_data*sizeof(signed char), 1, file);
   for (i=0; i<world->nb_data; i++) world->values[i] = (float)tmp_val[i];
   world->nb_var = 1;
   world->var_no = 0;
   world->nb_class=world->max-world->min+1;
   free(tmp_val);
   return (TRUE);
   }

static BOOLEAN  fbin_read(void)   /*F*/
   {
   FILE           *file = world->file;
   int             magic;

   rewind(file);
   fread(&magic, sizeof(int), 1, file);
   fread(world->title, sizeof(world->title), 1, file);
   fread(world->var_name, sizeof(world->var_name), 1, file);
   fread(&world->min, sizeof(world->min), 1, file);
   fread(&world->max, sizeof(world->max), 1, file);
   fread(world->n, sizeof(world->n), 1, file);
   if (world->n[X]<=0 || world->n[Y]<=0 || world->n[Z]<=0)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a FBINARY file\n");
        p_area(widgets->debug_area,
               "        Grid dimensions not correct (%d %d %d)\n",
               world->n[X], world->n[Y], world->n[Z]);
        return (FALSE); }
   fread(&world->nb_saved, sizeof(int), 1, file);
   p_area(widgets->debug_area,
          "        Title:      %s\nREAD -> Variable: %s\n",
          world->title, world->var_name);
   p_area(widgets->debug_area,
          "        Minimum:    %g\n        Maximum:    %g\n",
          world->min, world->max);
   p_area(widgets->debug_area,
          "        Dimensions: %dx%dx%d, %d saved\n",
          world->n[X], world->n[Y], world->n[Z], world->nb_saved);
   world->nb_data = world->n[X] * world->n[Y] * world->n[Z] * world->nb_saved;
   if (world->values) free(world->values);
   world->values=(float *)calloc(world->nb_data, sizeof(float));
   if (!world->values)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a FBINARY file\n");
        p_area(widgets->debug_area,
              "        Couldn't allocate memory for %d data\n", world->nb_data);
        return (FALSE); }
   fread(world->values, world->nb_data * sizeof(float), 1, file);
   world->nb_var = 1;
   world->var_no = 0;
   return (TRUE);
   }

static BOOLEAN  gsl_read(void)   /*F*/
   {
   char            string[STRING2];
   float           t_min = world->t_min;
   float           t_max = world->t_max;
   int             i, j, answer;
   float           val;
   float           min = VERYBIG;
   float           max = -VERYBIG;

   if (world->values) free(world->values);
   world->values=(float *)calloc(world->nb_data, sizeof(float));
   if (!world->values)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a GSLIB file\n");
        p_area(widgets->debug_area,
              "        Couldn't allocate memory for %d data\n", world->nb_data);
        return (FALSE); }

   /*for (i=0; i<world->nb_var; i++)*/
      /*if (!strcmp(var_names[i], world->var_name)) { world->var_no=i; break; }*/

   rewind(world->file);
   for (i=0; i<world->nb_var+2; i++)
      fgets(string, STRING2, world->file);

   for (i=0; i<world->nb_data; i++)
      {
      for (j=0; j<world->nb_var; j++)
         {
         fscanf(world->file, "%s", string);
         answer=sscanf(string, "%f", &val);
         if (answer!=1) return (FALSE);
         if (world->var_no==j)
            {
            if (val>t_min && val<t_max)
               { if (val>max) max=val; if (val<min) min=val; }
            world->values[i]=val;
            }
         }
      if (world->nb_data>10)
         if (!(i%(world->nb_data/10))) set_timer((float)(i+1)/world->nb_data);
      }
   world->min = min;
   world->max = max;
   p_area(widgets->debug_area,
          "READ -> Title:      %s\nREAD -> Variable:   %s\n",
          world->title, world->var_name);
   p_area(widgets->debug_area,
          "READ -> Minimum:    %g\n        Maximum:    %g\n",
          world->min, world->max);
   return (TRUE);
   }

static BOOLEAN gsl_check(void)     /*F*/
   {
   int             i, j, nb_data = 0;
   char            string1[STRING2];

   rewind(world->file);
   p_area(widgets->debug_area, "GSLIB, it seems\n");

   if (!fgets(world->title, STRING2, world->file))
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a GSLIB file\n");
        return (FALSE); }
/* Remove the '\n' at the end (because of fgets) */
   world->title[strlen(world->title)-1]='\0';

   if (!fgets(string1, STRING2, world->file))
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a GSLIB file\n");
        return (FALSE); }

/* This should be the number of variables, let's check it */
/* Let's see if it's not even an extended GSLIB file      */
/* The second line should be, in this case:               */
/* nb_var nx ny nz                                        */

   world->n[X]=0; world->n[Y]=0; world->n[Z]=0;
   sscanf(string1, "%d%d%d%d", &world->nb_var, &world->n[X],
                               &world->n[Y],   &world->n[Z]);

   if (world->nb_var<=0)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a GSLIB file\n");
        p_area(widgets->debug_area,
               "        can't get number of variables\n");
        return (FALSE); }

   if (world->n[X]>0&&world->n[Y]>0&&world->n[Z]>0) world->type=EXTGSL;

   var_names=(char **)malloc(sizeof(char *));
   if (!var_names)
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a GSLIB file\n");
        p_area(widgets->debug_area,
               "        Couldn't allocate memory for variable names\n");
        return(FALSE);
      }
   for (i=0; i<world->nb_var; i++)
      {
      var_names[i]=(char *)calloc(STRING1, sizeof(char));
      if (!var_names[i])
         { p_area(widgets->debug_area,
                  "READ -> After all, it doesn't seem to be a GSLIB file\n");
           p_area(widgets->debug_area,
                  "        Couldn't allocate memory for variable names\n");
           for (j=0; j<i; j++) free(var_names[j]);
           free(var_names);
           return(FALSE); }

      if (!fgets(var_names[i], STRING1, world->file))
      { p_area(widgets->debug_area,
               "READ -> After all, it doesn't seem to be a GSLIB file\n");
        p_area(widgets->debug_area,
               "        Can't get variables\n");
        for (j=0; j<=i; j++) free(var_names[j]);
        free(var_names);
        return (FALSE); }
      var_names[i][strlen(var_names[i])-1]='\0';
      }

   while (fgets(string1, STRING2, world->file)) nb_data++;

   if (!nb_data)
      { p_area(widgets->debug_area,
               "READ -> No data in file\n");
        for (i=0; i<world->nb_var; i++) free(var_names[i]);
        free(var_names);
        return (FALSE); }
   world->nb_data=nb_data;
   return(TRUE);
   }

static int      file_type(void)   /*F*/
   {
   int             i, magic;
   char            a_char;

   fread(&magic, sizeof(int), 1, world->file);
   if (magic == FMAGIC) return (FBINARY);
   if (magic == CMAGIC) return (CBINARY);

/* Now look if it's a binary or ascii file */
   for (i = 0; i < 10000; i++)
      {
      if (!fread(&a_char, sizeof(char), 1, world->file)) break;
      if (!isascii(a_char)) return (STEVE);
      }
   return (GSLIB);
   /* Don't rewind the file */
   }

BOOLEAN         file_check(char         *filename)       /*F*/
   {
   int             answer;

   world->file = fopen(filename, "r");

   if (!world->file)
      {
      p_area(widgets->debug_area, "READ -> file %s not found\n", world->name);
      return (FALSE);
      }
   NewCursor(widgets->top, XC_watch);
   init_timer("Checking");
   p_area(widgets->debug_area,
          "READ -> Looking for format of %s: ", world->name);
   world->type = file_type();
   switch (world->type)
      {
   case STEVE:

/* This option is not allowed here, because it generated bugs
because a binary file not recognized as "FBINARY or CBINARY" (my format)
was by default a STEVE format. Therefore, big mess if we try to
read something completely different (.o for example).
If you are using steve's format, comment the next line and uncomment the
following. But be careful not to read something different! */

      p_area(widgets->debug_area, "unknown, cannot read this file\n");
      /*p_area(widgets->debug_area, "'STEVE'\n"); answer=steve_check(filename); break;*/
      answer = FALSE; break;

   case FBINARY:
      p_area(widgets->debug_area, "BINARY float\n");
      answer = bin_check(); break;

   case CBINARY:
      p_area(widgets->debug_area, "BINARY char\n");
      answer = bin_check(); break;

   case GSLIB:
      if (!gsl_check()) {answer = FALSE; break;}
/* The type can be changed to EXTGSL in the function gsl_check */
      if (world->type == EXTGSL)
         p_area(widgets->debug_area, "        even extended GSLIB!\n");
      p_area(widgets->debug_area, "READ -> File checked, seems OK\n");
      answer = TRUE; break;

   default:
      p_area(widgets->debug_area, "unknown, cannot read this file\n");
      answer = FALSE; break;
      }
   set_timer((float)1.0);
   NewCursor(widgets->top, None);
   strcpy(world->name, filename);
   return(answer);
   }

BOOLEAN         file_read(void)     /*F*/
   {
   BOOLEAN first_loaded, answer;
   char    title[STRING1];

   print_mem("before loading file");
   if (world->loaded) first_loaded=FALSE;
   else               first_loaded=TRUE;
   NewCursor(widgets->top, XC_watch);
   init_timer("Reading");
   switch (world->type)
      {
   case STEVE:   answer=steve_read(); break;
   case FBINARY: answer=fbin_read();  break;
   case CBINARY: answer=cbin_read();  break;
   case GSLIB:
   case EXTGSL:  answer=gsl_read();   break;
   default:      answer=FALSE;
      }
   world->mode = ARITHMETIC;
   NewCursor(widgets->top, None);
   if (answer==FALSE)
      world->n[X]=0;
   else
      if (first_loaded && world->comp_stat)
         {
         MySetSensitive((int)B_STAT, THREED, True);
         /*if (world->nb_var==1)*/
            MySetSensitive((int)B_COMP, THREED, True);
/* Because bug */
         }
   set_timer((float)1.0);
   strncpy(world->base, world->name, strcspn(world->name, "."));
   world->base[strcspn(world->name, ".")]='\0';
   sprintf(title, "%s - %s", world->prg_name, world->name);
   XtVaSetValues(XtParent(widgets->main_win), XtNtitle, title, NULL);
   print_mem("after loading file");
   return(answer);
   }

void            param_fn(void)        /*F*/
{
   Widget          param, param_frame, param_form, msg_form;
   Widget          rowc_frame, rowc, button, msg_box, lbl[4];
   XmString        str_msg;
   char            string[256];
   int             i;

   /*str_title = XmStringCreateSimple("Parameters selection");*/
   param = XtVaCreatePopupShell("Parameters",
                      xmDialogShellWidgetClass, widgets->top,
                      XmNmwmFunctions,          30,
                      XmNdialogStyle,           XmDIALOG_FULL_APPLICATION_MODAL,
                      /*XmNdialogTitle,           str_title,*/
                      NULL);

   /*XmStringFree(str_title);*/

   param_frame = XtVaCreateWidget("param_frame",
                                  xmFrameWidgetClass, param,
                                  NULL);

   param_form = XtVaCreateManagedWidget("param_form",
                                        xmFormWidgetClass, param_frame,
                                        NULL);

   msg_form = XtVaCreateManagedWidget("msg_form",
                                      xmFormWidgetClass, param_form,
                                      XmNtopAttachment, XmATTACH_FORM,
                                      XmNleftAttachment, XmATTACH_FORM,
                                      XmNrightAttachment, XmATTACH_FORM,
                                      XmNmarginHeight, 5,
                                      XmNmarginWidth, 5,
                                      NULL);

   sprintf(string,
        "File:     %s\nTitle:    %s\nVariable: %s\n%d data, min=%g, max=%g",
           world->name, world->title, world->var_name,
           world->nb_data, world->min, world->max);
   str_msg = XmStringCreateLtoR(string, "charset");
   msg_box = XtVaCreateManagedWidget("message",
                                 xmLabelGadgetClass, msg_form,
                                 XmNalignment, XmALIGNMENT_BEGINNING,
                                 XmNlabelString, str_msg,
                                 XmNtopAttachment, XmATTACH_FORM,
                                 XmNleftAttachment, XmATTACH_FORM,
                                 XmNrightAttachment, XmATTACH_FORM,
                                 NULL);

   rowc_frame = XtVaCreateManagedWidget("rowc_frame",
                                        xmFrameWidgetClass, param_form,
                                        XmNtopAttachment, XmATTACH_WIDGET,
                                        XmNtopWidget, msg_form,
                                        XmNleftAttachment, XmATTACH_FORM,
                                        XmNrightAttachment, XmATTACH_FORM,
                                        NULL);

   rowc = XtVaCreateWidget("rowc",
                           xmRowColumnWidgetClass, rowc_frame,
                           XmNpacking, XmPACK_COLUMN,
                           XmNnumColumns, 6,
                           XmNorientation, XmHORIZONTAL,
                           XmNisAligned, True,
                           NULL);

   lbl[0] = XtVaCreateManagedWidget("Number of pixels in x: ",
                                    xmLabelGadgetClass, rowc,
                                    NULL);
   misc_txt[0] = XtVaCreateManagedWidget("x_win",
                                         xmTextFieldWidgetClass, rowc,
                                         NULL);
   lbl[1] = XtVaCreateManagedWidget("Number of pixels in y: ",
                                    xmLabelGadgetClass, rowc,
                                    NULL);
   misc_txt[1] = XtVaCreateManagedWidget("y_win",
                                         xmTextFieldWidgetClass, rowc,
                                         NULL);
   lbl[2] = XtVaCreateManagedWidget("Number of pixels in z: ",
                                    xmLabelGadgetClass, rowc,
                                    NULL);
   misc_txt[2] = XtVaCreateManagedWidget("z_win",
                                         xmTextFieldWidgetClass, rowc,
                                         NULL);
   lbl[3] = XtVaCreateManagedWidget("Number of classes: ",
                                    xmLabelGadgetClass, rowc,
                                    NULL);
   misc_txt[3] = XtVaCreateManagedWidget("nb_cl",
                                         xmTextFieldWidgetClass, rowc,
                                         NULL);
   XmTextFieldSetString(misc_txt[3], "20");

   sprintf(string, "%f", world->min);
   lbl[4] = XtVaCreateManagedWidget("Minimum to display: ",
                                    xmLabelGadgetClass, rowc,
                                    NULL);
   misc_txt[4] = XtVaCreateManagedWidget("min",
                                         xmTextFieldWidgetClass, rowc,
                                         NULL);
   sprintf(string, "%g", world->min);
   XmTextFieldSetString(misc_txt[4], string);

   lbl[5] = XtVaCreateManagedWidget("Maximum to display: ",
                                    xmLabelGadgetClass, rowc,
                                    NULL);
   misc_txt[5] = XtVaCreateManagedWidget("max",
                                         xmTextFieldWidgetClass, rowc,
                                         NULL);
   sprintf(string, "%g", world->max);
   XmTextFieldSetString(misc_txt[5], string);

   if (world->type != GSLIB)    /* We know the size */
   {
      for (i=0; i<3; i++)
      {
         sprintf(string, "%d", world->n[i]);
   	XmTextFieldSetString(misc_txt[i], string);
      }
      if (world->nb_class)
      {
         sprintf(string, "%d", world->nb_class);
   	XmTextFieldSetString(misc_txt[3], string);
      }
   }
   button = XtVaCreateManagedWidget("Set values",
                                    xmPushButtonGadgetClass, param_form,
                                    XmNleftAttachment, XmATTACH_FORM,
                                    XmNrightAttachment, XmATTACH_FORM,
                                    XmNtopAttachment, XmATTACH_WIDGET,
                                    XmNtopWidget, rowc_frame,
                                    NULL);

   XtAddCallback(button, XmNactivateCallback,
                 (XtCallbackProc)param_set_cb, (XtPointer)param);

   XtManageChild(rowc);
   XtManageChild(param_frame);
   XtManageChild(param);
   }

void            varia_fn(void)        /*F*/
   {
   int             i;
   XmString        str_title;
   char            string[STRING1];
   Widget         *toggle, varia, varia_form, varia_rb_frame;
   Widget          radio_box, varia_trim_rowc, varia_select;
   Widget          varia_tmin, varia_tmax;

   world->t_min = T_MIN; world->t_max = T_MAX;
   if ((world->type==GSLIB || world->type==EXTGSL) &&
       (world->nb_var>1 || world->change_trim))
      {
      toggle = (Widget *) malloc(world->nb_var * sizeof(Widget));
      if (!toggle)
         CANTALLOC(world->nb_var, toggle, "varia_fn");

      str_title = XmStringCreateSimple("Variable selection");
      varia = XtVaCreatePopupShell("Variables",
                    xmDialogShellWidgetClass, widgets->top,
                    XmNmwmFunctions,          30,
                    XmNdialogStyle,           XmDIALOG_FULL_APPLICATION_MODAL,
                    XmNdialogTitle,           str_title,
                    NULL);

      varia_form = XtVaCreateWidget("varia_form",
                                    xmFormWidgetClass, varia,
                                    NULL);

      varia_rb_frame = XtVaCreateWidget("varia_rb_frame",
                                        xmFrameWidgetClass, varia_form,
                                        NULL);

      radio_box = XmCreateRadioBox(varia_rb_frame, "radio_box", NULL, 0);

      for (i = 0; i < world->nb_var; i++)
         {
         toggle[i] = XtVaCreateManagedWidget(var_names[i],
                                xmToggleButtonGadgetClass, radio_box, NULL);
         XtAddCallback(toggle[i], XmNvalueChangedCallback, varia_cb, i);
         }

      XmToggleButtonSetState(toggle[world->nb_var-1], True, True);

      varia_trim_rowc = XtVaCreateManagedWidget("varia_trim_rowc",
                                  xmRowColumnWidgetClass, varia_form,
                                  XmNpacking,             XmPACK_COLUMN,
                                  XmNnumColumns,          2,
                                  XmNorientation,         XmHORIZONTAL,
                                  XmNisAligned,           True,
                                  XmNtopAttachment,       XmATTACH_FORM,
                                  XmNleftAttachment,      XmATTACH_WIDGET,
                                  XmNleftWidget,          varia_rb_frame,
                                  XmNrightAttachment,     XmATTACH_FORM,
                                  NULL);

      varia_tmin=XtVaCreateManagedWidget("Trimming limit min: ",
                                        xmLabelGadgetClass, varia_trim_rowc,
                                               NULL);
      sprintf(string, "%g", world->t_min);
      misc_txt[0] = XtVaCreateManagedWidget("t_min",
                                    xmTextFieldWidgetClass, varia_trim_rowc,
                                            XmNvalue, string,
                                            NULL);
      varia_tmax=XtVaCreateManagedWidget("Trimming limit max: ",
                                        xmLabelGadgetClass, varia_trim_rowc,
                                               NULL);
      sprintf(string, "%g", world->t_max);
      misc_txt[1] = XtVaCreateManagedWidget("t_max",
                                    xmTextFieldWidgetClass, varia_trim_rowc,
                                            XmNvalue, string,
                                            NULL);

      varia_select = XtVaCreateManagedWidget("Set",
                                        xmPushButtonGadgetClass, varia_form,
                                          XmNtopAttachment, XmATTACH_WIDGET,
                                             XmNtopWidget, varia_trim_rowc,
                                         XmNleftAttachment, XmATTACH_WIDGET,
                                             XmNleftWidget, varia_rb_frame,
                                          XmNrightAttachment, XmATTACH_FORM,
                                             NULL);
      XtAddCallback(varia_select, XmNactivateCallback,
                    varia_select_cb, (XtPointer) varia);

      XmStringFree(str_title);
      free(toggle);

      XtManageChild(radio_box);
      XtManageChild(varia_rb_frame);
      XtManageChild(varia_form);
      XtManageChild(varia);
      }                         /* End case type=GSLIB */
   else
      {
      file_read();
      param_fn();
      }
   }
