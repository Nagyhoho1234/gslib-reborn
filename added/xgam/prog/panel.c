#include "xgam.h"
#include "vario.h"
#include <X11/Xos.h> 
#include <sys/stat.h>
#define VarioMap 0

static Widget *MainMenu;
extern int      SelectVar_create();
extern int      VarioCal_create();
extern int      VarioModel_create();
int      VarioMap_create();
extern varioType vtype;

static Widget *MapTypes;
state_t states[NumStates], *pstate;
extern Widget Panel, swindow;
int istate = (-1);
Widget File;
Widget dialog;
extern graphics_data *data;
extern Widget toplevel;
extern int read_data();
extern void init_data();
void do_search(), new_file_cb();
void fileselect();
Widget MapPar[3];

extern void toggled1();
extern void toggled2();
extern int STAND;


void Mapok()
{

   FILE *fp;
   int np,nxlag,nylag,nzlag;
   float dxlag,dylag,dzlag; 
   int minpairs;

   fp=fopen("xvarmap.par","w");
   
  fprintf(fp,"%s\n",data->filename);
  if(data->icol[PRIMARY]==data->icol[SECONDARY])
    fprintf(fp,"%d %d %d\n",1,data->icol[PRIMARY],data->icol[SECONDARY]);
  else
    fprintf(fp,"%d %d %d\n",2,data->icol[PRIMARY],data->icol[SECONDARY]);

  fprintf(fp,"%f %f\n",data->trim_min,data->trim_max);
 
  if(data->exhaustive) {
    fprintf(fp,"%d\n",1);
    fprintf(fp,"%d %d %d\n",data->nx,data->ny,data->nz);
    fprintf(fp,"%f %f %f\n",data->dx,data->dy,data->dz);
    fprintf(fp,"%d %d %d\n",1,2,0);
  }
  else {
    fprintf(fp,"%d\n",0);
    fprintf(fp,"%d %d %d\n",50,50,1); 
    fprintf(fp,"%f %f %f\n",1.0,1.0,1.0);
    fprintf(fp,"%d %d %d\n",data->icol[X],data->icol[Y],data->icol[Z]);
  }
  
    np=sscanf(XmTextGetString(MapPar[0]), "%d%d%d",
                &nxlag,&nylag,&nzlag);  /* number of lags */
    fprintf(fp,"%d %d %d\n",nxlag,nylag,nzlag);
    np=sscanf(XmTextGetString(MapPar[1]), "%f%f%f",
                &dxlag,&dylag,&dzlag);  /* lag distances */
    fprintf(fp,"%f %f %f\n",dxlag,dylag,dzlag);
    np=sscanf(XmTextGetString(MapPar[2]), "%d",
                &minpairs);
    fprintf(fp,"%d\n",minpairs);
    fprintf(fp,"%d\n",STAND);

 switch(vtype){
   case Traditional_semivariogram:
     fprintf(fp,"%d %d %d\n",1,1,1);
     break;
   case Traditional_cross_semivariogram:
     fprintf(fp,"%d %d %d\n",1,2,2);
     break;
   case Covariance:
      fprintf(fp,"%d %d %d\n",1,1,3);
      break;
  }
  fclose(fp);
  system("./varmap");
  system("/yap xvarmap.out"); 
   


}


void selvartype(w)
Widget w;
{
        vtype = xv_GetChoice(MapTypes);
        fprintf(stderr, "Variogram Type: %d \n", vtype);
}

