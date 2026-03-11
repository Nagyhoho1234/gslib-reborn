#include <stdio.h>

/* constants */
#define DEG2RAD 3.14159265/180.0
#define EPSLON  1.0e-20
#define UNKNOWN 0
#define BINARY_GRIDED 1
#define GSLIB_DATA 2
#define GSLIB_VARIOGRAM 3
#define MISSING -9999
#define MAX(a,b) ((a>b)?a:b)
#define SPHERICAL 0
#define EXPONENTIAL 1
#define GAUSSIAN 2
 
#define MAGIC 122

typedef enum { Scattered_data, Gridded_data } dataType;

typedef enum { X, Y, Z, V, W } variableType;

typedef enum {
        VM_NUGGET, VM_SPHERICAL, VM_EXPONENTIAL, VM_GAUSSIAN
} modelType;

/* return the type of a file: gslib data file (ASCII) or binary 3D array
   or GSLIB variogram file 
*/
#define MAGIC 122
#define return_unknown \
{fprintf(stderr, "%d>> %s", __LINE__,str); fclose(fp); return UNKNOWN;}
#define get_next_line() {\
do { if (!fgets(str, 256, fp)) {return_unknown;} } while (str[0]=='@'); }
typedef struct {
        float ang1, ang2, ang3, anis1, anis2;
        float rotmat[3][3];
} anisotropy_t;

/* a specific variogram */
typedef struct {
        int type;
        float range, sill, cmax;
        anisotropy_t anis;
} variogram_t;

/* a group of nested variograms construct a model */
typedef struct {
        int nst;
        float nugget, cmax;
        variogram_t *vario;
} model_t;



