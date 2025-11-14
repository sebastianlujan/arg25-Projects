# How to Compile the EVVM Litepaper

This guide shows you how to compile `LITEPAPER.tex` into a PDF.

## Option 1: Online (Easiest - No Installation Required)

### Using Overleaf

1. Go to [https://www.overleaf.com](https://www.overleaf.com)
2. Create a free account (if you don't have one)
3. Click "New Project" → "Upload Project"
4. Upload `LITEPAPER.tex`
5. Click "Recompile"
6. Download the generated PDF

**Pros:** No installation, works everywhere, easy to edit
**Cons:** Requires internet connection

## Option 2: Docker (Recommended for Local Compilation)

### Prerequisites
- Docker installed and running

### Steps

```bash
# Navigate to the litepaper directory
cd stylus-contracts/litepaper

# Compile PDF (run twice for cross-references and TOC)
docker run --rm -i \
  -v "$(pwd)":/workdir \
  -w /workdir \
  texlive/texlive:latest \
  bash -c "pdflatex -interaction=nonstopmode LITEPAPER.tex && \
           pdflatex -interaction=nonstopmode LITEPAPER.tex"

# Clean up auxiliary files
rm -f LITEPAPER.{aux,log,out,toc,fls,fdb_latexmk}

# View the PDF
open LITEPAPER.pdf  # macOS
# xdg-open LITEPAPER.pdf  # Linux
# start LITEPAPER.pdf  # Windows
```

**Pros:** Consistent results, no local LaTeX installation needed
**Cons:** Requires Docker, slower first download

## Option 3: Local LaTeX Installation

### macOS

```bash
# Install MacTeX (large download, ~4GB)
brew install --cask mactex

# Or install BasicTeX (smaller, ~100MB)
brew install --cask basictex
sudo tlmgr update --self
sudo tlmgr install collection-latexextra

# Compile
cd stylus-contracts/litepaper
pdflatex LITEPAPER.tex
pdflatex LITEPAPER.tex  # Run twice for TOC

# Clean up
rm -f LITEPAPER.{aux,log,out,toc}

# View
open LITEPAPER.pdf
```

### Linux (Ubuntu/Debian)

```bash
# Install TeX Live
sudo apt-get update
sudo apt-get install texlive-full

# Compile
cd stylus-contracts/litepaper
pdflatex LITEPAPER.tex
pdflatex LITEPAPER.tex  # Run twice for TOC

# Clean up
rm -f LITEPAPER.{aux,log,out,toc}

# View
xdg-open LITEPAPER.pdf
```

### Windows

```bash
# Install MiKTeX from https://miktex.org/download

# Open Command Prompt or PowerShell
cd stylus-contracts\litepaper
pdflatex LITEPAPER.tex
pdflatex LITEPAPER.tex

# Clean up
del LITEPAPER.aux LITEPAPER.log LITEPAPER.out LITEPAPER.toc

# View
start LITEPAPER.pdf
```

**Pros:** Fast compilation, works offline
**Cons:** Large installation size

## Option 4: Automated with latexmk (Advanced)

If you have a local LaTeX installation:

```bash
cd stylus-contracts/litepaper

# Compile with automatic reruns
latexmk -pdf LITEPAPER.tex

# Continuous compilation (watches for changes)
latexmk -pdf -pvc LITEPAPER.tex

# Clean up
latexmk -c
```

## Troubleshooting

### Missing Packages

If you get errors about missing packages:

**Docker:** Use the full `texlive/texlive:latest` image (already includes everything)

**Local Installation:**
```bash
# macOS/Linux
sudo tlmgr install <package-name>

# Windows (MiKTeX)
# Packages install automatically, or use MiKTeX Console
```

### Common Packages Required
- `geometry` - Page layout
- `xcolor` - Colors
- `tcolorbox` - Colored boxes
- `hyperref` - Clickable links
- `booktabs` - Professional tables
- `titlesec` - Section formatting
- `fancyhdr` - Headers and footers

### Docker Not Running

```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker

# Windows
# Start Docker Desktop from Start Menu
```

### PDF Not Updating

Make sure to run `pdflatex` **twice**:
1. First pass: Generates content and references
2. Second pass: Resolves cross-references and TOC

## Quick Comparison

| Method | Setup Time | Compilation Speed | Disk Space | Internet Required |
|--------|------------|-------------------|------------|-------------------|
| Overleaf | 2 min | Medium | 0 MB | Yes |
| Docker | 10 min | Medium | ~1 GB | First time only |
| Local Install | 30 min | Fast | 3-5 GB | First time only |

## Expected Output

After successful compilation, you should have:

- **LITEPAPER.pdf** (~200-500 KB)
- Clean, professional formatting
- Clickable table of contents
- Colored sections and boxes
- Proper hyperlinks

## Verify PDF Quality

```bash
# Check file info
file LITEPAPER.pdf

# Check size
ls -lh LITEPAPER.pdf

# Count pages (requires pdfinfo)
pdfinfo LITEPAPER.pdf | grep Pages
```

## Tips

1. **Always run pdflatex twice** to ensure TOC and references are correct
2. **Clean auxiliary files** after compilation to save space
3. **Use Overleaf** for quick edits and previews
4. **Use Docker** for consistent, reproducible builds
5. **Use local installation** for frequent compilation

## Need Help?

- Check the LaTeX log file: `cat LITEPAPER.log`
- Search for errors containing "Error" or "!"
- Common issues: Missing packages, syntax errors, file encoding

---

**Quick Start (Recommended):**

If you just want to see the PDF quickly, use Overleaf:
1. Visit https://www.overleaf.com
2. Upload `LITEPAPER.tex`
3. Click Recompile
4. Download PDF

Done! 🎉
