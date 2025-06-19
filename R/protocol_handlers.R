#' Protocol Handlers for R↔Node.js Communication
#'
#' @description
#' Provides handlers for MCP protocol methods in the context of the
#' R↔Node.js communication protocol.
#'
#' @importFrom R6 R6Class
#' @name protocol_handlers
NULL

#' Create default protocol handlers for MCP server
#'
#' @description
#' Creates a set of default handlers for common MCP protocol methods.
#' These handlers integrate with the MCPServer class to provide
#' protocol functionality.
#'
#' @param server MCPServer instance
#' @return Named list of handler functions
#' @export
create_mcp_protocol_handlers <- function(server) {
  list(
    # MCP Core Protocol Methods
    "initialize" = function(params) {
      list(
        protocolVersion = "2024-11-05",
        capabilities = server$get_capabilities(),
        serverInfo = list(
          name = server$name,
          version = server$version
        )
      )
    },
    
    "initialized" = function(params) {
      # Notification that client has completed initialization
      # No response needed
      NULL
    },
    
    # Tools Protocol
    "tools/list" = function(params) {
      tools <- if (length(server$tools) > 0) {
        lapply(server$tools, function(tool) {
          list(
            name = tool$name,
            description = tool$description,
            inputSchema = tool$parameters
          )
        })
      } else {
        list()
      }
      
      list(tools = tools)
    },
    
    "tools/call" = function(params) {
      name <- params$name
      arguments <- params$arguments %||% list()
      
      # Execute tool with error handling
      result <- tryCatch({
        server$execute_tool(name, arguments)
      }, error = function(e) {
        return(list(
          isError = TRUE,
          content = list(list(
            type = "text",
            text = paste("Error executing tool:", as.character(e))
          ))
        ))
      })
      
      # Format result according to MCP spec
      if (is.list(result) && !is.null(result$isError) && result$isError) {
        result
      } else {
        list(
          content = list(list(
            type = "text",
            text = if (is.character(result) && length(result) == 1) {
              result
            } else {
              protocol_serialize(result)
            }
          ))
        )
      }
    },
    
    # Resources Protocol
    "resources/list" = function(params) {
      resources <- if (length(server$resources) > 0) {
        lapply(server$resources, function(resource) {
          list(
            uri = resource$name,
            name = resource$name,
            description = resource$description,
            mimeType = resource$mime_type %||% "text/plain"
          )
        })
      } else {
        list()
      }
      
      list(resources = resources)
    },
    
    "resources/read" = function(params) {
      uri <- params$uri
      
      tryCatch({
        server$get_resource(uri)
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
    
    # Prompts Protocol
    "prompts/list" = function(params) {
      prompts <- if (length(server$prompts) > 0) {
        lapply(server$prompts, function(prompt) {
          list(
            name = prompt$name,
            description = prompt$description,
            arguments = prompt$parameters
          )
        })
      } else {
        list()
      }
      
      list(prompts = prompts)
    },
    
    "prompts/get" = function(params) {
      name <- params$name
      arguments <- params$arguments %||% list()
      
      if (!name %in% names(server$prompts)) {
        stop("Unknown prompt: ", name)
      }
      
      prompt <- server$prompts[[name]]
      
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
    
    # Server lifecycle methods
    "ping" = function(params) {
      list(
        status = "ok",
        timestamp = Sys.time(),
        server = server$name
      )
    }
  )
}

#' Enhanced Stdio Transport with Protocol Support
#'
#' @description
#' An enhanced version of StdioTransport that uses the R↔Node.js
#' communication protocol for better reliability and error handling.
#'
#' @importFrom R6 R6Class
#' @export
ProtocolStdioTransport <- R6::R6Class(
  "ProtocolStdioTransport",
  
  public = list(
    #' @field server The MCP server instance
    server = NULL,
    
    #' @field use_protocol Whether to use the enhanced protocol
    use_protocol = TRUE,
    
    #' @description
    #' Create a new protocol-aware stdio transport
    #' @param server MCP server instance
    #' @param use_protocol Logical, whether to use enhanced protocol (default TRUE)
    initialize = function(server, use_protocol = TRUE) {
      self$server <- server
      self$use_protocol <- use_protocol && (Sys.getenv("MCPR_USE_PROTOCOL", "true") != "false")
      private$running <- FALSE
      private$handlers <- create_mcp_protocol_handlers(server)
    },
    
    #' @description
    #' Start the transport
    start = function() {
      private$running <- TRUE
      
      # Don't write startup messages to stderr to avoid breaking MCP clients
      if (self$use_protocol) {
        private$run_protocol_mode()
      } else {
        private$run_legacy_mode()
      }
    },
    
    #' @description
    #' Stop the transport
    stop = function() {
      private$running <- FALSE
    }
  ),
  
  private = list(
    running = FALSE,
    handlers = NULL,
    
    #' Run in enhanced protocol mode
    run_protocol_mode = function() {
      # Use the communication protocol functions
      run_protocol_loop(
        handlers = private$handlers,
        on_ready = function() {
          # Signal readiness without stderr output
        }
      )
    },
    
    #' Run in legacy mode (backwards compatibility)
    run_legacy_mode = function() {
      # Use the original StdioTransport logic
      while (private$running) {
        line <- tryCatch({
          input <- readLines(stdin(), n = 1, warn = FALSE)
          
          if (length(input) > 0 && nchar(input[1]) > 0) {
            input[1]
          } else if (length(input) == 0) {
            character(0)
          } else {
            ""
          }
        }, error = function(e) {
          character(0)
        })
        
        # Check for EOF
        if (length(line) == 0 || identical(line, character(0))) {
          if (!exists("empty_reads", private)) {
            private$empty_reads <- 0
          }
          private$empty_reads <- private$empty_reads + 1
          
          if (private$empty_reads > 10) {
            break
          }
          
          Sys.sleep(0.1)
          next
        } else {
          private$empty_reads <- 0
        }
        
        # Skip empty lines
        if (nchar(trimws(line)) == 0) {
          next
        }
        
        # Process the message using JSON-RPC format
        tryCatch({
          message <- jsonlite::fromJSON(line, simplifyVector = FALSE)
          response <- private$handle_jsonrpc_message(message)
          
          if (!is.null(response)) {
            response_json <- protocol_serialize(response, pretty = FALSE)
            cat(response_json, "\n", sep = "")
            flush(stdout())
          }
        }, error = function(e) {
          error_response <- list(
            jsonrpc = "2.0",
            error = list(
              code = -32700,
              message = "Parse error",
              data = as.character(e)
            ),
            id = NULL
          )
          cat(protocol_serialize(error_response, pretty = FALSE), "\n", sep = "")
          flush(stdout())
        })
      }
    },
    
    #' Handle JSON-RPC message (legacy mode)
    handle_jsonrpc_message = function(message) {
      # Validate JSON-RPC format
      if (is.null(message$jsonrpc) || message$jsonrpc != "2.0") {
        return(private$error_response(-32600, "Invalid Request", message$id))
      }
      
      # Extract method and params
      method <- message$method
      params <- message$params %||% list()
      id <- message$id
      
      # Find handler
      handler <- private$handlers[[method]]
      
      if (is.null(handler)) {
        return(private$error_response(-32601, "Method not found", id))
      }
      
      # Execute handler
      result <- tryCatch({
        handler(params)
      }, error = function(e) {
        return(list(error = list(
          code = -32603,
          message = "Internal error",
          data = as.character(e)
        )))
      })
      
      # Build response
      if (!is.null(id)) {
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
        return(NULL)
      }
    },
    
    #' Create error response
    error_response = function(code, message, id = NULL) {
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

#' Create protocol-aware server instance
#'
#' @description
#' Creates an MCP server instance that uses the enhanced protocol transport.
#' This is a convenience function that sets up both the server and transport.
#'
#' @param name Character string, server name
#' @param version Character string, server version
#' @param use_protocol Logical, whether to use enhanced protocol
#' @return List with server and transport components
#' @export
create_protocol_server <- function(name = "R MCP Server", 
                                 version = "1.0.0",
                                 use_protocol = TRUE) {
  # Create server instance
  server <- MCPServer$new(name = name, version = version)
  
  # Create protocol transport
  transport <- ProtocolStdioTransport$new(server, use_protocol = use_protocol)
  
  list(
    server = server,
    transport = transport,
    start = function() transport$start(),
    stop = function() transport$stop()
  )
}