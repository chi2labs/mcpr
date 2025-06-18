#!/usr/bin/env Rscript

# MCP Hello World Server - Clean version with no debug output
suppressPackageStartupMessages(library(jsonlite))

# Create a blocking stdin connection
stdin_con <- file("stdin", open = "r", blocking = TRUE)
on.exit(close(stdin_con))

# Helper function to read JSON-RPC from stdin
read_json_rpc <- function() {
  line <- tryCatch({
    readLines(stdin_con, n = 1, warn = FALSE)
  }, error = function(e) {
    NULL
  })
  
  if (length(line) > 0 && nchar(line[1]) > 0) {
    return(line[1])
  }
  return(NULL)
}

# Send JSON-RPC response
send_response <- function(response) {
  cat(toJSON(response, auto_unbox = TRUE), "\n", sep = "")
  flush(stdout())
}

# Server info
server_info <- list(
  name = "mcpr Hello World",
  version = "1.0.0"
)

# Available tools
tools <- list(
  hello = list(
    name = "hello",
    description = "Say hello and confirm the mcpr server is working",
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(
          type = "string",
          description = "Name to greet"
        )
      )
    )
  )
)

# Available resources
resources <- list(
  about = list(
    uri = "about",
    name = "about",
    description = "Information about the mcpr package",
    mimeType = "text/plain"
  )
)

# Main server loop
repeat {
  request_line <- read_json_rpc()
  
  if (is.null(request_line)) {
    break
  }
  
  # Parse the JSON-RPC request
  request <- tryCatch({
    fromJSON(request_line, simplifyVector = FALSE)
  }, error = function(e) {
    send_response(list(
      jsonrpc = "2.0",
      id = NULL,
      error = list(
        code = -32700,
        message = "Parse error"
      )
    ))
    NULL
  })
  
  if (is.null(request)) {
    next
  }
  
  # Handle the request
  if (request$method == "initialize") {
    send_response(list(
      jsonrpc = "2.0",
      id = request$id,
      result = list(
        protocolVersion = "2024-11-05",
        capabilities = list(
          tools = as.list(tools),
          resources = as.list(resources)
        ),
        serverInfo = server_info
      )
    ))
  } else if (request$method == "initialized") {
    # No response needed
  } else if (request$method == "tools/list") {
    send_response(list(
      jsonrpc = "2.0",
      id = request$id,
      result = list(
        tools = unname(as.list(tools))
      )
    ))
  } else if (request$method == "resources/list") {
    send_response(list(
      jsonrpc = "2.0",
      id = request$id,
      result = list(
        resources = unname(as.list(resources))
      )
    ))
  } else if (request$method == "resources/read") {
    if (request$params$uri == "about") {
      send_response(list(
        jsonrpc = "2.0",
        id = request$id,
        result = list(
          contents = list(
            list(
              uri = "about",
              mimeType = "text/plain",
              text = paste(
                "mcpr - Model Context Protocol for R",
                "",
                "This is the hello world example server from the mcpr package.",
                "It demonstrates basic MCP functionality in R.",
                "",
                paste("Running on R", R.version.string),
                paste("Working directory:", getwd()),
                sep = "\n"
              )
            )
          )
        )
      ))
    } else {
      send_response(list(
        jsonrpc = "2.0",
        id = request$id,
        error = list(
          code = -32002,
          message = "Resource not found"
        )
      ))
    }
  } else if (request$method == "tools/call") {
    if (request$params$name == "hello") {
      name <- request$params$arguments$name
      if (is.null(name)) name <- "World"
      
      result_text <- paste0("Hello, ", name, "!\n",
                           "This message is from the mcpr package (R version ", 
                           R.version$major, ".", R.version$minor, ").\n",
                           "The server is working correctly!")
      
      send_response(list(
        jsonrpc = "2.0",
        id = request$id,
        result = list(
          content = list(
            list(
              type = "text",
              text = result_text
            )
          )
        )
      ))
    } else {
      send_response(list(
        jsonrpc = "2.0",
        id = request$id,
        error = list(
          code = -32002,
          message = "Tool not found"
        )
      ))
    }
  } else {
    send_response(list(
      jsonrpc = "2.0",
      id = request$id,
      error = list(
        code = -32601,
        message = "Method not found"
      )
    ))
  }
}