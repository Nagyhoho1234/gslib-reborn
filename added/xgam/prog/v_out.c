#include "xgam.h"
#include "vario.h"
#include <Xm/DialogS.h>
#define VERSION 1.0
#define PROGRAM "xgam"
#define XtNmanaged      "Managed"
#define MAXCHAR 256

enum {PSFile, VarioFile} deviceType = PSFile;
static char deviceName[2][256] = {"xgam.ps", "xgam.var"};

#define MAXARY 50

#define LeftMargin 125.
#define BotMargin  135.
#define PageWidth  485.
#define PageHeight 530.


extern int ng;
extern var_data var[MAXNVARIOS];
extern Widget toplevel;
extern graph_t graph[MAXNVARIOS];

static Widget Tmp[9];
extern void CancelCB();
extern float gam();

static Widget *DeviceType;
static Widget Error;

static int numColumns=2;

/* the bounding box size of one graph */
static float XYOutWidth, XYOutHeight; 

/* INTERFACE */
static void ApplyCB();
static void select_device_type();

extern void DialogDismissCB();
char *get_localtime()
{
   char      *ctime(), newtime[MAXCHAR];
   time_t    time();

   int       i;
   time_t    timeofday;
   char      *loctime;

   /* get the local time */
   timeofday = time((time_t*)0);
   loctime   = ctime(&timeofday);

   /* loctime has a '\n' in it, so delete that character */
   i=0;
   while ((loctime[i] != '\n') && (i<MAXCHAR)) {
      newtime[i] = loctime[i];
      i++;
   }
   newtime[i] = '\0';

   return newtime;
}
int str_to_ints(s, ary, max_n)
char *s;
int *ary, max_n;
{
        char *t=s;
        int n=0;
        while (1) {
                while (*t!='\0' && *t == ' ' || *t == ',') t++;
                if (n==max_n || 1!=sscanf(t, "%d", &ary[n])) break;
                n++;
                while (*t!='\0' && *t != ' ') t++;
        }
        return n;
}

void var_output(w)
Widget w;
{
    Widget Dialog=NULL, Panel;
    int i, irow=0;
    char str[64];
    static     char *list[]={
		"Filename            ", 
		"Variogram List         ", 
		"Number of Columns     ",
	};

	if (Dialog!=NULL) {
		XtManageChild(Dialog);
		return;
	}

	Dialog=XmCreateDialogShell(toplevel, "Xgam Output", NULL, 0);
	Panel=WidgetCreate(NULL, xmBulletinBoardWidgetClass, Dialog, 
		XmNautoUnmanage, False, XtNmanaged, False, NULL);

    DeviceType=CreatePanelChoice(Panel,
		      "Device Name",
		      xv_col(NULL, 15),
		      xv_row(NULL, irow++),
		      3,
		      "PostScript File",
		      "GSLIB Variogram File",
		      0
			  );
	for (i=0; i<2; i++)
	XtAddCallback(DeviceType[2+i], XmNactivateCallback,
		select_device_type, NULL);
	for (i=0; i<XtNumber(list); i++, irow++) 
		Tmp[i] = CreateTextItem(Panel, 
			xv_col(NULL, 15), xv_row(NULL, irow), 15, list[i]);
	Error=WidgetCreate(NULL, xmLabelWidgetClass, Panel, 
		XmNx, 0, 
		XmNy, xv_row(NULL, irow++), 
		NULL);
	CreateDialogBottomLine(Panel, 30, irow,
		ApplyCB, NULL,
		DialogDismissCB, Dialog,
		NULL, NULL);

    XtManageChild(Panel);
    XtManageChild(Dialog);

	/* set default */
	{
	int n=0;
	xv_SetChoice(DeviceType, deviceType);
    XmTextSetString(Tmp[0], deviceName[deviceType]);
	wprintf_text(Tmp[2], "%d", numColumns);
    str[0] = '\0';
    for (i=0; i<ng; i++)
    if (graph[i].active) {
		sprintf(str, "%s %d", str, i+1);
		n++;
	}
    XmTextSetString(Tmp[1], str);
	wprintf(Error, "%d variograms %s selected to print\n", 
		n, (n==1) ? "variogram is" : "variograms are");
	}
}

static void select_device_type()
{
	deviceType = xv_GetChoice(DeviceType);
	XmTextSetString(Tmp[0], deviceName[deviceType]);
}

