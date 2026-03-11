#include "util2.h"
#include "xutil.h"
#include "WidgetWrap.h"
#include <Xm/DialogS.h>
#include <Xm/PushBG.h>
#include <Xm/LabelG.h>

void create_tick_dialog();
void create_title_dialog();

static int axis_id;
static Widget *axis;
static Widget *tlskip;
static Widget label_title_text_item;
static Widget tick_edit_dialog, label, label_text;
static Widget min_max;
static Widget *n_major_ticks, *n_minor_ticks;
static Widget *tick_applyto, *title_applyto;
static Widget *n_precision;

static Widget title_edit_dialog;
static Widget title_text_item;

static void (*update_viewport)();
static int current_graph_id, ngraph;

void DialogDismissCB(Widget w, Widget dialog)
{
    XtUnmanageChild(dialog);
}

update_title_proc(g)
graph_t *g;
{
    if (title_edit_dialog) {
        xv_setstr(title_text_item, g[current_graph_id].title);
    }
}

select_axis_proc(Widget w, graph_t *g)
{
    axis_id = xv_GetChoice(axis);
    update_tick_proc(g);
}

update_tick_proc(g)
graph_t *g;
{
    a_string buf;
    axinfo *a = (axis_id) ? &g[current_graph_id].ay : &g[current_graph_id].ax;
    if (!tick_edit_dialog) return;
    xv_SetChoice(axis, axis_id);
    xv_SetChoice(n_major_ticks, a->n);
    xv_SetChoice(n_minor_ticks, a->nt_minor);
    xv_SetChoice(n_precision, a->precision);
    sprintf(buf, "%%.%df    %%.%df", a->precision, a->precision);
    wprintf_text(min_max, buf, a->min, a->max);
}
void scale_viewport(g)
graph_t *g;
{
    g->sx = (g->ax.max - g->ax.min)/(float)(g->w);
    g->sy = (g->ay.max - g->ay.min)/(float)(g->h);
        /*
        g->ax.start = g->ax.min;
        g->ay.start = g->ay.min;
        */
}

void ok_tick_proc(w, g)
Widget w;
graph_t *g;
{
    int i, applyto=xv_GetChoice(tick_applyto);
    int t_major = xv_GetChoice(n_major_ticks);
    int t_minor = xv_GetChoice(n_minor_ticks);
    int t_precision = xv_GetChoice(n_precision);
    float t_min, t_max, t_step;
    axinfo *a; 
    if (sscanf(XmTextGetString(min_max), "%f%f", &t_min, &t_max)<2
        || t_min>=t_max ) {
        xerror(toplevel, "Invalid minimum and/or maximum values");
        return;
    }
    t_step = (t_max - t_min) / t_major;
    switch (applyto) {
    case 0:
        i=current_graph_id;
        a = (axis_id)? &g[i].ay : &g[i].ax;
        a->n = t_major, a->min=t_min, a->max=t_max, a->step=t_step;
        a->precision=t_precision;
        a->nt_minor = t_minor;
        scale_viewport(g+i);
        update_viewport(i);
        break;
    case 1:
        for (i=0; i < ngraph; i++) {
            if (!g[i].active) continue;
            a = (axis_id)? &g[i].ay : &g[i].ax;
            a->n = t_major, a->min=t_min, a->max=t_max, a->step=t_step;
            a->precision=t_precision;
            a->nt_minor = t_minor;
            scale_viewport(g+i);
            update_viewport(i);
        }
        break;
    case 2:
        for (i=0; i<ngraph; i++) {
            a = (axis_id)? &g[i].ay : &g[i].ax;
            a->n = t_major, a->min=t_min, a->max=t_max, a->step=t_step;
            a->precision=t_precision;
            a->nt_minor = t_minor;
            scale_viewport(g+i);
            update_viewport(i);
        }
        break;
    }
}

