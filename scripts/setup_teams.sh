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

# SMTP settings for the notices sent to attendees that already have an account
smtpurl=$SCRIPT_SMTP_URL
smtpuser=$SCRIPT_SMTP_USER
smtppassword=$SCRIPT_SMTP_PASSWORD
mailfrom=$SCRIPT_MAIL_FROM
# extra curl options for sending, e.g. --insecure for a test server with self-signed certificate
smtpcurlopts=$SCRIPT_SMTP_CURL_OPTS
orgname=$SCRIPT_ORGNAME
# usernames that already got a notice in this edition. delete a line to notify again
notifiedfile=${SCRIPT_NOTIFIED_FILE:-$rundir/../.notified-users-$orgname}
touch "$notifiedfile"

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

# load all existing users once. read-only, also executed on dry run.
function load_users {
  local page=1 chunk
  allusers='[]'
  while true; do
    chunk=$(curl --silent -H "Authorization: token $apitoken" -H 'accept: application/json' \
            "$apihost/api/v1/admin/users?limit=50&page=$page" </dev/null)
    if ! echo "$chunk" | jq -e 'type == "array"' >/dev/null 2>&1; then
      echo "Loading users failed: $chunk" >&2
      exit 1
    fi
    [ "$(echo "$chunk" | jq length)" -gt 0 ] || break
    allusers=$(jq -cn --argjson a "$allusers" --argjson b "$chunk" '$a + $b')
    page=$((page + 1))
  done
  echo "Loaded $(echo "$allusers" | jq length) existing users"
}

# "2025-08-01T10:00:00Z" -> "August 2025"
function month_year {
  LC_ALL=C date -d "$1" +"%B %Y"
}

# send_mail <to> <subject> <text body> <html body>
# multipart text + html, like the mails forgejo sends
function send_mail {
  local msg boundary
  boundary="=_hackathon_$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  msg=$(printf 'From: %s\nTo: %s\nSubject: %s\nDate: %s\nMessage-ID: <%s@%s>\nMIME-Version: 1.0\nX-Auto-Response-Suppress: All\nContent-Type: multipart/alternative; boundary="%s"\n\n--%s\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: base64\n\n%s\n\n--%s\nContent-Type: text/html; charset=utf-8\nContent-Transfer-Encoding: base64\n\n%s\n\n--%s--\n' \
        "$mailfrom" "$1" "$2" "$(date -R)" "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" "${mailfrom#*@}" \
        "$boundary" "$boundary" "$(echo "$3" | base64)" "$boundary" "$(echo "$4" | base64)" "$boundary")
  if [ "$dryrun" == "true" ]; then
    echo "MAIL to $1 ($2):" >&2
    echo "$3" >&2
  else
    echo "$msg" | sed 's/$/\r/' | curl --silent --show-error --ssl-reqd $smtpcurlopts \
        --url "$smtpurl" --user "$smtpuser:$smtppassword" \
        --mail-from "$mailfrom" --mail-rcpt "$1" -T -
  fi
}

# notify_existing <username> <to> <name> <created month and year> <explanation>
# sends the notice once per username
function notify_existing {
  if [ "$notify" != "true" ]; then
    echo "Notices disabled (SCRIPT_NOTIFY_USERS), not notifying $1"
    notice_result=NOT-NOTIFIED
    return
  fi
  if grep -qxF "$1" "$notifiedfile"; then
    echo "Already notified $1, skipping"
    notice_result=NOTIFIED-BEFORE
    return
  fi
  if send_mail "$2" "Your Hackathon account" "$(notice_text "$1" "$3" "$4" "$5")" "$(notice_html "$1" "$3" "$4" "$5")"; then
    notice_result=NOTIFIED
    [ "$dryrun" == "true" ] || echo "$1" >> "$notifiedfile"
  else
    notice_result=ERROR
    notice_error="sending mail failed"
  fi
}

# error message of an API response, empty if none
function api_error {
  echo "$1" | jq -r '.message // empty' 2>/dev/null
}

# notice_text <username> <name> <created month and year> <explanation>
function notice_text {
  cat <<BODY
Hi *$2* ,

$4

Your username: $1 (account created $3)

$apihost/user/login

If you forgot your password, you can set a new one ( $apihost/user/forgot_password ).

© Hackathon ( $apihost/ )
BODY
}

