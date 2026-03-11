#include "xgam.h"
#include "vario.h"


#define EPSLON SMALL
#define X 0
#define Y 1
#define Z 2

extern varioType vtype;
extern graphics_data *data;
extern var_data var[MAXNVARIOS]; 
extern Widget toplevel;
extern int STAND; 

void sum();
void cal_gam()
{
}


float *vector(nl,nh)
int nl,nh;
{
        float *v;

        v=(float *)malloc((unsigned) (nh-nl+1)*sizeof(float));
        if (!v) printf("allocation failure in vector()");
        return v-nl;
}

/* 2D variogram calculation: modified from GSLIB gamv2.f */
void cal_gamv(v)
var_data *v;
{
   int i, id, jd;
   float azimuth, band;
   float dx, dy, dz, csatol, dcazm, maxlag2, h, h2;
   float dx2, dy2,dz2;

   float *h2left=vector(0, v->nlag);
   float *h2right=vector(0, v->nlag);
   PAIR **tmp=(PAIR **)malloc((v->nlag+1)*sizeof(PAIR *));

	/*
	t: theta, direction
	d: delta, direction tolerance
	a: alpha, angle of the distance vetor
	*/
	float sin_t, cos_t, cos_d, cos_dt, cos_ta;
	float sin2_t, cos2_t, sin_2t, cos2_ta, cos2_d;
        float declin,uvzdec,uvhdec,csdtol,dxy,dcdec;

	/* consider special case */
	azimuth=v->dir;

	azimuth = (90.-azimuth)*PI/180.;
	cos_t = cos(azimuth);
	sin_t = sin(azimuth);
	sin2_t = sin_t * sin_t;
	cos2_t = cos_t * cos_t;
	sin_2t = 2*sin_t*cos_t;

	cos_d = cos(v->dirtol*PI/180.0);
	cos2_d = cos_d * cos_d;
 
 
        if(data->threed) {
             declin=(90.0-v->dip)*PI/180.;
             uvzdec=cos(declin);
             uvhdec=sin(declin);
             csdtol=cos(v->diptol*PI/180.0);
        }

	/* clean up memory */

/*
BUGS: crashes when doing q=p->next. 
-> memory leak!!!
*/
	if (v->included!=NULL) {
		for (i=1; i<v->nlag; i++) {
			PAIR *p=v->included[i], *q;
			for (; p; p=q) {
				q = p->next;
				free(p);
			}
		}
		free((char *)v->included);
	}


	v->included = (PAIR **)malloc((v->nlag+1)*sizeof(PAIR *));
	h2left[0]=0.0;
	h2right[0]=0.0;

	for (i=0; i<v->nlag; i++) {
		v->npt[i] = 0;
		h2left[i]=(v->lag[i]-v->lagtol)*(v->lag[i]-v->lagtol);
		h2right[i]=(v->lag[i]+v->lagtol)*(v->lag[i]+v->lagtol);
		v->included[i]=(PAIR *)malloc(sizeof(PAIR));
		tmp[i] = v->included[i];
	}

	maxlag2=h2right[v->nlag-1];


	for (id=0; id<data->nd; id++)
	for (jd=id; jd<data->nd; jd++)
	{
		dx=data->rdat[X][id]-data->rdat[X][jd];
		dy=data->rdat[Y][id]-data->rdat[Y][jd];
		dx2 = dx*dx;
                dy2=dy*dy;

                if(data->threed) {
                  dz=data->rdat[Z][id]-data->rdat[Z][jd];
                  dz2=dz*dz;
                }

		h2=dx2 + dy2;
                if(data->threed) h2=h2+dz2;
                h=sqrtf(h2);
                
		if (h2>=maxlag2) continue;
/*  check for an acceptable azimuth angle*/

                dxy=sqrtf(dx2+dy2);

                if(dxy<EPSLON) 
                   cos2_ta=1.0;
                else  
                 cos2_ta=(dx*cos_t+dy*sin_t)/dxy; 
 	        if (ABS(cos2_ta)<cos_d) 
                   continue;

 
/*  check the horizontal bandwidth */

		band = cos_t * dy - sin_t * dx;
		if (ABS(band)>v->dirband) continue;

/* check for an acceptable dip angel */
                if(data->threed) {
                   if(cos2_ta<0.0) dxy=-dxy;
                   if(h<=EPSLON)
                      dcdec=0.0;
                   else 
                     dcdec=(dxy*uvhdec+dz*uvzdec)/h; 
                if(ABS(dcdec)<csdtol) continue;
                  
 /* check the vertical bandwidth*/

                  band=uvhdec*dz-uvzdec*dxy;
                  if(ABS(band)>v->dipband) continue;
                }
                
 
		/* Now it is a good pair, let's see which lag it belongs to */
		for (i=1; i<v->nlag; i++)
		if (h2>h2left[i] && h2<=h2right[i])
		{
			tmp[i]->head = id;
			tmp[i]->tail = jd;

			tmp[i]->removed = FALSE;
			tmp[i]->next=(PAIR *)malloc(sizeof(PAIR));
			if (!tmp[i]->next) RETURN("not enough memory");
			tmp[i] = tmp[i]->next;
			tmp[i]->next = NULL;
		/* does not allow one pair appears in more than one interval */
			v -> npt[i] ++;
			break; 
		}
    }
	sum(data, v);
        
}
/*
#define _HEAD data->rdat[PRIMARY][tmp->head]
#define _TAIL data->rdat[SECONDARY][tmp->tail]
*/

