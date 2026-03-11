#ifndef YAP_H
#define YAP_H

#include <math.h>
#include <stdio.h>
#include <Xm/Frame.h>
#include <X11/Xlib.h>

#define VERSION "1.7"

/* Maximum number of colors in a colormap */
#define MAX_NB_COLOR 256
#define MAX_NB_CUT   256

#define XFLUSH     FALSE
#define MAX_COLOR  65535

#define FACT_H        .6

enum print_modes   { PORTRAIT, LANDSCAPE };
enum class_modes   { ARITHMETIC, LOGARITHMIC, QUANTILES };
enum scale_modes   { RATIO_MODE, FOLLOW_MODE };
enum device_modes  { PSFILE, SCR_CLEAR, SCR_NOCLEAR };
enum axis_indexes  {  X,  Y,  Z };
enum plane_indexes { YZ, XZ, XY, THREED };
enum file_type     { UNKNOWN, FBINARY, CBINARY, CLASSBIN, STEVE, GSLIB, EXTGSL};
enum b_widgets     { B_STAT, B_OPEN, B_SCALE, B_COMP, B_DEBUG };

#define FMAGIC       222
#define CMAGIC       223
#define STRING1      256
#define STRING2     1024

#define  VERYBIG   1e+36

#define  MMIN(a, b)  ( (a) < (b) ? (a) : (b) )
#define  MMAX(a, b)  ( (a) > (b) ? (a) : (b) )
#define  SIGN(a)    ( (a) > 0 ? (1) : (-1) )

#define  CALLOC(n, type)      (type *)calloc(n, sizeof(type))

#define  CANTALLOC(nb, vv, ff) \
   { \
   fprintf(stderr, "\nCannot perform malloc for vv in function ");\
   fprintf(stderr, ff);\
   fprintf(stderr, " (%d element(s)), exiting\n", nb);\
   exit(1); \
   }

#define WIN2D_MANAGED(p) (widgets->win2d[p] && XtIsManaged(widgets->win2d[p]))
#define WINST_MANAGED(p) (widgets->winst[p] && XtIsManaged(widgets->winst[p]))

typedef int     BOOLEAN;

typedef struct Color_t
   {
   float           r, g, b;
   }               Color_t;

typedef struct Stat_t
   {
   char            name[STRING2];
   int             nb;
   float           sum;
   float           mean, std_dev, coef_var;
   float           min, lower_q, median, upper_q, max;
   }               Stat_t;

typedef struct World_t
   {
   FILE           *file;
   int             type;
   char            prg_name[STRING2];
   char            cmap_name[STRING2];
   char            base[STRING2];
   char            name[STRING2];
   char            title[STRING2];
   char            var_name[STRING2];
   int             nb_data, n[3], nb_saved;
   BOOLEAN         refresh, loaded, help_file;
/* The following are defined in yaconfig.h, can be changed by user */
   BOOLEAN         change_trim, comp_stat, comp_quant;
/* This one is defined in yap.h, shouldn't be modified by user */
   BOOLEAN         xflush;
   float           min, max, *values, t_min, t_max;

   int             nb_var, var_no;

   float           scaling[3];
   BOOLEAN         show_line[3];

   int             nb_col_int;
   int             nb_class;    /* nb_cutoffs = nb_class + 1 */
   int             mode;        /* ARITHMETIC or LOGARITHMIC */
   int            *nbpc[4];     /* number per class for each plane */
   int             nbmax[4];
   unsigned char  *class_table;
   Color_t        *color;       /* color[0..nb_class+1].r,g,b */
   float          *cutoffs;
   int             current_cutoff;
   float          *quant;
   int             sld[4];      /* sld[3] = 1, for 3D stat */

   float           show_min, show_max;

   void           *pntr;
   }               World_t;

typedef struct Widgets_t
   {
   Widget          top, main_win, debug_area, nbcut, cutoff, allcut;
   Widget          winst[4], winst_area[4], winst_loc[4];
                   /* 3 used for 3D */
   Widget          win2d[3], win2d_area[3], win2d_loc[3], slide[3];
   Widget          win3d_area, comp_area, timer_label, timer_area;
   Widget          cutoff_txt, cutoff_lbl, allcut_txt;
   Pixel          *pixels, white, black;
   Display        *dpy;
   GC              gc;
   }               Widgets_t;

/* Start of function declarations */

extern void scale_cb(Widget w , int plane , XtPointer un1);
extern void print_win2d(Widget un1 , int plane , XtPointer un2);
extern void init_2d_indexes(void );
extern void draw_rectangle_scr(Window win , int x , int y , int dx , int dy);
extern void fill_rectangle_scr(Window win , int x , int y , int dx , int dy);
extern void set_color_scr(int class);
extern void draw_plane(int plane , int device);
extern void win2d_location(Widget un1 , int plane , XEvent * event);
extern void win2d_inout(Widget un1 , int plane , XEvent * event);
extern void init_3d_indexes(void );
extern void draw_3d_cube(BOOLEAN clear_before);
extern BOOLEAN read_cmap(char * filename);
extern void default_cmap(void );
extern void cmap_fn(void );
extern int Get_Colormap(int old_nb_cl , int new_nb_cl , int nb_c_i);
extern Stat_t compute_stat(int plane);
extern void init_compute(void );
extern void set_default_cutoffs(void );
extern void get_class_table(void );
extern void allcut_set_cb(Widget un1 , Widget dialog , XtPointer un2);
extern void cutoff_set_cb(Widget un1 , Widget dialog , XtPointer un2);
extern void nbclass_mode_cb(Widget un1 , int which , XmToggleButtonCallbackStruct * un2);
extern void l_arrow_cb(Widget un1 , XtPointer un2 , XtPointer un3);
extern void r_arrow_cb(Widget un1 , XtPointer un2 , XtPointer un3);
extern void cutoff_cancel_cb(Widget un1 , Widget dialog , XtPointer un2);
extern void nbclass_set_cb(Widget un1 , Widget dialog , XtPointer un2);
extern void p_area();
extern void create_debug(void );
extern void debug_fn(void );
extern void save_fn(void );
extern void open_fn(void );
extern void refresh_all(void );
extern void main(int argc , char * * argv);
extern BOOLEAN file_check(char * filename);
extern BOOLEAN file_read(void );
extern BOOLEAN file_save(char * name , int type);
extern void set_get_hs(void );
extern void winst_pdf_cb(Widget un1 , int plane , XtPointer un2);
extern void winst_cdf_cb(Widget un1 , int plane , XtPointer un2);
extern void winst_label(Widget un1 , int plane , XEvent * event);
extern int get_h_pdf(int y , int h_cl , int h_max , int un1);
extern int get_h_cdf(int y , int h_cl , int un1 , int plane);
extern void draw_stat(int plane , int device , BOOLEAN draw_nb);
extern void display_info(Widget area);
extern void comp_cb(Widget un1 , int plane , XtPointer un2);
extern void message(char * prgname);
extern void help(char * prgname);
extern BOOLEAN isnumber(char * string);
extern void PostDialog(Widget parent , int dialog_type , char * title , char * text , char * label);
extern void quit_fn(void );
extern void set_timer(float prop);
extern Widget CreateTimerForm(Widget parent);
extern void UpdateDisplay(void );
extern void init_timer(char * title);
extern void NewCursor(Widget w, unsigned int shape);
extern void param_fn(void );
extern void varia_fn(void );
extern void show_defaults(int all );
extern void MySetSensitive(int   b_widget, int plane, BOOLEAN what);
extern void print_mem(char * msg);
#endif
