# Example of MCP-decorated functions
# This file demonstrates the decorator-based approach for creating MCP servers

#* @mcp_tool
#* @description Calculate summary statistics for a numeric vector
#* @param data numeric A numeric vector to summarize
#* @param na.rm logical Whether to remove NA values (default: TRUE)
#* @param digits integer Number of decimal places to round to (default: 2)
calculate_stats <- function(data, na.rm = TRUE, digits = 2) {
  if (!is.numeric(data)) {
    stop("Data must be numeric")
  }
  
  stats <- list(
    mean = round(mean(data, na.rm = na.rm), digits),
    median = round(median(data, na.rm = na.rm), digits),
    sd = round(sd(data, na.rm = na.rm), digits),
    min = round(min(data, na.rm = na.rm), digits),
    max = round(max(data, na.rm = na.rm), digits),
    n = length(data),
    n_missing = sum(is.na(data))
  )
  
  # Add quartiles
  quartiles <- quantile(data, probs = c(0.25, 0.75), na.rm = na.rm)
  stats$q1 <- round(quartiles[1], digits)
  stats$q3 <- round(quartiles[2], digits)
  stats$iqr <- round(stats$q3 - stats$q1, digits)
  
  stats
}

#* @mcp_tool
#* @description Create a frequency table for categorical data
#* @param x vector A vector of categorical data
#* @param sort logical Whether to sort by frequency (default: TRUE)
#* @param prop logical Whether to include proportions (default: TRUE)
frequency_table <- function(x, sort = TRUE, prop = TRUE) {
  # Create frequency table
  tab <- table(x)
  
  if (sort) {
    tab <- sort(tab, decreasing = TRUE)
  }
  
  result <- list(
    counts = as.list(tab),
    total = length(x)
  )
  
  if (prop) {
    result$proportions <- as.list(prop.table(tab))
  }
  
  result
}

#* @mcp_tool
#* @description Perform correlation analysis between two numeric vectors
#* @param x numeric First numeric vector
#* @param y numeric Second numeric vector
#* @param method character Correlation method: "pearson", "spearman", or "kendall" (default: "pearson")
#* @param conf.level numeric Confidence level for confidence interval (default: 0.95)
correlation_analysis <- function(x, y, method = "pearson", conf.level = 0.95) {
  if (!is.numeric(x) || !is.numeric(y)) {
    stop("Both x and y must be numeric")
  }
  
  if (length(x) != length(y)) {
    stop("x and y must have the same length")
  }
  
  # Calculate correlation
  cor_test <- cor.test(x, y, method = method, conf.level = conf.level)
  
  result <- list(
    correlation = cor_test$estimate,
    p_value = cor_test$p.value,
    method = method,
    n = length(x)
  )
  
  # Add confidence interval for Pearson correlation
  if (method == "pearson" && !is.null(cor_test$conf.int)) {
    result$conf_int <- list(
      lower = cor_test$conf.int[1],
      upper = cor_test$conf.int[2],
      level = conf.level
    )
  }
  
  result
}

#* @mcp_resource
#* @description Get information about the current R session and environment
#* @mime_type text/plain
session_info <- function() {
  info <- sessionInfo()
  
  # Format session information
  lines <- c(
    paste("R Version:", info$R.version$version.string),
    paste("Platform:", info$platform),
    paste("Running under:", info$running),
    paste("Locale:", Sys.getlocale()),
    "",
    "Attached base packages:",
    paste("-", info$basePkgs),
    ""
  )
  
  if (length(info$otherPkgs) > 0) {
    lines <- c(lines,
      "Other attached packages:",
      sapply(info$otherPkgs, function(pkg) {
        paste("-", pkg$Package, pkg$Version)
      }),
      ""
    )
  }
  
  if (length(info$loadedOnly) > 0) {
    lines <- c(lines,
      "Loaded via namespace (and not attached):",
      paste("-", names(info$loadedOnly)),
      ""
    )
  }
  
  paste(lines, collapse = "\n")
}

#* @mcp_resource
#* @description Get list of available example datasets
#* @mime_type application/json
example_datasets <- function() {
  # Get datasets from common packages
  datasets_list <- list()
  
  # From base R datasets package
  if (requireNamespace("datasets", quietly = TRUE)) {
    data_info <- data(package = "datasets")$results
    for (i in seq_len(nrow(data_info))) {
      name <- data_info[i, "Item"]
      datasets_list[[name]] <- list(
        title = data_info[i, "Title"],
        package = "datasets",
        class = class(get(name, envir = as.environment("package:datasets")))[1]
      )
    }
  }
  
  datasets_list
}

#* @mcp_prompt
#* @description Request statistical analysis of a dataset
#* @template Please analyze the dataset {dataset_name} using appropriate statistical methods.
#*   Focus on {analysis_type} and provide insights suitable for a {audience_level} audience.
#*   {additional_requirements}
#* @param_dataset_name The name or description of the dataset to analyze
#* @param_analysis_type Type of analysis (e.g., "descriptive statistics", "correlation", "distribution")
#* @param_audience_level Audience level (e.g., "technical", "non-technical", "executive")
#* @param_additional_requirements Any additional specific requirements or constraints
statistical_analysis_request <- NULL

#* @mcp_prompt
#* @description Request data visualization
#* @template Create a {chart_type} visualization for {data_description}.
#*   The chart should highlight {key_insights} and be suitable for {presentation_context}.
#*   Use {color_scheme} color scheme if possible.
#* @param_chart_type Type of chart (e.g., "bar chart", "scatter plot", "histogram")
#* @param_data_description Description of the data to visualize
#* @param_key_insights Key insights to highlight in the visualization
#* @param_presentation_context Context where the chart will be used (e.g., "research paper", "presentation", "report")
#* @param_color_scheme Preferred color scheme (e.g., "colorblind-friendly", "corporate", "vibrant")
visualization_request <- NULL

# Example of using these decorated functions with mcpr:
# 
# library(mcpr)
# server <- mcp(name = "Statistical Analysis Server", version = "1.0.0")
# server$mcp_source("decorated-functions.R")
# server$mcp_run(transport = "stdio")