float nugget();
float spherical();
float exponential();
float gaussian();
float power();

typedef struct {
	char *name;
	float (*func)();
} FUNC;

extern FUNC func_info[];

