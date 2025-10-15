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
repos=$(api GET orgs/$orgname/repos)
for repo in $(echo $repos | jq -r '.[].name' | sed -z 's/\n/ /g'); do
  teams=$(api GET repos/$orgname/$repo/teams)
  teamids=$(echo $teams | jq -r '.[] | select(.name | startswith("team-")) | .id' | sed -z 's/\n/ /g')
  for teamid in $teamids; do 
    api DELETE teams/$teamid/repos/$orgname/$repo
  done
done

echo Removed participant teams from organization repos