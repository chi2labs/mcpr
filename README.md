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

# Or run with HTTP transport (new!)
server$mcp_run(transport = "http", port = 8080)
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
#       "url": "http://localhost:8080/mcp"
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

## HTTP Transport (New!)

mcpr now supports HTTP transport as an alternative to stdio, offering several advantages:

```r
# Create an HTTP server
server <- mcp_http(
  name = "My HTTP API",
  version = "1.0.0",
  port = 8080
)

# Add tools as usual
server$mcp_tool(
  name = "analyze",
  fn = function(data) summary(as.numeric(strsplit(data, ",")[[1]])),
  description = "Analyze comma-separated numbers"
)

# Start the server
server$mcp_run()  # Automatically uses HTTP
```

### Quick Start with HTTP

```r
# Start a hello world HTTP server
mcp_hello_world_http(port = 8080)

# Test with curl:
# curl -X POST http://localhost:8080/mcp \
#   -H "Content-Type: application/json" \
#   -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

### HTTP Features

- **Multiple clients**: Handle concurrent connections
- **Standard debugging**: Use curl, Postman, or browser tools
- **Easy deployment**: Deploy to cloud platforms or containers
- **Built-in logging**: Track requests and errors
- **No subprocess issues**: Avoids R's stdin limitations

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
- HTTP transport with plumber integration
- JSON-RPC 2.0 protocol handling
- Node.js wrapper template generation
- Server package generation from code or configuration
- Comprehensive test suite
- Logging and error handling for HTTP servers

🚧 **In Progress**:
- Decorator system for function annotations
- WebSocket transport
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