function html_escape {
  echo "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# notice_html: same arguments as notice_text
function notice_html {
  local name explanation
  name=$(html_escape "$2")
  explanation=$(html_escape "$4")
  cat <<BODY
<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<meta name="format-detection" content="telephone=no,date=no,address=no,email=no,url=no">
</head>

<body>
	<p>Hi <b>$name</b>,</p><br>
	<p>$explanation</p><br>
	<p>Your username: $1 (account created $3)</p><p><a href="$apihost/user/login">$apihost/user/login</a></p><br>
	<p>If you forgot your password, you can <a href="$apihost/user/forgot_password">set a new one</a>.</p><br>

	<p>© <a target="_blank" rel="noopener noreferrer" href="$apihost/">Hackathon</a></p>
</body>
</html>
BODY
}

load_users

summary=$(mktemp)
trap 'rm -f "$summary"' EXIT

cat $inputcsv | tail -n +2 | while read line || [ -n "$line" ]; do
    att_name=$(echo $line | cut -d, -f 1)
    att_email=$(echo $line | cut -d, -f 2)
    teamno=$(echo $line | cut -d, -f 3)

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

    username=$(echo $att_name | tr '[:upper:]' '[:lower:]' | iconv -f utf8 -t ascii//translit | sed -e 's/[^0-9a-z]/-/g')

    # find existing accounts by username and by email
    byname=$(echo "$allusers" | jq -c --arg u "$username" '[.[] | select(.login | ascii_downcase == $u)][0] // empty')
    byemail=$(echo "$allusers" | jq -c --arg e "$att_email" '[.[] | select((.email // "" | ascii_downcase) == ($e | ascii_downcase))][0] // empty')

    result=""
    reason=""
    notice_error=""

    if [ -n "$byname" ] && [ "$(echo "$byname" | jq -r '.email | ascii_downcase')" != "$(echo "$att_email" | tr '[:upper:]' '[:lower:]')" ]; then
      # username exists, but with another email
      username=$(echo "$byname" | jq -r .login)
      created=$(month_year "$(echo "$byname" | jq -r .created)")
      echo "User $username exists with a different email. notifying $att_email"
      notify_existing "$username" "$att_email" "$att_name" "$created" \
        "An account for you already exists, but it is registered with a different email address than this one. If you no longer have access to that email address, please contact the hackathon team and we will help you."
      result=$notice_result
      reason="username exists with another email"
    elif [ -z "$byname" ] && [ -n "$byemail" ]; then
      # email exists, but under another username
      username=$(echo "$byemail" | jq -r .login)
      created=$(month_year "$(echo "$byemail" | jq -r .created)")
      echo "Email $att_email exists as user $username. notifying"
      notify_existing "$username" "$att_email" "$att_name" "$created" \
        "An account is already registered with this email address, so we did not create a new one. Please log in with the existing account below."
      result=$notice_result
      reason="email belongs to existing user"
    elif [ -n "$byname" ]; then
      # username and email both match
      created=$(month_year "$(echo "$byname" | jq -r .created)")
      echo "User $username exists with the same email. notifying"
      notify_existing "$username" "$att_email" "$att_name" "$created" \
        "You already have an account registered with this email address, so we did not create a new one. Please log in with the existing account below."
      result=$notice_result
      reason="username and email exist"
    else
      # create user
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
      createjson=$(api POST admin/users "$usr")
      if [ -n "$createjson" ] && [ -z "$(echo "$createjson" | jq -r '.login // empty' 2>/dev/null)" ]; then
        result=ERROR
        notice_error="creating user failed: $(api_error "$createjson")"
      else
        result=CREATED
        # they get Forgejo's own mail, never send them a notice on re-runs
        [ "$dryrun" == "true" ] || echo "$username" >> "$notifiedfile"
      fi
      reason="new account"
    fi

    # add user to team
    memberjson=$(api PUT teams/$teamid/members/$username)
    note="$reason"
    [ "$notice_error" == "" ] || note="$note; $notice_error"
    if [ -n "$(api_error "$memberjson")" ]; then
      result=ERROR
      note="$note; adding to team failed: $(api_error "$memberjson")"
    fi
    [ "$dryrun" != "true" ] || note="$note; dry run"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$result" "$username" "$att_name" "$att_email" "$teamname" "${note#; }" >> "$summary"
done

summaryfile="$rundir/../summary-$orgname-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "===== Summary (saved to $summaryfile) ====="
{ printf 'RESULT\tUSERNAME\tNAME\tEMAIL\tTEAM\tNOTES\n'; cat "$summary"; } | column -t -s "$(printf '\t')" | tee "$summaryfile"
