#!/usr/bin/env bash
# =============================================================================
# AURORA RAG STACK - Installation Script for Debian 12
# =============================================================================
# Version: 1.0.0
# Target: HP ProDesk G3 Mini (8GB RAM, 256GB SSD)
# OS: Debian 12 (Bookworm)
# Date: 2025-12-26
#
# Usage:
#   sudo ./aurora-rag-install-debian12.sh
#
# What gets installed:
#   - Ollama (LLM runtime)
#   - litellm (model proxy)
#   - ChromaDB (vector database)
#   - OpenWebUI (interface + RAG)
#   - Jupyter (kernel + notebooks)
#   - Monitoring tools
#
# Frugality targets:
#   - RAM idle: <2GB
#   - RAM active: <4GB
#   - Disk: <10GB
#   - CPU idle: <5%
# =============================================================================

set -euo pipefail

readonly VERSION="1.0.0"
readonly INSTALL_DIR="/opt/aurora-rag"
readonly DATA_DIR="/var/lib/aurora-rag"
readonly DOCS_DIR="/var/docs/aurora"
readonly LOG_FILE="/var/log/aurora-rag-install.log"

readonly MIN_RAM_GB=7
readonly MIN_DISK_GB=15

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    echo -e "${BLUE}➜${NC} $*"
    echo "$msg" >> "$LOG_FILE"
}

success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*"
    echo -e "${GREEN}✓${NC} $*"
    echo "$msg" >> "$LOG_FILE"
}

warning() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*"
    echo -e "${YELLOW}⚠ ${NC} $*"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*"
    echo -e "${RED}✗${NC} $*" >&2
    echo "$msg" >> "$LOG_FILE"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    success "Running as root"
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS (missing /etc/os-release)"
    fi
    
    local os_id=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    local os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    
    if [[ "$os_id" != "debian" ]]; then
        error "This script requires Debian (detected: $os_id)"
    fi
    
    local version_major="${os_version%%.*}"
    if [[ "$version_major" -ne 12 ]]; then
        error "This script requires Debian 12 (detected: Debian $os_version)"
    fi
    
    success "Debian $os_version detected"
}

check_hardware() {
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -lt $MIN_RAM_GB ]]; then
        error "Insufficient RAM: ${ram_gb}GB (minimum: ${MIN_RAM_GB}GB)"
    fi
    success "RAM: ${ram_gb}GB (sufficient)"
    
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        error "Insufficient disk space: ${disk_gb}GB (minimum: ${MIN_DISK_GB}GB)"
    fi
    success "Disk space: ${disk_gb}GB available"
    
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 2 ]]; then
        warning "Only $cpu_cores CPU cores detected (recommended: 4+)"
    else
        success "CPU cores: $cpu_cores"
    fi
}

check_network() {
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        error "No internet connection (required for installation)"
    fi
    success "Internet connection OK"
}

create_directories() {
    log "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"/{scripts,config}
    mkdir -p "$DATA_DIR"/{ollama,chromadb,cache,openwebui,jupyter}
    mkdir -p "$DOCS_DIR"/{anthill,aurora,bome}
    mkdir -p /var/log/aurora-rag
    
    success "Directories created"
}

install_system_deps() {
    log "Installing system dependencies..."
    
    apt-get update -qq
    
    log "Installing Python 3.11 (Debian 12 native)..."
    apt-get install -y -qq \
        python3 \
        python3-venv \
        python3-dev \
        python3-pip
    
    local py_version=$(python3 --version | awk '{print $2}')
    log "System Python: $py_version"
    
    if [[ ! "$py_version" =~ ^3\.11\. ]]; then
        error "Expected Python 3.11.x, got $py_version"
    fi
    
    apt-get install -y -qq \
        curl \
        wget \
        git \
        build-essential \
        jq \
        htop \
        sysstat \
        sqlite3
    
    success "System dependencies installed (Python $py_version)"
}

install_ollama() {
    log "Installing Ollama..."
    
    if command -v ollama &>/dev/null; then
        warning "Ollama already installed, skipping"
        return
    fi
    
    curl -fsSL https://ollama.com/install.sh | sh
    
    if ! command -v ollama &>/dev/null; then
        error "Ollama installation failed"
    fi
    
    success "Ollama installed: $(ollama --version | head -1)"
}

