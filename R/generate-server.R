#' Generate MCP Server Package
#'
#' Creates a complete MCP server package with Node.js wrapper and R server implementation
#'
#' @param name Server name (used in package naming and configuration)
#' @param title Human-readable server title
#' @param description Server description
#' @param version Server version (default: "0.1.0")
#' @param path Directory to create the server in (default: current directory)
#' @param tools List of tool definitions (optional)
#' @param resources List of resource definitions (optional)
#' @param prompts List of prompt definitions (optional)
#' @param template Which template to use: "full" or "minimal" (default: "full")
#' @param author Author name (optional)
#' @param overwrite Whether to overwrite existing directory (default: FALSE)
#'
#' @return Path to the generated server directory
#' @export
#'
#' @examples
#' \dontrun{
#' # Generate a simple server
#' generate_mcp_server("my-analyzer", "My Data Analyzer", 
#'                     "Analyzes data using R functions")
#' 
#' # Generate with tools
#' tools <- list(
#'   analyze = list(
#'     description = "Analyze a dataset",
#'     parameters = list(
#'       data = list(type = "string", description = "Data to analyze")
#'     )
#'   )
#' )
#' generate_mcp_server("analyzer", "Data Analyzer", "Analyzes data",
#'                     tools = tools)
#' }
generate_mcp_server <- function(name, 
                               title, 
                               description,
                               version = "0.1.0",
                               path = ".",
                               tools = NULL,
                               resources = NULL,
                               prompts = NULL,
                               template = "full",
                               author = NULL,
                               overwrite = FALSE) {
  
  # Validate inputs
  if (!grepl("^[a-z0-9-]+$", name)) {
    stop("Server name must contain only lowercase letters, numbers, and hyphens")
  }
  
  # Create server directory
  server_dir <- file.path(path, paste0("mcp-", name))
  
  if (dir.exists(server_dir)) {
    if (!overwrite) {
      stop(sprintf("Directory '%s' already exists. Use overwrite=TRUE to replace.", server_dir))
    } else {
      unlink(server_dir, recursive = TRUE)
    }
  }
  
  dir.create(server_dir, recursive = TRUE)
  
  # Prepare template variables
  vars <- list(
    SERVER_NAME = name,
    SERVER_TITLE = title,
    SERVER_DESCRIPTION = description,
    SERVER_VERSION = version,
    AUTHOR_NAME = author %||% Sys.info()["user"],
    YEAR = format(Sys.Date(), "%Y"),
    R_SCRIPT_PATH = "./server.R",
    R_FLAGS = "--quiet --slave --no-echo"
  )
  
  # Generate R server
  generate_r_server(server_dir, vars, tools, resources, prompts, template)
  
  # Generate supporting files
  generate_readme(server_dir, vars)
  generate_gitignore(server_dir)
  
  # Make server script executable
  server_path <- file.path(server_dir, "server.R")
  Sys.chmod(server_path, "755")
  
  message(sprintf("MCP server '%s' created successfully in: %s", name, server_dir))
  message("\nNext steps:")
  message("1. cd ", server_dir)
  message("2. npm install")
  message("3. npm test")
  message("4. Add to Claude Desktop configuration (see mcp.json)")
  
  invisible(server_dir)
}