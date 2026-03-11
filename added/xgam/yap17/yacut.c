
#include <Xm/Label.h>
#include <Xm/Text.h>
#include <Xm/TextF.h>
#include "yap.h"

extern       World_t   *world;
extern       Widgets_t *widgets;
extern       Widget     nbclass_txt[3];

static int   mode;

void            set_default_cutoffs(void)     /*F*/
   {
   int             i;
   float           step;

   p_area(widgets->debug_area, "CUT  -> Setting default cutoff values\n");
   if (world->cutoffs) free(world->cutoffs);
   world->cutoffs = (float *)calloc(world->nb_class+1, sizeof(float));
   if (!world->cutoffs)
      CANTALLOC(world->nb_class+1, world->cutoffs, "set_default_cutoffs");

   if (!world->nb_class) world->nb_class=1;
   switch (world->mode)
      {
      case ARITHMETIC:
         step = (world->show_max - world->show_min) / world->nb_class;
         for (i = 0; i < world->nb_class + 2; i++)
            world->cutoffs[i] = world->show_min + i * step;
         break;
      case LOGARITHMIC:
         step = exp(log(world->show_max/world->show_min)/world->nb_class);
         world->cutoffs[0]=world->show_min;
         for (i=1; i<world->nb_class+2; i++)
            world->cutoffs[i] = world->cutoffs[i-1]*step;
         break;
      case QUANTILES:
         for (i=1; i<world->nb_class+2; i++)
            world->cutoffs[i]=world->quant[i];
         break;
      }
   }

static unsigned char get_class(float           v,  /*F*/
                               int             nb_class)       /*F*/
   {
   int             i;

   if (v<world->cutoffs[0]) return(0);

   for (i=1; i<nb_class+1; i++)
      {
      if (v<=world->cutoffs[i])
         return ((unsigned char)i);
      }
   return ((unsigned char) (nb_class+1));
   }

void            get_class_table(void)         /*F*/
   {
   int             total = world->n[X] * world->n[Y] * world->n[Z];
   int             i, nb_c = world->nb_class;

   if (world->class_table) free(world->class_table);
   world->class_table = (unsigned char *)calloc(total, sizeof(unsigned char));
   if (!world->class_table)
      CANTALLOC(total, world->class_table, "set_default_cutoffs");

   for (i=0; i<total; i++)
      world->class_table[i]=get_class((float)world->values[i], nb_c);
   }

static BOOLEAN  check_cutoffs_ranking(void)   /*F*/
   {
   int             i;

   for (i = 0; i < world->nb_class; i++)
      {
      if (world->cutoffs[i + 1] <= world->cutoffs[i])
         {
         p_area(widgets->debug_area,
                "CUT  -> Error in cutoffs ranking: %g > %g\n",
                world->cutoffs[i], world->cutoffs[i + 1]);
         return(FALSE);
         }
      }
   p_area(widgets->debug_area, "CUT  -> Ranking of cutoffs seems OK\n");
   return (TRUE);
   }

static BOOLEAN  get_cutoff_value(void)        /*F*/
   {
   float           cut;
   char           *str;

   str=CALLOC(STRING1, char);
   strcpy(str, (char *)XmTextFieldGetString(widgets->cutoff_txt));
   /*str = XmTextFieldGetString(widgets->cutoff_txt);*/

   if (sscanf(str, "%f", &cut)!=1)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please check that you entered a number!", "I'll do that");
      free(str);
      return (False);
      }
   free(str);

   world->cutoffs[world->current_cutoff] = cut;
   return (True);
   }

void            allcut_set_cb(Widget                un1,     /*F*/
                              Widget                dialog,  /*F*/
                              XtPointer             un2)     /*F*/
   {
   int             i, nb_cut=0, nb_color;
   char           *str;
   char            msg[STRING1];
   float          *tmp_cut;

   str=CALLOC(STRING2, char);
   strcpy(str, (char *)XmTextGetString(widgets->allcut_txt));
   /*str=XmTextGetString(widgets->allcut_txt);*/
   tmp_cut=CALLOC(MAX_NB_CUT, float);

   while(1)
      {
      char c;
      while ((c= *str)==' ' || c=='\t' && c!='\0') str++;
      if (sscanf(str, "%f", &tmp_cut[nb_cut])!=1)   break;
      while ((c= *str)!='\0' && c!=' ' && c!='\t')   str++;
      if (nb_cut!=0 && tmp_cut[nb_cut]<=tmp_cut[nb_cut-1])
         {
         PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
            "There is a problem in your cutoffs ranking", "Let's start again");
         free(str);
         return;
         }
      free(str);
      nb_cut++;
      if (nb_cut==MAX_NB_CUT) break;
      }

   if (world->nb_class != nb_cut-1)
      {
      nb_color = Get_Colormap(world->nb_class, nb_cut-1, world->nb_col_int);
/* nb_color should be = nb_cut (asked) + 1, unless we couldn't allocate
   all the colors */
      if (nb_color != nb_cut+1)     /* some color allocations failed */
         {
         sprintf(msg, "Could only allocate %d colors out of %d",
                 nb_color, nb_cut+1);
         PostDialog(widgets->top, XmDIALOG_ERROR, "Warning",
                    msg, "Too bad");
         }
      world->nb_class = nb_color-2;   /* colors really allocated */
      }
   world->show_min = tmp_cut[0];
   world->show_max = tmp_cut[nb_cut-1];
   for (i=0; i<nb_cut; i++)
      world->cutoffs[i]=tmp_cut[i];
   free(tmp_cut);
   XtDestroyWidget(dialog);
   XtSetSensitive(widgets->allcut, True);
   XtSetSensitive(widgets->cutoff, True);
   XtSetSensitive(widgets->nbcut,  True);
   get_class_table();
   if (world->comp_stat) init_compute();
   world->refresh=TRUE;
   refresh_all();
   }

