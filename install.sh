#!/bin/bash

set -e
#-----------------------------------
# VARIABLES
readonly SERVICE_NAME="calc_admin_price_bot"
readonly VERSION="v1.0.0"

# DIRS
readonly BOT_DIR="$HOME/calc_admin_price_bot"
readonly REPO_DIR="https://github.com/arvinmoradi/calc_admin_price_bot.git"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
readonly ADMINS_FILE="${BOT_DIR}/admins.json"

# COLORS
readonly GREEN='\e[32m'
readonly RED='\e[31m'
readonly YELLOW='\e[33m'
readonly BLUE='\e[34m'
readonly PURPLE='\e[35m'
readonly TURQUOISE='\e[36m'
readonly WHITE='\e[37m'
readonly MAGNETA='\e[35m'
readonly CYAN='\033[0;36m'
readonly NC='\e[0m'

readonly INSTALLED="${MAGNETA}✅ INSTALLED${NC}"
readonly NOT_INSTALLED="${RED}❌ NOT INSTALLED${NC}"
#-----------------------------------

show_banner() {
  echo -e '            _____                    _____                    _____'
  echo -e '         /\    \                  /\    \                  /\    \'
  echo -e '        /::\    \                /::\    \                /::\____\'
  echo -e '       /::::\    \              /::::\    \              /::::|   |'
  echo -e '      /::::::\    \            /::::::\    \            /:::::|   |'
  echo -e '     /:::/\:::\    \          /:::/\:::\    \          /::::::|   |'
  echo -e '    /:::/__\:::\    \        /:::/__\:::\    \        /:::/|::|   |'
  echo -e '   /::::\   \:::\    \      /::::\   \:::\    \      /:::/ |::|   |'
  echo -e '  /::::::\   \:::\    \    /::::::\   \:::\    \    /:::/  |::|___|______'
  echo -e ' /:::/\:::\   \:::\    \  /:::/\:::\   \:::\____\  /:::/   |::::::::\    \'
  echo -e '/:::/  \:::\   \:::\____\/:::/  \:::\   \:::|    |/:::/    |:::::::::\____\'
  echo -e '\::/    \:::\  /:::/    /\::/   |::::\  /:::|____|\::/    / ~~~~~/:::/    /'
  echo -e ' \/____/ \:::\/:::/    /  \/____|:::::\/:::/    /  \/____/      /:::/    /'
  echo -e '          \::::::/    /         |:::::::::/    /               /:::/    /'
  echo -e '           \::::/    /          |::|\::::/    /               /:::/    /'
  echo -e '           /:::/    /           |::| \::/____/               /:::/    /'
  echo -e '          /:::/    /            |::|  ~|                    /:::/    /'
  echo -e '         /:::/    /             |::|   |                   /:::/    /'
  echo -e '        /:::/    /              \::|   |                  /:::/    /'
  echo -e '        \::/    /                \:|   |                  \::/    /'
  echo -e '         \/____/                  \|___|                   \/____/'
  echo -e ''
}

# ─── Print helpers ───────────────────────────────────────────────────────────
print_step()    { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✅]${NC} $1"; }
print_error()   { echo -e "${RED}[❌]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[⚠️]${NC} $1"; }

press_key() {
  echo ""
  read -rp "Press any key to return to main menu..." -n1
}

# ─── Status helpers ──────────────────────────────────────────────────────────
check_status() {
  [ -d "${BOT_DIR}" ] && [ -d "${BOT_DIR}/.git" ] && [ -f "${BOT_DIR}/main.py" ]
}

check_installed() {
  if check_status; then
    status="${INSTALLED}"
  else
    status="${NOT_INSTALLED}"
  fi
}

# ─── jq availability (fallback to python3) ───────────────────────────────────
json_get_keys() {
  # prints all keys (telegram IDs) from admins.json
  if command -v jq &>/dev/null; then
    jq -r 'keys[]' "${ADMINS_FILE}"
  else
    python3 -c "import json,sys; d=json.load(open('${ADMINS_FILE}')); [print(k) for k in d]"
  fi
}

json_get_name() {
  local id="$1"
  if command -v jq &>/dev/null; then
    jq -r --arg id "$id" '.[$id].name // .[$id]' "${ADMINS_FILE}"
  else
    python3 -c "import json; d=json.load(open('${ADMINS_FILE}')); v=d.get('$id',{}); print(v.get('name',v) if isinstance(v,dict) else v)"
  fi
}

json_add_admin() {
  local id="$1" name="$2"
  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(jq --arg id "$id" --arg name "$name" '.[$id] = {name: $name}' "${ADMINS_FILE}")
    echo "$tmp" > "${ADMINS_FILE}"
  else
    python3 - "$id" "$name" "${ADMINS_FILE}" <<'PYEOF'
import json, sys
tid, name, path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f: d = json.load(f)
d[tid] = {"name": name}
with open(path, "w") as f: json.dump(d, f, indent=2, ensure_ascii=False)
PYEOF
  fi
}

