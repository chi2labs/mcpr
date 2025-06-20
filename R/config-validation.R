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