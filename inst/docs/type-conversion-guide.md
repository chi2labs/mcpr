# Type Conversion Guide for mcpR

This guide explains how mcpR handles type conversion between R objects and JSON for Model Context Protocol (MCP) communication.

## Overview

The mcpR package provides comprehensive type conversion between R's rich type system and JSON. This ensures data integrity when exposing R functionality through MCP servers.

## Basic Type Conversions

### Atomic Types

| R Type | JSON Type | Example | Notes |
|--------|-----------|---------|-------|
| `NULL` | `null` | `NULL` → `null` | Direct mapping |
| `logical` | `boolean` | `TRUE` → `true` | NA becomes null |
| `numeric` | `number` | `3.14` → `3.14` | Special values handled |
| `integer` | `number` | `42L` → `42` | Preserves integer type |
| `character` | `string` | `"hello"` → `"hello"` | UTF-8 encoding |

### Special Numeric Values

R has special numeric values that don't exist in JSON:

```r
# Special values are converted to strings
c(1, Inf, -Inf, NaN, NA)
# → {"values": [1, "Inf", "-Inf", "NaN", null], "_mcp_type": "numeric_vector_special"}
```

## Complex Type Conversions

### Vectors

Vectors are converted to JSON arrays:

```r
# Numeric vector
c(1, 2, 3) → [1, 2, 3]

# Named vector becomes object
c(a = 1, b = 2) → {"a": 1, "b": 2}
```

### Matrices and Arrays

Matrices and arrays preserve dimensions:

```r
matrix(1:6, nrow = 2)
# → {
#   "data": [1, 2, 3, 4, 5, 6],
#   "dim": [2, 3],
#   "_mcp_type": "matrix"
# }
```

### Data Frames

Data frames are converted column-wise by default:

```r
data.frame(x = 1:3, y = c("a", "b", "c"))
# → {
#   "x": [1, 2, 3],
#   "y": ["a", "b", "c"],
#   "_mcp_type": "data.frame",
#   "_mcp_nrow": 3
# }
```

### Factors

Factors preserve both levels and values:

```r
factor(c("a", "b", "a"))
# → {
#   "levels": ["a", "b"],
#   "values": [1, 2, 1],
#   "_mcp_type": "factor"
# }
```

### Dates and Times

Date/time objects use ISO 8601 format:

```r
# Date
as.Date("2024-01-15")
# → {"values": "2024-01-15", "_mcp_type": "Date"}

# POSIXct with timezone
as.POSIXct("2024-01-15 14:30:00", tz = "America/New_York")
# → {
#   "values": "2024-01-15T14:30:00",
#   "timezone": "America/New_York",
#   "_mcp_type": "POSIXct"
# }
```

### Complex Numbers

Complex numbers are decomposed:

```r
3 + 4i
# → {
#   "real": 3,
#   "imaginary": 4,
#   "_mcp_type": "complex"
# }
```

### Raw Vectors

Binary data is base64 encoded:

```r
as.raw(c(0x48, 0x65))
# → {
#   "data": "SGU=",
#   "_mcp_type": "raw"
# }
```

## Advanced Features

### Large Object Handling

Objects exceeding the size limit (default 1MB) are summarized:

```r
large_df <- data.frame(x = 1:1000000)
to_mcp_json(large_df, size_limit = 1000)
# → {
#   "_mcp_type": "large_object",
#   "class": "data.frame",
#   "size": 8000048,
#   "size_human": "7.6 Mb",
#   "summary": ["1000000 obs. of 1 variable"],
#   "preview": {
#     "nrow": 1000000,
#     "ncol": 1,
#     "head": {...}  # First 5 rows
#   }
# }
```

### Plot Conversion

Plots are converted to base64-encoded PNG images:

```r
library(ggplot2)
p <- ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point()
to_mcp_json(p)
# → {
#   "_mcp_type": "plot",
#   "format": "image/png",
#   "plot_type": "ggplot2",
#   "data": "iVBORw0KGgoAAAANS..."  # Base64 PNG
# }
```

### Custom Serializers

Register custom serializers for specific classes:

```r
# Register serializer for spatial data
register_mcp_serializer("sf", function(obj) {
  list(
    type = "geojson",
    data = sf::st_as_geojson(obj)
  )
})

# Now sf objects will use this serializer
spatial_data <- sf::st_point(c(1, 2))
to_mcp_json(spatial_data)  # Uses custom serializer
```

