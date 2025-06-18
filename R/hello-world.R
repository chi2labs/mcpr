#' Start a minimal MCP hello world server
#'
#' This function starts a simple MCP server with a single "hello" tool
#' that demonstrates the mcpr package is working correctly.
#'
#' @param transport Character string specifying the transport type. 
#'   Currently only "stdio" is supported.
#' @return Invisible NULL. The function starts the server which runs 
#'   until interrupted.
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
#' #       "command": "R",
#' #       "args": ["--quiet", "--slave", "-e", "mcpr::mcp_hello_world()"]
#' #     }
#' #   }
#' # }
#' }
mcp_hello_world <- function(transport = "stdio") {
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
  
  # Log startup message to stderr only
  if (transport == "stdio") {
    cat("Starting mcpr hello world server...\n", file = stderr())
    cat("This server has one tool: 'hello' - try calling it!\n", file = stderr())
  } else {
    message("Starting mcpr hello world server...")
    message("This server has one tool: 'hello' - try calling it!")
  }
  
  # Start the server
  server$mcp_run(transport = transport)
}