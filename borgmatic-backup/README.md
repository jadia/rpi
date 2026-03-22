# 🪐 Jupiter Backup System

This guide consolidates the backup setup for **Jupiter** (Raspberry Pi/Ubuntu server) into a single "Source of Truth". It covers the complete lifecycle of our backup system using `borgmatic`, `borgbackup`, and `rclone` synced to Google Drive.

---

## 🚀 1. First-Time Setup

### 1.1 System Prerequisites
Run this on any new Ubuntu machine (Raspberry Pi or otherwise) to prepare the environment.

```bash
# Update system and install core tools
 sudo apt update
 sudo apt install -y borgbackup rclone sqlite3 xxhash libsqlite3-dev python3-pip

# Install borgmatic for the current user
 pip install --user borgmatic

# Ensure the local bin is in your PATH (add to ~/.bashrc if needed)
 echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
 source ~/.bashrc
```

| Package | Purpose |
| :--- | :--- |
| `borgbackup` | The core engine that handles deduplication, encryption, and archives. |
| `rclone` | The "cloud-mover" that syncs local data to Google Drive. |
| `sqlite3` | Used for "safe dumping" of databases so they aren't backed up mid-write. |
| `xxhash` | Required for the "Spot Check" feature to verify data integrity. |

### 1.2 Google Drive & Rclone Setup
You must do this once to give your server permission to talk to Google Drive.

