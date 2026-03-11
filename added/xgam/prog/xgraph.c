#include "xgam.h"
#include "vario.h"

draw_window(g)
graph_t *g;
{
    int i, j, x=g->x, y=g->y-5;
    char str[256], format[256];
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
