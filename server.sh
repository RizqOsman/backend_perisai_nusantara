#!/bin/bash
# ============================================================
# Backend Perisai Nusantara - Linux Server Management Script
# ============================================================
# Usage:
#   ./server.sh start    - Start server
#   ./server.sh stop     - Stop server
#   ./server.sh restart  - Restart server
#   ./server.sh status   - Check server status
#   ./server.sh install  - Install dependencies
#   ./server.sh logs     - View server logs (tail)
#   ./server.sh dev      - Start in development mode (nodemon)
# ============================================================

set -e

# --- Configuration ---
APP_NAME="Backend Perisai Nusantara"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ENTRY="app.js"
LOG_FILE="$APP_DIR/logs/server.log"
PID_FILE="$APP_DIR/logs/server.pid"
ENV_FILE="$APP_DIR/.env"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║     Backend Perisai Nusantara Server      ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_node() {
    if ! command -v node &> /dev/null; then
        log_error "Node.js tidak ditemukan! Silakan install Node.js terlebih dahulu."
        echo "  → https://nodejs.org/"
        exit 1
    fi
    local node_version=$(node -v)
    log_info "Node.js version: $node_version"
}

check_npm() {
    if ! command -v npm &> /dev/null; then
        log_error "npm tidak ditemukan!"
        exit 1
    fi
}

get_port() {
    if [ -f "$ENV_FILE" ]; then
        local port=$(grep -E "^PORT=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
        echo "${port:-5000}"
    else
        echo "5000"
    fi
}

get_pid() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        # Cek apakah PID masih aktif
        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
    fi
    echo ""
    return 1
}

ensure_dirs() {
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/data"
}

create_env_if_missing() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warn "File .env tidak ditemukan. Membuat file .env default..."
        # Generate random JWT secret
        local jwt_secret=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
        cat > "$ENV_FILE" <<EOF
# ====================================
# Backend Perisai Nusantara - Config
# ====================================

# Server
PORT=5000
HOST=0.0.0.0

# JWT
JWT_SECRET=${jwt_secret}
JWT_EXPIRES_IN=7d

# Database (SQLite file path, relative to project root)
DB_PATH=./data/perisai_nusantara.db
EOF
        log_info "File .env berhasil dibuat. Silakan edit sesuai kebutuhan."
    fi
}

# --- Commands ---

do_install() {
    log_info "Menginstall dependencies..."
    cd "$APP_DIR"
    check_node
    check_npm
    npm install --production
    log_info "Dependencies berhasil diinstall."
}

do_start() {
    cd "$APP_DIR"
    ensure_dirs
    create_env_if_missing

    local existing_pid=$(get_pid)
    if [ -n "$existing_pid" ]; then
        log_warn "Server sudah berjalan (PID: $existing_pid)"
        return 0
    fi

    # Cek apakah node_modules ada
    if [ ! -d "$APP_DIR/node_modules" ]; then
        log_warn "node_modules tidak ditemukan. Menjalankan npm install..."
        do_install
    fi

    local port=$(get_port)
    
    # Cek apakah port sudah dipakai
    if lsof -Pi :"$port" -sTCP:LISTEN -t &>/dev/null 2>&1 || ss -tlnp | grep -q ":$port " 2>/dev/null; then
        log_error "Port $port sudah digunakan oleh proses lain!"
        log_info "Gunakan perintah berikut untuk cek: lsof -i :$port"
        exit 1
    fi

    log_info "Starting $APP_NAME pada port $port..."
    
    # Jalankan server di background
    nohup node "$APP_ENTRY" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Tunggu sebentar dan verifikasi
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        log_info "Server berhasil dijalankan!"
        log_info "PID: $pid"
        log_info "URL: http://0.0.0.0:$port"
        log_info "Log: $LOG_FILE"
    else
        log_error "Server gagal start! Cek log: $LOG_FILE"
        cat "$LOG_FILE" | tail -20
        exit 1
    fi
}

do_stop() {
    local pid=$(get_pid)
    if [ -z "$pid" ]; then
        log_warn "Server tidak sedang berjalan."
        # Bersihkan PID file jika ada
        rm -f "$PID_FILE"
        return 0
    fi

    log_info "Menghentikan server (PID: $pid)..."
    kill "$pid" 2>/dev/null
    
    # Tunggu proses benar-benar berhenti
    local count=0
    while kill -0 "$pid" 2>/dev/null; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge 10 ]; then
            log_warn "Proses tidak merespons, force kill..."
            kill -9 "$pid" 2>/dev/null
            break
        fi
    done
    
    rm -f "$PID_FILE"
    log_info "Server berhasil dihentikan."
}

do_restart() {
    log_info "Restarting server..."
    do_stop
    sleep 1
    do_start
}

do_status() {
    local pid=$(get_pid)
    local port=$(get_port)
    
    echo ""
    if [ -n "$pid" ]; then
        log_info "Status: ${GREEN}RUNNING${NC}"
        log_info "PID: $pid"
        log_info "Port: $port"
        log_info "URL: http://0.0.0.0:$port"
        
        # Cek memory dan CPU
        if command -v ps &> /dev/null; then
            echo ""
            echo "  Resource Usage:"
            ps -p "$pid" -o pid,pcpu,pmem,etime,args --no-headers 2>/dev/null | while read line; do
                echo "  $line"
            done
        fi
        
        # Health check
        echo ""
        if command -v curl &> /dev/null; then
            local health=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health" 2>/dev/null || echo "000")
            if [ "$health" = "200" ]; then
                log_info "Health Check: ${GREEN}OK${NC}"
            else
                log_warn "Health Check: ${RED}FAILED (HTTP $health)${NC}"
            fi
        fi
    else
        log_info "Status: ${RED}STOPPED${NC}"
    fi
    echo ""
}

do_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        log_warn "File log belum ada."
        return 0
    fi
    log_info "Menampilkan log (Ctrl+C untuk keluar)..."
    echo "---"
    tail -f "$LOG_FILE"
}

do_dev() {
    cd "$APP_DIR"
    ensure_dirs
    create_env_if_missing
    check_node

    if [ ! -d "$APP_DIR/node_modules" ]; then
        log_warn "node_modules tidak ditemukan. Menjalankan npm install..."
        npm install
    fi

    log_info "Starting development server (nodemon)..."
    npx nodemon "$APP_ENTRY"
}

# --- Main ---

print_banner

case "${1:-}" in
    start)
        check_node
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        check_node
        do_restart
        ;;
    status)
        do_status
        ;;
    install)
        do_install
        ;;
    logs)
        do_logs
        ;;
    dev)
        do_dev
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|install|logs|dev}"
        echo ""
        echo "Commands:"
        echo "  start    - Jalankan server (production, background)"
        echo "  stop     - Hentikan server"
        echo "  restart  - Restart server"
        echo "  status   - Cek status server & health check"
        echo "  install  - Install dependencies (npm install)"
        echo "  logs     - Lihat log server (tail -f)"
        echo "  dev      - Jalankan development mode (nodemon)"
        echo ""
        exit 1
        ;;
esac
