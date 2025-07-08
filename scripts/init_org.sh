#!/bin/bash

# SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

HOST="http://172.17.0.1:3000"
TOKEN=20ad9db1e6fd7205473fecfdd0d0ae76096c7155

function api {
    curl -X POST \
        -H "Authorization: token $TOKEN" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        $HOST/api/v1/$1 \
        -d "$2"
}

org='{
    "username": "hackathon",
    "full_name": "NOI Hackathon 2025 summer edition",
    "description": "Aug 1st-2nd, 2025",
    "location": "Lido Schenna",
    "website": "http://hackathon.bz.it",
    "visibility": "public",
    "repo_admin_change_team_access": false
}'

api /admin/users/hackathon/orgs -d $org

# Generate JSON
body=$(jq -n --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
      --arg email "test2@domain.com" \
      --arg full_name "Test User" \
      --arg password "passwordsupersecret" \
      --arg username "testusername" \
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

echo $body

api admin/users "$body"

