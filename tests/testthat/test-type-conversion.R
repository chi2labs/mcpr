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