#!/bin/bash
PROG=$( basename $0 )
HOST=$( hostname -s )
LOGERR=${LOGERR:-"logger -t ${PROG} -p local2.error"}
LOGOK=${LOGOK:-"logger -t ${PROG} -p local2.info"}
#
# You may substitute PARENT=${CYCLECLOUD_SPEC_PATH:-/prog/util/lib/install/cycleops/cluster-init} 
# or similar if you do not want to depend on /prog/util/lib/install/cycleops/cluster-init being available
#
PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="$( dirname $0 )/../files"
PATH="${PATH}:/opt/pbs/bin:/opt/torque/bin"; export PATH


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

if [ -w /var/spool/pbs/mom_priv/config ]
then
    # Change how out output files are delivered
    sed -i 's|^\$usecp.*|$usecp *:/dev/null /dev/null|' /var/spool/pbs/mom_priv/config 
    # Enable detailed mom debugging
    echo '$logevent 0xffffffff' >> /var/spool/pbs/mom_priv/config
    # Enforce memory limits
    echo '$enforce mem' >> /var/spool/pbs/mom_priv/config
    #
    # restart pbs_mom if running
    #
    if pgrep -x pbs_mom > /dev/null
    then
        echo "$PROG: pbs_mom is running. Reload pbs service for config changes" >&2
        ${LOGOK} "pbs_mom is running. Reload pbs service for config changes"
        pkill -HUP -x pbs_mom
    else
        echo "$PROG: pbs_mom is not running yet - no reload needed" >&2
        ${LOGOK} "pbs_mom is not running yet - no reload needed"
    fi
else
    echo "$PROG: Cannot write to /var/spool/pbs/mom_priv/config" >&2
fi

#
# exit - the rest of the tests are now moved to mom_health
#
exit 0

