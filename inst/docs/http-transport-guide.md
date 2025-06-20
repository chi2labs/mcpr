# HTTP Transport Implementation Guide for mcpr

## Overview

The mcpr package now supports HTTP transport as an alternative to stdio, providing a more robust and scalable solution for MCP servers. This guide explains the implementation details and migration path.

## Implementation Summary

### Core Components

1. **HttpTransport R6 Class** (`R/mcp_http_server.R`)
   - Implements the MCP protocol over HTTP using plumber
   - Handles JSON-RPC 2.0 request/response format
   - Provides logging and error handling capabilities
   - Supports CORS for browser-based clients

2. **Convenience Functions**
   - `mcp_http()` - Creates an HTTP-enabled MCP server
   - `mcp_hello_world_http()` - Quick start example with HTTP

3. **Integration with Existing MCPServer**
   - Modified `mcp_run()` method to support `transport = "http"`
   - Seamless migration path from stdio to HTTP

## Key Features

### 1. Protocol Implementation
- Single `/mcp` endpoint handling all JSON-RPC 2.0 requests
- Full support for all MCP methods:
  - `initialize` - Protocol handshake
  - `tools/list` and `tools/call` - Tool discovery and execution
  - `resources/list` and `resources/read` - Resource access
  - `prompts/list` and `prompts/get` - Prompt templates

### 2. Additional Endpoints
- `GET /health` - Health check for monitoring
- `GET /` - Server information and capabilities

### 3. Logging System
- Configurable log levels (debug, info, warn, error)
- File or console logging
- Request/response tracking
- Error logging with stack traces (in debug mode)

### 4. Error Handling
- Proper JSON-RPC 2.0 error responses
- HTTP status codes
- Graceful error recovery

## Migration Guide

### From stdio to HTTP

#### Before (stdio):
```r
server <- mcp(name = "My Server", version = "1.0.0")
server$mcp_tool(name = "hello", fn = function(name) paste("Hello", name))
server$mcp_run(transport = "stdio")
```

#### After (HTTP):
```r
server <- mcp(name = "My Server", version = "1.0.0")
server$mcp_tool(name = "hello", fn = function(name) paste("Hello", name))
server$mcp_run(transport = "http", port = 8080)
```

#### Using HTTP convenience function:
```r
server <- mcp_http(name = "My Server", version = "1.0.0", port = 8080)
server$mcp_tool(name = "hello", fn = function(name) paste("Hello", name))
server$mcp_run()  # Automatically uses HTTP
```

## Testing HTTP Servers

### Using curl:
```bash
# List tools
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# Call a tool
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"hello","arguments":{"name":"World"}},"id":2}'
```

### Using the test script:
```r
source("inst/examples/test-http-server.R")
```

## Deployment Options

### Local Development
```r
server <- mcp_http(host = "127.0.0.1", port = 8080)
```

### Docker Container
```dockerfile
FROM rocker/r-ver:4.3.0
RUN install.packages(c("plumber", "jsonlite", "R6", "remotes"))
RUN remotes::install_github("chi2labs/mcpr")
COPY server.R /app/
EXPOSE 8080
CMD ["Rscript", "/app/server.R"]
```

### Cloud Deployment
- Deploy to Heroku, Google Cloud Run, or AWS
- Use environment variables for configuration
- Implement proper authentication for production

## Advanced Configuration

### With Logging
```r
server <- mcp_http(
  name = "Production Server",
  log_file = "/var/log/mcp-server.log",
  log_level = "info"
)
```

### With Custom Error Handling
```r
server <- mcp_http(name = "Safe Server")
server$mcp_tool(
  name = "safe_divide",
  fn = function(a, b) {
    if (b == 0) stop("Division by zero")
    a / b
  }
)
```

## Performance Considerations

1. **Connection Pooling**: HTTP servers can handle multiple concurrent connections
2. **Stateless Design**: Each request is independent, enabling horizontal scaling
3. **Caching**: Implement caching for expensive operations
4. **Rate Limiting**: Add rate limiting for public endpoints

## Security Best Practices

1. **Authentication**: Implement OAuth 2.1 for production
2. **HTTPS**: Always use TLS in production
3. **Input Validation**: Validate all inputs before processing
4. **CORS**: Configure CORS policies appropriately
5. **Secrets**: Never log sensitive information

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```r
   # Use a different port
   server$mcp_run(transport = "http", port = 8081)
   ```

2. **plumber Not Installed**
   ```r
   install.packages("plumber")
   ```

3. **Logging Not Working**
   ```r
   # Check file permissions for log file
   # Or use console logging
   server <- mcp_http(log_level = "debug")  # Logs to console
   ```

## Next Steps

1. Review the examples in `inst/examples/`
2. Test HTTP servers with the provided test scripts
3. Deploy a simple server to understand the workflow
4. Implement security measures for production use

## Advantages of HTTP Transport

1. **No stdio complexity**: Avoids R's subprocess stdin handling issues
2. **Multi-client support**: Handle concurrent connections
3. **Standard tooling**: Use familiar HTTP debugging tools
4. **Cloud-ready**: Deploy to any platform supporting HTTP services
5. **Better monitoring**: Standard HTTP metrics and logging
6. **Easier testing**: Test with curl, Postman, or automated tests

The HTTP transport implementation provides a robust, scalable alternative to stdio transport while maintaining full compatibility with the MCP protocol specification.