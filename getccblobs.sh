#!/bin/bash
PROG=$( basename $0 .sh )
BASEURL="https://scp-repo.equinor.com:443/artifactory/scp-linux-gen-elx-prod"

if [ ! -r project.ini ]
then
   echo "$PROG: No project.ini file in $PWD" >&2
   exit 2
fi

LABEL=$( sed -n '/^\[project/,/^$/ s/^label = //p' project.ini | tr '[:upper:]' '[:lower:]' )
FILES=$( sed -n -e 's/,//g' -e '/^\[blobs/,/^$/ s/^Files = //p' project.ini )
DOWNLOADED=""

[ -z "${LABEL}" ] && echo "${PROG}: No 'label = ' in project section project.ini ?" >&2 && exit 2
[ -z "${FILES}" ] && echo "${PROG}: No 'Files = ' in blobs section in project.ini ?" >&2 && exit 2

mkdir -p blobs 
for F in ${FILES}
do 
    [ -s "blobs/${F}" ] && echo "${PROG}: blobs/${F} already in place. If you want to update, please delete." && continue
    echo -n "${PROG}: Get $F ... "
    if wget -q -O "blobs/.tmp-$$-${F}" "${BASEURL}/cyclecloud-${LABEL}-blobs/${F}"
    then
        mv -f "blobs/.tmp-$$-${F}" "blobs/${F}" && echo "OK"
        DOWNLOADED="${DOWNLOADED} ${F}" 
    else
        echo "FAILED"
        FAILED="${FAILED} ${F}"
    fi
done

if [ -z "${FAILED}" ]
then
    if [ -z "${DOWNLOADED}" ]
    then
        echo "${PROG}: No downloads - all there. No further action should be needed"
        exit 0
    fi
    if [ "$1" != "-n" ]
    then
        echo -ne "\n${PROG}: All done. Now uploading ...\n\n"
        cyclecloud project upload azure-storage
        exit $?
    else
        echo -ne "\n${PROG}: All done. For upload do:\n    cyclecloud project upload azure-storage\n"
        exit 0
    fi
fi

echo "${PROG}: The following files failed: ${FAILED}" 
exit 2
