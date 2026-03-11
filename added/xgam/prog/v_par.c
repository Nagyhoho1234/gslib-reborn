#include <Xm/ToggleBG.h>
#include "xgam.h"
#include "vario.h"

#define MAXNCUTOFFS 10
extern int str_to_floats();
varioType vtype=Traditional_semivariogram;
static Widget Par[10];
extern Display *display;
int ng;
int STAND=0;

extern state_t states[NumStates];
var_data var[MAXNVARIOS];
extern graph_t graph[MAXNVARIOS];
extern graphics_data *data;
extern Widget toplevel;
extern void cal_gam();
extern void cal_gamv();
extern void init_viewport();
extern void var_to_device();
extern void  refresh_canvas(); 
extern void show_pair();
extern void var_output();

static Widget *VarioTypes;
static char *par_names1[] = {
    "Azimuth    ",
    "Azi.Tolerance    ",
    "Azi.Bandwidth    ",
        "Dip    ",
        "Dip Tolerance    ",
        "Dip Bandwidth    ",
    "Lags    ",
    "Lag Tolerance    "
};

static char *par_names2[] = {
       "Dir1 offsets    ",
       "Dir2 offsets    ",
       "Dir3 offsets    ",
       "Dir4 offsets    ",
        "nlag  "
};

static struct {
    char   *name, *format;
    float   deft, min, max;
}   vpar[NPARS] = {
    "Azimuth:",        "%.2f",   0.00, 0.00, 180.00,
    "  Tolerance",     "%5.1f", 22.5, 0, 90,
    "  Bandwidth",     "%.2f",  50, 0, 100,
        "Dip:",            "%.2f",  0, 0, 90,
        "  Tolerance",     "%.2f",  22.5, 0, 90,
        "  Bandwidth",     "%.2f",  50, 0, 100,
    "Lags:",           "%.2f",  5, 0, 0,
    "  Tolerance",     "%.2f",  2.5, 0, 0
};

static char *var_type[] = {
    "Traditional Semivariogram",
        "Traditional Cross Semivariogram",
        "Covariance",
        "Correlogram",
        "General Relative Semivariogram",
        "Pairwise Relative Semivariogram",
        "Semivariogram of Logarithms",
        "Semimadogram"
};

void print_var_par();



void read_cutoff();

void sel_vartype(w)
Widget w;
{
        vtype = xv_GetChoice(VarioTypes);
        fprintf(stderr, "Variogram Type: %d (%s)\n", vtype, var_type[vtype]);
}





int str_to_floats(s, ary, max_n)
char *s;
float *ary;
int max_n;
{
        char *t=s;
        int n=0,m,i;
        while (1) {
                while (*t!='\0' && *t == ' ' || *t == ',') t++;
                if (1!=sscanf(t, "%f", &ary[n])) break;
                if (++n == max_n) break;
                while (*t!='\0' && *t != ' ' && *t != '*') t++;
                if (*t == '*') {
                        t++;
                        if (1!=sscanf(t, "%d", &m)) break;
                        for (; m>1 && n<max_n; m--,n++) ary[n] = ary[n-1];
                        while (*t!='\0' && *t != ' ') t++;
                }
        }
        return n;
}


create_var_option(w, upper )
Widget w, upper;
{ 
        Widget Option[7];

        int i;
        Widget Title, RC;
        static _Option var_option[] = {
                "Show #Pairs", show_pair,
                "Output",var_output
        };
        nargs=0;
        setarg(XmNtopAttachment, XmATTACH_WIDGET);
        setarg(XmNtopWidget, upper);
        setarg(XmNleftAttachment, XmATTACH_FORM);
        setarg(XmNrightAttachment, XmATTACH_FORM);
        Title=XmCreateLabel(w, "title", wargs, nargs);
        XtManageChild(Title);
        wprintf(Title, "Options");
        nargs=0;
        setarg(XmNtopAttachment, XmATTACH_WIDGET);
        setarg(XmNtopWidget, Title);
        RC=XmCreateRowColumn(w, "options", wargs, nargs);
        nargs=0;

        for (i=0; i<XtNumber(var_option); i++) {
                Option[i]=XmCreatePushButtonGadget(RC,
                        var_option[i].name, wargs, nargs);
          XtAddCallback(Option[i], XmNactivateCallback, var_option[i].cb,data);
        } 

        XtManageChildren(Option, XtNumber(var_option));
        XtManageChild(RC);
}

