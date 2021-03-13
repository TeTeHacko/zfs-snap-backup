#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# This script can be used as nagios/icinga check script

# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/config.sh

host=${1:-localhost}
time=${2:-1440}

last_snap=$(ls ${MOUNT_DIR}/${host}/.snapshots/ 2>/dev/null |tail -n 1)
running_rsyncs=$(ps aux|grep [r]sync | fgrep $host|wc -l)
test -f ${LOCK_DIR}/${host} && lock_file=1 || lock_file=0

rc=3
ret=""

if [[ $lock_file -eq 1 ]]; then
	lock_age=$(expr `date +%s` - `stat -c %Y ${LOCK_DIR}/${host}`)
	lock_age_h=$(expr $lock_age / 3600)
	lock_age_t=$(expr $lock_age % 3600)
	lock_age_m=$(expr $lock_age_t / 60)
	lock_age_s=$(expr $lock_age_t % 60)
	ret="lock file exists! lock_age: ${lock_age_h}h ${lock_age_m}m ${lock_age_s}s"
	[[ $running_rsyncs -gt 0 ]] && rc=1 || rc=2
elif find ${MOUNT_DIR}/${host}/ -maxdepth 1 -type f -name .last_backup -mmin -${time} -printf "%p is newer than ${time} mins, last chage: %c" 2>/dev/null |grep -q 'newer'; then
	rc=0
else
	ret="newer backup than ${time} mins not found!"
	rc=2
fi
ret="$ret last snap: ${last_snap}, lock file: ${lock_file}, running rsyncs: ${running_rsyncs} | lock_file=${lock_file}; running_rsyncs=${running_rsyncs}; "

[ $(basename "$0") == "check_backup.sh" ] && (echo $ret; exit $rc) || return $rc

# vim: noexpandtab tabstop=2 shiftwidth=2 nowrap
