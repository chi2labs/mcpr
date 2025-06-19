#!/usr/bin/env Rscript
#' MCP HTTP Server for mcpr Package
#'
#' This server demonstrates the mcpr package's HTTP transport capabilities.
#' It includes tools for R package development and analysis.

library(mcpr)

# Create HTTP server
server <- mcp_http(
  name = "mcpr Demo Server",
  version = "1.0.0",
  host = "127.0.0.1",
  port = 8000,
  log_level = "info"
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
      author = pkg_desc$Author,
      maintainer = pkg_desc$Maintainer,
      license = pkg_desc$License,
      depends = pkg_desc$Depends,
      imports = pkg_desc$Imports,
      suggests = pkg_desc$Suggests
    )
  },
  description = "Get information about an R package",
  parameters = list(
    type = "object",
    properties = list(
      package = list(
        type = "string",
        description = "Name of the R package (default: mcpr)"
      )
    )
  )
)

# Tool: List exported functions
server$mcp_tool(
  name = "list_exports",
  fn = function(package = "mcpr") {
    if (!requireNamespace(package, quietly = TRUE)) {
      return(paste("Package", package, "is not installed"))
    }
    
    exports <- getNamespaceExports(package)
    list(
      package = package,
      count = length(exports),
      exports = sort(exports)
    )
  },
  description = "List all exported functions from an R package",
  parameters = list(
    type = "object",
    properties = list(
      package = list(
        type = "string",
        description = "Name of the R package (default: mcpr)"
      )
    )
  )
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
  description = "Execute R code and return the result",
  parameters = list(
    type = "object",
    properties = list(
      code = list(
        type = "string",
        description = "R code to execute"
      )
    ),
    required = list("code")
  )
)

# Tool: Generate MCP server
server$mcp_tool(
  name = "generate_server",
  fn = function(name, title, description = NULL, output_dir = tempdir()) {
    # Generate a simple MCP server
    server_dir <- file.path(output_dir, paste0("mcp-", name))
    
    tryCatch({
      generate_mcp_server(
        name = name,
        title = title,
        description = description %||% paste("MCP server:", title),
        path = output_dir,
        template = "minimal"
      )
      
      list(
        success = TRUE,
        path = server_dir,
        files = list.files(server_dir, recursive = TRUE),
        message = paste("Server generated at:", server_dir)
      )
    }, error = function(e) {
      list(
        success = FALSE,
        error = as.character(e),
        message = "Failed to generate server"
      )
    })
  },
  description = "Generate a new MCP server package",
  parameters = list(
    type = "object",
    properties = list(
      name = list(
        type = "string",
        description = "Server name (lowercase, hyphens allowed)"
      ),
      title = list(
        type = "string",
        description = "Human-readable server title"
      ),
      description = list(
        type = "string",
        description = "Server description (optional)"
      ),
      output_dir = list(
        type = "string",
        description = "Output directory (default: temp directory)"
      )
    ),
    required = list("name", "title")
  )
)

# Resource: Package README
server$mcp_resource(
  name = "readme",
  fn = function() {
    readme_path <- system.file("../README.md", package = "mcpr")
    if (readme_path == "") {
      # Try relative path if installed version doesn't have it
      readme_path <- "README.md"
    }
    
    if (file.exists(readme_path)) {
      readLines(readme_path, warn = FALSE) |> paste(collapse = "\n")
    } else {
      "README.md not found. Visit https://github.com/chi2labs/mcpr for documentation."
    }
  },
  description = "mcpr package README",
  mime_type = "text/markdown"
)

# Resource: Server status
server$mcp_resource(
  name = "status",
  fn = function() {
    list(
      server = "mcpr Demo Server",
      version = "1.0.0",
      r_version = R.version.string,
      platform = R.version$platform,
      mcpr_version = packageVersion("mcpr"),
      loaded_packages = length(loadedNamespaces()),
      session_info = capture.output(sessionInfo())
    ) |> jsonlite::toJSON(pretty = TRUE, auto_unbox = TRUE)
  },
  description = "Current server and R session status",
  mime_type = "application/json"
)

# Prompt: Code review
server$mcp_prompt(
  name = "review_code",
  template = "Please review the following R code for best practices, potential issues, and improvements:\n\n{code}\n\nFocus on: {focus}",
  description = "Template for R code review requests",
  parameters = list(
    code = list(
      type = "string",
      description = "R code to review"
    ),
    focus = list(
      type = "string",
      description = "Specific aspects to focus on (e.g., performance, style, correctness)"
    )
  )
)

# Start message
cat("\n")
cat("==================================================\n")
cat("        mcpr Demo Server (HTTP Transport)         \n")
cat("==================================================\n")
cat("\n")
cat("Server starting on: http://127.0.0.1:8000\n")
cat("\n")
cat("Available tools:\n")
cat("  - package_info   : Get R package information\n")
cat("  - list_exports   : List package exports\n")
cat("  - run_code       : Execute R code\n")
cat("  - generate_server: Generate MCP server\n")
cat("\n")
cat("Available resources:\n")
cat("  - readme : mcpr package documentation\n")
cat("  - status : Server and session information\n")
cat("\n")
cat("Available prompts:\n")
cat("  - review_code : R code review template\n")
cat("\n")
cat("Test with:\n")
cat("  curl -X POST http://localhost:8000/mcp \\\n")
cat("    -H 'Content-Type: application/json' \\\n")
cat("    -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}'\n")
cat("\n")
cat("Press Ctrl+C to stop the server\n")
cat("==================================================\n")
cat("\n")

# Start the server
server$mcp_run()