#!/bin/bash
PROG=$( basename $0 .sh )
BASEURL="https://scp-repo.equinor.com:443/artifactory/scp-linux-gen-elx-prod"

if [ ! -r project.ini ]
then
   echo "$PROG: No project.ini file in $PWD" >&2
   exit 2
fi

LABEL=$( grep -A5 '^\[project' project.ini | sed -n 's/^label = //p' | tr '[:upper:]' '[:lower:]' )
FILES=$( grep -A2 '^\[files'   project.ini | sed -n -e 's/,//g' -e 's/^Files = //p'  project.ini )

[ -z "${LABEL}" ] && echo "${PROG}: No 'label = ' in project.init ?" >&2 && exit 2
[ -z "${FILES}" ] && echo "${PROG}: No 'Files = ' in project.init ?" >&2 && exit 2

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

[ -z "${FAILED}" ] && exit 0

echo "${PROG}: The following files failed: ${FAILED}" 
exit 2