static void ApplyCB(w)
Widget w;
{
    char filename[256];
    char *printlist;
    int ary[MAXARY], nary, iv;
    int np;

    strcpy(deviceName[deviceType], XmTextGetString(Tmp[0]));
    np=sscanf(XmTextGetString(Tmp[2]), "%d", &numColumns);
    if (np<1 || numColumns<=0) {
	xerror(w, "Error: invalid number of columns");
	return;
    } 

    switch (deviceType)
    {
       case PSFile:
          strcpy(filename, deviceName[deviceType]);
          break;
        case VarioFile:
            strcpy(filename, deviceName[deviceType]);
            break;
    }

     nary=str_to_ints(XmTextGetString(Tmp[1]), ary, MAXARY);
     printf("nary=%d\n",nary);
     if (nary<=0) {
      wprintf(Error, "ERROR: No variogram list to print");
      return;
    }
        /* error check of input variogram list */
      for (iv=0; iv<nary; iv++) {
        if (ary[iv]<1 || ary[iv]>ng) {
          wprintf(Error, "ERROR: illegal variogram id: %d", ary[iv]);
          return;
        }
     }

    if (deviceType == VarioFile) 
        create_text_file(filename, ary, nary);
    else {
	FILE *fps, *ftmp;
	char  str[256];

    	if ((fps = fopen(filename, "w"))==NULL) {
       	  wprintf(Error, "Error: cannot open file '%s'", filename);
          return;
    	}
        printf("3333%s\n",filename);

    	fprintf(fps, "%%!\n");
/*
    	fprintf(fps, "%%%%Creator: %s %s\n", PROGRAM, VERSION);

    	fprintf(fps, "%%%%Date: %s\n", get_localtime());
*/
	
	create_ps_file(fps, ary, nary); 
        printf("1111ps\n");

        fprintf(fps, "\nshowpage\n");
	fclose(fps);

        wprintf(Error,"%d variogram(s) saved in PostScript File `%s'", 
             nary, filename);
    }
}

create_text_file(filename, ary, nary)
char *filename;
int *ary;
int nary;
{
    FILE *fp;
    int exist, iv, il;
    float dummy=0.0;
    if ((fp = fopen(filename, "r"))!=NULL) {
        exist=1;
        fclose(fp);
    }
    if ((fp = fopen(filename, "a"))==NULL) {
        wprintf(Error, "Error: can not write to file '%s'", filename);
        return -1;
    }
    for (iv=0; iv<nary; iv++) {
        var_data *v = &var[ary[iv]-1];
		/*
        fprintf(fp, "%s\n", strstr(v->title, ":")+2);
		*/
        fprintf(fp, "%s\n", v->title+3);
        for (il=0; il<v->nlag; il++) {
            fprintf(fp, " %3d %12.3f %12.3f %8d %12.5f %12.5f\n",
            il, v->lag[il], v->var[il], v->npt[il], dummy, dummy);
        }
    }
    fclose(fp);
    if (!exist)
    wprintf(Error, "%d variogram(s) written in file '%s' in TEXT mode", 
        nary,filename);
    else
    wprintf(Error, "%d variogram(s) appended to file '%s' in TEXT mode", 
        nary,filename);
	return 0;
}

