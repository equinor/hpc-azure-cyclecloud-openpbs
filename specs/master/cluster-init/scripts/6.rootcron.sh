#!/bin/sh
PROG=$( basename $0 ) 

PARENT="/prog/util/lib/install/cycleops/cluster-init"
SCRIPTS="${PARENT}/scripts"
FILES="$( dirname $0 )/../files"
HOST=$( hostname -s )

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

echo "$PROG: Adding healtchkpbs to /etc/cron.d/healtchkpbs"
echo '*/3 * * * * root /prog/util/sbin/healthchkpbs >/dev/null 2>&1' > /etc/cron.d/healtchkpbs 

echo "$PROG: Adding pbscollect to /etc/cron.d/pbscollect"
echo '*/1 * * * * hrbu ${HOME}/bin/pbscollectcsv -c ${HOME}/.pbscollectcsv/sNNNN-XXXX > /tmp/pbscollectcsv.log 2>&1' | \
	sed "s/sNNNN-XXXX/${HOST}/g" > /etc/cron.d/pbscollect

echo "$PROG: Adding pbscollect to /etc/cron.d/pbsqstats"
echo '1 * * * * hrbu env STATSFILE="${HOME}/.pbscollectcsv/sNNNN-XXXX/queuestats.csv" INFLUXDBURL="http://unix-grafana.equinor.com:8086" INFLUXDBNAME="pbsstats" CLUSTER="sNNNN-XXXX" $HOME/bin/croncsvinflux > /tmp/croncsvinflux.log 2>&1' | \
	sed "s/sNNNN-XXXX/${HOST}/g" > /etc/cron.d/pbsqstats
