#!/bin/bash
################################################################
# Homelab deploy script
#
# Spins up all services and reports their status at the end.
# Safe to run multiple times — skips things already in place.
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
################################################################

set -euo pipefail

################################################################
# Colors
################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # no color

################################################################
# Helpers
################################################################
ok()   { echo -e "${GREEN}  ✓ ${1}${NC}"; }
skip() { echo -e "${YELLOW}  ↷ ${1} (skipped)${NC}"; }
info() { echo -e "${BLUE}  → ${1}${NC}"; }
fail() { echo -e "${RED}  ✗ ${1}${NC}"; }
header() { echo -e "\n${BOLD}${1}${NC}"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="${REPO_DIR}/services"

################################################################
# Track results for final report
################################################################
declare -A SERVICE_STATUS
WARNINGS=()

################################################################
# Step 1 — Check prerequisites
################################################################
header "[ 1/6 ] Checking prerequisites"

# Docker
if command -v docker &>/dev/null; then
    skip "Docker already installed ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    ok "Docker installed"
fi

# Docker Compose plugin
if docker compose version &>/dev/null; then
    skip "Docker Compose plugin already available ($(docker compose version --short))"
else
    info "Installing Docker Compose plugin..."
    apt-get update -qq && apt-get install -y docker-compose-plugin
    ok "Docker Compose plugin installed"
fi

# apache2-utils (for htpasswd — used to generate Traefik dashboard password)
if command -v htpasswd &>/dev/null; then
    skip "apache2-utils already installed"
else
    info "Installing apache2-utils..."
    apt-get update -qq && apt-get install -y apache2-utils
    ok "apache2-utils installed"
fi

################################################################
# Step 2 — Docker network
################################################################
header "[ 2/6 ] Docker network"

if docker network inspect proxy &>/dev/null; then
    skip "Docker network 'proxy' already exists"
else
    docker network create proxy
    ok "Docker network 'proxy' created"
fi

################################################################
# Step 3 — Media and download folders
################################################################
header "[ 3/6 ] Media and download folders"

FOLDERS=(
    "/data/media/movies"
    "/data/media/tv"
    "/data/media/music"
    "/data/downloads/complete"
    "/data/downloads/incomplete"
)

for folder in "${FOLDERS[@]}"; do
    if [ -d "$folder" ]; then
        skip "$folder already exists"
    else
        mkdir -p "$folder"
        ok "Created $folder"
    fi
done

################################################################
# Step 4 — Copy .env.example → .env for each service
################################################################
header "[ 4/6 ] Environment files"

ENV_SERVICES=("traefik" "adguard" "plex" "arr")

for svc in "${ENV_SERVICES[@]}"; do
    env_example="${SERVICES_DIR}/${svc}/.env.example"
    env_file="${SERVICES_DIR}/${svc}/.env"

    if [ -f "$env_file" ]; then
        skip "${svc}/.env already exists — not overwriting"
    else
        cp "$env_example" "$env_file"
        ok "Created ${svc}/.env from .env.example"
        WARNINGS+=("${svc}/.env was just created from the example — fill in your values before using this service")
    fi
done

# Traefik plex dynamic config
plex_example="${SERVICES_DIR}/traefik/config/dynamic/plex.yml.example"
plex_yml="${SERVICES_DIR}/traefik/config/dynamic/plex.yml"

if [ -f "$plex_yml" ]; then
    skip "traefik/config/dynamic/plex.yml already exists — not overwriting"
else
    cp "$plex_example" "$plex_yml"
    ok "Created plex.yml from plex.yml.example"
    WARNINGS+=("traefik/config/dynamic/plex.yml was created — replace YOUR_SERVER_IP with your actual server IP")
fi

# Traefik auth dynamic config
auth_example="${SERVICES_DIR}/traefik/config/dynamic/auth.yml.example"
auth_yml="${SERVICES_DIR}/traefik/config/dynamic/auth.yml"

if [ -f "$auth_yml" ]; then
    skip "traefik/config/dynamic/auth.yml already exists — not overwriting"
else
    cp "$auth_example" "$auth_yml"
    ok "Created auth.yml from auth.yml.example"
    WARNINGS+=("traefik/config/dynamic/auth.yml was created — replace the example hash with a real one: echo \$(htpasswd -nB yourpassword) | sed -e s/\\\\\$/\\\\\$\\\\\$/g")
fi

################################################################
# Step 5 — Start services
################################################################
header "[ 5/6 ] Starting services"

start_service() {
    local name="$1"
    local dir="${SERVICES_DIR}/${2}"

    info "Starting ${name}..."
    if docker compose -f "${dir}/docker-compose.yml" up -d 2>&1; then
        ok "${name} started"
    else
        fail "${name} failed to start — check logs: docker logs ${name}"
        SERVICE_STATUS["$name"]="FAILED"
        return
    fi
    SERVICE_STATUS["$name"]="STARTING"
}

start_service "traefik"     "traefik"
start_service "adguard"     "adguard"
start_service "plex"        "plex"
start_service "qbittorrent" "arr"
start_service "prowlarr"    "arr"
start_service "radarr"      "arr"
start_service "sonarr"      "arr"
start_service "lidarr"      "arr"
start_service "bazarr"      "arr"
start_service "overseerr"   "arr"

################################################################
# Step 6 — Wait and report
################################################################
header "[ 6/6 ] Waiting for containers to settle (15s)..."
sleep 15

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  DEPLOYMENT REPORT${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

CONTAINERS=(
    "traefik:http://\${SERVER_IP}:8080/dashboard/"
    "adguard:http://adguard.home"
    "plex:http://plex.home"
    "qbittorrent:http://qbit.home"
    "prowlarr:http://prowlarr.home"
    "radarr:http://radarr.home"
    "sonarr:http://sonarr.home"
    "lidarr:http://lidarr.home"
    "bazarr:http://bazarr.home"
    "overseerr:http://overseerr.home"
)

ALL_OK=true

for entry in "${CONTAINERS[@]}"; do
    name="${entry%%:*}"
    url="${entry#*:}"

    # Skip if we already know it failed to start
    if [ "${SERVICE_STATUS[$name]:-}" = "FAILED" ]; then
        printf "  %-20s ${RED}✗ FAILED${NC}   %s\n" "$name" "$url"
        ALL_OK=false
        continue
    fi

    state=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "missing")

    case "$state" in
        running)
            printf "  %-20s ${GREEN}✓ RUNNING${NC}  %s\n" "$name" "$url"
            ;;
        exited|dead)
            printf "  %-20s ${RED}✗ ${state^^}${NC}    %s\n" "$name" "$url"
            ALL_OK=false
            ;;
        restarting)
            printf "  %-20s ${YELLOW}⟳ RESTARTING${NC} %s\n" "$name" "$url"
            ALL_OK=false
            ;;
        missing)
            printf "  %-20s ${RED}✗ NOT FOUND${NC} %s\n" "$name" "$url"
            ALL_OK=false
            ;;
        *)
            printf "  %-20s ${YELLOW}? ${state^^}${NC}    %s\n" "$name" "$url"
            ;;
    esac
done

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Warnings
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠ Action required:${NC}"
    for w in "${WARNINGS[@]}"; do
        echo -e "${YELLOW}    • ${w}${NC}"
    done
fi

# Useful commands
echo ""
echo -e "${BOLD}  Useful commands:${NC}"
echo "    View logs for a container:  docker logs <name>"
echo "    Restart a service:          docker compose -f services/<name>/docker-compose.yml restart"
echo "    Pull latest images:         docker compose -f services/<name>/docker-compose.yml pull"
echo ""

if $ALL_OK; then
    echo -e "${GREEN}${BOLD}  All services are running. Enjoy your homelab!${NC}"
else
    echo -e "${RED}${BOLD}  Some services need attention. Check the logs above.${NC}"
fi

echo ""