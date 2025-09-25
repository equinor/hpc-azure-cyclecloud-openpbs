#!/bin/sh
PROG=$( basename $0 ) 

PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="$( dirname $0 )/../files"
INSTALL_DIR="/opt/cycle/pbspro"
EPILOG_DIR="/var/spool/pbs/mom_priv"


if [[ ! -e ${INSTALL_DIR} ]]; then
	mkdir -p ${INSTALL_DIR}
fi

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

echo "$PROG: Copying epilog/prolog hook files from ${FILES}/ into ${INSTALL_DIR}/"
cp -v ${FILES}/run_pelog_shell.py ${FILES}/run_pelog_shell.ini $INSTALL_DIR/
chmod a+r $INSTALL_DIR/run_pelog_shell.ini
chmod a+rx $INSTALL_DIR/run_pelog_shell.py

if [ ! -f "${INSTALL_DIR}/run_pelog_shell.py" ]
then
	echo "$PROG: Exiting. No epilog hook enabled in ${INSTALL_DIR}/run_pelog_shell.py. Rename files and install as instructed in the .py files if needed"
	exit 0
fi



/opt/pbs/bin/qmgr << EOF
create hook run_prologue_shell
set hook run_prologue_shell event = execjob_prologue
set hook run_prologue_shell enabled = true
set hook run_prologue_shell order = 1
set hook run_prologue_shell alarm = 35
import hook run_prologue_shell application/x-python default ${INSTALL_DIR}/run_pelog_shell.py
import hook run_prologue_shell application/x-config default ${INSTALL_DIR}/run_pelog_shell.ini

create hook run_epilogue_shell
set hook run_epilogue_shell event = execjob_epilogue
set hook run_epilogue_shell enabled = true
set hook run_epilogue_shell order = 999
set hook run_prologue_shell alarm = 35
import hook run_epilogue_shell application/x-python default ${INSTALL_DIR}/run_pelog_shell.py
import hook run_epilogue_shell application/x-config default ${INSTALL_DIR}/run_pelog_shell.ini
EOF


#
# exit 0 no matter what - or CycleCloud will retry
#



exit 0
