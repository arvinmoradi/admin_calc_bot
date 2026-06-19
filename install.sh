#!/bin/bash

# ========================================
#   Admin Calc Bot - Installer
#   github.com/arvinmoradi/admin_calc_bot
# ========================================

BASE_DIR="$HOME/calc_admin_price_bot"
REPO_URL="https://github.com/arvinmoradi/admin_calc_bot.git"
REPO_NAME="admin_calc_bot_src"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─────────────────────────────────────────
print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║        Admin Calc Bot Manager        ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─────────────────────────────────────────
check_dependencies() {
    echo -e "${YELLOW}⏳ Checking dependencies...${NC}"

    if ! command -v git &>/dev/null; then
        echo -e "${RED}✗ git is not installed. Installing...${NC}"
        apt-get update -qq && apt-get install -y git
    fi

    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}✗ python3 is not installed. Installing...${NC}"
        apt-get update -qq && apt-get install -y python3
    fi

    if ! command -v pip3 &>/dev/null; then
        echo -e "${RED}✗ pip3 is not installed. Installing...${NC}"
        apt-get update -qq && apt-get install -y python3-pip
    fi

    if ! python3 -m venv --help &>/dev/null; then
        echo -e "${RED}✗ python3-venv is not installed. Installing...${NC}"
        apt-get update -qq && apt-get install -y python3-venv
    fi

    echo -e "${GREEN}✓ All dependencies are ready.${NC}"
}

