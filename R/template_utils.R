#' Replace Template Variables
#'
#' Replaces \code{\{\{VARIABLE\}\}} placeholders in template content with actual values
#'
#' @param content Character vector of template content
#' @param vars Named list of variable replacements
#' @return Character vector with replacements made
#' @keywords internal
replace_template_vars <- function(content, vars) {
  # Convert content to a single string for easier replacement
  text <- paste(content, collapse = "\n")
  
  # Replace each variable
  for (var_name in names(vars)) {
    pattern <- sprintf("\\{\\{%s\\}\\}", var_name)
    replacement <- as.character(vars[[var_name]])
    text <- gsub(pattern, replacement, text, perl = TRUE)
  }
  
  # Split back into lines
  strsplit(text, "\n", fixed = TRUE)[[1]]
}

#' Validate Server Configuration
#'
#' Validates that server configuration meets requirements
#'
#' @param config Server configuration list
#' @return TRUE if valid, otherwise throws error
#' @keywords internal
validate_server_config <- function(config) {
  required_fields <- c("name", "title", "description")
  
  for (field in required_fields) {
    if (is.null(config[[field]]) || config[[field]] == "") {
      stop(sprintf("Required field '%s' is missing or empty", field))
    }
  }
  
  # Validate name format
  if (!grepl("^[a-z0-9-]+$", config$name)) {
    stop("Server name must contain only lowercase letters, numbers, and hyphens")
  }
  
  # Validate tools if provided
  if (!is.null(config$tools)) {
    validate_tools_config(config$tools)
  }
  
  # Validate resources if provided
  if (!is.null(config$resources)) {
    validate_resources_config(config$resources)
  }
  
  # Validate prompts if provided
  if (!is.null(config$prompts)) {
    validate_prompts_config(config$prompts)
  }
  
  TRUE
}

#' Validate Tools Configuration
#'
#' @param tools Tools configuration
#' @keywords internal
validate_tools_config <- function(tools) {
  if (!is.list(tools)) {
    stop("Tools must be a list")
  }
  
  for (tool_name in names(tools)) {
    tool <- tools[[tool_name]]
    
    if (!is.list(tool)) {
      stop(sprintf("Tool '%s' must be a list", tool_name))
    }
    
    if (is.null(tool$description)) {
      stop(sprintf("Tool '%s' must have a description", tool_name))
    }
    
    if (!is.null(tool$parameters) && !is.list(tool$parameters)) {
      stop(sprintf("Parameters for tool '%s' must be a list", tool_name))
    }
  }
}

#' Validate Resources Configuration
#'
#' @param resources Resources configuration
#' @keywords internal
validate_resources_config <- function(resources) {
  if (!is.list(resources)) {
    stop("Resources must be a list")
  }
  
  for (i in seq_along(resources)) {
    res <- resources[[i]]
    
    if (!is.list(res)) {
      stop(sprintf("Resource %d must be a list", i))
    }
    
    required <- c("uri", "name")
    for (field in required) {
      if (is.null(res[[field]])) {
        stop(sprintf("Resource %d must have a '%s' field", i, field))
      }
    }
  }
}

#' Validate Prompts Configuration
#'
#' @param prompts Prompts configuration
#' @keywords internal
validate_prompts_config <- function(prompts) {
  if (!is.list(prompts)) {
    stop("Prompts must be a list")
  }
  
  for (prompt_name in names(prompts)) {
    prompt <- prompts[[prompt_name]]
    
    if (!is.list(prompt)) {
      stop(sprintf("Prompt '%s' must be a list", prompt_name))
    }
  }
}

#' Create Server Directory Structure
#'
#' Creates the standard directory structure for an MCP server
#'
#' @param base_path Base directory path
#' @param server_name Server name
#' @return Path to created server directory
#' @keywords internal
create_server_structure <- function(base_path, server_name) {
  server_dir <- file.path(base_path, paste0("mcp-", server_name))
  
  # Create main directory
  dir.create(server_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Create subdirectories if needed
  dirs <- c("lib", "test", "docs")
  for (d in dirs) {
    dir.create(file.path(server_dir, d), showWarnings = FALSE)
  }
  
  server_dir
}

#' Load Server Configuration from File
#'
#' Loads server configuration from a YAML or JSON file
#'
#' @param config_file Path to configuration file
#' @return Configuration list
#' @export
load_server_config <- function(config_file) {
  if (!file.exists(config_file)) {
    stop(sprintf("Configuration file '%s' not found", config_file))
  }
  
  ext <- tolower(tools::file_ext(config_file))
  
  if (ext == "json") {
    config <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
  } else if (ext %in% c("yaml", "yml")) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
      stop("Package 'yaml' is required to read YAML configuration files")
    }
    config <- yaml::read_yaml(config_file)
  } else {
    stop("Configuration file must be JSON or YAML")
  }
  
  validate_server_config(config)
  config
}

#' Generate Server from Configuration File
#'
#' Generates an MCP server from a configuration file
#'
#' @param config_file Path to configuration file (JSON or YAML)
#' @param path Directory to create server in
#' @param overwrite Whether to overwrite existing directory
#' @return Path to generated server
#' @export
#'
#' @examples
#' \dontrun{
#' # From YAML config
#' generate_from_config("server-config.yaml")
#' 
#' # From JSON config
#' generate_from_config("server-config.json", path = "./servers")
#' }
generate_from_config <- function(config_file, path = ".", overwrite = FALSE) {
  config <- load_server_config(config_file)
  
  generate_mcp_server(
    name = config$name,
    title = config$title,
    description = config$description,
    version = config$version %||% "0.1.0",
    path = path,
    tools = config$tools,
    resources = config$resources,
    prompts = config$prompts,
    template = config$template %||% "full",
    author = config$author,
    overwrite = overwrite
  )
}

#' Create Example Configuration File
#'
#' Creates an example configuration file for server generation
#'
#' @param filename Output filename
#' @param format File format: "json" or "yaml" (default: "yaml")
#' @export
create_example_config <- function(filename = "server-config.yaml", format = "yaml") {
  config <- list(
    name = "example-server",
    title = "Example MCP Server",
    description = "An example Model Context Protocol server",
    version = "0.1.0",
    author = "Your Name",
    template = "full",
    tools = list(
      greet = list(
        description = "Greet someone",
        parameters = list(
          name = list(
            type = "string",
            description = "Name to greet"
          )
        )
      ),
      calculate = list(
        description = "Perform a calculation",
        parameters = list(
          expression = list(
            type = "string",
            description = "R expression to evaluate"
          )
        )
      )
    ),
    resources = list(
      list(
        uri = "data://example",
        name = "Example Data",
        description = "Example dataset"
      )
    ),
    prompts = list(
      analyze = list(
        description = "Analyze data and provide insights"
      )
    )
  )
  
  if (format == "json") {
    jsonlite::write_json(config, filename, pretty = TRUE, auto_unbox = TRUE)
  } else if (format == "yaml") {
    if (!requireNamespace("yaml", quietly = TRUE)) {
      stop("Package 'yaml' is required to write YAML files")
    }
    yaml::write_yaml(config, filename)
  } else {
    stop("Format must be 'json' or 'yaml'")
  }
  
  message(sprintf("Example configuration written to: %s", filename))
  invisible(filename)
}