#ifndef _GSLIB_H
#define _GSLIB_H 1

#include <stdio.h>

/* constants */
#define DEG2RAD 3.14159265/180.0
#define EPSLON  1.0e-20

typedef enum {
	UNKNOWN,
    BINARY_GRIDED,
    GSLIB_DATA,
    GSLIB_VARIOGRAM
} fileType;
#define MAGIC 122

typedef enum { Scattered_data, Gridded_data } dataType;

typedef enum { X, Y, Z, V, W } variableType;

typedef enum {
	VM_NUGGET, VM_SPHERICAL, VM_EXPONENTIAL, VM_GAUSSIAN, VM_POWER
} modelType;

typedef enum { SK, OK } krigeType;

/* interpolation or extrapolation algorithm beyond descritized cdf */
/*
typedef enum {
    BEYOND_LINEAR,
	BEYOND2,
	BEYOND3,
    BEYOND_POWER,
    BEYOND_CLASS
} beyondType;
*/
#define BEYOND_LINEAR 1
#define	BEYOND2       2
#define	BEYOND3       3
#define BEYOND_POWER  4
#define BEYOND_CLASS  5

/* basic types and data structures */

typedef double gslib_t;

typedef struct {
	int x, y, z;
} ipoint_t;

typedef struct {
	float x, y, z, v, w;
} gslib_data_t;

typedef struct {
	int nx, ny, nz;
	float xmin, ymin, zmin;
	float xsiz, ysiz, zsiz;
	float ***val;
} grid_t;

typedef struct {
	int nctx, ncty, nctz; /* maxmum 3D covariance box size */
	int nctxy, nctxyz;
	int ***global_idx;
	int n_inside;     /* number of nodes inside search neighborhood */
	int n;        /* total number of nodes in ctable */ 
	int **idx;        /* coordinates for each node in ctable */
} ctable_info;

typedef struct {
	float *val;
	int   *idx;
} ctable_t;

#define GLOBAL_INDEX(i,j,k) \
	ctb_info.global_idx[k+ctb_info.nctz][j+ctb_info.ncty][i]

typedef struct {
	float ang1, ang2, ang3, anis1, anis2;
	float rotmat[3][3];
} anisotropy_t;

typedef struct {
	int type, max_per_octant;
	float max;
	anisotropy_t anis;
} search_t;

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

typedef struct {
	int type;
	float par;
} beyond_t;

/* external variables and functions */
extern float sqdist(), cova3(), ginv(), gcum(), powint(), linint();

extern int *ivector(), **imatrix(), ***iblock();
extern float *vector(), **matrix(), ***block();

extern void gslib_debug();
extern FILE *gslib_start_debugging();

extern float linint(), powint();
extern float gcum(), ginv();
extern float cova3();

#endif
