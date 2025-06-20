#!/usr/bin/env Rscript

# Basic MCP Server Example
# This example shows how to create a simple MCP server with tools and resources

library(mcpr)

# Create a new MCP server
server <- mcp(name = "Basic R Analysis Server", version = "1.0.0")

# Add some tools
server$mcp_tool(
  name = "calculate_mean",
  fn = function(numbers) {
    if (!is.numeric(numbers)) {
      stop("Input must be numeric")
    }
    mean(numbers)
  },
  description = "Calculate the mean of a numeric vector"
)

server$mcp_tool(
  name = "generate_summary",
  fn = function(data) {
    if (is.data.frame(data)) {
      summary(data)
    } else if (is.numeric(data)) {
      list(
        mean = mean(data),
        median = median(data),
        sd = sd(data),
        min = min(data),
        max = max(data)
      )
    } else {
      stop("Data must be numeric or a data frame")
    }
  },
  description = "Generate summary statistics for data"
)

server$mcp_tool(
  name = "create_histogram",
  fn = function(data, breaks = 30) {
    if (!is.numeric(data)) {
      stop("Data must be numeric")
    }
    
    # Create histogram data
    h <- hist(data, breaks = breaks, plot = FALSE)
    
    list(
      breaks = h$breaks,
      counts = h$counts,
      density = h$density,
      mids = h$mids
    )
  },
  description = "Create histogram data for a numeric vector"
)

# Add a resource
server$mcp_resource(
  name = "dataset_info",
  fn = function() {
    "This server provides basic statistical analysis tools for R.
    Available tools:
    - calculate_mean: Compute the mean of numeric data
    - generate_summary: Get summary statistics
    - create_histogram: Generate histogram data
    
    Pass numeric vectors or data frames to these tools."
  },
  description = "Information about available tools",
  mime_type = "text/plain"
)

# Add a prompt template
server$mcp_prompt(
  name = "analyze_data",
  template = "Please analyze the following data: {data_description}. 
  I need to understand the distribution and key statistics. 
  Use the available tools to provide a comprehensive analysis.",
  description = "Template for requesting data analysis",
  parameters = list(
    data_description = list(
      type = "string",
      description = "Description of the data to analyze"
    )
  )
)

# Print server info
print(server)

# Run the server on HTTP
message("\nStarting MCP server on HTTP...")
message("Server will be available at: http://localhost:8080/mcp")
server$mcp_run(transport = "http", port = 8080)