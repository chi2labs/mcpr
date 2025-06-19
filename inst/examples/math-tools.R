#' Math Tools Example
#' 
#' Example R file with decorated functions for MCP server generation

#* @mcp_tool
#* @description Add two numbers together
#* @param a number First number to add
#* @param b number Second number to add
add <- function(a, b) {
  a + b
}

#* @mcp_tool
#* @description Subtract one number from another
#* @param a number Number to subtract from
#* @param b number Number to subtract
subtract <- function(a, b) {
  a - b
}

#* @mcp_tool
#* @description Multiply two numbers
#* @param a number First number
#* @param b number Second number
multiply <- function(a, b) {
  a * b
}

#* @mcp_tool
#* @description Divide one number by another
#* @param a number Dividend
#* @param b number Divisor (must not be zero)
divide <- function(a, b) {
  if (b == 0) {
    stop("Division by zero is not allowed")
  }
  a / b
}

#* @mcp_tool
#* @description Calculate the square root of a number
#* @param x number The number to find the square root of
sqrt_custom <- function(x) {
  if (x < 0) {
    stop("Cannot calculate square root of negative number")
  }
  sqrt(x)
}

#* @mcp_resource
#* @description Get math constants
#* @mime_type application/json
get_constants <- function() {
  list(
    pi = pi,
    e = exp(1),
    golden_ratio = (1 + sqrt(5)) / 2,
    euler_gamma = 0.5772156649
  )
}

#* @mcp_prompt
#* @description Prompt for solving a math problem
#* @template Please solve the following math problem: {{problem}}. Show your work step by step.
#* @param problem string The math problem to solve
math_solver_prompt <- NULL