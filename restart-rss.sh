#!/bin/bash

set -e

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

# only run if hostname is master AND ... (we have not already run...)
if [[ $HOSTNAME =~ master$ ]] && [ ! -f /home/ubuntu/.mpi_is_set_up ] ; then
    # determine master instance type
    MASTER_INSTANCE_TYPE=`curl -s http://169.254.169.254/latest/meta-data/instance-type`
    #export SGE_ROOT=/opt/sge6
    #WORKERS=`/opt/sge6/bin/linux-x64/qhost | egrep -v "^HOSTNAME|^---|^global|master"|cut -f 1 -d ' '`
    #WORKERS=`egrep -v "^#|localhost|^ff|^::" /etc/hosts| cut -d ' ' -f 2 |grep "node"`
    MASTER_NODE_NAME=`grep master /etc/hosts|cut -d ' ' -f 2`
    WORKERS=`grep node /etc/hosts|grep -v allnodes|cut -d ' ' -f 2`
    if [ "WORKERS" ]; then
        FIRST_WORKER=`echo $WORKERS|cut -f 1 -d " "`
        WORKERS_INSTANCE_TYPE=`ssh -t -t $FIRST_WORKER "curl -s http://169.254.169.254/latest/meta-data/instance-type"`
    else
        WORKERS_INSTANCE_TYPE=$MASTER_INSTANCE_TYPE
    fi
    # directory where hostfile.txt resides must be writable
    # by rstudio-server
    HOSTFILE=/usr/local/etc/hostfile.txt
    rm -f $HOSTFILE
    ARG=$MASTER_INSTANCE_TYPE
    get_num_cores
    echo "$MASTER_NODE_NAME slots=$NUM_CORES" > $HOSTFILE
    ARG=$WORKERS_INSTANCE_TYPE
    get_num_cores
    for WORKER in $WORKERS;
    do
        echo "$WORKER slots=$NUM_CORES" >> $HOSTFILE
    done
    chmod 0644 $HOSTFILE
    echo "rsession-path=/usr/local/bin/setup_r_mpi.sh" >> /etc/rstudio/rserver.conf
    cp /home/ubuntu/.mpi/.BatchJobs.R /home/ubuntu
    #mpirun -np 1 --hostfile $HOSTFILE /usr/lib/rstudio-server/bin/rsession "$@"
    echo SGE_ROOT=/opt/sge6 >> /usr/local/lib/R/etc/Renviron.site
    echo SGE_CELL=default >> /usr/local/lib/R/etc/Renviron.site
    echo SGE_CLUSTER_NAME=starcluster >> /usr/local/lib/R/etc/Renviron.site
    echo SGE_EXECD_PORT=63232 >> /usr/local/lib/R/etc/Renviron.site
    echo SGE_QMASTER_PORT=63231 >> /usr/local/lib/R/etc/Renviron.site

    PATH=$PATH:/sbin
    /usr/sbin/rstudio-server restart
    touch /home/ubuntu/.mpi_is_set_up
fi
