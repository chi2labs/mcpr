#' Start a minimal MCP hello world server
#'
#' This function starts a simple MCP server with a single "hello" tool
#' that demonstrates the mcpr package is working correctly.
#'
#' @param host Character string specifying the host to bind to (default: "127.0.0.1")
#' @param port Integer specifying the port to listen on (default: 8080)
#' @return Invisible NULL. The function starts the server which runs 
#'   until interrupted.
#' @importFrom utils packageVersion
#' @export
#' @examples
#' \dontrun{
#' # Start the hello world server
#' mcp_hello_world()
#' 
#' # To use with Claude Desktop, add to your config:
#' # {
#' #   "mcpServers": {
#' #     "r-hello": {
#' #       "url": "http://localhost:8080/mcp"
#' #     }
#' #   }
#' # }
#' }
mcp_hello_world <- function(host = "127.0.0.1", port = 8080) {
  # Create a minimal server
  server <- mcp(name = "mcpr Hello World", version = "1.0.0")
  
  # Add the hello tool
  server$mcp_tool(
    name = "hello",
    fn = function(name = "World") {
      # Return a multi-line message to show it's from mcpr
      paste0(
        "Hello, ", name, "!\n",
        "This message is from the mcpr package (Model Context Protocol for R).\n",
        "The server is working correctly!"
      )
    },
    description = "Say hello and confirm the mcpr server is working"
  )
  
  # Add a resource with package info
  server$mcp_resource(
    name = "about",
    fn = function() {
      paste0(
        "mcpr - Model Context Protocol for R\n",
        "Version: ", packageVersion("mcpr"), "\n",
        "This is a minimal hello world example showing that the MCP server is working.\n",
        "Visit https://github.com/chi2labs/mcpr for more information."
      )
    },
    description = "Information about the mcpr package",
    mime_type = "text/plain"
  )
  
  message("Starting mcpr hello world server...")
  message("Server will be available at: http://", host, ":", port, "/mcp")
  message("This server has one tool: 'hello' - try calling it!")
  
  # Start the server with HTTP transport
  server$mcp_run(transport = "http", host = host, port = port)
}

#' Start an HTTP MCP hello world server
#'
#' This function starts a simple MCP server over HTTP with a single "hello" tool
#' that demonstrates the mcpr package is working correctly. Unlike the stdio version,
#' this server can handle multiple clients and is easier to test with standard HTTP tools.
#'
#' @param host Character string specifying the host to bind to (default: "127.0.0.1")
#' @param port Integer specifying the port to listen on (default: 8080)
#' @param docs Logical indicating whether to enable Swagger documentation (default: FALSE)
#' @param quiet Logical indicating whether to suppress startup messages (default: FALSE)
#' @return Invisible NULL. The function starts the server which runs until interrupted.
#' @export
#' @examples
#' \dontrun{
#' # Start the HTTP hello world server on default port
#' mcp_hello_world_http()
#' 
#' # Start on a custom port with documentation
#' mcp_hello_world_http(port = 3000, docs = TRUE)
#' 
#' # Test with curl:
#' # curl -X POST http://localhost:8080/mcp \
#' #   -H "Content-Type: application/json" \
#' #   -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
#' }
mcp_hello_world_http <- function(host = "127.0.0.1", port = 8080, docs = FALSE, quiet = FALSE) {
  # Create server using the mcp_http convenience function
  server <- mcp_http(
    name = "mcpr Hello World HTTP", 
    version = "1.0.0",
    host = host,
    port = port
  )
  
  # Add the hello tool
  server$mcp_tool(
    name = "hello",
    fn = function(name = "World") {
      # Return a multi-line message to show it's from mcpr
      paste0(
        "Hello, ", name, "!\n",
        "This message is from the mcpr HTTP server (Model Context Protocol for R).\n",
        "The server is working correctly!"
      )
    },
    description = "Say hello and confirm the mcpr server is working"
  )
  
  # Add a resource with package info
  server$mcp_resource(
    name = "about",
    fn = function() {
      paste0(
        "mcpr - Model Context Protocol for R (HTTP Transport)\n",
        "Version: ", packageVersion("mcpr"), "\n",
        "This is a minimal hello world example showing that the MCP HTTP server is working.\n",
        "Server running on: http://", host, ":", port, "/mcp\n",
        "Visit https://github.com/chi2labs/mcpr for more information."
      )
    },
    description = "Information about the mcpr package and HTTP server",
    mime_type = "text/plain"
  )
  
  # Add an example prompt
  server$mcp_prompt(
    name = "greeting",
    template = "Please greet {name} in the style of {style}.",
    description = "Generate a greeting in a specific style",
    parameters = list(
      name = list(type = "string", description = "Name to greet"),
      style = list(type = "string", description = "Style of greeting (e.g., formal, casual, pirate)")
    )
  )
  
  if (!quiet) {
    message("\n=== mcpr Hello World HTTP Server ===")
    message("Server will start on: http://", host, ":", port)
    message("\nAvailable endpoints:")
    message("  - POST /mcp      : MCP protocol endpoint")
    message("  - GET  /health   : Health check")
    message("  - GET  /         : Server info")
    if (docs) {
      message("  - GET  /__docs__ : Swagger documentation")
    }
    message("\nTools: hello")
    message("Resources: about")
    message("Prompts: greeting")
    message("\nTest with: curl -X POST http://", host, ":", port, "/mcp -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}'")
    message("\nPress Ctrl+C to stop the server\n")
  }
  
  # Create and start HTTP transport directly (since mcp_http overrides mcp_run)
  transport <- HttpTransport$new(server = server, host = host, port = port)
  transport$start(docs = docs, quiet = quiet)
}