#include<stdio.h>
#include<math.h>
#include<string.h>
#include "lmc.h"
#define MAXVAR 3
#define EPSLON 1.0e-10
#define MAXNST 4
#define BUFSIZE 256 
#define MXVARG MAXVAR*MAXVAR
#define MXVNST MXVARG*MAXNST+1
#define ABS(x) ((x)>0. ? (x) : (-(x)))
 
int lmc(filename)
char *filename;
{

   FILE *fp;
   char s[BUFSIZE];
   int i,j,istart,ind,index,ie,nvr;
   int nst[MXVARG+1],it[MXVNST];
   float c0[MXVARG+1],aa[MXVNST],cc[MXVNST],ang1[MXVNST];
   float ang2[MXVNST],ang3[MXVNST],anis1[MXVNST];
   float anis2[MXVNST];
 
   int ind1,ind2,ist,index1,index2,istart1,istart2,indexii,indexjj,indexij,indexji;
   float aa1,aa2,temp,temp1,temp2;
   int i2,j2;
   

    int linmod=1;
     int posdef=1;

     for(i=0;i<=MXVARG*MAXNST;i++) {
       aa[i]=0.0;
       cc[i]=0.0;
       ang1[i]=0.0;
       ang2[i]=0.0;
       ang3[i]=0.0;
       anis1[i]=0.0;
       anis2[i]=0.0;
    }
      

 printf("filename=%s\n",filename);
 if((fp=fopen(filename,"r"))==NULL) {
    printf("can not open file \n");
    return FILEERROR;
 }
 
  fgets(s, BUFSIZE, fp);
  if(sscanf (s, "%d", &nvr)<1)
       return FILEFORMAT;
  
  if(nvr>MAXVAR) {
    printf("too many variables\n");
    return VARERROR;
  } 

   for(i=1;i<=nvr;i++) {
     for(j=1;j<=nvr;j++) {
       ind=i+(j-1)*MAXVAR;
       nst[ind]=-1;
     }
  }

   
 while (fgets(s, BUFSIZE, fp)!=NULL){
    if(sscanf (s, "%d %d", &i,&j)<2) 
        return FILEFORMAT;
    ind=i+(j-1)*MAXVAR;
    fgets (s, BUFSIZE, fp);
    if(sscanf (s, "%d %f", &nst[ind],&c0[ind])<1) 
        return FILEFORMAT;

    istart=1+(ind-1)*MAXNST;
    for(i=1;i<=nst[ind];i++) {
      index=istart+i-1;
      fgets (s, BUFSIZE, fp);
      if(sscanf (s, "%d %f %f %f %f", &it[index],&cc[index],&ang1[index],
           &ang2[index],&ang3[index])<1) 
       return FILEFORMAT;
      fgets (s, BUFSIZE, fp);
      if(sscanf (s, "%f %f %f ",&aa[index],&aa1,&aa2)<1)
         return FILEFORMAT;
      anis1[index]=aa1/aa[index];
      anis2[index]=aa2/aa[index];

    }  
 }

 
/* fill in cross variogram */
  
  for(i=1;i<=nvr;i++) {
    for(j=1;j<=nvr;j++) {

      ind1 = i + (j-1)*MAXVAR;
      ind2 = j + (i-1)*MAXVAR;
      if(nst[ind1]==-1 && nst[ind2]==-1) { 
          printf(" Need variogram between variables %d %d\n",i,j);
          return VARIOERROR;
      }
      if(nst[ind1]==-1) {
         nst[ind1] = nst[ind2];
         c0[ind1]  = c0[ind2];
         istart1   = 1 + (ind1-1)*MAXNST;
         istart2   = 1 + (ind2-1)*MAXNST;
         for(ist=1;ist<=nst[ind1];ist++) {
             index2        = istart2 + ist - 1;
             index1        = istart1 + ist - 1;
             it[index1]    = it[index2];
             cc[index1]    = cc[index2];
             aa[index1]    = aa[index2];
             ang1[index1]  = ang1[index2];
             ang2[index1]  = ang2[index2];
             ang3[index1]  = ang3[index2];
             anis1[index1]=anis1[index2];
             anis2[index1]=anis2[index2];

         } 
      }
      if(nst[ind2]==-1) { 
             nst[ind2] = nst[ind1];
             c0[ind2]  = c0[ind1];
             istart1   = 1 + (ind1-1)*MAXNST;
             istart2   = 1 + (ind2-1)*MAXNST;
             for(ist=1;ist<=nst[ind2];ist++) {
                 index2        = istart2 + ist - 1;
                 index1        = istart1 + ist - 1;
                 it[index2]    = it[index1];
                 cc[index2]    = cc[index1];
                 aa[index2]    = aa[index1];
                 ang1[index2]  = ang1[index1];
                 ang2[index2]  = ang2[index1];
                 ang3[index2]  = ang3[index1];
                 anis1[index2]=anis1[index1];
                 anis2[index2]=anis2[index1];
             }
        }
    }
 }



/* check for lmc */
 

     for(i=1;i<=nvr;i++) {
       for(j=1;j<=nvr;j++) {

          ind1=i+(j-1)*MAXVAR;

        for(i2=1;i2<=nvr;i2++) {
          for(j2=1;j2<=nvr;j2++) {

            ind2 = i2 + (j2-1)*MAXVAR; 
            if(nst[ind1]!=nst[ind2])
               linmod=0;
            
            istart1 = 1 + (ind1-1)*MAXNST;
            istart2 = 1 + (ind2-1)*MAXNST;

            for(ist=1;ist<=nst[ind1];ist++) {
              index2=istart2+ist-1;
              index1=istart1+ist-1;
           
               if(it[index1]!=it[index2] 
               || ABS(aa[index1]-aa[index2])>EPSLON 
               || ABS(ang1[index1]  - ang1[index2])>EPSLON
               || ABS(ang2[index1]  - ang2[index2])>EPSLON
               || ABS(ang3[index1]  - ang3[index2])>EPSLON 
               || ABS(anis1[index1] - anis1[index2])>EPSLON
               || ABS(anis2[index1] - anis2[index2])>EPSLON) {
               linmod=0;
              }
            }

          }
        }
      }
   }



   if(linmod) {
      int ii,jj,ij,ji,istartii,istartjj,istartij,istartji;
     
      posdef=1;
      for(i=1;i<=nvr;i++) {
        for(j=1;j<=nvr;j++) {
          if(i!=j) {
              ii = i+(i-1)*MAXVAR;
              jj = j+(j-1)*MAXVAR;
              ij = i+(j-1)*MAXVAR;
              ji = j+(i-1)*MAXVAR;
              istartii = 1 + (ii-1)*MAXNST;
              istartjj = 1 + (jj-1)*MAXNST;
              istartij = 1 + (ij-1)*MAXNST;
              istartji = 1 + (ji-1)*MAXNST;
             
              if(c0[ii]<=0.0 || c0[jj]<=0.0  ||
                   (c0[ii]*c0[jj])<(c0[ij]*c0[ji]) )  {
                        posdef = 0;
                      return NUGGETERROR;
              }
 
              for(ist=1;ist<=nst[ii];ist++) {
                   indexii = istartii + ist - 1;
                    indexjj = istartjj + ist - 1;
                    indexij = istartij + ist - 1;
                    indexji = istartji + ist - 1;
                    if(cc[indexii]<=0.0 || cc[indexjj]<=0.0 ||
                         (cc[indexii]*cc[indexjj])<
                         (cc[indexij]*cc[indexji]) ) { 
                             posdef =0.0;
                             printf("Positive definiteness violation on structure between %d and %d\n",i,j);
                          return STRUCTERROR;
                }
              }
            }
  
            }
          }
       if(!posdef) { 
           printf("The linear model of coregionalization is NOT positive definite!\n");       
      return POSERROR; 
      }
     }
       else { 
         printf("A linear model of coregionalization has NOT been used\n");
         return POSERROR;
      }
  return PRIOR;
}