void            cutoff_set_cb(Widget                un1,     /*F*/
                              Widget                dialog,  /*F*/
                              XtPointer             un2)     /*F*/
   {
   if (!get_cutoff_value())
      return;
   if (!check_cutoffs_ranking())
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
         "There is a problem in your cutoffs ranking", "Let's start again");
      return;
      }
   world->show_min=world->cutoffs[0];
   world->show_max=world->cutoffs[world->nb_class];
   XtDestroyWidget(dialog);
   XtSetSensitive(widgets->allcut, True);
   XtSetSensitive(widgets->cutoff, True);
   XtSetSensitive(widgets->nbcut, True);
   get_class_table();
   if (world->comp_stat) init_compute();
   world->refresh=TRUE;
   refresh_all();
   }

void            nbclass_mode_cb(Widget                         un1,    /*F*/
                                int                            which,  /*F*/
                                XmToggleButtonCallbackStruct  *un2)    /*F*/
   {
   mode=which;
   }

static void        set_cutoff_label(void)        /*F*/
   {
   XmString        str;
   char            cstr[STRING1];

   sprintf(cstr, "Cutoff # %3d: ", world->current_cutoff);
   str = XmStringCreateSimple(cstr);
   XtVaSetValues(widgets->cutoff_lbl, XmNlabelString, str, NULL);
   XmStringFree(str);
   sprintf(cstr, "%g", world->cutoffs[world->current_cutoff]);
   XtVaSetValues(widgets->cutoff_txt, XmNvalue, cstr, NULL);
   }

void            l_arrow_cb(Widget            un1,          /*F*/
                           XtPointer         un2,          /*F*/
                           XtPointer         un3)          /*F*/
   {
   if (!get_cutoff_value()) return;
   world->current_cutoff--;
   if (world->current_cutoff < 0)
      world->current_cutoff = world->nb_class;
   set_cutoff_label();
   }

void            r_arrow_cb(Widget            un1,  /*F*/
                           XtPointer         un2,  /*F*/
                           XtPointer         un3)  /*F*/
   {
   if (!get_cutoff_value())
      return;
   world->current_cutoff++;
   if (world->current_cutoff > world->nb_class)
      world->current_cutoff = 0;
   set_cutoff_label();
   }

void            cutoff_cancel_cb(Widget      un1,     /*F*/
                                 Widget      dialog,  /*F*/
                                 XtPointer   un2)     /*F*/
   {
   XtSetSensitive(widgets->allcut, True);
   XtSetSensitive(widgets->cutoff, True);
   XtSetSensitive(widgets->nbcut, True);
   world->refresh=TRUE;
   XtUnmanageChild(dialog);
   XtDestroyWidget(dialog);
   }

void            nbclass_set_cb(Widget        un1,     /*F*/
                               Widget        dialog,  /*F*/
                               XtPointer     un2)     /*F*/
   {
   char           *cstr[3];
   char            msg[STRING1];
   float           min, max;
   int             nb_class, nb_color, i;

   nb_color=world->nb_class+2;
   for (i=0; i<3; i++)
      {
      cstr[i]=CALLOC(STRING1, char);
      strcpy(cstr[i], (char *)XmTextFieldGetString(nbclass_txt[i]));
      /*cstr[i] = XmTextFieldGetString(nbclass_txt[i]);*/
      }
   if (sscanf(cstr[0], "%d", &nb_class)!=1
    || sscanf(cstr[1], "%f", &min)!=1
    || sscanf(cstr[2], "%f", &max)!=1)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "Please check that you entered numbers!", "I'll do that");
      for (i=0; i<3; i++) free(cstr[i]);
      return;
      }
   for (i=0; i<3; i++) free(cstr[i]);

   if (nb_class<2)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
                 "This # of classes seems strange", "I'll check");
      return;
      }
   if (min >= max)
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
          "Let's try to have a maximum greater than the minimum", "Indeed");
      return;
      }
   if (mode==LOGARITHMIC && (SIGN(min)!=SIGN(max) || min==0 || max==0))
      {
      PostDialog(widgets->top, XmDIALOG_ERROR, "Error",
          "Can't use log scale with those values", "Indeed");
      return;
      }
   if (world->nb_class != nb_class)
      {
      nb_color = Get_Colormap(world->nb_class, nb_class, world->nb_col_int);
/* nb_color should be = nb_class (asked)+2, unless we couldn't allocate
   all the colors */
      if (nb_color != nb_class+2)     /* some color allocations failed */
         {
         sprintf(msg, "Could only allocate %d colors out of %d",
                 nb_color, nb_class+2);
         PostDialog(widgets->top, XmDIALOG_ERROR, "Warning",
                    msg, "Too bad");
         }
      }
   if (world->show_min != min || world->show_max != max
    || world->nb_class != nb_class || world->mode != mode)
      {
      XtUnmanageChild(dialog);
      XtDestroyWidget(dialog);
      world->nb_class = nb_color - 2;   /* colors really allocated */
      world->show_min = min;
      world->show_max = max;
      world->mode     = mode;
      set_default_cutoffs();
      get_class_table();
      if (world->comp_stat) init_compute();
      world->refresh=TRUE;
      refresh_all();
      }
   XtSetSensitive(widgets->allcut, True);
   XtSetSensitive(widgets->nbcut, True);
   XtSetSensitive(widgets->cutoff, True);
   }