configure_ollama_service() {
    log "Configuring Ollama systemd service..."
    
    cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/var/lib/aurora-rag/ollama/models"
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ollama.service
    systemctl start ollama.service
    
    log "Waiting for Ollama to start..."
    for i in {1..30}; do
        if curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
            success "Ollama service ready"
            return
        fi
        sleep 1
    done
    
    error "Ollama failed to start (timeout)"
}

download_ollama_models() {
    log "Downloading Ollama models..."
    log "This may take 10-15 minutes depending on connection speed"
    
    log "Downloading mistral:7b..."
    if ollama pull mistral:7b; then
        success "mistral:7b downloaded"
    else
        error "Failed to download mistral:7b"
    fi
    
    log "Downloading nomic-embed-text..."
    if ollama pull nomic-embed-text; then
        success "nomic-embed-text downloaded"
    else
        error "Failed to download nomic-embed-text"
    fi
}

setup_python_venv() {
    log "Setting up Python virtual environment..."
    
    python3 -m venv "$INSTALL_DIR/venv"
    
    source "$INSTALL_DIR/venv/bin/activate"
    
    local py_version=$(python --version | awk '{print $2}')
    log "Using Python $py_version"
    
    if [[ ! "$py_version" =~ ^3\.11\. ]]; then
        error "Wrong Python version in venv: $py_version (expected 3.11.x)"
    fi
    
    pip install --quiet --upgrade pip setuptools wheel
    
    success "Python venv created with Python $py_version"
}

install_python_deps() {
    log "Installing Python dependencies..."
    
    source "$INSTALL_DIR/venv/bin/activate"
    
    log "Installing chromadb, litellm[proxy], jupyter..."
    pip install --quiet \
        chromadb \
        'litellm[proxy]' \
        psutil \
        pyyaml \
        requests \
        jupyter \
        ipykernel \
        notebook
    
    log "Installing open-webui..."
    if pip install open-webui; then
        success "open-webui installed successfully"
    else
        error "Failed to install open-webui"
    fi
    
    python -m ipykernel install --user --name=aurora-rag --display-name="AURORA RAG (Python 3.11)"
    
    success "Python dependencies installed"
}

configure_litellm() {
    log "Configuring litellm proxy..."
    
    cat > "$INSTALL_DIR/config/litellm.yaml" << 'EOF'
model_list:
  - model_name: mistral
    litellm_params:
      model: ollama/mistral:7b
      api_base: http://127.0.0.1:11434
  
  - model_name: nomic-embed
    litellm_params:
      model: ollama/nomic-embed-text
      api_base: http://127.0.0.1:11434

general_settings:
  cache: true
  cache_params:
    type: disk
    disk_cache_dir: /var/lib/aurora-rag/cache
EOF
    
    success "litellm configured (no auth for local use)"
}

create_litellm_service() {
    log "Creating litellm systemd service..."
    
    cat > /etc/systemd/system/litellm.service << EOF
[Unit]
Description=litellm Proxy Service
After=ollama.service
Requires=ollama.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$INSTALL_DIR/venv/bin/litellm --config $INSTALL_DIR/config/litellm.yaml --port 4000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable litellm.service
    systemctl start litellm.service
    
    sleep 3
    
    if systemctl is-active --quiet litellm.service; then
        success "litellm service started"
    else
        warning "litellm service may not be running (check logs)"
    fi
}

configure_openwebui() {
    log "Configuring OpenWebUI..."
    
    cat > "$INSTALL_DIR/config/openwebui.env" << 'EOF'
OLLAMA_BASE_URL=http://127.0.0.1:11434
WEBUI_AUTH=False
DATA_DIR=/var/lib/aurora-rag/openwebui
ENABLE_RAG_WEB_SEARCH=False
ENABLE_IMAGE_GENERATION=False
ENABLE_COMMUNITY_SHARING=False
WEBUI_NAME=AURORA RAG Stack
EOF
    
    success "OpenWebUI configured"
}