#define XYWidthInOutRatio 0.7
#define XYHeightInOutRatio 0.7
int create_ps_file(fp, ary, nary)
FILE *fp;
int *ary, nary;
{
    int i, j, iv;
    float x, y, x0;

    int numRows = nary/numColumns;
	if (!numRows) numRows++;
	else if (nary%numRows) numRows++;

    XYOutWidth = (float)(PageWidth-50)/(float)numColumns;
    XYOutHeight = XYOutWidth * 0.8;

    x0 = LeftMargin+10; /* 30 for y axis numbering + label */
    y=BotMargin+PageHeight;

	/* in case of page overflow */
	if (XYOutHeight*numRows>PageHeight) 
		XYOutHeight = (float)PageHeight/(float)numRows;
	if (XYOutWidth*numColumns>PageWidth) 
		XYOutWidth = (float)PageWidth/(float)numColumns;

	fprintf(fp, "%%%%BoundingBox: %.0f %.0f %.0f %.0f\n\n",
		LeftMargin, y-XYOutHeight*numRows-15, 
		x0+numColumns*XYOutWidth-(1-XYWidthInOutRatio)*XYOutWidth+10, 
		y-(1-XYHeightInOutRatio)*XYOutHeight+15);

    /* size of the xy plot boxes */
    fprintf(fp, "/XYOutWidth %f def\n", XYOutWidth); 
    fprintf(fp, "/XYOutHeight %f def\n", XYOutHeight); 
    fprintf(fp, "%%following two numbers control the spacing. (0,1]\n");  
    fprintf(fp, "/XYWidth  XYOutWidth  %f mul def\n", XYWidthInOutRatio);
    fprintf(fp, "/XYHeight XYOutHeight %f mul def\n", XYHeightInOutRatio);
    fprintf(fp, "/XYNumberingX true def\n");
    fprintf(fp, "/XYNumberingY true def\n");
    fprintf(fp, "/XYBoxClosed false def\n");
    fprintf(fp, "/XYTitlePosition {3 5} def\n");
    fprintf(fp, "/XYTitleDisplay true def\n");

	{
	FILE *ftmp;
	char str[256];
    if ((ftmp = fopen("./utiljc.pro", "r"))==NULL) {
       	xerror(toplevel, "Can not open file utiljc.pro");
       	return;
    } 
    while (fgets(str, BUFSIZE, ftmp)) fputs(str, fp);
	fclose(ftmp);
	}

    y -= XYOutHeight;
    for (iv=0; iv<nary; y-=XYOutHeight) {
      for (i=0, x=x0; i<numColumns && iv<nary; i++, x+=XYOutWidth) {
		var_data *v = &var[ary[iv++]-1];
		one_graph_ps(fp, x, y, v);
	  }
	}

    return 1;
}


one_graph_ps(fp, x, y, v)
FILE *fp;
float x, y;
var_data *v;
{
	float h, dh;
	int i, l;
	char fmt[256];
	fprintf(fp, "%%%%Begin VAR[%d]\n", v->id);
    fprintf(fp, "\n%%%s\n", v->title);
    fprintf(fp, "%f %f\n", x, y);
    fprintf(fp, "() %f %f %f %d\n", 
        v->g->ax.min, v->g->ax.max, v->g->ax.step, 5);
    fprintf(fp, "() %f %f %f %d\n", 
        v->g->ay.min, v->g->ay.max, v->g->ay.step, 5);
    fprintf(fp, "(%s) XYBox\n", v->title+4);

	sprintf(fmt, "(%%.%df)\n", v->g->ax.precision);
	fprintf(fp, "[\n");
	for (i=0; i<=v->g->ax.n; i++) 
		fprintf(fp, fmt, v->g->ax.min+v->g->ax.step*i);
	fprintf(fp, "] XYNumberX\n");
	sprintf(fmt, "(%%.%df)\n", v->g->ay.precision);
	fprintf(fp, "[\n");
	for (i=0; i<=v->g->ay.n; i++) 
		fprintf(fp, fmt, v->g->ay.min+v->g->ay.step*i);
	fprintf(fp, "] XYNumberY\n");

    fprintf(fp, "/XYPlot {moveto bullet} def\n");
    fprintf(fp, "[\n");
    for (l=0; l<v->nlag; l++) 
        fprintf(fp, "%f %f\n", v->lag[l], v->var[l]);
    fprintf(fp, "]\n");
    fprintf(fp, "%f %f XYPlotPoints\n\n", v->lag[0], v->var[0]);

    fprintf(fp, "%%model\n");
    fprintf(fp, "/XYPlot {lineto} def\n");
	fprintf(fp, "0.5 setlinewidth\n");
    fprintf(fp, "[\n");
    /* plotting interval of the models */
    dh=(float)((v->g->ax.max-v->g->ax.min)*0.85)/(float)NMODELSTEPS;
    for (h=v->g->ax.min; h<=v->g->ax.max*0.9; h += dh) 
        fprintf(fp, "%f %f\n", h, gam(&v->model, h));
    fprintf(fp, "]\n");
    fprintf(fp, "%f %f XYPlotPoints\n\n", v->g->ax.min, gam(&v->model, 0.0));
	fprintf(fp, "1.0 setlinewidth\n");
	fprintf(fp, "%%%%End VAR[%d]\n", v->id);
}
