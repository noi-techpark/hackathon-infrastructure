#!/bin/bash

# SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

HOST="http://172.17.0.1:3000"
TOKEN=20ad9db1e6fd7205473fecfdd0d0ae76096c7155

function api {
    curl --silent -X $1 \
        -H "Authorization: token $TOKEN" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        $HOST/api/v1/$2 \
        -d "$3"
}

# create org
orgname=2025-summer
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

#create users
username=testuser
usr=$(jq -n --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
      --arg email "test2@domain.com" \
      --arg full_name "Test User" \
      --arg password "passwordsupersecret" \
      --arg username "$username" \
'{
  "created_at": $created_at,
  "email": $email,
  "full_name": $full_name,
  "must_change_password": true,
  "password": $password,
  "restricted": false,
  "send_notify": false,
  "source_id": 0,
  "username": $username,
  "visibility": "private"
}')
api POST admin/users "$usr"

#create team
team=$(jq -n \
      --arg name "team1" \
      --arg description "Team 1" \
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
if [ "$teamid" = "null" ]; then
    teamid=$(api GET 'orgs/2025-summer/teams/search?q=team1' | jq '.data[0].id')
    echo fallback to searched teamid. hope it matches: $teamid
fi

# add user to team
api PUT teams/$teamid/members/$username

# create team repo
reponame=testrepo
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


