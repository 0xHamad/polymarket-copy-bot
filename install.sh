#!/bin/bash

#############################################
# Polymarket Copy Bot - ONE-CLICK INSTALLER
# Run with: bash install.sh
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Banner
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║     🚀 POLYMARKET COPY BOT - ONE CLICK INSTALLER 🚀           ║"
    echo "║                                                                ║"
    echo "║              Fast • Automated • Zero Config                    ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_progress() {
    echo -e "${YELLOW}⏳ $1...${NC}"
}

show_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

show_error() {
    echo -e "${RED}✗ $1${NC}"
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    else
        echo "unknown"
    fi
}

install_system_deps() {
    local os=$(detect_os)
    
    if [ "$os" = "linux" ]; then
        show_progress "Installing system dependencies (Linux)"
        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y -qq python3 python3-pip python3-venv git curl wget > /dev/null 2>&1
        show_success "System dependencies installed"
        
    elif [ "$os" = "mac" ]; then
        show_progress "Installing system dependencies (macOS)"
        
        if ! command -v brew &> /dev/null; then
            echo -e "${YELLOW}Installing Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        brew install python@3.11 > /dev/null 2>&1
        show_success "System dependencies installed"
    else
        show_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
}

check_python() {
    show_progress "Checking Python version"
    
    if ! command -v python3 &> /dev/null; then
        show_error "Python 3 not found!"
        echo -e "${YELLOW}Installing Python...${NC}"
        install_system_deps
    fi
    
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    REQUIRED_VERSION="3.9"
    
    if awk "BEGIN {exit !($PYTHON_VERSION >= $REQUIRED_VERSION)}"; then
        show_success "Python $PYTHON_VERSION detected"
    else
        show_error "Python 3.9+ required (found $PYTHON_VERSION)"
        echo -e "${YELLOW}Please upgrade Python${NC}"
        exit 1
    fi
}

setup_venv() {
    show_progress "Creating virtual environment"
    
    if [ -d "venv" ]; then
        echo -e "${YELLOW}  Recreating virtual environment...${NC}"
        rm -rf venv
    fi
    
    python3 -m venv venv
    source venv/bin/activate
    
    show_success "Virtual environment created"
}

install_packages() {
    show_progress "Installing Python packages"
    
    pip install --upgrade pip --quiet
    
    echo -e "${CYAN}  Installing dependencies...${NC}"
    pip install --quiet \
        web3>=6.11.0 \
        eth-account>=0.10.0 \
        py-clob-client>=0.25.0 \
        python-telegram-bot>=20.7 \
        colorama>=0.4.6 \
        aiohttp>=3.9.1 \
        requests>=2.31.0
    
    show_success "All packages installed"
}

download_bot() {
    show_progress "Setting up bot script"
    
    if [ ! -f "main.py" ]; then
        echo -e "${YELLOW}  main.py not found in current directory${NC}"
        echo -e "${YELLOW}  Please ensure main.py is present${NC}"
        exit 1
    fi
    
    chmod +x main.py 2>/dev/null || true
    show_success "Bot script ready"
}

create_run_script() {
    show_progress "Creating helper scripts"
    
    # Start script
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python3 main.py
EOF
    chmod +x start.sh
    
    # Stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "python3 main.py"
echo "✓ Bot stopped"
EOF
    chmod +x stop.sh
    
    # Status script
    cat > status.sh << 'EOF'
#!/bin/bash
if pgrep -f "python3 main.py" > /dev/null; then
    echo "✓ Bot is running"
    echo "Logs: tail -f bot.log"
else
    echo "✗ Bot is not running"
    echo "Start with: ./start.sh"
fi
EOF
    chmod +x status.sh
    
    show_success "Helper scripts created"
}

create_service() {
    if [ "$(detect_os)" = "linux" ]; then
        show_progress "Creating systemd service (optional)"
        
        local current_dir=$(pwd)
        local username=$(whoami)
        
        cat > polybot.service << EOF
[Unit]
Description=Polymarket Copy Trading Bot
After=network.target

[Service]
Type=simple
User=$username
WorkingDirectory=$current_dir
ExecStart=$current_dir/venv/bin/python3 $current_dir/main.py
Restart=always
RestartSec=10
StandardOutput=append:$current_dir/bot.log
StandardError=append:$current_dir/bot.log

[Install]
WantedBy=multi-user.target
EOF
        
        echo -e "${CYAN}  Service file created: polybot.service${NC}"
        echo -e "${YELLOW}  To enable 24/7:${NC}"
        echo -e "${WHITE}    sudo cp polybot.service /etc/systemd/system/${NC}"
        echo -e "${WHITE}    sudo systemctl enable polybot${NC}"
        echo -e "${WHITE}    sudo systemctl start polybot${NC}"
        echo ""
    fi
}

print_instructions() {
    echo ""
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║              INSTALLATION COMPLETE! 🎉                         ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}Quick Start:${NC}"
    echo -e "${WHITE}  1. Start bot:     ${GREEN}./start.sh${NC}"
    echo -e "${WHITE}  2. Check status:  ${GREEN}./status.sh${NC}"
    echo -e "${WHITE}  3. View logs:     ${GREEN}tail -f bot.log${NC}"
    echo -e "${WHITE}  4. Stop bot:      ${GREEN}./stop.sh${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}First Run:${NC}"
    echo -e "${YELLOW}  The bot will guide you through setup automatically!${NC}"
    echo -e "${WHITE}  Just run: ${GREEN}./start.sh${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}What You'll Need:${NC}"
    echo -e "${WHITE}  ✓ USDC on Polygon network (min $50)${NC}"
    echo -e "${WHITE}  ✓ 5 minutes for setup${NC}"
    echo ""
    echo -e "${GREEN}Ready to start? Run: ${BOLD}./start.sh${NC}"
    echo ""
}

main() {
    print_banner
    
    echo -e "${CYAN}${BOLD}Starting automated installation...${NC}"
    echo ""
    
    if [ "$EUID" -eq 0 ]; then 
        show_error "Please do NOT run as root"
        exit 1
    fi
    
    check_python
    setup_venv
    install_packages
    download_bot
    create_run_script
    create_service
    
    print_instructions
    
    echo ""
    read -p "$(echo -e ${YELLOW}Start bot now? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREEN}Starting bot...${NC}"
        sleep 1
        ./start.sh
    else
        echo ""
        echo -e "${CYAN}When ready, run: ${GREEN}./start.sh${NC}"
        echo ""
    fi
}

main
