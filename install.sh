#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="docker-vps"
REPO_URL="https://github.com/IamGunpoint/docker-vps.git"
INSTALL_DIR_DEFAULT="/opt/docker-vps"
LOG_FILE="/tmp/iamgunpoint-docker-vps-install.log"
HEADER_HEIGHT=13
DOCKER_STARTER_PATH="/usr/local/bin/iamgunpoint-docker-enable.sh"

BANNER='  ___                      ____             _       _
 |_ _| __ _ _ __ ___      / ___| _   _ _ __(_) ___ | |_
  | ||/ _` | `__/ _ \____| |  _| | | | `__| |/ _ \| __|
  | || (_| | | |  __/____| |_| | |_| | |  | | (_) | |_
 |___|\__,_|_|  \___|     \____|\__,_|_|  |_|\___/ \__|
'

rows_cache=""

cleanup_ui() {
    if [[ -t 1 ]]; then
        local rows
        rows="${rows_cache:-$(tput lines 2>/dev/null || echo 24)}"
        tput csr 0 "$((rows - 1))" 2>/dev/null || true
        tput sgr0 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        echo
    fi
}
trap cleanup_ui EXIT

setup_ui() {
    [[ -t 1 ]] || return 0
    local rows cols
    rows="$(tput lines 2>/dev/null || echo 24)"
    cols="$(tput cols 2>/dev/null || echo 80)"
    rows_cache="$rows"
    tput civis 2>/dev/null || true
    tput clear 2>/dev/null || true
    tput cup 0 0 2>/dev/null || true
    printf '\033[1;36m%s\033[0m\n' "$BANNER"
    printf '\033[1;35m%s\033[0m\n' 'iamgunpoint pinned'
    printf '%*s\n' "$cols" '' | tr ' ' '='
    printf ' Bot installer for %s\n' "$APP_NAME"
    printf ' Install log: %s\n' "$LOG_FILE"
    printf '%*s\n' "$cols" '' | tr ' ' '='
    if (( rows > HEADER_HEIGHT + 2 )); then
        tput csr "$HEADER_HEIGHT" "$((rows - 1))" 2>/dev/null || true
        tput cup "$HEADER_HEIGHT" 0 2>/dev/null || true
    fi
}

log() {
    setup_ui
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
    log "ERROR: $*"
    echo
    echo "---- last 80 lines of log ----"
    tail -n 80 "$LOG_FILE" 2>/dev/null || true
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_root_or_sudo() {
    if [[ ${EUID:-0} -eq 0 ]]; then
        SUDO=""
    elif need_cmd sudo; then
        SUDO="sudo"
    else
        fail "Run this script as root or install sudo first."
    fi
}

run_step() {
    local title="$1"
    shift
    log "$title"
    if "$@" >>"$LOG_FILE" 2>&1; then
        log "OK: $title"
    else
        fail "$title failed"
    fi
}

prompt_nonempty() {
    local var_name="$1"
    local label="$2"
    local is_secret="${3:-false}"
    local value=""
    while [[ -z "$value" ]]; do
        if [[ "$is_secret" == "true" ]]; then
            read -r -s -p "$label: " value
            echo
        else
            read -r -p "$label: " value
        fi
        value="${value## }"
        value="${value%% }"
    done
    printf -v "$var_name" '%s' "$value"
}

prompt_default() {
    local var_name="$1"
    local label="$2"
    local default_value="$3"
    local value=""
    read -r -p "$label [$default_value]: " value
    value="${value:-$default_value}"
    printf -v "$var_name" '%s' "$value"
}

install_base_packages() {
    if need_cmd apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        run_step "Updating apt package index" ${SUDO} apt-get update -y
        run_step "Upgrading installed packages" ${SUDO} apt-get upgrade -y
        run_step "Installing base packages" ${SUDO} apt-get install -y \
            bash curl wget git ca-certificates gnupg lsb-release jq \
            python3 python3-pip python3-venv python3-dev build-essential
    elif need_cmd dnf; then
        run_step "Refreshing dnf metadata" ${SUDO} dnf makecache -y
        run_step "Upgrading installed packages" ${SUDO} dnf upgrade -y
        run_step "Installing base packages" ${SUDO} dnf install -y \
            bash curl wget git ca-certificates gnupg2 jq \
            python3 python3-pip python3-virtualenv python3-devel gcc gcc-c++ make
    elif need_cmd yum; then
        run_step "Refreshing yum metadata" ${SUDO} yum makecache -y
        run_step "Upgrading installed packages" ${SUDO} yum update -y
        run_step "Installing base packages" ${SUDO} yum install -y \
            bash curl wget git ca-certificates jq \
            python3 python3-pip gcc gcc-c++ make
    else
        fail "Unsupported OS. Need apt-get, dnf, or yum."
    fi
}

install_docker_if_needed() {
    if need_cmd docker; then
        log "Docker already installed"
        return 0
    fi
    if [[ -n "$SUDO" ]]; then
        run_step "Installing Docker using official convenience script" bash -lc 'curl -fsSL https://get.docker.com | sudo sh'
    else
        run_step "Installing Docker using official convenience script" bash -lc 'curl -fsSL https://get.docker.com | sh'
    fi
}

write_docker_enabler() {
    log "Writing IamGunpoint Docker enabler to ${DOCKER_STARTER_PATH}"
    ${SUDO} tee "$DOCKER_STARTER_PATH" >/dev/null <<'EOF'
#!/usr/bin/env bash
#
#  IamGunpoint
#  ======================================================
#  DOCKER UNIVERSAL STARTER v3.8 VFS-SUCCESS
#  Author: IamGunpoint
#  DO NOT COPY MY CODE - IamGunpoint 2026
#  ======================================================
#  Stripped build - Method 18 only
#  SUCCESS: dockerd_vfs_storage_driver
#
set +u
set -o pipefail
: "${HOME:=/root}"; : "${USER:=root}"; export HOME USER

BANNER='
  ___            ____             _       _
 |_ _| __ _ _ __/ ___|_   _ _ __ | |_ __ (_)_ __ | |_
  | ||/ _` | `__\___ \ | | | `__|| __/ _` | | `__|| __|
  | || (_| | |   ___) || |_| | |  | || (_| | | |   | |_
 |___|\__,_|_|  |____/  \__,_|_|   \__\__,_|_|_|    \__|

          DOCKER UNIVERSAL STARTER
          Author: IamGunpoint
          DO NOT COPY MY CODE - VFS SUCCESS BUILD
'

printf "\033[0;36m%s\033[0m\n" "$BANNER"
SUDO=""; [[ $EUID -ne 0 ]] && command -v sudo >/dev/null && SUDO=sudo

echo "[*] IamGunpoint VFS Starter - Method 18"
docker info >/dev/null 2>&1 && { echo "[OK] Docker already running"; docker version; exit 0; }

${SUDO} pkill -9 dockerd 2>/dev/null || true
${SUDO} rm -f /var/run/docker.sock /var/run/docker.pid 2>/dev/null || true
${SUDO} modprobe overlay 2>/dev/null || true
${SUDO} sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

echo "[18] dockerd_vfs_storage_driver (prob 99%)"
echo "[*] CMD: dockerd --storage-driver=vfs --iptables=false"
${SUDO} nohup dockerd --storage-driver=vfs --iptables=false >/tmp/dockerd.iamgunpoint.vfs.log 2>&1 &

for i in {1..12}; do sleep 1; printf "."; docker info >/dev/null 2>&1 && break; done; echo

if docker info >/dev/null 2>&1; then
  echo ""
  echo "========================================"
  echo "  DOCKER STARTED SUCCESSFULLY"
  echo "  by IamGunpoint v3.8"
  echo "  Method 18: dockerd_vfs_storage_driver"
  echo "========================================"
  docker version
  exit 0
else
  echo "[X] VFS start failed - tail log:"
  tail -40 /tmp/dockerd.iamgunpoint.vfs.log
  exit 1
fi
EOF
    ${SUDO} chmod +x "$DOCKER_STARTER_PATH"
}

