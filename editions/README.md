# Z-Linux Editions

This directory contains package lists for each Z-Linux edition. Each edition is optimized for specific use cases with pre-configured packages.

## Available Editions

### Security Edition (Hacking)
**File:** `security.txt`

Designed for penetration testers, security researchers, and ethical hackers.

Install with:
```bash
sudo bash scripts/get --install-security
```

Includes:
- Penetration testing frameworks
- Network analysis tools
- Password cracking utilities
- Web security testing suites
- Wireless auditing tools

---

### Documentation Edition (Office)
**File:** `documentation.txt`

Designed for technical writers, documentation specialists, and office professionals.

Install with:
```bash
sudo bash scripts/get --install-documentation
```

Includes:
- Office productivity suite (LibreOffice)
- Document converters
- LaTeX for scientific documents
- Image and vector editors
- Documentation generators

---

### Entertainment Edition (Editor)
**File:** `entertainment.txt`

Designed for content creators, video editors, and multimedia professionals.

Install with:
```bash
sudo bash scripts/get --install-entertainment
```

Includes:
- 3D modeling and animation (Blender)
- Video editing tools
- Audio editing software
- Photo management and editing
- Screen recording and streaming

---

### Developer Edition (Default)
**File:** `developer.txt`

Designed for software developers and programmers.

Install with:
```bash
sudo bash scripts/get --install-developer
```

Includes:
- Compiler and build tools
- Version control systems
- Programming languages (Python, Node.js, Java)
- Container platforms (Docker)
- IDE and debugging tools

---

## Customizing Editions

To add packages to an edition:

1. Edit the corresponding `.txt` file
2. Add one package per line
3. Save and commit your changes
4. Run the installation command for that edition

## Creating a New Edition

1. Create a new file: `editions/your-edition.txt`
2. Add packages (one per line)
3. Update this README with the new edition description
4. Update `scripts/get` to handle `--install-your-edition` flag