### Schema Validation

Validate R objects against JSON Schema:

```r
# Define schema
schema <- list(
  type = "object",
  properties = list(
    name = list(type = "string"),
    age = list(type = "number", minimum = 0)
  ),
  required = c("name")
)

# Validate object
validate_against_schema(
  list(name = "John", age = 30),
  schema
)  # Returns TRUE

validate_against_schema(
  list(age = -5),  # Missing name, negative age
  schema
)  # Throws error
```

### Streaming Large Data

Stream large data frames in chunks:

```r
large_df <- data.frame(x = 1:10000, y = rnorm(10000))

stream_dataframe(large_df, chunk_size = 1000, callback = function(chunk) {
  # Process each chunk
  cat("Processing rows", chunk$start_row, "to", chunk$end_row, "\n")
  # Send chunk$data to client...
})
```

## Round-Trip Conversion

Most R objects can be serialized and then reconstructed:

```r
# Original object
original <- list(
  numbers = c(1, 2, Inf),
  date = Sys.Date(),
  factor = factor(c("a", "b")),
  matrix = matrix(1:4, 2, 2)
)

# Serialize and deserialize
json_str <- mcp_serialize(original)
reconstructed <- mcp_deserialize(json_str)

# Data is preserved (structure might differ slightly)
```

## Type Conversion Functions

### Main Functions

- `to_mcp_json(x, auto_unbox = TRUE, size_limit = 1e6, custom_serializers = list())` - Convert R to JSON-compatible format
- `from_mcp_json(json)` - Convert JSON back to R
- `mcp_serialize(x, pretty = FALSE, auto_unbox = TRUE)` - Serialize to JSON string
- `mcp_deserialize(json)` - Deserialize from JSON string
- `can_serialize(x)` - Check if object can be serialized

### Helper Functions

- `register_mcp_serializer(class_name, serializer_func)` - Register custom serializer
- `get_mcp_serializers()` - Get all registered serializers
- `validate_against_schema(value, schema)` - Validate against JSON Schema
- `stream_dataframe(df, chunk_size, callback)` - Stream large data frames

## Best Practices

1. **Handle Special Values**: Always consider NA, NaN, Inf when working with numeric data
2. **Size Limits**: Set appropriate size limits for your use case
3. **Custom Classes**: Register serializers for domain-specific classes
4. **Validation**: Use schemas to validate input data
5. **Streaming**: Use streaming for large datasets to manage memory

## Limitations

1. **Environments**: Cannot be serialized (replaced with markers)
2. **Functions**: Not directly serializable
3. **External pointers**: Cannot be serialized
4. **Circular references**: Not handled
5. **S4 objects**: Limited support, may not fully reconstruct

## Examples

### Example 1: API Response

```r
# Prepare API response
response <- list(
  status = "success",
  data = data.frame(
    id = 1:3,
    name = c("Alice", "Bob", "Charlie"),
    score = c(95.5, 87.3, 91.0)
  ),
  timestamp = Sys.time()
)

# Serialize for MCP
json_response <- mcp_serialize(response)
```

### Example 2: Statistical Results

```r
# Run analysis
model <- lm(mpg ~ wt + cyl, data = mtcars)
results <- summary(model)

# Convert results (S3 object) to JSON
json_results <- to_mcp_json(results)
```

### Example 3: Visualization

```r
library(ggplot2)

# Create plot
p <- ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
  geom_point() +
  theme_minimal()

# Convert to JSON with plot as PNG
plot_json <- to_mcp_json(p)
# Returns base64-encoded PNG image
```

## Troubleshooting

### Common Issues

1. **"Object too large"**: Increase `size_limit` or use streaming
2. **"Cannot serialize function"**: Functions need special handling
3. **"Invalid JSON"**: Check for circular references or unsupported types
4. **"Schema validation failed"**: Ensure data matches expected schema

### Debug Tips

```r
# Check if object can be serialized
can_serialize(my_object)

# Get detailed error
tryCatch(
  mcp_serialize(my_object),
  error = function(e) print(e)
)

# Inspect serialized structure
str(to_mcp_json(my_object))
```