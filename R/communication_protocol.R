#' R↔Node.js Communication Protocol
#'
#' @description
#' Defines the communication protocol between Node.js wrapper and R process.
#' This protocol handles bidirectional communication with proper serialization
#' of R's special values and error handling without stderr leakage.
#'
#' @details
#' Message Format:
#' \preformatted{
#' {
#'   "id": "unique-message-id",
#'   "type": "request|response|error|notification",
#'   "method": "method-name",
#'   "params": {},
#'   "result": {},
#'   "error": {}
#' }
#' }
#'
#' @importFrom jsonlite fromJSON toJSON
#' @name communication_protocol
NULL

#' Create a protocol message
#'
#' @description
#' Creates a properly formatted message for the R↔Node.js protocol.
#'
#' @param type Character string: "request", "response", "error", or "notification"
#' @param id Character string, message ID (auto-generated if NULL for requests)
#' @param method Character string, method name (for requests/notifications)
#' @param params List, method parameters (for requests/notifications)
#' @param result Any R object, result data (for responses)
#' @param error List with 'code' and 'message' (for error responses)
#'
#' @return List representing the protocol message
#' @export
create_protocol_message <- function(type = c("request", "response", "error", "notification"),
                                  id = NULL,
                                  method = NULL,
                                  params = NULL,
                                  result = NULL,
                                  error = NULL) {
  type <- match.arg(type)
  
  # Auto-generate ID for requests if not provided
  if (type == "request" && is.null(id)) {
    if (requireNamespace("uuid", quietly = TRUE)) {
      id <- uuid::UUIDgenerate()
    } else {
      id <- paste0("msg_", as.numeric(Sys.time()) * 1000, "_", sample(1000:9999, 1))
    }
  }
  
  # Build message structure
  msg <- list(type = type)
  
  # Add ID if present (not for notifications)
  if (!is.null(id) && type != "notification") {
    msg$id <- id
  }
  
  # Add method and params for requests/notifications
  if (type %in% c("request", "notification")) {
    if (is.null(method)) {
      stop("Method is required for request/notification messages")
    }
    msg$method <- method
    if (!is.null(params)) {
      msg$params <- params
    }
  }
  
  # Add result for responses
  if (type == "response") {
    if (is.null(id)) {
      stop("ID is required for response messages")
    }
    msg$result <- result
  }
  
  # Add error for error responses
  if (type == "error") {
    if (is.null(id)) {
      stop("ID is required for error messages")
    }
    if (is.null(error)) {
      stop("Error details are required for error messages")
    }
    msg$error <- error
  }
  
  msg
}

#' Serialize R object for protocol communication
#'
#' @description
#' Serializes R objects to JSON, handling special R values like NA, NULL, Inf, -Inf, NaN.
#' This ensures safe transmission between R and Node.js.
#'
#' @param obj Any R object to serialize
#' @param auto_unbox Logical, whether to auto-unbox length-1 vectors
#' @param null Character, how to encode NULL values
#' @param na Character, how to encode NA values
#' @param pretty Logical, whether to pretty-print JSON
#'
#' @return JSON string
#' @export
protocol_serialize <- function(obj, 
                             auto_unbox = TRUE, 
                             null = "null",
                             na = "null",
                             pretty = FALSE) {
  # Pre-process object to handle special R values
  obj <- preprocess_for_serialization(obj)
  
  # Use jsonlite for serialization with specific settings
  jsonlite::toJSON(
    obj,
    auto_unbox = auto_unbox,
    null = null,
    na = na,
    pretty = pretty,
    force = TRUE,
    digits = NA  # Preserve full numeric precision
  )
}

#' Deserialize JSON to R object
#'
#' @description
#' Deserializes JSON string to R object, handling special values that may
#' have been encoded during serialization.
#'
#' @param json Character string containing JSON
#' @param simplifyVector Logical, whether to simplify JSON arrays to vectors
#' @param simplifyDataFrame Logical, whether to simplify JSON objects to data frames
#' @param simplifyMatrix Logical, whether to simplify JSON arrays to matrices
#'
#' @return R object
#' @export
protocol_deserialize <- function(json,
                               simplifyVector = FALSE,
                               simplifyDataFrame = FALSE,
                               simplifyMatrix = FALSE) {
  # Parse JSON
  obj <- jsonlite::fromJSON(
    json,
    simplifyVector = simplifyVector,
    simplifyDataFrame = simplifyDataFrame,
    simplifyMatrix = simplifyMatrix
  )
  
  # Post-process to restore special R values
  postprocess_after_deserialization(obj)
}

#' Pre-process R object for serialization
#'
#' @description
#' Handles special R values that don't have direct JSON equivalents.
#'
#' @param obj Any R object
#' @return Modified object safe for JSON serialization
#' @keywords internal
preprocess_for_serialization <- function(obj) {
  if (is.list(obj)) {
    # Recursively process list elements
    lapply(obj, preprocess_for_serialization)
  } else if (is.data.frame(obj)) {
    # Convert data frame to list of columns, then process each column
    lapply(as.list(obj), preprocess_for_serialization)
  } else if (is.numeric(obj)) {
    # Handle special numeric values
    result <- obj
    pos_inf_idx <- is.infinite(obj) & obj > 0
    neg_inf_idx <- is.infinite(obj) & obj < 0
    nan_idx <- is.nan(obj)
    
    result[pos_inf_idx] <- "__R_POS_INF__"
    result[neg_inf_idx] <- "__R_NEG_INF__"
    result[nan_idx] <- "__R_NAN__"
    
    # Convert to character to preserve special value markers
    as.character(result)
  } else {
    obj
  }
}

