#!/bin/bash
set -e

REPO_URL="https://github.com/0xhamad/polymarket-copy-bot.git"
DIR="polymarket-copy-bot"

echo "[INFO] Bootstrapping Polymarket Copy Bot..."

if [ ! -d "$DIR" ]; then
    echo "[INFO] Cloning repository..."
    git clone "$REPO_URL"
else
    echo "[INFO] Repository already exists"
fi

cd "$DIR"
bash install.sh
