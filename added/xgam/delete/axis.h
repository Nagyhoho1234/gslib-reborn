#ifndef _AXIS_H
#define _AXIS_H 1

#include <math.h>
#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef MAX
#define MAX(a,b) ((a>b)?a:b)
#endif

typedef struct { 
    float    start, /* position of first tick mark */
    step,  /* tick mark spacing */
    add;   /* if interval is 123456.1..123456.2, add = 123456 */
    int     n,     /* number of ticks within interval */
    exp,   /* exponent for numbers */
	precision;
	float min, max;
	int nt_minor;
} axinfo;

#endif
