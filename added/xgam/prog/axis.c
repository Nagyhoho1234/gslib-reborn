#include "axis.h"

#ifndef sparc
float exp10(x)
float x;
{ 
	return(exp(log(10.)*x));
}
#endif

int human_scale(ax)
axinfo *ax;
{
    float  q,span,stop;
	float lo = ax->min, hi = ax->max;

    if ((span = hi - lo) < 0)  return FALSE;
    hi += .05*span;               /* widen it a little */
    lo -= .05*span;
    span = hi - lo;
    ax->step =  exp10(floor(log10(span/5.)));

    q = span / ax->step;
        if (q>=8)  ax->step *= 2.;
        if (q>20)  ax->step *= 2.5;
    ax->start = (floor(lo / ax->step)+1)* ax->step;
    if ((ax->start - lo) < span/20  )    /* make room at both ends   */
        lo = ax->start-span/20;        /* so ticks do not fall too */
    ax->n=floor((hi - ax->start) / ax->step); /* close to the frame.   */
    stop = ax->start + ax->step * ax->n;
    if ((hi - stop) < span/20)
       hi= stop + span/20;
    ax->add = 0;
    q = MAX(fabs(ax->start),fabs(stop));
    if ((hi - lo)/q < 1.11e-2){
    /* if range is small wrt to  the values (like in 1.002..1.003) */
       ax->add = ax->start;
    }
    q = MAX(fabs(ax->start-ax->add),fabs(stop-ax->add));
    ax->exp = floor(log10(q));

	{
	float f;
	int dec;
	/* JC ADDED: fabs() so that it does not run into inf. loop when hi<0 */
	float tmp= (hi>=0) ? hi : fabs(hi);
	for (f=1.0, dec=3; tmp/f>1.;f*=10.,dec--);
    for (f=1.0, dec=1; tmp/f<1.;f/=10.,dec++);
    if (dec<0) dec=0;
    ax->precision = dec;

	if (hi<0) ax->start -= ax->step, ax->n++;
	}

	ax->min = ax->start;
	ax->max = ax->start + ax->step * (1+ax->n);

    return TRUE;
}

#define SMALL 1.0e-10
/* round down a number */
double round_down(x)
double x;
{
   double pow();
   double inc, xnew, dpower;
   int    power;

   /* round down x */
   dpower = log10(fabs(x+SMALL));
   power  = (dpower > -SMALL) ? (int)dpower : (int)dpower - 1;
   inc    = pow(10.0,(double)power);
   if (x > -SMALL)
      xnew = inc * ((int)(x/inc + SMALL));
   else
      xnew = inc * ((int)(x/inc + SMALL) - 1);
   return(xnew);
}

/* round up a number */
double round_up(x)
double x;
{
   double pow();
   double inc, xnew, dpower;
   int    power;

   /* round up x */
   dpower = log10(fabs(x+SMALL));
   power  = (dpower > -SMALL) ? (int)dpower : (int)dpower - 1;
   inc    = pow(10.0,(double)power);
   if (x > SMALL)
      xnew = inc * ((int)(x/inc - SMALL) + 1);
   else
      xnew = inc * ((int)(x/inc - SMALL));
   return(xnew);
}
