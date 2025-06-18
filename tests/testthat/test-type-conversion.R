test_that("Basic atomic types are converted correctly", {
  # NULL
  expect_null(to_mcp_json(NULL))
  
  # Single values (should be unboxed)
  expect_equal(to_mcp_json(42), jsonlite::unbox(42))
  expect_equal(to_mcp_json("hello"), jsonlite::unbox("hello"))
  expect_equal(to_mcp_json(TRUE), jsonlite::unbox(TRUE))
  
  # Vectors (should not be unboxed)
  expect_equal(to_mcp_json(1:5), 1:5)
  expect_equal(to_mcp_json(c("a", "b", "c")), c("a", "b", "c"))
  
  # Named vectors become lists
  named_vec <- c(a = 1, b = 2, c = 3)
  expect_equal(to_mcp_json(named_vec), as.list(named_vec))
})

test_that("Matrices are converted with metadata", {
  mat <- matrix(1:6, nrow = 2, ncol = 3)
  result <- to_mcp_json(mat)
  
  expect_equal(result$data, 1:6)
  expect_equal(result$dim, c(2, 3))
  expect_equal(result$`_mcp_type`, "matrix")
  
  # Named matrix
  mat2 <- matrix(1:4, nrow = 2, ncol = 2)
  rownames(mat2) <- c("r1", "r2")
  colnames(mat2) <- c("c1", "c2")
  result2 <- to_mcp_json(mat2)
  
  expect_equal(result2$dimnames[[1]], c("r1", "r2"))
  expect_equal(result2$dimnames[[2]], c("c1", "c2"))
})

