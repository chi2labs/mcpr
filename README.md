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

# Create a new HTTP MCP server
server <- mcp_http(name = "My R Analysis Server", version = "1.0.0", port = 8080)

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

# Run the server
server$mcp_run()
```

## Configure Claude Desktop

Add your server to Claude Desktop's configuration:

```json
{
  "mcpServers": {
    "r-analysis": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

## HTTP Transport

mcpr uses HTTP transport as the primary method for MCP communication, offering several advantages:

- **Multiple clients**: Handle concurrent connections
- **Standard debugging**: Use curl, Postman, or browser tools
- **Easy deployment**: Deploy to cloud platforms or containers
- **Built-in logging**: Track requests and errors
- **Reliable communication**: No subprocess or stdin/stdout issues

### Quick Start

```r
# Start a hello world HTTP server
mcp_hello_world_http(port = 8080)

# Test with curl:
# curl -X POST http://localhost:8080/mcp \
#   -H "Content-Type: application/json" \
#   -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

### Creating Servers from Functions

```r
# Create server with multiple tools
server <- mcp_http("Stats Server", "1.0.0", port = 8080)

# Register existing R functions
server$mcp_tool(
  name = "t_test",
  fn = t.test,
  description = "Perform t-test"
)

server$mcp_tool(
  name = "cor_test",
  fn = cor.test,
  description = "Correlation test"
)

# Start the server
server$mcp_run()
```

### Using Decorators (Coming Soon)

```r
#* @mcp_tool
#* @description Calculate summary statistics
#* @param data A numeric vector
calculate_stats <- function(data) {
  list(mean = mean(data), sd = sd(data))
}

# Load decorated functions
server <- mcp_http()
server$source("analysis_functions.R")
server$mcp_run(port = 8080)
```

## Deployment Options

### Local Development
Run the server locally for Claude Desktop:

```r
server <- mcp_http("My Server", "1.0.0")
# ... add tools ...
server$mcp_run(port = 8080)
```

### Production Deployment
Deploy to production environments:

```r
# Configure for production
server <- mcp_http(
  name = "Production Server",
  version = "1.0.0",
  host = "0.0.0.0",  # Listen on all interfaces
  port = 8080,
  log_file = "mcp-server.log",
  log_level = "info"
)

# Add authentication (coming soon)
# server$use_auth(api_key = Sys.getenv("MCP_API_KEY"))

server$mcp_run()
```

### Docker Deployment
Create a Dockerfile for your MCP server:

```dockerfile
FROM rocker/r-ver:4.3.0
RUN install.packages(c("mcpr", "plumber", "jsonlite"))
COPY server.R /app/
WORKDIR /app
EXPOSE 8080
CMD ["Rscript", "server.R"]
```

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
- HTTP transport with plumber integration
- JSON-RPC 2.0 protocol handling
- Comprehensive test suite
- Logging and error handling
- JSON serialization fixes for MCP compliance

🚧 **In Progress**:
- Decorator system for function annotations
- WebSocket transport
- Package scanning functionality
- Authentication support

📋 **Planned**:
- Source file parsing with decorators
- Advanced security features
- Performance optimizations
- Cloud deployment templates

## Example Servers

See the `inst/examples/` directory for complete examples:
- `basic-server.R` - Simple server with basic tools
- `stats-server.R` - Statistical analysis tools
- `data-server.R` - Data manipulation and visualization

## Development

To run tests:

```r
devtools::test()
```

To build documentation:

```r
devtools::document()
pkgdown::build_site()
```

## Technical Notes

### JSON Serialization
When implementing MCP servers, mcpr handles proper JSON serialization including:
- Automatic scalar unboxing for cleaner JSON
- Protection of empty arrays to ensure they serialize as `[]` not `{}`
- Proper handling of R's special values (NA, NULL, Inf)

### Error Handling
The HTTP transport provides clean error responses following the JSON-RPC 2.0 specification, making debugging easier compared to stdio transport.

## License

MIT + file LICENSE