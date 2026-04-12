# 📂 Changing media paths

This guide walks you through updating media paths across all services.
Follow this when you mount a new drive, reorganize your storage, or migrate to a new server.

Currently, all media is stored under `/data`.

---

## Step 1 — Mount your new drive

```bash
# Find your new drive
lsblk

# Create a mount point (adjust if different)
sudo mkdir -p /data

# Mount it (replace sdX1 with your actual partition)
sudo mount /dev/sdX1 /data

# Make it permanent — add to /etc/fstab
echo '/dev/sdX1 /data ext4 defaults 0 2' | sudo tee -a /etc/fstab
```

Verify it's mounted:
```bash
df -h /data
```

---

## Step 2 — Recreate your folder structure

```bash
sudo mkdir -p /data/media/{movies,tv,music}
sudo mkdir -p /data/downloads/{complete,incomplete}
sudo chown -R $USER:$USER /data
```

---

## Step 3 — Update the arr stack compose file

Open `services/arr/docker-compose.yml` and update every volume that references `/data`.

Lines to look for and update:

| Service      | Volume line to change                          |
|--------------|------------------------------------------------|
| qBittorrent  | `/data/downloads:/downloads`                   |
| Radarr       | `/data/media/movies:/movies`                   |
| Sonarr       | `/data/media/tv:/tv`                           |
| Lidarr       | `/data/media/music:/music`                     |
| Bazarr       | `/data/media/movies:/movies`                   |
| Bazarr       | `/data/media/tv:/tv`                           |
| Overseerr    | *(no media volumes — nothing to change)*       |
| Prowlarr     | *(no media volumes — nothing to change)*       |

**Example** — changing from `/data` to `/mnt/storage`:

```yaml
# Before
- /data/downloads:/downloads

# After
- /mnt/storage/downloads:/downloads
```

---

## Step 4 — Update the Plex compose file

Open `services/plex/docker-compose.yml` and update the media volume lines:

```yaml
# Before
- /data/media:/media

# After
- /mnt/storage/media:/media
```

---

## Step 5 — Apply the changes

Restart only the affected services (no need to touch Traefik or AdGuard):

```bash
cd services/plex && docker compose up -d && cd ../..
cd services/arr && docker compose up -d && cd ../..
```

---

## Step 6 — Update paths inside the apps

After restarting, the containers will see the new paths — but the apps themselves
have their old paths saved in their configs. Update them in each app's UI:

| App         | Where to update                                      |
|-------------|------------------------------------------------------|
| Radarr      | Settings → Media Management → Root Folders           |
| Sonarr      | Settings → Media Management → Root Folders           |
| Lidarr      | Settings → Media Management → Root Folders           |
| Bazarr      | Settings → Radarr / Sonarr (paths auto-sync usually) |
| qBittorrent | Settings → Downloads → Default Save Path             |
| Plex        | Settings → Libraries → Edit → folder path            |

---

## Quick reference — all path occurrences

| File                              | Variable / line          |
|-----------------------------------|--------------------------|
| `services/arr/docker-compose.yml` | Volume mounts (see above)|
| `services/plex/docker-compose.yml`| Volume mounts (see above)|
| `services/arr/.env`               | `DOWNLOAD_PATH`          |
| `services/arr/.env`               | `MEDIA_PATH`             |
| `services/plex/.env`              | `MEDIA_PATH`             |
