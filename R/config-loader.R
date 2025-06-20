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