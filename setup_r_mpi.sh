#!/bin/bash

HOSTNAME=`hostname`

function get_num_cores() {
    case $ARG in
        m3.medium)
            NUM_CORES=1
            ;;
        m3.large)
            NUM_CORES=2
            ;;
        m3.xlarge)
            NUM_CORES=4
            ;;
        m3.2xlarge)
            NUM_CORES=8
            ;;
        c3.large)
            NUM_CORES=2
            ;;
        c3.xlarge)
            NUM_CORES=4
            ;;
        c3.2xlarge)
            NUM_CORES=8
            ;;
        c3.4xlarge)
            NUM_CORES=16
            ;;
        c3.8xlarge)
            NUM_CORES=32
            ;;
        g2.2xlarge)
            NUM_CORES=8
            ;;
        r3.large)
            NUM_CORES=2
            ;;
        r3.2xlarge)
            NUM_CORES=8
            ;;
        r3.4xlarge)
            NUM_CORES=16
            ;;
        r3.8xlarge)
            NUM_CORES=32
            ;;
        i2.xlarge)
            NUM_CORES=4
            ;;
        i2.2xlarge)
            NUM_CORES=8
            ;;
        i2.4xlarge)
            NUM_CORES=16
            ;;
        i2.8xlarge)
            NUM_CORES=32
            ;;
        hs1.8xlarge)
            NUM_CORES=16
            ;;
        t1.micro)
            NUM_CORES=1
            ;;
        m1.small)
            NUM_CORES=1
            ;;
        *)
            NUM_CORES=1
    esac
}

if [ $HOSTNAME == "master" ]; then
    # determine master instance type
    MASTER_INSTANCE_TYPE=`curl -s http://169.254.169.254/latest/meta-data/instance-type`
    #WORKERS=`qhost | egrep -v "^HOSTNAME|^---|^global|^master"|cut -f 1 -d ' '`
    WORKERS=`grep -v "^#" /etc/hosts| cut -d ' ' -f 2 |grep "^node"`
    if [ "WORKERS" ]; then
        FIRST_WORKER=`echo $WORKERS|cut -f 1 -d " "`
        # ssh runs as the rstudio-server user who does not have
        # the right keys to ssh to a worker
        # FIXME - this could maybe be set up in future
        ####WORKERS_INSTANCE_TYPE=`ssh $FIRST_WORKER "curl -s http://169.254.169.254/latest/meta-data/instance-type"`
        # but for now just use the same instance type as master:
        WORKERS_INSTANCE_TYPE=$MASTER_INSTANCE_TYPE
    else
        WORKERS_INSTANCE_TYPE=$MASTER_INSTANCE_TYPE
    fi
    # directory where hostfile.txt resides must be writable
    # by rstudio-server
    HOSTFILE=/usr/lib/rstudio-server/rss-writable/hostfile.txt
    rm -f $HOSTFILE
    ARG=$MASTER_INSTANCE_TYPE
    get_num_cores
    echo "master slots=$NUM_CORES" > $HOSTFILE
    ARG=$WORKERS_INSTANCE_TYPE
    get_num_cores
    for WORKER in $WORKERS;
    do
        echo "$WORKER slots=$NUM_CORES" >> $HOSTFILE
    done

    mpirun -np 1 --hostfile $HOSTFILE /usr/lib/rstudio-server/bin/rsession "$@"
else
    /usr/lib/rstudio-server/bin/rsession "$@"
fi
