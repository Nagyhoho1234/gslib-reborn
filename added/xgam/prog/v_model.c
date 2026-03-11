#include<string.h>
#include "gslib.h"
#include "xgam.h"
#include "vario.h"
#include "vmodel.h"
#include "lmc.h"
#include <Xm/PushBG.h>
#include <Xm/LabelG.h>
#include <Xm/TextF.h>
#define EPSLON  1.0e-20
#define MAXVAR 3

struct _namestr{
    char name[10];
    char name2[128];
};

int p_mm1=0;

extern Widget canvas[];
extern Widget create_canvas();

XPoint mdots[MAXNVARIOS][100];
int n_mdots;

extern int cdir;
extern int ng;
extern graphics_data *data;
extern var_data var[MAXNVARIOS];
#define XtNmanaged      "Managed"
extern Widget toplevel;
extern Display *display;
extern GC xgc;
extern int cvar;
extern graph_t graph[MAXNVARIOS];
extern int lmc();

Widget *Func[NST],Sill[NST]; 
static Widget Range[NST];
Widget  lmc1[3][NST],lmc2[3][NST],lmc3[3][NST];

/* Widgets for mm1_modeling */
Widget wmm1_type[NST],wmm1_sill[NST],wmm1_range1[NST],
 wmm1_range2[NST],wmm1_range3[NST];
Widget wmm1_angel1[NST],wmm1_angel2[NST],wmm1_angel3[NST],wnugget;
Widget p12[2],var2[2];



FUNC func_info[MAXNMODELTYPES] = {
        "Nugget", nugget,
        "Spherical", spherical,
        "Exponential", exponential,
        "Gaussian", gaussian,
        "Power", power
};

