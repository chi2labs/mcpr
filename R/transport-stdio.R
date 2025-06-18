#' Stdio Transport for MCP
#'
#' @description
#' Implements stdio transport for MCP communication, reading from stdin
#' and writing to stdout.
#'
#' @export
StdioTransport <- R6::R6Class(
  "StdioTransport",
  
  public = list(
    #' @field server The MCP server instance
    server = NULL,
    
    #' @description
    #' Create a new stdio transport
    #' @param server MCP server instance
    initialize = function(server) {
      self$server <- server
      private$running <- FALSE
    },
    
    #' @description
    #' Start the stdio transport
    start = function() {
      private$running <- TRUE
      
      # Print initialization message
      cat("MCP Server started on stdio transport\n", file = stderr())
      
      # Use file("stdin") for better compatibility
      con <- file("stdin", "r")
      on.exit(close(con))
      
      # Main message loop
      while (private$running) {
        # Read a line from stdin
        line <- tryCatch({
          # Try readLines with the connection
          input <- readLines(con, n = 1, warn = FALSE)
          if (length(input) > 0) input[1] else character(0)
        }, error = function(e) {
          # If readLines fails, return empty
          character(0)
        })
        
        # Check for EOF or empty input
        if (length(line) == 0 || identical(line, character(0))) {
          break
        }
        
        # Skip empty lines
        if (nchar(trimws(line)) == 0) {
          next
        }
        
        # Process the message
        tryCatch({
          # Parse JSON-RPC message
          message <- jsonlite::fromJSON(line, simplifyVector = FALSE)
          
          # Handle the message
          response <- private$handle_message(message)
          
          # Send response if any
          if (!is.null(response)) {
            response_json <- mcp_serialize(response, pretty = FALSE)
            cat(response_json, "\n", sep = "")
            flush(stdout())
          }
        }, error = function(e) {
          # Send error response
          error_response <- list(
            jsonrpc = "2.0",
            error = list(
              code = -32700,
              message = "Parse error",
              data = as.character(e)
            ),
            id = NULL
          )
          cat(mcp_serialize(error_response, pretty = FALSE), "\n", sep = "")
          flush(stdout())
        })
      }
      
      cat("MCP Server stopped\n", file = stderr())
    },
    
    #' @description
    #' Stop the transport
    stop = function() {
      private$running <- FALSE
    }
  ),
  
  private = list(
    running = FALSE,
    
    #' Handle incoming JSON-RPC message
    handle_message = function(message) {
      # Validate JSON-RPC format
      if (is.null(message$jsonrpc) || message$jsonrpc != "2.0") {
        return(private$error_response(-32600, "Invalid Request", message$id))
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
        # Notification - no response needed
        return(NULL)
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
          lapply(self$server$tools, function(tool) {
            list(
              name = tool$name,
              description = tool$description,
              inputSchema = tool$parameters
            )
          })
        } else list()
      )
    },
    
    #' Handle tools/call request
    handle_tools_call = function(params) {
      name <- params$name
      arguments <- params$arguments %||% list()
      
      # Execute tool
      result <- tryCatch({
        self$server$execute_tool(name, arguments)
      }, error = function(e) {
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
            text = if (is.character(result) && length(result) == 1) result else mcp_serialize(result)
          ))
        )
      }
    },
    
    #' Handle resources/list request
    handle_resources_list = function(params) {
      list(
        resources = if (length(self$server$resources) > 0) {
          lapply(self$server$resources, function(resource) {
            list(
              uri = resource$name,
              name = resource$name,
              description = resource$description,
              mimeType = resource$mime_type
            )
          })
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
          lapply(self$server$prompts, function(prompt) {
            list(
              name = prompt$name,
              description = prompt$description,
              arguments = prompt$parameters
            )
          })
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