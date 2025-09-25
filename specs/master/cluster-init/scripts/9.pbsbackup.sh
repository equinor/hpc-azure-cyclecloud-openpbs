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

echo "$PROG: Adding pbspro postgres DB backup via /etc/cron.d/pbsbackup" 

#
# add cron job
#
echo "3 0 * * * postgres /prog/util/sbin/dump_pbs_postgresql.sh >/dev/null 2>&1" > /etc/cron.d/pbsbackup 

#update postgress backup script
#update postgress backup script if necessary
if ! cmp ${FILES}/dump_pbs_postgresql.sh /prog/util/sbin/dump_pbs_postgresql.sh >/dev/null 2>&1
then
  su markr -g progadm -c "cp ${FILES}/dump_pbs_postgresql.sh /prog/util/sbin/dump_pbs_postgresql.sh" || echo "Could not update dump script - copy failed"
  su markr -g progadm -c "chmod +x /prog/util/sbin/dump_pbs_postgresql.sh" || echo "Could not update dump script permissions"
fi
# Allow pg_dumpall to connect passwordless locally via socket
sed -i '/^local/ s/md5/peer/' /var/spool/pbs/datastore/pg_hba.conf

systemctl restart pbs


#add backup of var-spool-pbs to cron
echo "$PROG: Adding var-spool-pbs backup via /etc/cron.d/pbs-var-spool-bkp" 
echo "2 0 * * *  root /usr/bin/env SYNCUSER='hrbu -g progadm' /prog/util/sbin/dump_pbs_all.sh >/dev/null 2>&1" > /etc/cron.d/pbs-var-spool-bkp

#update backup script
#update backup script if necessary
if ! cmp ${FILES}/dump_pbs_all.sh /prog/util/sbin/dump_pbs_all.sh >/dev/null 2>&1
then
  su markr -g progadm -c "cp ${FILES}/dump_pbs_all.sh /prog/util/sbin/dump_pbs_all.sh" || echo "Could not update dump script - copy failed"
  su markr -g progadm -c "chmod +x /prog/util/sbin/dump_pbs_all.sh" || echo "Could not update dump script permissions"
fi



#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
