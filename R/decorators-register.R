#' Register decorated elements with an MCP server
#'
#' @param server An MCPServer instance
#' @param elements List of parsed elements from parse_mcp_decorators
#' @param env Environment containing the function definitions
#' @return The server (invisibly) for chaining
register_decorated_elements <- function(server, elements, env = parent.frame()) {
  for (element in elements) {
    # Parse and evaluate the function definition in the provided environment
    tryCatch({
      eval(parse(text = element$definition), envir = env)
      fn <- get(element$name, envir = env)
      
      # Convert decorators to MCP parameters
      params <- decorators_to_mcp_params(element)
      
      # Register based on type
      if (element$type == "mcp_tool") {
        server$mcp_tool(
          name = params$name,
          fn = fn,
          description = params$description,
          parameters = params$parameters
        )
      } else if (element$type == "mcp_resource") {
        server$mcp_resource(
          name = params$name,
          fn = fn,
          description = params$description,
          mime_type = params$mime_type
        )
      } else if (element$type == "mcp_prompt") {
        # For prompts, we don't need to evaluate a function
        # The template is in the decorators
        if (!is.null(params$template)) {
          server$mcp_prompt(
            name = params$name,
            template = params$template,
            description = params$description,
            parameters = params$parameters
          )
        } else {
          warning("No template found for prompt '", element$name, "'")
        }
      }
      
    }, error = function(e) {
      warning("Failed to register ", element$type, " '", element$name, "': ", e$message)
    })
  }
  
  invisible(server)
}