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
    "server.R",
    "README.md",
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
  
  # Check server.R exists with correct content
  server_content <- readLines(file.path(server_dir, "server.R"))
  expect_true(any(grepl("test_tool", server_content)))
  
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
  
  # Check server was created with correct name from config
  server_content <- readLines(file.path(server_dir, "server.R"))
  expect_true(any(grepl("config-test", server_content)))
  
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

test_that("server.R is executable after generation", {
  skip_on_os("windows")  # File permissions work differently on Windows
  
  temp_dir <- tempdir()
  
  server_dir <- generate_mcp_server(
    name = "exec-test",
    title = "Exec Test",
    description = "Test executable permissions",
    path = temp_dir
  )
  
  server_path <- file.path(server_dir, "server.R")
  
  # Check server.R is executable
  server_info <- file.info(server_path)
  
  # On Unix-like systems, check executable bit
  expect_true(file.access(server_path, 1) == 0)
  
  # Clean up
  unlink(server_dir, recursive = TRUE)
})