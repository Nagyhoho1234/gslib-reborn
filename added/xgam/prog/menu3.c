#include "xgam.h"
#include "gslib.h"
#include <Xm/TextF.h>
#include <Xm/LabelG.h>

#define X 0
#define Y 1
#define Z 2
#define PRIMARY 3
#define SECONDARY 4

#define NXYZ 5
#define DXYZ 6
#define TRIM 7
#define TRIM_MAX 1.0e10

static Widget Par[10];
static Widget ParValue[3];
extern Widget toplevel;
extern istate;

static char *par_name[] = {
	"X Variable",
	"Y Variable",
	"Z Variable",
	"Head Variable",
	"Tail Variable",
	"NX NY NZ",
	"DX DY DZ",
	"Trimming Values"
};

static char *file_type[] = {
	"Scattered Data",
        "Gridded Data"
};

graphics_data *data;

void set_file_type();
void select_var1();
void select_var2();
void select_var3();
void select_var4();
void select_var5();

void dataok();
int update_par_panel();

int SelectVar_create(parent)
Widget parent;
{ 
        XmString titlelabel;
        int i,ij=0;

	Widget Title, Label[5], Type, RC1, RC2, Table, Ok,filename;
	Widget ParPanel = parent;
        void (*fun[5])();

        fun[0]=select_var1;
        fun[1]=select_var2;
        fun[2]=select_var3;
        fun[3]=select_var4;
        fun[4]=select_var5;

         if (data->varname[0] == NULL) {
                xerror(toplevel, "Select a data file first\n");
                return FALSE;
        }

        strcpy(data->varname[0], "N / A");

        nargs=0;
	setarg(XmNtopAttachment, XmATTACH_FORM);
	setarg(XmNleftAttachment, XmATTACH_FORM);
	setarg(XmNrightAttachment, XmATTACH_FORM);
        titlelabel=XmStringCreateLocalized("Parameters");
        setarg(XmNlabelString, titlelabel);

	Title=XmCreateLabel(ParPanel, "title", wargs, nargs);
	XtManageChild(Title);
        XmStringFree(titlelabel);

        
 
        Type=create_option_menu(ParPanel,
		"File Type:   ", file_type, XtNumber(file_type),
		ij, set_file_type, &ij);
	nargs=0;
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, Title);
	
        XtSetValues(Type, wargs, nargs);
	nargs=0;
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, Type);
	setarg(XmNrightAttachment, XmATTACH_FORM);
	setarg(XmNleftAttachment, XmATTACH_FORM);
	RC1=XmCreateRowColumn(ParPanel, "variables",wargs, nargs); 
	XtManageChild(RC1); 
        
        for(i=0;i<=data->nv;i++)

        for (i=0; i<5; i++) {
		Par[i]=create_option_menu(RC1, par_name[i], &data->varname, 
				data->nv+1, data->icol[i], fun[i], &data->icol[i]);
	}

	RC2=create_table(ParPanel, 
		Par+5, par_name+5, XtNumber(par_name)-5, 
		Label, xmLabelWidgetClass,
		ParValue, xmTextWidgetClass);
	nargs=0;
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, RC1);
	XtSetValues(RC2, wargs, nargs);
	update_par_panel(ij);  

	nargs=0;
	setarg(XmNleftAttachment, XmATTACH_FORM);
	setarg(XmNrightAttachment, XmATTACH_FORM);
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, RC2);
	Ok=XmCreatePushButton(ParPanel, "O K", wargs, nargs);
	
        XtAddCallback(Ok, XmNactivateCallback, dataok, data); 

	XtManageChild(Ok);
        
     filename=XtVaCreateManagedWidget ("Filename:",
            xmLabelGadgetClass, ParPanel,
            XmNtopAttachment, XmATTACH_WIDGET,
            XmNleftAttachment,   XmATTACH_FORM,
            XmNtopWidget,Ok,
            NULL);

        XtVaCreateManagedWidget (data->filename,
            xmLabelGadgetClass, ParPanel,
            XmNtopAttachment, XmATTACH_WIDGET,
            XmNleftAttachment,   XmATTACH_FORM,
            XmNtopWidget,filename,
            NULL);

	return TRUE;
}