int VarioMap_create(parent)
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
   static char *map_name1[]={
     "nlag:  x y z    ",
     "dlag:  x y z    ",
     "min pairs    "
   };

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

   for(i=0;i<XtNumber(map_name1);i++){
       MapPar[i] = (Widget) CreateTextItem(ParPanel,
                    xv_col(ParPanel, 9), xv_row(ParPanel, irow++),
                    15, map_name1[i]);
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

       MapTypes = CreatePanelChoice(ParPanel, "Variogram Type:",
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
        XtAddCallback(MapTypes[2+i],XmNactivateCallback, selvartype, NULL);

        Ok = WidgetCreate("Calculate", xmPushButtonWidgetClass, ParPanel,
                XmNleftAttachment, XmATTACH_FORM,
                XmNrightAttachment, XmATTACH_FORM,
                XmNy, xv_row(ParPanel, irow),
                NULL);

        XtAddCallback(Ok, XmNactivateCallback, Mapok, NULL);

        return TRUE;


}

quit(w, data)
Widget w;
caddr_t *data;
{
    exit(0);
}


switch_state(i)
int i;
{
	int go_ahead=0;
	state_t *old = pstate, *new = &states[i];
       
       /*   
        if (i==istate) return; 
*/
	if (new->active!=1) {
		nargs=0;
		setarg(XmNleftAttachment, XmATTACH_FORM);
		setarg(XmNrightAttachment, XmATTACH_FORM);
		setarg(XmNtopAttachment, XmATTACH_WIDGET);
		setarg(XmNtopWidget, MainMenu[0]);
		setarg(XmNbottomAttachment, XmATTACH_WIDGET);
		new->ParPanel=XmCreateForm(Panel, "panel", wargs, nargs);
		new->Drawing =XmCreateDrawingArea(swindow, "drawing", NULL, 0);
		go_ahead=new->create(new->ParPanel);
	} else 
		go_ahead=TRUE;

	XtUnmanageChild(Panel);
	if (go_ahead) {
		if (istate!=(-1)) {
			XtUnmanageChild(old->ParPanel);
			XtUnmanageChild(old->Drawing);
		}
		XtManageChild(new->ParPanel);
		XtManageChild(new->Drawing);
		pstate = new;
		istate = i;
		pstate->active = 1;
	} 
	XtManageChild(Panel);
}


set_main_menu(w)
Widget w;
{
        int i=xv_GetChoice(MainMenu);
        
        if (i==ExitState) quit();
        switch_state(i);
}


void create_panels(parent)
Widget parent;
{
        int i;

    XmString filelabel;
    static char *main_menu[] = {
        "Vario Volume",
        "Select Variable",
        "Vario Calculation",
        "Vario Modelling",
        "Exit"
   };



    nargs=0;

    setarg(XmNy, 100);
    setarg(XmNleftAttachment, XmATTACH_FORM);
    setarg(XmNrightAttachment, XmATTACH_FORM);
    filelabel=XmStringCreateLocalized("Select file");
    setarg(XmNlabelString, filelabel); 
    File=XmCreatePushButton(parent, "fileselection", wargs, nargs);
    XtAddCallback(File, XmNactivateCallback, fileselect, NULL); 
    XmStringFree(filelabel);
    XtManageChild(File);


    MainMenu=CreatePanelChoice(parent,
             "Main Menu:", 100, 150,
              6,
             "Vario Volume",
             "Select Variable",
             "Vario Calculation",
             "Vario Modelling",
             "Exit",
             0);
   

    for (i=0; i<XtNumber(main_menu); i++)
        XtAddCallback(MainMenu[i+2], XmNactivateCallback, set_main_menu, NULL);
   
    states[SelectVar ].create = SelectVar_create;
    states[VarioCal  ].create = VarioCal_create;
    states[VarioModel].create = VarioModel_create;
    states[VarioMap  ].create = VarioMap_create;
}


/* routine to determine if a file is accessible, a directory,
 * or writable.  Return -1 on all errors or if the file is not
 * writable.  Return 0 if it's a directory or 1 if it's a plain
 * writable file.
 */

int
is_writable(file)
char *file;
{
    struct stat s_buf;

    /* if file can't be accessed (via stat()) return. */
    if (stat (file, &s_buf) == -1)
        return -1;
    else if ((s_buf.st_mode & S_IFMT) == S_IFDIR)
        return 0; /* a directory */
    else if (!(s_buf.st_mode & S_IFREG) || access (file, W_OK) == -1)
        /* not a normal file or it is not writable */
        return -1;
    /* legitimate file */
    return 1;
}

void cancelsel()
{

    XtUnmanageChild(dialog);
    XtDestroyWidget(dialog);
}
 
void fileselect(w, data,call_data)
    Widget w;
    caddr_t   *data;
    XmAnyCallbackStruct *call_data;
{
    
    Arg args[5];
    int n=0;

 /*   XtSetArg (args[n], XmNfileSearchProc, do_search); n++;
*/

    dialog=XmCreateFileSelectionDialog (toplevel, "Files", NULL, 0);

    XtSetSensitive (
        XmFileSelectionBoxGetChild (dialog, XmDIALOG_HELP_BUTTON), False);
    XtAddCallback (dialog, XmNokCallback, new_file_cb, NULL);
    XtAddCallback (dialog, XmNcancelCallback, cancelsel, NULL);

    XtManageChild (dialog);

}
 
/* a new file was selected -- check to see if it's readable and not
 * a directory.  If it's not readable, report an error.  If it's a
 * directory, scan it just as tho the user had typed it in the mask
 * Text field and selected "Search".
 */
void
new_file_cb(widget, client_data, call_data)
Widget widget;
XtPointer client_data;
XtPointer call_data;
{
    char *file;
    int is;
    char dataname[256];

    XmFileSelectionBoxCallbackStruct *cbs =
        (XmFileSelectionBoxCallbackStruct *) call_data;

    /* get the string typed in the text field in char * format */
    if (!XmStringGetLtoR (cbs->value, XmFONTLIST_DEFAULT_TAG, &file))
       return;
    if (*file != '/') {
        /* if it's not a directory, determine the full pathname
         * of the selection by concatenating it to the "dir" part
         */
        char *dir, *newfile;
        if (XmStringGetLtoR (cbs->dir, XmFONTLIST_DEFAULT_TAG, &dir)) {
            newfile = XtMalloc (strlen (dir) + 1 + strlen (file) + 1);
            sprintf (newfile, "%s/%s", dir, file);
            XtFree( file);
            XtFree (dir);
            file = newfile;
        }
    }
    switch (is_writable (file)) {
        case 1 : {
            strcpy(dataname,file);
            strcpy(data->filename,file);
            init_data();
            read_data(dataname);  
            XtUnmanageChild(dialog);
            XtDestroyWidget(dialog);
            states[SelectVar].active=0;
/*            switch_state(SelectVar); */
            break;
        }
        case 0 : {
            /* a directory was selected, scan it */
            XmString str = XmStringCreateLocalized (file);
            XmFileSelectionDoSearch (widget, str);
           XmStringFree (str);
            break;
        }
        case -1 :
            /* a system error on this file */
            perror (file);
    }
    XtFree (file);
}


/* do_search() -- scan a directory and report only those files that
 * are writable.  Here, we let the shell expand the (possible)
 * wildcards and return a directory listing by using popen().
 * A *real* application should -not- do this; it should use the
 * system's directory routines: opendir(), readdir() and closedir().
 */
void
do_search(widget, search_data)
Widget widget; /* file selection box widget */
XtPointer search_data;
{
    char          *mask, buf[BUFSIZ], *p;

  XmString       names[256]; /* maximum of 256 files in dir */
    int            i = 0;
    FILE          *pp, *popen();
    XmFileSelectionBoxCallbackStruct *cbs =
        (XmFileSelectionBoxCallbackStruct *) search_data;

    if (!XmStringGetLtoR (cbs->mask, XmFONTLIST_DEFAULT_TAG, &mask))
        return; /* can't do anything */

    sprintf (buf, "/bin/ls %s", mask);
    XtFree (mask);
    /* let the shell read the directory and expand the filenames */
    if (!(pp = popen (buf, "r")))
        return;
    /* read output from popen() -- this will be the list of files */
    while (fgets (buf, sizeof buf, pp)) {
        if (p = index (buf, '\n'))
            *p = 0;
        /* only list files that are writable and not directories */
        if (is_writable (buf) == 1 &&
            (names[i] = XmStringCreateLocalized (buf)))
            i++;
    }

   pclose (pp);
    if (i) {
        XtVaSetValues (widget,
            XmNfileListItems,      names,
            XmNfileListItemCount,  i,
            XmNdirSpec,            names[0],
            XmNlistUpdated,        True,
            NULL);
        while (i > 0)
            XmStringFree (names[--i]);
    } else
        XtVaSetValues (widget,
            XmNfileListItems,      NULL,
            XmNfileListItemCount,  0,
            XmNlistUpdated,        True,
            NULL);
}


