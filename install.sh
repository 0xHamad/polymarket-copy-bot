#!/bin/bash

#############################################
# POLYMARKET COPY BOT - ULTIMATE INSTALLER
# One command does EVERYTHING!
#
# Usage:
# curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/polymarket-copy-bot/main/quick-install.sh | bash
#
# Or:
# wget -qO- https://raw.githubusercontent.com/YOUR_USERNAME/polymarket-copy-bot/main/quick-install.sh | bash
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Config
REPO_URL="https://github.com/YOUR_USERNAME/polymarket-copy-bot.git"
INSTALL_DIR="polymarket-copy-bot"

# Banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║        🤖 POLYMARKET AUTO COPY TRADING BOT 🤖                    ║
║                                                                   ║
║              ULTIMATE ONE-COMMAND INSTALLER                       ║
║                                                                   ║
║     Clone → Install → Setup → Trade in 2 minutes!                ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
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

check_requirements() {
    log_info "Checking system requirements..."
    
    local os=$(detect_os)
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        log_error "Please do NOT run as root"
        exit 1
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log_warning "Git not found. Installing..."
        if [ "$os" = "linux" ]; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq git
        elif [ "$os" = "mac" ]; then
            if ! command -v brew &> /dev/null; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install git
        fi
    fi
    log_success "Git available"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_warning "Python 3 not found. Installing..."
        if [ "$os" = "linux" ]; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq python3 python3-pip python3-venv
        elif [ "$os" = "mac" ]; then
            brew install python@3.11
        fi
    fi
    
    # Verify Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    REQUIRED="3.9"
    
    if awk "BEGIN {exit !($PYTHON_VERSION >= $REQUIRED)}"; then
        log_success "Python $PYTHON_VERSION detected"
    else
        log_error "Python 3.9+ required (found $PYTHON_VERSION)"
        exit 1
    fi
}

clone_repository() {
    log_info "Cloning repository from GitHub..."
    
    # Remove old installation if exists
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Found existing installation. Removing..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Clone repo
    if git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
        log_success "Repository cloned successfully"
    else
        log_error "Failed to clone repository"
        log_info "Make sure the repository URL is correct:"
        log_info "$REPO_URL"
        exit 1
    fi
    
    # Enter directory
    cd "$INSTALL_DIR"
}

setup_environment() {
    log_info "Setting up Python virtual environment..."
    
    # Create venv
    python3 -m venv venv
    
    # Activate venv
    source venv/bin/activate
    
    log_success "Virtual environment created"
}

install_dependencies() {
    log_info "Installing Python dependencies..."
    
    # Upgrade pip
    pip install --upgrade pip --quiet
    
    # Install from requirements.txt
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt --quiet
        log_success "Dependencies installed from requirements.txt"
    else
        # Fallback: install manually
        log_warning "requirements.txt not found. Installing dependencies manually..."
        pip install --quiet \
            web3>=6.11.0 \
            eth-account>=0.10.0 \
            py-clob-client>=0.25.0 \
            python-telegram-bot>=20.7 \
            colorama>=0.4.6 \
            aiohttp>=3.9.1 \
            requests>=2.31.0
        log_success "Dependencies installed"
    fi
}

create_helper_scripts() {
    log_info "Creating helper scripts..."
    
    # Make install.sh executable
    if [ -f "install.sh" ]; then
        chmod +x install.sh
    fi
    
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
    echo "✓ Bot is RUNNING"
    echo ""
    echo "Commands:"
    echo "  View logs:  tail -f bot.log"
    echo "  Stop bot:   ./stop.sh"
else
    echo "✗ Bot is NOT running"
    echo ""
    echo "Commands:"
    echo "  Start bot:  ./start.sh"
fi
EOF
    chmod +x status.sh
    
    # Update script
    cat > update.sh << 'EOF'
#!/bin/bash
echo "Updating bot from GitHub..."
git pull
source venv/bin/activate
pip install -r requirements.txt --upgrade --quiet
echo "✓ Update complete!"
echo "Restart bot with: ./start.sh"
EOF
    chmod +x update.sh
    
    log_success "Helper scripts created"
}

show_final_instructions() {
    local current_dir=$(pwd)
    
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║              🎉 INSTALLATION COMPLETE! 🎉                        ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📍 Installation Directory:${NC}"
    echo -e "   ${YELLOW}$current_dir${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}🚀 Quick Start:${NC}"
    echo -e "   ${WHITE}cd $INSTALL_DIR${NC}"
    echo -e "   ${GREEN}./start.sh${NC}    ${MAGENTA}# Start the bot${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📋 Available Commands:${NC}"
    echo -e "   ${GREEN}./start.sh${NC}    ${MAGENTA}# Start bot (runs setup wizard on first time)${NC}"
    echo -e "   ${GREEN}./stop.sh${NC}     ${MAGENTA}# Stop bot${NC}"
    echo -e "   ${GREEN}./status.sh${NC}   ${MAGENTA}# Check if bot is running${NC}"
    echo -e "   ${GREEN}./update.sh${NC}   ${MAGENTA}# Update bot from GitHub${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📱 First Run Setup:${NC}"
    echo -e "   ${YELLOW}The bot will automatically guide you through:${NC}"
    echo -e "   ${WHITE}1. Wallet creation/import${NC}"
    echo -e "   ${WHITE}2. Target trader selection${NC}"
    echo -e "   ${WHITE}3. RPC provider setup${NC}"
    echo -e "   ${WHITE}4. Telegram notifications (optional)${NC}"
    echo -e "   ${WHITE}5. Trading parameters${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}💰 What You'll Need:${NC}"
    echo -e "   ${WHITE}✓ USDC on Polygon network${NC}"
    echo -e "   ${WHITE}✓ Minimum $50 recommended for testing${NC}"
    echo -e "   ${WHITE}✓ 5 minutes for initial setup${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📚 Documentation:${NC}"
    echo -e "   ${WHITE}README:       cat README.md${NC}"
    echo -e "   ${WHITE}Quick Start:  cat QUICKSTART.md${NC}"
    echo -e "   ${WHITE}Features:     cat FEATURES.md${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Ready to start trading?${NC}"
    echo ""
}

prompt_start() {
    read -p "$(echo -e ${YELLOW}Start bot now? [y/N]: ${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREEN}🚀 Starting bot...${NC}"
        echo ""
        sleep 1
        ./start.sh
    else
        echo ""
        echo -e "${CYAN}To start later, run:${NC}"
        echo -e "${GREEN}cd $INSTALL_DIR && ./start.sh${NC}"
        echo ""
    fi
}

main() {
    show_banner
    
    echo -e "${BOLD}${CYAN}This script will:${NC}"
    echo -e "  ${WHITE}1. Clone bot from GitHub${NC}"
    echo -e "  ${WHITE}2. Install Python dependencies${NC}"
    echo -e "  ${WHITE}3. Create helper scripts${NC}"
    echo -e "  ${WHITE}4. Prepare for first run${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Continue? [Y/n]: ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        
        check_requirements
        clone_repository
        setup_environment
        install_dependencies
        create_helper_scripts
        show_final_instructions
        prompt_start
    else
        echo ""
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
}

main
