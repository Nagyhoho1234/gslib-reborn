#include "xutil.h"
#include "util.h"
#include "genlib.h"

#define NumStates  4
#define BaseMap    0
#define SelectVar  1
#define VarioCal   2
#define VarioModel 3
#define BUFSIZE 256
#define MAXNVARS 30
#define NVARIABLES 5
#define TRUE 1
#define FALSE 0
#define ExitState  4

typedef struct {
        Widget ParPanel, Drawing;
        int (*create)();
        int active;
} state_t;

typedef struct {
        char filename[BUFSIZE], title[BUFSIZE];
        char *varname[MAXNVARS];
        float **rdat, min[NVARIABLES], max[NVARIABLES];
        int icol[NVARIABLES];
        float trim_min, trim_max;
        float variance;
     
        int width, height;
        int last_x, last_y;

        int nv, nd;

        /* for exhaustive data */
        int nx, ny, nz;
        float dx, dy, dz;

        int threed, exhaustive;
        float max_lag;
        int ncol;
} graphics_data;

typedef struct {
        char *name;
        void (*cb)();
} _Option;