#' Post-process object after deserialization
#'
#' @description
#' Restores special R values that were encoded during serialization.
#'
#' @param obj Any R object
#' @return Object with restored special values
#' @keywords internal
postprocess_after_deserialization <- function(obj) {
  if (is.list(obj)) {
    # Recursively process list elements
    lapply(obj, postprocess_after_deserialization)
  } else if (is.character(obj) && length(obj) > 0) {
    # Check if any values are special R value markers
    has_special <- any(obj %in% c("__R_POS_INF__", "__R_NEG_INF__", "__R_NAN__"))
    
    if (has_special) {
      # Convert to numeric first
      result <- suppressWarnings(as.numeric(obj))
      
      # Replace special markers
      pos_inf_idx <- obj == "__R_POS_INF__"
      neg_inf_idx <- obj == "__R_NEG_INF__"
      nan_idx <- obj == "__R_NAN__"
      
      result[pos_inf_idx] <- Inf
      result[neg_inf_idx] <- -Inf
      result[nan_idx] <- NaN
      
      result
    } else {
      # Try to convert to numeric if all values look numeric
      if (all(grepl("^-?[0-9.]+$", obj, perl = TRUE))) {
        suppressWarnings(as.numeric(obj))
      } else {
        obj
      }
    }
  } else {
    obj
  }
}

#' Read protocol message from stdin
#'
#' @description
#' Reads a single protocol message from stdin, handling the complexities
#' of R's stdin behavior in subprocess contexts.
#'
#' @param timeout Numeric, timeout in seconds (NULL for no timeout)
#' @return Parsed message as list, or NULL if no message available
#' @export
read_protocol_message <- function(timeout = NULL) {
  # Use blocking stdin read
  con <- file("stdin", open = "r", blocking = TRUE)
  on.exit(close(con), add = TRUE)
  
  tryCatch({
    # Read one line
    line <- readLines(con, n = 1, warn = FALSE)
    
    # Check for EOF
    if (length(line) == 0) {
      return(NULL)
    }
    
    # Skip empty lines
    if (nchar(trimws(line)) == 0) {
      return(read_protocol_message(timeout))  # Recursive call for next line
    }
    
    # Parse the message
    protocol_deserialize(line)
  }, error = function(e) {
    # Return error as protocol error message
    create_protocol_message(
      type = "error",
      id = "parse_error",
      error = list(
        code = -32700,
        message = "Parse error",
        data = as.character(e)
      )
    )
  })
}

#' Write protocol message to stdout
#'
#' @description
#' Writes a protocol message to stdout, ensuring proper formatting
#' and flushing.
#'
#' @param message List representing the protocol message
#' @export
write_protocol_message <- function(message) {
  # Serialize the message
  json <- protocol_serialize(message, pretty = FALSE)
  
  # Write to stdout with newline
  cat(json, "\n", sep = "")
  
  # Ensure it's flushed immediately
  flush(stdout())
}

#' Protocol message handler
#'
#' @description
#' Main handler for processing protocol messages. This function routes
#' messages to appropriate handlers based on type and method.
#'
#' @param message List representing the incoming protocol message
#' @param handlers Named list of handler functions
#' @return Response message or NULL for notifications
#' @export
handle_protocol_message <- function(message, handlers = list()) {
  # Validate message structure
  if (!is.list(message) || is.null(message$type)) {
    msg_id <- if (is.list(message) && !is.null(message$id)) message$id else "unknown"
    return(create_protocol_message(
      type = "error",
      id = msg_id,
      error = list(
        code = -32600,
        message = "Invalid message format"
      )
    ))
  }
  
  # Handle based on message type
  if (message$type == "request") {
    # Find handler for the method
    handler <- handlers[[message$method]]
    
    if (is.null(handler)) {
      return(create_protocol_message(
        type = "error",
        id = message$id,
        error = list(
          code = -32601,
          message = "Method not found",
          data = message$method
        )
      ))
    }
    
    # Execute handler
    tryCatch({
      result <- handler(message$params %||% list())
      create_protocol_message(
        type = "response",
        id = message$id,
        result = result
      )
    }, error = function(e) {
      create_protocol_message(
        type = "error",
        id = message$id,
        error = list(
          code = -32603,
          message = "Internal error",
          data = as.character(e)
        )
      )
    })
  } else if (message$type == "notification") {
    # Handle notification (no response expected)
    handler <- handlers[[message$method]]
    if (!is.null(handler)) {
      tryCatch({
        handler(message$params %||% list())
      }, error = function(e) {
        # Log error internally but don't send response for notifications
        # This prevents stderr output
      })
    }
    NULL
  } else {
    # Unexpected message type
    create_protocol_message(
      type = "error",
      id = message$id %||% "unknown",
      error = list(
        code = -32600,
        message = "Invalid message type",
        data = message$type
      )
    )
  }
}

#' Run protocol communication loop
#'
#' @description
#' Main loop for handling protocol communication. Reads messages from stdin,
#' processes them, and writes responses to stdout.
#'
#' @param handlers Named list of handler functions
#' @param on_ready Optional function to call when ready to receive messages
#' @export
run_protocol_loop <- function(handlers = list(), on_ready = NULL) {
  # Signal readiness if callback provided
  if (!is.null(on_ready)) {
    on_ready()
  }
  
  # Main communication loop
  repeat {
    # Read message
    message <- read_protocol_message()
    
    # Check for EOF
    if (is.null(message)) {
      break
    }
    
    # Handle message
    response <- handle_protocol_message(message, handlers)
    
    # Send response if any
    if (!is.null(response)) {
      write_protocol_message(response)
    }
  }
}