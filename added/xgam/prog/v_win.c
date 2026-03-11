#include "xgam.h"
#include "vario.h"
#include "xutil.h"
 
extern graphics_data *data;
extern Display *display;
extern GC xgc,xorgc;
extern var_data var[MAXNVARIOS];
extern XPoint mdots[MAXNVARIOS][100]; /* mm1 modeling */
extern int n_mdots;
extern int p_mm1;

extern Widget swindow,toplevel;
Widget canvas[MAXNVARIOS];
graph_t  graph[MAXNVARIOS];
extern void human_scale();
extern int ng;
extern XFontStruct *large_font, *small_font;
static int p_s=0;
int cdir=0;
void refresh_canvas();
extern void new_axis_title();
extern void setModelParPanel();
extern float gam();
int cvar;
bool btn_pressed; 
extern bool range_locked,sill_locked;
extern int istate;
extern int STAND;

Widget Drawing;

void draw_model();
void refresh_active_canvases();

graph_to_var(ig)
int ig;
{
        int iv;
        int ndir=1;

        for (iv=0; iv<ng*ndir; iv++)
                if (var[iv].idir==cdir && var[iv].g == &graph[ig]) break;
        return iv;
}

static void new_axis_title(i)
int i;
{
        int iv=graph_to_var(i);
        var_to_device(&var[iv]);
        refresh_canvas(i);
}


static void handle_motion(w, data, event)
Widget w;
graphics_data *data;
XButtonEvent *event;
{
          graph_t *g = var[cvar].g;
/*
    if (istate!=VarioModel) return;
*/
    if (!btn_pressed) return;

        if (event->y > g->y+g->w || event->x<g->x) return;

    draw_model(&var[cvar].model, xorgc);
    if (!range_locked) data->last_x = event->x;
    if (!sill_locked ) data->last_y = event->y;
    mouse_fit(w, data, xorgc);


}

static void handle_release(w, data, event)
Widget w;
graphics_data *data;
XButtonEvent *event;
{
    int i, iv;

    if (event->button != Button1) return;
/*
    if (istate!=VarioModel) return;
*/
    if (!btn_pressed) return;

    mouse_fit(w, data, xorgc);
   refresh_active_canvases();

    if (!range_locked) data->last_x = event->x;
    if (!sill_locked ) data->last_y = event->y;
    btn_pressed=FALSE;
}

void draw_model(m, gc)
model_data *m;
GC gc;
{
        graph_t *g = m->g;
        int i, x, y, ix, n_mdots=0;
        float h, mvar, dx=((float)g->w)/(float)NMODELSTEPS;
        XPoint mdots[NMODELSTEPS];
        for (i=0,ix=g->x; i<NMODELSTEPS && ix<g->x+g->w; i++,ix+=dx) {
                h = USERX(g,ix);
                mvar=gam(m,h);
                y=DEVICEY(g, mvar);
                if (y<g->y) break;
                mdots[i].x=ix, mdots[i].y=y;
                n_mdots++;
        }
        XDrawLines(display, g->win, gc, mdots, n_mdots, CoordModeOrigin);
}

/* the callback when clicking the data point ,the functions called 
in the file v_hscat.c */
static void handle_press(w, data, event)
Widget w;
graphics_data *data;
XButtonEvent *event;
{

      int i, ig,iv,pt;
      
      
      if ((ig=GetChoice(w))>=ng) RETURN("invalid window");
      for (iv=0; var[iv].g != &graph[ig]; iv++);
      cvar=iv;

      if (event->button == Button1 && istate==VarioModel) {
        if (!graph[ig].active) {
            for (i=0; i<ng; i++) {  /* turn off all others */
              if (!graph[i].active) continue;
                graph[i].active=FALSE;
                highlight(canvas[i], FALSE);
             }
             graph[ig].active=TRUE;  /* and turn this one on and return */
             highlight(canvas[ig], TRUE);
             setModelParPanel(&var[cvar].model);
             return;
        }

      if(click_inside(event->x, event->y, graph, ng, ig, new_axis_title)) {
          btn_pressed=TRUE;
         data->last_x = event->x;
         data->last_y = event->y;
          for (iv=0; iv<ng; iv++)
             if (graph[ig].active)  refresh_canvas(ig);
           mouse_fit(w, data, xorgc);
       }
    }


     /* middle button is being pressed */
     if (event->button == Button2) {
        if (!graph[ig].active) {
             for (i=0; i<ng; i++) {  /* turn off all others */
                if (!graph[i].active) continue;
                graph[i].active=FALSE;
                highlight(canvas[i], FALSE);
             }
             graph[ig].active=TRUE;  /* and turn this one on and return */
             highlight(canvas[ig], TRUE);
             return;
       }
       /* click_inside is defined in the file xgraph.c, clicking the axis will
       pop the dialog */
       /* closest_point is defined in the file xmisc.c, finding the closest
          data point */
        if (click_inside(event->x, event->y, graph, ng, ig, new_axis_title)) {
            if ((pt=closest_point(event,var[cvar].ddots, var[cvar].n_ddots))>=0
                           && var[cvar].npt[pt] != 0 )
             if (data->nd<800) 
                 h_scatgram(cvar,pt,data); /* in v_hscat.c */
            else 
               RETURN("Data set too large to view h scatgram");
        }
    } 
    /* right button is pressed */
    else if (event->button == Button3) {
          graph[ig].active = !graph[ig].active;
          highlight(canvas[ig], graph[ig].active); /* in the file xcolor.c */
   }

}

