#!/bin/bash

# SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

HOST="http://172.17.0.1:3000"
TOKEN=5c8bfe50db6c1f0be1a1223159ecd8faaaf5c55d

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

for teamname in team1 team2 team3; do
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
    if [ "$teamid" = "null" ]; then
        teamid=$(api GET "orgs/2025-summer/teams/search?q=$teamname" | jq '.data[0].id')
        echo fallback to searched teamid. hope it matches: $teamid
    fi

    # create team repo
    reponame=$teamname-repo
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

    for username in user1 user2 user3; do
        #create users
        username=$teamname$username
        usr=$(jq -n --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
              --arg email "$username@domain.com" \
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

        # add user to team
        api PUT teams/$teamid/members/$username
    done
done


