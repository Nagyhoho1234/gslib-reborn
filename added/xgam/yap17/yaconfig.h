#ifndef YACONFIG_H
#define YACONFIG_H
                       /* Help file                                           */
                       /* Default colormap directory                          */
                       /* Default colormap                                    */

#define _HELP_FILE "/usr/people/london/development/yap/yap19/yap17.hlp"
#define _CMAP_DIR  "/usr/people/london/development/yap/yap19/CMAP"
#define _CMAP_DEF  "/usr/people/london/development/yap/yap19/CMAP/rainbow.cmap"

/*#define _HELP_FILE "/local/lib/yap/yap17.hlp"*/
/*#define _CMAP_DIR  "/local/lib/yap"*/
/*#define _CMAP_DEF  "/local/lib/yap/rainbow.cmap"*/


/* Silicon version */
/*#define _HELP_FILE "/usr/people/marsu/src/yap/yap17.hlp"*/
/*#define _CMAP_DIR "/usr/people/marsu/src/yap/CMAP"*/
/*#define _CMAP_DEF "/usr/people/marsu/src/yap/CMAP/rainbow.cmap"*/

/* /usr/local version */
/*#define _HELP_FILE "/usr/local/lib/yap/yap17.hlp"*/
/*#define _CMAP_DIR  "/usr/local/lib/yap"*/
/*#define _CMAP_DEF  "/usr/local/lib/yap/rainbow.cmap"*/

/* alpha version */
/*#define _HELP_FILE "/alpha1/marsu/src/yap/yap17.hlp"*/
/*#define _CMAP_DIR  "/alpha1/marsu/src/yap/CMAP"*/
/*#define _CMAP_DEF  "/alpha1/marsu/src/yap/CMAP/rainbow.cmap"*/

/*#define _HELP_FILE "/local/lib/yap/yap17.hlp"*/
/*#define _CMAP_DIR  "/local/lib/yap"*/
/*#define _CMAP_DEF  "/local/lib/yap/rainbow.cmap"*/

/* pangea version */
/*#define _HELP_FILE "/home/aes/marsu/lib/yap/yap17.hlp"*/
/*#define _CMAP_DIR  "/home/aes/marsu/lib/yap"*/
/*#define _CMAP_DEF  "/home/aes/marsu/lib/yap/rainbow.cmap"*/

/*#define _HELP_FILE "/home/aes/marsu/BP/WORK/YA/yap17.hlp"*/
/*#define _CMAP_DIR  "/home/aes/marsu/BP/WORK/YA/CMAP"*/
/*#define _CMAP_DEF  "/home/aes/marsu/BP/WORK/YA/CMAP/rainbow.cmap"*/

/* Sweet Hall version */
/*#define _HELP_FILE "/afs/ir.stanford.edu/users/m/marsu/src/yap/yap17.hlp"*/
/*#define _CMAP_DIR "/afs/ir.stanford.edu/users/m/marsu/src/yap/CMAP"*/
/*#define _CMAP_DEF "/afs/ir.stanford.edu/users/m/marsu/src/yap/CMAP/rainbow.cmap"*/

                       /* Default trimming values                             */
#define T_MIN        -9999.
#define T_MAX         9999.

                       /* Perspective angle (here 60 degrees)                 */
#define ANGLE  1.0471976
                       /* Number of labels on the colormap                    */
#define NB_LABEL       10
                       /* Default settings                                    */
#define COMP_STAT  TRUE  /* Compute stat      (can be overriden by +/- stat   */
#define COMP_QUANT FALSE /* Compute quantiles (can be overriden by +/- quant) */
#define SHOW_LINE  FALSE /* Show_line      (can be overriden by +/- show_line */

                       /* Default for Print window                            */
#define FILL_MAINTITLE  FALSE /* Put main title in window   TRUE or FALSE     */
#define FILL_XDIR       FALSE /* Put x title in window      TRUE or FALSE     */
#define FILL_YDIR       FALSE /* Put y title in window      TRUE or FALSE     */
#define XSIZE_DEF       0     /* Default x size (0->gslib compatible)         */
#define YSIZE_DEF       0     /* Default y size (0->gslib compatible)         */
#define ORIENTATION_DEF PORTRAIT /* PORTRAIT or LANDSCAPE                     */
#define PRINT_SCALE     FALSE /* */
#endif