1. **Google Console (APIs & Credentials)**
   - Go to [Google Cloud Console](https://console.cloud.google.com/).
   - Enable the **Google Drive API**.
   - Under **OAuth Consent Screen**, set user type to **External** and add your email as a **Test User**.
   - Under **Credentials**, create **OAuth 2.0 Client IDs** (Type: Desktop App). Save the Client ID and Client Secret.
2. **The Folder ID**
   - Open your Google Drive in a browser, create a folder named `BorgBackups`.
   - Copy the string at the end of the URL (e.g., `1Xyf...KHCh`). This is your `root_folder_id`.
3. **Rclone Config**
   - Run ` rclone config` and create a new remote.
   - Name it `jadiashares_gdrive` (Type: `drive`).
   - Use the Client ID, Secret, and Folder ID from above.

### 1.3 The "Jupiter" Config (`~/.config/borgmatic/config.yaml`)
First, create the necessary directories for your backups and configuration:
```bash
 mkdir -p ~/.config/borgmatic
 mkdir -p ~/borg_backups
```

Then, create the configuration file at `~/.config/borgmatic/config.yaml`:

```yaml
source_directories:
    - /home/ubuntu/data

repositories:
    - path: /home/ubuntu/borg_backups
      label: local

# Global Options
log_file: /home/ubuntu/borg_backups/borgmatic.log
log_file_verbosity: 1
log_file_format: "[{asctime}] {levelname}: {message}"
compression: zstd,3

# Retention (2-month policy)
keep_within: 60d
keep_weekly: 6

# Monitoring (Dead Man's Switch)
healthchecks:
    ping_url: https://hc-ping.com/YOUR-UUID-HERE

# Probabilistic Verification
checks:
    - name: spot
      frequency: 1 day
      data_sample_percentage: 1  # Verifies 1% of random files via xxh64sum

# Database safety
sqlite_databases:
    - name: finance_tracker
      path: /home/ubuntu/data/finance-tracker/finance.db

# Unified Commands (v2.1.3+)
commands:
    - before: action
      when: [create]
      run:
          - find /home/ubuntu/data -name "*.db" -exec sqlite3 {} "PRAGMA integrity_check;" \;
    
    - after: action
      when: [create]
      run:
          - rclone sync /home/ubuntu/borg_backups jadiashares_gdrive: -v
    
    - after: error
      run:
          - /home/ubuntu/.local/bin/ntfy -b pushover send "[FAILED] Jupiter Backup"
```

### 1.4 First Manual Run (or Dry-Run)
Before automating your backups, it's highly recommended to do a dry-run to test your config, and then trigger the very first backup manually to ensure data reaches Google Drive.

**1. Dry-Run (tests the config without copying files):**
```bash
 PYTHONWARNINGS="ignore" borgmatic --dry-run --verbosity 1
```

**2. Run the actual backup (creates archives & syncs to cloud):**
```bash
 PYTHONWARNINGS="ignore" borgmatic --verbosity 1 --stats
```
*(Running this master command will automatically execute your database dump, the Borg backup, and the Rclone sync based on your `config.yaml`.)*

---

## 🛠️ 2. Maintenance

Once set up, backups should run seamlessly. However, routine maintenance is recommended.

### 2.1 Automating via Cron
To run backups automatically, add a cron job:
```bash
 crontab -e
```
Add the following line to run the backup daily at 2:00 AM:
```bash
 0 2 * * * export PYTHONWARNINGS="ignore"; PATH=$PATH:/home/ubuntu/.local/bin /home/ubuntu/.local/bin/borgmatic --syslog-verbosity 1
```

### 2.2 Routine Checks
Periodic tasks to ensure backup integrity:
```bash
# Check repository integrity
 borgmatic check

# Prune old backups based on retention policy
 borgmatic prune --stats

# See all configured repositories and stats
 borgmatic info
```

### 2.3 Keeping Configs Safe
**Crucial Step:** Keep a copy of your `~/.config/rclone/rclone.conf` and your `~/.config/borgmatic/config.yaml` on a separate offline drive or secure vault. Also, back up your borg repository key if you use `repokey` encryption. Having these files makes recovery take 5 minutes instead of hours.

---

## 🆘 3. Disaster Recovery (The "What If?")

If your SD card fails or the Pi is destroyed, follow these steps on a **fresh** machine.

### 3.1 Re-install Pre-requisites & Configs
1. Follow **Section 1.1** to install `borgbackup`, `rclone`, and `borgmatic`.
2. Restore your `rclone.conf` (or run ` rclone config` again using your saved ID/Secret).
3. Verify access: ` rclone lsd jadiashares_gdrive:` should show your backup directories.

### 3.2 The Disaster Recovery One-Liner
If you need to quickly pull the entire latest backup and extract it locally:

```bash
 mkdir -p ~/borg_backups && cd ~/borg_backups
 rclone sync jadiashares_gdrive: ~/borg_backups -v && borg extract ~/borg_backups::$(borg list ~/borg_backups --format '{archive}{newline}' | tail -n 1)
```
*This downloads your synced folder, finds the newest archive, and extracts all files into your current directory.*

### 3.3 Quick Recovery via Mounting (Best for single files)
If you just need **one file** and don't want to extract the whole archive locally, you can "mount" the backup like a USB drive:
```bash
# Pull the repository from Drive if not already local
 rclone sync jadiashares_gdrive: ~/borg_backups -v

# Mount the backups
 mkdir ~/recovery_point
 borgmatic mount --mount-point ~/recovery_point

# Now you can 'cp' exactly what you need from that folder.
# When done:
 borgmatic umount --mount-point ~/recovery_point
```

### 3.4 Restoring an SQLite Database
Borgmatic securely dumps SQLite databases to standard `.sql` files before backing them up to prevent corruption. 
```bash
# After extracting the archive, pipe the SQL dump into a new database
 sqlite3 restored_finance.db < path/to/extracted/finance_tracker.sql
```

---

## 🩺 4. Troubleshooting & Useful Commands

Here is a quick reference guide of commands for common scenarios.

### 4.1 Backup Use Cases
**Initialize a new repository without encryption:**
```bash
 borgmatic init --encryption none
```
**List all available archives:**
```bash
 borgmatic list
```
**Dry-run a backup:**
```bash
 borgmatic create --dry-run --verbosity 1
```
**Find a specific file in the archives:**
```bash
 borg list ~/borg_backups::latest
```

### 4.2 Troubleshooting
**Unlock a stalled repository:**
Sometimes if a backup gets interrupted, it leaves a lock on the repository.
```bash
 borgmatic break-lock
```
**Rclone sync failing or rate-limited:**
If Google Drive rate limits you, or sync fails, run rclone interactively to see exact errors:
```bash
 rclone sync ~/borg_backups jadiashares_gdrive: -vv
```
**Healthchecks not pinging:**
1. Check `~/.config/borgmatic/config.yaml` to ensure your URL is correct.
2. Check `~/borg_backups/borgmatic.log` for connection issues.
```bash
 tail -n 50 ~/borg_backups/borgmatic.log
```
**Borgmatic command not found:**
If running via cron, remember cron executes with a minimal environment. Ensure the absolute path `~/.local/bin/borgmatic` is used or `PATH` is exported in the script.
