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

[ -z "${LABEL}" ] && echo "${PROG}: No 'label = ' in project section project.ini ?" >&2 && exit 2
[ -z "${FILES}" ] && echo "${PROG}: No 'Files = ' in blobs section in project.ini ?" >&2 && exit 2

mkdir -p blobs 
for F in ${FILES}
do 
    echo -n "Get $F ... "
    if wget -q -O "blobs/.tmp-$$-${F}" "${BASEURL}/cyclecloud-${LABEL}-blobs/${F}"
    then
        mv -f "blobs/.tmp-$$-${F}" "blobs/${F}" && echo "OK"
    else
        echo "FAILED"
        FAILED="${FAILED} ${F}"
    fi
done

if [ -z "${FAILED}" ]
then
    if [ "$1" = "-u" ]
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
