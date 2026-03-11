#include "gslib.h"
#include "xgam.h"
#include "vario.h"

extern int gslib_filetype();
extern Widget toplevel;
graphics_data Data, *data = &Data;
extern int ng;
extern var_data var[MAXNVARIOS];

/* return # of data in a GSLIB data file */
init_data()
{
 
    int i;
  
    for( i=0;i<NVARIABLES; i++) 
      data->icol[i]=0;
    data->trim_min=-9999;
    data->trim_max=9999;
    data->exhaustive=0;
    data->threed=FALSE;
    data->variance=0.0;
   
}

int gslib_ndat(fp)
FILE *fp;
{
        int n=0;
        char s[BUFSIZE];

        while (fgets(s, BUFSIZE, fp)!=NULL) n++;
        fclose(fp);
        return n;
}

float **matrix(nrl,nrh,ncl,nch)
int nrl,nrh,ncl,nch;
{
        int i;
        float **m;
        m=(float **) malloc((unsigned) (nrh-nrl+1)*sizeof(float*));
        if (!m) {fprintf(stderr,"allocation failure 1 in matrix()"); return;}
        m -= nrl;
        for(i=nrl;i<=nrh;i++) {
                m[i]=(float *) malloc((unsigned) (nch-ncl+1)*sizeof(float));
                if (!m[i])
                {fprintf(stderr,"allocation failure 2 in matrix()"); return;}
        }
        return m;
}

void free_matrix(m,nrl,nrh,ncl,nch)
float **m;
int nrl,nrh,ncl,nch;
{
        int i;

        for(i=nrh;i>=nrl;i--) free((char*) (m[i]+ncl));

        free((char*) (m+nrl));
}

int gslib_read_data(file,dat,n)
char *file;
int n;
float **dat;
{
  FILE *fp;
  int i,j,nv;


  if ((fp=fopen(file, "r"))==NULL) {
     printf("can not open file");
     return(0);
  }
 
  nv=read_header(fp);
  for(i=0;i<n;i++){ 
    for(j=0;j<nv;j++) {
      fscanf(fp, "%f", &dat[j][i]);
   }
 }
 return (1);

}

int load_var(fp)
FILE *fp;
{
    int length, idummy;
        float fdummy;
        char *pstr, str[256], dummy[256];
        int j=0, i, iv, nv=(-1);
    int n, iline=0, npair, npoints=0;
    float lag, gam, f1, f2;

     fseek(fp, 0, 0);
     while (fgets(str,255,fp)!=NULL) {
        /* if it is just a title line */
        int id;
        iline ++;
        if (sscanf(str,"%d",&id)!=1) {
           if ((++nv)>=MAXNVARIOS) {
             sprintf(str, "Line %d: Maximum number of variograms (%d) exceeded",
                                iline, MAXNVARIOS);
             xerror(toplevel,str);
             break;
           }
           strcpy(var[nv].title,str);
           var[nv].nlag=0;
           var[nv].id=nv;
           npoints=0;
           continue;
         }

                /* now we know it is a variogram point */
        if (sscanf(str,"%d%f%f%d", &n, &lag, &gam, &npair)==4)
        {
            var[nv].lag[npoints]=lag;
            var[nv].var[npoints]=gam;
            var[nv].npt[npoints]=npair;
            if ((++npoints) >= MAXNLAGS) {
               sprintf(str, "Line %d: maximum number of lags (%s) exceeded",
                                        iline, MAXNLAGS);
               xerror(toplevel, str);
               break;
            }
            var[nv].nlag++;
        } 
        else
          xerror(toplevel, "WARNNING: illegal file format\n");

    }

    for (iv=0; iv<=nv; iv++) {
      fprintf(stderr,"Variogram %2d: %d lags read\n",iv+1,var[iv].nlag);
      if (var[nv].lag[0] != 0.0)
      fprintf(stderr, "WARNING: variogram does not start with h=0\n");
    }

    if ((ng = nv+1) > MAXNVARIOS) ng = MAXNVARIOS;
    fprintf(stderr, "%d variogram%s read.\n", ng, (ng>1)?"s":"");

}

int read_data(file)
char *file;
{
    FILE *fp;
    char dummy[BUFSIZE], str[BUFSIZE];
    int is, nvar,ndat;
    int j=0, i, n, iv,type;

        type=gslib_filetype(file);
        if (type==UNKNOWN) {
           sprintf(str,"%s: not a GeoEas data or variogram file", file);
           xerror(toplevel,str);
           is=UNKNOWN;
        }

        if (type==GSLIB_VARIOGRAM) {
           is=VarioModel;
           if((fp=fopen(file,"r"))==NULL) printf("%s: can not open", file);
           load_var(fp);
           switch_state(VarioModel);
        } 
        
        if (type==GSLIB_DATA) { 
            if((fp=fopen(file,"r"))==NULL) printf("%s: can not open", file);
            data->nv = read_header(fp);
            nvar=data->nv;
 
            if(nvar) {
                data->nd=gslib_ndat(fp);
                ndat=data->nd;

                if(data->rdat) free_matrix(data->rdat, 0, nvar-1, 0, ndat-1);
                data->rdat=matrix(0,nvar-1,0,ndat-1);
                gslib_read_data(file,data->rdat,ndat);
            }
            is=SelectVar;
        }

        return is;
}

/* ignore the headers in GEOEAS formatted data file */
int     read_header (fp)
FILE *fp;
{

    char    c,
            dummy[BUFSIZE + 1];
    int     len,
            i,
            nvar;
    fgets (data->title, BUFSIZE, fp);  /* get rid of the title line */

        /* read the number of cloumns */
    fgets (dummy, BUFSIZE, fp);
    if (sscanf (dummy, "%d", &nvar)<1) return 0;

        /* varname is: Unset, variable_1, variable_2, ... */

        /* must be allocated */
        for (i=0; i<=nvar; i++) {
                if(data->varname[i]) free(data->varname[i]);
                data->varname[i]=(char *) malloc(BUFSIZE*sizeof(char));
        }
        strcpy(data->varname[0], "N / A");

    for (i = 1; i <= nvar; i++) {
        fgets (data->varname[i], BUFSIZE, fp);
        data->varname[i][strlen (data->varname[i]) - 1] = '\0';
    }
    return nvar;
}

