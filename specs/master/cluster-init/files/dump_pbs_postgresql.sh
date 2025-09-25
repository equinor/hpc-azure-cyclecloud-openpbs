#!/bin/bash
#
# Dump entire /var/spool/pbs
#
# Version control in https://github.com/equinor/hpc-azure-cyclecloud.git/projects/pbspro/specs/master/cluster-init/files/
#
##########################################################################################################################
# Dump the postgres databases
#
# Version control in https://github.com/equinor/hpc-azure-cyclecloud.git/projects/pbspro/specs/master/cluster-init/files/
#
# From:
# http://www.postgresql.org/docs/8.1/static/backup.html#BACKUP-DUMP-ALL
#
# 23.1.2. Using pg_dumpall
#
# The above mechanism is cumbersome and inappropriate when backing up an
# entire database cluster. For this reason the pg_dumpall program is provided.
# pg_dumpall backs up each database in a given cluster, and also preserves
# cluster-wide data such as users and groups. The basic usage of this command is:
#
# pg_dumpall > outfile
#
# The resulting dump can be restored with psql:
#
# psql -f infile postgres
#
# (Actually, you can specify any existing database name to start from, but if you
# are reloading in an empty cluster then postgres should generally be used.)
# It is always necessary to have database superuser access when restoring a pg_dumpall dump,
# as that is required to restore the user and group information.
#
#
#
#PATH="/usr/pgsql-9.6/bin:${PATH}"; export PATH

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

if [ -d "/var/lib/openpbs/postgres" ]
then
   DUMPDIR=${1:-"/var/lib/openpbs/postgres"}
else
   DUMPDIR=${1:-"/project/subadmin/backup/azure/pbs/${HOST}/pbs-postgres"}
fi

DATASTORE="/var/spool/pbs/datastore"
PG_DUMPARGS="-p 15007"

YMD=$( date +%Y-%m-%d )

if [ ! -e "${DUMPDIR}" ] 
then
   mkdir -p ${DUMPDIR}
   logprint error "creating dump directory ${DUMPDIR} " 
fi

if [ ! -w "${DUMPDIR}" ] 
then
   logprint error "Cannot write to ${DUMPDIR} as user ${USER}" 
   exit 2
fi

cd ${DATASTORE} || exit 1


DUMPROOT="pgdumpall-${HOST}"
DUMPFILE="${DUMPROOT}-${YMD}.sql"
MAILTO=${MAILTO:-"hrbu@statoil.com"}
#
[ -e ${DUMPDIR}/${DUMPFILE} ]    && /bin/rm -f ${DUMPDIR}/${DUMPFILE}
[ -e ${DUMPDIR}/${DUMPFILE}.gz ] && /bin/rm -f ${DUMPDIR}/${DUMPFILE}.gz
#
pg_dumpall ${PG_DUMPARGS} > ${DUMPDIR}/${DUMPFILE} < /dev/null
err="$?"
if [ "$err" != "0" ]
then
   logprint error "Postgres backup failed on ${HOST}. Error code is $err"
   exit 2
fi

for F in *.conf
do
   [ ! -f ${DUMPDIR}/${HOST}-${F} ] && cp ${F} ${DUMPDIR}/${HOST}-${F}
done

gzip ${DUMPDIR}/${DUMPFILE}
err="$?"
if [ "$err" != "0" ]
then
   logprint error "Postgres backup compression failed on ${HOST}. Error code is $err"
   exit 2
fi

ln -sf ${DUMPFILE}.gz ${DUMPDIR}/latest-${HOST}.gz


#
N=$( ls -1 ${DUMPDIR}/${DUMPROOT}*.gz | wc -l )

#
# Summariza and clean up
#
logprint info "Backup successful. There are $N postgres backupfiles for ${HOST} under ${DUMPDIR}"

if [ ${N} -le "${MINBACKUPS}" ]
then
   logprint warn "Only $N Postgres backupfiles left on ${HOST}"
   exit 0
fi

#
find ${DUMPDIR} -name "${DUMPROOT}*" -mtime +30 -exec /bin/rm {} \;
#
