#!/bin/sh
set -eu

if Rscript -e 'stopifnot(getRversion() >= "4.6.0")' >/dev/null 2>&1
then
  export R_MAKEVARS_USER="$BISECTRUNK_PROJECT/../Makevars.r46"
fi

R CMD INSTALL \
  --library="$BISECTRUNK_ENV" \
  "$BISECTRUNK_WORKTREE"

R CMD INSTALL \
  --library="$BISECTRUNK_ENV" \
  "$BISECTRUNK_PROJECT/../.sources/ggplot2_4.0.3.tar.gz"
