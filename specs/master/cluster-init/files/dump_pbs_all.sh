#!/bin/bash
#
# Dump entire /var/spool/pbs
#
# Version control in https://github.com/equinor/hpc-azure-cyclecloud.git/projects/pbspro/specs/master/cluster-init/files/
#

PROG=$( basename $0 )
HOST=$( hostname -s )
MINBACKUPS=5
LOGFACILITY="local2"

function logprint {
   local LVL="$1"
   shift
   echo "${PROG}: $*" # >&2
   logger -t ${PROG} -p ${LOGFACILITY:-"local2"}.${LVL} "$@"
}

if [ $( id -u ) != "0" ]
then
    logprint error "Must be run as user root" >&2
    exit 1
fi

[ "$1" = "-F" ] && shift && NOBUSY="y"

[[ -d /opt/torque/bin ]] && export PATH="/opt/torque/bin:/opt/torque/sbin:/opt/maui/bin:${PATH}:/sbin:/usr/sbin:${DIR}"; export PATH
[[ -d /opt/pbs/bin ]]    && export PATH="/opt/pbs/bin:/opt/pbs/sbin:${PATH}:/sbin:/usr/sbin:${DIR}"; export PATH

if [ -d "/var/lib/openpbs/spool" ]
then
    DUMPDIR=${1:-"/var/lib/openpbs/spool"}
    SYNCDIR=${2:-"/project/subadmin/backup/onsite/pbs/${HOST}/var-spool-pbs"}
else
    DUMPDIR=${1:-"/mnt/resource/backups/var-spool-pbs"}
    SYNCDIR=${2:-"/project/subadmin/backup/azure/pbs/${HOST}/var-spool-pbs"}
fi

DATASTORE="/var/spool/pbs/"

YMD=$( date +%Y-%m-%d )

if [ ! -e "${DUMPDIR}" ]
then
   logprint error "${DUMPDIR} does not exist. Will attempt to create."
   mkdir -p ${DUMPDIR}
fi

if [ ! -w "${DUMPDIR}" ] 
then
   logprint error "Cannot write to ${DUMPDIR} as user ${USER}" 
   exit 2
fi

NNODES=$( pbsnodes -a |& egrep -c "state = job" )
if [ ${NNODES} -gt 0 ]
then
    if [ -n "${NOBUSY}" ]
    then
        logprint error "Cluster has ${NNODES} nodes with jobs. No backup done from a busy system when -F option in use"
        exit 1
    else
        logprint warn "Cluster has ${NNODES} nodes with jobs. Using this backup may have some side effects"
    fi
fi

cd ${DATASTORE} || exit 1
DUMPROOT="pbsdump-${HOST}"
DUMPFILE="${DUMPROOT}-${YMD}.tar.gz"
MAILTO=${MAILTO:-"hrbu@statoil.com"}
#
[ -e ${DUMPDIR}/${DUMPFILE} ] && /bin/rm -f ${DUMPDIR}/${DUMPFILE}
#
PBSSTATE=$( systemctl is-active pbs ) 
[ "${PBSSTATE}" == "active" ] && logprint info "Stopping pbs service" && systemctl stop pbs 
PBSNEWSTATE=$( systemctl is-active pbs ) 
if [ "${PBSNEWSTATE}" == "inactive" ] 
then
    logprint info "Back up to ${DUMPDIR}/${DUMPFILE}"
    if ! tar --exclude "./server_logs/*" --exclude "./comm_logs/*" --exclude "./sched_logs/*" -czf ${DUMPDIR}/${DUMPFILE} . 
    then
       logprint error "Backup failed on ${HOST}. Error code is $err"
       exit 2
    fi
    ln -sf ${DUMPFILE} ${DUMPDIR}/latest-${HOST}.tar.gz
    logprint info "Backup completed for ${DUMPFILE}"
    [ "${PBSSTATE}" == "active" ] && logprint info "Starting pbs service" && systemctl start pbs 
    if [ -n "${SYNCUSER}" ]
    then
        logprint info "Syncing backups to ${SYNCDIR}"
	    su ${SYNCUSER} -c "mkdir -p ${SYNCDIR} && rsync --no-times --no-owner --no-group --no-perms -aHv ${DUMPDIR}/ ${SYNCDIR}/"
        exit $? 
    else
        logprint info "No SYNCUSER defined in environment. Please do a manual rsync --no-times --no-owner --no-group --no-perms -aHv ${DUMPDIR}/ ${SYNCDIR}/"
	exit 1
    fi
else
    logprint error "pbs service state is ${PBSNEWSTATE} - need to be inactive"
    exit 2
fi

