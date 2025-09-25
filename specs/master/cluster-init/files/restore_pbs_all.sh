#!/bin/bash
#
# restore entire /var/spool/pbs
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
   logger -t ${PROG} -p ${LOGFACILITY:-"local2"}.${LVL} $*
}

# function azuremeta {
#    curl -s --noproxy 169.254.169.254 -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2021-05-01" 
# }
# CLUSTERNAME=$( azuremeta | jq -r '.compute.tagsList[] | select(.name | contains("ClusterName")) | .value' )
# SUBSCRIPTIONID=$( azuremeta | jq -r .compute.subscriptionId)
# LOCATION=$( azuremeta | jq -r .compute.location )

# DUMPDIR="/project/subadmin/backup/azure/${SUBSCRIPTIONID}/${LOCATION}/${CLUSTERNAME}/${HOST}/var-spool-pbs"
DUMPDIR="/project/subadmin/backup/azure/pbs/${HOST}/var-spool-pbs"

if [ $( id -u ) != "0" ]
then
    logprint error "Must be run as user root" >&2
    exit 1
fi

[[ -d /opt/torque/bin ]] && export PATH="/opt/torque/bin:/opt/torque/sbin:/opt/maui/bin:${PATH}:/sbin:/usr/sbin:${DIR}"; export PATH
[[ -d /opt/pbs/bin ]]    && export PATH="/opt/pbs/bin:/opt/pbs/sbin:${PATH}:/sbin:/usr/sbin:${DIR}"; export PATH


DATASTORE="/var/spool/pbs"
DUMPFILE="${DUMPDIR}/latest-${HOST}.tar.gz"

#
# Command line options
#
DORESTORE="n"
[ "$1" == "-y" ] && DORESTORE="y" && shift

[ -n "$1" ] && DUMPFILE="$1"

if [ ! -e "${DUMPFILE}" ]
then
    echo "${DUMPFILE}" is missing skipping this stage"
    echo "Usage: ${PROG} [-y] [fullfilename.tar.gz]"
    exit 0
fi


if [ ! -r "${DUMPFILE}" ]
then
    echo "${DUMPFILE}" is not readable - cannot continue"
    echo "Usage: ${PROG} [-y] [fullfilename.tar.gz]"
    exit 0
fi

if [ "${DORESTORE}" != "y" ]
then
    logprint info "Checking backup in ${DUMPFILE}"
    tar -t --checkpoint=.100 -f "${DUMPFILE}" 
    exit $? 
fi

# check for running jobs if pbspro and qstat installed 
if [ -x /opt/pbs/bin/qstat ]
then
    NJOBS=$( /opt/pbs/bin/qstat -a | wc -l )
    if [ "${NJOBS}" != "0" ]
    then
        logprint info "There are running / pending jobs. Cannot continue"
        exit 1
	fi
fi
#
PBSSTATE=$( systemctl is-active pbs ) 
[ "${PBSSTATE}" == "active" ] && logprint info "Stopping pbs service" && systemctl stop pbs 
PBSNEWSTATE=$( systemctl is-active pbs ) 
if [ "${PBSNEWSTATE}" == "inactive" ] 
then
    logprint info "Rename ${DATASTORE} datastore to ${DATASTORE}-$$"
    if mkdir "${DATASTORE}-$$" && cd "${DATASTORE}-$$"
    then
        logprint info "Restore from ${DUMPFILE} into ${DATASTORE}-$$"
        if ! tar -xpf ${DUMPFILE} . 
        then
            logprint error "Restore failed"
            exit 2
        fi
    fi
    if [ -f "${DATASTORE}/pbs_version" -a -f "${DATASTORE}-$$/pbs_version" -a "${DATASTORE}/datastore/PG_VERSION" -a "${DATASTORE}-$$/datastore/PG_VERSION" ] 
    then
        VER_RESTORED=$( cat "${DATASTORE}-$$/pbs_version" )
        VER_ONDISK=$( cat "${DATASTORE}/pbs_version" )
        DB_RESTORED=$( cat "${DATASTORE}-$$/datastore/PG_VERSION" )
        DB_ONDISK=$( cat "${DATASTORE}/datastore/PG_VERSION" )
        if [ "${VER_RESTORED}" = "${VER_ONDISK}" -a "${DB_RESTORED}" = "${DB_ONDISK}" ]
        then 
            logprint info "Backups are from same compatible versions ${VER_ONDISK} in use, ${VER_RESTORED} in backup. Database version is ${DB_RESTORED}. Will activate backup."
            cd /
            mv -v "${DATASTORE}" "${DATASTORE}-orig-$$"
            mv -v "${DATASTORE}-$$" "${DATASTORE}"
            CLEANUP="${DATASTORE}-orig-$$"
        else
            logprint info "Backup is from version ${VER_ONDISK}. System version is ${VER_DATASTORE}"
            logprint info "Will transfer server logs and accounting data only"
            rsync -av "${DATASTORE}-$$/server_logs/" "${DATASTORE}/server_logs/"
            rsync -av "${DATASTORE}-$$/server_priv/accounting/" "${DATASTORE}/server_priv/accounting/"
            CLEANUP="${DATASTORE}-$$"
        fi
    else
        logprint error "Could not find version information from ${DATASTORE}/pbs_version or ${DATASTORE}-$$/pbs_version. No restore is done"
    fi

    [ "${PBSSTATE}" == "active" ] && logprint info "Starting pbs service" && systemctl start pbs 
    [ -n "${CLEANUP}" ] && logprint info "Please clean up ${CLEANUP} when verified OK"
    exit 0
else
    logprint error "pbs service state is ${PBSNEWSTATE} - need to be inactive"
    exit 2
fi
