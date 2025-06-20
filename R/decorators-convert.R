#' Convert decorator metadata to MCP registration parameters
#'
#' @param element A parsed element from parse_mcp_decorators
#' @return A list with parameters suitable for MCP registration
decorators_to_mcp_params <- function(element) {
  params <- list(
    name = element$name,
    description = element$decorators$description
  )
  
  # Handle parameters for tools
  if (element$type == "mcp_tool" && !is.null(element$decorators$params)) {
    properties <- list()
    required <- character()
    
    for (param_name in names(element$decorators$params)) {
      param_info <- element$decorators$params[[param_name]]
      
      # Map R types to JSON Schema types
      json_type <- switch(param_info$type,
        "numeric" = "number",
        "integer" = "integer",
        "character" = "string",
        "logical" = "boolean",
        "list" = "object",
        "data.frame" = "object",
        "vector" = "array",
        "string"  # default
      )
      
      properties[[param_name]] <- list(
        type = json_type,
        description = param_info$description
      )
      
      # Mark as required if no default value mentioned
      # This is a simple heuristic - could be improved
      if (!grepl("default:", param_info$description, ignore.case = TRUE)) {
        required <- c(required, param_name)
      }
    }
    
    params$parameters <- list(
      type = "object",
      properties = properties,
      required = if (length(required) > 0) required else NULL
    )
  }
  
  # Handle resource-specific attributes
  if (element$type == "mcp_resource") {
    params$mime_type <- element$decorators$mime_type %||% "text/plain"
  }
  
  # Handle prompt-specific attributes
  if (element$type == "mcp_prompt") {
    params$template <- element$decorators$template
    
    if (!is.null(params$template)) {
      # Extract template parameters from {param} patterns
      template_params <- gregexpr("\\{([^}]+)\\}", params$template)
      if (template_params[[1]][1] != -1) {
        param_names <- gsub("[{}]", "", regmatches(params$template, template_params)[[1]])
        
        params$parameters <- list()
        for (pname in param_names) {
          # Look for parameter description in decorators
          param_desc <- element$decorators[[paste0("param_", pname)]] %||% paste("Parameter", pname)
          params$parameters[[pname]] <- list(
            type = "string",
            description = param_desc
          )
        }
      }
    }
  }
  
  return(params)
}

# Helper function for NULL default values (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) {
    if (is.null(x)) y else x
  }
}