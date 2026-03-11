/**********************xerroc.c*****************/
#include "util.h"
#include "xutil.h"
/* This file contains some important application dependant functions. */
/* No local head files should be included */

void xerror(w,error)
Widget w;
char *error;
{
	Widget werror;
	XmString xmstr=XmStringCreateLtoR(error, XmSTRING_DEFAULT_CHARSET);
    nargs=0;
    setarg(XmNmessageString, xmstr);
    werror=(Widget)XmCreateErrorDialog(w, "error", wargs, nargs); 
    XtUnmanageChild(XmMessageBoxGetChild(werror,XmDIALOG_CANCEL_BUTTON));
    XtUnmanageChild(XmMessageBoxGetChild(werror,XmDIALOG_HELP_BUTTON));
    XtManageChild(werror);
    XtAddCallback(werror, XmNokCallback, okCB, NULL);
	XmStringFree(xmstr);
}

void not_ready()
{
	xerror(toplevel, "Sorry, but this function has not been implemented yet.");
}

CheckForEvents()
{
	XEvent event;
		while (XtPending()) {
			XtNextEvent(&event);
			XtDispatchEvent(&event);
		}
}

XmString str_array_to_xmstr(cs, n)
   char   *cs[];
   int     n;
{
   XmString   xmstr;
   int        i;
   /*
    * If the array is empty just return an empty string.
    */
   if (n <= 0)
      return (XmStringCreateSimple(""));

  xmstr = (XmString) NULL;

  for (i = 0; i < n; i++)  {
    if (i > 0)
       xmstr = XmStringConcat(xmstr,XmStringSeparatorCreate ()); 
    xmstr = XmStringConcat(xmstr, XmStringCreateSimple(cs[i]));
  }
  return (xmstr);
}

void messageCB(w, str, call_data)
Widget    w; 
char     *str[];
caddr_t   call_data;
{
  int        i, n;
  Widget     dialog;
  Widget     label;
  XmString   xmstr;
  Arg        wargs[5];
  /*
   * Create the message dialog to display the help.
   */
   n = 0;
   XtSetArg(wargs[n], XmNautoUnmanage, FALSE); n++;
   dialog = XmCreateMessageDialog(w, "Message", wargs, n);
   /*
    * We won't be using the cancel widget. Unmanage it.
    */
   XtUnmanageChild(XmMessageBoxGetChild (dialog,
                   XmDIALOG_CANCEL_BUTTON));
   /*
    * Retrieve the label widget and make the 
    * text left justified
    */
   label = XmMessageBoxGetChild (dialog,
                                 XmDIALOG_MESSAGE_LABEL);
   n = 0;
   XtSetArg(wargs[n],XmNalignment,XmALIGNMENT_BEGINNING);n++;
   XtSetValues(label, wargs, n);
   /*
    * Add an OK callback to pop down the dialog.
    */
   XtAddCallback(dialog, XmNokCallback, 
                 okCB, NULL);
  /*
   * Count the text up to the first NULL string.
   */
  for(i=0; str[i][0] != '\0'; i++)
    ;
  /*
   * Convert the string array to an XmString array and 
   * set it as the label text.
   */
  xmstr  = str_array_to_xmstr(str, i);
  n = 0;
  XtSetArg(wargs[n],  XmNmessageString, xmstr);n++;
  XtSetValues(dialog, wargs, n);
  /*
   * If the next entry in the help string array is also NULL,
   * then this is the last message. Unmanage the help button.
   */
  if(str[++i][0] == '\0')
    XtUnmanageChild(XmMessageBoxGetChild (dialog,
                    XmDIALOG_HELP_BUTTON));
  /*
   * Otherwise, add a help callback function with the address of 
   * the next entry  in the help string as client_data.
   */
  else{
    XtAddCallback(dialog, XmNhelpCallback, 
                  messageCB, &str[i]);
  }
  /*
   * Display the dialog.
   */
  XtManageChild(dialog);
}

int GetChoice(w)
Widget w;
{
	int choice;
	XtSetArg(wargs[0], XmNuserData, &choice);
	XtGetValues(w, wargs, 1);
	return choice;
}

static Boolean ready;
void PromptValueCB(w, str, call_data)
Widget w;
char *str;
XmListCallbackStruct *call_data;
{
	char *text;
    XmStringGetLtoR(call_data->item, XmSTRING_DEFAULT_CHARSET, &text);
	str=text;
	ready=TRUE;
}

