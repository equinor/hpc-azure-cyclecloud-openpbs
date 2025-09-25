#!/bin/bash
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
#if [ $( id -u ) -ne 0 -a -x ${SCRIPTS}/${PROG} ]
#then 
#	sudo "${SCRIPTS}/${PROG}" $* && exit 0
#fi


/opt/pbs/bin/qmgr <<EOF
#
# Additional managers
#
set server managers = hrbu@*
set server managers += markr@*
set server managers += kbjo@*
set server managers += root@*
#
# Job history
#
set server job_history_enable=True
EOF
JETPACK="/opt/cycle/jetpack/bin/jetpack"
No_Of_Active_Q=$($JETPACK config pbsqueue 2>&1|wc -l)

declare -a PBSQueues
PBSQueues=(`${JETPACK} config pbsqueue 2>&1|grep pbsqueue | sed -e 's/^[[:space:]]*//'| cut -d ' ' -f1 ` )
# find legal queues name
PBSQueueNames=""
for i in "${PBSQueues[@]}"
do
	cqname=$(${JETPACK} config $i.name 2>&1)
	PBSQueueNames="$PBSQueueNames$cqname "
done

#clean first from any restore debris

all_queues=( $(/opt/pbs/bin/qstat -Q |  cut -d " " -f 1|grep -v Queue|grep -v --  ------- |tr '\n' ' '))

for queue_name in "${all_queues[@]}"
do
        echo "checking queue_name $queue_name"
        qname=$(/opt/pbs/bin/qmgr -c 'p s' |  grep default.slot_type  | grep -w $queue_name |  cut -d " " -f 3)
        slotname=$(/opt/pbs/bin/qmgr -c 'p s' |  grep default.slot_type  | grep -w $queue_name |  cut -d " " -f 6)
	invalid_queue=$( echo "$PBSQueueNames" | grep -w $queue_name > /dev/null 2>&1 ; echo $? )
        if [ "$qname" = "$slotname" ] || [ "$invalid_queue" = 1 ]
        then
                echo "slotname = qname: $qname  or expired qname ....clean it"
                /opt/pbs/bin/qmgr <<EOF
                delete queue ${queue_name}
EOF

        else
                echo "qname: $qname ok"
        fi

done


#declare -a PBSQueues
#PBSQueues=(`${JETPACK} config pbsqueue 2>&1|grep pbsqueue | sed -e 's/^[[:space:]]*//'| cut -d ' ' -f1 ` )
#PBSQueues=$(${JETPACK} config pbsqueue 2>&1|grep pbsqueue | sed -e 's/^[[:space:]]*//'| cut -d ' ' -f1 |xargs )

#do we turn on access control
qacdummy=$(${JETPACK} config cyclecloud.pbs.accesscontrol >/dev/null 2>&1)                   #try and q access control variable
qacset=$?                                                         # did I get a value
if [ "$qacset" -eq "0" ]
then
	qac=$(${JETPACK} config cyclecloud.pbs.accesscontrol 2>&1)                   #try and q access control variable
	qacgroup1=$(${JETPACK} config cyclecloud.pbs.accessgroups 2>&1)                # get access group
	#qacgroup2=$(echo ${qacgroup1// /,})
	qacgroup2=$(echo ${qacgroup1}| tr ' ' ',')                          # convert spaces to commas, shouldnt be necessary
	qacgroup3=$(echo ${qacgroup2}| tr ';' ',')                          # convert semicolon to commas, shouldnt be necessary
	qacgroup=$( echo "${qacgroup3},admin_subadmins" | tr -s ,)          # add subops admin group as legal group and remove double commas etc
fi


