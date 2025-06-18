#' Convert R objects to JSON-compatible format for MCP
#'
#' Converts various R objects to a JSON-compatible format, preserving type
#' information where possible. Handles special types like dates, factors,
#' matrices, and special numeric values (Inf, -Inf, NaN).
#'
#' @param x An R object to convert
#' @param auto_unbox Whether to automatically unbox single-element vectors
#' @param size_limit Maximum object size in bytes before using large object handling (default: 1MB)
#' @param custom_serializers List of custom serializers for specific classes
#' @return A JSON-compatible representation of the R object
#' @importFrom utils object.size capture.output head
#' @importFrom grDevices png dev.off replayPlot
#' @importFrom methods slotNames slot
#' @importFrom stats as.formula
#' 
#' @details
#' The function handles the following R types:
#' \itemize{
#'   \item Basic types: NULL, logical, numeric, character, integer
#'   \item Special numeric values: Inf, -Inf, NaN
#'   \item Date/time types: Date, POSIXct, POSIXlt
#'   \item Complex numbers
#'   \item Raw vectors (binary data)
#'   \item Factors (with levels preserved)
#'   \item Matrices and arrays (with dimensions)
#'   \item Data frames
#'   \item Lists (recursive conversion)
#'   \item S3 and S4 objects
#'   \item Formulas and language objects
#'   \item Environments (replaced with markers)
#' }
#' 
#' @export
#' @examples
#' # Basic types
#' to_mcp_json(list(a = 1, b = "hello"))
#' to_mcp_json(c(TRUE, FALSE, NA))
#' 
#' # Special numeric values
#' to_mcp_json(c(1, Inf, -Inf, NaN))
#' 
#' # Dates and times
#' to_mcp_json(Sys.Date())
#' to_mcp_json(Sys.time())
#' 
#' # Data frames
#' to_mcp_json(data.frame(x = 1:3, y = letters[1:3]))
#' 
#' # Complex types
#' to_mcp_json(matrix(1:6, nrow = 2))
#' to_mcp_json(factor(c("a", "b", "a")))
#' to_mcp_json(3 + 4i)
to_mcp_json <- function(x, auto_unbox = TRUE, size_limit = 1e6, custom_serializers = list()) {
  # Handle NULL
  if (is.null(x)) {
    return(NULL)
  }
  
  # Check for custom serializers first
  obj_class <- class(x)[1]
  if (obj_class %in% names(custom_serializers)) {
    return(custom_serializers[[obj_class]](x))
  }
  
  # Check object size for large object handling
  obj_size <- object.size(x)
  if (obj_size > size_limit) {
    return(list(
      `_mcp_type` = "large_object",
      class = class(x),
      size = as.numeric(obj_size),
      size_human = format(obj_size, units = "auto"),
      summary = capture.output(summary(x)),
      preview = if (is.data.frame(x)) {
        list(
          nrow = nrow(x),
          ncol = ncol(x),
          columns = names(x),
          head = to_mcp_json(head(x, 5), auto_unbox = auto_unbox, size_limit = Inf)
        )
      } else if (is.atomic(x)) {
        list(
          length = length(x),
          type = typeof(x),
          head = head(x, 100)
        )
      } else {
        NULL
      }
    ))
  }
  
  # Handle special numeric values
  if (is.atomic(x) && is.numeric(x)) {
    # Check for special values
    if (any(is.infinite(x) | is.nan(x), na.rm = TRUE)) {
      # Convert special values to strings for JSON compatibility
      x_converted <- x
      x_converted[is.infinite(x) & x > 0] <- "Inf"
      x_converted[is.infinite(x) & x < 0] <- "-Inf"
      x_converted[is.nan(x)] <- "NaN"
      x_converted[is.na(x) & !is.nan(x)] <- NA
      
      # If it's a single value, return with type marker
      if (length(x) == 1) {
        return(list(
          value = if (auto_unbox) jsonlite::unbox(x_converted) else x_converted,
          `_mcp_type` = "special_numeric"
        ))
      }
      # For vectors, include original indices of special values
      return(list(
        values = x_converted,
        special_indices = which(is.infinite(x) | is.nan(x)),
        `_mcp_type` = "numeric_vector_special"
      ))
    }
  }
  
  # Handle Date objects
  if (inherits(x, "Date")) {
    return(list(
      values = format(x, "%Y-%m-%d"),
      `_mcp_type` = "Date"
    ))
  }
  
  # Handle POSIXct/POSIXlt datetime objects
  if (inherits(x, "POSIXt")) {
    # Convert POSIXlt to POSIXct for consistency
    if (inherits(x, "POSIXlt")) {
      x <- as.POSIXct(x)
    }
    return(list(
      values = format(x, "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
      timezone = attr(x, "tzone") %||% "UTC",
      `_mcp_type` = "POSIXct"
    ))
  }
  
  # Handle complex numbers
  if (is.complex(x)) {
    return(list(
      real = Re(x),
      imaginary = Im(x),
      `_mcp_type` = "complex"
    ))
  }
  
  # Handle raw vectors
  if (is.raw(x)) {
    # Convert to base64 for JSON compatibility
    return(list(
      data = jsonlite::base64_enc(x),
      `_mcp_type` = "raw"
    ))
  }
  
  # Handle formulas
  if (inherits(x, "formula")) {
    formula_str <- deparse(x)
    if (length(formula_str) == 1 && auto_unbox) {
      formula_str <- jsonlite::unbox(formula_str)
    }
    return(list(
      formula = formula_str,
      environment = jsonlite::unbox(if (!identical(environment(x), globalenv())) "<non-global>" else "global"),
      `_mcp_type` = jsonlite::unbox("formula")
    ))
  }
  
  # Handle language objects (expressions, calls, symbols)
  if (is.language(x)) {
    # For single-line expressions, unbox the string
    expr_str <- deparse(x)
    if (length(expr_str) == 1 && auto_unbox) {
      expr_str <- jsonlite::unbox(expr_str)
    }
    return(list(
      expression = expr_str,
      type = jsonlite::unbox(typeof(x)),
      `_mcp_type` = jsonlite::unbox("language")
    ))
  }
  
  # Handle environments (just return a marker, don't serialize contents)
  if (is.environment(x)) {
    env_name <- environmentName(x)
    if (env_name == "") {
      env_name <- capture.output(print(x))[1]
    }
    return(list(
      name = jsonlite::unbox(env_name),
      `_mcp_type` = jsonlite::unbox("environment")
    ))
  }
  
  # Handle plots
  if (inherits(x, "gg") || inherits(x, "ggplot")) {
    # ggplot2 plots
    if (requireNamespace("ggplot2", quietly = TRUE)) {
      tmp <- tempfile(fileext = ".png")
      on.exit(unlink(tmp), add = TRUE)
      
      requireNamespace("ggplot2", quietly = TRUE)
      ggplot2::ggsave(tmp, x, width = 8, height = 6, dpi = 150)
      
      return(list(
        `_mcp_type` = "plot",
        format = "image/png",
        plot_type = "ggplot2",
        data = jsonlite::base64_enc(readBin(tmp, "raw", file.info(tmp)$size))
      ))
    }
  }
  
  # Handle base R recorded plots
  if (inherits(x, "recordedplot")) {
    tmp <- tempfile(fileext = ".png")
    on.exit(unlink(tmp), add = TRUE)
    
    png(tmp, width = 800, height = 600)
    replayPlot(x)
    dev.off()
    
    return(list(
      `_mcp_type` = "plot",
      format = "image/png", 
      plot_type = "base_r",
      data = jsonlite::base64_enc(readBin(tmp, "raw", file.info(tmp)$size))
    ))
  }
  
  # Handle factors (moved after special type checks)
  if (is.factor(x)) {
    return(list(
      levels = levels(x),
      values = as.integer(x),
      `_mcp_type` = "factor"
    ))
  }
  
  # Handle basic atomic types
  if (is.atomic(x) && !is.array(x) && !is.matrix(x)) {
    # Preserve names if they exist
    if (!is.null(names(x))) {
      return(as.list(x))
    }
    # Single values should be unboxed
    if (length(x) == 1 && auto_unbox) {
      return(jsonlite::unbox(x))
    }
    return(x)
  }
  
  # Handle matrices and arrays
  if (is.matrix(x) || is.array(x)) {
    # Convert to list with dimension information
    result <- list(
      data = as.vector(x),
      dim = dim(x),
      dimnames = dimnames(x),
      `_mcp_type` = if (is.matrix(x)) "matrix" else "array"
    )
    return(result)
  }
  
  # Handle data frames
  if (is.data.frame(x)) {
    # Convert to list of columns
    result <- as.list(x)
    # Add metadata
    attr(result, "_mcp_type") <- "data.frame"
    attr(result, "_mcp_nrow") <- nrow(x)
    return(result)
  }
  
  
  # Handle S3/S4 objects before generic lists
  if (is.object(x)) {
    # Try to convert to list representation
    if (isS4(x)) {
      # S4 objects
      slots <- slotNames(x)
      result <- list(`_mcp_type` = "S4", `_mcp_class` = class(x))
      for (slot in slots) {
        result[[slot]] <- to_mcp_json(methods::slot(x, slot), auto_unbox = auto_unbox, size_limit = size_limit, custom_serializers = custom_serializers)
      }
      return(result)
    } else {
      # S3 objects - convert to list and preserve class
      result <- unclass(x)
      if (is.list(result)) {
        # Use a loop to preserve attributes
        converted <- list()
        for (i in seq_along(result)) {
          converted[[names(result)[i]]] <- to_mcp_json(result[[i]], auto_unbox = auto_unbox, size_limit = size_limit, custom_serializers = custom_serializers)
        }
        result <- converted
      } else {
        result <- to_mcp_json(result, auto_unbox = auto_unbox, size_limit = size_limit, custom_serializers = custom_serializers)
      }
      attr(result, "_mcp_type") <- "S3"
      attr(result, "_mcp_class") <- class(x)
      return(result)
    }
  }
  
  # Handle lists (after checking for S3/S4 objects)
  if (is.list(x)) {
    # Recursively convert list elements
    result <- lapply(x, to_mcp_json, auto_unbox = auto_unbox, size_limit = size_limit, custom_serializers = custom_serializers)
    return(result)
  }
  
  # Default: return as-is and hope jsonlite can handle it
  return(x)
}

#' Convert JSON data back to R objects
#'
#' Reconstructs R objects from JSON data that was created with \code{to_mcp_json}.
#' Preserves type information including dates, factors, matrices, and other
#' special R types.
#'
#' @param json JSON string or already parsed JSON data
#' @return An R object reconstructed from the JSON data
#' 
#' @details
#' This function reverses the conversion done by \code{to_mcp_json}, reconstructing:
#' \itemize{
#'   \item Special numeric values (Inf, -Inf, NaN)
#'   \item Date and POSIXct objects with timezones
#'   \item Factors with original levels
#'   \item Matrices and arrays with dimensions
#'   \item Data frames
#'   \item S3 objects with class information
#'   \item Complex numbers
#'   \item Raw vectors from base64
#'   \item Formulas and language objects
#' }
#' 
#' Note: Environments cannot be reconstructed and are replaced with marker objects.
#' 
#' @export
#' @examples
#' # Simple JSON string
#' json_str <- '{"a": 1, "b": ["hello", "world"]}'
#' from_mcp_json(json_str)
#' 
#' # Round-trip conversion
#' original <- list(
#'   date = Sys.Date(),
#'   values = c(1, 2, Inf),
#'   factor = factor(c("a", "b", "a"))
#' )
#' json <- mcp_serialize(original)
#' reconstructed <- from_mcp_json(json)
from_mcp_json <- function(json) {
  # If it's a string, parse it first
  if (is.character(json) && length(json) == 1) {
    x <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  } else {
    x <- json
  }
  
  # Recursive function to reconstruct R objects
  reconstruct <- function(obj) {
    if (is.null(obj)) {
      return(NULL)
    }
    
    # Check for MCP type markers
    if (is.list(obj)) {
      mcp_type <- obj[["_mcp_type"]]
      
      if (!is.null(mcp_type)) {
        if (mcp_type == "matrix") {
          # Reconstruct matrix
          data <- if (is.list(obj$data)) unlist(obj$data) else obj$data
          dims <- if (is.list(obj$dim)) unlist(obj$dim) else obj$dim
          mat <- matrix(data, nrow = dims[1], ncol = dims[2])
          if (!is.null(obj$dimnames)) {
            dimnames(mat) <- obj$dimnames
          }
          return(mat)
        } else if (mcp_type == "array") {
          # Reconstruct array
          data <- if (is.list(obj$data)) unlist(obj$data) else obj$data
          dims <- if (is.list(obj$dim)) unlist(obj$dim) else obj$dim
          arr <- array(data, dim = dims)
          if (!is.null(obj$dimnames)) {
            dimnames(arr) <- obj$dimnames
          }
          return(arr)
        } else if (mcp_type == "factor") {
          # Reconstruct factor
          return(factor(obj$values, levels = obj$levels))
        } else if (mcp_type == "data.frame") {
          # Reconstruct data frame
          obj[["_mcp_type"]] <- NULL
          obj[["_mcp_nrow"]] <- NULL
          df <- as.data.frame(lapply(obj, reconstruct))
          return(df)
        } else if (mcp_type == "S3") {
          # Reconstruct S3 object
          mcp_class <- obj[["_mcp_class"]]
          obj[["_mcp_type"]] <- NULL
          obj[["_mcp_class"]] <- NULL
          result <- lapply(obj, reconstruct)
          class(result) <- mcp_class
          return(result)
        } else if (mcp_type == "S4") {
          # S4 reconstruction is more complex and may not always work
          # For now, return as list with class info
          return(obj)
        } else if (mcp_type == "special_numeric") {
          # Reconstruct special numeric value
          val <- obj$value
          if (identical(val, "Inf")) return(Inf)
          if (identical(val, "-Inf")) return(-Inf)
          if (identical(val, "NaN")) return(NaN)
          return(as.numeric(val))
        } else if (mcp_type == "numeric_vector_special") {
          # Reconstruct numeric vector with special values
          values <- obj$values
          result <- numeric(length(values))
          for (i in seq_along(values)) {
            if (is.null(values[[i]])) {
              result[i] <- NA
            } else if (identical(values[[i]], "Inf")) {
              result[i] <- Inf
            } else if (identical(values[[i]], "-Inf")) {
              result[i] <- -Inf
            } else if (identical(values[[i]], "NaN")) {
              result[i] <- NaN
            } else {
              result[i] <- as.numeric(values[[i]])
            }
          }
          return(result)
        } else if (mcp_type == "Date") {
          # Reconstruct Date objects
          values <- if (is.list(obj$values)) unlist(obj$values) else obj$values
          return(as.Date(values))
        } else if (mcp_type == "POSIXct") {
          # Reconstruct POSIXct objects
          values <- if (is.list(obj$values)) unlist(obj$values) else obj$values
          result <- as.POSIXct(values, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
          if (!is.null(obj$timezone) && obj$timezone != "UTC") {
            attr(result, "tzone") <- obj$timezone
          }
          return(result)
        } else if (mcp_type == "complex") {
          # Reconstruct complex numbers
          return(complex(real = obj$real, imaginary = obj$imaginary))
        } else if (mcp_type == "raw") {
          # Reconstruct raw vectors from base64
          data <- if (is.list(obj$data)) obj$data[[1]] else obj$data
          return(jsonlite::base64_dec(data))
        } else if (mcp_type == "formula") {
          # Reconstruct formula
          formula_str <- if (is.list(obj$formula)) obj$formula[[1]] else obj$formula
          return(as.formula(formula_str))
        } else if (mcp_type == "language") {
          # Reconstruct language objects
          return(parse(text = obj$expression)[[1]])
        } else if (mcp_type == "environment") {
          # Can't reconstruct environments - return a marker
          return(structure(list(name = obj$name), class = "mcp_environment_marker"))
        } else if (mcp_type == "plot") {
          # Can't reconstruct plots - return a marker with the image data
          return(structure(list(
            format = obj$format,
            plot_type = obj$plot_type,
            data = obj$data
          ), class = "mcp_plot_marker"))
        } else if (mcp_type == "large_object") {
          # Can't reconstruct large objects - return the summary
          return(structure(obj, class = "mcp_large_object_marker"))
        }
      }
      
      # Regular list - recursively process elements
      return(lapply(obj, reconstruct))
    }
    
    # Return as-is
    return(obj)
  }
  
  reconstruct(x)
}

#' Serialize R object to JSON string for MCP
#'
#' @param x An R object to serialize
#' @param pretty Whether to pretty-print the JSON
#' @param auto_unbox Whether to automatically unbox single-element vectors
#' @return A JSON string representation of the R object
#' @export
#' @examples
#' mcp_serialize(list(result = 42, message = "success"))
mcp_serialize <- function(x, pretty = FALSE, auto_unbox = TRUE) {
  # Convert to MCP-compatible format
  mcp_obj <- to_mcp_json(x, auto_unbox = auto_unbox, custom_serializers = get_mcp_serializers())
  
  # Serialize to JSON
  jsonlite::toJSON(
    mcp_obj,
    pretty = pretty,
    auto_unbox = FALSE,  # We handle unboxing in to_mcp_json
    null = "null",
    na = "null"
  )
}

#' Deserialize JSON string to R object from MCP
#'
#' @param json A JSON string to deserialize
#' @return An R object
#' @export
#' @examples
#' mcp_deserialize('{"result": 42, "message": "success"}')
mcp_deserialize <- function(json) {
  from_mcp_json(json)
}

#' Check if an R object can be safely serialized to JSON
#'
#' @param x An R object to check
#' @return TRUE if the object can be serialized, FALSE otherwise
#' @export
can_serialize <- function(x) {
  tryCatch({
    mcp_serialize(x)
    TRUE
  }, error = function(e) {
    FALSE
  })
}

#' Global registry for custom serializers
#' @keywords internal
.mcp_custom_serializers <- new.env(parent = emptyenv())

#' Register a custom serializer for a specific class
#'
#' @param class_name Character, name of the R class
#' @param serializer_func Function that takes an object and returns JSON-compatible representation
#' @export
#' @examples
#' # Register a custom serializer for spatial data
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   register_mcp_serializer("sf", function(obj) {
#'     list(
#'       type = "geojson",
#'       data = sf::st_as_geojson(obj)
#'     )
#'   })
#' }
register_mcp_serializer <- function(class_name, serializer_func) {
  .mcp_custom_serializers[[class_name]] <- serializer_func
}

#' Get all registered custom serializers
#' @return List of custom serializers
#' @export
get_mcp_serializers <- function() {
  as.list(.mcp_custom_serializers)
}

#' Validate R object against JSON schema
#'
#' @param value R object to validate
#' @param schema JSON schema definition
#' @return TRUE if valid, error otherwise
#' @export
validate_against_schema <- function(value, schema) {
  if (is.null(schema$type)) return(TRUE)
  
  valid <- switch(schema$type,
    "array" = is.vector(value) || is.list(value),
    "object" = is.list(value) && !is.null(names(value)),
    "string" = is.character(value),
    "number" = is.numeric(value),
    "integer" = is.integer(value) || (is.numeric(value) && all(value == as.integer(value), na.rm = TRUE)),
    "boolean" = is.logical(value),
    "null" = is.null(value),
    TRUE
  )
  
  if (!valid) {
    stop(sprintf("Value does not match schema type '%s'", schema$type))
  }
  
  # Additional validation for arrays
  if (schema$type == "array" && !is.null(schema$items)) {
    lapply(value, function(item) {
      validate_against_schema(item, schema$items)
    })
  }
  
  # Additional validation for objects
  if (schema$type == "object" && !is.null(schema$properties)) {
    for (prop in names(schema$properties)) {
      if (prop %in% names(value)) {
        validate_against_schema(value[[prop]], schema$properties[[prop]])
      } else if (!is.null(schema$required) && prop %in% schema$required) {
        stop(sprintf("Required property '%s' is missing", prop))
      }
    }
  }
  
  # Enum validation
  if (!is.null(schema$enum)) {
    if (!value %in% schema$enum) {
      stop(sprintf("Value '%s' is not in allowed enum values", value))
    }
  }
  
  TRUE
}

#' Create a streaming converter for large data frames
#'
#' @param df Data frame to stream
#' @param chunk_size Number of rows per chunk
#' @param callback Function to call with each chunk
#' @export
stream_dataframe <- function(df, chunk_size = 1000, callback) {
  n_rows <- nrow(df)
  n_chunks <- ceiling(n_rows / chunk_size)
  
  for (i in seq_len(n_chunks)) {
    start_row <- (i - 1) * chunk_size + 1
    end_row <- min(i * chunk_size, n_rows)
    
    chunk <- df[start_row:end_row, , drop = FALSE]
    chunk_json <- to_mcp_json(chunk, size_limit = Inf)
    
    callback(list(
      chunk = i,
      total_chunks = n_chunks,
      start_row = start_row,
      end_row = end_row,
      data = chunk_json
    ))
  }
}