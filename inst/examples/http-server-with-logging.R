#!/usr/bin/env Rscript
#' HTTP MCP Server with Logging Example
#'
#' This example demonstrates how to use the logging features
#' of the HTTP MCP server for debugging and monitoring.

library(mcpr)

# Create a log directory
log_dir <- file.path(tempdir(), "mcp_logs")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_file <- file.path(log_dir, paste0("mcp_server_", format(Sys.Date(), "%Y%m%d"), ".log"))

cat("Log file will be written to:", log_file, "\n\n")

# Create an HTTP MCP server with logging enabled
server <- mcp_http(
  name = "Logged R Server",
  version = "1.0.0",
  host = "127.0.0.1",
  port = 8080,
  log_file = log_file,
  log_level = "debug"  # Set to debug for detailed logging
)

# Add a tool that demonstrates logging
server$mcp_tool(
  name = "process_data",
  fn = function(data, operation = "summary") {
    # This function will generate log entries when called
    
    # Parse data if string
    if (is.character(data)) {
      values <- as.numeric(strsplit(data, ",")[[1]])
    } else {
      values <- data
    }
    
    # Perform operation
    result <- switch(operation,
      summary = {
        list(
          mean = mean(values, na.rm = TRUE),
          median = median(values, na.rm = TRUE),
          sd = sd(values, na.rm = TRUE),
          min = min(values, na.rm = TRUE),
          max = max(values, na.rm = TRUE),
          n = length(values)
        )
      },
      histogram = {
        hist_data <- hist(values, plot = FALSE)
        list(
          breaks = hist_data$breaks,
          counts = hist_data$counts,
          density = hist_data$density
        )
      },
      outliers = {
        q1 <- quantile(values, 0.25, na.rm = TRUE)
        q3 <- quantile(values, 0.75, na.rm = TRUE)
        iqr <- q3 - q1
        lower_bound <- q1 - 1.5 * iqr
        upper_bound <- q3 + 1.5 * iqr
        outliers <- values[values < lower_bound | values > upper_bound]
        list(
          outliers = outliers,
          lower_bound = lower_bound,
          upper_bound = upper_bound,
          n_outliers = length(outliers)
        )
      },
      stop(paste("Unknown operation:", operation))
    )
    
    # Return formatted result
    jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
  },
  description = "Process numerical data with various operations",
  parameters = list(
    type = "object",
    properties = list(
      data = list(
        type = "string",
        description = "Comma-separated numerical values"
      ),
      operation = list(
        type = "string",
        description = "Operation to perform (summary, histogram, outliers)",
        enum = list("summary", "histogram", "outliers")
      )
    ),
    required = list("data")
  )
)

# Add a tool that might fail (for demonstrating error logging)
server$mcp_tool(
  name = "risky_operation",
  fn = function(risk_level = "low") {
    if (risk_level == "high") {
      stop("Operation failed due to high risk!")
    } else if (risk_level == "medium") {
      warning("Operation completed with warnings")
      return("Operation completed with some concerns")
    } else {
      return("Operation completed successfully")
    }
  },
  description = "A tool that might fail (for testing error handling)",
  parameters = list(
    type = "object",
    properties = list(
      risk_level = list(
        type = "string",
        description = "Risk level of the operation",
        enum = list("low", "medium", "high")
      )
    )
  )
)

# Add a resource
server$mcp_resource(
  name = "log_preview",
  fn = function() {
    # Return last 20 lines of the log file
    if (file.exists(log_file)) {
      lines <- readLines(log_file)
      n_lines <- length(lines)
      if (n_lines > 20) {
        lines <- lines[(n_lines - 19):n_lines]
      }
      paste(lines, collapse = "\n")
    } else {
      "No log entries yet"
    }
  },
  description = "Preview the last 20 lines of the server log",
  mime_type = "text/plain"
)

# Display information
cat("=== HTTP MCP Server with Logging ===\n")
cat("Server: http://127.0.0.1:8080\n")
cat("Log file:", log_file, "\n")
cat("Log level:", "debug", "\n\n")
cat("Tools:\n")
cat("  - process_data: Process numerical data\n")
cat("  - risky_operation: Demonstrates error logging\n\n")
cat("Resources:\n")
cat("  - log_preview: View recent log entries\n\n")
cat("Monitor the log file with:\n")
cat("  tail -f", log_file, "\n\n")
cat("Test commands:\n")
cat("  # Success case:\n")
cat("  curl -X POST http://localhost:8080/mcp \\\n")
cat("    -H 'Content-Type: application/json' \\\n")
cat("    -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"process_data\",\"arguments\":{\"data\":\"1,2,3,4,5,6,7,8,9,10\"}},\"id\":1}'\n\n")
cat("  # Error case:\n")
cat("  curl -X POST http://localhost:8080/mcp \\\n")
cat("    -H 'Content-Type: application/json' \\\n")
cat("    -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"risky_operation\",\"arguments\":{\"risk_level\":\"high\"}},\"id\":2}'\n\n")

# Also set up console logging for immediate feedback
if (requireNamespace("logger", quietly = TRUE)) {
  # Add a console appender in addition to file
  logger::log_appender(logger::appender_tee(
    logger::appender_file(log_file),
    logger::appender_console()
  ))
}

# Start the server
server$mcp_run(transport = "http")