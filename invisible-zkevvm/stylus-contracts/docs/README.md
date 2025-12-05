# Documentation Directory

Centralized documentation for the Invisible zkEVM Stylus Contracts project.

---

## 📁 Directory Structure

```
docs/
├── README.md                   # This file
├── LITEPAPER_LOCATION.md       # Pointer to litepaper directory
├── development/                # Development documentation
├── testing/                    # Testing guides and specifications
├── deployment/                 # Deployment documentation
└── archive/                    # Historical/completed documentation
```

---

## 📚 Documentation Categories

### 🔧 Development

**Location**: `docs/development/`

Contains documentation for development workflows, project status, and AI context.

| File | Description |
|------|-------------|
| **CLAUDE.md** | AI context and project overview for Claude Code |
| **STATUS.md** | Current project state, architecture, dependency chain |
| **SUMMARY.md** | Quick project summary and overview |
| **CLEANUP.md** | Code cleanup strategy and toxic waste analysis |

**Key Files**:
- Start here: `STATUS.md` for project overview
- AI context: `CLAUDE.md` for LLM collaboration
- Code quality: `CLEANUP.md` for refactoring guide

---

### 🧪 Testing

**Location**: `docs/testing/`

Contains all testing documentation, guides, and specifications.

| File | Description |
|------|-------------|
| **TESTING_GUIDE.md** | How to test WASM-only contracts |
| **TEST_SPEC.md** | Comprehensive test specifications |
| **README_TESTING.md** | Testing workflow guide |

**Key Files**:
- Start here: `TESTING_GUIDE.md` for testing workflow
- Test cases: `TEST_SPEC.md` for all test specifications
- Workflow: `README_TESTING.md` for testing procedures

---

### 🚀 Deployment

**Location**: `docs/deployment/`

Contains deployment documentation and guides.

| File | Description |
|------|-------------|
| **DEPLOYMENT_PLAN.md** | Step-by-step deployment guide with git commits |

**Key Files**:
- Deployment: `DEPLOYMENT_PLAN.md` for complete deployment workflow

---

### 📦 Archive

**Location**: `docs/archive/`

Historical documentation from previous development iterations. These files are kept for reference but may be outdated.

| File | Description |
|------|-------------|
| **CARGO_STYLUS_CHECK_RESULTS.md** | Historical Stylus validation results |
| **EXECUTION_RESULTS.md** | Build execution logs |
| **FIX_APPLIED.md** | Dependency fix documentation |
| **OPTIMIZATION_STATUS.md** | WASM size optimization attempts |
| **DELIVERABLES.md** | Complete file inventory |
| **KNOWN_ISSUES.md** | Historical issues (may be resolved) |

**Note**: Archive files are historical snapshots and may not reflect current project state.

---

## 🗂️ File Organization Guide

### Files in Project Root

Only essential entry points remain in project root:

- **README.md** - Main project documentation
- **DOCS_LOCATION.md** - Pointer to all documentation (this directory)
- **rust-toolchain.toml** - Rust toolchain configuration
- **Cargo.toml** - Workspace configuration

All markdown documentation (including litepaper location) is in `docs/`.

### Everything Else

All other documentation is organized in:
- `docs/` - This directory (all markdown documentation)
- `litepaper/` - Litepaper and related files
- `contracts/` - Solidity contracts
- `stylus-contracts/` - Rust Stylus contracts

---

## 🎯 Quick Access Guides

### For New Contributors

1. **Start**: Read `/README.md` (project root)
2. **Understand**: Read `development/STATUS.md` (architecture)
3. **Setup**: Follow root README for installation
4. **Test**: Read `testing/TESTING_GUIDE.md`
5. **Deploy**: Read `deployment/DEPLOYMENT_PLAN.md`

### For Developers

```bash
# Current project state
cat docs/development/STATUS.md

# Testing procedures
cat docs/testing/TESTING_GUIDE.md

# Deployment workflow
cat docs/deployment/DEPLOYMENT_PLAN.md
```

### For AI Assistants

```bash
# Full project context
cat docs/development/CLAUDE.md

# Current status and architecture
cat docs/development/STATUS.md
```

### For Code Review

```bash
# Cleanup priorities
cat docs/development/CLEANUP.md

# Current project summary
cat docs/development/SUMMARY.md
```

---

## 📊 Documentation Map

