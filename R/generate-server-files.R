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