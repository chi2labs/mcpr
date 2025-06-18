#' Create a new Model Context Protocol server
#'
#' Creates a new MCP server instance that can be configured with tools,
#' resources, and prompts before running.
#'
#' @param name Optional name for the server
#' @param version Optional version string
#' @return An MCP server object
#' @export
#' @examples
#' # Create a simple MCP server
#' server <- mcp()
#' 
#' # Create a named server
#' server <- mcp(name = "My Analysis Server", version = "1.0.0")
mcp <- function(name = NULL, version = NULL) {
  MCPServer$new(name = name, version = version)
}

#' MCP Server Class
#'
#' @description
#' R6 class representing a Model Context Protocol server. This class
#' manages tools, resources, prompts, and handles the protocol communication.
#'
#' @importFrom R6 R6Class
#' @export
MCPServer <- R6::R6Class(
  "MCPServer",
  
  public = list(
    #' @field name Server name
    name = NULL,
    
    #' @field version Server version
    version = NULL,
    
    #' @field tools List of registered tools
    tools = NULL,
    
    #' @field resources List of registered resources
    resources = NULL,
    
    #' @field prompts List of registered prompts
    prompts = NULL,
    
    #' @description
    #' Create a new MCP server
    #' @param name Server name
    #' @param version Server version
    initialize = function(name = NULL, version = NULL) {
      self$name <- name %||% "mcpr-server"
      self$version <- version %||% "0.1.0"
      self$tools <- list()
      self$resources <- list()
      self$prompts <- list()
      private$transport <- NULL
      invisible(self)
    },
    
    #' @description
    #' Register a tool with the server
    #' @param name Tool name
    #' @param fn Function to execute
    #' @param description Tool description
    #' @param parameters Parameter schema (optional)
    #' @return Self for chaining
    mcp_tool = function(name, fn, description = NULL, parameters = NULL) {
      if (!is.function(fn)) {
        stop("Tool must be a function")
      }
      
      # Extract function signature if parameters not provided
      if (is.null(parameters)) {
        parameters <- private$extract_parameters(fn)
      }
      
      self$tools[[name]] <- list(
        name = name,
        description = description,
        fn = fn,
        parameters = parameters
      )
      
      invisible(self)
    },
    
    #' @description
    #' Register a resource with the server
    #' @param name Resource name
    #' @param fn Function that returns resource content
    #' @param description Resource description
    #' @param mime_type MIME type of the resource
    #' @return Self for chaining
    mcp_resource = function(name, fn, description = NULL, mime_type = "text/plain") {
      if (!is.function(fn)) {
        stop("Resource must be a function")
      }
      
      self$resources[[name]] <- list(
        name = name,
        description = description,
        fn = fn,
        mime_type = mime_type
      )
      
      invisible(self)
    },
    
    #' @description
    #' Register a prompt template with the server
    #' @param name Prompt name
    #' @param template Prompt template string
    #' @param description Prompt description
    #' @param parameters List of parameter definitions
    #' @return Self for chaining
    mcp_prompt = function(name, template, description = NULL, parameters = NULL) {
      self$prompts[[name]] <- list(
        name = name,
        template = template,
        description = description,
        parameters = parameters
      )
      
      invisible(self)
    },
    
    #' @description
    #' Load tools/resources from an R source file
    #' @param file Path to R file with decorated functions
    #' @return Self for chaining
    mcp_source = function(file) {
      if (!file.exists(file)) {
        stop("Source file does not exist: ", file)
      }
      
      # Parse decorators from the file
      elements <- parse_mcp_decorators(file)
      
      # Create a new environment for the functions
      source_env <- new.env(parent = globalenv())
      
      # Register all decorated elements
      register_decorated_elements(self, elements, env = source_env)
      
      invisible(self)
    },
    
    #' @description
    #' Expose functions from an R package
    #' @param package Package name
    #' @param include Character vector of patterns to include
    #' @param exclude Character vector of patterns to exclude
    #' @return Self for chaining
    mcp_package = function(package, include = NULL, exclude = NULL) {
      if (!requireNamespace(package, quietly = TRUE)) {
        stop("Package '", package, "' is not installed")
      }
      
      # Get all exported functions from the package
      pkg_env <- asNamespace(package)
      exports <- getNamespaceExports(package)
      
      # Filter based on include/exclude patterns
      if (!is.null(include)) {
        # Convert patterns to regex and match
        include_pattern <- paste0("^(", paste(gsub("\\*", ".*", include), collapse = "|"), ")$")
        exports <- exports[grepl(include_pattern, exports)]
      }
      
      if (!is.null(exclude)) {
        # Convert patterns to regex and exclude
        exclude_pattern <- paste0("^(", paste(gsub("\\*", ".*", exclude), collapse = "|"), ")$")
        exports <- exports[!grepl(exclude_pattern, exports)]
      }
      
      # Register each function as a tool
      for (fn_name in exports) {
        fn <- get(fn_name, envir = pkg_env)
        if (is.function(fn)) {
          # Create a namespaced tool name
          tool_name <- paste0(package, "::", fn_name)
          
          # Try to get help documentation
          help_file <- utils::help(fn_name, package = package)
          description <- NULL
          if (length(help_file) > 0) {
            # Extract description from help (simplified for now)
            description <- paste("Function", fn_name, "from package", package)
          }
          
          self$mcp_tool(
            name = tool_name,
            fn = fn,
            description = description
          )
        }
      }
      
      invisible(self)
    },
    
    #' @description
    #' Run the MCP server
    #' @param transport Transport type ("stdio", "http", "websocket")
    #' @param host Host address for HTTP/WebSocket transport
    #' @param port Port number for HTTP/WebSocket transport
    #' @return Server handle (transport-specific)
    mcp_run = function(transport = "stdio", host = "127.0.0.1", port = NULL) {
      # Validate transport
      if (!transport %in% c("stdio", "http", "websocket")) {
        stop("Invalid transport: ", transport, ". Must be one of: stdio, http, websocket")
      }
      
      # Create appropriate transport
      if (transport == "stdio") {
        if (!requireNamespace("processx", quietly = TRUE)) {
          stop("Package 'processx' is required for stdio transport")
        }
        private$transport <- StdioTransport$new(self)
      } else if (transport == "http") {
        if (!requireNamespace("httpuv", quietly = TRUE)) {
          stop("Package 'httpuv' is required for HTTP transport")
        }
        stop("HTTP transport not yet implemented")
      } else if (transport == "websocket") {
        stop("WebSocket transport not yet implemented")
      }
      
      # Start the transport
      private$transport$start()
    },
    
    #' @description
    #' Generate a standalone MCP server package
    #' @param path Directory to create the server in
    #' @param template Template to use ("full" or "minimal")
    #' @param overwrite Whether to overwrite existing directory
    #' @return Path to generated server directory
    generate = function(path = ".", template = "full", overwrite = FALSE) {
      # Convert tools, resources, and prompts to configuration format
      tools_config <- NULL
      if (length(self$tools) > 0) {
        tools_config <- lapply(self$tools, function(tool) {
          list(
            description = tool$description,
            parameters = tool$parameters$properties
          )
        })
        names(tools_config) <- names(self$tools)
      }
      
      resources_config <- NULL
      if (length(self$resources) > 0) {
        resources_config <- lapply(seq_along(self$resources), function(i) {
          res <- self$resources[[i]]
          list(
            uri = paste0("resource://", res$name),
            name = res$name,
            description = res$description
          )
        })
      }
      
      prompts_config <- NULL
      if (length(self$prompts) > 0) {
        prompts_config <- lapply(self$prompts, function(prompt) {
          list(
            description = prompt$description
          )
        })
        names(prompts_config) <- names(self$prompts)
      }
      
      # Generate the server package
      generate_mcp_server(
        name = gsub("[^a-z0-9-]", "-", tolower(self$name)),
        title = self$name,
        description = paste("MCP server:", self$name),
        version = self$version,
        path = path,
        tools = tools_config,
        resources = resources_config,
        prompts = prompts_config,
        template = template,
        overwrite = overwrite
      )
    },
    
    #' @description
    #' Get server capabilities for initialization
    #' @return List of server capabilities
    get_capabilities = function() {
      list(
        tools = if (length(self$tools) > 0) {
          lapply(self$tools, function(tool) {
            list(
              name = tool$name,
              description = tool$description,
              inputSchema = tool$parameters
            )
          })
        } else NULL,
        resources = if (length(self$resources) > 0) {
          lapply(self$resources, function(resource) {
            list(
              name = resource$name,
              description = resource$description,
              mimeType = resource$mime_type
            )
          })
        } else NULL,
        prompts = if (length(self$prompts) > 0) {
          lapply(self$prompts, function(prompt) {
            list(
              name = prompt$name,
              description = prompt$description,
              arguments = prompt$parameters
            )
          })
        } else NULL
      )
    },
    
    #' @description
    #' Execute a tool
    #' @param name Tool name
    #' @param arguments Tool arguments
    #' @return Tool result
    execute_tool = function(name, arguments = list()) {
      if (!name %in% names(self$tools)) {
        stop("Unknown tool: ", name)
      }
      
      tool <- self$tools[[name]]
      
      # Execute the tool function with provided arguments
      result <- do.call(tool$fn, arguments)
      
      # Convert result to JSON-compatible format
      to_mcp_json(result)
    },
    
    #' @description
    #' Get a resource
    #' @param name Resource name
    #' @return Resource content
    get_resource = function(name) {
      if (!name %in% names(self$resources)) {
        stop("Unknown resource: ", name)
      }
      
      resource <- self$resources[[name]]
      
      # Execute the resource function
      content <- resource$fn()
      
      list(
        contents = list(
          list(
            uri = name,
            mimeType = resource$mime_type,
            text = if (is.character(content)) content else mcp_serialize(content)
          )
        )
      )
    },
    
    #' @description
    #' Print method for MCP server
    #' @param ... Additional arguments (ignored)
    print = function(...) {
      cat("MCP Server: ", self$name, " (v", self$version, ")\n", sep = "")
      cat("Tools: ", length(self$tools), "\n")
      if (length(self$tools) > 0) {
        cat("  ", paste(names(self$tools), collapse = ", "), "\n")
      }
      cat("Resources: ", length(self$resources), "\n")
      if (length(self$resources) > 0) {
        cat("  ", paste(names(self$resources), collapse = ", "), "\n")
      }
      cat("Prompts: ", length(self$prompts), "\n")
      if (length(self$prompts) > 0) {
        cat("  ", paste(names(self$prompts), collapse = ", "), "\n")
      }
      invisible(self)
    }
  ),
  
  private = list(
    transport = NULL,
    
    #' Extract parameters from function signature
    extract_parameters = function(fn) {
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
        
        # Check if argument has a default
        # In formals(), missing arguments are represented as empty symbols
        if (is.symbol(args[[i]]) && identical(as.character(args[[i]]), character(0))) {
          required <- c(required, arg_name)
        }
        
        # Simple type inference (can be enhanced)
        properties[[arg_name]] <- list(
          type = "string",  # Default to string, could be smarter
          description = paste("Parameter", arg_name)
        )
      }
      
      list(
        type = "object",
        properties = properties,
        required = if (length(required) > 0) required else NULL
      )
    }
  )
)

#' @export
print.MCPServer <- function(x, ...) {
  x$print(...)
}

#' NULL coalescing operator
#'
#' Returns the left-hand side if it is not NULL, otherwise returns the right-hand side.
#'
#' @param x Left-hand side value
#' @param y Right-hand side value (default)
#' @return \code{x} if not NULL, otherwise \code{y}
#' @name grapes-or-or-grapes
#' @keywords internal
#' @examples
#' NULL %||% "default"  # returns "default"
#' "value" %||% "default"  # returns "value"
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}