int varyyy; 

/* draw the rectangles(variograms) called by refresh_canvas_proc*/
draw_var(v)
var_data *v;
{
        if (v->n_ddots<=0) return;
        XDrawRectangles(display, v->g->win, xgc, v->ddots, v->n_ddots);
/*
        if(!STAND)
        XDrawLine(display, v->g->win, xgc,v->g->x,varyyy,v->g->x+15, varyyy);
*/

}

/* show the pairs */
void draw_pair(v, gc)
var_data *v;
GC gc;
{
        char str[256];
        int il;
        int xx1,yy1;

        for (il=0; il<v->nlag; il++) {
             sprintf(str, "%d", v->npt[il]);
             xx1=DEVICEX(v->g, v->lag[il]) + 4;
             yy1=DEVICEY(v->g, v->var[il]) + 10; 
             XDrawString(display, v->g->win, gc,xx1,yy1,str,strlen(str));
        }
}

/* the callback of the button Show #Pair(in v_par.c) */
void show_pair()
{
   var_data *v;
   int iv;

    p_s = !p_s;
    for (iv=0; iv<ng; iv++) {
        if ((v = &var[iv])!=NULL) {
            draw_pair(v, xorgc);
         }
    }
}

void refresh_canvas_proc(w)
Widget w;
{ 

       int ig, iv;
        int cvar,i;
        var_data *v;
        int ndir=1;

        if (!XtIsManaged(w)) return;

        ig=GetChoice(w); /* this window is to be refreshed */
        draw_window(&graph[ig]);

        /* find the var id for window ig */
        for (iv=0; iv<ng*ndir; iv++)
        if (var[iv].idir==cdir && var[iv].g == &graph[ig]) break;

        cvar=iv;

/* show the rectangles */

        draw_var(&var[iv]);

        if (p_s) draw_pair(&var[iv], xgc);
        draw_model(&var[iv].model, xgc);
        if(p_mm1) {
         for(i=0;i<ng;i++) {
          var_data *v= &var[i];
          XDrawLines(display, v->g->win, xgc, mdots+i, n_mdots, CoordModeOrigin);
        }
      }
}

void refresh_active_canvases()
{
        int i, s;
        for (i=0; i<ng; i++)
        if (var[i].g->active) {
                for (s=0; s<NST; s++) {
                        var[i].model.sill[s] = var[cvar].model.sill[s];
                        var[i].model.range[s] = var[cvar].model.range[s];
                        var[i].model.type[s] = var[cvar].model.type[s];
                }
                refresh_canvas(var[i].id);
        }
}

void refresh_canvas(i)
int i;
{
        XClearArea(display, XtWindow(canvas[i]), 0, 0, 0, 0, TRUE);
}

static Widget RowCol=NULL;
Widget create_canvas(n, data)
int n;
graphics_data *data;
{
    int i, nr;
    int nc=0;
    data->ncol=2;

    if (RowCol==NULL) {

      nargs=0;
      Drawing=XmCreateBulletinBoard(swindow, "varioBoard", wargs, nargs);

      nargs=0;
      setarg(XmNorientation, XmHORIZONTAL);
      setarg(XmNpacking, XmPACK_COLUMN);
      RowCol=XmCreateRowColumn(Drawing, "varioRowCol", wargs, nargs);
      for (i=0; i<MAXNVARIOS; i++) canvas[i] = NULL;
     }
     XtManageChild(RowCol);
     if (n==0) return Drawing;

/* find the start index of the canvas*/
     for (i=0; i<n; i++) {
         if (canvas[i]!=NULL) {
                nc++;
                continue;
        } 
        else {  
/* Intialize the windows */
          graph_t *g = &graph[i];
          g->W = 340;
          g->H = 300;
          g->x = g->W * .15;
          g->y = g->H * .10;
          g->w = g->W-g->x-15;
          g->h = g->H-2*g->y;

          canvas[i] = XtCreateWidget("canvas", xmDrawingAreaWidgetClass,
                                   RowCol, NULL, 0);
          XtVaSetValues(canvas[i], XmNwidth, g->W,
                                   XmNheight, g->H,
                                   XmNuserData, i,
                                           NULL);
        }
     }

     XtManageChildren(canvas, i);

     nargs=0;
     /* nr= (cross) ? cross_nv : ((n+1)/data->ncol); */
     nr=(n+1)/data->ncol;
     setarg(XmNnumColumns, nr);
     XtSetValues(RowCol, wargs, nargs);
     XtManageChild(RowCol);
     XtManageChild(Drawing);

/* assign the win and id */
     for (i=nc; i<n; i++) {
        graph[i].win = XtWindow(canvas[i]);
        graph[i].id  = i;
 
        XtAddCallback(canvas[i], XmNexposeCallback, refresh_canvas_proc,NULL);
        XtAddEventHandler(canvas[i], ButtonPressMask, False, 
                                         handle_press,data);
        XtAddEventHandler(canvas[i], PointerMotionMask, False, 
                                         handle_motion,data);
        XtAddEventHandler(canvas[i], ButtonReleaseMask, False,
                                        handle_release, data);
        XGrabButton(display, AnyButton, AnyModifier,
                XtWindow(canvas[i]), TRUE,
                ButtonPressMask | ButtonMotionMask | ButtonReleaseMask,
                GrabModeAsync, GrabModeAsync,
                XtWindow(canvas[i]),
                XCreateFontCursor(display,XC_crosshair));
     }

     return Drawing;
}