void start_exgam()
{
  FILE *fp;
  int ixd,iyd,izd,nlag;
  int ixxd[5],iyyd[5],izzd[5];
  int np,i,ndir=0;
  int icol=2;

  fp=fopen("xgam.par","w");
  fprintf(fp,"%s\n",data->filename);
  if(data->icol[PRIMARY]==data->icol[SECONDARY]){
    icol=1;
    fprintf(fp,"%d %d %d\n",1,data->icol[PRIMARY],data->icol[SECONDARY]);
  }
  else
    fprintf(fp,"%d %d %d\n",2,data->icol[PRIMARY],data->icol[SECONDARY]);
   
  fprintf(fp,"%f %f\n",data->trim_min,data->trim_max);
  fprintf(fp,"%d %f\n",data->nx,data->dx);
  fprintf(fp,"%d %f\n",data->ny,data->dy); 
  fprintf(fp,"%d %f\n",data->nz,data->dz);

  for(i=0;i<4;i++) {
  np=sscanf(XmTextGetString(Par[i]), "%d%d%d",
                &ixd,&iyd,&izd);  /* offsets */
    if(np>0) {
      ixxd[ndir]=ixd;
      iyyd[ndir]=iyd;
      izzd[ndir]=izd;
      ndir++;
    }
 }

  np=sscanf(XmTextGetString(Par[4]),"%d",&nlag); /* number of lags */
  if(np<=0) 
    RETURN("Number of lags not defined\n");
  if(ndir==0)
    RETURN("At least one direction\n");
  fprintf(fp,"%d %d\n",ndir,nlag);
  for(i=0;i<ndir;i++) 
    fprintf(fp,"%d %d %d\n",ixxd[i],iyyd[i],izzd[i]);
  fprintf(fp,"%d\n",STAND); /* standardize sill */
  switch(vtype){
   case Traditional_semivariogram:
     fprintf(fp,"%d %d %d\n",1,icol,1);
     break;
   case Traditional_cross_semivariogram:
     fprintf(fp,"%d %d %d\n",1,icol,2);
     break;
   case Covariance:
      fprintf(fp,"%d %d %d\n",1,icol,3);
      break;
  case Correlogram:
      fprintf(fp,"%d %d %d\n",1,icol,4);
      break;
  case General_relative_semivariogram:
      fprintf(fp,"%d %d %d\n",1,icol,5);
      break;
  case Pairwise_relative_semivariogram: 
      fprintf(fp,"%d %d %d\n",1,icol,6);
      break;
  case Semivariogram_of_logarithms:
      fprintf(fp,"%d %d %d\n",1,icol,7);
      break;
  case Semimadogram:
      fprintf(fp,"%d %d %d\n",1,icol,8); 
      break;
  }
  fclose(fp); 

  system("./gam");
  
  read_data("xgam.out");

  switch_state(VarioModel);


}


