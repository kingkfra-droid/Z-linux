# Z-Linux

A Debian-based Linux distribution with custom build tools, configuration, and edition-specific package management.

## Overview

Z-Linux is a customized Linux operating system based on Debian, designed with modular components for building, bootstrapping, and configuring the OS. It features multiple editions optimized for different use cases with pre-configured package sets.

## Editions

Z-Linux comes in multiple editions, each with pre-installed packages tailored for specific use cases:

### 🔒 Security Edition (Hacking)
For penetration testers, security researchers, and ethical hackers.

**Pre-installed packages:**
- `metasploit-framework` - Penetration testing framework
- `burp-suite-community` - Web application security testing
- `wireshark` - Network packet analysis
- `nmap` - Network scanning and reconnaissance
- `hashcat` - Password cracking tool
- `aircrack-ng` - Wireless network auditing
- `hydra` - Login cracking tool
- `sqlmap` - SQL injection testing
- `git` - Version control
- `vim` - Text editor

### 📚 Documentation Edition (Office)
For technical writers, documentation specialists, and office professionals.

**Pre-installed packages:**
- `libreoffice` - Office suite (Writer, Calc, Impress)
- `pandoc` - Document converter
- `texlive` - LaTeX document preparation
- `gimp` - Image editing
- `inkscape` - Vector graphics editor
- `sphinx` - Documentation generator
- `asciidoc` - Text-based document format
- `git` - Version control
- `curl` - Web content retrieval
- `vim` - Text editor

### 🎬 Entertainment Edition (Editor)
For content creators, video editors, and multimedia professionals.

**Pre-installed packages:**
- `blender` - 3D modeling and animation
- `ffmpeg` - Multimedia framework
- `kdenlive` - Video editor
- `audacity` - Audio editor
- `gimp` - Image editing
- `darktable` - Photo management and editing
- `obs-studio` - Screen recording and streaming
- `obs-plugins` - OBS plugin collection
- `git` - Version control
- `vim` - Text editor

### 💻 Developer Edition (Default)
For software developers and programmers.

**Pre-installed packages:**
- `build-essential` - Essential build tools
- `git` - Version control
- `curl` - Web content retrieval
- `wget` - File downloader
- `vim` - Text editor
- `nano` - Simple text editor
- `htop` - System monitoring
- `python3` - Python interpreter
- `nodejs` - JavaScript runtime
- `docker.io` - Container platform

## Directory Structure

- **`bootstrap/`** - Bootstrap scripts and components for initial OS setup
- **`boot/`** - Boot configuration files, GRUB setup, and filesystem tables
- **`build/`** - Build scripts and compilation tools
- **`config/`** - Configuration files for the OS
- **`scripts/`** - Utility scripts and automation tools
- **`editions/`** - Edition-specific package lists and installation profiles

## Getting Started

### Prerequisites
- Debian-based Linux distribution
- Root or sudo privileges
- Internet connection for package downloads

### Basic Installation

1. **Choose your edition** by selecting the appropriate package set:
   ```bash
   # Security Edition
   sudo bash scripts/get --install-security
   
   # Documentation Edition
   sudo bash scripts/get --install-documentation
   
   # Entertainment Edition
   sudo bash scripts/get --install-entertainment
   
   # Developer Edition (default)
   sudo bash scripts/get --install-developer
   ```

2. **Configure boot** (if needed):
   ```bash
   sudo bash boot/boot.sh
   ```

3. **Run system updates**:
   ```bash
   get --update
   get --upgrade
   ```

### Manual Package Management

Install individual packages:
```bash
get package-name
```

Update package lists:
```bash
get --update
```

Remove packages:
```bash
get --remove package-name
```

Search for packages:
```bash
get --search search-term
```

## Edition Configuration Files

Each edition has a dedicated package list file in the `editions/` directory:

- `editions/security.txt` - Security/Hacking packages
- `editions/documentation.txt` - Office/Documentation packages
- `editions/entertainment.txt` - Entertainment/Editor packages
- `editions/developer.txt` - Developer packages

## Scripts

### Package Manager (`scripts/get`)
The main package management utility that wraps `apt-get` with Z-Linux specific functionality:
- Install packages: `get package-name`
- Update: `get --update`
- Upgrade: `get --upgrade`
- Remove: `get --remove package-name`
- Search: `get --search keyword`

### Boot Configuration (`boot/boot.sh`)
Configures the bootloader and filesystem:
- Auto-detects boot device
- Installs/updates GRUB bootloader
- Verifies boot configuration

## License

TBD - Add license information.

## Contributing

Contributions are welcome. Please submit pull requests or open issues for:
- Bug reports
- Feature requests
- New edition package suggestions
- Documentation improvements

## Support

For issues, questions, or feature requests, please open an issue on the GitHub repository.

---

**Current Version:** 0.1.0  
**Last Updated:** 2026-08-21
