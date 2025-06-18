#!/usr/bin/env Rscript

# Minimal MCP Server Template
# This is a simplified version for quick function wrapping

suppressPackageStartupMessages(library(jsonlite))

# Simple JSON-RPC handling
stdin_con <- file("stdin", open = "r", blocking = TRUE)
on.exit(close(stdin_con))

# Tool implementations
{{TOOL_FUNCTIONS}}

# Main loop
repeat {
  line <- readLines(stdin_con, n = 1, warn = FALSE)
  if (length(line) == 0) break
  
  request <- fromJSON(line, simplifyVector = FALSE)
  
  response <- list(jsonrpc = "2.0", id = request$id)
  
  if (request$method == "initialize") {
    response$result <- list(
      protocolVersion = "2024-11-05",
      capabilities = list(tools = list({{TOOL_LIST}})),
      serverInfo = list(name = "{{SERVER_NAME}}", version = "1.0.0")
    )
  } else if (request$method == "tools/list") {
    response$result <- list(tools = list({{TOOL_LIST}}))
  } else if (request$method == "tools/call") {
    result <- do.call(request$params$name, request$params$arguments)
    response$result <- list(content = list(list(type = "text", text = as.character(result))))
  }
  
  cat(toJSON(response, auto_unbox = TRUE), "\n", sep = "")
  flush(stdout())
}