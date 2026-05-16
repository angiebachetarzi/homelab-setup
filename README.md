# 🏠 homelab

Docker-based homelab stack running on Debian.
All services are exposed via Traefik on `.home` subdomains, resolved by AdGuard Home.
The homelab is going on the SSD for me but usually it would be on the HDD

> **Before cloning:** copy each `.env.example` to `.env` and fill in your values.
> Your real IP, timezone, and credentials should only ever live in `.env` files — these are gitignored and never pushed to GitHub.

---

## Stack

| Service       | URL                                      |
|---------------|------------------------------------------|
| Traefik       | `http://${SERVER_IP}:8080/dashboard/`    |
| AdGuard Home  | `http://adguard.home`                    |
| Jellyfin          | `http://jellyfin.home`                       |
| qBittorrent   | `http://qbit.home`                       |
| Prowlarr      | `http://prowlarr.home`                   |
| Radarr        | `http://radarr.home`                     |
| Sonarr        | `http://sonarr.home`                     |
| Lidarr        | `http://lidarr.home`                     |
| Bazarr        | `http://bazarr.home`                     |
| Jellyseerr     | `http://jellyseerr.home`                  |

---

## Prerequisites

- Debian server with a static IP
- [Docker](https://docs.docker.com/engine/install/debian/)
- [Docker Compose plugin](https://docs.docker.com/compose/install/linux/)
- Git

---

## First-time setup on a fresh server

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/homelab.git /opt/homelab
cd /opt/homelab
```

### 2. Create the shared Docker network

All services communicate through a shared network called `proxy`.
Create it once — it persists across compose restarts:

```bash
docker network create proxy
```

### 3. Set up each service

For every service, copy the example env file and fill in your values:

```bash
cp services/traefik/.env.example services/traefik/.env
cp services/adguard/.env.example services/adguard/.env
cp services/jellyfin/.env.example services/jellyfin/.env
cp services/arr/.env.example services/arr/.env
```

### 4. Start services in order

**Order matters** — Traefik must be up before other services register with it.
AdGuard should be up before you try to reach `.home` domains in your browser.

```bash
# 1. Traefik (reverse proxy)
cd services/traefik && docker compose up -d && cd ../..

# 2. AdGuard (DNS)
cd services/adguard && docker compose up -d && cd ../..

# 3. Jellyfin
cd services/jellyfin && docker compose up -d && cd ../..

# 4. Arr stack
cd services/arr && docker compose up -d && cd ../..
```

---

## Updating a service

```bash
cd services/<service>
docker compose pull
docker compose up -d
```

---

## Stopping a service

```bash
cd services/<service>
docker compose down
```

---

## Media paths

Media is stored under `/mnt`. If you ever need to change that path
(e.g. after mounting a new drive), see **[REPATH.md](./REPATH.md)**.

---

## AdGuard DNS setup

AdGuard handles all `.home` domain resolution.
Make sure your router's DHCP advertises your server IP as the DNS server.

In AdGuard Home → Filters → DNS Rewrites, add:
- `*.home` → your server's IP (the value of `SERVER_IP` in your `.env`)