```
Invisible zkEVM Project
│
├── Getting Started
│   └── /README.md (project root)
│
├── Technical Details
│   ├── docs/development/STATUS.md (architecture)
│   ├── docs/development/CLAUDE.md (AI context)
│   └── litepaper/LITEPAPER.pdf (complete documentation)
│
├── Development Workflow
│   ├── docs/development/CLEANUP.md (code quality)
│   ├── docs/testing/TESTING_GUIDE.md (testing)
│   └── docs/deployment/DEPLOYMENT_PLAN.md (deployment)
│
└── Reference
    ├── docs/testing/TEST_SPEC.md (test cases)
    ├── litepaper/LITEPAPER.md (markdown litepaper)
    └── docs/archive/* (historical docs)
```

---

## 🔄 Updating Documentation

### Adding New Documentation

```bash
# Development docs
mv new-dev-doc.md docs/development/

# Testing docs
mv new-test-doc.md docs/testing/

# Deployment docs
mv new-deploy-doc.md docs/deployment/

# Historical/completed
mv old-doc.md docs/archive/
```

### Updating Existing Docs

```bash
# Edit in place
vim docs/development/STATUS.md

# Or move between categories as needed
mv docs/development/old-status.md docs/archive/
```

---

## 📝 Documentation Standards

### File Naming

- Use `SCREAMING_SNAKE_CASE.md` for documentation files
- Be descriptive: `TESTING_GUIDE.md` not `TESTS.md`
- Use prefixes for related docs: `README_TESTING.md`

### Content Structure

Each documentation file should have:

1. **Title** - Clear H1 header
2. **Purpose** - What this doc covers
3. **Table of Contents** - For longer docs
4. **Content** - Well-organized sections
5. **Examples** - Code samples where relevant
6. **References** - Links to related docs

### Cross-References

Link to other docs using relative paths:

```markdown
See [deployment guide](../deployment/DEPLOYMENT_PLAN.md) for details.
See [testing guide](../testing/TESTING_GUIDE.md) for examples.
```

---

## 🔍 Finding Documentation

### By Topic

| Topic | Location |
|-------|----------|
| Architecture | `development/STATUS.md` |
| AI Context | `development/CLAUDE.md` |
| Testing | `testing/TESTING_GUIDE.md` |
| Test Cases | `testing/TEST_SPEC.md` |
| Deployment | `deployment/DEPLOYMENT_PLAN.md` |
| Code Cleanup | `development/CLEANUP.md` |
| Historical | `archive/*` |

### By Development Phase

| Phase | Documentation |
|-------|---------------|
| **Onboarding** | `/README.md`, `development/STATUS.md` |
| **Development** | `development/CLAUDE.md`, `development/CLEANUP.md` |
| **Testing** | `testing/TESTING_GUIDE.md`, `testing/TEST_SPEC.md` |
| **Deployment** | `deployment/DEPLOYMENT_PLAN.md` |
| **Reference** | `archive/*`, `litepaper/` |

---

## 🎯 Documentation Health

| Category | Files | Status |
|----------|-------|--------|
| Development | 4 | ✅ Organized |
| Testing | 3 | ✅ Organized |
| Deployment | 1 | ✅ Organized |
| Archive | 6 | ✅ Organized |
| **Total** | **14** | **✅ Complete** |

---

## 🆘 Documentation Support

### Need Help?

1. **Can't find a doc?** - Check this README's documentation map
2. **Outdated info?** - Create GitHub issue or update directly
3. **Missing docs?** - Create new file in appropriate category
4. **Archive confusion?** - Check `development/STATUS.md` for current state

### Common Questions

**Q: Where's the main README?**
A: In project root: `/README.md`

**Q: Where's the litepaper?**
A: In dedicated folder: `/litepaper/LITEPAPER.pdf`

**Q: Where are test specifications?**
A: In testing folder: `docs/testing/TEST_SPEC.md`

**Q: Where's deployment info?**
A: In deployment folder: `docs/deployment/DEPLOYMENT_PLAN.md`

**Q: What's in archive/?**
A: Historical documentation from previous iterations

---

## 📈 Documentation Statistics

```
Total Files:        14 markdown files
Active Docs:        8 files (development, testing, deployment)
Archived Docs:      6 files (historical reference)
Total Size:         ~150 KB
Organization:       4 categories

Status:             ✅ Complete and organized
Last Updated:       November 12, 2025
```

---

## 🔗 Related Documentation

- **Litepaper**: See `/litepaper/` directory
- **Code Documentation**: Inline comments in source files
- **API Reference**: See litepaper technical reference
- **External Docs**: Links in `development/STATUS.md`

---

**Maintained by**: Invisible zkEVM Team
**Last Updated**: November 12, 2025
**Status**: Organized and Complete ✨
