#' HTTP Transport for MCP
#'
#' @description
#' Implements HTTP transport for MCP communication using plumber.
#' This transport allows MCP servers to be accessed over HTTP,
#' enabling multi-client support and easier deployment.
#'
#' @importFrom R6 R6Class
#' @importFrom jsonlite fromJSON toJSON
#' @export
HttpTransport <- R6::R6Class(
  "HttpTransport",
  
  public = list(
    #' @field server The MCP server instance
    server = NULL,
    
    #' @field plumber_app The plumber application instance
    plumber_app = NULL,
    
    #' @field host Host address to bind to
    host = NULL,
    
    #' @field port Port number to listen on
    port = NULL,
    
    #' @field log_file Optional log file path
    log_file = NULL,
    
    #' @field log_level Logging level ("debug", "info", "warn", "error")
    log_level = NULL,
    
    #' @description
    #' Create a new HTTP transport
    #' @param server MCP server instance
    #' @param host Host address (default: "127.0.0.1")
    #' @param port Port number (default: 8080)
    #' @param log_file Optional path to log file
    #' @param log_level Logging level (default: "info")
    initialize = function(server, host = "127.0.0.1", port = 8080, log_file = NULL, log_level = "info") {
      self$server <- server
      self$host <- host
      self$port <- port
      self$log_file <- log_file
      self$log_level <- log_level
      
      # Check for plumber dependency
      if (!requireNamespace("plumber", quietly = TRUE)) {
        stop("Package 'plumber' is required for HTTP transport. Install it with: install.packages('plumber')")
      }
      
      # Initialize logging
      private$init_logging()
      
      # Create plumber app
      private$create_app()
    },
    
    #' @description
    #' Start the HTTP transport
    #' @param docs Whether to enable Swagger documentation (default: FALSE)
    #' @param quiet Whether to suppress plumber startup messages (default: FALSE)
    #' @return The running plumber API object
    start = function(docs = FALSE, quiet = FALSE) {
      if (!quiet) {
        message(sprintf("Starting MCP HTTP server on http://%s:%d/mcp", self$host, self$port))
        message("Server info: ", self$server$name, " v", self$server$version)
      }
      
      # Run the plumber app
      self$plumber_app$run(
        host = self$host,
        port = self$port,
        docs = docs,
        quiet = quiet
      )
    },
    
    #' @description
    #' Get the plumber app (for testing or custom deployment)
    #' @return The plumber API object
    get_app = function() {
      self$plumber_app
    }
  ),
  
  private = list(
    #' Initialize logging
    init_logging = function() {
      # Check if logger package is available for structured logging
      private$use_logger <- requireNamespace("logger", quietly = TRUE)
      
      if (private$use_logger) {
        # Set up logger
        logger::log_threshold(self$log_level)
        
        # Add file appender if log file specified
        if (!is.null(self$log_file)) {
          logger::log_appender(logger::appender_file(self$log_file))
        }
        
        private$log <- function(level, msg, ...) {
          switch(level,
            debug = logger::log_debug(msg, ...),
            info = logger::log_info(msg, ...),
            warn = logger::log_warn(msg, ...),
            error = logger::log_error(msg, ...)
          )
        }
      } else {
        # Fallback to basic logging
        private$log <- function(level, msg, ...) {
          if (level %in% c("info", "warn", "error") || 
              (self$log_level == "debug" && level == "debug")) {
            timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
            formatted_msg <- sprintf("[%s] %s: %s", timestamp, toupper(level), sprintf(msg, ...))
            
            if (!is.null(self$log_file)) {
              cat(formatted_msg, "\n", file = self$log_file, append = TRUE)
            } else {
              message(formatted_msg)
            }
          }
        }
      }
    },
    
    #' Logger instance
    use_logger = FALSE,
    log = NULL,
    #' Create the plumber application
    create_app = function() {
      # Create a new plumber instance
      self$plumber_app <- plumber::Plumber$new()
      
      # Add request logging filter
      self$plumber_app$filter("logger", function(req, res) {
        start_time <- Sys.time()
        
        # Log request
        private$log("info", "[%s] %s %s", 
                   req$REMOTE_ADDR %||% "unknown",
                   req$REQUEST_METHOD,
                   req$PATH_INFO)
        
        # Continue processing
        plumber::forward()
      })
      
      # Add CORS headers for browser-based clients
      self$plumber_app$filter("cors", function(req, res) {
        res$setHeader("Access-Control-Allow-Origin", "*")
        res$setHeader("Access-Control-Allow-Methods", "POST, OPTIONS")
        res$setHeader("Access-Control-Allow-Headers", "Content-Type")
        
        # Handle preflight requests
        if (req$REQUEST_METHOD == "OPTIONS") {
          res$status <- 200
          return(list())
        }
        
        plumber::forward()
      })
      
      # Add error handler
      self$plumber_app$setErrorHandler(function(err) {
        private$log("error", "Error handling request: %s", err$message)
        
        list(
          jsonrpc = "2.0",
          error = list(
            code = -32603,
            message = "Internal error",
            data = if (self$log_level == "debug") err$message else NULL
          ),
          id = NULL
        )
      })
      
      # Add the main MCP endpoint
      self$plumber_app$handle("POST", "/mcp", function(req, res) {
        # Parse request body
        tryCatch({
          # Get raw body for JSON parsing
          body <- req$postBody
          if (is.null(body) || nchar(body) == 0) {
            res$status <- 400
            return(private$create_error_response(
              code = -32700,
              message = "Parse error: Empty request body",
              id = NULL
            ))
          }
          
          # Parse JSON-RPC request
          message <- jsonlite::fromJSON(body, simplifyVector = FALSE)
          
          # Log the method being called
          private$log("debug", "Processing method: %s (id: %s)", 
                     message$method %||% "unknown",
                     message$id %||% "null")
          
          # Handle the message
          response <- private$handle_message(message)
          
          # Log response status
          if (!is.null(response$error)) {
            private$log("warn", "Method %s failed: %s", 
                       message$method %||% "unknown",
                       response$error$message)
          } else {
            private$log("debug", "Method %s completed successfully", 
                       message$method %||% "unknown")
          }
          
          # Return response
          res$status <- 200
          res$setHeader("Content-Type", "application/json")
          res$body <- jsonlite::toJSON(response, auto_unbox = TRUE, null = "null", na = "null")
          return(res)
          
        }, error = function(e) {
          res$status <- 400
          res$setHeader("Content-Type", "application/json")
          error_response <- private$create_error_response(
            code = -32700,
            message = paste("Parse error:", as.character(e)),
            id = NULL
          )
          res$body <- jsonlite::toJSON(error_response, auto_unbox = TRUE, null = "null")
          return(res)
        })
      })
      
      # Add a health check endpoint
      self$plumber_app$handle("GET", "/health", function() {
        list(
          status = "ok",
          server = self$server$name,
          version = self$server$version,
          transport = "http"
        )
      })
      
      # Add server info endpoint
      self$plumber_app$handle("GET", "/", function() {
        list(
          name = self$server$name,
          version = self$server$version,
          mcp_version = "2024-11-05",
          transport = "http",
          endpoint = "/mcp",
          capabilities = self$server$get_capabilities()
        )
      })
    },
    
    #' Handle incoming JSON-RPC message
    handle_message = function(message) {
      # Validate JSON-RPC format
      if (is.null(message$jsonrpc) || message$jsonrpc != "2.0") {
        return(private$create_error_response(
          code = -32600,
          message = "Invalid Request: Missing or invalid jsonrpc version",
          id = message$id
        ))
      }
      
      # Extract method and params
      method <- message$method
      params <- message$params %||% list()
      id <- message$id
      
      # Route to appropriate handler
      result <- tryCatch({
        switch(method,
          # MCP protocol methods
          "initialize" = private$handle_initialize(params),
          "initialized" = {
            # Client notification that initialization is complete
            NULL
          },
          "tools/list" = private$handle_tools_list(params),
          "tools/call" = private$handle_tools_call(params),
          "resources/list" = private$handle_resources_list(params),
          "resources/read" = private$handle_resources_read(params),
          "prompts/list" = private$handle_prompts_list(params),
          "prompts/get" = private$handle_prompts_get(params),
          
          # Unknown method
          stop("Unknown method: ", method)
        )
      }, error = function(e) {
        return(list(error = list(
          code = -32601,
          message = "Method not found",
          data = as.character(e)
        )))
      })
      
      # Build response
      if (!is.null(id)) {
        # Request requires response
        response <- list(
          jsonrpc = "2.0",
          id = id
        )
        
        if (!is.null(result$error)) {
          response$error <- result$error
        } else {
          response$result <- result
        }
        
        return(response)
      } else {
        # Notification - no response needed unless it's an error
        if (!is.null(result$error)) {
          return(list(
            jsonrpc = "2.0",
            error = result$error,
            id = NULL
          ))
        }
        return(list(jsonrpc = "2.0", result = list()))
      }
    },
    
    #' Handle initialize request
    handle_initialize = function(params) {
      list(
        protocolVersion = "2024-11-05",
        capabilities = self$server$get_capabilities(),
        serverInfo = list(
          name = self$server$name,
          version = self$server$version
        )
      )
    },
    
    #' Handle tools/list request
    handle_tools_list = function(params) {
      list(
        tools = if (length(self$server$tools) > 0) {
          unname(lapply(self$server$tools, function(tool) {
            # Fix required field to ensure it's an array
            schema <- tool$parameters
            if (!is.null(schema$required)) {
              if (length(schema$required) == 0) {
                schema$required <- I(list())
              } else {
                schema$required <- I(as.list(schema$required))
              }
            }
            list(
              name = tool$name,
              description = tool$description,
              inputSchema = schema
            )
          }))
        } else list()
      )
    },
    
    #' Handle tools/call request
    handle_tools_call = function(params) {
      name <- params$name
      arguments <- params$arguments %||% list()
      
      private$log("info", "Executing tool: %s", name)
      private$log("debug", "Tool arguments: %s", 
                 jsonlite::toJSON(arguments, auto_unbox = TRUE))
      
      # Execute tool
      result <- tryCatch({
        self$server$execute_tool(name, arguments)
      }, error = function(e) {
        private$log("error", "Tool execution failed: %s", e$message)
        return(list(
          isError = TRUE,
          content = list(list(
            type = "text",
            text = paste("Error executing tool:", as.character(e))
          ))
        ))
      })
      
      # Format result
      if (is.list(result) && !is.null(result$isError) && result$isError) {
        result
      } else {
        list(
          content = list(list(
            type = "text",
            text = if (is.character(result) && length(result) == 1) {
              result
            } else {
              jsonlite::toJSON(result, auto_unbox = TRUE, null = "null")
            }
          ))
        )
      }
    },
    
    #' Handle resources/list request
    handle_resources_list = function(params) {
      list(
        resources = if (length(self$server$resources) > 0) {
          unname(lapply(self$server$resources, function(resource) {
            list(
              uri = resource$name,
              name = resource$name,
              description = resource$description,
              mimeType = resource$mime_type
            )
          }))
        } else list()
      )
    },
    
    #' Handle resources/read request
    handle_resources_read = function(params) {
      uri <- params$uri
      
      # Get resource
      tryCatch({
        self$server$get_resource(uri)
      }, error = function(e) {
        list(
          contents = list(list(
            uri = uri,
            mimeType = "text/plain",
            text = paste("Error reading resource:", as.character(e))
          ))
        )
      })
    },
    
    #' Handle prompts/list request
    handle_prompts_list = function(params) {
      list(
        prompts = if (length(self$server$prompts) > 0) {
          unname(lapply(self$server$prompts, function(prompt) {
            list(
              name = prompt$name,
              description = prompt$description,
              arguments = prompt$parameters
            )
          }))
        } else list()
      )
    },
    
    #' Handle prompts/get request  
    handle_prompts_get = function(params) {
      name <- params$name
      arguments <- params$arguments %||% list()
      
      if (!name %in% names(self$server$prompts)) {
        stop("Unknown prompt: ", name)
      }
      
      prompt <- self$server$prompts[[name]]
      
      # Simple template substitution
      text <- prompt$template
      for (arg_name in names(arguments)) {
        pattern <- paste0("{", arg_name, "}")
        text <- gsub(pattern, arguments[[arg_name]], text, fixed = TRUE)
      }
      
      list(
        messages = list(
          list(
            role = "user",
            content = list(
              type = "text",
              text = text
            )
          )
        )
      )
    },
    
    #' Create error response
    create_error_response = function(code, message, id = NULL) {
      list(
        jsonrpc = "2.0",
        error = list(
          code = code,
          message = message
        ),
        id = id
      )
    }
  )
)

