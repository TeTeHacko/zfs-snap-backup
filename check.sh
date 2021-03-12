#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/shared.sh

declare -A crit
declare -A warn
declare -A tot_used
declare -A last

for host in ${HOSTS[@]}; do
  debug "checking host" "${White}${host}"

  ret=$(ssh -o ConnectTimeout=13 -o PasswordAuthentication=no ${host} true 2>&1)
  rc=$?
  if [ $rc -gt 0 ]; then
    debug "${Orange}warn" "${ret}"
    warn["${host}"]="${ret}"
  fi

  source $SCRIPTPATH/check_backup.sh $host
  tot_used["${host}"]="$used"
  last["${host}"]="$last_snap"
  if [ $rc -gt 1 ]; then
    debug "${Red}crit" "${ret}"
    crit["${host}"]=""
  elif [ $rc -eq 1 ]; then
    debug "${Orange}warn" "${ret}"
    warn["${host}"]=""
  else
    debug "${Green}ok" "${ret}"
  fi
done

if [ ${#warn[@]} -gt 0 ]; then
  echo -n "WARNING: "
  rc=1
  for host in "${!warn[@]}"; do
    [ "${!crit[$host]}" == "" ] && echo -n "${host} (${last[${host}]}) "
  done
fi
if [ ${#crit[@]} -gt 0 ]; then
  echo -n "CRITICAL: "
  rc=2
  for host in "${!crit[@]}"; do
    echo -n "${host} (${last[${host}]}) "
  done
fi
if [ ${#crit[@]} -eq 0 -a ${#warn[@]} -eq 0 ]; then
  echo -n "ALL ${#HOSTS[@]} BACKUPS OK"
  rc=0
fi

echo -n " | "

for i in "${!tot_used[@]}"
do
  diff=$((($(date +%s)-$(date +%s --date "$(echo ${last[${i}]} | sed 's/-/ /3')"))/(60)))
  echo -n "${i//./_}-size=${tot_used[$i]}B; ${i//./_}-age=${diff}m; "
done

echo
exit $rc

# vim: noexpandtab tabstop=2 shiftwidth=2 nowrap