void ok_title_proc(Widget w, graph_t *g)
{
    int i, applyto=xv_GetChoice(title_applyto);
    ASSERT("apply to %d", applyto);
    switch (applyto) {
    case 0: 
        i=current_graph_id;
        strcpy(g[i].title, (char *)xv_getstr(title_text_item));
        update_viewport(i);
        break;
    case 1: 
        for (i=0; i<ngraph; i++) {
            if (!g[i].active) continue;
            strcpy(g[i].title, (char *)xv_getstr(title_text_item));
            update_viewport(i);
        }
        break;
    case 2: 
        for (i=0; i<ngraph; i++) {
            strcpy(g[i].title, (char *)xv_getstr(title_text_item));
            update_viewport(i);
        }
        break;
    }
}

void create_tick_dialog(g, ng, ig, which, cb) 
graph_t *g;
int ng, ig, which;
void (*cb)();
{
    Widget panel, ok, dismiss;
    a_string buf;
    int i, irow=0;
    if (tick_edit_dialog) {
        XtManageChild(tick_edit_dialog);
        update_tick_proc(g);
        return;
    }

    update_viewport = cb;
    current_graph_id = ig;
    ngraph = ng;

    axis_id = which;

    tick_edit_dialog = XmCreateDialogShell(toplevel, "Axes", NULL, 0);
    panel = WidgetCreate("axes panel", xmBulletinBoardWidgetClass,
    tick_edit_dialog, XmNautoUnmanage, False, XtNmanaged, False, NULL);

         axis          = CreatePanelChoice(panel, "Change Axis:",
                         xv_col(panel, 15),
                         xv_row(panel, irow++),
                         3, 
                         "X", "Y", 0,
                         0);
    for (i=0; i<2; i++) 
    XtAddCallback(axis[2+i], XmNactivateCallback, select_axis_proc, g);

 label_title_text_item = (Widget) CreateTextItem(panel,
                         xv_col(panel, 15),
                         xv_row(panel, irow++),
                         30, "Axis Label:");
               min_max = (Widget) CreateTextItem(panel, 
                         xv_col(panel, 15),
                         xv_row(panel, irow++),
                         30, "Minimum and maximum:");
         n_precision   = CreatePanelChoice(panel, "Number of decimal points:",
                         xv_col(panel, 15),
                         xv_row(panel, irow++),
                         5, 
             "0", "1", "2", "3", "4", "5", 0,
             0);
         n_major_ticks = CreatePanelChoice(panel, "Number of major ticks:",
                         xv_col(panel, 15),
                         xv_row(panel, irow++),
                         10, 
             "1", "2", "3", "4", "5", "6", "7", "8", "9", 0,
             0);
         n_minor_ticks = CreatePanelChoice(panel, "Number of minor ticks:",
                         xv_col(panel, 15),
                         xv_row(panel, irow++),
                         6, "0", "1", "2", "3", "4", 0);
          tick_applyto = CreatePanelChoice(panel, "Apply to:",
                        xv_col(panel, 15),
                         xv_row(panel, irow++),
                        4,
                         "Current Graph",
                         "Selected Graph(s)",
                         "All Graphs",
                         NULL,
                         0);
    CreateDialogBottomLine(panel, 40, irow, 
                ok_tick_proc, g,
                DialogDismissCB, tick_edit_dialog,
                NULL, NULL);
    XmAddTabGroup(panel);
    update_tick_proc(g);
    XtManageChild(panel);
    XtManageChild(tick_edit_dialog);
}

