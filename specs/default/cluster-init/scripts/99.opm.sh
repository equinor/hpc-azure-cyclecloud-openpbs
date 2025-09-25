#!/bin/sh
PROG=$( basename $0 ) 
DIR=$( dirname $0 )
HOST=$( hostname -s )

#
# You may substitute PARENT=${CYCLECLOUD_SPEC_PATH:-/prog/util/lib/install/cycleops/cluster-init} 
# or similar if you do not want to depend on /prog/util/lib/install/cycleops/cluster-init being available
#
PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="${DIR}/../files"

# if hostname -s | egrep -q 'lc.m$|top[0-9][0-9]|rgs.*[0-9][0-9]'
if hostname -s | egrep -q 'lc.m$'
then
    echo "$PROG: Does not apply to master nodes" 
    exit 0
fi

#
# just so we know where this came from 
#
echo "$PROG: Initialized from $0 at `date` as user `id -a`" 

#
# Keep the below line if root elevation is needed
# 
[ $( id -u ) -ne 0 ] && exec /usr/bin/sudo -n "$0" $* 2>&1

#
# If this is available from shared storage , same basename , run that instead, use the below as fallback
# ... or comment below line if you want to run the below directly
#
[ -x ${SCRIPTS}/${PROG} ] && [ $0 != ${SCRIPTS}/${PROG} ] && exec "${SCRIPTS}/${PROG}" $* 2>&1

CLUSTERNAME=$( /opt/cycle/jetpack/bin/jetpack config cyclecloud.cluster.name )
case "${CLUSTERNAME}" in
    *-ERT-*|*-FMU-*|*-TDP*)
        echo "$PROG: Installing OPM for cluster ${CLUSTERNAME}" 
        cp -v "${FILES}/opm.repo" "/etc/yum.repos.d/"
        yum -y install openblas hdf5-openmpi < /dev/null
        yum -y --disablerepo="*" --enablerepo="opm" install opm-simulators-openmpi-bin libdune-common-openmpi libdune-geometry-openmpi libdune-grid-openmpi libdune-uggrid-openmpi openblas < /dev/null
        ;;
esac

#
# exit 0 - or CycleCloud will retry
#
exit 0