create_openwebui_service() {
    log "Creating OpenWebUI systemd service..."
    
    cat > /etc/systemd/system/openwebui.service << EOF
[Unit]
Description=OpenWebUI Service
After=ollama.service litellm.service
Requires=ollama.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$INSTALL_DIR/config/openwebui.env
ExecStart=$INSTALL_DIR/venv/bin/open-webui serve --host 0.0.0.0 --port 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable openwebui.service
    systemctl start openwebui.service
    
    sleep 5
    
    if systemctl is-active --quiet openwebui.service; then
        success "OpenWebUI service started"
    else
        warning "OpenWebUI service may not be running (check logs)"
    fi
}

configure_jupyter() {
    log "Configuring Jupyter..."
    
    cat > "$INSTALL_DIR/config/jupyter_config.py" << 'EOF'
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.port = 8888
c.NotebookApp.open_browser = False
c.NotebookApp.token = ''
c.NotebookApp.password = ''
c.NotebookApp.notebook_dir = '/var/lib/aurora-rag/jupyter'
c.NotebookApp.allow_root = True
EOF
    
    success "Jupyter configured"
}

create_jupyter_service() {
    log "Creating Jupyter systemd service..."
    
    cat > /etc/systemd/system/jupyter.service << EOF
[Unit]
Description=Jupyter Notebook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR/jupyter
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$INSTALL_DIR/venv/bin/jupyter notebook --config=$INSTALL_DIR/config/jupyter_config.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable jupyter.service
    systemctl start jupyter.service
    
    sleep 3
    
    if systemctl is-active --quiet jupyter.service; then
        success "Jupyter service started"
    else
        warning "Jupyter service may not be running (check logs)"
    fi
}

create_jupyter_sample() {
    log "Creating sample Jupyter notebook..."
    
    cat > "$DATA_DIR/jupyter/aurora-rag-test.ipynb" << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# AURORA RAG Stack - Test Notebook\n",
    "\n",
    "Test notebook for AURORA RAG integration."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import requests\n",
    "\n",
    "response = requests.get('http://localhost:11434/api/tags')\n",
    "print(\"Ollama Models:\")\n",
    "for model in response.json()['models']:\n",
    "    print(f\"  - {model['name']}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import sys\n",
    "print(f\"Python version: {sys.version}\")\n",
    "print(f\"Python executable: {sys.executable}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import chromadb\n",
    "\n",
    "client = chromadb.Client()\n",
    "print(\"ChromaDB initialized successfully\")"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "AURORA RAG (Python 3.11)",
   "language": "python",
   "name": "aurora-rag"
  },
  "language_info": {
   "name": "python",
   "version": "3.11"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF
    
    success "Sample notebook created"
}

create_monitoring_script() {
    log "Creating monitoring script..."
    
    cat > "$INSTALL_DIR/scripts/monitor.py" << 'PYEOF'
#!/usr/bin/env python3
import psutil
import time
from datetime import datetime
from pathlib import Path

class AuroraMonitor:
    def __init__(self):
        self.output = Path("/var/lib/aurora-rag/metrics.txt")
        self.targets = {
            'ram_idle_mb': 2000,
            'ram_active_mb': 4000,
            'cpu_idle_percent': 5,
            'disk_total_gb': 10
        }
    
    def collect(self):
        mem = psutil.virtual_memory()
        cpu = psutil.cpu_percent(interval=1)
        disk = psutil.disk_usage('/var/lib/aurora-rag')
        
        return {
            'timestamp': datetime.now().isoformat(),
            'ram_mb': round(mem.used / 1024 / 1024, 1),
            'ram_percent': mem.percent,
            'cpu_percent': round(cpu, 1),
            'disk_gb': round(disk.used / 1024 / 1024 / 1024, 2),
            'disk_percent': round(disk.percent, 1)
        }
    
    def format_output(self, m):
        ram_status = '✓ GOOD' if m['ram_mb'] < self.targets['ram_idle_mb'] else '⚠ HIGH'
        cpu_status = '✓ GOOD' if m['cpu_percent'] < self.targets['cpu_idle_percent'] else '⚠ HIGH'
        disk_status = '✓ GOOD' if m['disk_gb'] < self.targets['disk_total_gb'] else '⚠ HIGH'
        
        lines = [
            f"AURORA RAG Stack - Frugality Metrics",
            f"Updated: {m['timestamp']}",
            "=" * 60,
            "",
            f"Memory:     {m['ram_mb']} MB ({m['ram_percent']}%) - {ram_status}",
            f"Target:     < {self.targets['ram_idle_mb']} MB idle",
            "",
            f"CPU:        {m['cpu_percent']}% - {cpu_status}",
            f"Target:     < {self.targets['cpu_idle_percent']}% idle",
            "",
            f"Disk:       {m['disk_gb']} GB ({m['disk_percent']}%) - {disk_status}",
            f"Target:     < {self.targets['disk_total_gb']} GB total"
        ]
        
        return '\n'.join(lines)
    
    def run_once(self):
        metrics = self.collect()
        output = self.format_output(metrics)
        self.output.write_text(output)
        return metrics

if __name__ == '__main__':
    monitor = AuroraMonitor()
    while True:
        try:
            monitor.run_once()
            time.sleep(30)
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(30)
PYEOF
    
    chmod +x "$INSTALL_DIR/scripts/monitor.py"
    
    success "Monitoring script created"
}

