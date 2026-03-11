
#include <Xm/DrawingA.h>
#include <Xm/FileSB.h>
#include "yap.h"
#include "yaconfig.h"
#include "NXHelp.h"

extern World_t   *world;
extern Widgets_t *widgets;

static float    r_extr[2], g_extr[2], b_extr[2];

static float    r_beg[MAX_NB_COLOR], r_inc[MAX_NB_COLOR];
static float    g_beg[MAX_NB_COLOR], g_inc[MAX_NB_COLOR];
static float    b_beg[MAX_NB_COLOR], b_inc[MAX_NB_COLOR];

BOOLEAN         read_cmap(char                   *filename)   /*F*/
   {
   FILE           *file;
   char            cstr[STRING1];
   int             i, nb_c;
   int             nb_color;
   int             nb_class;
   float           f[3];

   if (!filename || !(file = fopen(filename, "r")))
      {
   /* No default color map, using w2b */
      p_area(widgets->debug_area,
             "CMAP -> Building default black to white colormap\n");

      r_extr[0]=1; r_extr[1]=1;
      g_extr[0]=1; g_extr[1]=1;
      b_extr[0]=1; b_extr[1]=1;

      r_beg[0]=1; r_beg[1]=0; r_inc[0]= -1;
      g_beg[0]=1; g_beg[1]=0; g_inc[0]= -1;
      b_beg[0]=1; b_beg[1]=0; b_inc[0]= -1;
      world->nb_col_int = 1;
      PostDialog(widgets->top, XmDIALOG_INFORMATION, "Default colormap built",
              "Couldn't open colormap", "OK");
      }
   else
      {
      p_area(widgets->debug_area, "CMAP -> Reading colormap file %s\n",
                                  filename);
      if (!fscanf(file, "%d", &nb_c)) return(FALSE);
      nb_c = MMIN(nb_c, 255);
      if (fscanf(file, "%f%f%f", &f[0], &f[1], &f[2])!=3) return(FALSE);
      r_extr[0]=MMAX(0, MMIN(f[0], 1));
      g_extr[0]=MMAX(0, MMIN(f[1], 1));
      b_extr[0]=MMAX(0, MMIN(f[2], 1));
      for (i=0; i<nb_c; i++)
         {
         if (fscanf(file, "%f%f%f", &f[0], &f[1], &f[2])!=3) return(FALSE);
         r_beg[i]=MMAX(0, MMIN(f[0], 1));
         g_beg[i]=MMAX(0, MMIN(f[1], 1));
         b_beg[i]=MMAX(0, MMIN(f[2], 1));
         if (i)
            {
            r_inc[i-1] = r_beg[i]-r_beg[i-1];
            g_inc[i-1] = g_beg[i]-g_beg[i-1];
            b_inc[i-1] = b_beg[i]-b_beg[i-1];
            }
         }
      if (fscanf(file, "%f%f%f", &f[0], &f[1], &f[2])!=3) return(FALSE);
      r_extr[1]=MMAX(0, MMIN(f[0], 1));
      g_extr[1]=MMAX(0, MMIN(f[1], 1));
      b_extr[1]=MMAX(0, MMIN(f[2], 1));
      world->nb_col_int = nb_c - 1;
      fclose(file);
      }
   nb_class = world->nb_class;
   if (world->file)
      {
/* if old_nb_cl (here world->nb_class) is <=  0, no XFreeColor */
      nb_color = Get_Colormap(world->nb_class, nb_class,
                              world->nb_col_int);
      world->nb_class = nb_color - 2;
      set_default_cutoffs();
      get_class_table();
      if (nb_color != nb_class + 2)
         {
         sprintf(cstr, "Could only allocate %d colors out of %d",
                 nb_color, nb_class + 2);
         PostDialog(widgets->top, XmDIALOG_ERROR, "Warning",
                    cstr, "Too bad");
         p_area(widgets->debug_area, cstr, "\n");
         }
      }
   p_area(widgets->debug_area, "CMAP -> Colormap read, seems OK\n");
   return(TRUE);
   }

void            default_cmap(void)  /*F*/
   {
   p_area(widgets->debug_area,
             "CMAP -> _CMAP_DEF is defined as %s\n", _CMAP_DEF);
   if (!read_cmap(_CMAP_DEF)) read_cmap(NULL);
   }

static void   cancel_read_cmap_cb(Widget                     dialog,    /*F*/
                           XtPointer                         un1,       /*F*/
                           XmFileSelectionBoxCallbackStruct *cbs)       /*F*/
   {
   world->refresh=TRUE;
   XtUnmanageChild(dialog);
   }

static void   read_cmap_cb(Widget                            dialog,    /*F*/
                           XtPointer                         un1,       /*F*/
                           XmFileSelectionBoxCallbackStruct *cbs)       /*F*/
   {
   char           *fn = NULL;

   if (cbs)
      {
      if (!XmStringGetLtoR(cbs->value, XmSTRING_DEFAULT_CHARSET, &fn))
         return;
      if (!read_cmap(fn)) read_cmap(NULL);
      }
   XtUnmanageChild(dialog);
   world->refresh=TRUE;
   refresh_all();
   }

