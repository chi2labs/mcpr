# mcpr Product Requirements Document

## Executive Summary

The mcpr package is an R implementation of the Model Context Protocol (MCP) that enables R developers to expose functions, files, or entire packages as MCP servers. This allows seamless integration between R code and AI systems like Claude Desktop. The package follows design patterns established by the successful plumber package, providing a familiar and intuitive interface for the R community.

## Project Overview

### Vision
Create the standard way for R developers to connect their code with AI assistants and LLM systems through the Model Context Protocol.

### Goals
- Provide a simple, decorator-based system for exposing R functions
- Enable embedding MCP servers within existing R packages
- Support multiple granularities: single functions, files, or entire packages
- Maintain CRAN compliance for broad distribution
- Create an intuitive API inspired by plumber's successful patterns

### Target Users
- **Primary**: R package developers who want to make their packages AI-accessible
- **Secondary**: Data scientists who want to expose analysis functions to AI assistants
- **Tertiary**: R users who want to integrate their workflows with Claude Desktop

## Technical Requirements

### Core Components

#### 1. Type Conversion System (Issue #5)
- **Priority**: HIGH - Foundation for all other components
- **Requirements**:
  - Bidirectional R ↔ JSON conversion
  - Support for all common R types (vectors, lists, data.frames, matrices)
  - Handle S3/S4 objects gracefully
  - Preserve attributes where possible
  - Clear documentation of type mappings

#### 2. Decorator System (Issue #2)
- **Priority**: HIGH - Critical for developer experience
- **Requirements**:
  - Roxygen2-style decorators (@mcp_tool, @mcp_resource, @mcp_prompt)
  - Parameter type hints and descriptions
  - Automatic function discovery in source files
  - R6-based implementation for extensibility
  - Examples:
    ```r
    #* @mcp_tool
    #* @description Calculate summary statistics
    #* @param data A numeric vector
    calculate_stats <- function(data) {
      list(mean = mean(data), sd = sd(data))
    }
    ```

#### 3. Core MCP Protocol Handler (Issue #3)
- **Priority**: HIGH - Essential for protocol compliance
- **Requirements**:
  - Full JSON-RPC 2.0 implementation
  - Session management and lifecycle (initialize/shutdown)
  - Capability negotiation
  - Error handling per MCP specification
  - Support for all MCP primitives (tools, resources, prompts, sampling)

#### 4. Transport Layers (Issue #4)
- **Priority**: HIGH for stdio, MEDIUM for others
- **Requirements**:
  - **stdio** (Phase 1): For Claude Desktop integration
    - MUST include Node.js wrapper for subprocess reliability
    - R's stdin handling is broken in subprocess contexts
    - Zero stderr output allowed (breaks connections)
  - **HTTP+SSE** (Phase 2): For remote servers
  - **WebSocket** (Phase 3): For bidirectional communication
  - Clean abstraction for adding new transports

#### 5. Package Integration Features
- **Priority**: MEDIUM - Key differentiator
- **Requirements**:
  - Scan packages for exportable functions
  - Include/exclude patterns for selective exposure
  - Automatic documentation extraction
  - Helper functions for package authors
  - Template for adding MCP servers to existing packages

### API Design

#### Core API (Plumber-Inspired)
```r
# Create MCP server (generates complete server package)
mcp_create_server(
  source = "my_functions.R",
  output_dir = "my-mcp-server",
  name = "my-server",
  version = "1.0.0"
)

# Alternative: Build server programmatically
mcp() %>%
  mcp_tool("name", function) %>%
  mcp_resource("name", function) %>%
  mcp_prompt("name", template) %>%
  mcp_generate(output_dir = "server-package")

# Source from file with decorators
mcp_create_server(
  source = "tools.R",
  output_dir = "tools-server"
)

# Expose package functions
mcp_create_server(
  package = "ggplot2", 
  include = c("ggplot", "geom_*"),
  exclude = c("*.data"),
  output_dir = "ggplot2-server"
)
```

#### Generated Server Structure
```
my-mcp-server/
├── package.json          # npm package definition
├── index.js              # Node.js wrapper (auto-generated)
├── server.R              # R MCP server (auto-generated)
├── README.md             # Installation instructions
└── mcp.json              # Example Claude Desktop config
```

