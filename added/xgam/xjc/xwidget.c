/***************xwidget.c*************/
#include "xutil.h"

#define MAXNITEMS 20
Widget create_table_labels(parent, names, Right, values, nitem)
Widget parent;
char *names[], *values[];
Widget *Right;
int nitem;
{
	Widget Row, Col[2], Left[MAXNITEMS];
	/*
	Widget Right[MAXNITEMS];
	*/
	int i;

	if (nitem>MAXNITEMS) nitem=MAXNITEMS;

	nargs=0; 
	setarg(XmNorientation, XmVERTICAL);
	setarg(XmNpacking, XmPACK_COLUMN);
	setarg(XmNnumColumns, 2);
	Row=XmCreateRowColumn(parent, "table", wargs, nargs);

	nargs=0;
	setarg(XmNorientation, XmVERTICAL);
	setarg(XmNnumColumns, 1);
	Col[0]=XmCreateRowColumn(Row, "left", wargs, nargs);
	Col[1]=XmCreateRowColumn(Row, "right", wargs, nargs);
	for (i=0; i<nitem; i++) Left[i]=XmCreateLabel(Col[0], names[i], NULL, 0);
	for (i=0; i<nitem; i++) Right[i]=XmCreateLabel(Col[1], values[i], NULL, 0);
	XtManageChildren(Left, nitem);
	XtManageChildren(Right, nitem);
	XtManageChildren(Col, 2);
	XtManageChild(Row);
	return Row;
}

Widget create_table_widget(parent, name, Item, names, nitem)
Widget parent, Item[];
char name[], *names[];
int nitem;
{
	Widget Row, Col[2], Label[MAXNITEMS];
	int i, space=70;

	if (nitem>MAXNITEMS) nitem=MAXNITEMS;

	nargs=0;
	setarg(XmNorientation, XmHORIZONTAL);
	setarg(XmNnumColumns, 1);
	Row=XmCreateRowColumn(parent, name, wargs, nargs);
	
	nargs=0;
	setarg(XmNorientation, XmVERTICAL);
	setarg(XmNnumColumns, 1);
	Col[0]=XmCreateRowColumn(Row, "left", wargs, nargs);
	Col[1]=XmCreateRowColumn(Row, "right", wargs, nargs);

	for (i=0; i<nitem; i++) Label[i]=XmCreateLabel(Col[0], names[i], NULL, 0);
	for (i=0; i<nitem; i++) Item[i]=XmCreateText(Col[1], names[i], NULL, 0);
	XtManageChildren(Label, nitem);
	XtManageChildren(Item, nitem);

	XtManageChildren(Col,2);
	XtManageChild(Row);

	return Row;
}
#undef MAXNITEMS

Widget create_ok_cancel_widget(parent, up, okCB, cancelCB, data, label)
Widget parent, up;
void (*okCB)(), (*cancelCB)();
caddr_t *data;
int label;
{
	Widget Label, Separator, RowCol, Btn[3];
	Widget top=up;

	if (label)
	{
	nargs=0;
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, up);
	setarg(XmNleftAttachment, XmATTACH_FORM);
	setarg(XmNrightAttachment, XmATTACH_FORM);
	setarg(XmNrecomputeSize, FALSE);
	setarg(XmNalignment, XmALIGNMENT_BEGINNING);
	setarg(XmNforeground, GetColor("red"));
	Label=XmCreateLabel(parent, ">> ", wargs, nargs);
	XtManageChild(Label);
	top=Label;
	}

	nargs=0;
	setarg(XmNorientation, XmHORIZONTAL);
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, top);
	setarg(XmNleftAttachment, XmATTACH_FORM);
	setarg(XmNrightAttachment, XmATTACH_FORM);
	Separator=XmCreateSeparator(parent, "separator", wargs, nargs);
	XtManageChild(Separator);

	nargs=0;
	setarg(XmNtopAttachment, XmATTACH_WIDGET);
	setarg(XmNtopWidget, Separator);
	setarg(XmNleftAttachment, XmATTACH_FORM);
	setarg(XmNrightAttachment, XmATTACH_FORM);
	RowCol=XmCreateRowColumn(parent, "ok_cancel", wargs, nargs);

	Btn[0]=XmCreatePushButton(RowCol, "OK", wargs, nargs);
	Btn[1]=XmCreatePushButton(RowCol, "Dismiss", NULL, 0);
	Btn[2]=XmCreatePushButton(RowCol, "Help", NULL, 0);
	XtManageChildren(Btn, 3);
	XtManageChild(RowCol);
	XtAddCallback(Btn[0], XmNactivateCallback, okCB, data);
	XtAddCallback(Btn[1], XmNactivateCallback, cancelCB, parent);

	return Label;
}

