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
## Repository
Our repo is chi2labs/mcpr

## MCP Server Implementation Lessons

### Key Requirements for R MCP Servers
1. **No stderr output**: R servers must not write ANY debug messages to stderr - this breaks Claude Desktop's connection
2. **Use Node.js wrapper**: R's stdin handling doesn't work reliably in subprocess contexts. Always wrap R servers with Node.js
3. **Clean JSON output**: Ensure only valid JSON-RPC responses are written to stdout
4. **Blocking stdin**: Use `file("stdin", open = "r", blocking = TRUE)` for reading input in R

### Working Example Structure
```
inst/bin/
├── mcp-hello-world-clean.R    # Clean R implementation (no stderr output)
├── mcp-wrapper-clean.js       # Node.js wrapper that spawns R process
└── .mcp.json configuration:
    {
      "mcpServers": {
        "r-hello": {
          "command": "node",
          "args": ["/path/to/mcp-wrapper-clean.js"]
        }
      }
    }
```

### Common Pitfalls to Avoid
- Don't use `--quiet --slave` flags in shebang lines (invalid syntax)
- Don't use `readLines(stdin())` directly - it returns EOF immediately in subprocesses
- Don't output startup messages or debug info to stderr
- Ensure tools/resources are returned as proper objects/arrays in JSON responses