void get_gam_par(par_status)
int *par_status;
{
        int i, iv;
        float dir[MAXNVARIOS], dirtol, dirband, lag[MAXNLAGS], lagtol ;
        float dip,diptol,dipband;
        int nlag;

        *par_status = 0;

        /* extract parameters */

        ng=str_to_floats(XmTextGetString(Par[DIRECTION]), dir, MAXNVARIOS);

        if (ng<=0) RETURN("No direction specified.\n");
        if (ng>MAXNVARIOS) RETURN("Too many directions.\n");

        dirtol=atof(XmTextGetString(Par[DIRTOL]));
        lag[0] = 0.0;
        nlag=str_to_floats(XmTextGetString(Par[LAG]), lag+1, MAXNLAGS-1)+1;

        for (i=1; i<nlag; i++) lag[i] += lag[i-1];
        if (nlag<=1 || nlag>=MAXNLAGS)
                RETURN("Illegal lag definition.\n");

        lagtol=atof(XmTextGetString(Par[LAGTOL]));
        dirband=atof(XmTextGetString(Par[DIRBAND]));
        if(data->threed) {
          dip=atof(XmTextGetString(Par[DIP]));
          diptol=atof(XmTextGetString(Par[DIPTOL]));
          dipband=atof(XmTextGetString(Par[DIPBAND]));
        }
 
       /* Except for directions, other parameters are forced to be the same. */
        /* May need to changed in the furture */
 
       for (iv=0; iv<ng; iv++) {
            int j;
            var_data *v= &var[iv];
            for (j=0; j<nlag; j++) v->lag[j] = lag[j];
            v->dir = dir[iv];
            v->nlag=nlag;
            v->dirtol=dirtol;
            v->lagtol=lagtol;
            v->dirband=dirband;
            if(data->threed) {
              v->dip=dip;
              v->diptol=diptol;
              v->dipband=dipband;
            }
            print_var_par(v);
        }

        *par_status = 1;
}

void print_var_par(v)
var_data *v;
{
      fprintf(stderr,"Dir: %f %f %f\nDip: %f %f %f\nLag: %d %f\n",
             v->dir, v->dirtol, v->dirband,
             v->dip, v->diptol, v->dipband,
             v->nlag, v->lagtol);
}

void install_variogram(iv)
int iv;
{
        var_data *v = &var[iv];
        v->id = iv;
        if (iv>=ng || iv<0) RETURN(("Invalid window\n"));
        if (data->threed)
        sprintf(v->title, "#%d: %s: Azimuth=%.1f, Dip=%.1f",
                        iv+1, var_type[vtype], v->dir, v->dip);
        else
        sprintf(v->title, "#%d: %s: Azimuth=%.1f", iv+1, var_type[vtype], v->dir);
      
        v->g = &graph[iv];
        v->model.g = &graph[iv];
        strcpy(v->g->title, v->title);
        init_viewport(v->g, v->lag, v->var, v->nlag);
        var_to_device(v);
       
         
        refresh_canvas(iv);
}


void variok(w)
Widget w;
{
     int iv,par_status;
     unsigned i;

     if (data->exhaustive) {
          start_exgam(); 
          return;
      }
      else
        get_gam_par(&par_status);

      if (!par_status) return;

      busyCursor(); 

      create_canvas(ng, data);

      for (iv=0; iv<ng; iv++) {
          XFlush(display);
             cal_gamv(&var[iv]);
          install_variogram(iv);
       }

       unbusyCursor();
}
 
 

void
toggled1(widget, client_data, call_data)
Widget widget;
XtPointer client_data;
XtPointer call_data;
{
       XmToggleButtonCallbackStruct *state =
        (XmToggleButtonCallbackStruct *) call_data;
    if(state->set)
        STAND=1;
} 

void
toggled2(widget, client_data, call_data)
Widget widget;
XtPointer client_data;
XtPointer call_data;
{
    XmToggleButtonCallbackStruct *state =
        (XmToggleButtonCallbackStruct *) call_data;
    if(state->set) 
      STAND=0; 
     

} 


