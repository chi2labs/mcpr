#' Convert R objects to JSON-compatible format for MCP
#'
#' @param x An R object to convert
#' @param auto_unbox Whether to automatically unbox single-element vectors
#' @return A JSON-compatible representation of the R object
#' @export
#' @examples
#' to_mcp_json(list(a = 1, b = "hello"))
#' to_mcp_json(data.frame(x = 1:3, y = letters[1:3]))
to_mcp_json <- function(x, auto_unbox = TRUE) {
  # Handle NULL
  if (is.null(x)) {
    return(NULL)
  }
  
  # Handle factors first (before atomic check since factors are atomic)
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
        result[[slot]] <- to_mcp_json(slot(x, slot), auto_unbox = auto_unbox)
      }
      return(result)
    } else {
      # S3 objects - convert to list and preserve class
      result <- unclass(x)
      if (is.list(result)) {
        # Use a loop to preserve attributes
        converted <- list()
        for (i in seq_along(result)) {
          converted[[names(result)[i]]] <- to_mcp_json(result[[i]], auto_unbox = auto_unbox)
        }
        result <- converted
      } else {
        result <- to_mcp_json(result, auto_unbox = auto_unbox)
      }
      attr(result, "_mcp_type") <- "S3"
      attr(result, "_mcp_class") <- class(x)
      return(result)
    }
  }
  
  # Handle lists (after checking for S3/S4 objects)
  if (is.list(x)) {
    # Recursively convert list elements
    result <- lapply(x, to_mcp_json, auto_unbox = auto_unbox)
    return(result)
  }
  
  # Default: return as-is and hope jsonlite can handle it
  return(x)
}

#' Convert JSON data back to R objects
#'
#' @param json JSON string or already parsed JSON data
#' @return An R object reconstructed from the JSON data
#' @export
#' @examples
#' json_str <- '{"a": 1, "b": ["hello", "world"]}'
#' from_mcp_json(json_str)
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
          mat <- matrix(data, nrow = obj$dim[1], ncol = obj$dim[2])
          if (!is.null(obj$dimnames)) {
            dimnames(mat) <- obj$dimnames
          }
          return(mat)
        } else if (mcp_type == "array") {
          # Reconstruct array
          data <- if (is.list(obj$data)) unlist(obj$data) else obj$data
          arr <- array(data, dim = obj$dim)
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
  mcp_obj <- to_mcp_json(x, auto_unbox = auto_unbox)
  
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