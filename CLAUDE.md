# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

mcpr is an  R package creating Model Context Protocols from R code.  The goal is to expose a file, directory or an entire package as a Model Context Protocol (MCP) server to allow access from Claude Desktop and other LLM systems.

## Development Commands

### Build and Check
```bash
# Build the package
R CMD build .

# Check the package (includes running tests)
R CMD check moodleR_*.tar.gz

# Install locally
R CMD INSTALL moodleR_*.tar.gz
```

### Testing
```r
# Run all tests
devtools::test()

# Run specific test file
devtools::test(filter = "test_name")
```

### Documentation
```r
# Generate documentation from roxygen2 comments
devtools::document()

# Build vignettes
devtools::build_vignettes()
```
## Respository
Our repo is chi2labs/mcpr
