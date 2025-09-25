#!/bin/sh
PROG=$( basename $0 ) 

PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="$( dirname $0 )/../files"
HOST="$( hostname -s )"

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

for F in ${FILES}/*.patch
do
	echo "$PROG: Applying patch ${F} ..."
	cat "${F}"
	patch -d/ -p0 -f < "${F}"
done

case "${HOST}" in
	s*-lc[djgh]m)
		echo "$PROG: No overallocation for < 20 nodes in" /opt/cycle/pbspro/venv/lib/python*/site-packages/hpc/autoscale/job/job.py
		sed -i 's/= node_count + 1/= node_count/' /opt/cycle/pbspro/venv/lib/python*/site-packages/hpc/autoscale/job/job.py
		;;
esac

#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
