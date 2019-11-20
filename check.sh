#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/shared.sh

prob=0
declare -A crit
declare -A warn

for host in ${HOSTS[@]}; do
	debug "checking host" "${White}${host}"

  ret=$(ssh -o ConnectTimeout=5 -o PasswordAuthentication=no ${host} true 2>&1)
  rc=$?
  prob=$((prob + rc))
  if [ $rc -gt 0 ]; then
    debug "${Red}crit" "${ret}"
    crit["${host}"]="${ret}"
  fi

  ret=$(./check_backup.sh "${host}" 2>&1)
  rc=$?
  prob=$((prob + rc))
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
    echo -n "${host}, "
  done
fi
if [ ${#crit[@]} -gt 0 ]; then
  echo -n "CRITICAL: "
  rc=2
  for host in "${!crit[@]}"; do
    echo -n "${host}, "
  done
fi

echo
exit $rc
