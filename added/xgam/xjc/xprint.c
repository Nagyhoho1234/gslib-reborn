/********************xprint.c*******************/
#include "xutil.h"

/* send a file to printer */
#ifndef WIFEXITED
#define WIFEXITED(x)    ((x & 0xff) == 0)
#endif

#ifndef WEXITSTATUS
#define WEXITSTATUS(x)  ((x >> 8) & 0xff)
#endif
send_printer_output(w, filename, printer)
Widget w;
char *filename, *printer;
{
	int pid, status;
	char tmp[512];

	if (printer == NULL) {
		wprintf(w, "You must specify a printer name");
		unlink(filename);
		return;
	}

	(void)sprintf(tmp, "lpr -P%s %s >& /dev/null", printer, filename);
	if (!try_cmd_from_shell(tmp))
		xerror(toplevel, "Could not send PostScript file to printer.",
			printer);
	else
		xerror(toplevel, "PostScript file sent to printer.");
	unlink(filename);
}