bool range_locked, sill_locked;
extern bool btn_pressed;
void create_lmc3();
void update_text();
extern float cova3();
extern void refresh_canvas();
extern void init_cova3();
void lmc_apply();
void lmc_return();

   
void mm1_apply(w,client_data,call_data)
Widget w; 
XtPointer client_data;
XtPointer call_data;
{
  
  int nst,i,il,is,var_type[NST];
  float r12,mm1_sill[NST],cc,mm1_range1[NST],mm1_range2[NST],mm1_range3[NST];
  float mm1_angel1[NST],mm1_angel2[NST],mm1_angel3[NST];
  float sec_var,anis1[NST],anis2[NST];
  Widget wnst=(Widget)client_data;
  variogram_t vario_t[NST];
  model_t mt;

  float xoff[10],yoff[10],zoff[10],x1,y1,z1,xx,yy,zz,cov,gamout;
  float azm,dip,xlag,h;

  p_mm1=1; 
  nst=atoi(XmTextGetString(wnst));

  mt.nst=nst;

   for(i=0;i<NST;i++) {
     mm1_sill[i]=0.0;
     mm1_range1[i]=0.0;
     mm1_range2[i]=0.0;
     mm1_range3[i]=0.0;
     anis1[i]=0.0;
     anis2[i]=0.0; 
     mm1_angel1[i]=0.0;
     mm1_angel2[i]=0.0;
     mm1_angel3[i]=0.0;

     var_type[i]=0;
  }
  
   cc=atof(XmTextGetString(wnugget));
   mt.nugget=cc;

   for(is=0;is<nst;is++) {
      var_type[is]=xv_GetChoice(wmm1_type[is]);
      mm1_sill[is]=atof(XmTextGetString(wmm1_sill[is]));
      mm1_range1[is]=atof(XmTextGetString(wmm1_range1[is]));
      mm1_range2[is]=atof(XmTextGetString(wmm1_range2[is]));
      mm1_range3[is]=atof(XmTextGetString(wmm1_range3[is]));
      mm1_angel1[is]=atof(XmTextGetString(wmm1_angel1[is]));
      mm1_angel2[is]=atof(XmTextGetString(wmm1_angel2[is]));
      mm1_angel3[is]=atof(XmTextGetString(wmm1_angel3[is]));
      anis1[is]=mm1_range2[is]/mm1_range1[is];
      anis2[is]=mm1_range3[is]/mm1_range1[is];
  }

  for(is=0;is<nst;is++) {
    vario_t[is].type=var_type[is];
    vario_t[is].sill=mm1_sill[is];
    vario_t[is].range=mm1_range1[is];
    vario_t[is].anis.ang1=mm1_angel1[is];
    vario_t[is].anis.ang2=mm1_angel2[is];
    vario_t[is].anis.ang3=mm1_angel2[is];
    vario_t[is].anis.anis1=anis1[is];
    vario_t[is].anis.anis2=anis2[is];
    
  }
  for(is=0;is<nst;is++)
    setrot(&vario_t[is].anis);

  mt.vario=&vario_t[0];

  init_cova3(&mt);
  

  for(i=0;i<nst;i++)
    cc=cc+mm1_sill[i];

   r12=atof(XmTextGetString(p12[1]));
   sec_var=atof(XmTextGetString(var2[1]));

   if(cc!=0)
    r12=r12*sqrtf(sec_var/cc);


  for(i=0;i<ng;i++) {
    var_data *v= &var[i];
    azm=v->dir;
    dip=v->dip;
    xlag=v->lag[1];
    xoff[i]=sin(DEG2RAD*azm)*cos(DEG2RAD*dip)*xlag;
    yoff[i] = cos(DEG2RAD*azm)*cos(DEG2RAD*dip)*xlag;
    zoff[i] = sin(DEG2RAD*dip)*xlag;

  }
   
  for(i=0;i<ng;i++) {   
     var_data *v= &var[i];
     xx=-xoff[i];
     yy=-yoff[i];
     zz=-zoff[i];
     n_mdots=0;

    for(il=0;il<v->nlag;il++) {
         xx=xx+xoff[i];
         yy=yy+yoff[i];
         zz=zz+zoff[i];
         h=sqrtf(xx*xx+yy*yy+zz*zz);
         cov=cova3(mt,xx,yy,zz);
         gamout=r12*(mt.cmax-cov);
         printf("gam=%f\n",gamout);
         mdots[i][n_mdots].x=DEVICEX(v->g, h);
         mdots[i][n_mdots].y=DEVICEY(v->g, gamout);
         n_mdots++;
       if(!il) {
         x1=xx+0.0001*xoff[i];
         y1=yy+0.0001*yoff[i];
         z1=zz+0.0001*zoff[i];
         h=sqrtf(x1*x1+y1*y1+z1*z1);
         cov=cova3(mt,x1,y1,z1);
         gamout=r12*(mt.cmax-cov);
         mdots[i][n_mdots].x=DEVICEX(v->g, h);
         mdots[i][n_mdots].y=DEVICEY(v->g, gamout);
         n_mdots++;
         printf("gam=%f\n",gamout);
      }
    }
    XDrawLines(display, v->g->win, xgc, mdots+i, n_mdots, CoordModeOrigin);
    refresh_canvas(i);

  }   
     
     
 
 
  
}

void mm1_cancel()
{
}

void mm1_return(w,s)
Widget w,s;
{
  XtDestroyWidget(s);
}


