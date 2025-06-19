#!/usr/bin/env Rscript
#' HTTP MCP Server Example
#'
#' This example demonstrates how to create and run an MCP server
#' using HTTP transport instead of stdio. HTTP transport offers
#' several advantages:
#' - Multiple concurrent clients
#' - Easy testing with curl/Postman
#' - Standard HTTP debugging tools
#' - Better deployment options

library(mcpr)

# Create an MCP server using HTTP transport
server <- mcp_http(
  name = "R Analysis Server",
  version = "1.0.0",
  host = "127.0.0.1",
  port = 8080
)

# Add some example tools
server$mcp_tool(
  name = "calculate",
  fn = function(expression) {
    # Safely evaluate mathematical expressions
    result <- try(eval(parse(text = expression)), silent = TRUE)
    if (inherits(result, "try-error")) {
      return(paste("Error:", as.character(result)))
    }
    as.character(result)
  },
  description = "Evaluate a mathematical expression",
  parameters = list(
    type = "object",
    properties = list(
      expression = list(
        type = "string",
        description = "Mathematical expression to evaluate (e.g., '2 + 2')"
      )
    ),
    required = list("expression")
  )
)

server$mcp_tool(
  name = "statistics",
  fn = function(numbers, operation = "mean") {
    # Parse numbers if provided as string
    if (is.character(numbers)) {
      numbers <- as.numeric(strsplit(numbers, ",")[[1]])
    }
    
    result <- switch(operation,
      mean = mean(numbers, na.rm = TRUE),
      median = median(numbers, na.rm = TRUE),
      sd = sd(numbers, na.rm = TRUE),
      min = min(numbers, na.rm = TRUE),
      max = max(numbers, na.rm = TRUE),
      sum = sum(numbers, na.rm = TRUE),
      stop(paste("Unknown operation:", operation))
    )
    
    paste0("Result of ", operation, ": ", result)
  },
  description = "Calculate statistics on a set of numbers",
  parameters = list(
    type = "object",
    properties = list(
      numbers = list(
        type = "string",
        description = "Comma-separated list of numbers"
      ),
      operation = list(
        type = "string",
        description = "Statistical operation (mean, median, sd, min, max, sum)",
        enum = list("mean", "median", "sd", "min", "max", "sum")
      )
    ),
    required = list("numbers")
  )
)

# Add a resource
server$mcp_resource(
  name = "system_info",
  fn = function() {
    info <- list(
      r_version = R.version.string,
      platform = R.version$platform,
      os = Sys.info()[["sysname"]],
      hostname = Sys.info()[["nodename"]],
      user = Sys.info()[["user"]],
      working_directory = getwd(),
      loaded_packages = paste(loadedNamespaces(), collapse = ", ")
    )
    paste(names(info), info, sep = ": ", collapse = "\n")
  },
  description = "Get information about the R environment",
  mime_type = "text/plain"
)

# Add a prompt template
server$mcp_prompt(
  name = "analyze_data",
  template = "Please analyze the following data: {data}\nFocus on: {focus}",
  description = "Template for data analysis requests",
  parameters = list(
    data = list(
      type = "string",
      description = "The data to analyze"
    ),
    focus = list(
      type = "string", 
      description = "What aspect to focus on"
    )
  )
)

# Display server info
cat("\n=== R Analysis HTTP Server ===\n")
cat("Starting server on: http://127.0.0.1:8080\n\n")
cat("Available tools:\n")
cat("  - calculate: Evaluate mathematical expressions\n")
cat("  - statistics: Calculate statistics on numbers\n")
cat("\nAvailable resources:\n")
cat("  - system_info: Get R environment information\n")
cat("\nAvailable prompts:\n")
cat("  - analyze_data: Template for analysis requests\n")
cat("\n")
cat("Example curl commands:\n")
cat("  # List tools:\n")
cat("  curl -X POST http://localhost:8080/mcp \\\n")
cat("    -H 'Content-Type: application/json' \\\n")
cat("    -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}'\n\n")
cat("  # Call calculate tool:\n")
cat("  curl -X POST http://localhost:8080/mcp \\\n")
cat("    -H 'Content-Type: application/json' \\\n")
cat("    -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"calculate\",\"arguments\":{\"expression\":\"pi * 4^2\"}},\"id\":2}'\n\n")
cat("Press Ctrl+C to stop the server\n\n")

# Start the server
# Note: The server will run until interrupted
server$mcp_run(transport = "http")