for i in "${PBSQueues[@]}"
do
# Create and define queue
#
echo "working on $i"
qname=$(${JETPACK} config $i.name 2>&1)
qplace=$(${JETPACK} config $i.place 2>&1)
qungrouped=$(${JETPACK} config $i.ungrouped 2>&1 | tr [:upper:] [:lower:] )          #convert False to false azure azpbs and pbs dont agree about case 
array=$(echo $i|cut -d "." -f 2)
/opt/pbs/bin/qmgr <<EOF
create queue ${qname}
set queue ${qname} queue_type = Execution
set queue ${qname} resources_default.place = ${qplace}
set queue ${qname} resources_default.slot_type = ${array}
set queue ${qname} resources_default.ungrouped = ${qungrouped}
set queue ${qname} default_chunk.slot_type = ${array}
set queue ${qname} default_chunk.ungrouped = ${qungrouped}
set queue ${qname} enabled = True
set queue ${qname} started = True
EOF
if [ $i = "pbsqueue.q1" ]
then
/opt/pbs/bin/qmgr <<EOF
set server default_queue = ${qname}
EOF
fi
if [ "$qacset" -eq "0" ] 
then
	echo "access control variables set"

	if [ "$qac" = "False" ] || [ "$qacgroup" = "none" ]
	then
		echo "access control disabled"
	else
		echo "access control enabled use obe of these groups $qacgroup"
/opt/pbs/bin/qmgr <<EOF                             # add linux access group to q and enavle
set queue ${qname} acl_groups = "$qacgroup"
set queue ${qname} acl_group_enable = True
EOF
	fi
else
	echo "queue $qname access variables not set"
fi
done

CLUSTERNAME=$( /opt/cycle/jetpack/bin/jetpack config cyclecloud.cluster.name )
HISTORY_DURATION_CHANGE_DUMMY=$(${JETPACK} config cyclecloud.pbs.JobRetentionEnable >/dev/null 2>&1)
history_set=$?
if [ "$history_set" -eq "0" ]
then
	HISTORY_DURATION=$(${JETPACK} config cyclecloud.pbs.JobRetention 2>&1)
	HISTORY_DURATION_CHANGE=$(${JETPACK} config cyclecloud.pbs.JobRetentionEnable 2>&1)
fi
case "${CLUSTERNAME}" in
    *-ERT-*|*-FMU-*)
        /opt/pbs/bin/qmgr -c 'set server job_history_duration = 12:00:00'
        ;;
    *)
	if [ "$history_set" -eq "0" ] 
	then
		if [ "$HISTORY_DURATION_CHANGE" = "True" ]
		then
			/opt/pbs/bin/qmgr -c "set server job_history_duration = $HISTORY_DURATION"
		fi
	fi
	;;
esac

# adjust vm_idle_timeout for cluster

CONFIG_PARAMETER="cyclecloud.pbs.timeout"

VM_IDLE_TIMEOUT_DEFAULT=300

AUTOSCALE_JSON="/opt/cycle/pbspro/autoscale.json"

#JETPACK="/opt/cycle/jetpack/bin/jetpack"

${JETPACK} config ${CONFIG_PARAMETER} > /dev/null 2>&1

if [ "$?" -eq 0 ]; then

        VM_IDLE_TIMEOUT=(`${JETPACK} config ${CONFIG_PARAMETER}` )
#VM_IDLE_TIMEOUT=301  #to test
        echo "TIMEOUT is $VM_IDLE_TIMEOUT"

else
        #use default
        VM_IDLE_TIMEOUT=$VM_IDLE_TIMEOUT_DEFAULT
        echo "Use default $VM_IDLE_TIMEOUT"
fi

if [ "$VM_IDLE_TIMEOUT" -eq "$VM_IDLE_TIMEOUT_DEFAULT" ]; then
        echo "TIMEOUT unchanged : do nothing"
else

        echo "TIMEOUT changed : updating..."
        sed -i 's/\"idle_timeout\":.*/\"idle_timeout\": '${VM_IDLE_TIMEOUT},'/g' "${AUTOSCALE_JSON}"
fi

#
# exit 0 no matter what - or CycleCloud will retry
#
exit 0
