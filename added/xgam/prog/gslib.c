#include<math.h>
#include "gslib.h"

int gslib_filetype(char *file)
{
        FILE *fp;
        char str[256], *buf;
        int n, nvar, i, magic;
        if ((fp=fopen(file, "r"))==NULL) {
                fprintf(stderr, "%s: can not open.\n", file);
                exit(1);
        }

        /* check if it is a binary file */
        rewind(fp);
        n=fread(&magic, sizeof(int), 1, fp);
        if (n<1) return_unknown;
        if (magic==MAGIC) return BINARY_GRIDED;

        rewind(fp);
        get_next_line();

        if (strstr(str, "gram")!=NULL || strstr(str, "vari")!=NULL) {
                int f1;
                float f2, f3;
                get_next_line();
                n=sscanf(str, "%d%f%f", &f1, &f2, &f3);
                if (n==3) return GSLIB_VARIOGRAM;
        }

        /* check if it is a gslib data file */
        rewind(fp);
        get_next_line();
        if (fscanf(fp, "%d", &nvar)!=1 || nvar<=0) return_unknown;
        get_next_line();
        for (i=0; i<nvar; i++) {get_next_line(); }
        get_next_line();     
        
        buf=str;
        for (n=0; ; n++) {
                char c;
                float tmp;
                while ((c= *buf)==' ' || c=='\t' && c!='\0') buf++;
                if (sscanf(buf, "%f", &tmp)!=1) break;
                while ((c=(*buf))!='\0' && c!=' ' && c!='\t') buf++;
        }
        if (n==nvar) return GSLIB_DATA;

        fclose(fp);
        return UNKNOWN;
}

/* square structural distance of two points. the anisotropy is characterized
in 3x3 matrix rotmat, which was initialized by setrot().
Original: Clayton
*/
float sqdist(dx, dy, dz, rotmat)
float dx, dy, dz;
float rotmat[][3];
{
        int i;
        float sq=0.0;
        for (i=0; i<3; i++) {
                float tmp=rotmat[i][0] * dx + rotmat[i][1] * dy + rotmat[i][2] * dz;
                sq += tmp*tmp;
        }
        return sq;
}

setrot(a)
anisotropy_t * a;
{
        float         alpha, beta, theta;
        float         sina, sinb, sint, cosa, cosb, cost, afac1, afac2;

        printf("angel1=%f\n a->anis1=%f\n",a->anis2,a->anis1);
        if (a->ang1 >= 0.0 && a->ang1 < 270.0)
                alpha = (90.0 - a->ang1) * DEG2RAD;
        else
                alpha = (450.0 - a->ang1) * DEG2RAD;

        beta = -1.0 * a->ang2 * DEG2RAD;
        theta = a->ang3 * DEG2RAD;

        sina = sin(alpha), sinb = sin(beta), sint = sin(theta);
        cosa = cos(alpha), cosb = cos(beta), cost = cos(theta);


        afac1 = 1.0 / MAX(a->anis1, EPSLON);
        afac2 = 1.0 / MAX(a->anis2, EPSLON);
        printf("afac1=%f afac2=%f\n",afac1,afac2);
        a->rotmat[0][0] = (cosb * cosa);
        a->rotmat[0][1] = (cosb * sina);
        a->rotmat[0][2] = (-sinb);
        a->rotmat[1][0] = afac1 * (sint * sinb * cosa - cost * sina);
        a->rotmat[1][1] = afac1 * (cost * cosa + sint * sinb * sina);
        a->rotmat[1][2] = afac1 * (sint * cosb);
        a->rotmat[2][0] = afac2 * (sint * sina + cost * sinb * cosa);
        a->rotmat[2][1] = afac2 * (cost * sinb * sina - sint * cosa);
        a->rotmat[2][2] = afac2 * (cost * cosb);

        printf("Rotation Matrix:\n%f %f %f\n%f %f %f\n %f %f %f\n",
                    a->rotmat[0][0], a->rotmat[0][1], a->rotmat[0][2],
                    a->rotmat[1][0], a->rotmat[1][1], a->rotmat[1][2],
                    a->rotmat[2][0], a->rotmat[2][1], a->rotmat[2][2]);
}

/* functions to calculat 3D covariance. setrot() must be called first */
init_cova3(m)
model_t *m;
{
                int i;
                m->cmax=m->nugget;
                for (i=0; i<m->nst; i++)
                        m->cmax +=m->vario[i].sill;
}

float cova3(m, dx, dy, dz)
model_t m;
float dx, dy, dz;
{
        int i;
        float cov, hsqd;
        cov=0.0;

        if (dx==0. && dy==0. && dz==0.) return m.cmax;
        for (i=0; i<m.nst; i++) {
                variogram_t *v= &m.vario[i];
                float hr, h;
                hsqd=sqdist(dx, dy, dz,v->anis.rotmat);
                h=sqrtf(hsqd);
                printf("h=%f type=%d sill=%f range=%f\n",h,v->type,v->sill,v->range);
   
                switch (v->type) {
                case SPHERICAL:{
                        hr=h/v->range;
                        if(hr<1) cov =cov+v->sill*(1.0-hr*(1.5-.5*hr*hr));
                        break;
                }
                case EXPONENTIAL:{
                        cov = cov + v->sill * expf(-3*h/v->range);
                        break;
                }
                case GAUSSIAN:{
                        float temp;
                        hr = h/v->range;
                        hr=hr*hr;
                        temp=expf(-3.0*hr);
                        temp=v->sill*temp;
                        cov = cov + v->sill*expf(-3.0*hr);
                        break;
                }
                default:
                        printf("unknown variogram type: %d", v->type);
                }
        }
        return cov;
}