void minmax1d(dat, n, min, max)
float *dat, *min, *max;
int n;
{
        int i;
        float tmp, low=(TRIM_MAX), high=(-TRIM_MAX);

        for (i=0; i<n; i++)
        {
                if (dat[i]==MISSING) continue;
                if ((tmp=dat[i])< low) low=tmp;
                if (tmp>high) high=tmp;
        }
        *min=low;
        *max=high;
}



void parse_data()
{
   int i;
 
   if (data->icol[X]==0 && data->icol[Y]==0 && data->icol[Z]==0)
       data->exhaustive=TRUE;
   if (data->icol[Z]!=0) data->threed=TRUE;
   if (!data->exhaustive) {
      minmax1d(data->rdat[X], data->nd, &data->min[X], &data->max[X]);
      minmax1d(data->rdat[Y], data->nd, &data->min[Y], &data->max[Y]);
      if(data->threed)
          minmax1d(data->rdat[Z], data->nd, &data->min[Z], &data->max[Z]);
      data->max_lag=0.;
      for (i=X; i<=Z; i++)
      {
            float diff;
            if (data->icol[i]==0) continue;
            diff = data->max[i]-data->min[i];


             data->max_lag += diff*diff;
        }

        data->max_lag=sqrtf(data->max_lag);
        data->max_lag *= 0.5;
      }
}

void cal_variance()
{

   float sum1,ssq1;
   int j;

  
   int ihead=data->icol[PRIMARY]-1;
   int itail=data->icol[SECONDARY]-1;
    
   sum1=0;
   ssq1=0;

     for(j=0;j<data->nd;j++) {
       sum1=sum1+data->rdat[ihead][j];
       ssq1=ssq1+data->rdat[ihead][j]*data->rdat[ihead][j]; 
     }
     
    data->variance=(ssq1/data->nd)-(sum1*sum1)/(data->nd*data->nd);
}
void dataok(w,call_data)
Widget w;
caddr_t call_data;
{
   
   int np;

   
   np=sscanf(XmTextGetString(ParValue[TRIM-5]), "%f%f",
                &data->trim_min, &data->trim_max);
   if (np<2) data->trim_max=TRIM_MAX;
   if (np<1) data->trim_min=(-TRIM_MAX);
   
   busyCursor();
   if(data->exhaustive) {
     np=sscanf(XmTextGetString(ParValue[NXYZ-5]), "%d%d%d", 
                &data->nx, &data->ny, &data->nz);
     if (np<=2) data->nz=1;
     if (np<=1) {
       data->nz=1;
       data->ny=1;
     }
     if (np<=0) RETURN("grid size not defined");
     if (data->nx<=0 || data->ny<=0 || data->nz<=0)
                RETURN("illegal grid size\n");
     np=sscanf(XmTextGetString(ParValue[DXYZ-5]),
                        "%f%f%f", &data->dx, &data->dy, &data->dz);
   }
   else {
    parse_data();

    cal_variance();

   }
   unbusyCursor();
   switch_state(VarioCal); 
}
   

void select_var1(w, i)
Widget w;
int *i;
{
        *i = GetChoice(w);
        data->icol[X]=*i;
}

void select_var2(w, i)
Widget w;
int *i;
{
        *i = GetChoice(w);
        data->icol[Y]=*i;
} 


void select_var3(w, i)
Widget w;
int *i;
{
        *i = GetChoice(w);
        data->icol[Z]=*i;
}

void select_var4(w, i)
Widget w;
int *i;
{
        *i = GetChoice(w);
        data->icol[PRIMARY]=*i;
}

void select_var5(w, i)
Widget w;
int *i;
{
        *i = GetChoice(w);
        data->icol[SECONDARY]=*i;
}

void set_file_type(w, t)
Widget w;
int *t;
{

	*t=GetChoice(w);
        if(*t==Gridded_data) 
          data->exhaustive=1;
        else 
          data->exhaustive=0;

	update_par_panel(*t);
}

int update_par_panel(type)
int type;
{
	int i;
	for (i=0; i<XtNumber(par_name); i++) XtManageChild(Par[i]);
	if (type == Gridded_data) {
		XtUnmanageChild(Par[X]);
		XtUnmanageChild(Par[Y]);
		XtUnmanageChild(Par[Z]);
	} else {
		XtUnmanageChild(Par[NXYZ]);
		XtUnmanageChild(Par[DXYZ]);
	}
}