#### Embedded Server Pattern
```r
# In any R package
#' Start MCP server for this package
#' @export
start_mcp_server <- function(transport = "stdio", port = NULL) {
  mcp <- mcpr::mcp()
  mcp %>%
    mcp_source(system.file("mcp", "api.R", package = "mypackage")) %>%
    mcp_run(transport = transport, port = port)
}
```

### Package Structure
```
mcpr/
├── R/
│   ├── mcp.R              # Main MCP object and constructor
│   ├── mcp-tool.R          # Tool registration methods
│   ├── mcp-resource.R      # Resource registration methods
│   ├── mcp-prompt.R        # Prompt template registration
│   ├── mcp-source.R        # Source file parsing
│   ├── mcp-package.R       # Package scanning
│   ├── decorators.R        # Decorator parsing
│   ├── json-rpc.R          # Protocol implementation
│   ├── type-conversion.R   # R ↔ JSON conversion
│   ├── transport-stdio.R   # stdio transport (with blocking stdin)
│   ├── transport-http.R    # HTTP transport
│   ├── server-generator.R  # Generate R server scripts
│   ├── wrapper-generator.R # Generate Node.js wrappers
│   └── utils.R             # Helper functions
├── inst/
│   ├── templates/          # Package templates
│   │   ├── node-wrapper.js # Node.js wrapper template
│   │   ├── server.R        # R server template
│   │   ├── package.json    # npm package template
│   │   └── README.md       # Installation guide template
│   ├── bin/                # CLI tools
│   │   └── mcpr            # Command line interface
│   └── examples/           # Example servers
│       ├── basic/          # Simple function exposure
│       ├── data-analysis/  # Data analysis workflow
│       └── package/        # Package exposure example
├── tests/
│   └── testthat/
│       ├── test-type-conversion.R
│       ├── test-decorators.R
│       ├── test-json-rpc.R
│       ├── test-transport.R
│       ├── test-wrapper-generator.R
│       └── test-integration.R
├── vignettes/
│   ├── getting-started.Rmd
│   ├── embedding-servers.Rmd
│   ├── subprocess-architecture.Rmd
│   └── mcp-protocol.Rmd
```

### Dependencies
```yaml
Imports:
  jsonlite (>= 1.8.0),     # JSON parsing
  R6 (>= 2.5.0),           # OOP for decorators
  later (>= 1.3.0),        # Async operations
  processx (>= 3.5.0)      # Process management

Suggests:
  plumber (>= 1.2.0),      # Inspiration and HTTP server
  httpuv (>= 1.6.0),       # HTTP transport
  httr2 (>= 1.0.0),        # HTTP client for testing
  testthat (>= 3.0.0),     # Testing framework
  withr (>= 2.5.0)         # Test helpers
```

## Non-Functional Requirements

### Performance
- Handle large data transfers efficiently
- Minimal overhead for function calls
- Async support for long-running operations
- Connection pooling for HTTP transport

### Security
- Input validation for all exposed functions
- Option to sandbox function execution
- Authentication support (OAuth 2.1 for HTTP)
- No automatic exposure of sensitive functions
- Clear security documentation

### Usability
- Intuitive API familiar to R developers
- Comprehensive error messages
- Extensive documentation and examples
- RStudio add-in for server management (future)

### Quality
- >90% test coverage
- CRAN compliance (no NOTEs or WARNINGs)
- Continuous integration with GitHub Actions
- Performance benchmarks in CI

## Implementation Phases

