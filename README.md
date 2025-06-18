# mcpr

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN status](https://www.r-pkg.org/badges/version/mcpr)](https://CRAN.R-project.org/package=mcpr)
<!-- badges: end -->

The goal of mcpr is to expose R functions, files, or entire packages through the Model Context Protocol (MCP). This allows R code to integrate seamlessly with AI assistants like Claude Desktop.

## Installation

You can install the development version of mcpr from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("chi2labs/mcpr")
```

## Basic Usage

Create a simple MCP server with tools and resources:

```r
library(mcpr)

# Create a new MCP server
server <- mcp(name = "My R Analysis Server", version = "1.0.0")

# Add a tool
server$mcp_tool(
  name = "calculate_mean",
  fn = function(numbers) mean(numbers),
  description = "Calculate the mean of a numeric vector"
)

# Add a resource
server$mcp_resource(
  name = "info",
  fn = function() "This server provides statistical analysis tools",
  description = "Server information"
)

# Run the server on stdio (for Claude Desktop)
server$mcp_run(transport = "stdio")
```

## Current Implementation Status

✅ **Completed (Phase 1)**:
- Type conversion system (R ↔ JSON) with comprehensive support for:
  - Atomic types (numeric, character, logical)
  - Vectors and matrices
  - Data frames and factors
  - Lists and arrays
  - S3/S4 objects
- Basic MCP server object with builder pattern
- Tool, resource, and prompt registration
- stdio transport implementation
- JSON-RPC 2.0 protocol handling
- Comprehensive test suite for type conversion

🚧 **In Progress**:
- Decorator system for function annotations
- HTTP and WebSocket transports
- Package scanning functionality

📋 **Planned**:
- Source file parsing with decorators
- Integration examples
- Performance optimizations
- Security features

## Example Server

See `inst/examples/basic-server.R` for a complete example of creating an MCP server with multiple tools and resources.

## Development

To run tests:

```r
devtools::test()
```

To build documentation:

```r
devtools::document()
```

## License

MIT + file LICENSE