#' Create an HTTP MCP server
#'
#' @description
#' Convenience function to create an MCP server with HTTP transport.
#' This function creates a server instance and configures it for HTTP.
#'
#' @param name Server name
#' @param version Server version
#' @param host Host address (default: "127.0.0.1")
#' @param port Port number (default: 8080)
#' @param log_file Optional path to log file
#' @param log_level Logging level ("debug", "info", "warn", "error", default: "info")
#' @return An MCP server configured with HTTP transport
#' @export
#' @examples
#' \dontrun{
#' # Create an HTTP MCP server
#' server <- mcp_http("My Server", "1.0.0", port = 3000)
#' 
#' # Add a tool
#' server$mcp_tool(
#'   name = "greet",
#'   fn = function(name) paste("Hello,", name),
#'   description = "Greet someone"
#' )
#' 
#' # Start the server
#' server$mcp_run()
#' }
mcp_http <- function(name = NULL, version = NULL, host = "127.0.0.1", port = 8080, log_file = NULL, log_level = "info") {
  server <- mcp(name = name, version = version)
  
  # Store HTTP-specific parameters
  server$.__enclos_env__$private$http_config <- list(
    host = host,
    port = port,
    log_file = log_file,
    log_level = log_level
  )
  
  # Override the mcp_run method to use HTTP transport by default
  server$.__enclos_env__$public$mcp_run <- function(transport = "http", host = NULL, port = NULL) {
    if (transport != "http") {
      warning("mcp_http servers use HTTP transport. Ignoring transport parameter.")
      transport <- "http"
    }
    
    # Use provided values or defaults from initialization
    host <- host %||% server$.__enclos_env__$private$http_config$host
    port <- port %||% server$.__enclos_env__$private$http_config$port
    
    # Create and start HTTP transport
    http_transport <- HttpTransport$new(
      server = server, 
      host = host, 
      port = port,
      log_file = server$.__enclos_env__$private$http_config$log_file,
      log_level = server$.__enclos_env__$private$http_config$log_level
    )
    http_transport$start()
  }
  
  server
}