var_to_device(v)
var_data *v;
{
    
    int i, n;
   
    for (i=0, n=0; i<v->nlag; i++) {
        v->ddots[n].x=DEVICEX(v->g, v->lag[i])-1;
        v->ddots[n].y=DEVICEY(v->g, v->var[i])-1;
        if (v->ddots[n].y<v->g->y) continue;
        v->ddots[n].width = v->ddots[n].height = 2;
        n++;
    }
    v->n_ddots = n;
   if(STAND) 
     varyyy=DEVICEY(v->g,1.0)-1;
   else 
     varyyy=DEVICEY(v->g,data->variance)-1;

}

/*  initialize the axis values and draw the axis*/

void init_viewport(g, xx, yy, n)
graph_t *g;
float *xx, *yy;
int n;
{

        
        minmax1d(xx, n, &g->ax.min, &g->ax.max);
        minmax1d(yy, n, &g->ay.min, &g->ay.max);

        human_scale(&g->ax); /* defined in axis.c */
        human_scale(&g->ay);

        g->ax.n=5, g->ay.n=5;
        g->ax.step=(g->ax.max-g->ax.min)/5;
        g->ay.step=(g->ay.max-g->ay.min)/5;
        g->sx = (g->ax.max - g->ax.min)/(float)(g->w);
        g->sy = (g->ay.max - g->ay.min)/(float)(g->h);

        g->ax.nt_minor=4;
        g->ay.nt_minor=4;
        

        g->titleFont = small_font;
        g->numberFont = small_font;
         g->labelFont = small_font;

}
 

void v_reduce(win, event, params, num_params)
Window win;
XEvent *event;
String *params;
Cardinal *num_params;
{
        int i;
        int w, h, x, y;
        w = graph[0].W * 0.9;
        h = graph[0].H * 0.9;
        if (w<=10 || h<=10) {
                fprintf(stderr, "Further reduction not allowed\n");
                return;
        }
        x = w * .15, y = h * .10;

        XtUnmanageChildren(canvas, ng);
        for (i=0; i<ng; i++) {
                graph_t *g = &graph[i];
                g->W = w, g->H = h;
                g->x = x, g->y = y;
                g->w = g->W-g->x*1.5; /* no label on rhs edge */
                g->h = g->H-2*g->y;   /* both title and x label needed */
                XtVaSetValues(canvas[i], XmNwidth, g->W, XmNheight, g->H, NULL);
                g->sx = (g->ax.max - g->ax.min)/(float)(g->w);
                g->sy = (g->ay.max - g->ay.min)/(float)(g->h);
        }

        for (i=0; i<ng; i++)
                if (var[i].idir==cdir)
                        var_to_device(&var[i]);

        XtManageChildren(canvas, ng);
}
void v_enlarge(w, event, params, num_params)
Window w;
XEvent *event;
String *params;
Cardinal *num_params;
{
        int i;
        XtUnmanageChildren(canvas, ng);
        for (i=0; i<ng; i++) {
                graph_t *g = &graph[i];
                g->W = g->W / 0.9 ;
                g->H = g->H / 0.9;
                g->x = g->W * .15;
                g->y = g->H * .10;
                g->w = g->W-g->x-15;
                g->h = g->H-2*g->y;
                XtVaSetValues(canvas[i], XmNwidth, g->W, XmNheight, g->H, NULL);
                g->sx = (g->ax.max - g->ax.min)/(float)(g->w);
                g->sy = (g->ay.max - g->ay.min)/(float)(g->h);
        }

        for (i=0; i<ng; i++)
                if (var[i].idir==cdir)
                        var_to_device(&var[i]);

        XtManageChildren(canvas, ng);
}

void v_maximize(w, event, params, num_params)
Window w;
XEvent *event;
String *params;
Cardinal *num_params;
{
        static int maximized=FALSE;
        XtUnmanageChild(swindow);
        XtUnmanageChild(Drawing);
        XtUnmanageChildren(canvas, ng);
        nargs=0;
        setarg(XmNrightAttachment, XmATTACH_POSITION);
        if (!maximized) {
                setarg(XmNrightPosition, 100);
        } else {
                setarg(XmNrightPosition, 72);
        }
        XtSetValues(swindow, wargs, nargs);
        XtManageChild(Drawing);
        XtManageChildren(canvas, ng);
        XtManageChild(swindow);
        maximized = !maximized;
}