enable_docker() {
    if need_cmd systemctl; then
        ${SUDO} systemctl enable docker >>"$LOG_FILE" 2>&1 || true
        ${SUDO} systemctl start docker >>"$LOG_FILE" 2>&1 || true
    fi
    run_step "Running IamGunpoint Docker enabler" "$DOCKER_STARTER_PATH"
}

clone_or_update_repo() {
    local install_dir="$1"
    if [[ -d "$install_dir/.git" ]]; then
        run_step "Updating existing repo in $install_dir" git -C "$install_dir" pull --ff-only
    elif [[ -d "$install_dir" && -n "$(find "$install_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
        fail "Install directory $install_dir exists and is not empty."
    else
        ${SUDO} mkdir -p "$install_dir"
        ${SUDO} chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$install_dir"
        run_step "Cloning repo into $install_dir" git clone "$REPO_URL" "$install_dir"
    fi
}

create_requirements_if_missing() {
    local install_dir="$1"
    if [[ ! -f "$install_dir/requirements.txt" ]]; then
        cat >"$install_dir/requirements.txt" <<'EOF'
discord.py
psutil
requests
EOF
        log "Created requirements.txt"
    fi
}

setup_python_env() {
    local install_dir="$1"
    run_step "Creating Python virtual environment" python3 -m venv "$install_dir/venv"
    run_step "Upgrading pip/setuptools/wheel" "$install_dir/venv/bin/pip" install --upgrade pip setuptools wheel
    run_step "Installing Python requirements" "$install_dir/venv/bin/pip" install -r "$install_dir/requirements.txt"
}

persist_ip_forward() {
    log "Persisting IPv4 forwarding"
    ${SUDO} mkdir -p /etc/sysctl.d
    ${SUDO} tee /etc/sysctl.d/99-iamgunpoint-docker-vps.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
EOF
    ${SUDO} sysctl --system >>"$LOG_FILE" 2>&1 || true
}

patch_bot_config() {
    local install_dir="$1"
    export CFG_TOKEN CFG_ADMIN_ROLE_ID CFG_MAIN_ADMIN_ID CFG_LOGS_CHANNEL_ID CFG_RAM_LIMIT CFG_STORAGE_LIMIT CFG_BOT_OWNER_NAME CFG_INSTALL_DIR
    CFG_INSTALL_DIR="$install_dir"
    python3 <<'PY' >>"$LOG_FILE" 2>&1
import os
import re
from pathlib import Path

install_dir = Path(os.environ['CFG_INSTALL_DIR'])
bot_path = install_dir / 'bot.py'
text = bot_path.read_text()

replacements = {
    'TOKEN': os.environ['CFG_TOKEN'],
    'ADMIN_ROLE_ID': os.environ['CFG_ADMIN_ROLE_ID'],
    'MAIN_ADMIN_ID': os.environ['CFG_MAIN_ADMIN_ID'],
    'LOGS_CHANNEL_ID': os.environ['CFG_LOGS_CHANNEL_ID'],
    'RAM_LIMIT': os.environ['CFG_RAM_LIMIT'],
    'STORAGE_LIMIT': os.environ['CFG_STORAGE_LIMIT'],
    'BOT_OWNER_NAME': os.environ['CFG_BOT_OWNER_NAME'],
}

patterns = {
    'TOKEN': lambda v: f"TOKEN = {v!r}",
    'ADMIN_ROLE_ID': lambda v: f"ADMIN_ROLE_ID = {v}",
    'MAIN_ADMIN_ID': lambda v: f"MAIN_ADMIN_ID = {v}",
    'LOGS_CHANNEL_ID': lambda v: f"LOGS_CHANNEL_ID = {v}",
    'RAM_LIMIT': lambda v: f"RAM_LIMIT = {v!r}",
    'STORAGE_LIMIT': lambda v: f"STORAGE_LIMIT = {v!r}",
    'BOT_OWNER_NAME': lambda v: f"BOT_OWNER_NAME = {v!r}",
}

for key, value in replacements.items():
    pattern = rf"^{key}\s*=\s*.*$"
    text, count = re.subn(pattern, patterns[key](value), text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise SystemExit(f"Could not find config key: {key}")

bot_path.write_text(text)
PY
    log "Patched bot.py with your values"
}

write_install_notes() {
    local install_dir="$1"
    cat >"$install_dir/INSTALL_INFO.txt" <<EOF
IamGunpoint docker-vps install summary
====================================
Install directory: $install_dir
Repository: $REPO_URL
Python venv: $install_dir/venv
Bot file: $install_dir/bot.py
Docker enabler: $DOCKER_STARTER_PATH
Install log: $LOG_FILE

Run bot manually:
cd $install_dir && ./start.sh

Restart Docker manually:
$DOCKER_STARTER_PATH
EOF
}

write_start_script() {
    local install_dir="$1"
    cat >"$install_dir/start.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$install_dir"
exec "$install_dir/venv/bin/python" "$install_dir/bot.py"
EOF
    chmod +x "$install_dir/start.sh"
}

write_systemd_service_if_possible() {
    local install_dir="$1"
    local service_name="iamgunpoint-docker-vps.service"
    if ! need_cmd systemctl; then
        log "systemctl not found, skipping bot service creation"
        return 0
    fi

    log "Creating systemd service ${service_name}"
    ${SUDO} tee "/etc/systemd/system/${service_name}" >/dev/null <<EOF
[Unit]
Description=IamGunpoint Docker VPS Discord Bot
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$install_dir
ExecStart=$install_dir/venv/bin/python $install_dir/bot.py
Restart=always
RestartSec=5
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    ${SUDO} systemctl daemon-reload >>"$LOG_FILE" 2>&1 || true
    ${SUDO} systemctl enable "$service_name" >>"$LOG_FILE" 2>&1 || true
}

maybe_start_bot() {
    local install_dir="$1"
    local answer=""
    read -r -p "Start the bot now? [Y/n]: " answer
    answer="${answer:-Y}"
    if [[ "$answer" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        if need_cmd systemctl && [[ -f /etc/systemd/system/iamgunpoint-docker-vps.service ]]; then
            run_step "Starting bot service" ${SUDO} systemctl restart iamgunpoint-docker-vps.service
            ${SUDO} systemctl --no-pager --full status iamgunpoint-docker-vps.service | tail -n 20 || true
        else
            log "Starting bot with nohup"
            nohup "$install_dir/start.sh" >>"$install_dir/bot-runtime.log" 2>&1 &
            log "Bot started in background. Log: $install_dir/bot-runtime.log"
        fi
    else
        log "Skipped bot start"
    fi
}

main() {
    : >"$LOG_FILE"
    require_root_or_sudo
    setup_ui

    echo
    echo "This installer will:"
    echo "  - update the system"
    echo "  - install Python, pip, git, curl and build tools"
    echo "  - install Docker"
    echo "  - run your IamGunpoint Docker enabler"
    echo "  - clone/update your bot repo"
    echo "  - ask for bot config values"
    echo "  - install Python packages"
    echo "  - create start scripts and optional systemd service"
    echo

    prompt_default INSTALL_DIR "Install directory" "$INSTALL_DIR_DEFAULT"

    install_base_packages
    install_docker_if_needed
    write_docker_enabler
    enable_docker
    persist_ip_forward
    clone_or_update_repo "$INSTALL_DIR"
    create_requirements_if_missing "$INSTALL_DIR"
    setup_python_env "$INSTALL_DIR"

    prompt_nonempty CFG_TOKEN "Discord bot token" true
    prompt_nonempty CFG_ADMIN_ROLE_ID "Admin role ID"
    prompt_nonempty CFG_MAIN_ADMIN_ID "Main admin user ID"
    prompt_nonempty CFG_LOGS_CHANNEL_ID "Logs channel ID"
    prompt_default CFG_RAM_LIMIT "Default RAM limit" "2g"
    prompt_default CFG_STORAGE_LIMIT "Default storage limit" "25g"
    prompt_default CFG_BOT_OWNER_NAME "Bot owner name" "ImGunpoint"

    patch_bot_config "$INSTALL_DIR"
    write_start_script "$INSTALL_DIR"
    write_systemd_service_if_possible "$INSTALL_DIR"
    write_install_notes "$INSTALL_DIR"
    maybe_start_bot "$INSTALL_DIR"

    log "Install finished successfully"
    echo
    echo "Done. Useful files:"
    echo "  $INSTALL_DIR/start.sh"
    echo "  $INSTALL_DIR/INSTALL_INFO.txt"
    echo "  $DOCKER_STARTER_PATH"
    echo "  $LOG_FILE"
}

main "$@"
