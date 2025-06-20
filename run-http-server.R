#!/usr/bin/env Rscript
#' Start mcpr HTTP Demo Server
#'
#' This script starts the mcpr demo server on HTTP transport.

library(mcpr)

# Create server using regular mcp() function
server <- mcp(
  name = "mcpr Demo Server",
  version = "1.0.0"
)

# Tool: Get package information
server$mcp_tool(
  name = "package_info",
  fn = function(package = "mcpr") {
    if (!requireNamespace(package, quietly = TRUE)) {
      return(paste("Package", package, "is not installed"))
    }
    
    pkg_desc <- packageDescription(package)
    list(
      name = package,
      version = pkg_desc$Version,
      title = pkg_desc$Title,
      description = pkg_desc$Description,
      license = pkg_desc$License
    )
  },
  description = "Get information about an R package"
)

# Tool: Run R code
server$mcp_tool(
  name = "run_code",
  fn = function(code) {
    # Capture output and result
    output <- capture.output({
      result <- try(eval(parse(text = code)), silent = FALSE)
    })
    
    if (inherits(result, "try-error")) {
      return(list(
        success = FALSE,
        error = as.character(result),
        output = output
      ))
    }
    
    list(
      success = TRUE,
      result = if (is.null(result)) "NULL" else as.character(result),
      output = output,
      class = class(result)
    )
  },
  description = "Execute R code and return the result"
)

# Resource: Server status
server$mcp_resource(
  name = "status",
  fn = function() {
    paste(
      "Server:", server$name,
      "\nVersion:", server$version,
      "\nR Version:", R.version.string,
      "\nmcpr Version:", packageVersion("mcpr"),
      "\nTools:", length(server$tools),
      "\nResources:", length(server$resources)
    )
  },
  description = "Server status information",
  mime_type = "text/plain"
)

# Prompt: Code review
server$mcp_prompt(
  name = "analyze",
  template = "Please analyze this R code: {code}\nFocus on: {aspect}",
  description = "Template for code analysis",
  parameters = list(
    code = list(type = "string", description = "R code to analyze"),
    aspect = list(type = "string", description = "What to focus on")
  )
)

# Start message
cat("\n=== mcpr Demo Server (HTTP) ===\n")
cat("Starting on: http://localhost:8000\n")
cat("Tools: package_info, run_code\n")
cat("Resources: status\n")
cat("Prompts: analyze\n\n")

# Start the server with HTTP transport
server$mcp_run(transport = "http", host = "127.0.0.1", port = 8000)