int device_t=0;
#include <Xm/ToggleB.h>
Widget create_device_radio(w, cb)
Widget w;
void (*cb)();
{
	static char *device_name[]={
		"PostScript Printer", "PostScript File", "GSLIB Text File"};
	Widget Board, Label, Radio, DeviceType[3];
	int i;

	nargs=0; 
	Board=XmCreateBulletinBoard(w, "board", wargs, nargs);

	nargs=0;
	Label=XmCreateLabel(Board, " Device Type:", wargs, nargs);
	XtManageChild(Label);

	nargs=0;
	setarg(XmNy, 30);
	setarg(XmNentryClass, xmToggleButtonWidgetClass);
	setarg(XmNindicatorOn, True);
	Radio=XmCreateRadioBox (Board, "radio", wargs, nargs);
	XtManageChild (Radio);
	for (i=0; i<XtNumber(device_name); i++)
	{
		nargs=0;
		setarg(XmNuserData, i);
		DeviceType[i]=XmCreateToggleButton(Radio, device_name[i], wargs, nargs);
		XtAddCallback(DeviceType[i], 
			XmNvalueChangedCallback, cb, NULL);
	}
	XtManageChildren(DeviceType, XtNumber(device_name));
	XtManageChild(Board);
	nargs=0;
	setarg(XmNset, TRUE);
	XtSetValues(DeviceType[device_t], wargs, nargs);
	return Board;
}

/*****************************************************************************/

#define MAXNITEMS 20
/*
ON DEC, Ultrix 4.1, *lst[] won't compile if use proto_type
Widget create_option_menu(Widget w, char *title, char *lst[], int n, 
int deft, void (*cb)(), caddr_t *data)
*/
Widget create_option_menu(w, title, lst, n,deft, cb, data)
Widget w;
char *title, *lst[];
int n,deft;
void (*cb)();
caddr_t *data;
{
	Widget type, submenu, bt[MAXNITEMS];
	XmString string;
	int i;

	if (n>MAXNITEMS) {
		n=MAXNITEMS;
		fprintf(stderr, "nitems maximum exceeded\n");
	}
	submenu=XmCreatePulldownMenu(w, "subMenu", NULL, 0);
	for (i=0; i<n; i++) {
		nargs=0;
		setarg(XmNuserData, i);
		bt[i]=XmCreatePushButton(submenu, lst[i], wargs, nargs);
		XtAddCallback(bt[i], XmNactivateCallback, cb, data);
	}
	XtManageChildren(bt, n);

	string=XmStringCreateLtoR(title, XmSTRING_DEFAULT_CHARSET);
	nargs=0;
	setarg(XmNsubMenuId, submenu);
	setarg(XmNlabelString, string);
	setarg(XmNmenuHistory, bt[deft]);
	type=XmCreateOptionMenu(w, title, wargs, nargs);
	XtManageChild(type);
	return type;
}

Widget create_table(w, Row, item, nitems, Left, type_L, Right, type_R)
Widget w;
char *item[];
int nitems;
Widget Row[], Left[], Right[];
caddr_t type_L, type_R;
{
	int i, m, len=0, x, width;
	Widget RC;

	nargs=0;
	setarg(XmNmarginHeight, 0);
	setarg(XmNmarginWidth, 0);
	RC=XmCreateRowColumn(w, "table", wargs, nargs);
	for (i=0; i<nitems; i++) {
	nargs=0;
	setarg(XmNmarginHeight, 0);
	setarg(XmNmarginWidth, 0);
	Row[i] =XmCreateBulletinBoard(RC, "labeledText", wargs, nargs);
	Left[i]=XtCreateManagedWidget(item[i], type_L, Row[i], NULL, 0);
	Right[i]=XtCreateManagedWidget("right", type_R, Row[i], NULL, 0);
	}
	XtManageChildren(Row, nitems);
	XtManageChild(RC);
	return RC;
}

Widget create_table3(w, name, Row, Field, type, ncol, nrow)
Widget w, *Row, **Field;
caddr_t type[];
int ncol, nrow;
char *name;
{
	Widget RC;
	int i, j;
	nargs=0;
	setarg(XmNmarginHeight, 0);
	setarg(XmNmarginWidth, 0);
	RC=XmCreateRowColumn(w, name, wargs, nargs);
	for (i=0; i<nrow; i++) {
		nargs=0;
		setarg(XmNmarginHeight, 0);
		setarg(XmNmarginWidth, 0);
		Row[i] = XmCreateBulletinBoard(RC, "row", wargs, nargs);
		for (j=0; j<ncol; j++) {
			char buf[80];
			sprintf(buf, "%s%d", name, j);
			nargs=0;
			setarg(XmNuserData, i);
			Field[j][i] = XtCreateManagedWidget(buf, type[j], 
				Row[i], wargs, nargs);
			XtManageChild(Field[j][i]);
		}
	}
	XtManageChildren(Row, nrow);
	XtManageChild(RC);
	return RC;
}

