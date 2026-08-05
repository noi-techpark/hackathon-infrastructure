#!/bin/bash

# SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Deletes all non-admin users from the forgejo instance.
#
# The forgejo/gitea admin user deletion endpoint removes the user's org and
# team memberships as part of the same DB transaction, so there is no need
# to remove users from teams beforehand.

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

# collect all non-admin usernames, paging through the admin users list
usernames=()
page=1
while :; do
  users=$(api GET "admin/users?limit=50&page=$page")
  count=$(echo "$users" | jq 'length')
  if [ -z "$count" ] || [ "$count" == "0" ] || [ "$count" == "null" ]; then
    break
  fi
  while IFS= read -r username; do
    usernames+=("$username")
  done < <(echo "$users" | jq -r '.[] | select(.is_admin == false) | .login')
  page=$((page+1))
done

if [ "${#usernames[@]}" -eq 0 ]; then
  echo "No non-admin users found."
  exit 0
fi

echo "About to delete ${#usernames[@]} non-admin user(s):"
printf '  %s\n' "${usernames[@]}"

if [ "$dryrun" != "true" ]; then
  read -p "Type 'yes' to confirm deletion: " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
  fi
fi

for username in "${usernames[@]}"; do
  api DELETE "admin/users/$username?purge=true"
done
