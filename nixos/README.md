# 🧠 RAG-NixOS

**One-command RAG system for NixOS** - Deploy your own local AI knowledge base in minutes.

[![NixOS](https://img.shields.io/badge/NixOS-25.11-blue.svg)](https://nixos.org/)
[![Ollama](https://img.shields.io/badge/Ollama-Latest-green.svg)](https://ollama.ai/)
[![Open WebUI](https://img.shields.io/badge/Open_WebUI-v0.6.41-orange.svg)](https://github.com/open-webui/open-webui)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/aa0eac3d-b07b-4936-a792-a9d133a4b03f" />


---

## 🌟 Why RAG on NixOS is the Future of Knowledge Management

### The Problem with Traditional Knowledge Bases

Traditional documentation systems are **static, fragile, and disconnected**:

- 📄 **Static wikis** require manual updates and become outdated
- 🔍 **Search-only systems** can't understand context or intent
- ☁️ **Cloud-based solutions** lock your knowledge behind paywalls and privacy concerns
- 🔧 **Complex setups** require Docker expertise and constant maintenance
- 👥 **Single-user focus** makes team collaboration difficult

### The RAG-NixOS Advantage

**RAG-NixOS isn't just another documentation tool** - it's a paradigm shift in how teams create, maintain, and interact with knowledge:

#### 🔒 True Self-Hosting
- **100% local** - Your data never leaves your infrastructure
- **No cloud dependencies** - Works offline, always available
- **Full control** - No vendor lock-in, no surprise pricing changes
- **Privacy-first** - Perfect for sensitive projects, research, or company IP

#### 📈 Living Knowledge Base
Unlike static documentation:
- **Evolves with your content** - Automatically indexes new documents
- **Understands context** - Answers questions across multiple documents
- **Learns your terminology** - Adapts to your project's specific language
- **Finds connections** - Discovers relationships you didn't know existed

#### 👥 Team-First Architecture
Designed for **collaborative work** from day one:
- **Shared context** - Everyone asks questions from the same knowledge base
- **Consistent answers** - No more "it depends who you ask"
- **Onboarding accelerator** - New team members get instant access to institutional knowledge
- **Asynchronous collaboration** - Team members in different timezones share insights

#### 🛡️ NixOS: The Perfect Foundation

Why NixOS specifically?

- **Declarative configuration** - Your entire RAG system is defined in code
- **Reproducible deployments** - Deploy identical systems across dev/staging/prod
- **Atomic upgrades** - Update with confidence, rollback instantly if needed
- **Zero dependency hell** - NixOS manages all dependencies correctly
- **Long-term stability** - Systems keep working for years without bitrot

#### 🚀 Production-Ready, Self-Service

**For individuals:**
- Research papers organization
- Personal knowledge management
- Code documentation
- Learning notes

**For teams:**
- Company wikis that actually get used
- Project documentation
- Technical onboarding
- Institutional knowledge preservation

**For communities:**
- Open source project docs
- Community wikis
- Collaborative research
- Shared learning resources

### 🔮 The Vision: Evolving Stack

This is **version 1.0** of an evolving platform. Future enhancements:

- 🔄 **Auto-sync with Git repos** - Docs stay current automatically
- 📊 **Analytics & insights** - Understand what knowledge is most valuable
- 🌐 **Multi-node federation** - Connect multiple RAG instances
- 🎨 **Custom embeddings** - Fine-tune for your domain
- 🔐 **Advanced auth** - Role-based access control
- 📱 **Mobile clients** - Access your knowledge anywhere
- 🤖 **Agent workflows** - RAG that can take actions
- 💬 **Slack/Discord integration** - Bring answers where your team works

**Join us in building the future of self-hosted, AI-powered knowledge management.**

---

## 🎯 What is RAG-NixOS?

A **production-ready RAG (Retrieval-Augmented Generation)** system for NixOS that lets you:

- 🚀 Deploy in **5 minutes** with a single script
- 🔒 Run **100% locally** - no cloud, no API keys
- 📚 Index your **documentation, code, notes** automatically
- 💬 Chat with your knowledge base through a modern web UI
- 🔄 Stay **reproducible** with declarative NixOS configuration

Perfect for:
- 📖 Large documentation projects
- 🏢 Company knowledge bases
- 🔬 Research papers and notes
- 💻 Code repositories
- 📝 Personal knowledge management

---

## ⚡ Quick Start

### Prerequisites

- NixOS 25.11+
- 8GB RAM minimum (16GB recommended)
- 10GB free disk space
- Internet connection

### One-Command Installation

```bash
curl -sSL https://raw.githubusercontent.com/YOUR-USERNAME/rag-nixos/main/install.sh | sudo bash
```

**That's it!** After 5-10 minutes, open `http://localhost:3000` in your browser.

---

## 📋 What Gets Installed

| Component | Purpose | Port |
|-----------|---------|------|
| **Ollama** | LLM runtime (Mistral 7B) | 11434 |
| **Open WebUI** | Chat interface + RAG | 3000 |
| **Podman** | Container runtime | - |

**Storage locations:**
- Models: `/var/lib/<project>-rag/ollama/models`
- Documents: `/var/docs/<project>`
- Open WebUI data: `/var/lib/openwebui`

---

## 🚀 Usage

### 1. Access the Interface

Open your browser: `http://localhost:3000`

Or from another machine: `http://[YOUR-IP]:3000`

### 2. Upload Your Documents

Click **Documents** → **Upload** → Select your files (Markdown, PDF, TXT, etc.)

Open WebUI will automatically:
- Parse the content
- Generate embeddings
- Index in vector database
- Make searchable via chat

### 3. Ask Questions

```
"What is the deployment procedure for X?"
"Show me examples of Y configuration"
"Summarize the architecture document"
```

---

## 📚 Recommended Documentation Structure

```
/var/docs/<project>/
├── README.md                    # Project overview
├── architecture/                # Design documents
│   ├── overview.md
│   └── components.md
├── guides/                      # How-to guides
│   ├── getting-started.md
│   └── deployment.md
├── reference/                   # API docs, configs
│   ├── api.md
│   └── configuration.md
└── projects/                    # Sub-projects
    └── [project-name]/
```

---

## 🔧 Configuration

### Basic Configuration

Edit `/etc/nixos/configuration.nix`:

```nix
# Enable RAG system
services.ollama.enable = true;

<project>.openwebui = {
  enable = true;
  port = 3000;                    # Change web UI port
  enableAuth = false;             # Enable for production
};
```

### Change LLM Model

```nix
services.ollama = {
  enable = true;
  environmentVariables = {
    OLLAMA_MODELS = "/var/lib/<project>-rag/ollama/models";
  };
};
```

Then:
```bash
ollama pull deepseek-r1:7b    # Or any other model
sudo systemctl restart openwebui.service
```

### Enable Authentication

```nix
<project>.openwebui.enableAuth = true;
```

First user to register becomes admin.

---

## 📊 System Status

Check services:
```bash
sudo /etc/<project>-rag/status.sh
```

Output:
```
🔍 RAG System Status
====================

📦 Ollama:
Active: active (running) since ...
  ✓ mistral:7b
  ✓ nomic-embed-text

🌐 Open WebUI:
Active: active (running) since ...
  ✓ Container: Up 5 minutes

🌐 URLs:
  Ollama API: http://localhost:11434
  Open WebUI: http://localhost:3000

💾 Disk Usage:
  Models: 4.3GB
  Documents: 245MB
```

---

## 🐛 Troubleshooting

### Open WebUI shows "No models available"

**Check Ollama is running:**
```bash
curl http://localhost:11434/api/tags
```

**If not responding:**
```bash
sudo systemctl restart ollama.service
sudo systemctl restart openwebui.service
```

### Container won't start

**Check logs:**
```bash
sudo journalctl -u openwebui.service -n 50
```

**Common fix:**
```bash
sudo podman rm -f openwebui
sudo systemctl restart openwebui.service
```

### Models not downloading

**Manual download:**
```bash
ollama pull mistral:7b
ollama pull nomic-embed-text
```

### Port 3000 already in use

**Change port in configuration.nix:**
```nix
<project>.openwebui.port = 8080;  # Or any free port
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

---

## 🔄 Updates

### Update Open WebUI

```bash
sudo podman pull ghcr.io/open-webui/open-webui:main
sudo systemctl restart openwebui.service
```

### Update Ollama

```bash
sudo nixos-rebuild switch --upgrade
```

### Update Models

```bash
ollama pull mistral:7b
```

---

## 🎛️ Advanced Configuration

### Add More Models

```bash
ollama pull llama3:8b
ollama pull codellama:7b
ollama pull deepseek-r1:7b
```

Models appear automatically in Open WebUI.

### GPU Acceleration

For NVIDIA GPUs:
```nix
services.ollama.acceleration = "cuda";
```

For AMD GPUs:
```nix
services.ollama.acceleration = "rocm";
```

### Custom Data Directory

```nix
services.ollama.environmentVariables = {
  OLLAMA_MODELS = "/mnt/data/models";
};
```

---

## 📈 Performance

On a typical system (16GB RAM, 4-core CPU):

| Metric | Value |
|--------|-------|
| Response time | 2-5 seconds |
| Token generation | 20-30 tokens/sec |
| Document indexing | ~1000 docs/minute |
| RAM usage (idle) | ~6GB |
| RAM usage (active) | ~8GB |

---

## 🔒 Security

### Production Deployment

1. **Enable authentication:**
```nix
<project>.openwebui.enableAuth = true;
```

2. **Use HTTPS** (via reverse proxy like Nginx)

3. **Firewall configuration:**
```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 3000 ];  # Or your custom port
};
```

4. **Regular updates:**
```bash
sudo nixos-rebuild switch --upgrade
```

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test on NixOS 25.11
4. Submit a pull request

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Ollama](https://ollama.ai/) - Local LLM runtime
- [Open WebUI](https://github.com/open-webui/open-webui) - Beautiful RAG interface
- [NixOS](https://nixos.org/) - Reproducible system configuration

---

## 📞 Support

- 🐛 **Issues:** [GitHub Issues](https://github.com/YOUR-USERNAME/rag-nixos/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/YOUR-USERNAME/rag-nixos/discussions)
- 📧 **Email:** [your-email@example.com](mailto:your-email@example.com)

---

## 🗺️ Roadmap

- [ ] Automatic GitHub sync for documentation
- [ ] Multi-user support with permissions
- [ ] Integration with MkDocs
- [ ] Backup/restore scripts
- [ ] Docker Compose alternative
- [ ] Kubernetes deployment guide

---

**Made with ❤️ for the NixOS community**# nixos-rag-stack
