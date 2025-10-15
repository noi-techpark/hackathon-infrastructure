#!/bin/bash

# SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

rundir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $rundir/../.env

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

# create org
orgname=$SCRIPT_ORGNAME
org='{
    "username": "'"$orgname"'",
    "full_name": "NOI Hackathon 2025 SFSCON edition",
    "description": "Nov 7th-8th, 2025",
    "location": "NOI Techpark @NOISE",
    "website": "https://hackathon.bz.it",
    "visibility": "public",
    "repo_admin_change_team_access": false
}'
api POST admin/users/hackathon/orgs "$org"

# Create jury team
juryteam='{
  "can_create_org_repo": false,
  "description": "Jury",
  "includes_all_repositories": true,
  "name": "Jury",
  "permission": "read",
  "units": [
    "repo.actions",
    "repo.code",
    "repo.issues",
    "repo.ext_issues",
    "repo.wiki",
    "repo.ext_wiki",
    "repo.pulls",
    "repo.releases",
    "repo.projects",
    "repo.ext_wiki"
  ]
}'
api POST orgs/$orgname/teams "$juryteam"