void sum(data,v)
graphics_data *data;
var_data *v;
{
    PAIR *tmp;
    float g, gam, hm, tm, hv, tv, htave, dif,dif1,dif2;
    int i;
    float hsum,tsum,tseq,hseq,headvar,tailvar,tvar,hvar,cov,sumpair;

    
    int ihead,itail;
  
    ihead=data->icol[PRIMARY]-1;
    itail=data->icol[SECONDARY]-1;

    for (i=0; i<v->nlag; i++) { 
      if (!v->npt[i]) {
        v->var[i]=0.;
        continue;
      }

    gam=tm=hm=hv=tv=0.;
    tmp = v->included[i];

    if (!tmp) continue;

    switch (vtype){
      case Traditional_semivariogram: {
	for (; tmp->next; tmp=tmp->next){
          dif = data->rdat[ihead][tmp->head]-data->rdat[itail][tmp->tail];
          gam += dif * dif;
        }
        v->var[i] = 0.5 * gam / v->npt[i];
        if(STAND && data->variance>TINY) 
          v->var[i]=v->var[i]/data->variance;
     break;
     }
     case Traditional_cross_semivariogram: {
       for(;tmp->next!=NULL; tmp=tmp->next) {
         dif1=data->rdat[ihead][tmp->head]-data->rdat[ihead][tmp->tail];
          dif2 = data->rdat[itail][tmp->head]-data->rdat[itail][tmp->tail];
          gam += dif1 * dif2;
        }
        v->var[i] = 0.5 * gam / v->npt[i];
        break;
     } 
     case Covariance: {
       hsum=0;
       tsum=0;
       for(;tmp->next!=NULL; tmp=tmp->next) {
          headvar=data->rdat[ihead][tmp->head];
          tailvar=data->rdat[itail][tmp->tail];
          hsum=hsum+headvar;
          tsum=tsum+tailvar;
          gam += headvar*tailvar;
          
        }
        
        v->var[i]=gam /v->npt[i]-hsum*tsum/(v->npt[i]*v->npt[i]);

        break;
     }
     case Correlogram: {
         tsum=0;
         hsum=0;
         hseq=0;
         tseq=0;
       for(;tmp->next!=NULL; tmp=tmp->next) {
          headvar=data->rdat[ihead][tmp->head];
          tailvar=data->rdat[itail][tmp->tail];
          hsum=hsum+headvar;
          tsum=tsum+tailvar;
          hseq+=headvar*headvar;
          tseq+=tailvar*tailvar;
          gam += headvar*tailvar;
        }
        hsum=hsum/v->npt[i];
        tsum=tsum/v->npt[i];
        hvar=hseq/v->npt[i]-hsum*hsum;
        tvar=tseq/v->npt[i]-tsum*tsum;
        cov=gam /v->npt[i]-hsum*tsum;

        if((hvar*tvar)<EPSLON)
           v->var[i]=0.0;
        else 
          v->var[i]=cov/(sqrtf(hvar)*sqrtf(tvar));
        break;
     }
     case General_relative_semivariogram: {
        for (; tmp->next!=NULL; tmp=tmp->next) {
            dif = data->rdat[ihead][tmp->head]-data->rdat[itail][tmp->tail];
            gam += dif * dif;
            hm += data->rdat[ihead][tmp->head];
            tm += data->rdat[itail][tmp->tail];
        }
        hm = hm/v->npt[i];
        tm = tm/v->npt[i];
        gam= gam/v->npt[i];
        if ((hm+tm)<EPSLON) 
            v->var[i] = 0.;
        else {
           htave = 0.5*(hm+tm);
           v->var[i] = gam/(htave*htave);
        }
        break;

     }
     case Pairwise_relative_semivariogram: {
        for (; tmp->next!=NULL; tmp=tmp->next) {
             headvar=data->rdat[ihead][tmp->head];
             tailvar=data->rdat[itail][tmp->tail];
          if ((headvar+tailvar) < EPSLON)  
              v->npt[i] --;
          else {
             dif = headvar-tailvar;
             sumpair=headvar+tailvar;
             g=dif/sumpair;
             gam += g*g;
          }
        }
       v->var[i] = 0.5*gam/v->npt[i];
       break;
     }
     case Semivariogram_of_logarithms: {
         for (; tmp->next!=NULL; tmp=tmp->next) {
              headvar=data->rdat[ihead][tmp->head];
              tailvar=data->rdat[itail][tmp->tail];
              if (headvar <EPSLON || tailvar <EPSLON)
                   v->npt[i] --;
              else {
                g=log10(headvar)-log10(tailvar);
                gam += g*g;
             }
         }
       v->var[i] = 0.5*gam/v->npt[i];
       break;
     }
     case Semimadogram: {
       for(;tmp->next!=NULL; tmp=tmp->next) {
           dif=data->rdat[ihead][tmp->head]-data->rdat[itail][tmp->tail];
             gam += ABS(dif);
       }
       v->var[i] = 0.5*gam/v->npt[i];
      break;
     }

   }

  }
}


sum_one_lag(iv, il, is, tmp)
int iv, il; /* index for variogram, lag, and pair */
int is; /* -1 if one pair is removed. +1 if one pair is added back */
PAIR *tmp;
{
        int  i;
        int ihead,itail;
        float gam,dif1,dif2;

        gam=0.;
        ihead=data->icol[PRIMARY]-1;
        itail=data->icol[SECONDARY]-1;


         dif1=data->rdat[ihead][tmp->head]-data->rdat[ihead][tmp->tail];
         dif2=data->rdat[itail][tmp->head]-data->rdat[itail][tmp->tail];

        if (var[iv].npt[il]+is <= 0) {
                xerror(toplevel, "At least one pair is needed\n");
                return;
        }
        if(STAND && data->variance>TINY) 
           var[iv].var[il] = (var[iv].var[il] * var[iv].npt[il]*data->variance+
               (float)is * dif1 * dif2 / 2.)
               /((var[iv].npt[il]+is)*data->variance);
        else 
           var[iv].var[il] = (var[iv].var[il] * var[iv].npt[il] +
                (float)is * dif1 * dif2 / 2.)
                /(var[iv].npt[il]+is);

        var[iv].npt[il] += is;
}

