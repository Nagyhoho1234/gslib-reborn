#include "xgam.h"
#include <Xm/TextF.h>
#include <Xm/LabelG.h>
#include "vario.h"

extern Widget toplevel;
extern Display *display;
extern PAIR *included[];
extern int new_run, new_par;
static GC scat_normal_gc, scat_highlight_gc;
extern GC xgc;
extern var_data var[MAXNVARIOS];

Widget Gama[5];

void gama_change();

#define X 0
#define Y 1
#define Z 2
#define XtNmanaged      "Managed"

#define MAXNHSCAT 5
struct _scat {
	Widget Shell, Info[2], Drawing;
	int nd, iv, il, np, nremoved;
	PAIR *pair;
	var_data *v;
	XRectangle *rec;
	float **dat;
	graph_t *graph;
} *cscat;

extern graphics_data *data;

static void new_axis_title();

static void scat_dismiss(w, s, call_data)
Widget w;
struct _scat *s;
caddr_t *call_data;
{
	XtDestroyWidget(s->Shell);
	s->Shell = NULL;
}

static void put_all_back(w, s, call_data)
Widget w;
struct _scat *s;
caddr_t call_data;
{
	PAIR *tmp;
	s->nremoved=0;
	for (tmp=s->pair; tmp->next!=NULL; tmp=tmp->next)
	{
		if (tmp->removed) 
		{
			sum_one_lag(s->iv, s->il, 1, tmp);
			tmp->removed=0;
		}
	}
	XDrawRectangles(display, XtWindow(s->Drawing), scat_normal_gc,
		s->rec, s->np);
	update_info(s);
        gama_change(s);
	var_to_device(s->v);
	refresh_canvas(s->iv);
}

static draw_one_rec(w, s, ip, gc)
Widget w;
struct _scat *s;
int ip;
GC gc;
{
	XDrawRectangle(XtDisplay(w), XtWindow(w), gc,
		s->rec[ip].x, s->rec[ip].y, 
		s->rec[ip].width, s->rec[ip].height);

}

static void scat_press(w, s, event)
Widget w;
struct _scat *s;
XButtonEvent *event;
{
	int ip, i, il;
	PAIR *tmp;

        int ihead,itail;
	cscat = s; 

       ihead=data->icol[PRIMARY]-1;
       itail=data->icol[SECONDARY]-1;


	if (!click_inside(event->x, event->y, s->graph, 1, 0, new_axis_title)) return;


	if ((ip=closest_point(event, s->rec, s->np))<0) 
	{
/*		wprintf(s->Info[1], " You missed it!"); */
		return;
	}

	if (ip>s->np) ip -= s->np;

	for (i=0, tmp=s->pair; i<ip && tmp->next!=NULL; tmp=tmp->next, i++);

	if (!tmp->removed )
	{
		draw_one_rec(w, s, ip, scat_highlight_gc);
		sum_one_lag(s->iv, s->il, -1, tmp);
		tmp->removed = 1;
		s->nremoved ++;
/*
		wprintf(s->Info[1], 
			"-P(%.1f %.1f %.1f, %.2f)(%.1f %.1f %.1f, %.2f)",
			s->dat[X][tmp->head], s->dat[Y][tmp->head], s->dat[Z][tmp->head],
			s->dat[ihead][tmp->head],
			s->dat[X][tmp->tail], s->dat[Y][tmp->tail], s->dat[Z][tmp->tail],
	 		s->dat[TAIL][tmp->tail]);
*/
	} else {
		draw_one_rec(w, s, ip, scat_normal_gc);
		sum_one_lag(s->iv, s->il, 1, tmp);
		tmp->removed = 0;
		s->nremoved --;
/*
		wprintf(s->Info[1], 
			"+(%.1f %.1f %.1f, %.2f)(%.1f %.1f %.1f, %.2f)",
			s->dat[X][tmp->head], s->dat[Y][tmp->head], s->dat[Z][tmp->head],
			s->dat[ihead][tmp->head],
			s->dat[X][tmp->tail], s->dat[Y][tmp->tail], s->dat[Z][tmp->tail],
	 		s->dat[itail][tmp->tail]);
*/
	}
	var_to_device(s->v);
	refresh_canvas(s->iv);
	update_info(s);
        gama_change(s);
}


