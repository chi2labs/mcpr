# Draft Release for v0.9.0

Once PR #29 is merged, create a new release with:

**Tag:** v0.9.0
**Target:** main (after PR merge)
**Release title:** mcpr v0.9.0 - First Official Release

**Release body:**

---

We're excited to announce the first official release of mcpr - Model Context Protocol for R! 🎉

## Overview

mcpr enables R developers to expose their functions, resources, and entire packages through the Model Context Protocol (MCP), allowing seamless integration with AI assistants like Claude Desktop. This package brings the power of R's statistical and data analysis capabilities directly to AI workflows.

## Key Features

### 🚀 HTTP-Based Architecture
- Reliable HTTP transport for stable connections with Claude Desktop
- Support for multiple concurrent clients
- Easy testing with standard HTTP tools
- Robust error handling and JSON-RPC compliance

### 🎨 Decorator System
Following patterns established by plumber, mcpr provides an intuitive decorator system:
- `@mcp_tool` - Expose functions as callable tools
- `@mcp_resource` - Provide data and information resources
- `@mcp_prompt` - Define reusable prompt templates

### 💻 Flexible Server Creation
- **Programmatic API**: Create servers dynamically in R scripts
- **Decorator-based**: Annotate existing functions with minimal changes
- **Server Generation**: Generate standalone server packages

### 📚 Comprehensive Documentation
- Detailed vignettes for creating servers and using decorators
- Extensive function documentation
- Real-world examples included

## Installation

```r
# Install from GitHub
devtools::install_github("chi2labs/mcpr@v0.9.0")
```

## Getting Started

```r
library(mcpr)

# Create a server with decorators
server <- mcp("My R Server", "1.0.0")
server$mcp_source("my-functions.R")
server$mcp_run(transport = "http", port = 8080)
```

## What's Changed
- Initial release with core MCP functionality
- HTTP transport implementation
- Decorator system for tools, resources, and prompts
- Server generation utilities
- Comprehensive documentation

## What's Next

We're planning several enhancements for future releases:
- Subscription support for real-time updates (#17)
- Automatic type inference from function signatures (#12)
- Package-level exports (#13)
- Enhanced validation and error messages (#6)

## Contributing

We welcome contributions! Please see our [contributing guidelines](https://github.com/chi2labs/mcpr) and feel free to open issues or submit pull requests.

**Full Changelog**: https://github.com/chi2labs/mcpr/commits/v0.9.0

---

For detailed documentation, visit our [package website](https://chi2labs.github.io/mcpr/).