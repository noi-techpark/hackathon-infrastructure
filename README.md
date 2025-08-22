<!--
SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>

SPDX-License-Identifier: CC0-1.0
-->

# hackathon-infrastructure
Infrastructure repo for all things hackathon.bz.it

# Infrastructure
## DNS
create a CNAME and proxy entry
## EC2
- create a dedicated volume and attach it to the chosen docker instance.  
- Tag the volume for AWS backup with `AWSBackup=true`
## Volume
- initialize the volume using [this guide](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html)  
- mount volume to /mnt/forgejo
## system user
On the docker host:
```bash
# create a system user for forgejo
useradd -r -M -s /bin/false forgejo
# make this user own the mounted volume
chown -R forgejo:forgejo /mnt/forgejo
# get user and group id of the user. use this in config of forgejo
echo "userid:groupid = $(id -u forgejo):$(id -g forgejo)"
```
## volume backup schedule
Create a EC2 LifecycleManager backup policy that runs hourly during the hackathon event:
`cron(0 * 1,2 8 ? 2025)`
with a retention of 1 day.

# Anubis
[Anubis](https://github.com/TecharoHQ/anubis) is used to prevent excessive AI crawler traffic.

To not fall behind in the weapons race, we always use the `latest` version.  
But because forgejo has some custom handling of favicons that leads to problems, we have to supply our own policy file.  
The ci/cd downloads the most recent default policy and inserts the custom rule every time, hoping it aligns with `latest`

There is a [local version](./infrastructure/local/botPolicies.yaml) that might be out of sync with the most recent Anubis version.  
In that case follow what the ci/cd does: download the most recent one, and add the favicon rule.  

If the format or name has changed, adjust the pipeline accordingly
# Forgejo
## run locally:
```bash
cp .env.example .env
docker compose --profile dev --project-directory . -f infrastructure/docker-compose.run.yml up
```
now you can access via http://localhost:8080 (assuming default $LOCAL_DEV_PORT)

Note that since Anubis does now work without a proxy server, when testing locally you need to access via the included caddy, and not directly via the port `SERVER_PORT_WEB`

The provided config file creates an admin user with credentials `hackathon:hackathon`

# initial setup
For initial setup, go to the web page, and the installation site will greet you.  
- remove the slogan
- create the Administrator account

To create, restore or change the admin user after initial setup, access the docker container shell and run the `forgejo admin user create` command ([see docs](https://forgejo.org/docs/latest/admin/command-line/))

```bash
# note --user, must be executed as 'git' user inside container. Use 'su git' in interactive mode to access the forgejo cli
docker exec --user git forgejo forgejo admin user create --admin --username hackathon --email forgejo@hackathon.bz.it --password '******'
```

# run hackathon setup script
- create an API token with scope admin:read+write and organization:read+write
- customize the `.env` values with prefix `SCRIPT_`

```bash
./scripts/setup_hackathon.sh input.csv
```
passing your input csv file in the same format as `input.example.csv`

Only the team number, name and email columns are used

# gong script
At gong sound run this script to make all org repos public
```bash
./scripts/gong_open_repos.sh
```