test_that("Data frames are converted correctly", {
  df <- data.frame(
    x = 1:3,
    y = c("a", "b", "c"),
    z = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  
  result <- to_mcp_json(df)
  
  expect_equal(result$x, 1:3)
  expect_equal(result$y, c("a", "b", "c"))
  expect_equal(result$z, c(TRUE, FALSE, TRUE))
  expect_equal(attr(result, "_mcp_type"), "data.frame")
  expect_equal(attr(result, "_mcp_nrow"), 3)
})

test_that("Factors are converted with levels", {
  f <- factor(c("a", "b", "a", "c"), levels = c("a", "b", "c"))
  result <- to_mcp_json(f)
  
  expect_true(is.list(result))
  expect_equal(result$`_mcp_type`, "factor")
  expect_equal(result$levels, c("a", "b", "c"))
  expect_equal(result$values, c(1, 2, 1, 3))
})

test_that("Lists are recursively converted", {
  lst <- list(
    a = 1:3,
    b = list(x = "hello", y = TRUE),
    c = data.frame(p = 1:2, q = c("a", "b"))
  )
  
  result <- to_mcp_json(lst)
  
  expect_equal(result$a, 1:3)
  expect_equal(result$b$x, jsonlite::unbox("hello"))
  expect_equal(result$b$y, jsonlite::unbox(TRUE))
  expect_equal(attr(result$c, "_mcp_type"), "data.frame")
})

test_that("S3 objects are handled", {
  # Create a simple S3 object
  obj <- structure(list(x = 1, y = 2), class = "myclass")
  result <- to_mcp_json(obj)
  
  # Check that result has the expected structure  
  expect_true(is.list(result))
  expect_equal(result$x, jsonlite::unbox(1))
  expect_equal(result$y, jsonlite::unbox(2))
  
  # S3 class info should be preserved as attributes
  expect_equal(attr(result, "_mcp_type"), "S3")
  expect_equal(attr(result, "_mcp_class"), "myclass")
})

test_that("from_mcp_json reconstructs objects", {
  # Simple values
  expect_equal(from_mcp_json('42'), 42)
  expect_equal(from_mcp_json('"hello"'), "hello")
  expect_equal(from_mcp_json('[1, 2, 3]'), list(1, 2, 3))
  
  # Objects
  json_obj <- '{"a": 1, "b": ["x", "y"]}'
  result <- from_mcp_json(json_obj)
  expect_equal(result$a, 1)
  expect_equal(result$b, list("x", "y"))
})

test_that("Round-trip conversion works for data frames", {
  df <- data.frame(
    x = 1:3,
    y = letters[1:3],
    z = c(1.1, 2.2, 3.3),
    stringsAsFactors = FALSE
  )
  
  # Convert to JSON and back
  json_str <- mcp_serialize(df)
  reconstructed <- mcp_deserialize(json_str)
  
  # The structure might be slightly different but data should be same
  expect_true(is.list(reconstructed))
  expect_equal(reconstructed$x, as.list(1:3))
  expect_equal(reconstructed$y, as.list(letters[1:3]))
})

test_that("mcp_serialize produces valid JSON", {
  # Various R objects
  objects <- list(
    null = NULL,
    number = 42,
    string = "hello",
    vector = 1:5,
    list = list(a = 1, b = "x"),
    dataframe = data.frame(x = 1:3, y = letters[1:3])
  )
  
  for (name in names(objects)) {
    json_str <- mcp_serialize(objects[[name]])
    expect_type(json_str, "character")
    expect_length(json_str, 1)
    
    # Should be valid JSON
    expect_error(jsonlite::fromJSON(json_str), NA)
  }
})

test_that("can_serialize correctly identifies serializable objects", {
  # Should be serializable
  expect_true(can_serialize(42))
  expect_true(can_serialize("hello"))
  expect_true(can_serialize(list(a = 1, b = 2)))
  expect_true(can_serialize(data.frame(x = 1:3)))
  
  # Complex objects that should still work
  expect_true(can_serialize(matrix(1:6, 2, 3)))
  expect_true(can_serialize(factor(letters[1:3])))
})

test_that("auto_unbox parameter works correctly", {
  # With auto_unbox = TRUE (default)
  expect_equal(to_mcp_json(42, auto_unbox = TRUE), jsonlite::unbox(42))
  expect_equal(to_mcp_json(list(a = 1), auto_unbox = TRUE)$a, jsonlite::unbox(1))
  
  # With auto_unbox = FALSE
  expect_equal(to_mcp_json(42, auto_unbox = FALSE), 42)
  expect_equal(to_mcp_json(list(a = 1), auto_unbox = FALSE)$a, 1)
})

test_that("Arrays are handled correctly", {
  arr <- array(1:24, dim = c(2, 3, 4))
  result <- to_mcp_json(arr)
  
  expect_equal(result$`_mcp_type`, "array")
  expect_equal(result$data, 1:24)
  expect_equal(result$dim, c(2, 3, 4))
  
  # Test reconstruction through full cycle
  json_str <- mcp_serialize(arr)
  reconstructed <- mcp_deserialize(json_str)
  
  # Should be reconstructed as an array
  expect_true(is.array(reconstructed))
  expect_equal(dim(reconstructed), c(2, 3, 4))
  
  # Compare the actual data
  expect_equal(reconstructed[,,], arr[,,])
})

test_that("Special numeric values are handled correctly", {
  # Single special values
  expect_equal(to_mcp_json(Inf)$value, jsonlite::unbox("Inf"))
  expect_equal(to_mcp_json(-Inf)$value, jsonlite::unbox("-Inf"))
  expect_equal(to_mcp_json(NaN)$value, jsonlite::unbox("NaN"))
  
  # Vector with special values
  vec <- c(1, Inf, -Inf, NaN, 5)
  result <- to_mcp_json(vec)
  expect_equal(result$`_mcp_type`, "numeric_vector_special")
  expect_equal(result$special_indices, c(2, 3, 4))
  
  # Round trip
  json_str <- mcp_serialize(vec)
  reconstructed <- mcp_deserialize(json_str)
  expect_true(is.infinite(reconstructed[[2]]) && reconstructed[[2]] > 0)
  expect_true(is.infinite(reconstructed[[3]]) && reconstructed[[3]] < 0)
  expect_true(is.nan(reconstructed[[4]]))
})

test_that("Date objects are converted correctly", {
  # Single date
  date1 <- as.Date("2024-01-15")
  result <- to_mcp_json(date1)
  expect_equal(result$`_mcp_type`, "Date")
  expect_equal(result$values, "2024-01-15")
  
  # Date vector
  dates <- as.Date(c("2024-01-15", "2024-02-20", "2024-03-25"))
  result <- to_mcp_json(dates)
  expect_equal(result$values, c("2024-01-15", "2024-02-20", "2024-03-25"))
  
  # Round trip
  json_str <- mcp_serialize(dates)
  reconstructed <- mcp_deserialize(json_str)
  expect_true(inherits(reconstructed, "Date"))
  expect_equal(reconstructed, dates)
})

test_that("POSIXct datetime objects are converted correctly", {
  # Create POSIXct with specific timezone
  dt1 <- as.POSIXct("2024-01-15 14:30:00", tz = "America/New_York")
  result <- to_mcp_json(dt1)
  expect_equal(result$`_mcp_type`, "POSIXct")
  expect_true(!is.null(result$timezone))
  
  # POSIXlt should be converted to POSIXct
  dt2 <- as.POSIXlt("2024-01-15 14:30:00", tz = "UTC")
  result2 <- to_mcp_json(dt2)
  expect_equal(result2$`_mcp_type`, "POSIXct")
  
  # Round trip
  json_str <- mcp_serialize(dt1)
  reconstructed <- mcp_deserialize(json_str)
  expect_true(inherits(reconstructed, "POSIXct"))
})

test_that("Complex numbers are handled correctly", {
  # Single complex number
  z1 <- 3 + 4i
  result <- to_mcp_json(z1)
  expect_equal(result$`_mcp_type`, "complex")
  expect_equal(result$real, jsonlite::unbox(3))
  expect_equal(result$imaginary, jsonlite::unbox(4))
  
  # Complex vector
  z_vec <- c(1+2i, 3-4i, 0+1i)
  result <- to_mcp_json(z_vec)
  expect_equal(result$real, c(1, 3, 0))
  expect_equal(result$imaginary, c(2, -4, 1))
  
  # Round trip
  json_str <- mcp_serialize(z_vec)
  reconstructed <- mcp_deserialize(json_str)
  expect_equal(reconstructed, z_vec)
})

test_that("Raw vectors are converted correctly", {
  # Create raw vector
  raw_vec <- as.raw(c(0x48, 0x65, 0x6c, 0x6c, 0x6f))  # "Hello" in hex
  result <- to_mcp_json(raw_vec)
  expect_equal(result$`_mcp_type`, "raw")
  expect_true(!is.null(result$data))  # Should be base64 encoded
  
  # Round trip
  json_str <- mcp_serialize(raw_vec)
  reconstructed <- mcp_deserialize(json_str)
  expect_equal(reconstructed, raw_vec)
})

test_that("Formulas are handled correctly", {
  # Simple formula
  f1 <- y ~ x + z
  result <- to_mcp_json(f1)
  expect_true(identical(as.character(result$`_mcp_type`), "formula"))
  expect_true(grepl("y ~ x \\+ z", result$formula))
  
  # Formula with interactions
  f2 <- y ~ x * z + I(x^2)
  result2 <- to_mcp_json(f2)
  expect_true(!is.null(result2$formula))
  
  # Round trip
  json_str <- mcp_serialize(f1)
  reconstructed <- mcp_deserialize(json_str)
  expect_true(inherits(reconstructed, "formula"))
  expect_equal(deparse(reconstructed), deparse(f1))
})

test_that("Language objects are handled correctly", {
  # Expression
  expr <- quote(x + y * z)
  result <- to_mcp_json(expr)
  expect_true(identical(as.character(result$`_mcp_type`), "language"))
  expect_true(identical(as.character(result$type), "language"))
  
  # Call
  call_obj <- quote(mean(x, na.rm = TRUE))
  result2 <- to_mcp_json(call_obj)
  expect_true(identical(as.character(result2$`_mcp_type`), "language"))
  
  # Round trip
  json_str <- mcp_serialize(expr)
  reconstructed <- mcp_deserialize(json_str)
  expect_equal(deparse(reconstructed), deparse(expr))
})

test_that("Environments are handled with markers", {
  # Global environment
  result <- to_mcp_json(globalenv())
  expect_true(identical(as.character(result$`_mcp_type`), "environment"))
  expect_true(!is.null(result$name))
  
  # Custom environment
  env <- new.env()
  result2 <- to_mcp_json(env)
  expect_true(identical(as.character(result2$`_mcp_type`), "environment"))
  
  # Round trip returns marker
  json_str <- mcp_serialize(env)
  reconstructed <- mcp_deserialize(json_str)
  expect_true(inherits(reconstructed, "mcp_environment_marker"))
})

test_that("Mixed data frames with special types work", {
  # Data frame with dates and special values
  df <- data.frame(
    date = as.Date(c("2024-01-01", "2024-01-02")),
    value = c(1.5, Inf),
    category = factor(c("A", "B")),
    stringsAsFactors = FALSE
  )
  
  json_str <- mcp_serialize(df)
  expect_type(json_str, "character")
  
  # The reconstruction might not perfectly preserve the data frame structure
  # due to how special types are handled, but the data should be recoverable
  reconstructed <- mcp_deserialize(json_str)
  expect_true(is.list(reconstructed))
})

test_that("Large object handling works correctly", {
  # Create a large object
  large_df <- data.frame(
    x = 1:10000,
    y = rnorm(10000),
    z = sample(letters, 10000, replace = TRUE)
  )
  
  # Convert with size limit
  result <- to_mcp_json(large_df, size_limit = 1000)
  
  expect_equal(result$`_mcp_type`, "large_object")
  expect_equal(result$class, "data.frame")
  expect_true(result$size > 1000)
  expect_true(!is.null(result$size_human))
  expect_true(!is.null(result$summary))
  expect_true(!is.null(result$preview))
  expect_equal(result$preview$nrow, 10000)
  expect_equal(result$preview$ncol, 3)
  expect_equal(length(result$preview$head[[1]]), 5)  # Should have 5 rows in preview
})

test_that("Custom serializers work correctly", {
  # Register a custom serializer
  register_mcp_serializer("myclass", function(obj) {
    list(
      `_mcp_type` = "custom_myclass",
      data = obj$data,
      metadata = obj$metadata
    )
  })
  
  # Create object with custom class
  obj <- structure(
    list(data = 1:5, metadata = "test"),
    class = "myclass"
  )
  
  # Convert using custom serializer
  result <- to_mcp_json(obj, custom_serializers = get_mcp_serializers())
  
  expect_equal(result$`_mcp_type`, "custom_myclass")
  expect_equal(result$data, 1:5)
  expect_equal(result$metadata, "test")
  
  # Clean up
  .mcp_custom_serializers$myclass <- NULL
})

test_that("Plot conversion works for ggplot2", {
  skip_if_not_installed("ggplot2")
  
  # Create a simple ggplot
  library(ggplot2)
  p <- ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point()
  
  result <- to_mcp_json(p)
  
  expect_equal(result$`_mcp_type`, "plot")
  expect_equal(result$format, "image/png")
  expect_equal(result$plot_type, "ggplot2")
  expect_true(!is.null(result$data))  # Should have base64 data
  expect_true(nchar(result$data) > 100)  # Should be non-trivial
})

test_that("Schema validation works correctly", {
  # Valid cases
  expect_true(validate_against_schema(42, list(type = "number")))
  expect_true(validate_against_schema("hello", list(type = "string")))
  expect_true(validate_against_schema(c(1, 2, 3), list(type = "array")))
  expect_true(validate_against_schema(list(a = 1), list(type = "object")))
  
  # Invalid cases
  expect_error(validate_against_schema("hello", list(type = "number")))
  expect_error(validate_against_schema(42, list(type = "string")))
  
  # Array with items validation
  schema <- list(
    type = "array",
    items = list(type = "number")
  )
  expect_true(validate_against_schema(c(1, 2, 3), schema))
  expect_error(validate_against_schema(c("a", "b"), schema))
  
  # Object with properties
  schema <- list(
    type = "object",
    properties = list(
      name = list(type = "string"),
      age = list(type = "number")
    ),
    required = c("name")
  )
  expect_true(validate_against_schema(list(name = "John", age = 30), schema))
  expect_error(validate_against_schema(list(age = 30), schema))  # Missing required
  
  # Enum validation
  schema <- list(type = "string", enum = c("red", "green", "blue"))
  expect_true(validate_against_schema("red", schema))
  expect_error(validate_against_schema("yellow", schema))
})

test_that("Data frame streaming works correctly", {
  df <- data.frame(
    x = 1:100,
    y = rnorm(100)
  )
  
  chunks <- list()
  stream_dataframe(df, chunk_size = 30, callback = function(chunk) {
    chunks <<- append(chunks, list(chunk))
  })
  
  expect_equal(length(chunks), 4)  # 100 rows / 30 per chunk = 4 chunks
  expect_equal(chunks[[1]]$chunk, 1)
  expect_equal(chunks[[1]]$total_chunks, 4)
  expect_equal(chunks[[1]]$start_row, 1)
  expect_equal(chunks[[1]]$end_row, 30)
  expect_equal(length(chunks[[1]]$data[[1]]), 30)
  
  # Last chunk should have only 10 rows
  expect_equal(chunks[[4]]$start_row, 91)
  expect_equal(chunks[[4]]$end_row, 100)
  expect_equal(length(chunks[[4]]$data[[1]]), 10)
})

test_that("Plot markers are created for reconstruction", {
  skip_if_not_installed("ggplot2")
  
  library(ggplot2)
  p <- ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point()
  
  json_str <- mcp_serialize(p)
  reconstructed <- mcp_deserialize(json_str)
  
  # The plot object is nested in the reconstructed list
  plot_obj <- if (inherits(reconstructed, "mcp_plot_marker")) {
    reconstructed
  } else {
    reconstructed[[1]]  # If it's wrapped in a list
  }
  
  expect_true(inherits(plot_obj, "mcp_plot_marker"))
  expect_equal(plot_obj$format[[1]], "image/png")
  expect_equal(plot_obj$plot_type[[1]], "ggplot2")
  expect_true(!is.null(plot_obj$data[[1]]))
})

test_that("Large object markers are created for reconstruction", {
  large_vec <- 1:100000
  
  json_str <- mcp_serialize(large_vec, auto_unbox = FALSE)
  json_obj <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)
  
  # Manually create large object for testing reconstruction
  large_obj_json <- list(
    `_mcp_type` = "large_object",
    class = "integer",
    size = 400000,
    summary = c("Min: 1", "Max: 100000")
  )
  
  reconstructed <- from_mcp_json(large_obj_json)
  expect_true(inherits(reconstructed, "mcp_large_object_marker"))
})