void            cmap_fn(void)         /*F*/
   {
   static Widget   open_cmap;
   XmString        str, mask;
   char            cmap_dir[STRING1];

   world->refresh=FALSE;
   str = XmStringCreateSimple("File selection");

/* First, look the environmental variable CMAP_DIR
   then        the define (from config.h) _CMAP_DIR
   otherwise, start here
*/
   if (getenv("CMAP_DIR"))
      {
      p_area(widgets->debug_area,
            "CMAP -> Envir. var. CMAP_DIR defined as %s\n", getenv("CMAP_DIR"));
      sprintf(cmap_dir, "%s/*.cmap", getenv("CMAP_DIR"));
      }
   else
      {
      if (strlen(_CMAP_DIR))
         {
         p_area(widgets->debug_area,
                "CMAP -> _CMAP_DIR defined as %s\n", _CMAP_DIR);
         sprintf(cmap_dir, "%s/*.cmap", _CMAP_DIR);
         }
      else
         {
         p_area(widgets->debug_area,
                "CMAP -> Looking for colormap in current directory\n");
         strcpy(cmap_dir, "*.cmap");
         }
      }

   mask = XmStringCreateSimple(cmap_dir);
   if (!open_cmap)
      {
      open_cmap=XmCreateFileSelectionDialog(widgets->top, "File selection",
                                            NULL, 0);
      XtAddCallback(open_cmap, XmNokCallback,
                    (XtCallbackProc)read_cmap_cb, NULL);
      XtAddCallback(open_cmap, XmNcancelCallback,
                    (XtCallbackProc)cancel_read_cmap_cb, NULL);
      XtAddCallback(open_cmap, XmNhelpCallback,
                    (XtCallbackProc)XnHelpCB, "Load colormap");
      XtVaSetValues(open_cmap, XmNdialogTitle, str,
                    XmNdialogStyle, XmDIALOG_FULL_APPLICATION_MODAL,
                    XmNdirMask, mask,
                    NULL);
      }
   XtManageChild(open_cmap);
   XtPopup(XtParent(open_cmap), XtGrabNone);
   XmStringFree(str);
   XmStringFree(mask);
   }

int             Get_Colormap(int            old_nb_cl,  /*F*/
                             int            new_nb_cl,  /*F*/
                             int            nb_c_i)        /*F*/
   {
   Colormap        cmap;
   XColor          x_color;
   float           by_c_cl;
   float           inc, pos;
   int             cl, color_cl;
   int             nb_color = 0;

   cmap=DefaultColormap(widgets->dpy, DefaultScreen(widgets->dpy));

   if (!new_nb_cl) return(0);

/* First let's try to free the memory */

   if (old_nb_cl>0)
      {
      p_area(widgets->debug_area, "CMAP -> Freeing old colormap memory\n");
      XFreeColors(widgets->dpy, cmap, widgets->pixels, old_nb_cl + 2, 0);
      free(widgets->pixels);
      free(world->color);
      }
   widgets->pixels = (Pixel *)calloc(new_nb_cl+2, sizeof(Pixel));
   if (!widgets->pixels)
      CANTALLOC(new_nb_cl+2, widgets->pixels, "Get_Colormap");
   world->color = (Color_t *)calloc(new_nb_cl+2, sizeof(Color_t));
   if (!world->color)
      CANTALLOC(new_nb_cl+2, world->color, "Get_Colormap");

   by_c_cl = (float) (new_nb_cl - 1) / nb_c_i;

   inc = 1 / by_c_cl;

   world->color[0].r = r_extr[0];
   x_color.red = r_extr[0] * MAX_COLOR;
   world->color[0].g = g_extr[0];
   x_color.green = g_extr[0] * MAX_COLOR;
   world->color[0].b = b_extr[0];
   x_color.blue = b_extr[0] * MAX_COLOR;
   if (XAllocColor(widgets->dpy, cmap, &x_color))
      {
      widgets->pixels[0] = x_color.pixel;
      nb_color++;
      }

   for (cl = 0; cl < new_nb_cl - 1; cl++)
      {
      color_cl = (int) ((float) cl * inc);
      pos = (cl - color_cl * by_c_cl) / by_c_cl;
      world->color[cl + 1].r = r_beg[color_cl] + r_inc[color_cl] * pos;
      world->color[cl + 1].g = g_beg[color_cl] + g_inc[color_cl] * pos;
      world->color[cl + 1].b = b_beg[color_cl] + b_inc[color_cl] * pos;
      x_color.red = world->color[cl + 1].r * MAX_COLOR;
      x_color.green = world->color[cl + 1].g * MAX_COLOR;
      x_color.blue = world->color[cl + 1].b * MAX_COLOR;
      if (XAllocColor(widgets->dpy, cmap, &x_color))
         {
         widgets->pixels[nb_color] = x_color.pixel;
         nb_color++;
         }
      }

   world->color[new_nb_cl].r = r_beg[nb_c_i];
   x_color.red = r_beg[nb_c_i] * MAX_COLOR;
   world->color[new_nb_cl].g = g_beg[nb_c_i];
   x_color.green = g_beg[nb_c_i] * MAX_COLOR;
   world->color[new_nb_cl].b = b_beg[nb_c_i];
   x_color.blue = b_beg[nb_c_i] * MAX_COLOR;
   if (XAllocColor(widgets->dpy, cmap, &x_color))
      {
      p_area(widgets->debug_area, "CMAP -> Allocating new colormap\n");
      widgets->pixels[nb_color] = x_color.pixel;
      nb_color++;
      }

   world->color[new_nb_cl + 1].r = r_extr[1];
   x_color.red = r_extr[1] * MAX_COLOR;
   world->color[new_nb_cl + 1].g = g_extr[1];
   x_color.green = g_extr[1] * MAX_COLOR;
   world->color[new_nb_cl + 1].b = b_extr[1];
   x_color.blue = b_extr[1] * MAX_COLOR;
   if (XAllocColor(widgets->dpy, cmap, &x_color))
      {
      widgets->pixels[nb_color] = x_color.pixel;
      nb_color++;
      }

   return (nb_color);
   }
