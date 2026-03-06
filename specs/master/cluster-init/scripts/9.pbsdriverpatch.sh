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

SITEPKG=$( /opt/cycle/pbspro/venv/bin/python -c "import sys; print('\n'.join(sys.path))"| grep /venv/lib/ )

for F in ${FILES}/pbspro-driver.py-patch
do
	echo "$PROG: Applying patch ${F} into ${SITEPKG} ..."
	cat "${F}"
	patch -d "${SITEPKG}" -p0 -f < "${F}"
done

#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
