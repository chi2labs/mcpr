#!/usr/bin/env Rscript

# Example: Generating MCP Servers with mcpr

library(mcpr)

# Example 1: Simple server generation
cat("=== Example 1: Simple Server ===\n")
generate_mcp_server(
  name = "hello-world",
  title = "Hello World MCP Server",
  description = "A simple MCP server that demonstrates basic functionality",
  path = tempdir()
)

# Example 2: Server with tools
cat("\n=== Example 2: Server with Tools ===\n")
tools <- list(
  greet = list(
    description = "Greet a person by name",
    parameters = list(
      name = list(
        type = "string",
        description = "The name of the person to greet"
      ),
      language = list(
        type = "string", 
        description = "Language for greeting (en, es, fr)"
      )
    )
  ),
  
  calculate = list(
    description = "Perform a calculation",
    parameters = list(
      expression = list(
        type = "string",
        description = "R expression to evaluate"
      )
    )
  ),
  
  get_time = list(
    description = "Get current time in specified timezone",
    parameters = list(
      timezone = list(
        type = "string",
        description = "Timezone (e.g., 'UTC', 'America/New_York')"
      )
    )
  )
)

server_dir <- generate_mcp_server(
  name = "utility-tools",
  title = "Utility Tools Server",
  description = "Collection of useful utility functions",
  tools = tools,
  path = tempdir()
)

cat("Server created at:", server_dir, "\n")

# Example 3: Using programmatic API
cat("\n=== Example 3: Programmatic API ===\n")
server <- mcp(name = "Data Analysis Server", version = "1.0.0")

# Add statistical tools
server$mcp_tool(
  name = "summary_stats",
  fn = function(data) {
    list(
      mean = mean(data, na.rm = TRUE),
      median = median(data, na.rm = TRUE),
      sd = sd(data, na.rm = TRUE),
      min = min(data, na.rm = TRUE),
      max = max(data, na.rm = TRUE)
    )
  },
  description = "Calculate summary statistics for numeric data"
)

server$mcp_tool(
  name = "correlation",
  fn = function(x, y) {
    cor(x, y, use = "complete.obs")
  },
  description = "Calculate correlation between two vectors"
)

# Add a resource
server$mcp_resource(
  name = "datasets",
  fn = function() {
    "Available datasets: iris, mtcars, airquality"
  },
  description = "List of available R datasets"
)

# Generate the server
server$generate(path = tempdir(), template = "full")

# Example 4: Configuration file
cat("\n=== Example 4: Configuration File ===\n")
config_file <- file.path(tempdir(), "server-config.yaml")
create_example_config(config_file, format = "yaml")
cat("Created example config at:", config_file, "\n")

# Example 5: Server with resources and prompts
cat("\n=== Example 5: Full-Featured Server ===\n")
resources <- list(
  list(
    uri = "data://iris",
    name = "Iris Dataset",
    description = "Classic iris flower dataset"
  ),
  list(
    uri = "data://mtcars", 
    name = "Motor Trend Cars",
    description = "1974 Motor Trend car data"
  )
)

prompts <- list(
  analyze_data = list(
    description = "Analyze a dataset and provide insights"
  ),
  visualize = list(
    description = "Create appropriate visualizations for the data"
  )
)

generate_mcp_server(
  name = "data-science",
  title = "Data Science Toolkit",
  description = "Comprehensive data science tools and datasets",
  tools = tools,
  resources = resources,
  prompts = prompts,
  author = "Data Science Team",
  path = tempdir()
)

cat("\n✅ All examples completed successfully!\n")
cat("\nTo use these servers:\n")
cat("1. Navigate to the server directory\n")
cat("2. Run: npm install\n")
cat("3. Run: npm test\n")
cat("4. Add to Claude Desktop configuration\n")