char *PromptValue(w)
Widget w;
{
	Widget Tmp;
	char *str;
	ready=FALSE;
	Tmp=(Widget)XmCreatePromptDialog(w, "PromptValue", NULL, 0);
	XtManageChild(Tmp);
	XtAddCallback(Tmp, XmNokCallback, PromptValueCB, &str);
	while (!ready);
	return str;
}

void okCB(w, data, call_data)
Widget w;
caddr_t *data, call_data;
{
    XtUnmanageChild(w);
    XtDestroyWidget(w);
}

void CancelCB(w, dialog)
Widget w, dialog;
{
	if (dialog==NULL) return;
	XtUnmanageChild(dialog);
	XtDestroyWidget(dialog);
	dialog=NULL;
}

GC create_xor_gc(w)
   Widget            w;
{
  XGCValues values;
  GC        gc;
  Arg       wargs[10];
  /*
   * Get the colors used by the widget.
   */
  XtSetArg(wargs[0], XtNforeground, &values.foreground);
  XtSetArg(wargs[1], XtNbackground, &values.background);
  XtGetValues(w, wargs,2);
  /*
   * Set the fg to the XOR of the fg and bg, so if it is
   * XOR'ed with bg, the result will be fg and vice-versa.
   * This effectively achieves inverse video for the line.
   */
  /* values.foreground = values.foreground ^ values.background;
  */ 
/*
   * Set the rubber band gc to use XOR mode and draw 
   * a dashed line.
  values.line_style = LineSolid;
   */
  values.line_style = LineOnOffDash;
  values.function   = GXxor;
  gc = XtGetGC(w, GCForeground | GCBackground | 
               GCFunction | GCLineStyle, &values);
  return gc;
}

void refresh_window(w)
Widget w;
{
    XClearArea(XtDisplay(w), XtWindow(w), 0, 0, 0, 0, TRUE);
}

/* Find the point which is closest to the clicked point on screen */
int closest_point(event, rec, nrec)
XButtonEvent *event;
XRectangle *rec;
int nrec;
{
	float dis=HUGE, dd;
	int i, dx, dy, closest=(-1);
	for (i=0; i<nrec; i++)
	{
		dx=event->x - rec[i].x - rec[i].width/2;
		dy=event->y - rec[i].y - rec[i].height/2;
		if (ABS(dx)>3 || ABS(dy)>3) continue;
		dd=(float)(dx*dx+dy*dy);
		if (dd<dis) {dis=dd; closest=i;}
	}
	if (closest>=0 && closest<nrec) return closest;
	return (-1);
}
/*
**	initFont()
**
**	Initializes a font for drawing text in for a given graphics context.
**	If you just use this font for a given GC, then you no longer
**	have to worry about the font.
**
*/

XFontStruct	*
initFont(theDisplay, theGC, fontName )
Display *theDisplay;
GC	theGC;
char	fontName[];

{	/* -- function initFont */
	XFontStruct	*fontStruct;

	fontStruct	= XLoadQueryFont( theDisplay, fontName );

	if ( fontStruct != 0 )
		XSetFont( theDisplay, theGC, fontStruct->fid );
	else
		fprintf(stderr, "Warning: font %s not found\n", fontName);

	return( fontStruct );

}	/* -- function initFont */

XRectangle **matrix_rect(nrl,nrh,ncl,nch)
int nrl,nrh,ncl,nch;
{
	int i;
	XRectangle **m;

	m=(XRectangle **) malloc((unsigned) (nrh-nrl+1)*sizeof(XRectangle *));
	if (!m) {fprintf(stderr,"allocation failure 1 in matrix_rect()"); return;}
	m -= nrl;
	for(i=nrl;i<=nrh;i++) {
		m[i]=(XRectangle *) malloc((unsigned) (nch-ncl+1)*sizeof(XRectangle));
		if (!m[i]) 
		{fprintf(stderr,"allocation failure 2 in matrix()"); return;}
	}
	return m;
}

void free_rect(m, nrl,nrh,ncl,nch)
XRectangle **m;
int nrl,nrh,ncl,nch;
{
	int i;
	for(i=nrh;i>=nrl;i--) free((char*) (m[i]+ncl));
	free((char*) (m+nrl));
}
