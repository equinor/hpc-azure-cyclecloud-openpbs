#!/bin/bash
PROG=$( basename $0 .sh ) 
PARENT="$( dirname $0 )/.."
FILES="${PARENT}/files"

#
# just so we know where this came from 
#
echo "$PROG: Initialized from $0 at `date` as user `id -a`" 

# Add systemd-tmpclean config in case /mnt/scratch exists
cp -v "${FILES}/pbslogs.conf" /etc/tmpfiles.d/

exit 0