static void scat_refresh(w, s, call_data)
Widget w;
struct _scat *s;
caddr_t call_data;
{
	int i,itemp;
	PAIR *tmp;
	graph_t *g;

	if (!XtIsRealized(w)) return;
	cscat = s;
	g = s->graph;
	draw_window(g);

    XDrawRectangles(display, g->win, xgc, s->rec, s->np);
	XDrawLine(display, g->win, xgc, g->x, g->y+g->h, g->x+g->w, g->y);

       

	if (s->nremoved!=0)
	for (i=0, tmp=s->pair; tmp->next!=NULL; tmp=tmp->next, i++)
	if (tmp->removed) draw_one_rec(w, s, i, scat_highlight_gc);
}

static void new_axis_title(i)
int i;
{
	scat_to_device(cscat);
	XClearArea(display, cscat->graph->win, 0, 0, 0, 0, TRUE);
}

void gama_change(s)
struct _scat *s;
{
  
   char buf[24];
/*
   wprintf(s->Info[0],
                "G(%.2f)=%.2f. #Pairs: %d + %d",
                s->v->lag[s->il], s->v->var[s->il], s->v->npt[s->il],
                s->nremoved);
  */     
   
     sprintf(buf, "%.2f",s->v->lag[s->il]); 
     XmTextSetString(Gama[0], buf);
     sprintf(buf, "%.2f",s->v->var[s->il]);
     XmTextSetString(Gama[1], buf);
     sprintf(buf, "%d",s->v->npt[s->il]);
     XmTextSetString(Gama[2], buf);
     sprintf(buf, "%d",s->nremoved);
     XmTextSetString(Gama[3], buf);
     
}  
   
/*
   Plot H scatgram of the point clicked. User may delete or recover any
   pairs by clicking the pair points. The updated variograms are
   calculated and the variogram windows are refreshed following a deletion
   or recovering.
*/
#define NCMDS 2
h_scatgram(iv, il, data)
int iv, il;
graphics_data *data;
{
	int i, j;
	char str[256];
	Widget Board, Cmd[NCMDS];
	static char *cmd_label[] = {"Reset", "Return"};
        Widget rowcol,form;
        static char *label11[]={"Distance", "Gamma","#Pairs","#Removed"};

	struct _scat *s = (struct _scat *)malloc(sizeof(struct _scat));
        int ihead=data->icol[PRIMARY]-1;
        int itail=data->icol[SECONDARY]-1;

	s->graph = (graph_t *)malloc(sizeof(graph_t));
	cscat = s;
     
/* create the h_scattergram dialog */
	sprintf(s->graph->title, "H_Scattergram of lag %d, vario %d", il+1, iv+1);
/*
	s->Shell=XmCreateDialogShell(toplevel, s->graph->title, NULL, 0);
*/
        s->Shell=XmCreateDialogShell(toplevel, "H-scattergram", NULL, 0);
/*
	Board=WidgetCreate("Scatboard", xmBulletinBoardWidgetClass, s->Shell, 
*/
        Board=WidgetCreate("Scatboard", xmFormWidgetClass, s->Shell, 
		XmNautoUnmanage, False, 
		XtNmanaged, False,
                XmNwidth,380,
                XmNheight,600,
		NULL);

	s->graph->W = 350;
	s->graph->H = 300;
	s->graph->w = 250;
	s->graph->h = 250;
	s->graph->x = 50;
	s->graph->y = 20;
 
/* draw the axis defined in v_win.c */
	init_viewport(s->graph, data->rdat[ihead], data->rdat[itail], data->nd);


	s->Drawing=WidgetCreate("Scatdrawing", xmDrawingAreaWidgetClass, Board, 
                XmNleftAttachment,    XmATTACH_FORM,
                XmNtopAttachment,     XmATTACH_FORM,
                XmNrightAttachment,  XmATTACH_FORM,
		XmNwidth, s->graph->W,
		XmNheight, s->graph->H,
		NULL);
/*
	for (j=0; j<2; j++)
	s->Info[j]=WidgetCreate("Click on a point to delete/remove a pair", 
	   xmLabelWidgetClass, Board,
	   XmNx, 0,
	   XmNy, 330+j*20,
	   XmNwidth, 350,
	   XmNrecomputeSize, FALSE,
	   XmNalignment, XmALIGNMENT_BEGINNING,
	   NULL);
*/
/*
        Cmd[0]=WidgetCreate("Reset", xmPushButtonGadgetClass, Board,
                                 XmNleftAttachment,    XmATTACH_FORM,
                                 XmNy, 370, NULL);             
	Cmd[1]=WidgetCreate("Return", xmPushButtonGadgetClass, Board, 
		XmNx, 130, XmNy, 370, NULL);
	XtAddCallback(Cmd[0], XmNactivateCallback, put_all_back, s);
	XtAddCallback(Cmd[1], XmNactivateCallback, scat_dismiss, s);
*/
     rowcol = XtVaCreateWidget ("rowcol1",
        xmRowColumnWidgetClass, Board,
        XmNleftAttachment,   XmATTACH_FORM,
        XmNrightAttachment,  XmATTACH_FORM,
        XmNy, 350,
        NULL);

   for(i=0;i<XtNumber (label11); i++ ) {
      form = XtVaCreateWidget ("form1", xmFormWidgetClass, rowcol,
            XmNfractionBase,  4,
            NULL);

       XtVaCreateManagedWidget (label11[i],
            xmLabelGadgetClass, form,
            XmNtopAttachment,    XmATTACH_FORM,
            XmNbottomAttachment, XmATTACH_FORM,
            XmNleftAttachment,   XmATTACH_FORM,
            XmNrightAttachment,  XmATTACH_POSITION,
            XmNrightPosition,    1,
            XmNalignment,        XmALIGNMENT_END,
            NULL);
      Gama[i]=XtVaCreateManagedWidget ("Gama",
            xmTextFieldWidgetClass, form,
            XmNleftAttachment,   XmATTACH_POSITION,
            XmNrightPosition,    3,
            XmNleftPosition,    2,
            XmNeditable,        False,
            NULL);
/*
      XtAddCallback(Gama[i], XmNactivateCallback, gama_change, NULL);
*/
     XtManageChild( form);
    }
   
      XtManageChild (rowcol);

     Cmd[0]=WidgetCreate("Reset", xmPushButtonGadgetClass, Board,
                           XmNtopAttachment,     XmATTACH_WIDGET,
                           XmNtopWidget,         rowcol,
                           XmNx,100, 
                            NULL);
     Cmd[1]=WidgetCreate("Return", xmPushButtonGadgetClass, Board,
                           XmNx,200,
                            XmNtopAttachment,     XmATTACH_WIDGET,
                            XmNtopWidget,         rowcol,
                           NULL);
        XtAddCallback(Cmd[0], XmNactivateCallback, put_all_back, s);
        XtAddCallback(Cmd[1], XmNactivateCallback, scat_dismiss, s); 
 

	XtManageChild(Board);
	XtManageChild(s->Shell);

	s->graph->win= XtWindow(s->Drawing);
	XtAddCallback(s->Drawing, XmNexposeCallback, scat_refresh, s);
	XtAddEventHandler(s->Drawing, ButtonPressMask, False, scat_press, s);

	s->v = &var[iv];
	s->np= s->v->npt[il];
	s->nd = data->nd;
	s->dat=data->rdat;
	s->pair = var[iv].included[il];
	s->iv = iv;
	s->il = il;

	XGrabButton(display, AnyButton, AnyModifier,
			XtWindow(s->Drawing), TRUE,
			ButtonPressMask | ButtonMotionMask | ButtonReleaseMask,
			GrabModeAsync, GrabModeAsync,
			XtWindow(s->Drawing),
			XCreateFontCursor(display,XC_crosshair));

	init_scat(s, data);
	update_info(s);
        gama_change(s);
}

