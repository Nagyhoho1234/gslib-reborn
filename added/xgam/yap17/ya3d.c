
#include <math.h>
#include <Xm/DrawingA.h>
#include <X11/cursorfont.h>
#include "yap.h"
#include "yaconfig.h"

extern Widgets_t   *widgets;
extern World_t     *world;
extern int          nX[4], nY[4], sX[4], sY[4]; /* in ya2d.c */

static int          pixel_size;
static int          dX1[3], dX2[3], dY1[3], dY2[3];
static int          idx_begin[3], x_begin[3], y_begin[3];
static Window       win3d;

void            init_3d_indexes(void)         /*F*/
   {
/* XZ is FRONT
   XY is TOP
   YZ is RIGHT
*/
   win3d = XtWindow(widgets->win3d_area);
   idx_begin[XY]=world->n[X]*world->n[Y]*(world->n[Z]-1);
   idx_begin[YZ]=world->n[X]-1;
   idx_begin[XZ]=0;
   }

static void     draw_3d_scale(int               x,  /*F*/
                              int               y,  /*F*/
                              int               w,  /*F*/
                              int               h)         /*F*/
   {
   int             i, height, sy, nb, step_pos;
   float           val;
   char            str[STRING1];
   XPoint          pt[5];

   p_area(widgets->debug_area, "SCR3 -> Drawing scale\n");
   sy = (int) ((h-2) / (world->nb_class+2));    /* height of one color   */
   height = 1+sy*(world->nb_class+2);           /* height of the whole scale */

   XSetForeground(widgets->dpy, widgets->gc, widgets->black);
   XDrawRectangle(widgets->dpy, win3d, widgets->gc, x, y-height, w, height);

   if (world->type==CBINARY
    && world->nb_class==world->show_max-world->show_min+1
    && world->mode==ARITHMETIC)
      {
      for (i=1; i<world->nb_class+1; i++)
         {
         val=world->cutoffs[i];
         sprintf(str, "%d", (int)floor(val));
         XDrawString(widgets->dpy, win3d, widgets->gc, x+w+2,
                     (int)(y-(i+.5)*sy), str, strlen(str));
         }
      }
   else
      {
      nb=MMIN(world->nb_class, NB_LABEL);
      step_pos = (int) ceil((float) world->nb_class / nb);
      for (i=0; i<world->nb_class; i+=step_pos)
         {
         val = world->cutoffs[i];
         sprintf(str, "%g", val);
         XDrawString(widgets->dpy, win3d, widgets->gc, x + w + 2, y - (i + 1) * sy, str, strlen(str));
         }
      sprintf(str, "%g", world->show_max);
      XDrawString(widgets->dpy, win3d, widgets->gc, x+w+2, y-(world->nb_class+1)*sy, str, strlen(str));
      }

   for (i=0; i<world->nb_class+2; i++)
      {
      XSetForeground(widgets->dpy, widgets->gc, widgets->pixels[i]);
      XFillRectangle(widgets->dpy, win3d, widgets->gc, x + 1, y - sy * (i + 1), w - 1, sy);
      }
   pt[0].x = x - w;                       pt[0].y = y - w * .8;
   pt[1].x = pt[0].x;                     pt[1].y = y;
   pt[2].x = x - w * .2;                  pt[2].y = pt[1].y;
   pt[3].x = pt[1].x;                     pt[3].y = pt[1].y;
   pt[4].x = x - w + w * .6 * cos(ANGLE); pt[4].y = y - w * .6 * sin(ANGLE);
   XSetForeground(widgets->dpy, widgets->gc, widgets->black);
   XDrawLines(widgets->dpy, win3d, widgets->gc, pt, 5, CoordModeOrigin);
   sprintf(str, "z");
   XDrawString(widgets->dpy, win3d, widgets->gc, (int) (x-w-10), (int) (y-w*.8), "z", 1);
   XDrawString(widgets->dpy, win3d, widgets->gc, (int) (x-w*.3), (int) (y-10), "x", 1);
   XDrawString(widgets->dpy, win3d, widgets->gc, (int) (x-w+w*.6*cos(ANGLE)),
               (int) (y - w * .8 * sin(ANGLE)), "y", 1);
   }

