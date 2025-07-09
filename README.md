<!--
SPDX-FileCopyrightText: 2025 NOI Techpark <digital@noi.bz.it>

SPDX-License-Identifier: CC0-1.0
-->

# hackathon-infrastructure
Infrastructure repo for all things hackathon.bz.it

# Forgejo
## run locally:
```bash
cp .env.example .env
docker compose --project-directory . -f infrastructure/docker-compose.run.yml up
```

The provided config file creates an admin user with credentials `hackathon:hackathon`


# initial setup
For initial setup, go to the web page, and the installation site will greet you.  
We override most settings via env variable, so it should not be necessary to do much.  
The only important thing is creating the Administrator account.  

To create, restore or change the admin user after initial setup, access the docker container shell and run the `forgejo admin user create` command ([see docs](https://forgejo.org/docs/latest/admin/command-line/))