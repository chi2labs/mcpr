#' Enhanced Source File Handling for MCP
#'
#' @description
#' Functions for discovering and loading MCP-decorated functions from
#' source files and directories.
#'
#' @name mcp-source
NULL

#' Scan directory for R files with MCP decorators
#'
#' @param path Directory path to scan
#' @param pattern File pattern to match (default: "\\\\.R$")
#' @param recursive Whether to scan subdirectories
#' @return A list of files containing MCP decorators
#' @export
scan_mcp_directory <- function(path, pattern = "\\.R$", recursive = TRUE) {
  if (!dir.exists(path)) {
    stop("Directory does not exist: ", path)
  }
  
  # Find all R files
  r_files <- list.files(
    path = path, 
    pattern = pattern, 
    full.names = TRUE, 
    recursive = recursive
  )
  
  # Filter to only files with MCP decorators
  mcp_files <- character()
  
  for (file in r_files) {
    # Quick scan for MCP decorators
    lines <- readLines(file, warn = FALSE, n = 100)  # Check first 100 lines
    if (any(grepl("#\\*\\s*@(mcp_tool|mcp_resource|mcp_prompt)", lines))) {
      mcp_files <- c(mcp_files, file)
    }
  }
  
  return(mcp_files)
}

#' Load all MCP elements from a directory
#'
#' @param server MCPServer instance
#' @param path Directory path
#' @param pattern File pattern to match
#' @param recursive Whether to scan subdirectories
#' @return The server (invisibly) for chaining
#' @export
mcp_source_directory <- function(server, path, pattern = "\\.R$", recursive = TRUE) {
  # Find all files with MCP decorators
  mcp_files <- scan_mcp_directory(path, pattern, recursive)
  
  if (length(mcp_files) == 0) {
    warning("No files with MCP decorators found in ", path)
    return(invisible(server))
  }
  
  # Load each file
  for (file in mcp_files) {
    message("Loading MCP elements from: ", basename(file))
    server$mcp_source(file)
  }
  
  invisible(server)
}

#' Parse function signature to extract parameter information
#'
#' @param fn A function object
#' @return A list with parameter information suitable for JSON Schema
#' @export
parse_function_signature <- function(fn) {
  if (!is.function(fn)) {
    stop("Input must be a function")
  }
  
  # Get function arguments
  args <- formals(fn)
  
  if (length(args) == 0) {
    return(list(type = "object", properties = list()))
  }
  
  # Build parameter schema
  properties <- list()
  required <- character()
  
  for (i in seq_along(args)) {
    arg_name <- names(args)[i]
    if (arg_name == "...") next
    
    # Get default value
    default_val <- args[[i]]
    
    # Check if argument has a default
    has_default <- !is.symbol(default_val) || !identical(as.character(default_val), character(0))
    
    if (!has_default) {
      required <- c(required, arg_name)
    }
    
    # Try to infer type from default value
    param_type <- "string"  # default
    
    if (has_default && !is.symbol(default_val)) {
      if (is.numeric(default_val)) {
        param_type <- if (is.integer(default_val)) "integer" else "number"
      } else if (is.logical(default_val)) {
        param_type <- "boolean"
      } else if (is.character(default_val)) {
        param_type <- "string"
      } else if (is.list(default_val)) {
        param_type <- "object"
      }
    }
    
    properties[[arg_name]] <- list(
      type = param_type,
      description = paste("Parameter", arg_name)
    )
    
    # Add default value to schema if present
    if (has_default && !is.symbol(default_val) && !is.null(default_val)) {
      properties[[arg_name]]$default <- default_val
    }
  }
  
  list(
    type = "object",
    properties = properties,
    required = if (length(required) > 0) required else NULL
  )
}

#' Create a source file with example decorated functions
#'
#' @param file Path where to create the example file
#' @param overwrite Whether to overwrite existing file
#' @return The file path (invisibly)
#' @export
create_mcp_example <- function(file = "mcp_example.R", overwrite = FALSE) {
  if (file.exists(file) && !overwrite) {
    stop("File already exists. Use overwrite = TRUE to replace it.")
  }
  
  example_content <- '# Example MCP-decorated functions
# This file demonstrates how to use decorators with mcpr

#* @mcp_tool
#* @description Calculate summary statistics for a numeric vector
#* @param data numeric A numeric vector to summarize
#* @param na.rm logical Whether to remove NA values (default: TRUE)
calculate_stats <- function(data, na.rm = TRUE) {
  if (!is.numeric(data)) {
    stop("Data must be numeric")
  }
  
  list(
    mean = mean(data, na.rm = na.rm),
    median = median(data, na.rm = na.rm),
    sd = sd(data, na.rm = na.rm),
    min = min(data, na.rm = na.rm),
    max = max(data, na.rm = na.rm),
    n = length(data),
    n_missing = sum(is.na(data))
  )
}

#* @mcp_tool
#* @description Perform linear regression analysis
#* @param x numeric Independent variable
#* @param y numeric Dependent variable
#* @param formula character Optional formula (overrides x and y)
linear_regression <- function(x = NULL, y = NULL, formula = NULL) {
  if (!is.null(formula)) {
    # Parse formula string and create model
    model <- lm(as.formula(formula))
  } else if (!is.null(x) && !is.null(y)) {
    model <- lm(y ~ x)
  } else {
    stop("Either provide x and y, or a formula")
  }
  
  summary_obj <- summary(model)
  
  list(
    coefficients = coef(model),
    r_squared = summary_obj$r.squared,
    adj_r_squared = summary_obj$adj.r.squared,
    p_values = summary_obj$coefficients[, "Pr(>|t|)"],
    residual_std_error = summary_obj$sigma
  )
}

#* @mcp_resource
#* @description Get information about the current R session
#* @mime_type text/plain
session_info <- function() {
  info <- sessionInfo()
  
  paste(
    "R Version:", info$R.version$version.string,
    "Platform:", info$platform,
    "Running under:", info$running,
    "",
    "Loaded packages:",
    paste("-", names(info$otherPkgs), collapse = "\\n"),
    sep = "\\n"
  )
}

#* @mcp_resource  
#* @description Get available datasets in base R
#* @mime_type application/json
available_datasets <- function() {
  # Get datasets from base packages
  datasets <- data(package = "datasets")$results
  
  # Convert to list
  dataset_list <- list()
  for (i in seq_len(nrow(datasets))) {
    dataset_list[[datasets[i, "Item"]]] <- datasets[i, "Title"]
  }
  
  dataset_list
}

#* @mcp_prompt
#* @description Template for requesting statistical analysis
#* @template Please analyze the dataset {dataset_name} using appropriate statistical methods. Focus on {analysis_focus}. The analysis should be suitable for {audience_level} audience.
#* @param_dataset_name The name of the dataset to analyze
#* @param_analysis_focus Specific aspects to focus on (e.g., "correlation", "distribution", "outliers")
#* @param_audience_level The audience level (e.g., "technical", "non-technical", "executive")
statistical_analysis <- NULL  # Prompt templates don\'t need a function body
'
  
  writeLines(example_content, file)
  message("Created example file: ", file)
  invisible(file)
}