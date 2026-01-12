#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

check_requirements() {
    log_info "Checking system requirements..."

    # Git
    if ! command -v git &> /dev/null; then
        log_error "Git not found. Install with: sudo apt install git"
        exit 1
    fi
    log_success "Git available"

    # Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found. Install with: sudo apt install python3"
        exit 1
    fi

    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
        log_error "Python 3.9+ required (found $PYTHON_VERSION)"
        exit 1
    fi

    log_success "Python $PYTHON_VERSION detected"
}

clone_repository() {
    log_info "Repository already cloned. Skipping clone step."
}

setup_environment() {
    log_info "Setting up virtual environment..."

    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log_success "Virtual environment created"
    else
        log_info "Virtual environment already exists"
    fi

    source venv/bin/activate
}

install_dependencies() {
    log_info "Installing dependencies..."

    pip install --upgrade pip --quiet

    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt --quiet
    else
        pip install --quiet \
            py-clob-client \
            web3 \
            eth-account \
            aiohttp \
            python-telegram-bot \
            colorama \
            requests
    fi

    log_success "Dependencies installed"
}

create_scripts() {
    log_info "Creating helper scripts..."

    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python3 main.py
EOF

    cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "python3 main.py" && echo "✓ Bot stopped" || echo "✗ Bot not running"
EOF

    cat > status.sh << 'EOF'
#!/bin/bash
if pgrep -f "python3 main.py" > /dev/null; then
    echo "✓ Bot is RUNNING"
else
    echo "✗ Bot is NOT running"
fi
EOF

    chmod +x start.sh stop.sh status.sh
    log_success "Scripts created"
}

show_instructions() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 INSTALLATION COMPLETE! 🎉                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Start bot:${NC}  ${GREEN}./start.sh${NC}"
    echo -e "${CYAN}Stop bot:${NC}   ${GREEN}./stop.sh${NC}"
    echo -e "${CYAN}Status:${NC}     ${GREEN}./status.sh${NC}"
    echo ""
}

main() {
    check_requirements
    clone_repository
    setup_environment
    install_dependencies
    create_scripts
    show_instructions

    read -p "Start bot now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./start.sh
    fi
}

main
