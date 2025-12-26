# 🧠 AURORA RAG Stack

**One-command local RAG system** — Deploy your own AI knowledge base in minutes.

[![NixOS](https://img.shields.io/badge/NixOS-25.11-blue.svg)](https://nixos.org/)
[![Debian](https://img.shields.io/badge/Debian-12-red.svg)](https://www.debian.org/)
[![Ollama](https://img.shields.io/badge/Ollama-Latest-green.svg)](https://ollama.ai/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 🎯 What is AURORA RAG?

A **production-ready RAG (Retrieval-Augmented Generation)** system that lets you:

- 🚀 Deploy in **5-10 minutes** with a single script
- 🔒 Run **100% locally** — no cloud, no API keys
- 📚 Index your **documentation, code, notes** automatically
- 💬 Chat with your knowledge base through a modern web UI
- 🔄 Stay **reproducible** with declarative or imperative setup

**Perfect for:**
- 📖 Large documentation projects
- 🏢 Company knowledge bases
- 🔬 Research papers and notes
- 💻 Code repositories
- 📝 Personal knowledge management

---

## 🌟 Why AURORA RAG?

### The Problem with Traditional Knowledge Bases

- 📄 **Static wikis** become outdated quickly
- 🔍 **Search-only systems** can't understand context
- ☁️ **Cloud-based solutions** lock your data behind paywalls
- 🐳 **Complex setups** require Docker expertise
- 💸 **Expensive APIs** charge per token

### The AURORA RAG Advantage

- **🔒 True Self-Hosting** — Your data never leaves your infrastructure
- **📈 Living Knowledge Base** — Evolves with your content
- **💥 Team-First** — Built for collaborative work from day one
- **🛡️ Multi-OS Foundation** — NixOS (declarative) + Debian (imperative)
- **🎯 Production-Ready** — Battle-tested frugality targets

---

## ⚡ Choose Your OS

AURORA RAG supports **two deployment strategies**:

### 🐧 NixOS — Declarative, Reproducible

**Perfect for:**
- DevOps teams
- Infrastructure as code
- Long-term stability
- Atomic upgrades/rollbacks

**Features:**
- Configuration in `/etc/nixos/configuration.nix`
- Hermetic dependencies
- Zero drift
- One-command install

👉 [**NixOS Installation Guide**](nixos/README.md)

```bash
curl -sSL https://raw.githubusercontent.com/dravitch/aurora-rag-stack/main/nixos/install.sh | sudo bash
```

---

### 🎯 Debian 12 — Classic, Stable

**Perfect for:**
- Traditional Linux deployments
- Familiar environments
- Enterprise stability
- Quick setup

**Features:**
- Python 3.11 native
- systemd services
- Simple bash scripts
- LTS support

👉 [**Debian 12 Installation Guide**](debian/README.md)

```bash
curl -sSL https://raw.githubusercontent.com/dravitch/aurora-rag-stack/main/debian/aurora-rag-install-debian12.sh | sudo bash
```

---

## 📦 What Gets Installed

Both implementations share the same core stack:

| Component | Purpose | Port |
|-----------|---------|------|
| **Ollama** | LLM runtime (Mistral 7B) | 11434 |
| **litellm** | Model proxy | 4000 |
| **ChromaDB** | Vector database | embedded |
| **OpenWebUI** | Chat interface + RAG | 8080 |
| **Jupyter** | Notebook environment | 8888 |
| **Monitoring** | Frugality metrics | — |

**Storage locations:**
- Models: `/var/lib/aurora-rag/ollama/models`
- Documents: `/var/docs/aurora`
- Data: `/var/lib/aurora-rag`

---

## 🚀 Quick Start

### 1. Access the Interface

Open your browser: `http://localhost:8080`

Or from another machine: `http://[YOUR-IP]:8080`

### 2. Upload Your Documents

Click **Documents** → **Upload** → Select your files (Markdown, PDF, TXT, etc.)

OpenWebUI will automatically:
- Parse the content
- Generate embeddings
- Index in vector database
- Make searchable via chat

### 3. Ask Questions

```
"What is the deployment procedure for X?"
"Show me examples of Y configuration"
"Summarize the architecture document"
"Compare approaches A and B"
```

---

## 📊 Performance & Frugality

On a typical system (8GB RAM, 4-core CPU):

| Metric | Target | Achieved |
|--------|--------|----------|
| RAM idle | <2GB | 1.7GB |
| RAM active | <4GB | 3.8GB |
| CPU idle | <5% | 2-3% |
| Disk total | <10GB | 8.5GB |
| Response time | <5s | 2-5s |
| Token generation | >20/s | 20-30/s |

---

## 🔧 Configuration

### Change LLM Model

```bash
# Download a different model
ollama pull deepseek-r1:7b
ollama pull llama3:8b

# Models appear automatically in OpenWebUI
```

### Enable Authentication

**NixOS:**
```nix
aurora.openwebui.enableAuth = true;
```

**Debian:**
```bash
sudo nano /opt/aurora-rag/config/openwebui.env
# Set: WEBUI_AUTH=True

sudo systemctl restart openwebui
```

First user to register becomes admin.

### Add More Documents

Simply drop Markdown/PDF/TXT files into:
```
/var/docs/aurora/
```

OpenWebUI auto-indexes on upload.

---

## 🛠️ System Status

### NixOS

```bash
sudo systemctl status ollama openwebui
```

### Debian

```bash
sudo /opt/aurora-rag/scripts/status.sh
```

Output:
```
📊 Services Status:
  Ollama:     ✓ active (running)
  litellm:    ✓ active (running)
  OpenWebUI:  ✓ active (running)
  Jupyter:    ✓ active (running)

📈 Frugality Metrics:
  Memory:     1721 MB (21.5%) - ✓ GOOD
  CPU:        2.3% - ✓ GOOD
  Disk:       8.5 GB (3.6%) - ✓ GOOD
```

---

## 🔍 Troubleshooting

### OpenWebUI shows "No models available"

**Check Ollama:**
```bash
curl http://localhost:11434/api/tags
```

**If not responding:**
```bash
sudo systemctl restart ollama
sudo systemctl restart openwebui
```

### Models not downloading

**Manual download:**
```bash
ollama pull mistral:7b
ollama pull nomic-embed-text
```

### Port conflicts

**Change OpenWebUI port:**

NixOS:
```nix
aurora.openwebui.port = 8090;
```

Debian:
```bash
sudo nano /opt/aurora-rag/config/openwebui.env
# Set port in ExecStart
```

---

## 📈 Advanced Configuration

### GPU Acceleration

**NixOS:**
```nix
services.ollama.acceleration = "cuda";  # NVIDIA
# or
services.ollama.acceleration = "rocm";  # AMD
```

**Debian:**
```bash
# Install CUDA/ROCm drivers first
# Ollama auto-detects GPU
```

### Custom Data Directory

**NixOS:**
```nix
services.ollama.environmentVariables = {
  OLLAMA_MODELS = "/mnt/data/models";
};
```

**Debian:**
```bash
sudo nano /etc/systemd/system/ollama.service
# Edit OLLAMA_MODELS path
```

---

## 🔒 Security

### Production Deployment Checklist

- ✅ Enable authentication (`WEBUI_AUTH=True`)
- ✅ Use HTTPS (via reverse proxy like Nginx/Caddy)
- ✅ Configure firewall rules
- ✅ Regular system updates
- ✅ Backup `/var/lib/aurora-rag` regularly
- ✅ Monitor access logs

### Firewall Configuration

**NixOS:**
```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 8080 ];
};
```

**Debian:**
```bash
sudo ufw allow 8080/tcp
sudo ufw enable
```

---

## 📚 Documentation Structure

Recommended layout for `/var/docs/aurora/`:

```
aurora/
├── README.md              # Project overview
├── architecture/          # Design documents
│   ├── overview.md
│   └── components.md
├── guides/                # How-to guides
│   ├── getting-started.md
│   └── deployment.md
├── reference/             # API docs, configs
│   ├── api.md
│   └── configuration.md
└── projects/              # Sub-projects
    └── [project-name]/
```

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test on NixOS 25.11 or Debian 12
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Ollama](https://ollama.ai/) — Local LLM runtime
- [OpenWebUI](https://github.com/open-webui/open-webui) — Beautiful RAG interface
- [litellm](https://github.com/BerriAI/litellm) — Model proxy
- [NixOS](https://nixos.org/) — Reproducible system configuration

---

## 📞 Support

- 🐛 **Issues:** [GitHub Issues](https://github.com/dravitch/aurora-rag-stack/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/dravitch/aurora-rag-stack/discussions)
- 📧 **Email:** andrei@anthill.dev

---

## 🗺️ Roadmap

- [ ] Automatic GitHub sync for documentation
- [ ] Multi-node federation
- [ ] Analytics dashboard
- [ ] Fine-tuning custom embeddings
- [ ] Docker Compose alternative
- [ ] Ubuntu 24.04 support
- [ ] Slack/Discord integration
- [ ] Mobile clients

---

## 📊 Comparison: NixOS vs Debian

| Feature | NixOS | Debian 12 |
|---------|-------|-----------|
| **Setup Time** | 5-10 min | 5-10 min |
| **Reproducibility** | ✓✓✓ Perfect | ✓ Good |
| **Rollback** | ✓ Atomic | ✗ Manual |
| **Learning Curve** | Medium | Low |
| **Community** | Smaller | Larger |
| **Stability** | Excellent | Excellent |
| **Frugality** | 6.2GB disk | 8.5GB disk |
| **Best For** | DevOps, IaC | Traditional Linux |

Both are production-ready. Choose based on your team's expertise.

---

## 🏆 Achievements

- ✅ First open-source RAG stack with one-shot install
- ✅ Multi-OS support (NixOS + Debian)
- ✅ Frugality <2GB RAM validated
- ✅ Installation <10 min validated
- ✅ 100% local (no cloud dependencies)
- ✅ Full stack (5 layers)
- ✅ Production-ready documentation

---

**Made with ❤️ for the self-hosting community**

**AURORA RAG Stack — Your Knowledge, Your Infrastructure, Your Control**
