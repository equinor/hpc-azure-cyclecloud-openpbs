#!/bin/sh
PROG=$( basename $0 ) 
HOST=$( hostname -s )

IDLE_TIMEOUT="1800" # maybe we make it a cluster config item one day

#
# There is this in jetpack config, but not sure where they can be set:
#   cyclecloud.cluster.autoscale.idle_time_after_jobs  = 300
#   cyclecloud.cluster.autoscale.idle_time_before_jobs = 1800

#
# just so we know where this came from 
#
echo "$PROG: Initialized from $0 at `date` as user `id -a`" 

#
# Keep the below line if root elevation is needed
# 
[ $( id -u ) -ne 0 ] && exec /usr/bin/sudo -n "$0" $* 2>&1

#
# CycleCloud cluster naming standard will tell you node role, location, usage, scheduler and more ... 
#
if [ -x /opt/cycle/jetpack/bin/jetpack ]
then
    CLUSTERNAME=$( /opt/cycle/jetpack/bin/jetpack config cyclecloud.cluster.name ) 
    echo "$PROG: Cluster name from jetpack config is ${CLUSTERNAME}"
else
    CLUSTERNAME=""
    echo "$PROG: Not a CycleCloud cluster node"
fi

case "${CLUSTERNAME}" in
      *-FMU-*)
            echo "$PROG: Change idle_timeout to ${IDLE_TIMEOUT} (/opt/cycle/pbspro/autoscale.json)"
            sed -i "s/\"idle_timeout\": .*/\"idle_timeout\": ${IDLE_TIMEOUT},/" /opt/cycle/pbspro/autoscale.json
            ;;
esac

exit 0
