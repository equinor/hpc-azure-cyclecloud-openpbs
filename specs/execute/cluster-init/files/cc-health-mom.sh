#!/bin/bash
#
# CycleCloud health check for nodes missing property tags
#
# More info on https://docs.microsoft.com/en-us/azure/cyclecloud/how-to/healthcheck?view=cyclecloud-8
# 
PROG=$( basename $0 .sh )
HOST=$( hostname -s )
PATH="${PATH}:/opt/pbs/bin:/opt/torque/bin"; export PATH
# syslog settings
LOGFACILITY="local2"
STATEFILE="/tmp/${PROG}-state.txt"

function logprint {
    local LVL="$1"; shift
    echo "${PROG}: $*"
    logger -t ${PROG} -p ${LOGFACILITY}.${LVL} "$*"
}

if pgrep -x pbs_mom >/dev/null
then
    PBSNODES=$(pbsnodes ${HOST} | egrep 'state =|jobs =|slot_type =' )

    LASTSTATE=""
    [[ -r ${STATEFILE} ]] && LASTSTATE=$( cat ${STATEFILE} )
    echo "${PBSNODES}" > ${STATEFILE}

    if  [[ "${PBSNODES}" == *"state ="* ]]
    then
        if  [[ "${PBSNODES}" == *"jobs ="* ]]
        then
            logprint "info" "pbsnodes reported jobs being present - we're OK" 
            exit 0
        fi

        if  [[ "${PBSNODES}" == *"slot_type ="* ]]
        then
            logprint "info" "pbsnodes reported slot type - we're OK" 
            exit 0
        fi

        if  [[ "${LASTSTATE}" == *"slot_type ="* ]]
        then
            logprint "info" "pbsnodes reported slot type at last run - we're OK" 
            exit 0
        fi

        UPMINUTES=$( awk '{ print int($1 / 60) }' /proc/uptime )
        if [[ ${UPMINUTES} -gt 8 ]]
        then
            logprint "err" "pbsnodes reported no slot_type property twice after ${UPMINUTES} minutes uptime. Node to be dismissed" 
            exit 254
        fi
    else
        logprint "warn" "pbsnodes reported no node state - pbs server may be down"
        exit 0
    fi
else
    if [[ -f ${STATEFILE} ]]
    then
        logprint "err" "pbs_mom no longer running. Node to be dismissed"
        exit 254
    else
        logprint "warn" "pbs_mom has not started"
    fi
fi
exit 0

# vim:ts=4:sw=4:shiftwidth=4:softtabstop=4:expandtab
