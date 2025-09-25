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





#
# exit 0 no matter what - or CycleCloud will retry
#



# install epilog script
if [ ! -f "${INSTALL_DIR}/epilogue" ]
then
	cp ${FILES}/epilogue  ${EPILOG_DIR}
	chown root ${EPILOG_DIR}/epilogue
	chmod 744 ${EPILOG_DIR}/epilogue
fi
exit 0
