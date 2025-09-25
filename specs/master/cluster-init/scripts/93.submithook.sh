#!/bin/sh
PROG=$( basename $0 ) 

PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="$( dirname $0 )/../files"
INSTALL_DIR="/opt/cycle/pbspro"

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

echo "$PROG: Copying submit hook files from ${FILES}/ into ${INSTALL_DIR}/"
cp -v ${FILES}/eq_submit_hook.py ${FILES}/eq_submit_hook*.json "${INSTALL_DIR}/"

cd "${INSTALL_DIR}" || exit 2
chmod a+r eq_submit_hook*.json
chmod a+rx eq_submit_hook.py

if [ ! -f "eq_submit_hook.py" ]
then
	echo "$PROG: Exiting. No submit hook in ${INSTALL_DIR}/eq_submit_hook.py. Rename files and install as instructed in the .py files if needed"
	exit 0
fi

/opt/pbs/bin/qmgr -c "list hook eq_submit_hook" >& /dev/null || /opt/pbs/bin/qmgr -c "create hook eq_submit_hook" 
/opt/pbs/bin/qmgr -c "import hook eq_submit_hook application/x-python default eq_submit_hook.py"        # Same python script
/opt/pbs/bin/qmgr -c "import hook eq_submit_hook application/x-config default eq_submit_hook_cc.json"   # _cc.json for CycleCloud
/opt/pbs/bin/qmgr -c "set hook eq_submit_hook event = queuejob"

/opt/pbs/bin/qmgr -c "list hook eq_periodic_hook" >& /dev/null || /opt/pbs/bin/qmgr -c "create hook eq_periodic_hook"
/opt/pbs/bin/qmgr -c "import hook eq_periodic_hook application/x-python default eq_submit_hook.py"      # Same python script
/opt/pbs/bin/qmgr -c "import hook eq_periodic_hook application/x-config default eq_submit_hook_cc.json" # _cc.json for CycleCloud
/opt/pbs/bin/qmgr -c "set hook eq_periodic_hook event = periodic"
/opt/pbs/bin/qmgr -c "set hook eq_periodic_hook freq = 15"


#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
