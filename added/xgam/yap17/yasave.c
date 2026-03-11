
#include <stdio.h>
#include "yap.h"

extern World_t *world;

static BOOLEAN     gsl_save(char           *name)  /*F*/
   {
   int             i;
   FILE           *file = fopen(name, "w");

   if (!file) return (FALSE);
   fprintf(file, "%s\n", world->title);
   fprintf(file, "1 %d %d %d\n%s\n", world->n[X], world->n[Y], world->n[Z],
                                     world->var_name);
   for (i=0; i<world->nb_data; i++) fprintf(file, "%g\n", world->values[i]);
   fclose(file);
   return (TRUE);
   }

static BOOLEAN     fbin_save(char          *name)  /*F*/
   {
   int             magic = FMAGIC;
   FILE           *file = fopen(name, "wb");

   if (!file)
      return (FALSE);
   fwrite(&magic, sizeof(int), 1, file);
   fwrite(world->title, sizeof(world->title), 1, file);
   fwrite(world->var_name, sizeof(world->var_name), 1, file);
   fwrite(&world->min, sizeof(world->min), 1, file);
   fwrite(&world->max, sizeof(world->max), 1, file);
   fwrite(world->n, sizeof(world->n), 1, file);
   world->nb_saved = 1;
   fwrite(&world->nb_saved, sizeof(int), 1, file);
   fwrite(world->values, world->nb_data * sizeof(float), 1, file);
   fclose(file);
   return (TRUE);
   }

static BOOLEAN     class_save(char          *name)  /*F*/
   {
   int             magic = CMAGIC;
   float           min, max;
   FILE           *file = fopen(name, "wb");

   if (!file) return (FALSE);

   min=1; max=world->nb_class;
   fwrite(&magic, sizeof(int), 1, file);
   fwrite(world->title, sizeof(world->title), 1, file);
   fwrite(world->var_name, sizeof(world->var_name), 1, file);
   fwrite(&min, sizeof(min), 1, file);
   fwrite(&max, sizeof(max), 1, file);
   fwrite(world->n, sizeof(world->n), 1, file);
   world->nb_saved = 1;
   fwrite(&world->nb_saved, sizeof(int), 1, file);
   fwrite(world->class_table, world->nb_data * sizeof(char), 1, file);
   fclose(file);
   return (TRUE);
   }

static BOOLEAN     cbin_save(char          *name)  /*F*/
   {
   int             i, magic = CMAGIC;
   FILE           *file = fopen(name, "wb");
   char           *tmp_val;

   if (!file) return (FALSE);
   tmp_val=(char *)calloc(world->nb_data, sizeof(char));
   for (i=0; i<world->nb_data; i++) tmp_val[i]=(char)world->values[i];

   fwrite(&magic, sizeof(int), 1, file);
   fwrite(world->title, sizeof(world->title), 1, file);
   fwrite(world->var_name, sizeof(world->var_name), 1, file);
   fwrite(&world->min, sizeof(world->min), 1, file);
   fwrite(&world->max, sizeof(world->max), 1, file);
   fwrite(world->n, sizeof(world->n), 1, file);
   world->nb_saved = 1;
   fwrite(&world->nb_saved, sizeof(int), 1, file);
   fwrite(tmp_val, world->nb_data * sizeof(char), 1, file);
   fclose(file);
   free(tmp_val);
   return (TRUE);
   }

BOOLEAN         file_save(char          *name,  /*F*/
                          int            type)  /*F*/
   {
   switch (type)
      {
   case GSLIB:    return (gsl_save(name));
   case FBINARY:  return (fbin_save(name));
   case CBINARY:  return (cbin_save(name));
   case CLASSBIN: return (class_save(name));
   default:       return (FALSE);
      }
   }
