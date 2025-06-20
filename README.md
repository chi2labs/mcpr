# mcpr

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN status](https://www.r-pkg.org/badges/version/mcpr)](https://CRAN.R-project.org/package=mcpr)
<!-- badges: end -->

mcpr exposes R functions through the Model Context Protocol (MCP), enabling seamless integration with AI assistants like Claude Desktop.

## Installation

```r
# install.packages("devtools")
devtools::install_github("chi2labs/mcpr")
```

## Quick Start

### Basic Server

```r
library(mcpr)

# Create and configure server
server <- mcp_http("My R Analysis Server", "1.0.0", port = 8080)

# Add tools
server$mcp_tool(
  name = "calculate_mean",
  fn = function(numbers) mean(numbers),
  description = "Calculate the mean of a numeric vector"
)

# Run server
server$mcp_run()
```

### Using Decorators

Create a file with decorated functions:

```r
# analysis-tools.R
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
```

Load and run:

```r
server <- mcp("Analysis Server", "1.0.0")
server$mcp_source("analysis-tools.R")
server$mcp_run(transport = "http", port = 8080)
```

## Configure Claude Desktop

Add to Claude Desktop's configuration:

```json
{
  "mcpServers": {
    "r-analysis": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

## Advanced Usage

### Register Existing Functions

```r
server <- mcp_http("Stats Server", "1.0.0")

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
```

### Production Deployment

```r
server <- mcp_http(
  name = "Production Server",
  version = "1.0.0",
  host = "0.0.0.0",  # Listen on all interfaces
  port = 8080,
  log_file = "mcp-server.log",
  log_level = "info"
)
```

### Docker Deployment

```dockerfile
FROM rocker/r-ver:4.3.0
RUN install.packages(c("mcpr", "plumber", "jsonlite"))
COPY server.R /app/
WORKDIR /app
EXPOSE 8080
CMD ["Rscript", "server.R"]
```

## Examples

Complete examples in `inst/examples/`:
- `basic-server.R` - Simple server with basic tools
- `stats-server.R` - Statistical analysis tools
- `data-server.R` - Data manipulation and visualization

## License

MIT + file LICENSE