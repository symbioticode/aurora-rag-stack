#!/usr/bin/env bash
#
# RAG-NixOS One-Command Installer (Native services)
# Usage: curl -sSL https://raw.githubusercontent.com/dravitch/rag-nixos/main/install.sh | sudo bash
#
# This script installs:
# - Ollama (native NixOS service)
# - Open WebUI (native NixOS service) 
# - Auto-downloads models
# - No Docker, no Podman, pure NixOS

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_NAME="${PROJECT_NAME:-myproject}"
NIXOS_CONFIG_DIR="/etc/nixos"

log() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
header() { echo -e "${CYAN}$1${NC}"; }

banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║          🧠 RAG-NixOS Native Installer                ║
║                                                       ║
║   Ollama + Open WebUI (100% Native NixOS)             ║
║   No Docker, No Podman, Pure Declarative              ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        log "Usage: sudo $0"
        exit 1
    fi
}

check_nixos() {
    if [[ ! -f /etc/os-release ]] || ! grep -q "NixOS" /etc/os-release; then
        error "This script requires NixOS"
        exit 1
    fi
    
    local version=$(nixos-version | cut -d. -f1-2 | head -1)
    success "NixOS $version detected"
    
    if [[ "$version" < "24.05" ]]; then
        warning "NixOS 24.05+ recommended (you have $version)"
        warning "services.open-webui requires NixOS 24.05+"
    fi
}

check_resources() {
    log "Checking system resources..."
    
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $ram_gb -lt 8 ]]; then
        warning "Low RAM: ${ram_gb}GB (8GB minimum, 16GB recommended)"
    else
        success "RAM: ${ram_gb}GB"
    fi
    
    if [[ $disk_gb -lt 10 ]]; then
        error "Insufficient disk space: ${disk_gb}GB (10GB minimum required)"
        exit 1
    else
        success "Disk space: ${disk_gb}GB available"
    fi
}

prompt_project_name() {
    echo ""
    log "Enter your project name (lowercase, no spaces):"
    read -p "Project name [myproject]: " input_name
    PROJECT_NAME="${input_name:-myproject}"
    
    # Sanitize
    PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    
    success "Project name: $PROJECT_NAME"
}

backup_config() {
    if [[ -f "$NIXOS_CONFIG_DIR/configuration.nix" ]]; then
        local backup_file="$NIXOS_CONFIG_DIR/configuration.nix.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$NIXOS_CONFIG_DIR/configuration.nix" "$backup_file"
        success "Backed up config to: $backup_file"
    fi
}

