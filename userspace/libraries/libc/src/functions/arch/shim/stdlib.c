#include <stdio.h>
#include <stdlib.h>

double strtod(const char *nptr, char **endptr) {
	double retval = 0.0;
	int written = sscanf(nptr, "%lf", &retval);
	if(endptr != NULL) {
		*endptr = (char *)nptr + written;
	}
	return retval;
}