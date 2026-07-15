#include <Rinternals.h>

SEXP Rf_findVarInFrame3(SEXP rho, SEXP symbol, Rboolean do_get);
SEXP PRVALUE(SEXP promise);
void SET_PRVALUE(SEXP promise, SEXP value);
void SET_PRCODE(SEXP promise, SEXP code);
void SET_PRENV(SEXP promise, SEXP environment);
