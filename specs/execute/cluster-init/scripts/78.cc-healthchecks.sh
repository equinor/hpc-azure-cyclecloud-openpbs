#!/bin/sh
PROG=$( basename $0 ) 
DIR=$( dirname $0 )

#
# You may substitute PARENT=${CYCLECLOUD_SPEC_PATH:-/prog/util/lib/install/cycleops/cluster-init} 
# or similar if you do not want to depend on /prog/util/lib/install/cycleops/cluster-init being available
#
PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="${DIR}/../files"
DESTDIR="/opt/cycle/jetpack/config/healthcheck.d/"

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


for SCRIPT in ${FILES}/cc-health-*.sh
do
	echo "$PROG: Installing from ${SCRIPT} to ${DESTDIR}/"
	cp -v "${SCRIPT}" "${DESTDIR}/"
done
chmod -v a+rx ${DESTDIR}/cc-health-*.sh

#
# Change test interval to 5 minutes if possible
# ... comment this section if done before
#
# if [ -w "/etc/systemd/system/healthcheck.service" ]
# then
# 	sed -i 's/Environment=INTERVAL=.*/Environment=INTERVAL=5/' /etc/systemd/system/healthcheck.service
# 	systemctl daemon-reload
# 	systemctl restart healthcheck 
# fi

#
# exit 0 - or CycleCloud will retry
#
exit 0
