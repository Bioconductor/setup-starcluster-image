#!/bin/bash

HOSTNAME=`hostname`
HOSTFILE=/usr/local/etc/hostfile.txt


if [[ $HOSTNAME =~ master$ ]] && [ -f $HOSTFILE ]; then
    mpirun -np 1 --hostfile $HOSTFILE /usr/lib/rstudio-server/bin/rsession "$@"
else
    /usr/lib/rstudio-server/bin/rsession "$@"
fi

