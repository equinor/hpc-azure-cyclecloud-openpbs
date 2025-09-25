#!/bin/sh
PROG=$( basename $0 )

PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="${PARENT}/files"

#
# just so we know where this came from
#
echo "$PROG: Initialized from $0 at `date` as user `id -a`"

#
# If this is available from shared storage , same basename , run that instead, use the below as fallback
#
if [ $( id -u ) -ne 0 -a -x ${SCRIPTS}/${PROG} ]
then
	sudo "${SCRIPTS}/${PROG}" $* && exit 0
fi

echo "$PROG: Continuing as user $( id -u )"
echo "$PROG: Starting x2g0"
sudo yum -y install epel-release
sudo yum -y install x2goserver-xsession
sudo yum -y groupinstall "Xfce"
sudo yum -y groupinstall "General Purpose Desktop" # not in RHEL 9
sudo yum -y groupinstall "MATE Desktop"            # not in RHEL 9

#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0