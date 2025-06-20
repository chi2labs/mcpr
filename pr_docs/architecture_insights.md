# Architecture Insights - mcpr Package

## Key Findings from HTTP-First Implementation

After extensive development and testing, the mcpr package has successfully adopted an HTTP-first architecture that provides:

1. **Reliable Transport**: HTTP/JSON-RPC communication eliminates the complexity of subprocess management
2. **Multi-Client Support**: Unlike stdio, HTTP servers can handle multiple concurrent connections
3. **Standard Tooling**: HTTP endpoints can be tested with curl, Postman, or any HTTP client
4. **Clean Architecture**: Direct R-to-client communication without intermediate layers

## Architectural Advantages

### HTTP Transport Benefits
- **No subprocess management**: R server runs as a standalone HTTP service
- **Clean error handling**: HTTP status codes and JSON error responses
- **Debugging simplicity**: Standard HTTP debugging tools apply
- **Deployment flexibility**: Can run locally or be deployed to any server

### R's Web Framework Strengths
The R ecosystem provides robust HTTP server capabilities:
- **plumber**: Production-ready REST API framework with automatic OpenAPI documentation
- **httpuv**: Low-level HTTP server with WebSocket support
- **jsonlite**: Reliable JSON serialization with proper handling of R data types

## Simplified Package Design

### Core Architecture
```
┌─────────────┐     HTTP/JSON-RPC     ┌──────────────┐
│ MCP Client  │◄────────────────────►│   R Server   │
│   (Claude)  │                       │  (plumber)   │
└─────────────┘                       └──────────────┘
```

### Implementation Stack
1. **Transport Layer**: HTTP via plumber
2. **Protocol Layer**: MCP/JSON-RPC handling in pure R
3. **Function Layer**: Direct R function registration and execution

## Best Practices

### Server Implementation
```r
# Simple HTTP MCP server
server <- mcp_http("My R Analysis Server", "1.0.0", port = 8080)

# Register functions directly
server$register_tool(
  name = "analyze_data",
  fn = function(data, method) {
    # Direct R implementation
  },
  description = "Analyze data using R"
)

# Start serving
server$run()
```

### Configuration for Claude Desktop
```json
{
  "mcpServers": {
    "r-analysis": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

## Technical Considerations

### JSON Serialization
- Use `jsonlite::toJSON()` with `auto_unbox = TRUE` for proper scalar handling
- Protect empty arrays with `I()` to ensure correct serialization
- Handle R's special values (NA, NULL, Inf) appropriately

### Error Handling
- Implement proper JSON-RPC error responses
- Use HTTP status codes meaningfully
- Provide clear error messages for debugging

### Performance
- HTTP overhead is minimal for typical MCP use cases
- Connection pooling handled by HTTP clients
- Supports streaming for large datasets via chunked responses

## Deployment Options

1. **Local Development**: Run on localhost for Claude Desktop
2. **Network Deployment**: Host on internal network for team access
3. **Cloud Deployment**: Deploy to cloud services with proper authentication
4. **Containerization**: Package as Docker containers for easy deployment

## Conclusion

The HTTP-first approach has proven to be the optimal architecture for mcpr:
- Eliminates complexity of subprocess and stdio management
- Leverages R's mature web framework ecosystem
- Provides flexibility for various deployment scenarios
- Maintains clean separation of concerns

This architecture makes MCP servers in R as straightforward to implement as any REST API, opening up R's analytical capabilities to AI assistants with minimal complexity.