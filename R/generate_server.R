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


#' Generate R Server
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @param tools Tool definitions
#' @param resources Resource definitions
#' @param prompts Prompt definitions
#' @param template Template type
#' @keywords internal
generate_r_server <- function(server_dir, vars, tools, resources, prompts, template) {
  template_file <- if (template == "minimal") "minimal-server.R" else "server.R"
  template_path <- system.file("templates", template_file, package = "mcpr")
  
  if (!file.exists(template_path)) {
    stop(sprintf("Server template '%s' not found.", template_file))
  }
  
  server_content <- readLines(template_path)
  
  # Add tool, resource, and prompt definitions
  if (!is.null(tools)) {
    vars$TOOLS_DEFINITION <- format_tools_definition(tools)
  }
  if (!is.null(resources)) {
    vars$RESOURCES_DEFINITION <- format_resources_definition(resources)
  }
  if (!is.null(prompts)) {
    vars$PROMPTS_DEFINITION <- format_prompts_definition(prompts)
  }
  
  server_content <- replace_template_vars(server_content, vars)
  
  server_path <- file.path(server_dir, "server.R")
  writeLines(server_content, server_path)
}


#' Generate README.md
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @keywords internal
generate_readme <- function(server_dir, vars) {
  template_path <- system.file("templates", "README.md", package = "mcpr")
  content <- readLines(template_path)
  content <- replace_template_vars(content, vars)
  writeLines(content, file.path(server_dir, "README.md"))
}


#' Generate .gitignore
#'
#' @param server_dir Server directory path
#' @keywords internal
generate_gitignore <- function(server_dir) {
  template_path <- system.file("templates", "gitignore", package = "mcpr")
  file.copy(template_path, file.path(server_dir, ".gitignore"))
}

#' Format Tools Definition for R Code
#'
#' @param tools List of tool definitions
#' @return Formatted R code string
#' @keywords internal
format_tools_definition <- function(tools) {
  if (is.null(tools) || length(tools) == 0) {
    return("")
  }
  
  code_lines <- character()
  
  for (tool_name in names(tools)) {
    tool <- tools[[tool_name]]
    code_lines <- c(code_lines, 
                   sprintf("  %s = list(", tool_name),
                   sprintf("    description = \"%s\",", tool$description),
                   "    parameters = list(")
    
    if (!is.null(tool$parameters)) {
      param_lines <- character()
      for (param_name in names(tool$parameters)) {
        param <- tool$parameters[[param_name]]
        param_lines <- c(param_lines,
                        sprintf("      %s = list(type = \"%s\", description = \"%s\")",
                               param_name, 
                               param$type %||% "string",
                               param$description %||% ""))
      }
      code_lines <- c(code_lines, paste0(param_lines, collapse = ",\n"))
    }
    
    code_lines <- c(code_lines, "    )", "  )")
  }
  
  paste0(code_lines, collapse = ",\n")
}

#' Format Resources Definition for R Code
#'
#' @param resources List of resource definitions
#' @return Formatted R code string
#' @keywords internal
format_resources_definition <- function(resources) {
  if (is.null(resources) || length(resources) == 0) {
    return("")
  }
  
  code_lines <- character()
  
  for (i in seq_along(resources)) {
    res <- resources[[i]]
    code_lines <- c(code_lines,
                   "  list(",
                   sprintf("    uri = \"%s\",", res$uri),
                   sprintf("    name = \"%s\",", res$name),
                   sprintf("    description = \"%s\"", res$description %||% ""),
                   "  )")
  }
  
  paste0(code_lines, collapse = ",\n")
}

#' Format Prompts Definition for R Code
#'
#' @param prompts List of prompt definitions
#' @return Formatted R code string
#' @keywords internal
format_prompts_definition <- function(prompts) {
  if (is.null(prompts) || length(prompts) == 0) {
    return("")
  }
  
  code_lines <- character()
  
  for (prompt_name in names(prompts)) {
    prompt <- prompts[[prompt_name]]
    code_lines <- c(code_lines,
                   sprintf("  %s = list(", prompt_name),
                   sprintf("    description = \"%s\"", prompt$description %||% ""),
                   "  )")
  }
  
  paste0(code_lines, collapse = ",\n")
}

