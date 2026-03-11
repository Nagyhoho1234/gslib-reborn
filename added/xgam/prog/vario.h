/* #include "xutil.h" */
#include "axis.h"

#define MAXNVARIOS 25
#define MAXNLAGS 601
#define NMODELSTEPS 50
#define PI 3.1415926536
#define BUFSIZE   256
#define SMALL 1.0e-10
#define TINY 1.0e-20

#define X 0
#define Y 1
#define Z 2
#define PRIMARY 3
#define SECONDARY 4


/* variogram parameters */
#define NPARS 8
#define DIRECTION 0
#define DIRTOL    1
#define DIRBAND   2
#define DIP       3
#define DIPTOL    4
#define DIPBAND   5
#define LAG       6
#define LAGTOL    7

#define MAXNVARTYPES 9
typedef enum {
    Traditional_semivariogram,
    Traditional_cross_semivariogram,
    Covariance,
    Correlogram,
    General_relative_semivariogram,
    Pairwise_relative_semivariogram,
    Semivariogram_of_logarithms,
    Semimadogram,
} varioType;

typedef struct {
        int id;
        char title[256];
        XFontStruct *titleFont, *numberFont, *labelFont;
         Window win;
        int x, y, w, h, W, H;
        float sx, sy;
        axinfo ax, ay;
        int active;
} graph_t;


typedef struct _PAIR {
        /* float vrh, vrt; */
        int head, tail;
        int removed;
        struct _PAIR *next;
} PAIR;
#define ABS(x) ((x)>0. ? (x) : (-(x)))

#define MAXNMODELTYPES   5
#define NST  4

typedef enum {
        VM_NUGGET, VM_SPHERICAL, VM_EXPONENTIAL, VM_GAUSSIAN, VM_POWER
} modelType;

typedef struct {
        graph_t *g;
        int irow;
        modelType type[NST];
        float sill[NST], range[NST];
        float ang1[NST], ang2[NST], ang3[NST], anis1[NST], anis2[NST];
} model_data;

/* variogram data structure: */
typedef struct {
        char title[BUFSIZE];

        /* parameters used in calculation */
        int nlag;            /* number of lags */
        float dir, dirtol, dirband;
        float dip, diptol, dipband;
        float lagtol;
        PAIR **included; 
        int idir; /* 0 or 1 */

        /* variogram results */
        float lag[MAXNLAGS]; /* lag distances */
        float var[MAXNLAGS]; /* variogram values */
        int npt[MAXNLAGS];   /* number of pairs */

        /* variogram model */
        int  wt[MAXNLAGS];   /* weights used in modeling */
        model_data model;

        /* graphics */
        int id;  /* var or window id */
        graph_t *g; 
        XRectangle ddots[MAXNLAGS];
        int n_ddots;
        float dx, dy;       /* ??? */
}var_data;