create_monitoring_service() {
    log "Creating monitoring systemd service..."
    
    cat > /etc/systemd/system/aurora-monitor.service << EOF
[Unit]
Description=AURORA RAG Metrics Monitor
After=ollama.service

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/scripts/monitor.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable aurora-monitor.service
    systemctl start aurora-monitor.service
    
    success "Monitoring service started"
}

create_utility_scripts() {
    log "Creating utility scripts..."
    
    cat > "$INSTALL_DIR/scripts/status.sh" << 'EOF'
#!/usr/bin/env bash

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "  AURORA RAG Stack - System Status"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "📊 Services Status:"
systemctl status ollama --no-pager | grep "Active:" | sed 's/^/  Ollama:     /'
systemctl status litellm --no-pager | grep "Active:" | sed 's/^/  litellm:    /'
systemctl status openwebui --no-pager | grep "Active:" | sed 's/^/  OpenWebUI:  /'
systemctl status jupyter --no-pager | grep "Active:" | sed 's/^/  Jupyter:    /'
systemctl status aurora-monitor --no-pager | grep "Active:" | sed 's/^/  Monitor:    /'

echo ""
echo "📈 Frugality Metrics:"
cat /var/lib/aurora-rag/metrics.txt 2>/dev/null || echo "  (metrics not available yet)"

echo ""
echo "📦 Ollama Models:"
ollama list 2>/dev/null | sed 's/^/  /'

echo ""
EOF
    
    chmod +x "$INSTALL_DIR/scripts/status.sh"
    
    cat > "$INSTALL_DIR/scripts/logs.sh" << 'EOF'
#!/usr/bin/env bash

SERVICE="${1:-openwebui}"

case "$SERVICE" in
    ollama)
        journalctl -u ollama.service -f
        ;;
    litellm)
        journalctl -u litellm.service -f
        ;;
    openwebui|webui)
        journalctl -u openwebui.service -f
        ;;
    jupyter)
        journalctl -u jupyter.service -f
        ;;
    monitor)
        journalctl -u aurora-monitor.service -f
        ;;
    *)
        echo "Usage: $0 {ollama|litellm|openwebui|jupyter|monitor}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/scripts/logs.sh"
    
    success "Utility scripts created"
}

create_sample_docs() {
    log "Creating sample documentation..."
    
    cat > "$DOCS_DIR/README.md" << 'EOF'
# AURORA RAG Stack - Documentation

Welcome to your AURORA RAG Stack documentation directory.

## Structure

```
/var/docs/aurora/
├── anthill/     # ANTHILL infrastructure docs
├── aurora/      # AURORA Compute standards
└── bome/        # BOME financial strategies
```

## Usage

1. Add your Markdown documentation to appropriate directories
2. Documents are automatically indexed by OpenWebUI
3. Ask questions via chat interface at http://localhost:8080

## Next Steps

- Import your existing documentation
- Test RAG queries via OpenWebUI
- Monitor frugality metrics: `cat /var/lib/aurora-rag/metrics.txt`
EOF
    
    success "Sample documentation created"
}

