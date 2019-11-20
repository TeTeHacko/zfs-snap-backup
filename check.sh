#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/shared.sh

for host in ${HOSTS[@]}; do
	debug "checking host" "${White}${host}"

  ret=$(ssh -o ConnectTimeout=5 -o PasswordAuthentication=no ${host} true 2>&1)
  rc=$?
  if [ $rc -gt 0 ]; then
    debug "${Red}${ret}"
  fi

  ret=$(./check_backup.sh "${host}" 2>&1)
  rc=$?
  if [ $rc -gt 1 ]; then
    debug "${Red}${ret}"
  elif [ $rc -eq 1 ]; then
    debug "${Orange}${ret}"
  else
    debug "${Green}${ret}"
  fi

  echo
done
