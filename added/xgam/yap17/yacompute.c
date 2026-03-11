#include "yaconfig.h"
#include "yap.h"
#include <X11/cursorfont.h>
#include <sys/types.h>
#include <sys/times.h>

extern World_t   *world;
extern Widgets_t *widgets;

extern int      nX[4], nY[4], sX[4], sY[4], coeff[4];
Stat_t          stat_THREED;

/* Taken from numerical recipes */
#define M 7
#define NSTACK 50
#define FM 7875
#define FA 211
#define FC 1663

static void qcksrt(int n, float *arr)
{
	int l=1,jstack=0,j,ir,iq,i;
	int istack[NSTACK+1];
	long int fx=0L;
	float a;
   /*void nrerror();*/

	ir=n;
	for (;;) {
		if (ir-l < M) {
			for (j=l+1;j<=ir;j++) {
				a=arr[j];
				for (i=j-1;arr[i]>a && i>0;i--) arr[i+1]=arr[i];
				arr[i+1]=a;
			}
			if (jstack == 0) return;
			ir=istack[jstack--];
			l=istack[jstack--];
		} else {
			i=l;
			j=ir;
			fx=(fx*FA+FC) % FM;
			iq=l+((ir-l+1)*fx)/FM;
			a=arr[iq];
			arr[iq]=arr[l];
			for (;;) {
				while (j > 0 && a < arr[j]) j--;
				if (j <= i) {
					arr[i]=a;
					break;
				}
				arr[i++]=arr[j];
				while (a > arr[i] && i <= n) i++;
				if (j <= i) {
					arr[(i=j)]=a;
					break;
				}
				arr[j--]=arr[i];
			}
			if (ir-i >= i-l) {
				istack[++jstack]=i+1;
				istack[++jstack]=ir;
				ir=i-1;
			} else {
				istack[++jstack]=l;
				istack[++jstack]=i-1;
				l=i+1;
			}
			/*if (jstack > NSTACK) nrerror("NSTACK too small in QCKSRT");*/
		}
	}
}

#undef M
#undef NSTACK
#undef FM
#undef FA
#undef FC
/* We'll compute the global stat ahead of time (plane=4)
   and on the fly for the planes */
Stat_t   compute_stat(int                 plane)        /*F*/
   {
   int    idx_begin, i, j, nb;
   float  s_min, s_max, v, *val;
   Stat_t stat;
   char   d, p[2];
   float  sum, min, max;
   float  mean, std_dev;

   time_t a, b;

time(&b);
   std_dev=0;
   nb=0; sum=0;
   s_min=world->show_min; s_max=world->show_max;
   min=world->show_max; max=world->show_min;
   idx_begin=world->sld[plane]*coeff[plane];
   val=(float *)calloc(nX[plane]*nY[plane]+1, sizeof(float));

   for (i=0; i<nX[plane]; i++)
      for (j=0; j<nY[plane]; j++)
         {
         v=world->values[idx_begin+i*sX[plane]+j*sY[plane]];
         if (v>=s_min && v<=s_max)
            {
            if (v<min) min=v;
            if (v>max) max=v;
            sum+=v;
            std_dev+=v*v;
            val[++nb]=v; /* Fill val for sorting */
            }
         }
   if (nb) mean=sum/nb;
         
time(&a);
/*printf("%ld\n",a-b);*/
   if (world->comp_quant)
      {
      /*Sort the elements, put them in val[]*/
      qcksrt(nb,val);
      stat.upper_q=val[(int)((float)nb*.75)];
      stat.median =val[(int)((float)nb*.5)];
      stat.lower_q=val[(int)((float)nb*.25)];
      if (world->quant) free(world->quant);
      world->quant=(float *)calloc(world->nb_class+1, sizeof(float));
      for (i=0; i<world->nb_class+1; i++)
         world->quant[i]=val[(int)(((float)nb*i)/(float)(world->nb_class))];
      world->quant[world->nb_class+1]=world->show_max;
      }
time(&b);
/*printf("%ld\n",b-a);*/
   switch (plane)
     { case X: d='X'; strcpy(p, "yz"); break;
       case Y: d='Y'; strcpy(p, "xz"); break;
       case Z: d='Z'; strcpy(p, "xy"); break; }
   if (plane<3)
      sprintf(stat.name, "Statistics for plane %s, %c=%d",
                        p, d, world->sld[plane]+1);
   else
      sprintf(stat.name, "3D statistics");
   stat.nb       = nb;
   stat.mean     = mean;
   stat.std_dev  = sqrt(std_dev/nb-mean*mean);
   if (stat.std_dev) stat.coef_var = mean/stat.std_dev;
               else stat.coef_var = -10; /* <0 => no display */
   stat.max      = max;
   stat.min      = min;
   free(val);
   return(stat);
   }

void    init_compute(void)        /*F*/
   {
   int          i, j, idx_begin, level, plane, class;

   NewCursor(widgets->win3d_area, XC_watch);
   init_timer("Computing");
   world->nbmax[THREED]=0;
   for (class=0; class<world->nb_class+2; class++)
      world->nbpc[THREED][class]=0;
   for (plane=0; plane<3; plane++)
      {
      world->nbmax[plane]=0;
      for (level=0; level<world->n[plane]; level++)
         {
         idx_begin = level*coeff[plane];
         for (class=0; class<world->nb_class+2; class++)
            {
            world->nbpc[plane][class]=0;
            for (i = 0; i < nX[plane]; i++)
               for (j = 0; j < nY[plane]; j++)
                  {
                  if (world->class_table[idx_begin+i*sX[plane]+j*sY[plane]]
                      ==class)
                     {
                        world->nbpc[plane][class]++;
                     if (!plane)
                        world->nbpc[THREED][class]++;
                     }
                  }
            if (world->nbmax[plane]<world->nbpc[plane][class])
                world->nbmax[plane]=world->nbpc[plane][class];
            if (world->nbmax[THREED]<world->nbpc[THREED][class])
                world->nbmax[THREED]=world->nbpc[THREED][class];
            }
         }
         set_timer((float)(.25*(plane+1)));
      }
   p_area(widgets->debug_area, "STAT -> Computed\n");
   stat_THREED=compute_stat((int)THREED);
   if (widgets->comp_area) display_info(widgets->comp_area);
   }