void nst_input(w,sname,call_data)
struct _namestr *sname;
caddr_t call_data;
Widget w;
{
  int nst;
  char buf[16];
   Widget wpar,lmc_form,gama1;
   Widget Cmd[2],wnst,wp;
   int i,irow,j,l;
   int ix1,ix2,textwidth;

   static char *labelstr1[]={"Type","Sill","Angle1","Angle2","Angle3"};
   static char *rangelab[]={"Range1","Range2","Range3"};

   nst=atoi(XmTextGetString(w)); 
   if(nst>=NST) {
      xerror(toplevel, "nested structures must be less four\n");
      return;
   }

   XtVaGetValues(w,XmNuserData,&wp,NULL);

   XtDestroyWidget(wp);
 
   wpar=XmCreateDialogShell(toplevel, "MM_modeling", NULL, 0);
   lmc_form = XtVaCreateWidget ("MM1_FORM", xmFormWidgetClass, wpar,
                                 XmNautoUnmanage, False,
                                 XtNmanaged, False,
                                  NULL);
   irow=0;
   textwidth=80;
   gama1=WidgetCreate("Gama11", xmLabelWidgetClass, lmc_form,
          XmNx, xv_col(lmc_form, 20),
          XmNy, xv_row(lmc_form, irow),
         NULL);
    wprintf(gama1, sname->name);

     irow++;
     XtVaCreateManagedWidget ("NST",xmLabelGadgetClass,lmc_form,
                           XmNx, xv_col(lmc_form, 4),
                         XmNy, xv_row(lmc_form, irow),
                          NULL);
     wnst=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNeditable,        False,
            XmNx, xv_col(lmc_form, 10),
            XmNy, xv_row(lmc_form, irow),
          NULL);
    sprintf(buf,"%d",nst);
    XmTextSetString(wnst, buf);
     
     XtVaCreateManagedWidget ("Nugget effect",xmLabelGadgetClass,lmc_form,
                           XmNx, xv_col(lmc_form, 20),
                         XmNy, xv_row(lmc_form, irow),
                          NULL);
     wnugget=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNx, xv_col(lmc_form, 30),
          XmNy, xv_row(lmc_form, irow),
          NULL);



    for (i = 0; i < nst; i++) {
       irow++;
       irow++;
       ix1=3;
       for(l=0;l<XtNumber(labelstr1);l++) {
         XtVaCreateManagedWidget (labelstr1[l],xmLabelGadgetClass,lmc_form,
                            XmNx, xv_col(lmc_form, ix1),
                            XmNy, xv_row(lmc_form, irow),
                           NULL);
          ix1=ix1+9;
      }

       ix2=10;
       irow++;
   wmm1_type[i]=CreatePanelChoice(lmc_form, "",
                              xv_col(lmc_form, 1), xv_row(lmc_form, irow),
                              4,
                             "Sph.", "Exp.", "Gaus.",0,
                                0);

  /* create sill and three angels */

      wmm1_sill[i]= XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNx,xv_col(lmc_form, 10),
            XmNy, xv_row(lmc_form, irow),
            NULL);
      wmm1_angel1[i]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNx,xv_col(lmc_form, 20),
            XmNy, xv_row(lmc_form, irow),
            NULL);

  wmm1_angel2[i]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNx,xv_col(lmc_form, 30),
            XmNy, xv_row(lmc_form, irow),
            NULL);
      wmm1_angel3[i]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNx,xv_col(lmc_form, 40),
            XmNy, xv_row(lmc_form, irow),
            NULL);

      irow++;

