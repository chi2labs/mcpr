#' Create MCP Server from Source
#'
#' High-level API for creating MCP servers from R source files, directories, or packages.
#' This function parses decorators, generates a complete npm package, and sets up
#' all necessary infrastructure for a working MCP server.
#'
#' @param source Character string specifying the source:
#'   - Path to an R file with decorated functions
#'   - Path to a directory containing R files
#'   - Name of an installed R package
#' @param name Server name (auto-generated from source if not provided)
#' @param output_dir Output directory for the generated server (default: "./servers")
#' @param title Human-readable server title (optional)
#' @param description Server description (optional)
#' @param version Server version (default: "1.0.0")
#' @param author Author name (optional)
#' @param include Character vector of patterns to include (for packages/directories)
#' @param exclude Character vector of patterns to exclude (for packages/directories)
#' @param recursive Logical, whether to search directories recursively (default: TRUE)
#' @param use_protocol Logical, whether to use enhanced protocol (default: TRUE)
#' @param overwrite Whether to overwrite existing directory (default: FALSE)
#'
#' @return Path to the generated server directory
#' @export
#'
#' @examples
#' \dontrun{
#' # From an R file with decorators
#' mcp_create_server(
#'   source = "analysis.R",
#'   output_dir = "servers",
#'   description = "Analysis tools for data science"
#' )
#' 
#' # From a package
#' mcp_create_server(
#'   source = "ggplot2",
#'   include = c("ggplot", "geom_*"),
#'   exclude = c("*.data")
#' )
#' 
#' # From a directory
#' mcp_create_server(
#'   source = "R/",
#'   name = "my-tools",
#'   recursive = TRUE
#' )
#' }
mcp_create_server <- function(source,
                            name = NULL,
                            output_dir = "./servers",
                            title = NULL,
                            description = NULL,
                            version = "1.0.0",
                            author = NULL,
                            include = NULL,
                            exclude = NULL,
                            recursive = TRUE,
                            use_protocol = TRUE,
                            overwrite = FALSE) {
  
  # Determine source type
  if (is.null(source) || !is.character(source) || length(source) != 1) {
    stop("Source must be a single character string")
  }
  
  # Initialize variables
  tools <- list()
  resources <- list()
  prompts <- list()
  source_type <- NULL
  
  # Check if source is a file
  if (file.exists(source) && !dir.exists(source)) {
    source_type <- "file"
    if (!grepl("\\.R$", source, ignore.case = TRUE)) {
      stop("Source file must be an R file (.R extension)")
    }
  } else if (dir.exists(source)) {
    source_type <- "directory"
  } else {
    # Check if it's a package
    if (requireNamespace(source, quietly = TRUE)) {
      source_type <- "package"
    } else {
      stop("Source must be an existing file, directory, or installed package")
    }
  }
  
  # Generate default name if not provided
  if (is.null(name)) {
    name <- switch(source_type,
      file = gsub("\\.R$", "", basename(source)),
      directory = basename(normalizePath(source)),
      package = source
    )
    name <- gsub("[^a-z0-9-]", "-", tolower(name))
    name <- gsub("^-+|-+$", "", name)  # Remove leading/trailing dashes
    name <- gsub("-+", "-", name)      # Collapse multiple dashes
  }
  
  # Generate default title and description
  if (is.null(title)) {
    title <- paste0(toupper(substring(name, 1, 1)), substring(name, 2), " MCP Server")
  }
  
  if (is.null(description)) {
    description <- switch(source_type,
      file = paste("MCP server generated from", basename(source)),
      directory = paste("MCP server generated from directory", basename(source)),
      package = paste("MCP server exposing functions from the", source, "package")
    )
  }
  
  # Process source based on type
  if (source_type == "file") {
    # Parse decorators from file
    message("Parsing decorators from file: ", source)
    elements <- parse_mcp_decorators(source)
    
    # Convert to tools/resources/prompts
    result <- decorators_to_mcp_params(elements, source)
    tools <- result$tools
    resources <- result$resources
    prompts <- result$prompts
    
  } else if (source_type == "directory") {
    # Scan directory for R files
    message("Scanning directory: ", source)
    r_files <- scan_mcp_directory(source, recursive = recursive, 
                                 include = include, exclude = exclude)
    
    # Parse each file
    for (file in r_files) {
      elements <- parse_mcp_decorators(file)
      if (length(elements) > 0) {
        result <- decorators_to_mcp_params(elements, file)
        tools <- c(tools, result$tools)
        resources <- c(resources, result$resources)
        prompts <- c(prompts, result$prompts)
      }
    }
    
  } else if (source_type == "package") {
    # Create server from package
    message("Creating server from package: ", source)
    server <- mcp()
    server$mcp_package(source, include = include, exclude = exclude)
    
    # Extract configured tools
    if (length(server$tools) > 0) {
      tools <- lapply(server$tools, function(tool) {
        list(
          description = tool$description,
          parameters = tool$parameters$properties,
          implementation = tool$fn
        )
      })
      names(tools) <- names(server$tools)
    }
  }
  
  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Generate the server
  server_path <- generate_mcp_server(
    name = name,
    title = title,
    description = description,
    version = version,
    path = output_dir,
    tools = tools,
    resources = resources,
    prompts = prompts,
    template = "full",
    author = author,
    use_protocol = use_protocol,
    source_files = if (source_type == "file") source else NULL,
    overwrite = overwrite
  )
  
  return(server_path)
}

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
#' @param use_protocol Whether to use enhanced protocol (default: TRUE)
#' @param source_files Original source files to copy (optional)
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
                               use_protocol = TRUE,
                               source_files = NULL,
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
    R_SCRIPT_NAME = "server.R",
    R_FLAGS = "--quiet --slave --no-echo",
    USE_PROTOCOL = use_protocol,
    ADDITIONAL_FILTERS = ""  # Can be customized based on server
  )
  
  # Generate wrapper (use protocol-enhanced wrapper if enabled)
  generate_wrapper(server_dir, vars, use_protocol)
  
  # Generate R server (use protocol-enhanced server if enabled)
  generate_r_server(server_dir, vars, tools, resources, prompts, template, use_protocol, source_files)
  
  # Generate supporting files
  generate_package_json(server_dir, vars)
  generate_readme(server_dir, vars)
  generate_mcp_json(server_dir, vars)
  generate_test_script(server_dir, vars)
  generate_gitignore(server_dir)
  generate_license(server_dir, vars)
  
  # Make scripts executable
  wrapper_path <- file.path(server_dir, "wrapper.js")
  server_path <- file.path(server_dir, "server.R")
  Sys.chmod(wrapper_path, "755")
  Sys.chmod(server_path, "755")
  
  message(sprintf("MCP server '%s' created successfully in: %s", name, server_dir))
  message("\nNext steps:")
  message("1. cd ", server_dir)
  message("2. npm install")
  message("3. npm test")
  message("4. Add to Claude Desktop configuration (see mcp.json)")
  
  invisible(server_dir)
}

