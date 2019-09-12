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

float strtof(const char *nptr, char **endptr) {
	float retval = 0.0;
	int written = sscanf(nptr, "%f", &retval);
	if(endptr != NULL) {
		*endptr = (char *)nptr + written;
	}
	return retval;
}

double atof(const char *nptr) {
	double retval = 0.0;
	sscanf(nptr, "%lf", &retval);
	return retval;
}