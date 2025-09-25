#
# Stop pbs
# 
systemctl stop pbs

# Upgrade - do not start
rpm -Uhv https://st-rhsm.st.statoil.no/pub/subops/openpbs/openpbs-server-22.05.11-0-el8.x86_64.rpm
or
rpm -Uhv https://st-rhsm.st.statoil.no/pub/subops/openpbs/openpbs-server-22.05.11-0.x86_64.rpm

# Update database - original script in /opt/pbs/libexec/pbs_schema_upgrade 
export PBS_DATA_SERVICE_PORT=15007
export PBS_DATA_SERVICE_USER=postgres
set -a
source /etc/pbs.conf
set +a
bash -x /prog/util/sbin/pbs_schema_upgrade_22.05.11 

# Create a new latest version of the /var/spool/pbs backup as in  /etc/cron.d/pbs-var-spool-bkp
/usr/bin/env SYNCUSER='hrbu -g progadm' bash -x /prog/util/sbin/dump_pbs_all.sh

# stop cluster / update settings to 2022.05.11

# Start cluster .....


# Example schema upgrade result:

# bash -x /prog/util/sbin/pbs_schema_upgrade_22.05.11
+ . /opt/pbs/libexec/pbs_db_env
++ PGSQL_LIBSTR=
++ '[' -z /opt/pbs ']'
++ '[' -d /opt/pbs/pgsql ']'
+++ type psql
+++ cut '-d ' -f3
++ PGSQL_CMD=/bin/psql
++ '[' -z /bin/psql ']'
+++ type pg_config
+++ cut '-d ' -f3
++ PGSQL_CONF=/bin/pg_config
++ '[' -z /bin/pg_config ']'
+++ /bin/pg_config
+++ awk '/BINDIR/{ print $3 }'
++ PGSQL_BIN=/usr/bin
+++ dirname /usr/bin
++ PGSQL_DIR=/usr
++ '[' /usr = / ']'
++ export PGSQL_BIN=/usr/bin
++ PGSQL_BIN=/usr/bin
++ '[' -d /opt/pbs/lib ']'
++ LD_LIBRARY_PATH=/opt/pbs/lib:
++ export LD_LIBRARY_PATH
+ tmpdir=/var/tmp
+ PBS_CURRENT_SCHEMA_VER=1.5.0
+ outfile=/var/tmp/pbs_dataservice_output_31426
+ /opt/pbs/sbin/pbs_dataservice status
+ '[' 0 -eq 0 ']'
+ /opt/pbs/sbin/pbs_dataservice stop
+ '[' 0 -ne 0 ']'
+ ret=0
+ '[' 0 -ne 0 ']'
+ /opt/pbs/sbin/pbs_dataservice start
+ '[' 0 -ne 0 ']'
+ rm -f /var/tmp/pbs_dataservice_output_31426
++ sudo -u postgres /usr/bin/psql -A -t -p 15007 -d pbs_datastore -U postgres -c 'select pbs_schema_version from pbs.info'
could not change directory to "/root"
+ ver=1.4.0
+ '[' 1.4.0 = 1.5.0 ']'
+ '[' 1.4.0 = 1.0.0 ']'
+ /opt/pbs/sbin/pbs_dataservice status
+ '[' 0 -eq 1 ']'
+ '[' 1.4.0 = 1.1.0 ']'
+ '[' 1.4.0 = 1.2.0 ']'
+ '[' 1.4.0 = 1.3.0 ']'
+ '[' 1.4.0 = 1.4.0 ']'
+ upgrade_pbs_schema_from_v1_4_0
+ sudo -u postgres /usr/bin/psql -p 15007 -d pbs_datastore -U postgres
could not change directory to "/root"
+ ret=0
+ '[' 0 -ne 0 ']'
+ ret=0
+ '[' 0 -ne 0 ']'
+ ver=1.5.0
+ /opt/pbs/sbin/pbs_dataservice status
+ '[' 0 -eq 1 ']'
+ rm -f /var/tmp/pbs_dataservice_output_31426
+ /opt/pbs/sbin/pbs_dataservice stop
+ ret=0
+ exit 0
