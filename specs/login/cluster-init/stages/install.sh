#!/bin/bash

source "${CYCLECLOUD_PROJECT_PATH}/default/files/utils.sh" || exit 1
source "${CYCLECLOUD_PROJECT_PATH}/default/files/default.sh" || fail

"${CYCLECLOUD_PROJECT_PATH}/default/scripts/hwlocs-install.sh" || fail

PACKAGE_NAME=$(get_package_name "client") || fail
SERVER_HOSTNAME=$(get_server_hostname) || fail

for P in cjson chkconfig
do
    rpm -q "$P" && continue
    echo "Install missing prereq $P ..."
    sed -i '/proxy-swe/ s/#proxy=/proxy=/' /etc/yum.conf
    dnf install -y --enablerepo=epel "$P"
done

if rpm -q "$PACKAGE_NAME"
then
    echo "$PACKAGE_NAME is already installed - no download/install needed"
else
    jetpack download --project pbspro "$PACKAGE_NAME" "/tmp" || fail
    # Equinor repo may have older / conflicting versions
    dnf install --disablerepo="equinor*"  -y -q "/tmp/$PACKAGE_NAME" || fail
fi

if [[ -n "$SERVER_HOSTNAME" ]]; then
    sed -e "s|__SERVERNAME__|${SERVER_HOSTNAME}|g" \
        "${CYCLECLOUD_PROJECT_PATH}/default/templates/default/pbs.conf.template" > /etc/pbs.conf || fail
    chmod 0644 /etc/pbs.conf || fail
fi

# Not needed. Login nodes have no daemons: /opt/pbs/bin/qmgr -c "set server flatuid=true" || fail