void create_title_dialog(graph_t *g, int ng, int ig, void (*cb)()) 
{
    Widget panel, ok, dismiss;
    int irow=0;
    update_viewport = cb;
    current_graph_id = ig;
    ngraph = ng;

    if (title_edit_dialog) {
        XtManageChild(title_edit_dialog);
        update_title_proc(g);
        return;
    }

    title_edit_dialog = XmCreateDialogShell(toplevel, "Title", NULL, 0);
    panel = WidgetCreate("title panel", xmBulletinBoardWidgetClass,
        title_edit_dialog, XmNautoUnmanage, False, 
        XtNmanaged, False, NULL);

                         WidgetCreate("Title Attributs", xmLabelGadgetClass, panel,
                 XmNx, xv_col(panel, 1),
                 XmNy, xv_row(panel, irow++),
                 NULL);
       title_text_item = (Widget) CreateTextItem(panel,
                         xv_col(panel, 10),
                         xv_row(panel, irow++),
                         40, "Title String:");
         title_applyto = CreatePanelChoice(panel, "Apply to:",
                        xv_col(panel, 10),
                         xv_row(panel, irow++),
                        4,
                         "Current Graph",
                         "Selected Graph(s)",
                         "All Graph(s)",
                         NULL,
                         0);
    CreateDialogBottomLine(panel, 40, irow, 
                ok_title_proc, g,
                DialogDismissCB, title_edit_dialog,
                NULL, NULL);
    XmAddTabGroup(panel);
    update_title_proc(g);
    XtManageChild(panel);
    XtManageChild(title_edit_dialog);
}

#define CENTER 0
#define TITLE  1
#define AXIS_X 2
#define AXIS_Y 3
int click_inside(int x, int y, graph_t *g, int ng, int ig, void (*cb)())
{
    int where;
    if (x>g->x && y>g->y && x<g->x+g->w && y<g->y+g->h) where= CENTER;
    if (x<g->x && y>g->y && y<g->y+g->h) where= AXIS_Y;
    if (y>g->y+g->h && x>g->x) where= AXIS_X;
    if (y<g->y && x>g->x) where= TITLE;
    switch (where) {
        case AXIS_X:
            create_tick_dialog(g, ng, ig, 0, cb);
            break;
        case AXIS_Y:
            create_tick_dialog(g, ng, ig, 1, cb);
            break;
        case TITLE:
            create_title_dialog(g, ng, ig, cb);
            break;
        case CENTER:
            return TRUE;
        default:
            return FALSE;
    }
    return FALSE;
}

extern XFontStruct *small_font, *large_font;
draw_window(g)
graph_t *g;
{
    int i, j, x=g->x, y=g->y-5;
    a_string str, format;
    int step;

    XSetFont (display, xgc, g->titleFont->fid);
    XDrawString(display, g->win, xgc, x, y, g->title, strlen(g->title));
    XDrawRectangle(display, g->win, xgc, g->x, g->y, g->w, g->h);
    
    XSetFont (display, xgc, g->numberFont->fid);
    y=DEVICEY(g,g->ay.min);
    step=DEVICEX(g, g->ax.step);
    sprintf(format, "%%.%df", g->ax.precision);
    for (i=0; i<=g->ax.n; i++) {
        float xx=g->ax.min+g->ax.step*i;
        int tw;
        sprintf(str, format, xx);
        x=DEVICEX(g, xx);
        XDrawLine(display, g->win, xgc, x, y, x, y-4);
        tw=XTextWidth(small_font, str, strlen(str));
        XDrawString(display, g->win, xgc, x-tw/2, y+15, str, strlen(str));
        if (i!=g->ay.n)
        for (j=0; j<g->ax.nt_minor; j++) {
            x = DEVICEX(g, xx+ g->ax.step * (j+1) / (g->ax.nt_minor+1));
            XDrawLine(display, g->win, xgc, x, y, x, y-2);
        }
    }
    x=DEVICEX(g,g->ax.min);
    sprintf(format, "%%.%df", g->ay.precision);
    for (i=0; i<=g->ay.n; i++) {
        float yy=g->ay.min+g->ay.step*i;
        int tw;
        sprintf(str, format, yy);
        y=DEVICEY(g,yy);
        XDrawLine(display, g->win, xgc, x, y, x+4, y);
        tw=XTextWidth(small_font, str, strlen(str));
        XDrawString(display, g->win, xgc, x-tw-5, y+4, str, strlen(str));
        if (i!=g->ay.n)
        for (j=0; j<g->ay.nt_minor; j++) {
            y = DEVICEY(g, yy+ g->ay.step * (j+1) / (g->ay.nt_minor+1));
            XDrawLine(display, g->win, xgc, x, y, x+2, y);
        }
    }
}

