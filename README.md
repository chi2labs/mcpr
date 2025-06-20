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

### Method 1: Programmatic API

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


# Run the server with HTTP transport (recommended)
server$mcp_run(transport = "http", port = 8080)
```

### Method 2: Decorator Syntax

Use plumber-style decorators to define MCP tools, resources, and prompts:

```r
# Create a file: analysis-tools.R
#* @mcp_tool
#* @description Calculate summary statistics for a numeric vector
#* @param x numeric vector to analyze
#* @param na.rm logical whether to remove NA values (default: TRUE)
calculate_stats <- function(x, na.rm = TRUE) {
  list(
    mean = mean(x, na.rm = na.rm),
    median = median(x, na.rm = na.rm),
    sd = sd(x, na.rm = na.rm),
    min = min(x, na.rm = na.rm),
    max = max(x, na.rm = na.rm)
  )
}

#* @mcp_resource
#* @description List available datasets
#* @mime_type application/json
list_datasets <- function() {
  data(package = "datasets")$results[, "Item"]
}

#* @mcp_prompt
#* @description Request statistical analysis
#* @template Analyze the {{dataset}} dataset using {{method}} and provide insights about {{focus}}
#* @param_dataset The dataset to analyze
#* @param_method The analysis method to use
#* @param_focus The aspect to focus on
statistical_analysis_prompt <- NULL
```

Load decorated functions into a server:

```r
# Create server and load decorated functions
server <- mcp(name = "Analysis Server", version = "1.0.0")
server$mcp_source("analysis-tools.R")

# Run with HTTP transport
server$mcp_run(transport = "http", port = 8080)
```

See the complete example at `inst/examples/decorated-functions.R`.

## Generating Standalone MCP Servers
=======
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