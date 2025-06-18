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

## Generating Standalone MCP Servers

Due to R's stdin handling limitations in subprocess contexts, mcpr provides Node.js wrapper templates that ensure reliable communication with MCP clients like Claude Desktop.

### Quick Server Generation

Generate a complete MCP server package with Node.js wrapper:

```r
# Generate a simple server
generate_mcp_server(
  name = "my-tools",
  title = "My R Tools", 
  description = "Useful R tools for data analysis",
  tools = list(
    analyze = list(
      description = "Analyze a dataset",
      parameters = list(
        data = list(type = "object", description = "Data to analyze")
      )
    )
  )
)
```

This creates a complete server in `./mcp-my-tools/` with:
- `wrapper.js` - Node.js wrapper that handles stdin/stdout properly
- `server.R` - R server implementation
- `package.json` - NPM package configuration
- Test and documentation files

### Using the Generated Server

```bash
cd mcp-my-tools
npm install
npm test

# Add to Claude Desktop config:
# {
#   "mcpServers": {
#     "my-tools": {
#       "command": "node",
#       "args": ["/path/to/mcp-my-tools/wrapper.js"]
#     }
#   }
# }
```

### Generating from Existing Server Objects

```r
# Create and configure a server
server <- mcp(name = "Stats Server", version = "1.0.0")
server$mcp_tool(name = "t_test", fn = t.test, description = "Perform t-test")
server$mcp_tool(name = "cor_test", fn = cor.test, description = "Correlation test")

# Generate standalone package
server$generate(path = "./servers")
```

### Configuration Files

Create servers from YAML or JSON configuration:

```r
# Create example configuration
create_example_config("server-config.yaml")

# Generate from configuration
generate_from_config("server-config.yaml")
```

See `vignette("creating-servers")` for detailed documentation on server generation.

## Current Implementation Status

✅ **Completed**:
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
- Node.js wrapper template generation
- Server package generation from code or configuration
- Comprehensive test suite

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