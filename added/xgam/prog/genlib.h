
/* Type: bool                                                  */
/* ----------------------------------------------------------- */
/* This type has two values, FALSE and TRUE, which are equal   */
/* to 0 and 1 respectively.  Most of the advantage of defining */
/* this type comes from readability, because it allows the     */
/* programmer to provide documentation that a value will       */
/* take on only one of these two values.                       */
/***************************************************************/

/* On Alpha, we have to undefine TRUE and FALSE first, -jc */
#ifdef FALSE
#undef FALSE
#endif
#ifdef TRUE
#undef TRUE
#endif

#ifdef(THINK_C)
   typedef Boolean bool;
#else
   typedef enum {FALSE, TRUE} bool;
#endif


