#!/bin/bash

# 🧙 BurlowToolKit: LXC Wizard v2.4.3
# Creates Proxmox containers with branding, smart networking, and silent setup.

LOGFILE="container-build.log"

# 🔍 Check for dependencies
if ! command -v jq &>/dev/null; then
    echo "❌ 'jq' not installed. Run: apt update && apt install jq -y"
    exit 1
fi

# 🌐 Detect host IP, CIDR, gateway (via vmbr0)
bridge_iface="vmbr0"
cidr=$(ip -4 addr show "$bridge_iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
host_ip="${cidr%/*}"
subnet="${cidr#*/}"
gateway="$(echo "$host_ip" | awk -F. '{print $1"."$2"."$3".1"}')"
base_ip="$(echo "$host_ip" | awk -F. '{print $1"."$2"."$3}')"

# 🔢 Suggest VMID
cluster_json=$(pvesh get /cluster/resources --type vm --output-format=json 2>/dev/null)
if ! echo "$cluster_json" | jq empty >/dev/null 2>&1; then
    echo "⚠️ Cluster scan failed. Falling back to local list."
    existing_ids=($(pct list | awk 'NR>1 {print $1}'))
else
    existing_ids=($(echo "$cluster_json" | jq -r '.[] | select(.vmid != null) | .vmid'))
fi
highest_id=$(printf "%s\n" "${existing_ids[@]}" | sort -n | tail -1)
next_id=$((highest_id + 1))

read -p "🔢 VM ID (default: $next_id): " vmid
vmid="${vmid:-$next_id}"
read -p "📛 Hostname (default: ct-$vmid): " cname
cname="${cname:-ct-$vmid}"

# 🧰 Storage pool + disk
echo -e "\n🧰 Available storage pools:"
pools=($(pvesh get /storage --output-format=json | jq -r '.[].storage'))
for i in "${!pools[@]}"; do echo "$((i+1))) ${pools[$i]}"; done
read -p "→ Choose pool [1-${#pools[@]}] (default: 1): " pool_choice
pool_choice="${pool_choice:-1}"
storage="${pools[$((pool_choice-1))]}"
read -p "🗃️ Root disk size (default: 8G): " rawsize
rawsize="${rawsize:-8G}"
disksize=$(echo "$rawsize" | sed 's/[gGmM]$//')
rootfs="${storage}:${disksize}"

# 📦 Template selection
echo -e "\n📦 CT templates available:"
templates=($(ls /var/lib/vz/template/cache/*.tar.* 2>/dev/null))
if [ ${#templates[@]} -eq 0 ]; then echo "❌ No templates found."; exit 1; fi
for i in "${!templates[@]}"; do echo "$((i+1))) ${templates[$i]##*/}"; done
read -p "→ Choose template [1-${#templates[@]}] (default: 1): " tmpl_choice
tmpl_choice="${tmpl_choice:-1}"
template="${templates[$((tmpl_choice-1))]}"

# 🧠 CPU/RAM
core_count=$(grep -c ^processor /proc/cpuinfo)
echo "💡 Host has $core_count cores."
read -p "🧠 CPU cores (default: 1): " cpu
cpu="${cpu:-1}"
read -p "💾 RAM in GB (default: 2): " ram_gb
ram_gb="${ram_gb:-2}"
ram=$((ram_gb * 1024))

# 🌐 IP & 🔐 Password
while [[ -z "$ip_suffix" ]]; do
    read -p "🌐 Final IP digits (e.g. $base_ip.XXX → 170): " ip_suffix
done
ip="$base_ip.$ip_suffix"
read -s -p "🔐 Root password (default: 'root'): " rootpw
echo
rootpw="${rootpw:-root}"

# 📋 Config summary
echo -e "\n🛠 Final configuration:"
echo "→ VMID: $vmid | Hostname: $cname"
echo "→ Storage: $rootfs"
echo "→ Template: ${template##*/}"
echo "→ CPU: $cpu | RAM: ${ram}MB"
echo "→ IP: $ip/$subnet | Gateway: $gateway"

# 🚀 Container creation
echo -e "\n📦 Creating '$cname'..."
pct create "$vmid" "$template" \
  -hostname "$cname" \
  -cores "$cpu" -memory "$ram" \
  -net0 name=eth0,bridge=$bridge_iface,ip="$ip"/$subnet,gw="$gateway" \
  --rootfs "$rootfs" --unprivileged 1 >>"$LOGFILE" 2>&1
pct start "$vmid" >>"$LOGFILE" 2>&1

# 🔒 Set password
echo "🔒 Setting root password..."
pct exec "$vmid" -- bash -c "echo 'root:$rootpw' | chpasswd" >>"$LOGFILE" 2>&1

# ⏳ Updates (based on OS)
echo -ne "🔍 Detecting container OS... "
os_id=$(pct exec "$vmid" -- bash -c "source /etc/os-release && echo \$ID")
echo "$os_id"

echo -n "⏳ Installing updates — please wait "
spinner="/-\|"
case "$os_id" in
  ubuntu|debian)
    pct exec "$vmid" -- bash -c "apt update -y && apt upgrade -y" >>"$LOGFILE" 2>&1 &
    ;;
  alpine)
    pct exec "$vmid" -- sh -c "apk update && apk upgrade" >>"$LOGFILE" 2>&1 &
    ;;
  arch)
    pct exec "$vmid" -- bash -c "pacman -Syu --noconfirm" >>"$LOGFILE" 2>&1 &
    ;;
  fedora)
    pct exec "$vmid" -- bash -c "dnf upgrade -y" >>"$LOGFILE" 2>&1 &
    ;;
  *)
    echo -ne "\r⚠️ Unknown OS '$os_id' — skipping updates.\n"
    update_skipped=true
    ;;
esac

if [ -z "$update_skipped" ]; then
    pid=$!
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\r⏳ Installing updates — please wait ${spinner:i:1}"
            sleep 0.2
        done
    done
    wait $pid
    echo -ne "\r✅ Updates complete.\n"
fi

# 🖼️ Branding notes
pct set "$vmid" -description "![Burlowcraft Logo](http://192.168.0.148:3000/haydnsan/lxc-creation/raw/branch/main/MDrrHASi.png)

**Burlowcraft — Powered by BurlowToolKit**  
Crafted with precision, coffee ☕, and sysadmin magic 🧙‍♂️

🔗 [View on Gitea](http://192.168.0.148:3000/haydnsan/lxc-creation)"

# 🎉 Completion
echo -e "\n🎉 '$cname' is ready!"
echo "🔗 Connect → pct enter $vmid"
echo "🔐 Password → root:$rootpw"
echo "📁 Log file → $(pwd)/$LOGFILE"
