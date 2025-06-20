#' Parse MCP Decorators from R Source
#'
#' @description
#' Functions for parsing roxygen2-style decorators (@mcp_tool, @mcp_resource, @mcp_prompt)
#' from R source files. This enables a decorator-based approach similar to plumber.
#'
#' @name decorators
NULL

#' Parse decorators from a source file
#'
#' @param file Path to R source file
#' @return A list of parsed elements with their decorators and function definitions
#' @export
parse_mcp_decorators <- function(file) {
  if (!file.exists(file)) {
    stop("File does not exist: ", file)
  }
  
  # Read the file
  lines <- readLines(file, warn = FALSE)
  
  # Initialize state
  elements <- list()
  current_block <- NULL
  current_decorators <- list()
  decorator_start <- NULL
  
  # Regex patterns for decorators
  decorator_pattern <- "^#\\*\\s*@(mcp_tool|mcp_resource|mcp_prompt)\\s*$"
  tag_pattern <- "^#\\*\\s*@(\\w+)\\s+(.*)$"
  continuation_pattern <- "^#\\*\\s+(.*)$"
  function_pattern <- "^\\s*([a-zA-Z][a-zA-Z0-9._]*)\\s*(<-|=)\\s*function\\s*\\("
  
  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]
    
    # Check for MCP decorator start
    if (grepl(decorator_pattern, line)) {
      # Save previous block if any
      if (!is.null(current_block)) {
        elements <- append(elements, list(current_block))
      }
      
      # Start new block
      decorator_type <- gsub("^#\\*\\s*@", "", line)
      decorator_type <- trimws(decorator_type)
      current_block <- list(
        type = decorator_type,
        decorators = list(),
        line_start = i
      )
      current_decorators <- list()
      decorator_start <- i
      
    } else if (!is.null(current_block) && grepl("^#\\*", line)) {
      # Parse decorator tags
      if (grepl(tag_pattern, line)) {
        matches <- regmatches(line, regexec(tag_pattern, line))[[1]]
        tag <- matches[2]
        value <- matches[3]
        
        # Handle multi-line values
        j <- i + 1
        while (j <= length(lines) && grepl("^#\\*\\s+[^@]", lines[j])) {
          cont_value <- gsub("^#\\*\\s+", "", lines[j])
          value <- paste(value, cont_value, sep = " ")
          j <- j + 1
        }
        i <- j - 1
        
        # Store decorator
        if (tag == "param") {
          # Parse parameter: @param name type description
          param_parts <- strsplit(value, "\\s+", perl = TRUE)[[1]]
          if (length(param_parts) >= 2) {
            param_name <- param_parts[1]
            param_type <- param_parts[2]
            param_desc <- if (length(param_parts) > 2) {
              paste(param_parts[3:length(param_parts)], collapse = " ")
            } else {
              ""
            }
            
            if (!"params" %in% names(current_decorators)) {
              current_decorators$params <- list()
            }
            current_decorators$params[[param_name]] <- list(
              type = param_type,
              description = param_desc
            )
          }
        } else {
          current_decorators[[tag]] <- value
        }
      } else if (grepl("^#\\*\\s+[^@]", line)) {
        # Continuation of previous tag (line starting with #* and spaces but no @)
        cont_value <- gsub("^#\\*\\s+", "", line)
        if (length(current_decorators) > 0) {
          last_tag <- names(current_decorators)[length(current_decorators)]
          if (last_tag != "params") {
            current_decorators[[last_tag]] <- paste(current_decorators[[last_tag]], cont_value, sep = " ")
          }
        }
      }
      
    } else if (!is.null(current_block)) {
      # Check for function definition or prompt template assignment
      fn_name <- NULL
      definition_lines <- character()
      
      if (grepl(function_pattern, line)) {
        # Found a function definition
        matches <- regmatches(line, regexec(function_pattern, line))[[1]]
        if (length(matches) >= 2) {
          fn_name <- matches[2]
        }
      } else if (current_block$type == "mcp_prompt" && grepl("^\\s*([a-zA-Z][a-zA-Z0-9._]*)\\s*(<-|=)\\s*NULL", line)) {
        # Found a prompt template assignment
        matches <- regmatches(line, regexec("^\\s*([a-zA-Z][a-zA-Z0-9._]*)\\s*(<-|=)\\s*NULL", line))[[1]]
        if (length(matches) >= 2) {
          fn_name <- matches[2]
          definition_lines <- line
        }
      }
      
      if (is.null(fn_name)) {
        next
      }
      
      # Extract the complete function definition
      fn_start <- i
      
      if (length(definition_lines) > 0) {
        # For prompt templates, we already have the definition
        fn_lines <- definition_lines
        j <- i
      } else {
        # For functions, extract until all braces are closed
        fn_lines <- character()
        brace_count <- 0
        in_function <- FALSE
        
        j <- i
        while (j <= length(lines)) {
          fn_line <- lines[j]
          fn_lines <- c(fn_lines, fn_line)
          
          # Count braces to find function end
          for (char in strsplit(fn_line, "")[[1]]) {
            if (char == "{") {
              brace_count <- brace_count + 1
              in_function <- TRUE
            } else if (char == "}") {
              brace_count <- brace_count - 1
            }
          }
          
          # Check if we've closed all braces
          if (in_function && brace_count == 0) {
            break
          }
          
          j <- j + 1
        }
      }
      
      # Store the complete element
      current_block$name <- fn_name
      current_block$decorators <- current_decorators
      current_block$definition <- paste(fn_lines, collapse = "\n")
      current_block$line_end <- j
      
      # Add to elements and reset
      elements <- append(elements, list(current_block))
      current_block <- NULL
      current_decorators <- list()
      
      i <- j
    }
    
    i <- i + 1
  }
  
  # Don't forget last block if file ends without function
  if (!is.null(current_block) && "name" %in% names(current_block)) {
    elements <- append(elements, list(current_block))
  }
  
  return(elements)
}