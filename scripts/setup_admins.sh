#!/bin/bash

# SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

rundir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $rundir/../.env

orgname=$SCRIPT_ORGNAME

# forgejo instance url
apihost=$SCRIPT_HOST
# forgejo api token. must have admin and organization read/write permissions
apitoken=$SCRIPT_TOKEN

# enable API dry run. just echo and don't call anything
dryrun=$SCRIPT_DRYRUN

function api {
  if [ "$dryrun" == "true" ]; then
    echo API $1 $2 $3 >&2
  else
    curl --silent -X $1 \
        -H "Authorization: token $apitoken" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        $apihost/api/v1/$2 \
        -d "$3"
  fi
}
admins=()
admins+=('czagler,Clemens Zagler,c.zagler@noi.bz.it')
admins+=('mroggia,Matteo Roggia,m.roggia@noi.bz.it')
admins+=('rthoeni,Rudi Thoeni,r.thoeni@noi.bz.it')
admins+=('lmiotto,Luca Miotto,l.miotto@noi.bz.it')
admins+=('sseppi,Stefano Seppi,s.seppi@noi.bz.it')
admins+=('pohnewein,Patrick Ohnewein,p.ohnewein@noi.bz.it')

for i in "${!admins[@]}"; do
    IN=${admins[$i]}
    IFS=','; arrIN=($IN); unset IFS;
    username=${arrIN[0]} 
    fullname=${arrIN[1]} 
    email=${arrIN[2]} 
    password=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
    usr=$(jq -n --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
          --arg email "$email" \
          --arg full_name "$fullname" \
          --arg password "$password" \
          --arg username "$username" \
    '{
      "created_at": $created_at,
      "email": $email,
      "full_name": $full_name,
      "must_change_password": true,
      "password": $password,
      "restricted": false,
      "send_notify": true,
      "source_id": 0,
      "username": $username,
      "visibility": "private"
    }')
    api POST admin/users "$usr"
    echo "created user $username"
done
