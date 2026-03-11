/*****************xio.c***************/
#include "xutil.h"

#include <Xm/FileSB.h>

/*
05/91 adapted from Doug Young's book
09/91 modified so that it writes to both Label and Text widgets
*/
#include <varargs.h>
#include <Xm/Label.h>
void wprintf(va_alist)
     va_dcl
{
  Widget    w;
  char     *format;
  va_list   args;
  char      str[1000];  /* DANGER: Fixed buffer size */
  XmString  xmstr;
  int n;
  /*
   * Init the variable length args list.
   */
  va_start(args);
  /*
   * Extract the destination widget.
   * Make sure it is a subclass of XmLabel.
   */
  w = va_arg(args, Widget);
  if(!XtIsSubclass(w, xmLabelWidgetClass))
     XtError("wprintf() requires a Label Widget");
  format = va_arg(args, char *);
  /*
   * Use vsprintf to format the string to be displayed in the
   * XmLabel widget, then convert it to a compound string
   */
  vsprintf(str, format, args);
  xmstr =  XmStringLtoRCreate(str, XmSTRING_DEFAULT_CHARSET);

  XtSetArg(wargs[0], XmNlabelString, xmstr);
  XtSetValues(w, wargs, 1);     

  va_end(args);
}

wprintf_text(va_alist)
	va_dcl
{
	Widget w;
	char *format;
	va_list args;
	char str[1000];
	int n;
	va_start(args);
	w=va_arg(args, Widget);
	format=va_arg(args, char *);
	vsprintf(str, format, args);
	XmTextSetString(w, str);
	va_end(args);
}
FILE * open_file_for_write(filename, Error)
char *filename;
Widget Error;
{
	FILE *fp;
	if ((fp=fopen(filename, "r"))!=NULL) /* exist */
	{
		wprintf(Error, "%s: file already exist", filename); return NULL;
	} else fclose(fp);
	if ((fp=fopen(filename, "w"))==NULL)
	{
		wprintf(Error, "ERROR: can not create file '%s'", filename);
		return NULL;
	}
	return fp;
}

