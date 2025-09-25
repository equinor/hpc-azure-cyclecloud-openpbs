#!/bin/sh
PROG=$( basename $0 ) 

PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="$( dirname $0 )/../files"

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

# Ignore errors here. Could be that none of these queues exist any more
/opt/pbs/bin/qmgr <<EOF
# Set normal queue as default, then delete workq
# do this as late as possible to avoid collison with chef
set server default_queue = normal
delete queue workq 
delete queue htcq
EOF

for Q in $( /opt/pbs/bin/qstat -Q -f -F json | jq -r ' .Queue| keys[]' )
do
	# h nodes need a default memory requirement
	if [ "${Q#h*}" != "${Q}" ]
	then
		echo "$PROG: qmgr: set queue ${Q} resources_default.mem = 8gb"
		/opt/pbs/bin/qmgr -c "set queue ${Q} resources_default.mem = 8gb"
	fi
done

#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