static void     draw_3d_plane(int              plane)      /*F*/
   {
   unsigned char class;
   int             i, j;
   XPoint          pt[5];

   p_area(widgets->debug_area, "SCR3 -> Drawing plane %d\n", plane);
   for (class=0; class<world->nb_class+2; class++)
      {
      XSetForeground(widgets->dpy, widgets->gc, widgets->pixels[class]);
      for (i = 0; i < nX[plane]; i++)
         for (j = 0; j < nY[plane]; j++)
            {
            if (world->class_table[idx_begin[plane]
                                   + i * sX[plane] + j * sY[plane]] == class)
               {
               pt[0].x = x_begin[plane] + i * dX1[plane] + j * dX2[plane];
               pt[0].y = y_begin[plane] + i * dY1[plane] + j * dY2[plane];
               pt[1].x = pt[0].x + dX1[plane];
               pt[1].y = pt[0].y + dY1[plane];
               pt[2].x = pt[1].x + dX2[plane];
               pt[2].y = pt[1].y + dY2[plane];
               pt[3].x = pt[0].x + dX2[plane];
               pt[3].y = pt[0].y + dY2[plane];
               XFillPolygon(widgets->dpy, win3d, widgets->gc, pt, 4, Convex, CoordModeOrigin);
               }
            }
      }
   XSetForeground(widgets->dpy, widgets->gc, widgets->black);
   pt[0].x = x_begin[plane];
   pt[0].y = y_begin[plane];
   pt[1].x = pt[0].x + nX[plane] * dX1[plane];
   pt[1].y = pt[0].y + nX[plane] * dY1[plane];
   pt[2].x = pt[1].x + nY[plane] * dX2[plane];
   pt[2].y = pt[1].y + nY[plane] * dY2[plane];
   pt[3].x = pt[0].x + nY[plane] * dX2[plane];
   pt[3].y = pt[0].y + nY[plane] * dY2[plane];
   pt[4].x = pt[0].x;
   pt[4].y = pt[0].y;
   XDrawLines(widgets->dpy, win3d, widgets->gc, pt, 5, CoordModeOrigin);
   }

void            draw_3d_cube(BOOLEAN          clear_before)        /*F*/
   {
   Dimension       width, height;
   float           fact_w, fact_h;
   int             h, w, i;

   NewCursor(widgets->win3d_area, XC_watch);
   init_timer("Drawing");
   if (clear_before)
      XClearArea(widgets->dpy, XtWindow(widgets->win3d_area), 0, 0, 0, 0, False);
   XtVaGetValues(widgets->win3d_area, XmNwidth, &width,
                 XmNheight, &height, NULL);
   fact_h = FACT_H;
   fact_w = FACT_H / tan(ANGLE);
   h = (int) (.9 * height / (world->n[Z] + fact_h * world->n[Y]));
   w = (int) (.8 * width / (world->n[X] + fact_w * world->n[Y]));
   pixel_size = MMIN(h, w);

   dX1[XZ] = pixel_size;
   dY1[XZ] = 0;
   dX2[XZ] = 0;
   dY2[XZ] = -pixel_size;

   dX1[XY] = pixel_size;
   dY1[XY] = 0;
   dX2[XY] = (int) (fact_w * pixel_size);
   dY2[XY] = -(int) (fact_h * pixel_size);

   dX1[YZ] = (int) (fact_w * pixel_size);
   dY1[YZ] = -(int) (fact_h * pixel_size);
   dX2[YZ] = 0;
   dY2[YZ] = -pixel_size;

   x_begin[XZ]=0.01*width;
   y_begin[XZ]=0.99*height;
   x_begin[YZ]=0.01*width+pixel_size*world->n[X];
   y_begin[YZ]=0.99*height;
   x_begin[XY]=0.01*width;
   y_begin[XY]=0.99*height-pixel_size*world->n[Z];
   for (i=0; i<3; i++)
      {
      if (pixel_size && dX1[i] && dY2[i]) draw_3d_plane(i);
      set_timer((float).25*(i+1));
      }
   draw_3d_scale((int) (.84*width), (int) (.95*height),
                 (int) (.08*width), (int) (.9*height));
   set_timer((float)1.);
   NewCursor(widgets->win3d_area, None);
   }
