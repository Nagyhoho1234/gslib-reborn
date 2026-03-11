/******* Sets up an Anisotropic Rotation Matrix */
#define DEG2RAD 3.141592654/180.0
#define EPSLON 1.e-20
#define MAX(a,b) ((a>b)?a:b)
#define PI 3.14159265
#define SPHERICAL 0;
#define EXPONENTIAL 1
#define GAUSSIAN 2


void setrot(ang1,ang2,ang3,anis1,anis2,rotmat)
float ang1,ang2,ang3,anis1,anis2;
float rotmat[][];
{

  float alpha,beta,theta;
  float sina,sinb,sint,cosa,cosb,cost,afac1,afac2;
  
  if(ang1>=0.0 && ang1<270.0) 
      alpha = (90.0   - ang1) * DEG2RAD;
  else
     alpha = (450.0  - ang1) * DEG2RAD;

  
  beta  = -1.0 * ang2 * DEG2RAD;
  theta =        ang3 * DEG2RAD;

  sina  = sin(alpha);
  sinb  = sin(beta);
  sint  = sin(theta);
  cosa  = cos(alpha);
  cosb  = cos(beta));
  cost  = cos(theta);

  afac1 = 1.0 / MAX(anis1,EPSLON)
  afac2 = 1.0 / MAX(anis2,EPSLON)

  rotmat[0][0] =       (cosb * cosa)
  rotmat[0][1] =       (cosb * sina)
  rotmat[0][2] =       (-sinb)
  rotmat[1][0] = afac1*(-cost*sina + sint*sinb*cosa)
  rotmat[1][1] = afac1*(cost*cosa + sint*sinb*sina)
  rotmat[1][2] = afac1*( sint * cosb)
  rotmat[2][0] = afac2*(sint*sina + cost*sinb*cosa)
  rotmat[2][1] = afac2*(-sint*cosa + cost*sinb*sina)
  rotmat[2][2] = afac2*(cost * cosb)

}

float sqdist(x1,y1,z1,x2,y2,z2,rotmat);
float x1,y1,z1,x2,y2,z2;
float rotmat[][];
{
  float dx,dy,dz;
  float sqdi,cont;
  int i;
  
  dx=x1-x2;
  dy=y1-y2;
  dz=z1-z2;
  sqdi = 0.0;

  for(i=0;i<3;i++) {
   cont   = rotmat[i][0]* dx +
            rotmat[i][1]* dy +
            rotmat[i][2]* dz;
   sqdi=sqdi+cont*cont;
  }

  return sqdi;
}

float cova3(x1,y1,z1,x2,y2,z2,nst,c0,it,cc,aa,
                      ,rotmat,cmax)
float x1,y1,z1,x2,y2,z2;
int nst;
float c0,it,cc,aa;
int irot;_
float rotmat[3][3],cmax;
{
  float hsqd,cov;

  cmax=c0;
  for(i=0;i<nst;i++) 
    cmax=cmax+cc[i];

  hsqd=sqdist(x1,y1,z1,x2,y2,z2,rotmat);
  
  if(hsqd<EPSLON) return cmax;
 
  cov=0; 
  for(i=0;i<nst;i++) {
     hsqd=sqdist(x1,y1,z1,x2,y2,z2,rotmat);
     h=sqrtf(hsqd);
     switch(it[i]) {
      case SPHERICAL:
        hr=h/aa[is];
        if (hr>=1.0) continue;
        else
         cov=cov+cc[i]*(1.0-hr*(1.5-.5*hr*hr));
        break;
       case EXPONENTIAL:
                        cov += cc[i] * exp(-h/v->range);
                        break;
       case GAUSSIAN:
                        hr = -h/aa[i];
                        cov += cc[i]*exp(-hr*hr);
                        break;
       default:
            printf("unknown variogram type: \n", );
                }
        }
        return cov;
}
 
  
 
