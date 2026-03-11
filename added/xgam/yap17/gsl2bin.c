
#include <math.h>
#include <stdio.h>

#if FMT==1
#define MAGIC        222
#define FORMAT     float
#else
#define MAGIC        223
/*#define FORMAT  unsigned char*/
#define FORMAT  signed char
#endif

#define  FALSE         0
#define  TRUE          1
#define  X             0
#define  Y             1
#define  Z             2
#define  BIG_STRING 1024
#define  VERYBIG   1e+36

int             n[3], nb_data, var_no;
FORMAT         *values;
float           min, max;
char            title[BIG_STRING], var_name[BIG_STRING], oname[BIG_STRING];

static void     usage(char           *prg_name)   /*F*/
   {
   fprintf(stderr, "\nUsage:");
   fprintf(stderr, "\n   %s input_file output_file", prg_name);
   fprintf(stderr, "\nor %s input_file var_no nx ny nz output_file", prg_name);
   fprintf(stderr, "\n(No output file written)\n");
   exit(1);
   }

static void     print_error(char           *msg)  /*F*/
   {
   fprintf(stderr, "\nError: %s", msg);
   fprintf(stderr, "\nOutput file removed\n");
   unlink(oname);
   exit(1);
   }

static void     gsl_read(FILE           *file)  /*F*/
   {
   char            str1[BIG_STRING], str2[BIG_STRING];
   int             line, var, answer, nb_var;
   float           val;

   fgets(title, BIG_STRING, file);
   title[strlen(title) - 1] = '\0';
   fgets(str1, BIG_STRING, file);
   if (!n[X])     /* get nx, ny and nz on second line */
      {
      sscanf(str1, "%d%d%d%d", &nb_var, &n[X], &n[Y], &n[Z]);
      if (n[X]<=0 || n[Y]<=0 || n[Z]<=0)
         print_error("Didn't find nx, ny or nz on second line of file");
      }
   else
      sscanf(str1, "%d", &nb_var);

   if (nb_var < var_no)
      print_error("Not enough variables");

   printf("\nNb of variables: %d", nb_var);
   printf("\nSize:            %dx%dx%d", n[X], n[Y], n[Z]);
   nb_data = n[0]*n[1]*n[2];
   min = VERYBIG; max = -VERYBIG;
   values = (FORMAT *) calloc(nb_data, sizeof(FORMAT));
   if (!values) print_error("Allocation of values");

   printf("\nTitle:           %s", title);

   for (var=0; var<nb_var; var++)
      {
      fgets(str1, BIG_STRING, file);
      if (var==var_no-1)
         {
         strcpy(var_name, str1);
         var_name[strlen(var_name) - 1] = '\0';
         }
      }

   printf("\nVariable:        %s\n", var_name);

   for (line=0; line<nb_data; line++)
      {
      for (var=0; var<nb_var; var++)
         {
         answer=fscanf(file, "%s", str1);
         if (answer==EOF) 
            {
            sprintf(str1, "End of file reached at at line %d", line+nb_var+3);
            print_error(str1);
            }
         if (var==var_no-1)
            {
            if (!sscanf(str1, "%f", &val))
               {
               sprintf(str2,"Error in input file at line %d (%s)",
                       line+nb_var+3, str1);
               print_error(str2);
               }
            values[line]=(FORMAT)val;
            if (val<min) min=val;
            if (val>max) max=val;
            break;                /* Can stop here and read till end of line */
            }
         }
      fgets(str1, BIG_STRING, file); /* In case there is something more on
                                        the line */
      }
#if FMT==1
   printf("\nMinimum:         %g\nMaximum:         %g", min, max);
#else
   printf("\nMinimum:         %d\nMaximum:         %d", (int)min, (int)max);
   if (min<-128) { printf("\nWarning: values < -128"); min= -128; }
   if (max>127)  { printf("\nWarning: values >  127"); max=127;  }
#endif
   return;
   }

static void     bin_save(FILE           *file)  /*F*/
   {
   int             magic, nb_saved;

   magic    = MAGIC;
   nb_saved = 1;
   fwrite(&magic, sizeof(int), 1, file);
   fwrite(title, sizeof(title), 1, file);
   fwrite(var_name, sizeof(var_name), 1, file);
   fwrite(&min, sizeof(min), 1, file);
   fwrite(&max, sizeof(max), 1, file);
   fwrite(n, sizeof(n), 1, file);
   fwrite(&nb_saved, sizeof(int), 1, file);
   fwrite(values, nb_data * sizeof(FORMAT), 1, file);
   }

main(int         argc,  /*F*/
     char      **argv)  /*F*/
   {
   FILE           *ifile, *ofile;
   char            str[BIG_STRING];

#if FMT==1
   printf("Conversion GSLIB to FLOAT BINARY format\n");
#elif FMT==2
   printf("Conversion GSLIB to CHAR BINARY format\n");
#else
   printf("Check -DFMT=... at compilation\n");
   exit(1);
#endif

   if (argc != 7 && argc != 3)
      usage(argv[0]);

   if (argc==7) strcpy(oname, argv[6]);
   else         strcpy(oname, argv[2]);

   ifile = fopen(argv[1], "r");
   if (!ifile) print_error("Couldn't read input file");
   ofile = fopen(oname, "w");
   if (!ofile) print_error("Couldn't write to output file");

   if (argc==7)    /* nx, ny, nz in file, using first variable */
      {
      var_no=atoi(argv[2]);
      n[X]  =atoi(argv[3]);
      n[Y]  =atoi(argv[4]);
      n[Z]  =atoi(argv[5]);
      if (!var_no) { sprintf(str, "Check variable number (%s)", argv[2]);
                     print_error(str); }
      if (!n[X])   { sprintf(str, "Check nx (%s)", argv[3]);
                     print_error(str); }
      if (!n[Y])   { sprintf(str, "Check ny (%s)", argv[4]);
                     print_error(str); }
      if (!n[Z])   { sprintf(str, "Check nz (%s)", argv[5]);
                     print_error(str); }
      }

   else
      { n[X]=0; var_no=1; }

   printf("\nStarting to read gslib file         %s", argv[1]);
   gsl_read(ifile); fclose(ifile);
#if FMT==1
   printf("\nStarting to write binary float file %s", oname);
#elif FMT==2
   printf("\nStarting to write binary char  file %s", oname);
#endif
   bin_save(ofile); fclose(ofile);
   printf("\nEnd of transfer\n");
   }