#' Generate Node.js Wrapper
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @param use_protocol Whether to use protocol-enhanced wrapper
#' @keywords internal
generate_wrapper <- function(server_dir, vars, use_protocol = TRUE) {
  # Choose the appropriate template
  template_file <- if (use_protocol) "wrapper-protocol.js" else "wrapper.js"
  template_path <- system.file("templates", template_file, package = "mcpr")
  
  if (!file.exists(template_path)) {
    stop("Wrapper template not found. Please reinstall mcpr package.")
  }
  
  wrapper_content <- readLines(template_path)
  wrapper_content <- replace_template_vars(wrapper_content, vars)
  
  wrapper_path <- file.path(server_dir, "wrapper.js")
  writeLines(wrapper_content, wrapper_path)
}

#' Generate R Server
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @param tools Tool definitions
#' @param resources Resource definitions
#' @param prompts Prompt definitions
#' @param template Template type
#' @param use_protocol Whether to use protocol-enhanced server
#' @param source_files Original source files to copy
#' @keywords internal
generate_r_server <- function(server_dir, vars, tools, resources, prompts, template, 
                            use_protocol = TRUE, source_files = NULL) {
  
  # For protocol mode, we'll create a new enhanced template
  if (use_protocol) {
    # Generate protocol-enhanced server
    generate_protocol_server(server_dir, vars, tools, resources, prompts, source_files)
  } else {
    # Use legacy template
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
}

#' Generate package.json
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @keywords internal
generate_package_json <- function(server_dir, vars) {
  template_path <- system.file("templates", "package.json", package = "mcpr")
  content <- readLines(template_path)
  content <- replace_template_vars(content, vars)
  writeLines(content, file.path(server_dir, "package.json"))
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

#' Generate mcp.json Configuration Example
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @keywords internal
generate_mcp_json <- function(server_dir, vars) {
  template_path <- system.file("templates", "mcp.json", package = "mcpr")
  content <- readLines(template_path)
  content <- replace_template_vars(content, vars)
  writeLines(content, file.path(server_dir, "mcp.json"))
}

#' Generate Test Script
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @keywords internal
generate_test_script <- function(server_dir, vars) {
  template_path <- system.file("templates", "test.js", package = "mcpr")
  content <- readLines(template_path)
  content <- replace_template_vars(content, vars)
  writeLines(content, file.path(server_dir, "test.js"))
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

#' Generate protocol-enhanced R server
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @param tools Tool definitions
#' @param resources Resource definitions
#' @param prompts Prompt definitions
#' @param source_files Original source files to copy
#' @keywords internal
generate_protocol_server <- function(server_dir, vars, tools, resources, prompts, source_files) {
  # Create the server content using MCPProtocolHandler
  server_lines <- c(
    '#!/usr/bin/env Rscript',
    '',
    '# {{SERVER_NAME}} MCP Server',
    '# Generated by mcpr (https://github.com/chi2labs/mcpr)',
    '# ',
    '# This server uses the enhanced MCPProtocolHandler for robust communication',
    '',
    '# Suppress all package startup messages',
    'suppressPackageStartupMessages({',
    '  library(mcpr)',
    '  library(jsonlite)',
    '})',
    '',
    '# Server configuration',
    'SERVER_NAME <- "{{SERVER_NAME}}"',
    'SERVER_VERSION <- "{{SERVER_VERSION}}"',
    '',
    '# Check if we are in protocol mode',
    'USE_PROTOCOL <- Sys.getenv("MCPR_USE_PROTOCOL", "true") != "false"',
    '',
    '# Create server instance',
    'server <- mcp(name = SERVER_NAME, version = SERVER_VERSION)',
    ''
  )
  
  # Add tool registrations
  if (!is.null(tools) && length(tools) > 0) {
    server_lines <- c(server_lines, 
      '# Register tools',
      format_tool_registrations(tools),
      ''
    )
  }
  
  # Add resource registrations
  if (!is.null(resources) && length(resources) > 0) {
    server_lines <- c(server_lines,
      '# Register resources',
      format_resource_registrations(resources),
      ''
    )
  }
  
  # Add prompt registrations
  if (!is.null(prompts) && length(prompts) > 0) {
    server_lines <- c(server_lines,
      '# Register prompts',
      format_prompt_registrations(prompts),
      ''
    )
  }
  
  # Add source file loading if provided
  if (!is.null(source_files)) {
    server_lines <- c(server_lines,
      '# Load source files',
      sprintf('source("%s")', source_files),
      ''
    )
  }
  
  # Add server startup
  server_lines <- c(server_lines,
    '# Create and start transport',
    'if (USE_PROTOCOL) {',
    '  # Use enhanced protocol transport',
    '  transport <- ProtocolStdioTransport$new(server)',
    '} else {',
    '  # Use legacy transport',
    '  transport <- StdioTransport$new(server)',
    '}',
    '',
    '# Start the server',
    'transport$start()',
    '',
    '# Server will run until EOF is received'
  )
  
  # Replace template variables
  server_content <- replace_template_vars(server_lines, vars)
  
  # Write server file
  server_path <- file.path(server_dir, "server.R")
  writeLines(server_content, server_path)
}

#' Format tool registrations for protocol server
#'
#' @param tools List of tool definitions
#' @return Character vector of R code lines
#' @keywords internal
format_tool_registrations <- function(tools) {
  if (is.null(tools) || length(tools) == 0) return(character())
  
  lines <- character()
  for (tool_name in names(tools)) {
    tool <- tools[[tool_name]]
    
    # Check if tool has implementation
    if (!is.null(tool$implementation)) {
      # Deparse function to a single line
      fn_str <- paste(deparse(tool$implementation, width.cutoff = 500L), collapse = " ")
      lines <- c(lines, sprintf(
        'server$mcp_tool("%s", %s, "%s")',
        tool_name,
        fn_str,
        tool$description %||% ""
      ))
    } else {
      # Create a placeholder function
      lines <- c(lines, sprintf(
        'server$mcp_tool("%s", function(...) { "Tool %s not implemented" }, "%s")',
        tool_name,
        tool_name,
        tool$description %||% ""
      ))
    }
  }
  lines
}

#' Format resource registrations for protocol server
#'
#' @param resources List of resource definitions
#' @return Character vector of R code lines
#' @keywords internal
format_resource_registrations <- function(resources) {
  if (is.null(resources) || length(resources) == 0) return(character())
  
  lines <- character()
  for (i in seq_along(resources)) {
    res <- resources[[i]]
    lines <- c(lines, sprintf(
      'server$mcp_resource("%s", function() { "%s content" }, "%s")',
      res$name %||% res$uri,
      res$name %||% res$uri,
      res$description %||% ""
    ))
  }
  lines
}

#' Format prompt registrations for protocol server
#'
#' @param prompts List of prompt definitions
#' @return Character vector of R code lines
#' @keywords internal  
format_prompt_registrations <- function(prompts) {
  if (is.null(prompts) || length(prompts) == 0) return(character())
  
  lines <- character()
  for (prompt_name in names(prompts)) {
    prompt <- prompts[[prompt_name]]
    lines <- c(lines, sprintf(
      'server$mcp_prompt("%s", "%s", "%s")',
      prompt_name,
      prompt$template %||% "",
      prompt$description %||% ""
    ))
  }
  lines
}

#' Generate LICENSE file
#'
#' @param server_dir Server directory path
#' @param vars Template variables
#' @keywords internal
generate_license <- function(server_dir, vars) {
  license_content <- c(
    'MIT License',
    '',
    sprintf('Copyright (c) %s %s', vars$YEAR, vars$AUTHOR_NAME),
    '',
    'Permission is hereby granted, free of charge, to any person obtaining a copy',
    'of this software and associated documentation files (the "Software"), to deal',
    'in the Software without restriction, including without limitation the rights',
    'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell',
    'copies of the Software, and to permit persons to whom the Software is',
    'furnished to do so, subject to the following conditions:',
    '',
    'The above copyright notice and this permission notice shall be included in all',
    'copies or substantial portions of the Software.',
    '',
    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR',
    'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,',
    'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE',
    'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER',
    'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,',
    'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE',
    'SOFTWARE.'
  )
  
  writeLines(license_content, file.path(server_dir, "LICENSE"))
}

#' Scan directory for MCP-decorated R files
#'
#' @param path Directory path to scan
#' @param recursive Whether to search recursively
#' @param include Patterns to include
#' @param exclude Patterns to exclude
#' @return Character vector of R file paths
#' @keywords internal
scan_mcp_directory <- function(path, recursive = TRUE, include = NULL, exclude = NULL) {
  # Get all R files
  r_files <- list.files(path, pattern = "\\.R$", recursive = recursive, 
                       full.names = TRUE, ignore.case = TRUE)
  
  # Apply include filters
  if (!is.null(include)) {
    include_pattern <- paste0("(", paste(gsub("\\*", ".*", include), collapse = "|"), ")")
    r_files <- r_files[grepl(include_pattern, basename(r_files))]
  }
  
  # Apply exclude filters
  if (!is.null(exclude)) {
    exclude_pattern <- paste0("(", paste(gsub("\\*", ".*", exclude), collapse = "|"), ")")
    r_files <- r_files[!grepl(exclude_pattern, basename(r_files))]
  }
  
  r_files
}

#' Convert decorator elements to MCP parameters
#'
#' @param elements List of parsed decorator elements
#' @param source_file Source file path
#' @return List with tools, resources, and prompts
#' @keywords internal
decorators_to_mcp_params <- function(elements, source_file) {
  tools <- list()
  resources <- list()
  prompts <- list()
  
  # Read the source file to get function implementations
  source_env <- new.env()
  source(source_file, local = source_env)
  
  for (element in elements) {
    if (element$type == "mcp_tool") {
      # Extract tool configuration
      if (is.null(element$name)) {
        next  # Skip if no function name found
      }
      tool_name <- element$name
      tool <- list(
        description = element$decorators$description %||% "",
        parameters = list()
      )
      
      # Add parameters if specified
      if (!is.null(element$decorators$params)) {
        for (param_name in names(element$decorators$params)) {
          param <- element$decorators$params[[param_name]]
          tool$parameters[[param_name]] <- list(
            type = param$type %||% "string",
            description = param$description %||% ""
          )
        }
      }
      
      # Try to get the function implementation
      if (!is.null(element$name) && exists(element$name, envir = source_env)) {
        tool$implementation <- get(element$name, envir = source_env)
      }
      
      tools[[tool_name]] <- tool
      
    } else if (element$type == "mcp_resource") {
      # Extract resource configuration
      res_name <- element$name
      resources <- append(resources, list(list(
        name = res_name,
        uri = paste0("resource://", res_name),
        description = element$decorators$description %||% "",
        mime_type = element$decorators$mime_type %||% "text/plain"
      )))
      
    } else if (element$type == "mcp_prompt") {
      # Extract prompt configuration
      prompt_name <- element$name
      prompts[[prompt_name]] <- list(
        template = element$decorators$template %||% "",
        description = element$decorators$description %||% "",
        parameters = element$decorators$params
      )
    }
  }
  
  list(tools = tools, resources = resources, prompts = prompts)
}