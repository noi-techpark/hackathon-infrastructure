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

if [ -z "$1" ]; then
  echo "Missing csv file argument"
  exit 1
fi
inputcsv=$1

# enable API dry run. just echo and don't call anything
dryrun=$SCRIPT_DRYRUN
# notify newly created users via mail
notify=$SCRIPT_NOTIFY_USERS

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
orgname=2025-summer-t1
org='{
    "username": "'"$orgname"'",
    "full_name": "NOI Hackathon 2025 summer edition",
    "description": "Aug 1st-2nd, 2025",
    "location": "Lido Schenna",
    "website": "https://hackathon.bz.it",
    "visibility": "public",
    "repo_admin_change_team_access": false
}'
api POST admin/users/hackathon/orgs "$org"

cat $inputcsv | tail -n +2 | while read line; do
    teamno=$(echo $line | cut -d, -f 5)
    att_name=$(echo $line | cut -d, -f 1)
    att_email=$(echo $line | cut -d, -f 9)

    teamname=team-$teamno
    teamid=$(api GET "orgs/$orgname/teams/search?q=$teamname" | jq '.data[0].id')
    if [ "$teamid" == "null" ]; then
      echo "Team $teamname has not been found. creating..."
      #create team
      team=$(jq -n \
            --arg name "$teamname" \
            --arg description "Team $teamname" \
      '{
        "can_create_org_repo": false,
        "description": $description,
        "includes_all_repositories": false,
        "name": $name,
        "permission": "write",
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
      }')
      teamjson=$(api POST orgs/$orgname/teams "$team")
      teamid=$(echo $teamjson | jq '.id')
      echo TEAM: $team, $teamjson, $teamid

      # create team repo
      reponame=$teamname
      repo='{
        "auto_init": true,
        "license": "AGPL-3.0-or-later",
        "name": "'"$reponame"'",
        "private": true,
        "template": false
      }'
      api POST orgs/$orgname/repos "$repo"

      # give repo access to team
      api PUT teams/$teamid/repos/$orgname/$reponame
    fi

    # create user
    # lowercase, convert umlauts etc., replace spaces with dashes
    username=$(echo $att_name | tr '[:upper:]' '[:lower:]' | iconv -f utf8 -t ascii//translit | sed -e 's/[^0-9a-z]/-/g')
    password=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
    usr=$(jq -n --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
          --arg email "$att_email" \
          --arg full_name "$att_name" \
          --arg password "$password" \
          --arg username "$username" \
          --argjson notify $notify \
    '{
      "created_at": $created_at,
      "email": $email,
      "full_name": $full_name,
      "must_change_password": true,
      "password": $password,
      "restricted": false,
      "send_notify": $notify,
      "source_id": 0,
      "username": $username,
      "visibility": "private"
    }')
    api POST admin/users "$usr"

    # add user to team
    api PUT teams/$teamid/members/$username
done