### Phase 1: Foundation (Weeks 1-3)
1. Type conversion system (Issue #5)
2. Basic MCP object and builders
3. Decorator parser (Issue #2)
4. Core protocol implementation (Issue #3)
5. **Node.js wrapper generator** (Critical for stdio transport)

### Phase 2: Basic Functionality (Weeks 4-5)
1. stdio transport with Node.js wrapper (Issue #4)
2. Server generator (creates R + Node.js package)
3. Simple tool/resource registration
4. Basic examples demonstrating wrapper usage
5. Initial test suite including subprocess tests

### Phase 3: Advanced Features (Weeks 6-7)
1. Package scanning functionality
2. HTTP transport (may not need Node.js wrapper)
3. CLI tools for server generation
4. Comprehensive documentation including architecture

### Phase 4: Polish (Week 8)
1. Performance optimization
2. Security review
3. CRAN preparation
4. Community feedback incorporation
5. npm package publishing guidelines

## Success Metrics

### Technical Metrics
- All 7 GitHub issues resolved
- Test coverage >90%
- CRAN acceptance on first submission
- <100ms overhead per function call
- Support for 95% of common R data types

### Adoption Metrics
- 10+ example implementations
- Integration with at least 3 popular R packages
- 100+ GitHub stars within 3 months
- Active community contributions

## Example Use Cases

### Use Case 1: Data Analysis Package
A data scientist wants to expose their analysis functions to Claude:
```r
# In analysis_functions.R with decorators
#* @mcp_tool
#* @description Load CSV data
load_data <- function(path) { read.csv(path) }

#* @mcp_tool  
#* @description Clean missing values
clean_data <- function(data) { na.omit(data) }

# Generate server package
mcp_create_server(
  source = "analysis_functions.R",
  output_dir = "analysis-server",
  name = "analysis-tools"
)

# Install and use
# cd analysis-server && npm install -g .
```

### Use Case 2: Package Author Integration
A package author wants to make ggplot2 functions available:
```r
# Selective exposure of ggplot2
mcp_create_server(
  package = "ggplot2", 
  include = c("ggplot", "aes", "geom_*", "theme_*"),
  exclude = c("*.data", "update_*"),
  output_dir = "ggplot2-mcp-server",
  name = "ggplot2-tools"
)

# Creates a complete npm package with:
# - Node.js wrapper for subprocess handling
# - Clean R server (no stderr output)
# - Ready for npm install -g
```

### Use Case 3: Research Workflow
A researcher wants to expose their entire workflow:
```r
# Create server from directory of R files
mcp_create_server(
  source = "R/",  # Scans all .R files for @mcp_* decorators
  output_dir = "research-mcp-server",
  name = "research-tools",
  prompts = list(
    analyze_experiment = "Analyze {experiment_name} using {method}"
  )
)

# Resulting server works reliably with Claude Desktop
# thanks to Node.js wrapper handling subprocess issues
```

## Open Questions

1. **Async Operations**: How should we handle long-running R computations?
2. **State Management**: Should servers be stateless or maintain session state?
3. **Error Recovery**: How to handle R errors gracefully in the protocol?
4. **Resource Limits**: Should we implement rate limiting or resource quotas?
5. **Versioning**: How to handle protocol version differences?

## Risks and Mitigations

### Technical Risks
- **Risk**: R's subprocess stdin handling is fundamentally broken
  - **Mitigation**: Mandatory Node.js wrapper layer for all servers
  
- **Risk**: R packages write to stderr, breaking MCP connections
  - **Mitigation**: Node.js wrapper filters all stderr output
  
- **Risk**: R's single-threaded nature may limit concurrency
  - **Mitigation**: Use future/promises for async operations
  
- **Risk**: Type conversion edge cases
  - **Mitigation**: Extensive testing, clear documentation of limitations

### Adoption Risks
- **Risk**: Competition from Python/JS implementations
  - **Mitigation**: Focus on R-specific strengths, seamless package integration
  
- **Risk**: Learning curve for decorators
  - **Mitigation**: Excellent documentation, similarity to plumber

## Appendix

### Model Context Protocol Overview
MCP is an open protocol that standardizes how AI assistants interact with external systems. Key features:
- JSON-RPC 2.0 based
- Support for tools, resources, prompts, and sampling
- Multiple transport options
- Secure by design

### References
- [MCP Specification](https://modelcontextprotocol.io/specification)
- [Plumber Package](https://www.rplumber.io/)
- [GitHub Issues](https://github.com/chi2labs/mcpr/issues)

---

*Document Version: 1.0*  
*Date: 2025-06-18*  
*Author: mcpr Development Team*