json_remove_admin() {
  local id="$1"
  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(jq --arg id "$id" 'del(.[$id])' "${ADMINS_FILE}")
    echo "$tmp" > "${ADMINS_FILE}"
  else
    python3 - "$id" "${ADMINS_FILE}" <<'PYEOF'
import json, sys
tid, path = sys.argv[1], sys.argv[2]
with open(path) as f: d = json.load(f)
d.pop(tid, None)
with open(path, "w") as f: json.dump(d, f, indent=2, ensure_ascii=False)
PYEOF
  fi
}

# ─── Install ─────────────────────────────────────────────────────────────────
install_core() {
  if check_status; then
    print_success "The bot is already installed."
    press_key
    return 0
  fi

  print_step "Updating system packages..."
  sudo apt-get update -y >/dev/null 2>&1
  sudo apt-get install -y python3 python3-venv python3-pip git jq >/dev/null 2>&1
  print_success "Packages updated."

  mkdir -p "${BOT_DIR}"
  cd "${BOT_DIR}"

  print_step "Cloning repository..."
  git clone "${REPO_DIR}" . >/dev/null 2>&1 || { print_error "Clone failed!"; exit 1; }

  print_step "Creating virtual environment..."
  python3 -m venv venv
  # shellcheck source=/dev/null
  source venv/bin/activate
  print_success "Virtual environment created."

  print_step "Installing Python requirements..."
  pip install --upgrade pip >/dev/null 2>&1
  pip install -r requirements.txt >/dev/null 2>&1
  deactivate
  print_success "Requirements installed."

  if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    cp .env.example .env
    print_success ".env file created from example."
  else
    print_warn "Skipping .env creation (already exists or .env.example missing)."
  fi

  # Initialize admins file
  echo '{}' > "${ADMINS_FILE}"
  print_success "admins.json initialized."

  # Create systemd service
  print_step "Creating systemd service..."
  sudo tee "${SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=Telegram calc price admin bot
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${BOT_DIR}
ExecStart=${BOT_DIR}/venv/bin/python3 ${BOT_DIR}/main.py
Restart=always
RestartSec=10
EnvironmentFile=${BOT_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "${SERVICE_NAME}" >/dev/null 2>&1
  sudo systemctl start "${SERVICE_NAME}"
  print_success "Service created and started."

  print_success "Bot installed successfully!"
  status="${INSTALLED}"
  press_key
}

# ─── Update ──────────────────────────────────────────────────────────────────
update_core() {
  if ! check_status; then
    print_error "Bot is not installed."
    press_key
    return 0
  fi

  print_step "Stopping service..."
  sudo systemctl stop "${SERVICE_NAME}" 2>/dev/null || true

  print_step "Pulling latest code..."
  cd "${BOT_DIR}"
  git pull || { print_error "Git pull failed!"; press_key; return 1; }

  print_step "Updating Python dependencies..."
  # shellcheck source=/dev/null
  source "${BOT_DIR}/venv/bin/activate"
  pip install --upgrade pip >/dev/null 2>&1
  pip install -r requirements.txt >/dev/null 2>&1
  deactivate

  print_step "Restarting service..."
  sudo systemctl start "${SERVICE_NAME}"
  print_success "Bot updated and restarted."
  press_key
}

# ─── Restart ─────────────────────────────────────────────────────────────────
restart() {
  if ! check_status; then
    print_error "Bot is not installed."
    press_key
    return 0
  fi

  print_step "Restarting service..."
  sudo systemctl restart "${SERVICE_NAME}"

  # Brief pause then check status
  sleep 2
  if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
    print_success "Service restarted successfully."
  else
    print_error "Service failed to restart. Check logs:"
    echo ""
    sudo journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
  fi
  press_key
}

# ─── Create Admin ─────────────────────────────────────────────────────────────
create_admin() {
  if ! check_status; then
    print_error "Bot is not installed."
    press_key
    return 0
  fi

  echo ""
  echo -e "${CYAN}─── Add New Admin ──────────────────────────────────${NC}"
  echo ""

  # Get Telegram ID
  while true; do
    read -rp "$(echo -e "${CYAN}Enter Telegram ID (numbers only):${NC} ")" admin_id
    if [[ "$admin_id" =~ ^[0-9]+$ ]]; then
      break
    else
      print_error "Invalid ID — must be numeric. Try again."
    fi
  done

  # Check for duplicate
  if [ -f "${ADMINS_FILE}" ]; then
    existing=$(json_get_name "$admin_id" 2>/dev/null || echo "")
    if [ -n "$existing" ] && [ "$existing" != "null" ]; then
      print_warn "Admin ID ${admin_id} already exists (name: ${existing})."
      read -rp "Overwrite? [y/N]: " overwrite
      [[ "$overwrite" =~ ^[Yy]$ ]] || { echo "Cancelled."; press_key; return 0; }
    fi
  fi

  # Get name
  while true; do
    read -rp "$(echo -e "${CYAN}Enter admin name:${NC} ")" admin_name
    if [ -n "$admin_name" ]; then
      break
    else
      print_error "Name cannot be empty."
    fi
  done

  json_add_admin "$admin_id" "$admin_name"
  print_success "Admin '${admin_name}' (ID: ${admin_id}) added successfully."
  press_key
}

# ─── Remove Admin ─────────────────────────────────────────────────────────────
remove_admin() {
  if ! check_status; then
    print_error "Bot is not installed."
    press_key
    return 0
  fi

  if [ ! -f "${ADMINS_FILE}" ]; then
    print_error "admins.json not found."
    press_key
    return 0
  fi

  echo ""
  echo -e "${CYAN}─── Current Admins ─────────────────────────────────${NC}"
  echo ""

  # Build list
  mapfile -t ids < <(json_get_keys 2>/dev/null)

  if [ ${#ids[@]} -eq 0 ]; then
    print_warn "No admins found."
    press_key
    return 0
  fi

  # Show numbered list
  local i=1
  declare -A id_map
  for id in "${ids[@]}"; do
    name=$(json_get_name "$id")
    echo -e "  ${CYAN}${i}.${NC} ${name} (ID: ${id})"
    id_map[$i]="$id"
    ((i++))
  done

  echo ""
  read -rp "$(echo -e "${CYAN}Enter number to remove (0 to cancel):${NC} ")" choice

  if [[ "$choice" == "0" ]] || [ -z "$choice" ]; then
    echo "Cancelled."
    press_key
    return 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ -z "${id_map[$choice]}" ]; then
    print_error "Invalid selection."
    press_key
    return 0
  fi

  local target_id="${id_map[$choice]}"
  local target_name
  target_name=$(json_get_name "$target_id")

  read -rp "$(echo -e "${YELLOW}Remove '${target_name}' (ID: ${target_id})? [y/N]:${NC} ")" confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    json_remove_admin "$target_id"
    print_success "Admin '${target_name}' removed."
  else
    echo "Cancelled."
  fi
  press_key
}

# ─── Uninstall ────────────────────────────────────────────────────────────────
uninstall_core() {
  if ! check_status; then
    print_error "Bot is not installed."
    press_key
    return 0
  fi

  echo ""
  print_warn "This will permanently delete the bot and all data."
  read -rp "$(echo -e "${RED}Are you sure? [y/N]:${NC} ")" confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    press_key
    return 0
  fi

  print_step "Stopping and disabling service..."
  sudo systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
  sudo systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
  sudo rm -f "${SERVICE_FILE}"
  sudo systemctl daemon-reload

  print_step "Removing bot files..."
  rm -rf "${BOT_DIR}"

  print_success "Bot uninstalled successfully."
  status="${NOT_INSTALLED}"
  press_key
}

# ─── Main Menu ────────────────────────────────────────────────────────────────
main_menu() {
  check_installed
  while true; do
    clear
    show_banner
    echo -e "${GREEN}╔═════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Main Menu                                                                   ║${NC}"
    echo -e "${GREEN}║                                                                             ║${NC}"
    echo -e "${GREEN}║ AdminCalcBot Installer ${VERSION}                                               ║${NC}"
    echo -e "${GREEN}║ Author: ArM                                                                 ║${NC}"
    echo -e "${GREEN}║ Telegram bot to calculate and manage prices and balances for admins.        ║${NC}"
    echo -e "${GREEN}║                                                                             ║${NC}"
    printf "${GREEN}║ Status: $(echo -e "${status}")%-38s${GREEN}║${NC}\n" ""
    echo -e "${GREEN}╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}1.${NC} Install Core"
    echo -e "${CYAN}2.${NC} Create Admin"
    echo -e "${CYAN}3.${NC} Update Core"
    echo -e "${CYAN}4.${NC} Restart"
    echo -e "${CYAN}5.${NC} Remove Admin"
    echo -e "${CYAN}6.${NC} Uninstall"
    echo -e "${CYAN}0.${NC} Exit"
    echo ""
    read -rp "Select option [0-6]: " choice

    case $choice in
      1) install_core ;;
      2) create_admin ;;
      3) update_core ;;
      4) restart ;;
      5) remove_admin ;;
      6) uninstall_core ;;
      0) echo "Bye!"; exit 0 ;;
      *) print_error "Invalid choice."; sleep 1 ;;
    esac

    check_installed
  done
}

main_menu