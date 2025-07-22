# lxc-creation

# 🔧 BurlowToolKit

A modular toolkit for streamlined server provisioning, automation, and container orchestration in Proxmox environments.  
Designed for sysadmins, homelab builders, and infrastructure enthusiasts who want powerful tools with intuitive UX.

---

## 🧩 Module: LXC Wizard (`v2.3.8`)

An interactive shell script for building LXC containers with guided prompts, live progress feedback, and silent backend setup.

---

### ⚙️ Features

- 🔢 Cluster-safe **VMID detection** using Proxmox API
- 📦 Local **template discovery** via `/var/lib/vz/template/cache/`
- 🧰 Smart **storage pool selection** and disk sizing
- 🧠 Prompted **CPU core and RAM** assignment
- 🌐 IP suffix input with **full IP preview** (`e.g. 192.168.0.170`)
- 🔐 Secure **root password** setup (masked input + fallback)
- 📄 Backend operations silently logged to `container-build.log`
- 🔄 **Live progress stages**:
  - ⚙️ Container creation
  - 🔒 Credential configuration
  - ⏳ Apt updates with animated spinner
- 🎉 Completion summary with login and access instructions

---

### 🚀 Quick Start

```bash
bash -c "$(curl -fsSL http://192.168.0.148:3000/haydnsan/lxc-creation/raw/branch/main/create-container.sh)"
```

You'll be guided through:

- Selecting a VMID and hostname  
- Picking a storage pool and disk size  
- Choosing an OS template  
- Allocating CPU and RAM  
- Assigning an IP address  
- Entering root credentials  

Behind the scenes:

- Runs `pct create` and `pct start`  
- Sets the root password silently  
- Executes apt updates in the background  
- Logs all output to `container-build.log`

---

### 📁 Output Files

| File                | Description                                         |
|---------------------|-----------------------------------------------------|
| `container-build.log` | Captures verbose output from container setup       |
| `pct enter $vmid`     | Command to access your freshly deployed container |

---

### 📦 Requirements

- Proxmox VE host with LXC enabled  
- OS templates stored in `/var/lib/vz/template/cache/`  
- `jq` installed:
  ```bash
  apt update && apt install jq -y
  ```

---

## 🛠 Modules (Coming Soon)

| Name            | Description                                         |
|-----------------|-----------------------------------------------------|
| `Wings`         | Installs and configures Pterodactyl panel and daemon |
| `Arr Suite`     | Deploys Sonarr, Radarr, Bazarr, and Lidarr stack     |
| `Plex`          | Containerized Plex with GPU passthrough detection    |
| `WireGuard`     | VPN deployment with NAT, peer config, and Pi-hole integration |

Each module will be standalone, extensible, and tightly integrated into the BurlowToolKit CLI interface.

---

### 🧙 Philosophy

BurlowToolKit balances precision and polish.  
It’s for admins who want their systems to run like clockwork, but still feel like magic.

---
