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