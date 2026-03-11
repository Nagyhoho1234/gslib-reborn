/* assert.h: Jinchi Chu, 08/1992 */

#ifndef _ASSERT_H
#define _ASSERT_H 1

#include <stdio.h>

#ifdef DEBUG
#define assert(ex) {if (!(ex)) \
  fprintf(stderr,"Assertion failed: file %s, line %d\n", __FILE__, __LINE__);\
}
/*
#define ASSERT fprintf(stderr,"%3d of %s: ", __LINE__, __FILE__); debug
*/
#define ASSERT fprintf(stderr,"%3d of %s: \n", __LINE__, __FILE__); 
#else
#define assert(ex) ;
#define ASSERT
#endif

#endif /* _ASSERT_H */
