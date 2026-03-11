#ifndef _UTIL_H
#define _UTIL_H 1

#include <stdio.h>
#include <math.h>
#include <limits.h>

/* some handy defs */
#define bool char
#ifndef TRUE
#define TRUE (1)
#endif
#ifndef FALSE
#define FALSE (0)
#endif
#define Null(t) ((t)0)
#define Nullch Null(char *)
#define Nullfp Null(FILE *)

#define Ctrl(ch) (ch & 037)

#define strNE(s1,s2) (strcmp(s1,s2))
#define strEQ(s1,s2) (!strcmp(s1,s2))
#define strnNE(s1,s2,l) (strncmp(s1,s2,l))
#define strnEQ(s1,s2,l) (!strncmp(s1,s2,l))
#define HUGE 1.0e21

/* constant */
#define PI 3.1415926536
#define BUFSIZE   256
#define SMALL 1.0e-10
#define TINY 1.0e-20
#define MISSING (-9999)

#if defined(__alpha) || defined(__mips64)
#define RAND1() ((float)random()/(float)INT_MAX)
#else
#define RAND1() ((float)random()/(float)LONG_MAX)
#endif

#define ON 1
#define OFF 0
#define ALLOC(type, n)  (type *) malloc((unsigned) sizeof(type) * n)
#define NIL(type)            (type *) 0
#define FREE(item)           (void) free(item)
#define ABS(x) ((x)>0. ? (x) : (-(x)))
#define MIN(x, y) ((x)<(y) ? (x) : (y))
#define MAX(x, y) ((x)>(y) ? (x) : (y))
#define CLAMP(v,l,h)    ((v)<(l) ? (l) : (v) > (h) ? (h) : v)
#define SWAP(a,b) ({ typeof(a) temp = (a); (a) = (b); (b) = temp; })

#define LaserPrinter 0
#define PostScript   1
#define TextFile   2

#define NVARIABLES 5
typedef enum {
	GamX, GamY, GamZ, HEAD, TAIL
} gam_variableType;
#define GamX 0
#define GamY 1
#define GamZ 2
#define HEAD 3
#define TAIL 4

/*
#define DEBUG(x) {printf x; fflush(stdout);}
*/
#define DEGREES(x) ((x)*180./PI)
#define RADIUS(x)  ((x)*PI/180.)

/* also make changes in ../util/regular.c if you change the next two lines
*/
#define NHISTSAVE 30
#define LINESIZE 256
extern char hist[NHISTSAVE][LINESIZE];

/* image class */
#define SIMULATION 0
#define EXHAUSTIVE_DATA 1
#define SCATTERED_DATA 2

typedef char a_string[BUFSIZE];
/*
typedef double Matrix3[3][3];
typedef double Matrix4[4][4];
*/


extern int *ivector();
extern int **imatrix();
extern int ***iblock();
extern float *vector();
extern float **matrix();
extern float ***black();
extern double *dvector();
extern void free_vector();
extern void free_matrix();
extern void free_block();

extern int gslib_output();
extern float gasdev();

#endif