scat_to_device(s)
struct _scat *s;
{
	int i;
	PAIR *tmp;
        int ihead=data->icol[PRIMARY]-1;
        int itail=data->icol[SECONDARY]-1;

	for (i=0,tmp=s->pair; tmp->next!=NULL; tmp=tmp->next) {
		s->rec[i].x=DEVICEX(s->graph, s->dat[ihead][tmp->head])-1;
		s->rec[i].y=DEVICEY(s->graph, s->dat[itail][tmp->tail])-1;
		s->rec[i].width=s->rec[i].height=2;
		i++;
	}

}

static init_scat(s, data)
struct _scat *s;
graphics_data *data;
{
	PAIR *tmp;
	if (!scat_highlight_gc) {
		XGCValues values;
		nargs=0;
		values.foreground = (int)GetColor("red");
		scat_highlight_gc=XtGetGC(s->Drawing, 
			GCForeground | GCBackground, &values);
		scat_normal_gc=xgc;
	}

	s->rec=(XRectangle *)malloc(s->np*sizeof(XRectangle));
	scat_to_device(s);

	for (tmp=s->pair, s->nremoved=0; tmp->next!=NULL; tmp=tmp->next)
	if (tmp->removed) s->nremoved++;
}

static update_info(s)
struct _scat *s;
{
   /*
	if (!XtIsRealized(s->Info[0])) return;
	wprintf(s->Info[0], 
		"G(%.2f)=%.2f. #Pairs: %d + %d", 
		s->v->lag[s->il], s->v->var[s->il], s->v->npt[s->il],
		s->nremoved);
*/
}