int VarioCal_create(parent)
Widget parent;
{
   int i=0; 
   int irow=0;
   Widget Title;
   Widget ParPanel=parent;
   Widget Label1;
   XmString titlelabel=XmStringCreateLocalized("Standard");
   XmString titlelabel1=XmStringCreateLocalized("  ");
   char buf[256];
   Widget Ok,yes,no,rc;

   fprintf(stderr, "calc: %d\n", data->nd);
   if( !data->exhaustive){
     if (data->nd <=0) {
         xerror(toplevel, "You must load data first\n");
         return FALSE;
     }
   }
    nargs=0;
    Title=WidgetCreate("title", xmLabelWidgetClass, ParPanel,
             XmNleftAttachment, XmATTACH_FORM,
             XmNrightAttachment, XmATTACH_FORM,
             XmNy, xv_row(ParPanel, irow++),
             NULL);
    wprintf(Title, "Parameters");

    if(data->exhaustive){
     for(i=0;i<XtNumber(par_names2);i++)
       Par[i] = (Widget) CreateTextItem(ParPanel,
                    xv_col(ParPanel, 9), xv_row(ParPanel, irow++),
                    15, par_names2[i]);
    }
    else {
     for (i=0; i<XtNumber(par_names1); i++) {
       if (!data->threed && (i==DIP || i==DIPTOL || i==DIPBAND)) 
         continue;
       Par[i] = (Widget) CreateTextItem(ParPanel,
                    xv_col(ParPanel, 9), xv_row(ParPanel, irow++),
                    15, par_names1[i]);
        }
   }

 
   rc = XtVaCreateWidget ("rc", xmRowColumnWidgetClass, ParPanel,
        XmNnumColumns,      3,
        XmNleftAttachment,  XmATTACH_FORM,
        XmNradioBehavior,   True,
        XmNy, xv_row(ParPanel, irow++),
        NULL);

   Label1=XtVaCreateManagedWidget("Stand",
          xmLabelWidgetClass, rc ,
          XmNlabelString, titlelabel,
          XmNx, xv_col(rc, 0),
          NULL);
 

   yes = XtVaCreateManagedWidget ("Yes",
        xmToggleButtonWidgetClass, rc , 
          NULL);
    XtAddCallback (yes, XmNvalueChangedCallback, toggled1, 1);

   no = XtVaCreateManagedWidget ("No",
        xmToggleButtonWidgetClass, rc, 
         NULL);
    XtAddCallback (no, XmNvalueChangedCallback, toggled2, 2);

   XtManageChild(rc);
  

    VarioTypes = CreatePanelChoice(ParPanel, "Variogram Type:",
                      xv_col(ParPanel, 9), xv_row(ParPanel, irow++),
                      9,
                        "Traditional Semivariogram",
                        "Traditional Cross Semivariogram",
                        "Covariance",
                        "Correlogram",
                        "General Relative Semivariogram",
                        "Pairwise Relative Semivariogram",
                        "Semivariogram of Logarithms",
                        "Semimadogram",
                        0,
                        0);

        for (i=0; i<8; i++)
        XtAddCallback(VarioTypes[2+i],XmNactivateCallback, sel_vartype, NULL);

        Ok = WidgetCreate("Calculate", xmPushButtonWidgetClass, ParPanel,
                XmNleftAttachment, XmATTACH_FORM,
                XmNrightAttachment, XmATTACH_FORM,
                XmNy, xv_row(ParPanel, irow),
                NULL);

        XtAddCallback(Ok, XmNactivateCallback, variok, NULL);

        create_var_option(ParPanel, Ok); 

        if (!data->exhaustive)
        init_vpar();

        return TRUE;
}

#define DEF_NLAGS 10
init_vpar()
{
        int i, j;
        char buf[256];

        vpar[LAG].deft = data->max_lag/(float)DEF_NLAGS;
        vpar[LAG].max = data->max_lag;
        vpar[LAGTOL].deft = vpar[LAG].deft/2.;
        vpar[LAGTOL].max = vpar[LAG].deft;
        vpar[DIRBAND].deft = data->max_lag/2.;

        for (i=0; i<MAXNVARIOS; i++) {
        var[i].dir = 0.00;
        var[i].dirtol = 22.5;
        var[i].dirband = data->max_lag;
        var[i].dip = 0.00;
        var[i].diptol = 22.5;
        var[i].dipband = data->max_lag;
        var[i].nlag = DEF_NLAGS;
        var[i].lag[0] = 0.0;

        for (j=1; j<var[i].nlag; j++)
        var[i].lag[j] = var[i].lag[j-1] + data->max_lag/(float)var[i].nlag;
        }


        for (i=0; i<NPARS; i++) {
         if (!data->threed && (i==DIP || i==DIPTOL || i==DIPBAND)) continue;
                if (i==LAG) {
                        char fmt[256];
                        sprintf(fmt, "%s*%%d", vpar[i].format);
                        sprintf(buf, fmt, vpar[LAG].deft, DEF_NLAGS);
                }
                else sprintf(buf, vpar[i].format, vpar[i].deft);
                XmTextSetString(Par[i], buf);
        }
}

