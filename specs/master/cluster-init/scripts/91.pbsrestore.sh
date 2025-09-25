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


# update backup script if necessary
echo "Update /prog/util/sbin/restore_pbs_all.sh manually, if needed"
# echo "check if /prog/util/sbin/restore_pbs_all.sh needs updating"
# if ! cmp ${FILES}/restore_pbs_all.sh /prog/util/sbin/restore_pbs_all.sh >/dev/null 2>&1
# then
#   echo "update /prog/util/sbin/restore_pbs_all.sh ${FILES}/restore_pbs_all.sh is newer"
#   su  markr -g progadm -c "cp ${FILES}/restore_pbs_all.sh /prog/util/sbin/restore_pbs_all.sh" || echo "couldnt update restore script"
#   su  markr -g progadm -c "chmod +x /prog/util/sbin/restore_pbs_all.sh" || echo "couldnt set access on new resore script"
# fi

#use restore script in files
if ! /prog/util/sbin/restore_pbs_all.sh -y
then
       echo "PBS restore failed on ${HOST}. Error code is $err"
       exit 0
fi



#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
