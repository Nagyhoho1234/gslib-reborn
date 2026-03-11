#include "xutil.h"

XtArgVal GetColor(colorstr)
char *colorstr;
{
   XrmValue from, to;

   from.size = strlen(colorstr) +1;
   if (from.size < sizeof(String)) from.size = sizeof(String);
   from.addr = colorstr;
   to.addr = NULL;
   XtConvert(toplevel, XmRString, &from, XmRPixel, &to);

    if (to.addr != NULL)
      return ((XtArgVal)((Pixel) *((Pixel *) to.addr)));
    else
      return ( (XtArgVal) NULL);
}

void highlight(w, active)
Widget w;
int active;
{
	XtSetArg(wargs[0], XmNborderWidth, 1);
	XtSetArg(wargs[1], XmNborderColor, GetColor((active)?"red":"white"));
	XtSetValues(w, wargs, 2);
}

/* the following two functions define a rainbow style colormap */
#define MAXCOLOR 65535
#define RED 0
#define GREEN 1
#define BLUE 2
#define GRAY 3
XColor color(x,x1,x2,x3,x4,y0)
float x,x1,x2,x3,x4,y0;
{
XColor color;
int r,g,b;

/* red */
    if (x<x1) r=(int)((x1-x)/(x1-0.)*y0);
    else if (x<x3) r=0;
    else if (x<x4) r=(int)((x-x3)/(x4-x3)*MAXCOLOR);
    else r=MAXCOLOR;

    if (r<0) r=0;
    if (r>MAXCOLOR) r=MAXCOLOR;

/* green */
    if (x<x1) g=0;
    else if (x<x2) g=(int)((x-x1)/(x2-x1)*MAXCOLOR);
    else if (x<x4) g=MAXCOLOR;
    else g=(int)((MAXCOLOR-x)/(MAXCOLOR-x4)*MAXCOLOR);

    if (g<0) g=0;
    if (g>MAXCOLOR) g=MAXCOLOR;

/* blue */
    if (x<x2) b=MAXCOLOR;
    else if (x<x3) b=(int)((x3-x)/(x3-x2)*MAXCOLOR);
    else b=0;

    if (b<0) b=0;
    if (b>MAXCOLOR) b=MAXCOLOR;

    color.red=r;
    color.green=g;
    color.blue=b;
    return color;
}

#define BASIC_COLORS 5
Colormap initDefaultColors(display, pixels, rgb, nclass, icolor)
Display *display;
unsigned long pixels[];
float **rgb;
int nclass;
Boolean icolor;
{
    Colormap   theColormap = DefaultColormap(display, DefaultScreen(display));
    XColor          clr;
    int             i,j;
    float x0=0.01, x1=0.+x0*MAXCOLOR, h=(MAXCOLOR-x0*MAXCOLOR)/4.;
	float x2=x1+h, x3=x2+h, x4=x3+h, y0=MAXCOLOR*(x1-0.)/h; 

	if (nclass<=1) {
		fprintf(stderr, "Error: initDefaultColors(): nclass<=1\n");
		return;
	}

    for (i=0;i<nclass;i++) {
       	float x=(float)(i*MAXCOLOR)/(float)(nclass-1);
       	clr = color(x,x1,x2,x3,x4,y0);

		if (!icolor)
			clr.red = clr.green = clr.blue = (nclass-i-1)*MAXCOLOR/(nclass-1);
		rgb[i][RED] = (float)clr.red/(float)MAXCOLOR;
		rgb[i][GREEN] = (float)clr.green/(float)MAXCOLOR;
		rgb[i][BLUE] = (float)clr.blue/(float)MAXCOLOR;
		rgb[i][GRAY] = (float)(nclass-i-1)/(float)(nclass-1);
    	if (XAllocColor(display, theColormap, &clr))
       		pixels[i]=clr.pixel;
		else 
			fprintf(stderr, "warning: failed in allocating color %d\n",i);
    }
    return theColormap;
}