/* create three ranges */
     for(j=0;j<XtNumber(rangelab); j++) {
         ix2=ix2+10;

          XtVaCreateManagedWidget (rangelab[j],xmLabelGadgetClass,lmc_form,
                            XmNx, xv_col(lmc_form, ix2),

                           XmNy, xv_row(lmc_form, irow),
                           NULL);
      }
      irow++;

     wmm1_range1[i]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNx,xv_col(lmc_form, 20),
            XmNy, xv_row(lmc_form, irow),
            NULL);
      wmm1_range2[i]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNx,xv_col(lmc_form, 30),
            XmNy, xv_row(lmc_form, irow),
            NULL);
      wmm1_range3[i]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,

           XmNx,xv_col(lmc_form, 40),
            XmNy, xv_row(lmc_form, irow),
            NULL);




   }

   if(strcmp(sname->name2,"LMC")) {

   irow++;
   irow++;
   p12[0]=WidgetCreate("", xmLabelWidgetClass, lmc_form,
                       XmNx, xv_col(lmc_form, 2),
                       XmNy, xv_row(lmc_form, irow),
                          NULL);
   wprintf(p12[0],"Correlation coefficient");
 
   p12[1]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNy, xv_row(lmc_form, irow),


            XmNleftAttachment,  XmATTACH_WIDGET,
            XmNleftWidget,      p12[0],
            NULL);
   irow++;

   var2[0]=WidgetCreate("", xmLabelWidgetClass, lmc_form,
                        XmNx, xv_col(lmc_form, 2),
                        XmNy, xv_row(lmc_form, irow),
                          NULL);
   wprintf(var2[0],sname->name2);
   var2[1]=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth,
            XmNtraversalOn,      True,
            XmNy, xv_row(lmc_form, irow),

           XmNleftAttachment,  XmATTACH_WIDGET,
            XmNleftWidget,      var2[0],
            NULL);
  irow++;

    Cmd[0]=WidgetCreate("Apply", xmPushButtonGadgetClass, lmc_form,
                           XmNy, xv_row(lmc_form, irow),
                           XmNx,150,
                            NULL);
    Cmd[1]=WidgetCreate("Return", xmPushButtonGadgetClass, lmc_form,
                           XmNx,250,
                           XmNy, xv_row(lmc_form, irow),
                            NULL);
    XtAddCallback(Cmd[0], XmNactivateCallback, mm1_apply, wnst);
    XtAddCallback(Cmd[1], XmNactivateCallback, mm1_return, wpar);
   }

    else {
   
    irow++;

    Cmd[0]=WidgetCreate("Apply", xmPushButtonGadgetClass, lmc_form,
                           XmNy, xv_row(lmc_form, irow),
                           XmNx,150,
                            NULL);
    Cmd[1]=WidgetCreate("Return", xmPushButtonGadgetClass, lmc_form,
                           XmNx,250,
                           XmNy, xv_row(lmc_form, irow),
                            NULL);

    XtAddCallback(Cmd[0], XmNactivateCallback, lmc_apply, wnst);
    XtAddCallback(Cmd[1], XmNactivateCallback, lmc_return, wpar);
 
   }

    XtManageChild (lmc_form);
    XtManageChild (wpar);
   
   
}
void mm_modeling(name,name2)
char *name,*name2;
{
   Widget wpar,lmc_form,gama1,wnst;
   int irow;
   int textwidth;
   struct _namestr *sname;
 
   sname=(struct _namestr *)malloc(sizeof(struct _namestr));

   wpar=XmCreateDialogShell(toplevel, "MM_modeling", NULL, 0);
   lmc_form = XtVaCreateWidget ("MM1_FORM", xmFormWidgetClass, wpar,
                                 XmNautoUnmanage, False,
                                 XtNmanaged, False,
                                  NULL);
   irow=0; 
   textwidth=80;
   gama1=WidgetCreate("Gama11", xmLabelWidgetClass, lmc_form,
          XmNx, xv_col(lmc_form, 20),
          XmNy, xv_row(lmc_form, irow),
          NULL);
     strcpy(sname->name,name);
     strcpy(sname->name2,name2);
     wprintf(gama1, name);

     irow++;
     XtVaCreateManagedWidget ("NST",xmLabelGadgetClass,lmc_form,
                           XmNx, xv_col(lmc_form, 4),
                         XmNy, xv_row(lmc_form, irow),
                          NULL);
     wnst=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth, 
            XmNx, xv_col(lmc_form, 10),
          XmNy, xv_row(lmc_form, irow),
          NULL);
    
     XtVaSetValues(wnst,XmNuserData,wpar,NULL);
  
     XtAddCallback (wnst, XmNactivateCallback,
            nst_input,sname);
 
 
     XtVaCreateManagedWidget ("Nugget effect",xmLabelGadgetClass,lmc_form,
                           XmNx, xv_col(lmc_form, 20),
                         XmNy, xv_row(lmc_form, irow),
                          NULL);
     wnugget=XtVaCreateManagedWidget ("",
            xmTextFieldWidgetClass, lmc_form,
            XmNwidth,textwidth, 
            XmNx, xv_col(lmc_form, 30),
          XmNy, xv_row(lmc_form, irow),
          NULL);
    
    XtManageChild (lmc_form);
    XtManageChild (wpar);

     
 
}

void mm1_modeling()
{
   char string1[]="Gamma11";
   char string2[]="Variance of secondary variable";

   mm_modeling(string1,string2);
}

void mm2_modeling()
{
   char string1[]="Gamma22";
   char string2[]="Variance of primary variable";

  mm_modeling(string1,string2);
}

void range_input(lmc_range)
float lmc_range[3][NST];
{

    int l,is;
    
    for(l=0;l<3;l++)  
      for (is=1; is<NST; is++)
        lmc_range[l][is]=atof(XmTextGetString(lmc3[l][is]));
      
    
  
}

void sill_input(lmc_sill)
float lmc_sill[3][NST];
{

   int l,is;

   for(l=0;l<3;l++)
     for (is=0;is<NST; is++)
        lmc_sill[l][is]=atof(XmTextGetString(lmc2[l][is]));
    
  
}

void type_input(itype)
int itype[3][NST];
{
        int is,l,i;
        modelType type[NST];
        

        /* The type of which structure is changed? */

        /* the new type */
        for(l=0;l<3;l++)
          for (is=0;is<NST; is++)
           itype[l][is]=xv_GetChoice(lmc1[l][is]);
          
        
}

