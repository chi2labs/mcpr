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