# Type Conversion Demo for mcpR
# This script demonstrates the type conversion capabilities of mcpR

library(mcpr)

cat("=== mcpR Type Conversion Demo ===\n\n")

# 1. Basic Types
cat("1. Basic Types\n")
cat("--------------\n")

# NULL
cat("NULL: ", mcp_serialize(NULL), "\n")

# Single values (auto-unboxed)
cat("Single number: ", mcp_serialize(42), "\n")
cat("Single string: ", mcp_serialize("hello"), "\n")
cat("Single boolean: ", mcp_serialize(TRUE), "\n")

# Vectors
cat("Numeric vector: ", mcp_serialize(1:5), "\n")
cat("Character vector: ", mcp_serialize(c("a", "b", "c")), "\n\n")

# 2. Special Numeric Values
cat("2. Special Numeric Values\n")
cat("------------------------\n")

special_nums <- c(1, Inf, -Inf, NaN, NA, 5)
cat("Special numbers: ", mcp_serialize(special_nums), "\n\n")

# 3. Complex Types
cat("3. Complex Types\n")
cat("----------------\n")

# Matrix
mat <- matrix(1:6, nrow = 2, ncol = 3)
cat("Matrix:\n")
print(mat)
cat("Serialized: ", substr(mcp_serialize(mat), 1, 100), "...\n\n")

# Data frame
df <- data.frame(
  id = 1:3,
  name = c("Alice", "Bob", "Charlie"),
  score = c(95.5, 87.3, 91.0),
  grade = factor(c("A", "B", "A"))
)
cat("Data frame:\n")
print(df)
cat("Serialized: ", substr(mcp_serialize(df), 1, 150), "...\n\n")

# 4. Date and Time
cat("4. Date and Time\n")
cat("----------------\n")

today <- Sys.Date()
now <- Sys.time()
cat("Date: ", format(today), " → ", mcp_serialize(today), "\n")
cat("DateTime: ", format(now), " → ", substr(mcp_serialize(now), 1, 100), "...\n\n")

# 5. Other Special Types
cat("5. Other Special Types\n")
cat("---------------------\n")

# Complex numbers
complex_num <- 3 + 4i
cat("Complex: ", as.character(complex_num), " → ", mcp_serialize(complex_num), "\n")

# Raw data
raw_data <- charToRaw("Hello")
cat("Raw: ", paste(raw_data, collapse = " "), " → ", mcp_serialize(raw_data), "\n")

# Formula
formula_obj <- y ~ x + z
result <- to_mcp_json(formula_obj)
cat("Formula: ", deparse(formula_obj), " → ", substr(mcp_serialize(result), 1, 80), "...\n\n")

# 6. Large Object Handling
cat("6. Large Object Handling\n")
cat("-----------------------\n")

large_df <- data.frame(
  x = 1:10000,
  y = rnorm(10000)
)
large_json <- to_mcp_json(large_df, size_limit = 1000)
cat("Large data frame (10000 rows):\n")
cat("Type: ", large_json$`_mcp_type`, "\n")
cat("Size: ", large_json$size_human, "\n")
cat("Preview rows: ", large_json$preview$nrow, "\n\n")

# 7. Custom Serializers
cat("7. Custom Serializers\n")
cat("--------------------\n")

# Define a custom class
setClass("Person", slots = c(name = "character", age = "numeric"))

# Register custom serializer
register_mcp_serializer("Person", function(obj) {
  list(
    `_mcp_type` = "custom_person",
    name = obj@name,
    age = obj@age,
    adult = obj@age >= 18
  )
})

# Create and serialize custom object
person <- new("Person", name = "John Doe", age = 25)
cat("Custom object serialized: ", mcp_serialize(person), "\n\n")

# 8. Schema Validation
cat("8. Schema Validation\n")
cat("-------------------\n")

# Define schema
user_schema <- list(
  type = "object",
  properties = list(
    username = list(type = "string", minLength = 3),
    email = list(type = "string"),
    age = list(type = "number", minimum = 0, maximum = 150)
  ),
  required = c("username", "email")
)

# Valid user
valid_user <- list(
  username = "alice123",
  email = "alice@example.com",
  age = 30
)

cat("Valid user passes validation: ", 
    validate_against_schema(valid_user, user_schema), "\n")

# Invalid user (will error if run)
# invalid_user <- list(username = "ab", age = 200)  # Too short, missing email, age too high
# validate_against_schema(invalid_user, user_schema)

# 9. Data Streaming
cat("\n9. Data Streaming\n")
cat("-----------------\n")

# Stream a data frame in chunks
streaming_df <- data.frame(
  id = 1:100,
  value = runif(100)
)

chunk_count <- 0
stream_dataframe(streaming_df, chunk_size = 25, callback = function(chunk) {
  chunk_count <<- chunk_count + 1
  cat("Received chunk", chunk$chunk, "of", chunk$total_chunks,
      "(rows", chunk$start_row, "-", chunk$end_row, ")\n")
})

# 10. Round-trip Conversion
cat("\n10. Round-trip Conversion\n")
cat("------------------------\n")

# Create complex object
original <- list(
  metadata = list(
    version = "1.0",
    created = Sys.Date()
  ),
  data = data.frame(
    x = 1:5,
    y = c(1.1, 2.2, Inf, 4.4, 5.5),
    category = factor(c("A", "B", "A", "C", "B"))
  ),
  matrix = matrix(1:9, 3, 3),
  special = list(
    complex = 2 + 3i,
    formula = y ~ x^2
  )
)

# Serialize and deserialize
json_str <- mcp_serialize(original)
recovered <- mcp_deserialize(json_str)

cat("Original object keys: ", paste(names(original), collapse = ", "), "\n")
cat("Recovered object keys: ", paste(names(recovered), collapse = ", "), "\n")
cat("JSON size: ", nchar(json_str), " characters\n\n")

# 11. Plot Conversion (if ggplot2 available)
if (requireNamespace("ggplot2", quietly = TRUE)) {
  cat("11. Plot Conversion\n")
  cat("------------------\n")
  
  library(ggplot2)
  p <- ggplot(mtcars, aes(x = mpg, y = wt)) + 
    geom_point(aes(color = factor(cyl))) +
    theme_minimal() +
    labs(title = "MPG vs Weight", color = "Cylinders")
  
  plot_json <- to_mcp_json(p)
  cat("Plot converted to PNG\n")
  cat("Format: ", plot_json$format, "\n")
  cat("Type: ", plot_json$plot_type, "\n")
  cat("Data size: ", nchar(plot_json$data), " characters (base64)\n")
}

cat("\n=== Demo Complete ===\n")