validate_installation() {
    log "Validating installation..."
    
    local errors=0
    
    if ! curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
        warning "Ollama API not responding"
        ((errors++))
    else
        success "Ollama API: OK"
    fi
    
    if ! systemctl is-active --quiet litellm.service; then
        warning "litellm service not running"
        ((errors++))
    else
        success "litellm service: OK"
    fi
    
    if ! systemctl is-active --quiet openwebui.service; then
        warning "OpenWebUI service not running"
        ((errors++))
    else
        success "OpenWebUI service: OK"
    fi
    
    if ! systemctl is-active --quiet jupyter.service; then
        warning "Jupyter service not running"
        ((errors++))
    else
        success "Jupyter service: OK"
    fi
    
    if ! systemctl is-active --quiet aurora-monitor.service; then
        warning "Monitor service not running"
        ((errors++))
    else
        success "Monitor service: OK"
    fi
    
    local models=$(ollama list 2>/dev/null | grep -c "mistral\|nomic-embed" || echo "0")
    if [[ $models -lt 2 ]]; then
        warning "Not all models downloaded (expected 2, found $models)"
        ((errors++))
    else
        success "Ollama models: OK ($models models)"
    fi
    
    if [[ $errors -gt 0 ]]; then
        warning "Installation completed with $errors warnings"
        return 1
    else
        success "All validation checks passed"
        return 0
    fi
}

print_summary() {
    local ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    cat << EOF

╔═══════════════════════════════════════════════════════════════════╗
║           ✓ AURORA RAG Stack Installation Complete               ║
╚═══════════════════════════════════════════════════════════════════╝

📦 Installed Components:
   ✓ Ollama        (port 11434)
   ✓ litellm       (port 4000)
   ✓ ChromaDB      (embedded)
   ✓ OpenWebUI     (port 8080)
   ✓ Jupyter       (port 8888)
   ✓ Monitoring    (active)

🌐 Access URLs:
   OpenWebUI:     http://localhost:8080
                  http://${ip}:8080
   
   Jupyter:       http://localhost:8888
                  http://${ip}:8888
   
   Ollama API:    http://localhost:11434
   litellm Proxy: http://localhost:4000

📁 Important Paths:
   Installation:  $INSTALL_DIR
   Data:          $DATA_DIR
   Docs:          $DOCS_DIR
   Logs:          /var/log/aurora-rag

🔧 Useful Commands:
   Status:        $INSTALL_DIR/scripts/status.sh
   View logs:     $INSTALL_DIR/scripts/logs.sh [service]
   Metrics:       cat /var/lib/aurora-rag/metrics.txt
   
   Restart all:   systemctl restart ollama litellm openwebui jupyter
   Stop all:      systemctl stop ollama litellm openwebui jupyter

📊 Frugality Targets:
   RAM idle:      < 2GB
   RAM active:    < 4GB
   CPU idle:      < 5%
   Disk total:    < 10GB

🎯 Next Steps:
   1. Open http://localhost:8080 in your browser
   2. Start chatting with the AI (no auth required by default)
   3. Upload documents via Documents → Upload
   4. Monitor frugality: $INSTALL_DIR/scripts/status.sh

📖 Documentation:
   Installation log:  $LOG_FILE
   Sample docs:       $DOCS_DIR/README.md

╔═══════════════════════════════════════════════════════════════════╗
║  AURORA RAG Stack v$VERSION - Frugal, Local, Open                ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
}

main() {
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║        AURORA RAG Stack - Installation for Debian 12             ║"
    echo "║                     Version $VERSION                                  ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log "Starting installation..."
    log "Target: HP ProDesk G3 Mini (8GB RAM, 256GB SSD)"
    
    check_root
    check_os
    check_hardware
    check_network
    
    create_directories
    install_system_deps
    
    install_ollama
    configure_ollama_service
    download_ollama_models
    
    setup_python_venv
    install_python_deps
    
    configure_litellm
    create_litellm_service
    configure_openwebui
    create_openwebui_service
    configure_jupyter
    create_jupyter_service
    create_jupyter_sample
    
    create_monitoring_script
    create_monitoring_service
    
    create_utility_scripts
    create_sample_docs
    
    sleep 5
    if validate_installation; then
        success "Installation completed successfully"
    else
        warning "Installation completed with warnings (check logs)"
    fi
    
    print_summary
    
    log "Installation finished at $(date)"
}

main "$@"
