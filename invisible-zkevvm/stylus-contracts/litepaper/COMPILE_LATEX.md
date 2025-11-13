# LaTeX Compilation Guide

## Quick Compilation

```bash
# Single command (recommended)
pdflatex LITEPAPER.tex && pdflatex LITEPAPER.tex

# Or use latexmk for automatic compilation
latexmk -pdf LITEPAPER.tex
```

## Step-by-Step Compilation

### Method 1: Using pdflatex (Standard)

```bash
# Run twice for proper cross-references and TOC
pdflatex LITEPAPER.tex
pdflatex LITEPAPER.tex

# Output: LITEPAPER.pdf
```

**Why run twice?**
- First pass: Generates document, collects references
- Second pass: Resolves all cross-references and page numbers

### Method 2: Using latexmk (Automatic)

```bash
# Install latexmk if not installed
# macOS: brew install latexmk
# Linux: sudo apt-get install latexmk

# Compile with automatic reruns
latexmk -pdf LITEPAPER.tex

# Clean auxiliary files
latexmk -c
```

### Method 3: Using XeLaTeX (Better Font Support)

```bash
xelatex LITEPAPER.tex
xelatex LITEPAPER.tex
```

## Prerequisites

### macOS

```bash
# Install MacTeX (full distribution)
brew install --cask mactex

# Or BasicTeX (minimal, faster)
brew install --cask basictex
sudo tlmgr update --self
sudo tlmgr install latexmk
```

### Linux (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install texlive-full

# Or minimal installation
sudo apt-get install texlive-latex-base texlive-latex-extra
```

### Windows

Download and install MiKTeX or TeX Live:
- MiKTeX: https://miktex.org/download
- TeX Live: https://tug.org/texlive/

## Required LaTeX Packages

The document uses these packages (usually included in full distributions):

- `geometry` - Page margins
- `hyperref` - Clickable links
- `listings` - Code syntax highlighting
- `xcolor` - Colors
- `booktabs` - Professional tables
- `enumitem` - Custom lists
- `fancyhdr` - Headers/footers
- `titlesec` - Section formatting

## Troubleshooting

### Missing Packages

If you get "Package X not found":

```bash
# macOS/Linux with tlmgr
sudo tlmgr install <package-name>

# Or install full distribution
sudo tlmgr install scheme-full
```

### Font Issues

If fonts don't render properly:

```bash
# Use XeLaTeX instead
xelatex LITEPAPER.tex
```

### Compilation Errors

**Error: "File not found"**
- Make sure you're in the correct directory
- Check that LITEPAPER.tex exists

**Error: "Undefined control sequence"**
- A LaTeX command is misspelled
- Check the error line number in output

**Error: "Missing $ inserted"**
- Math mode issue
- Usually a special character needs escaping

### Clean Build

Remove all auxiliary files and rebuild:

```bash
# Remove auxiliary files
rm -f LITEPAPER.aux LITEPAPER.log LITEPAPER.out LITEPAPER.toc

# Or use latexmk
latexmk -C LITEPAPER.tex

# Then recompile
pdflatex LITEPAPER.tex
pdflatex LITEPAPER.tex
```

## Online Compilation (No Installation Required)

### Overleaf

1. Go to https://www.overleaf.com
2. Create free account
3. New Project → Upload Project
4. Upload LITEPAPER.tex
5. Click "Recompile"
6. Download PDF

### Other Online Compilers

- **Papeeria**: https://papeeria.com
- **LaTeX Base**: https://latexbase.com
- **ShareLaTeX**: Now merged with Overleaf

## Output Files

After compilation, you'll see:

```
LITEPAPER.pdf     # Final PDF document ← This is what you want!
LITEPAPER.aux     # Auxiliary file (can delete)
LITEPAPER.log     # Compilation log (can delete)
LITEPAPER.out     # Hyperref output (can delete)
LITEPAPER.toc     # Table of contents (can delete)
LITEPAPER.fls     # File list (can delete)
LITEPAPER.fdb_latexmk  # Latexmk database (can delete)
```

Keep only `LITEPAPER.pdf` and `LITEPAPER.tex`.

## Automation Script

Save as `build.sh`:

```bash
#!/bin/bash
set -e

echo "Compiling LITEPAPER.tex..."

# Compile twice for references
pdflatex -interaction=nonstopmode LITEPAPER.tex > /dev/null
pdflatex -interaction=nonstopmode LITEPAPER.tex > /dev/null

echo "✓ Compilation successful!"
echo "Output: LITEPAPER.pdf"

# Clean auxiliary files
rm -f LITEPAPER.aux LITEPAPER.log LITEPAPER.out LITEPAPER.toc

echo "✓ Cleaned auxiliary files"
```

Run with: `bash build.sh`

## Advanced: Continuous Compilation

Watch for changes and auto-compile:

```bash
# Install fswatch (macOS)
brew install fswatch

# Watch and compile on changes
fswatch -o LITEPAPER.tex | xargs -n1 -I{} pdflatex LITEPAPER.tex
```

Or use latexmk:

```bash
latexmk -pvc -pdf LITEPAPER.tex
```

## Viewing the PDF

### macOS
```bash
open LITEPAPER.pdf
```

### Linux
```bash
xdg-open LITEPAPER.pdf
# or
evince LITEPAPER.pdf
```

### Windows
```bash
start LITEPAPER.pdf
```

## Expected Output

The compiled PDF will have:

- **Title page** with project branding
- **Table of contents** (clickable links)
- **~40 pages** of formatted content
- **Syntax-highlighted code blocks** (Rust, Bash, JavaScript)
- **Professional tables** with proper formatting
- **Clickable hyperlinks** (blue color)
- **ASCII diagrams** in monospace font
- **Section numbering** and cross-references

## File Size

Expected PDF size: ~200-500 KB (depending on fonts embedded)

## Quality Check

After compilation, verify:

- [ ] All sections appear in TOC
- [ ] Code blocks are properly formatted
- [ ] Links are clickable (blue color)
- [ ] Tables render correctly
- [ ] No LaTeX errors in log
- [ ] Page numbers are correct
- [ ] Diagrams are readable

## Distribution

The PDF is now ready for:
- GitHub releases
- Documentation website
- Academic submissions
- Investor presentations
- Developer onboarding

---

**Questions?** Check the compilation log: `less LITEPAPER.log`
