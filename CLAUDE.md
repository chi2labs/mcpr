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

# Build website for package
pkgdown::build_site(preview = FALSE)
```
## Repository
Our repo is chi2labs/mcpr

## MCP Server Implementation

### HTTP Transport (Recommended)
The mcpr package uses HTTP transport for reliable MCP server implementation. This approach:
- Provides stable connections with Claude Desktop
- Supports multiple concurrent clients
- Enables easy testing with standard HTTP tools
- Avoids stdin/stdout handling complexity

### Configuration Example
```json
{
  "mcpServers": {
    "r-server": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

### Key Requirements
1. **Clean JSON output**: Ensure all responses follow the MCP protocol specification
2. **Proper error handling**: Return appropriate JSON-RPC error responses
3. **Array serialization**: Empty arrays must serialize as `[]` not `{}` when using auto_unbox
4. **HTTP endpoints**: Implement `/mcp` for protocol, `/health` for monitoring
