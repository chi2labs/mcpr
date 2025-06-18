#!/usr/bin/env Rscript

# MCP Server for Claude Desktop
# To use this with Claude Desktop, add to your claude_desktop_config.json:
# {
#   "mcpServers": {
#     "r-analysis": {
#       "command": "Rscript",
#       "args": ["/path/to/mcp-server.R"]
#     }
#   }
# }

library(mcpr)

# Create the server
server <- mcp(name = "R Analysis Server", version = "1.0.0")

# Statistical tools
server$mcp_tool(
  name = "summary_stats",
  fn = function(data) {
    if (!is.numeric(data)) {
      stop("Data must be numeric")
    }
    
    list(
      n = length(data),
      mean = mean(data, na.rm = TRUE),
      median = median(data, na.rm = TRUE),
      sd = sd(data, na.rm = TRUE),
      min = min(data, na.rm = TRUE),
      max = max(data, na.rm = TRUE),
      q1 = quantile(data, 0.25, na.rm = TRUE),
      q3 = quantile(data, 0.75, na.rm = TRUE)
    )
  },
  description = "Calculate comprehensive summary statistics"
)

server$mcp_tool(
  name = "correlation",
  fn = function(x, y, method = "pearson") {
    if (!is.numeric(x) || !is.numeric(y)) {
      stop("Both x and y must be numeric")
    }
    if (length(x) != length(y)) {
      stop("x and y must have the same length")
    }
    
    cor_result <- cor.test(x, y, method = method)
    list(
      correlation = cor_result$estimate,
      p_value = cor_result$p.value,
      confidence_interval = as.numeric(cor_result$conf.int),
      method = cor_result$method
    )
  },
  description = "Calculate correlation between two variables"
)

server$mcp_tool(
  name = "linear_regression", 
  fn = function(formula_str, data) {
    # Parse formula string
    formula <- as.formula(formula_str)
    
    # Fit model
    model <- lm(formula, data = as.data.frame(data))
    summary_model <- summary(model)
    
    list(
      coefficients = coef(summary_model),
      r_squared = summary_model$r.squared,
      adj_r_squared = summary_model$adj.r.squared,
      f_statistic = summary_model$fstatistic,
      residual_std_error = summary_model$sigma
    )
  },
  description = "Fit a linear regression model"
)

# Data generation tools
server$mcp_tool(
  name = "random_normal",
  fn = function(n, mean = 0, sd = 1, seed = NULL) {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    rnorm(n, mean = mean, sd = sd)
  },
  description = "Generate random normal data"
)

server$mcp_tool(
  name = "random_uniform",
  fn = function(n, min = 0, max = 1, seed = NULL) {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    runif(n, min = min, max = max)
  },
  description = "Generate random uniform data"
)

# Utility tools
server$mcp_tool(
  name = "create_sequence",
  fn = function(from, to, by = 1) {
    seq(from = from, to = to, by = by)
  },
  description = "Create a sequence of numbers"
)

server$mcp_tool(
  name = "sample_data",
  fn = function(data, size, replace = FALSE, prob = NULL) {
    sample(data, size = size, replace = replace, prob = prob)
  },
  description = "Sample from data with or without replacement"
)

# Add informational resource
server$mcp_resource(
  name = "server_info",
  fn = function() {
    paste0(
      "R Analysis Server v1.0.0\n\n",
      "Available tools:\n",
      "- summary_stats: Calculate comprehensive summary statistics\n",
      "- correlation: Calculate correlation between variables\n", 
      "- linear_regression: Fit linear regression models\n",
      "- random_normal: Generate normal random data\n",
      "- random_uniform: Generate uniform random data\n",
      "- create_sequence: Create numeric sequences\n",
      "- sample_data: Sample from data\n\n",
      "R version: ", R.version.string
    )
  },
  description = "Information about this server and available tools"
)

# Add example prompt
server$mcp_prompt(
  name = "analyze_dataset",
  template = "Please analyze this dataset: {description}. 
Start with summary statistics, check for correlations between variables, 
and suggest appropriate statistical models.",
  description = "Template for comprehensive data analysis"
)

# Start the server
cat("Starting R Analysis MCP Server...\n", file = stderr())
server$mcp_run(transport = "stdio")