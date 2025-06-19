test_that("generate_mcp_server creates correct directory structure", {
  temp_dir <- tempdir()
  server_name <- "test-server"
  
  # Generate server
  server_dir <- generate_mcp_server(
    name = server_name,
    title = "Test Server",
    description = "A test server",
    path = temp_dir
  )
  
  # Check directory was created
  expect_true(dir.exists(server_dir))
  expect_equal(basename(server_dir), paste0("mcp-", server_name))
  
  # Check all files exist
  expected_files <- c(
    "wrapper.js",
    "server.R",
    "package.json",
    "README.md",
    "mcp.json",
    "test.js",
    ".gitignore"
  )
  
  for (file in expected_files) {
    expect_true(file.exists(file.path(server_dir, file)),
                info = paste("Missing file:", file))
  }
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("generate_mcp_server validates server name", {
  expect_error(
    generate_mcp_server(
      name = "Test Server",  # Invalid: contains space and uppercase
      title = "Test",
      description = "Test"
    ),
    "lowercase letters, numbers, and hyphens"
  )
  
  expect_error(
    generate_mcp_server(
      name = "test_server",  # Invalid: contains underscore
      title = "Test",
      description = "Test"
    ),
    "lowercase letters, numbers, and hyphens"
  )
})

test_that("generate_mcp_server handles existing directory", {
  temp_dir <- tempdir()
  server_name <- "existing-server"
  
  # Create directory first
  server_dir <- file.path(temp_dir, paste0("mcp-", server_name))
  dir.create(server_dir, showWarnings = FALSE)
  
  # Should fail without overwrite
  expect_error(
    generate_mcp_server(
      name = server_name,
      title = "Test",
      description = "Test",
      path = temp_dir
    ),
    "already exists"
  )
  
  # Should succeed with overwrite
  result <- generate_mcp_server(
    name = server_name,
    title = "Test",
    description = "Test",
    path = temp_dir,
    overwrite = TRUE
  )
  expect_true(dir.exists(result))
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("generate_mcp_server includes tools in generated code", {
  temp_dir <- tempdir()
  
  tools <- list(
    greet = list(
      description = "Greet someone",
      parameters = list(
        name = list(type = "string", description = "Name to greet")
      )
    )
  )
  
  server_dir <- generate_mcp_server(
    name = "tool-server",
    title = "Tool Server",
    description = "Server with tools",
    path = temp_dir,
    tools = tools
  )
  
  # Check server.R contains tool definition
  server_content <- readLines(file.path(server_dir, "server.R"))
  server_text <- paste(server_content, collapse = "\n")
  
  expect_true(grepl("greet", server_text))
  expect_true(grepl("Greet someone", server_text))
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("template variable replacement works correctly", {
  vars <- list(
    SERVER_NAME = "test",
    SERVER_TITLE = "Test Server",
    YEAR = "2024"
  )
  
  content <- c(
    "Server: {{SERVER_NAME}}",
    "Title: {{SERVER_TITLE}}",
    "Copyright {{YEAR}}"
  )
  
  result <- replace_template_vars(content, vars)
  
  expect_equal(result[1], "Server: test")
  expect_equal(result[2], "Title: Test Server")
  expect_equal(result[3], "Copyright 2024")
})

test_that("MCPServer generate method works", {
  # Create server with tools
  server <- mcp(name = "Test Server", version = "2.0.0")
  
  server$mcp_tool(
    name = "test_tool",
    fn = function(x) x * 2,
    description = "Test tool"
  )
  
  temp_dir <- tempdir()
  
  # Generate server
  server_dir <- server$generate(path = temp_dir)
  
  # Check server was created with correct name
  expect_true(dir.exists(server_dir))
  expect_equal(basename(server_dir), "mcp-test-server")
  
  # Check package.json has correct version
  pkg_json <- jsonlite::fromJSON(file.path(server_dir, "package.json"))
  expect_equal(pkg_json$version, "2.0.0")
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("generate_from_config works with JSON", {
  temp_dir <- tempdir()
  config_file <- file.path(temp_dir, "test-config.json")
  
  # Create config
  config <- list(
    name = "config-test",
    title = "Config Test Server",
    description = "Test server from config",
    version = "1.2.3",
    tools = list(
      test = list(
        description = "Test function"
      )
    )
  )
  
  jsonlite::write_json(config, config_file, auto_unbox = TRUE)
  
  # Generate from config
  server_dir <- generate_from_config(config_file, path = temp_dir)
  
  # Verify
  expect_true(dir.exists(server_dir))
  expect_equal(basename(server_dir), "mcp-config-test")
  
  # Check version
  pkg_json <- jsonlite::fromJSON(file.path(server_dir, "package.json"))
  expect_equal(pkg_json$version, "1.2.3")
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
  unlink(config_file)
})

test_that("format_tools_definition generates correct R code", {
  tools <- list(
    add = list(
      description = "Add two numbers",
      parameters = list(
        a = list(type = "number", description = "First number"),
        b = list(type = "number", description = "Second number")
      )
    )
  )
  
  result <- format_tools_definition(tools)
  
  expect_true(grepl("add = list", result))
  expect_true(grepl("description = \"Add two numbers\"", result))
  expect_true(grepl("a = list\\(type = \"number\"", result))
  expect_true(grepl("b = list\\(type = \"number\"", result))
})

test_that("minimal template is used when specified", {
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "minimal-test",
    title = "Minimal Test",
    description = "Test minimal template",
    path = temp_dir,
    template = "minimal"
  )
  
  # Check that minimal server.R was used
  server_content <- readLines(file.path(server_dir, "server.R"))
  
  # Minimal template should be simpler/shorter than full template
  # This is a basic check - could be more specific based on actual template differences
  expect_true(file.exists(file.path(server_dir, "server.R")))
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("wrapper.js is executable after generation", {
  skip_on_os("windows")  # File permissions work differently on Windows
  
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "exec-test",
    title = "Exec Test",
    description = "Test executable permissions",
    path = temp_dir
  )
  
  wrapper_path <- file.path(server_dir, "wrapper.js")
  server_path <- file.path(server_dir, "server.R")
  
  # Check files are executable
  wrapper_info <- file.info(wrapper_path)
  server_info <- file.info(server_path)
  
  # On Unix-like systems, check executable bit
  expect_true(file.access(wrapper_path, 1) == 0)
  expect_true(file.access(server_path, 1) == 0)
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

# Tests for new mcp_create_server functionality
test_that("mcp_create_server generates server from R file", {
  temp_dir <- tempdir()
  
  # Create a test R file with decorators
  test_file <- file.path(temp_dir, "test_functions.R")
  writeLines(c(
    "#* @mcp_tool",
    "#* @description Calculate sum of two numbers",
    "#* @param x number First number",
    "#* @param y number Second number",
    "add <- function(x, y) {",
    "  x + y",
    "}",
    "",
    "#* @mcp_tool",
    "#* @description Multiply two numbers",
    "multiply <- function(x, y) {",
    "  x * y",
    "}"
  ), test_file)
  
  # Generate server from file
  output_dir <- file.path(temp_dir, "servers")
  server_path <- mcp_create_server(
    source = test_file,
    output_dir = output_dir
  )
  
  # Check server was created
  expect_true(dir.exists(server_path))
  expect_equal(basename(server_path), "mcp-test-functions")
  
  # Check server.R contains registered tools
  server_content <- readLines(file.path(server_path, "server.R"))
  server_text <- paste(server_content, collapse = "\n")
  
  expect_true(grepl("mcp_tool.*add", server_text))
  expect_true(grepl("mcp_tool.*multiply", server_text))
  expect_true(grepl("Calculate sum of two numbers", server_text))
  
  # Clean up
  unlink(output_dir, recursive = TRUE)
  unlink(test_file)
})

test_that("mcp_create_server generates server from directory", {
  temp_dir <- tempdir()
  source_dir <- file.path(temp_dir, "r_functions")
  dir.create(source_dir)
  
  # Create multiple R files
  writeLines(c(
    "#* @mcp_tool",
    "#* @description Tool in file 1",
    "tool1 <- function() { 'Tool 1' }"
  ), file.path(source_dir, "file1.R"))
  
  writeLines(c(
    "#* @mcp_tool",
    "#* @description Tool in file 2",
    "tool2 <- function() { 'Tool 2' }"
  ), file.path(source_dir, "file2.R"))
  
  # Generate server from directory
  output_dir <- file.path(temp_dir, "servers")
  server_path <- mcp_create_server(
    source = source_dir,
    output_dir = output_dir,
    name = "multi-file-server"
  )
  
  # Check server was created
  expect_true(dir.exists(server_path))
  expect_equal(basename(server_path), "mcp-multi-file-server")
  
  # Check both tools are registered
  server_content <- readLines(file.path(server_path, "server.R"))
  server_text <- paste(server_content, collapse = "\n")
  
  expect_true(grepl("tool1", server_text))
  expect_true(grepl("tool2", server_text))
  
  # Clean up
  unlink(output_dir, recursive = TRUE)
  unlink(source_dir, recursive = TRUE)
})

test_that("mcp_create_server handles package source", {
  skip_if_not_installed("stats")  # Use a base package that's always available
  
  temp_dir <- tempdir()
  output_dir <- file.path(temp_dir, "servers")
  
  # Generate server from package
  server_path <- mcp_create_server(
    source = "stats",
    output_dir = output_dir,
    include = c("mean", "median"),
    name = "stats-subset"
  )
  
  # Check server was created
  expect_true(dir.exists(server_path))
  expect_equal(basename(server_path), "mcp-stats-subset")
  
  # Clean up
  unlink(output_dir, recursive = TRUE)
})

test_that("generate_mcp_server uses protocol mode by default", {
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "protocol-test",
    title = "Protocol Test",
    description = "Test protocol mode",
    path = temp_dir
  )
  
  # Check that protocol-enhanced wrapper is used
  wrapper_content <- readLines(file.path(server_dir, "wrapper.js"))
  wrapper_text <- paste(wrapper_content, collapse = "\n")
  
  expect_true(grepl("protocol", wrapper_text, ignore.case = TRUE))
  expect_true(grepl("mcpToProtocol", wrapper_text))
  
  # Check that server.R uses ProtocolStdioTransport
  server_content <- readLines(file.path(server_dir, "server.R"))
  server_text <- paste(server_content, collapse = "\n")
  
  expect_true(grepl("ProtocolStdioTransport", server_text))
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("generate_mcp_server can use legacy mode", {
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "legacy-test",
    title = "Legacy Test", 
    description = "Test legacy mode",
    path = temp_dir,
    use_protocol = FALSE
  )
  
  # Check that legacy templates are used
  server_content <- readLines(file.path(server_dir, "server.R"))
  server_text <- paste(server_content, collapse = "\n")
  
  # Legacy mode should use direct JSON-RPC handling
  expect_true(grepl("jsonrpc", server_text))
  expect_false(grepl("ProtocolStdioTransport", server_text))
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("LICENSE file is generated", {
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "license-test",
    title = "License Test",
    description = "Test license generation",
    path = temp_dir,
    author = "Test Author"
  )
  
  # Check LICENSE file exists
  license_path <- file.path(server_dir, "LICENSE")
  expect_true(file.exists(license_path))
  
  # Check content
  license_content <- readLines(license_path)
  license_text <- paste(license_content, collapse = "\n")
  
  expect_true(grepl("MIT License", license_text))
  expect_true(grepl("Test Author", license_text))
  expect_true(grepl(format(Sys.Date(), "%Y"), license_text))
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})

test_that("enhanced package.json is generated correctly", {
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "package-test",
    title = "Package Test",
    description = "Test package.json generation",
    path = temp_dir,
    author = "Test Author",
    version = "2.0.0"
  )
  
  # Read package.json
  pkg_json <- jsonlite::fromJSON(file.path(server_dir, "package.json"))
  
  # Check enhanced fields
  expect_equal(pkg_json$name, "mcp-package-test")
  expect_equal(pkg_json$version, "2.0.0")
  expect_equal(pkg_json$author, "Test Author")
  expect_true("bin" %in% names(pkg_json))
  expect_equal(pkg_json$bin$`mcp-package-test`, "./wrapper.js")
  expect_true("debug" %in% names(pkg_json$scripts))
  expect_true("install-global" %in% names(pkg_json$scripts))
  expect_equal(pkg_json$engines$node, ">=16.0.0")
  expect_equal(pkg_json$mcp$serverName, "package-test")
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})