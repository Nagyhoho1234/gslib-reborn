/*********************xhelp.c********************/
#include "util2.h"
#include "xutil.h"
#include "Xm/XmP.h"

#define NHELP 50
static char help_str[NHELP][BUFSIZE];
static int nhelp;

void InitHelp(char *helpfile)
{
	FILE *fp;
	int i, j;
	char c;
	if ((fp=fopen(helpfile, "r"))==NULL) {
		fprintf(stderr, "WARNING: help file not found\n");
		return;
	}
	/* AIX 3.2 does not work! getc()
	i=(-1);
	while ((c=getc(fp))!=EOF)  {
		if (c=='@') {
			if (++i < NHELP) {j=(-1); continue;}
			else break;
		}
		if ((j++)<BUFSIZE) help_str[i][j] = c;
	}
	*/
	i=0;
	while (i<NHELP && fgets(help_str[i], BUFSIZE, fp)) i++;
	if (i==NHELP) debug("More then %d help items, truncated\n", NHELP); 
	fclose(fp);
	nhelp = i;
#ifdef DEBUG
	fprintf(stderr, "%d help items loaded\n", nhelp);
#endif
}

void ShowHelp(w, data, event)
Widget w;
caddr_t *data;
XEvent *event;
{
	char *wname;
	a_string str;
	int i;
	if (event->type == EnterNotify) {
		wname=XrmQuarkToString(w->core.xrm_name);
		fprintf(stderr, "Entering %s\n", wname);
		for (i=0; i<nhelp; i++) {
			int len=strlen(wname);
			if (!strncmp(wname, help_str[i]+1, len))
			if (StatusW!=NULL) wprintf(StatusW, "%s", help_str[i]+len);
		}
	} else if (event->type == LeaveNotify) {
		if (StatusW!=NULL) wprintf(StatusW, " ");
	}
}