# ─────────────────────────────────────────
fetch_source() {
    local tmp_dir="/tmp/${REPO_NAME}"

    echo -e "${YELLOW}⏳ Fetching source from GitHub...${NC}"

    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi

    git clone --depth=1 "$REPO_URL" "$tmp_dir" 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to clone from GitHub. Check your internet connection.${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Source fetched successfully.${NC}"
    echo "$tmp_dir"
    return 0
}

# ─────────────────────────────────────────
install_base() {
    print_header
    echo -e "${BLUE}═══ Base Installation ═══${NC}\n"

    check_dependencies

    if [ -d "$BASE_DIR" ]; then
        echo -e "${YELLOW}⚠ Directory ${BASE_DIR} already exists.${NC}"
    else
        mkdir -p "$BASE_DIR"
        echo -e "${GREEN}✓ Base directory created: ${BASE_DIR}${NC}"
    fi

    echo -e "\n${GREEN}✅ Base installation completed successfully.${NC}"
    echo -e "${CYAN}ℹ You can now add admins.${NC}\n"
    read -rp "Press Enter to go back..."
}

# ─────────────────────────────────────────
add_admin() {
    print_header
    echo -e "${BLUE}═══ Add New Admin ═══${NC}\n"

    while true; do
        read -rp "Enter admin username: " user_name
        user_name=$(echo "$user_name" | tr -cd '[:alnum:]_-')

        if [ -z "$user_name" ]; then
            echo -e "${RED}✗ Username cannot be empty.${NC}"
            continue
        fi

        if [ -d "${BASE_DIR}/${user_name}" ]; then
            echo -e "${RED}✗ Admin \"${user_name}\" already exists.${NC}"
            continue
        fi

        break
    done

    local admin_dir="${BASE_DIR}/${user_name}"

    echo -e "\n${YELLOW}⏳ Setting up admin \"${user_name}\"...${NC}\n"

    local tmp_dir
    tmp_dir=$(fetch_source)
    if [ $? -ne 0 ]; then
        read -rp "Press Enter to go back..."
        return 1
    fi

    mkdir -p "$admin_dir"
    echo -e "${GREEN}✓ Admin directory created: ${admin_dir}${NC}"

    cp "${tmp_dir}/main.py" "${admin_dir}/main.py"
    cp "${tmp_dir}/requirements.txt" "${admin_dir}/requirements.txt"
    echo -e "${GREEN}✓ Project files copied.${NC}"

    cat > "${admin_dir}/.env" <<EOF
API_TOKEN=your_bot_token_here
CHANNEL_ID=your_channel_id_here
ADMIN_ID=your_admin_id_here
PRICE_UNIT_GB=15
PRICE_UNIT_MONTH_UNLIMITED=110
EOF
    echo -e "${GREEN}✓ .env file created.${NC}"

    echo -e "${YELLOW}⏳ Creating Python virtual environment...${NC}"
    python3 -m venv "${admin_dir}/venv"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to create venv.${NC}"
        rm -rf "$admin_dir"
        read -rp "Press Enter to go back..."
        return 1
    fi
    echo -e "${GREEN}✓ Virtual environment created.${NC}"

    echo -e "${YELLOW}⏳ Installing Python dependencies...${NC}"
    "${admin_dir}/venv/bin/pip" install --upgrade pip -q
    "${admin_dir}/venv/bin/pip" install -r "${admin_dir}/requirements.txt"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to install dependencies.${NC}"
        read -rp "Press Enter to go back..."
        return 1
    fi
    echo -e "${GREEN}✓ Dependencies installed.${NC}"

    echo -e "${YELLOW}⏳ Creating systemd service...${NC}"

    cat > "/etc/systemd/system/${user_name}_bot.service" <<EOF
[Unit]
Description=Telegram Bot Service ${user_name}
After=network.target

[Service]
WorkingDirectory=${admin_dir}
ExecStart=${admin_dir}/venv/bin/python3 ${admin_dir}/main.py
EnvironmentFile=${admin_dir}/.env
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${user_name}_bot.service"
    systemctl start "${user_name}_bot.service"

    local service_status
    service_status=$(systemctl is-active "${user_name}_bot.service")

    if [ "$service_status" = "active" ]; then
        echo -e "${GREEN}✓ Service is active and running.${NC}"
    else
        echo -e "${YELLOW}⚠ Service created but may need .env to be configured.${NC}"
    fi

    rm -rf "$tmp_dir"

    echo -e "\n${GREEN}✅ Admin \"${user_name}\" added successfully!${NC}"
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📝 Next step - edit the .env file:${NC}"
    echo -e "   ${CYAN}nano ${admin_dir}/.env${NC}"
    echo -e "\n${YELLOW}🔄 After editing, restart the service:${NC}"
    echo -e "   ${CYAN}systemctl restart ${user_name}_bot.service${NC}"
    echo -e "\n${YELLOW}📋 View service logs:${NC}"
    echo -e "   ${CYAN}journalctl -u ${user_name}_bot.service -f${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    read -rp "Press Enter to go back..."
}

# ─────────────────────────────────────────
remove_admin() {
    print_header
    echo -e "${BLUE}═══ Remove Admin ═══${NC}\n"

    if [ ! -d "$BASE_DIR" ] || [ -z "$(ls -A "$BASE_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠ No admins found.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    echo -e "${CYAN}Existing admins:${NC}"
    local i=1
    local admins=()
    for dir in "${BASE_DIR}"/*/; do
        if [ -d "$dir" ]; then
            local name
            name=$(basename "$dir")
            admins+=("$name")
            local status
            status=$(systemctl is-active "${name}_bot.service" 2>/dev/null || echo "unknown")
            echo -e "  ${i}) ${name}  ${YELLOW}[${status}]${NC}"
            ((i++))
        fi
    done

    if [ ${#admins[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ No admins found.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    echo ""
    read -rp "Enter the username of the admin to remove: " user_name

    if [ -z "$user_name" ]; then
        echo -e "${RED}✗ Username is empty.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    if [ ! -d "${BASE_DIR}/${user_name}" ]; then
        echo -e "${RED}✗ Admin \"${user_name}\" does not exist.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    echo -e "\n${RED}⚠ Warning: This action is irreversible!${NC}"
    read -rp "Are you sure you want to remove admin \"${user_name}\"? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    echo -e "\n${YELLOW}⏳ Removing admin \"${user_name}\"...${NC}"

    if systemctl is-active --quiet "${user_name}_bot.service" 2>/dev/null; then
        systemctl stop "${user_name}_bot.service"
        echo -e "${GREEN}✓ Service stopped.${NC}"
    fi

    if systemctl is-enabled --quiet "${user_name}_bot.service" 2>/dev/null; then
        systemctl disable "${user_name}_bot.service"
        echo -e "${GREEN}✓ Service disabled.${NC}"
    fi

    if [ -f "/etc/systemd/system/${user_name}_bot.service" ]; then
        rm -f "/etc/systemd/system/${user_name}_bot.service"
        systemctl daemon-reload
        systemctl reset-failed "${user_name}_bot.service" 2>/dev/null
        echo -e "${GREEN}✓ Service file removed.${NC}"
    fi

    rm -rf "${BASE_DIR}/${user_name}"
    echo -e "${GREEN}✓ Admin directory removed.${NC}"

    echo -e "\n${GREEN}✅ Admin \"${user_name}\" removed successfully.${NC}\n"
    read -rp "Press Enter to go back..."
}

# ─────────────────────────────────────────
update_project() {
    print_header
    echo -e "${BLUE}═══ Update Project ═══${NC}\n"

    if [ ! -d "$BASE_DIR" ] || [ -z "$(ls -A "$BASE_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠ No admins found. Add an admin first.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    # List admins
    echo -e "${CYAN}Available admins:${NC}"
    local i=1
    local admins=()
    for dir in "${BASE_DIR}"/*/; do
        if [ -d "$dir" ]; then
            local name
            name=$(basename "$dir")
            admins+=("$name")
            local status
            status=$(systemctl is-active "${name}_bot.service" 2>/dev/null || echo "unknown")
            echo -e "  ${i}) ${name}  ${YELLOW}[${status}]${NC}"
            ((i++))
        fi
    done

    echo -e "  ${CYAN}a) Update ALL admins${NC}"
    echo ""
    read -rp "Enter username to update (or 'a' for all): " choice

    local targets=()

    if [ "$choice" = "a" ]; then
        for dir in "${BASE_DIR}"/*/; do
            [ -d "$dir" ] && targets+=("$(basename "$dir")")
        done
        echo -e "\n${YELLOW}Updating all ${#targets[@]} admin(s)...${NC}"
    else
        local user_name
        user_name=$(echo "$choice" | tr -cd '[:alnum:]_-')
        if [ ! -d "${BASE_DIR}/${user_name}" ]; then
            echo -e "${RED}✗ Admin \"${user_name}\" does not exist.${NC}"
            read -rp "Press Enter to go back..."
            return
        fi
        targets=("$user_name")
    fi

    # Fetch latest source once
    local tmp_dir
    tmp_dir=$(fetch_source)
    if [ $? -ne 0 ]; then
        read -rp "Press Enter to go back..."
        return 1
    fi

    echo ""

    for user_name in "${targets[@]}"; do
        local admin_dir="${BASE_DIR}/${user_name}"
        echo -e "${CYAN}─── Updating \"${user_name}\" ───${NC}"

        # Stop service
        if systemctl is-active --quiet "${user_name}_bot.service" 2>/dev/null; then
            systemctl stop "${user_name}_bot.service"
            echo -e "  ${YELLOW}⏹ Service stopped.${NC}"
        fi

        # Backup .env
        if [ -f "${admin_dir}/.env" ]; then
            cp "${admin_dir}/.env" "${admin_dir}/.env.bak"
            echo -e "  ${GREEN}✓ .env backed up.${NC}"
        fi

        # Replace main.py and requirements.txt
        cp "${tmp_dir}/main.py" "${admin_dir}/main.py"
        echo -e "  ${GREEN}✓ main.py updated.${NC}"

        # Update requirements only if changed
        if ! diff -q "${tmp_dir}/requirements.txt" "${admin_dir}/requirements.txt" &>/dev/null; then
            cp "${tmp_dir}/requirements.txt" "${admin_dir}/requirements.txt"
            echo -e "  ${YELLOW}⏳ requirements.txt changed — reinstalling dependencies...${NC}"
            "${admin_dir}/venv/bin/pip" install --upgrade pip -q
            "${admin_dir}/venv/bin/pip" install -r "${admin_dir}/requirements.txt"
            if [ $? -ne 0 ]; then
                echo -e "  ${RED}✗ Failed to install dependencies for \"${user_name}\". Skipping restart.${NC}"
                # Restore .env from backup just in case
                [ -f "${admin_dir}/.env.bak" ] && mv "${admin_dir}/.env.bak" "${admin_dir}/.env"
                continue
            fi
            echo -e "  ${GREEN}✓ Dependencies updated.${NC}"
        else
            echo -e "  ${GREEN}✓ requirements.txt unchanged — skipping reinstall.${NC}"
        fi

        # Restore .env (in case it was overwritten)
        if [ -f "${admin_dir}/.env.bak" ]; then
            mv "${admin_dir}/.env.bak" "${admin_dir}/.env"
            echo -e "  ${GREEN}✓ .env restored.${NC}"
        fi

        # Restart service
        systemctl start "${user_name}_bot.service"
        sleep 1

        local service_status
        service_status=$(systemctl is-active "${user_name}_bot.service")
        if [ "$service_status" = "active" ]; then
            echo -e "  ${GREEN}✓ Service restarted successfully.${NC}"
        else
            echo -e "  ${RED}✗ Service failed to start. Check: journalctl -u ${user_name}_bot.service -f${NC}"
        fi

        echo ""
    done

    rm -rf "$tmp_dir"

    echo -e "${GREEN}✅ Update complete.${NC}\n"
    read -rp "Press Enter to go back..."
}

# ─────────────────────────────────────────
show_status() {
    print_header
    echo -e "${BLUE}═══ Admin Status ═══${NC}\n"

    if [ ! -d "$BASE_DIR" ] || [ -z "$(ls -A "$BASE_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠ No admins found.${NC}"
        read -rp "Press Enter to go back..."
        return
    fi

    printf "%-20s %-15s\n" "Username" "Service Status"
    echo "─────────────────────────────────────"

    for dir in "${BASE_DIR}"/*/; do
        if [ -d "$dir" ]; then
            local name
            name=$(basename "$dir")
            local status
            status=$(systemctl is-active "${name}_bot.service" 2>/dev/null || echo "unknown")

            if [ "$status" = "active" ]; then
                printf "%-20s ${GREEN}%-15s${NC}\n" "$name" "● $status"
            else
                printf "%-20s ${RED}%-15s${NC}\n" "$name" "○ $status"
            fi
        fi
    done

    echo ""
    read -rp "Press Enter to go back..."
}

# ─────────────────────────────────────────
update_script() {
    print_header
    echo -e "${BLUE}═══ Update Script & All Admins ═══${NC}\n"

    # Find where this script is running from
    local script_path
    script_path=$(realpath "$0")

    echo -e "${YELLOW}⏳ Fetching latest version from GitHub...${NC}"

    local tmp_dir="/tmp/${REPO_NAME}"
    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi

    git clone --depth=1 "$REPO_URL" "$tmp_dir" 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to clone from GitHub. Check your internet connection.${NC}"
        read -rp "Press Enter to go back..."
        return 1
    fi

    echo -e "${GREEN}✓ Latest source fetched.${NC}\n"

    # ─── Update install.sh ───
    if [ -f "${tmp_dir}/install.sh" ]; then
        cp "${tmp_dir}/install.sh" "$script_path"
        chmod +x "$script_path"
        echo -e "${GREEN}✓ install.sh updated.${NC}"
    else
        echo -e "${YELLOW}⚠ install.sh not found in repo — skipping.${NC}"
    fi

    # ─── Update main.py for all admins ───
    if [ -d "$BASE_DIR" ] && [ -n "$(ls -A "$BASE_DIR" 2>/dev/null)" ]; then
        echo ""
        for dir in "${BASE_DIR}"/*/; do
            if [ -d "$dir" ]; then
                local user_name
                user_name=$(basename "$dir")
                local admin_dir="${BASE_DIR}/${user_name}"

                echo -e "${CYAN}─── Updating \"${user_name}\" ───${NC}"

                # Stop service
                if systemctl is-active --quiet "${user_name}_bot.service" 2>/dev/null; then
                    systemctl stop "${user_name}_bot.service"
                    echo -e "  ${YELLOW}⏹ Service stopped.${NC}"
                fi

                # Update main.py
                cp "${tmp_dir}/main.py" "${admin_dir}/main.py"
                echo -e "  ${GREEN}✓ main.py updated.${NC}"

                # Update requirements.txt if changed
                if ! diff -q "${tmp_dir}/requirements.txt" "${admin_dir}/requirements.txt" &>/dev/null; then
                    cp "${tmp_dir}/requirements.txt" "${admin_dir}/requirements.txt"
                    echo -e "  ${YELLOW}⏳ requirements.txt changed — reinstalling dependencies...${NC}"
                    "${admin_dir}/venv/bin/pip" install --upgrade pip -q
                    "${admin_dir}/venv/bin/pip" install -r "${admin_dir}/requirements.txt"
                    if [ $? -ne 0 ]; then
                        echo -e "  ${RED}✗ Failed to install dependencies for \"${user_name}\".${NC}"
                        continue
                    fi
                    echo -e "  ${GREEN}✓ Dependencies updated.${NC}"
                else
                    echo -e "  ${GREEN}✓ requirements.txt unchanged — skipping reinstall.${NC}"
                fi

                # Restart service
                systemctl start "${user_name}_bot.service"
                sleep 1

                local service_status
                service_status=$(systemctl is-active "${user_name}_bot.service")
                if [ "$service_status" = "active" ]; then
                    echo -e "  ${GREEN}✓ Service restarted successfully.${NC}"
                else
                    echo -e "  ${RED}✗ Service failed to start. Check: journalctl -u ${user_name}_bot.service -f${NC}"
                fi

                echo ""
            fi
        done
    else
        echo -e "${YELLOW}⚠ No admins found — only install.sh was updated.${NC}\n"
    fi

    rm -rf "$tmp_dir"

    echo -e "${GREEN}✅ Update complete!${NC}"
    echo -e "${CYAN}ℹ Restarting script to apply new version...${NC}\n"
    sleep 2

    # Re-execute the updated script
    exec bash "$script_path"
}

# ─────────────────────────────────────────
exit_script() {
    print_header
    echo -e "${BLUE}═══ Exit ═══${NC}\n"

    echo -e "${CYAN}Active services:${NC}"
    local has_active=false
    if [ -d "$BASE_DIR" ]; then
        for dir in "${BASE_DIR}"/*/; do
            if [ -d "$dir" ]; then
                local name
                name=$(basename "$dir")
                local status
                status=$(systemctl is-active "${name}_bot.service" 2>/dev/null)
                if [ "$status" = "active" ]; then
                    echo -e "  ${GREEN}● ${name}_bot.service is running${NC}"
                    has_active=true
                fi
            fi
        done
    fi

    if [ "$has_active" = false ]; then
        echo -e "  ${YELLOW}⚠ No active services found.${NC}"
    fi

    echo ""
    echo -e "  ${GREEN}1)${NC} Exit (keep all services running)"
    echo -e "  ${RED}2)${NC} Exit and stop all services"
    echo -e "  ${YELLOW}3)${NC} Back to main menu"
    echo ""
    read -rp "Select an option: " choice

    case $choice in
        1)
            echo -e "\n${GREEN}✓ All services remain running.${NC}"
            echo -e "${CYAN}Goodbye!${NC}\n"
            exit 0
            ;;
        2)
            echo -e "\n${YELLOW}⏳ Stopping all services...${NC}"
            if [ -d "$BASE_DIR" ]; then
                for dir in "${BASE_DIR}"/*/; do
                    if [ -d "$dir" ]; then
                        local name
                        name=$(basename "$dir")
                        if systemctl is-active --quiet "${name}_bot.service" 2>/dev/null; then
                            systemctl stop "${name}_bot.service"
                            echo -e "  ${RED}⏹ ${name}_bot.service stopped.${NC}"
                        fi
                    fi
                done
            fi
            echo -e "\n${CYAN}Goodbye!${NC}\n"
            exit 0
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid option.${NC}"
            sleep 1
            exit_script
            ;;
    esac
}

# ─────────────────────────────────────────
main_menu() {
    while true; do
        print_header
        echo -e "${CYAN}Base directory: ${BASE_DIR}${NC}\n"
        echo -e "  ${GREEN}1)${NC} Base installation (first time)"
        echo -e "  ${GREEN}2)${NC} Add new admin"
        echo -e "  ${GREEN}3)${NC} Remove admin"
        echo -e "  ${GREEN}4)${NC} Update project (pull latest code from GitHub)"
        echo -e "  ${GREEN}5)${NC} Show admin status"
        echo -e "  ${GREEN}6)${NC} Update script + all admins (pull everything from GitHub)"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        read -rp "Select an option: " choice

        case $choice in
            1) install_base ;;
            2) add_admin ;;
            3) remove_admin ;;
            4) update_project ;;
            5) show_status ;;
            6) update_script ;;
            0) exit_script ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ─────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}✗ This script must be run as root.${NC}"
    echo -e "  Run: ${CYAN}sudo bash install.sh${NC}"
    exit 1
fi

main_menu