int search_int(a,array,f,ar_range,n)
int a,array[NST],n; 
float ar_range[NST],f;
{ 
  int i;

  for(i=0;i<n;i++) { 
   if(a==array[i] && ABS(f-ar_range[i])<EPSLON) return i;
  }
  return -1;
}

   
void lmc_apply()
{
  printf("apply\n");
}

void lmc_return(w,s)
Widget w,s;
{ 
  printf("return\n");
  XtDestroyWidget(s); 
}


void
read_nvr(widget, client_data, call_data)
Widget widget;
XtPointer client_data;
XtPointer call_data;
{
   char *buf;

   int nvr;

    XmSelectionBoxCallbackStruct *cbs =
        (XmSelectionBoxCallbackStruct *) call_data;

    if (!XmStringGetLtoR (cbs->value, XmFONTLIST_DEFAULT_TAG, &buf))
       return;
   
    /* check for LMC */ 
    nvr=lmc(buf);
    switch(nvr) {
      case VARERROR:
         RETURN("Warning:Too many variables.\n");
         break;
      case FILEERROR:
         RETURN("Warning:File does not exist\n");
         break;
     case FILEFORMAT:
         RETURN("Warning:File format error\n");
         break;
     case VARIOERROR:
         RETURN("Warning:Need variogram between variables\n");
         break;
     case NUGGETERROR:
         RETURN("Warning:Positive definiteness violation on nugget effects\n");
         break;
     case STRUCTERROR:
        RETURN("Warning:Positive definiteness violation on structure\n");
        break;
     case POSERROR:
        RETURN("Warning:This is not permessible LMC\n");
        break;
     case PRIOR:
        RETURN("This is priori permessible LMC\n");
        break;

   }

    
/*
    if (nvr<=0) RETURN("No number of variables specified.\n");
    if (nvr>MAXVAR) RETURN("Too many variables.\n");
*/
    /* Name's fine -- go ahead and enter it */
    XtDestroyWidget(widget);
}



void lmc_checking()
{
  
  Widget ddialog;
    XmString t = XmStringCreateLocalized ("Enter variogram file:");
    Arg args[5];
    char buf[20];
    int n = 0;
    int i;

    /* Create the dialog -- the PushButton acts as the DialogShell's
     * parent (not the parent of the PromptDialog).
     */
    XtSetArg (args[n], XmNselectionLabelString, t); n++;
    XtSetArg (args[n], XmNautoUnmanage, False); n++;
    ddialog = XmCreatePromptDialog (toplevel, "Variogram", args, n);
    XmStringFree (t); /* always destroy compound strings when done */

    /* When the user types the name, call read_name() ... */
    XtAddCallback (ddialog, XmNokCallback, read_nvr, NULL);

    /* If the user selects cancel, just destroy the dialog */
    XtAddCallback (ddialog, XmNcancelCallback, XtDestroyWidget, NULL);
    /* No help is available... */
    XtUnmanageChild (XmSelectionBoxGetChild (ddialog, XmDIALOG_HELP_BUTTON));
    XtManageChild (ddialog);

    XtPopup (XtParent (ddialog), XtGrabNone);
    
}

init_model(m)
model_data *m;
{
        int i;
        m->type[0]=VM_NUGGET;
        m->irow=1;
        for (i=1; i<NST; i++) {
                m->type[i]=VM_SPHERICAL;
                m->sill[i] = 0.;
                m->range[i] = 0.;
        }
}


mouse_fit(w, data, gc)
Widget w;
graphics_data *data;
GC gc;
{
    float old_sill, new_sill;
    int i, cs;
    model_data *m = &var[cvar].model;
    cs=m->irow;      /* the current structure */

    old_sill=m->sill[cs];
    if (!sill_locked) {
        new_sill=USERY(m->g, data->last_y);
        for (i=0; i<cs; i++) new_sill -= m->sill[i];
        m->sill[cs]= new_sill;
     } 
     else 
       new_sill = old_sill;

     if (!range_locked)
          m->range[cs] = USERX(m->g, data->last_x);

    update_text(m,cs);

    if (cs != NST-1){
        /* if cstruct is the last structure, "cstruct+1" will not be updated*/
        if (m->sill[cs+1]>= 1e-4){
            if ((m->sill[cs+1]+= old_sill - new_sill)<0.)
                m->sill[cs+1]= 0.;
            update_text(m,cs+1);
        }
    }
    draw_model(m, gc); /* defined in v_win.c */
}