patch_configuration() {
    log "Patching configuration.nix..."
    
    local config_file="$NIXOS_CONFIG_DIR/configuration.nix"
    
    # Check if already configured
    if grep -q "services.open-webui" "$config_file"; then
        warning "services.open-webui already configured, skipping"
        return 0
    fi
    
    # Find the last closing brace
    local last_brace=$(grep -n "^}" "$config_file" | tail -1 | cut -d: -f1)
    
    if [[ -z "$last_brace" ]]; then
        error "Cannot find closing brace in configuration.nix"
        return 1
    fi
    
    # Create temporary file with additions
    cat > /tmp/rag-patch.nix << EOF

  # ============================================
  # RAG-NixOS - Native services
  # Installed: $(date)
  # ============================================
  
  # Ollama LLM service (native NixOS)
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    acceleration = null;  # Set to "cuda" or "rocm" for GPU
    
    environmentVariables = {
      OLLAMA_MODELS = "/var/lib/${PROJECT_NAME}-rag/ollama/models";
    };
  };
  
  # Open WebUI service (native NixOS)
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 3000;
    
    environment = {
      # Connection to Ollama
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      
      # Privacy settings
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      
      # Authentication (false for local dev, true for production)
      WEBUI_AUTH = "False";
    };
  };
  
  # Create data directories
  systemd.tmpfiles.rules = [
    "d /var/lib/${PROJECT_NAME}-rag 0755 root root -"
    "d /var/lib/${PROJECT_NAME}-rag/ollama 0755 ollama ollama -"
    "d /var/lib/${PROJECT_NAME}-rag/ollama/models 0755 ollama ollama -"
    "d /var/docs/${PROJECT_NAME} 0755 root root -"
    "d /var/docs/${PROJECT_NAME}/architecture 0755 root root -"
    "d /var/docs/${PROJECT_NAME}/guides 0755 root root -"
    "d /var/docs/${PROJECT_NAME}/reference 0755 root root -"
    "d /var/docs/${PROJECT_NAME}/projects 0755 root root -"
  ];
  
  # Auto-download models service
  systemd.services.rag-pull-models = {
    description = "Download default Ollama models";
    after = [ "ollama.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    script = ''
      # Wait for Ollama service
      echo "Waiting for Ollama..."
      for i in {1..60}; do
        if \${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
          echo "Ollama is ready"
          break
        fi
        sleep 1
      done
      
      # Download mistral if missing
      if ! \${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags | \${pkgs.jq}/bin/jq -e '.models[]? | select(.name | startswith("mistral"))' > /dev/null 2>&1; then
        echo "Downloading mistral:7b..."
        \${pkgs.ollama}/bin/ollama pull mistral:7b
      fi
      
      # Download embeddings model
      if ! \${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags | \${pkgs.jq}/bin/jq -e '.models[]? | select(.name | startswith("nomic-embed-text"))' > /dev/null 2>&1; then
        echo "Downloading nomic-embed-text..."
        \${pkgs.ollama}/bin/ollama pull nomic-embed-text
      fi
      
      echo "Models ready"
    '';
  };
  
  # Firewall configuration
  networking.firewall.allowedTCPPorts = [ 
    3000    # Open WebUI
    # 11434  # Ollama - opened automatically by services.ollama
  ];
  
  # Useful packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    jq
    ollama  # CLI tool
  ];
  
  # Status script
  environment.etc."${PROJECT_NAME}-rag/status.sh" = {
    text = ''
      #!/usr/bin/env bash
      echo "🔍 RAG System Status - ${PROJECT_NAME}"
      echo "===================================="
      echo ""
      
      echo "📦 Ollama Service:"
      systemctl status ollama.service --no-pager | grep -E "Active:|Loaded:" | head -2
      
      if systemctl is-active --quiet ollama.service; then
        echo "Available models:"
        curl -s http://localhost:11434/api/tags 2>/dev/null | jq -r '.models[]?.name' | while read model; do
          echo "  ✓ \$model"
        done || echo "  (no models or API not responding)"
      fi
      echo ""
      
      echo "🌐 Open WebUI Service:"
      systemctl status open-webui.service --no-pager | grep -E "Active:|Loaded:" | head -2
      echo ""
      
      echo "🔗 Access URLs:"
      echo "  Open WebUI:    http://localhost:3000"
      echo "  Ollama API:    http://localhost:11434"
      echo ""
      
      echo "📁 Data locations:"
      echo "  Models:        /var/lib/${PROJECT_NAME}-rag/ollama/models"
      echo "  Documentation: /var/docs/${PROJECT_NAME}/"
      echo ""
      
      echo "🔧 Commands:"
      echo "  Pull model:    ollama pull <model>"
      echo "  View logs:     journalctl -u open-webui -f"
      echo "  Restart:       systemctl restart ollama open-webui"
    '';
    mode = "0755";
  };
EOF
    
    # Insert patch before last closing brace
    head -n $((last_brace - 1)) "$config_file" > /tmp/config-temp.nix
    cat /tmp/rag-patch.nix >> /tmp/config-temp.nix
    tail -n +$last_brace "$config_file" >> /tmp/config-temp.nix
    mv /tmp/config-temp.nix "$config_file"
    
    success "Configuration patched"
}

rebuild_system() {
    log "Rebuilding NixOS configuration..."
    warning "This may take 5-10 minutes (downloading models and services)"
    echo ""
    
    # Update channels first
    nix-channel --update || true
    
    # Rebuild
    if nixos-rebuild switch --upgrade; then
        success "System rebuilt successfully"
    else
        error "System rebuild failed"
        log "Check logs: journalctl -xe"
        log "Or try manually: sudo nixos-rebuild switch --show-trace"
        exit 1
    fi
}

verify_installation() {
    log "Verifying installation..."
    echo ""
    
    sleep 5  # Give services time to start
    
    # Check Ollama
    header "📦 Checking Ollama..."
    if systemctl is-active --quiet ollama.service; then
        success "Ollama service is running"
    else
        error "Ollama service not running"
        log "Check: journalctl -u ollama.service -n 50"
        return 1
    fi
    
    # Check Open WebUI
    header "🌐 Checking Open WebUI..."
    if systemctl is-active --quiet open-webui.service; then
        success "Open WebUI service is running"
    else
        error "Open WebUI service not running"
        log "Check: journalctl -u open-webui.service -n 50"
        return 1
    fi
    
    # Check Ollama API
    header "🔌 Checking Ollama API..."
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        success "Ollama API is accessible"
        
        local models=$(curl -s http://localhost:11434/api/tags | jq -r '.models[]?.name' 2>/dev/null)
        if [[ -n "$models" ]]; then
            success "Models available:"
            echo "$models" | while read model; do
                echo "    ✓ $model"
            done
        else
            warning "No models downloaded yet (may still be downloading)"
        fi
    else
        warning "Ollama API not yet accessible (may still be starting)"
    fi
    
    # Check Open WebUI port
    header "🌐 Checking Open WebUI port..."
    if ss -tlnp | grep -q ":3000"; then
        success "Open WebUI listening on port 3000"
    else
        warning "Open WebUI not yet listening (may still be starting)"
    fi
    
    # Check network accessibility
    header "🔗 Checking network access..."
    local ip=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null)
    if [[ -n "$ip" ]]; then
        if timeout 3 curl -sf http://$ip:3000 > /dev/null 2>&1; then
            success "Open WebUI accessible via network at http://$ip:3000"
        else
            warning "Open WebUI may not be accessible via network yet"
        fi
    fi
}

run_final_checks() {
    log "Running final checks..."
    echo ""
    
    # Check if models are still downloading
    if systemctl is-active --quiet rag-pull-models.service; then
        warning "Models are still downloading in background"
        log "Check progress: journalctl -u rag-pull-models.service -f"
    fi
    
    # Check for errors
    local ollama_errors=$(journalctl -u ollama.service -n 50 --no-pager | grep -i "error\|failed" | grep -v "level=INFO" || true)
    if [[ -n "$ollama_errors" ]]; then
        warning "Some errors detected in Ollama logs"
        echo "$ollama_errors" | head -3
    fi
    
    local webui_errors=$(journalctl -u open-webui.service -n 50 --no-pager | grep -i "error\|failed\|exception" || true)
    if [[ -n "$webui_errors" ]]; then
        warning "Some messages in Open WebUI logs"
        echo "$webui_errors" | head -3
    fi
}

print_summary() {
    local ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo ""
    cat << EOF
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║          ✅ Installation Complete!                    ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

🎉 Your RAG system is ready!

🌐 Access URLs:
   Local:    http://localhost:3000
   Network:  http://${ip}:3000

📦 Services (Native NixOS):
   • Ollama (port 11434) - systemd service
   • Open WebUI (port 3000) - systemd service

📁 Data directories:
   Models:   /var/lib/${PROJECT_NAME}-rag/ollama/models
   Docs:     /var/docs/${PROJECT_NAME}/

🔧 Useful commands:
   Status:   sudo /etc/${PROJECT_NAME}-rag/status.sh
   Logs:     journalctl -u open-webui.service -f
   Restart:  sudo systemctl restart ollama open-webui

📚 Next steps:
   1. Open http://localhost:3000 in your browser
   2. Wait for models to finish downloading (~5 min)
   3. Upload your documents via Documents tab
   4. Start chatting with your knowledge base!

💡 Pro tip: Run status check:
   sudo /etc/${PROJECT_NAME}-rag/status.sh

EOF
}

main() {
    banner
    echo ""
    
    check_root
    check_nixos
    check_resources
    prompt_project_name
    
    echo ""
    log "Starting installation..."
    echo ""
    
    backup_config
    patch_configuration
    rebuild_system
    
    echo ""
    verify_installation
    run_final_checks
    
    print_summary
}

# Handle interruption
trap 'error "Installation interrupted"; exit 130' INT TERM

main "$@"
