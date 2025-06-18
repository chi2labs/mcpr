#!/usr/bin/env Rscript

# Simple MCP Server for testing
suppressPackageStartupMessages(library(mcpr))

# Ensure output is not buffered
if (isatty(stdout())) {
  options(width = Sys.getenv("COLUMNS", 80))
}

# Create a minimal server
server <- mcp(name = "Simple R Server", version = "0.1.0")

# Add one simple tool
server$mcp_tool(
  name = "hello",
  fn = function(name = "World") {
    paste("Hello,", name, "from R!")
  },
  description = "Say hello"
)

# Add another simple tool
server$mcp_tool(
  name = "add",
  fn = function(a, b) {
    list(result = a + b, message = paste(a, "+", b, "=", a + b))
  },
  description = "Add two numbers"
)

# Start the server
server$mcp_run(transport = "stdio")