extern void var_output();
create_model_option(w, upper)
Widget w, upper;
{
        int i;
        Widget RC, Title, Option[5];
        static _Option model_option[] = {
                "LMC checking", lmc_checking,
                "MM1 modeling", mm1_modeling,
                "MM2 modeling",mm2_modeling,
                "Output", var_output
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
        for (i=0; i<XtNumber(model_option); i++) {
                Option[i]=XmCreatePushButtonGadget(RC,
                        model_option[i].name, wargs, nargs);
                XtAddCallback(Option[i], XmNactivateCallback, model_option[i].cb
, data);
        }
        XtManageChildren(Option, XtNumber(model_option));
        XtManageChild(RC);
}

void update_text(m, is)
model_data *m;
int is;
{
    char  buf[256];
    int zero_sill= FALSE;


    /* caution: the format! */
    sprintf(buf, "%f", m->sill[is]);
    XmTextSetString(Sill[is], buf);

    if (is!=0 ) {
        if (zero_sill) sprintf(buf, "\t\t\t");
        else sprintf(buf, "%f", m->range[is]);
        XmTextSetString(Range[is], buf);
    }
}


void change_type(w)
Widget w;
{
        int i;
        highlight_struc(var[cvar].model.irow, OFF);

        /* The type of which structure is changed? */
        for (i=0; i<NST && Func[i][1] != XtParent(w); i++);
        var[cvar].model.irow = i;

        /* the new type */
        var[cvar].model.type[i]=xv_GetChoice(Func[i]);
        fprintf(stderr, "struct: %d, type: %d\n", i, var[cvar].model.type[i]);

        refresh_active_canvases();
        highlight_struc(var[cvar].model.irow, ON);
}


void user_fit(w)
Widget w;
{
    int is, iv;
    char buf[20];
    var_data *v;
    model_data *m = &var[cvar].model;

    /* nugget */
    m->sill[0]=atof(XmTextGetString(Sill[0]));
    update_text(m,0);

    for (is=1; is<NST; is++)
    {
        m->sill[is]=atof(XmTextGetString(Sill[is]));
        m->range[is]=atof(XmTextGetString(Range[is]));
        update_text(m,is);
    }
        refresh_active_canvases();
}

void lock_par(w, par)
Widget w;
bool *par;
{
        *par = !(*par);
}


void Single_Modeling_Panel(parent)
Widget parent;
{
	Widget Title, Labels,Table, Label[3],rowcol;
        Widget form;
	int i, j, irow=0;
	Widget ParPanel = parent;




	Title=WidgetCreate("title", xmLabelWidgetClass, ParPanel,
		XmNy, xv_row(ParPanel, irow),
		XmNleftAttachment, XmATTACH_FORM,
		XmNrightAttachment, XmATTACH_FORM,
		NULL);
	wprintf(Title, "Nested Structures");


	irow++;
	Label[0]=WidgetCreate("Type", xmToggleButtonWidgetClass, ParPanel,
			  XmNx, xv_col(ParPanel, 0),
			  XmNy, xv_row(ParPanel, irow),
			  NULL);
	Label[1]=WidgetCreate("Sill", xmToggleButtonWidgetClass, ParPanel,
			  XmNx, xv_col(ParPanel, 8),
			  XmNy, xv_row(ParPanel, irow),
			  NULL);
        Label[2]=WidgetCreate("Range", xmToggleButtonWidgetClass, ParPanel,
			  XmNy, xv_row(ParPanel, irow),
		          XmNrightAttachment, XmATTACH_FORM,
			  NULL);
         XtManageChildren(Label, 3);
        XtAddCallback(Label[1], XmNvalueChangedCallback, lock_par, &sill_locked);
        XtAddCallback(Label[2], XmNvalueChangedCallback, lock_par, &range_locked);
       
      irow++;
      rowcol = XtVaCreateWidget ("rowcol",
        xmRowColumnWidgetClass, ParPanel, 
        XmNleftAttachment,   XmATTACH_FORM,
        XmNrightAttachment,  XmATTACH_FORM,
        XmNy, xv_row(ParPanel, irow),
        NULL);

   
       for (i = 0; i < NST; i++) {
        form = XtVaCreateWidget ("form", xmFormWidgetClass, rowcol,
            XmNfractionBase,  9,
            NULL);

      Func[i] = CreatePanelChoice(form, "",
                              xv_col(ParPanel, -1), 0,
                               (i==VM_NUGGET) ? 2 : 6,
                  "Nugget", "Sph.", "Exp.", "Gaus.", "Power",
                                  NULL,
                            0);
      Sill[i]= XtVaCreateManagedWidget ("text_w",
            xmTextFieldWidgetClass, form,
            XmNtraversalOn,      True,
            XmNrightAttachment,  XmATTACH_POSITION,
            XmNleftAttachment,   XmATTACH_POSITION,
            XmNleftPosition,    3,
            XmNrightPosition,    6,
            NULL);

      Range[i]=XtVaCreateManagedWidget ("text_w1",
            xmTextFieldWidgetClass, form,
            XmNtraversalOn,      True,
            XmNrightAttachment,  XmATTACH_FORM,
            XmNleftAttachment,   XmATTACH_POSITION,
            XmNleftPosition,    6,
            NULL);
            irow++;

      if (i!=VM_NUGGET) 
          XtAddCallback(Range[i], XmNactivateCallback, user_fit, NULL);
      else 
         XtUnmanageChild(Range[i]);
      XtAddCallback(Sill[i], XmNactivateCallback, user_fit, NULL);
      for (j=0; j<((i==VM_NUGGET)?1:MAXNMODELTYPES); j++)
         XtAddCallback(Func[i][j+2], XmNactivateCallback, change_type, NULL);

     XtManageChild( form);

   }

   XtManageChild (rowcol);
   create_model_option(ParPanel, rowcol);
             
}

assign_vars_to_graphs(whichDir)
int whichDir;
{
        int i;
        int ndir=1;

        for (i=0; i<ng*ndir; i++) {
                if (var[i].idir!=whichDir) continue;
                var[i].g = &graph[var[i].id];
                var[i].model.g = &graph[var[i].id];

                strcpy(var[i].g->title, var[i].title);
                init_viewport(var[i].g, var[i].lag, var[i].var, var[i].nlag);
                var_to_device(&var[i]);
                if (var[i].g->active) highlight(canvas[i], TRUE);
        }
}

int VarioModel_create(parent)
Widget parent;
{
	int i, j=0;

        int ndir=1;

	if (ng<=0) {
		xerror(toplevel, "No variograms to model\n");
		return FALSE;
	}

	if (var[0].model.sill[1]==0.) /* otherwise, use history */
	for (i=0; i<ng*ndir; i++) init_model(&var[i].model);

	/* create ng graphs */
	create_canvas(ng, data);

	/* only load the variograms of current direction */
	assign_vars_to_graphs(cdir);


	/* create interfaces */
	Single_Modeling_Panel(parent);

	return TRUE;
}

highlight_struc(i, onoff)
int i, onoff;
{
        nargs=0;
        setarg(XmNforeground, GetColor(((onoff)?"red":"black")));
        XtSetValues(Func[i][0], wargs, nargs);
}

void setModelParPanel(m)
model_data *m;
{
        int i;
        for (i=0; i<NST; i++) {
                xv_SetChoice(Func[i], m->type[i]);
                update_text(m, i);

                if (i==m->irow)
                highlight_struc(i, ON);
                else
                highlight_struc(i, OFF);
        }
}

float gam(m, h)
model_data *m;
float h;
{
int i;
float g=0., tmp, (*ff)();

    for (i=0; i<NST; i++)
        g  += func_info[m->type[i]].func(m->sill[i], m->range[i], h);
    return g;
}

float nugget(c0,a,h)
float c0, a, h;
{
    return c0;
}

float spherical(c0, a, h)
float c0, a, h;
{
    float r;
        if (a<=0.) return 0.;
        r=(h/a);
    if (h>=a) return c0;
    return c0*r*(1.5-0.5*r*r);
}

float exponential(c0, a, h)
float c0, a, h;
{
        if (a<=0.) return 0.;
    return c0*(1-exp(-3*h/a));
}
float gaussian(c0, a, h)
float c0, a, h;
{
    float r;
        if (a<=0) return 0.;
        r=h/a;
    return c0*(1-exp(-3*r*r));
}

float power(c0, a, h)
float c0, a, h;
{
        /*
    return c0*h/a;
        */
        return c0*pow(h,a);
}


