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