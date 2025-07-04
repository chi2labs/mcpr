% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/generate-server.R
\name{generate_mcp_server}
\alias{generate_mcp_server}
\title{Generate MCP Server Package}
\usage{
generate_mcp_server(
  name,
  title,
  description,
  version = "0.1.0",
  path = ".",
  tools = NULL,
  resources = NULL,
  prompts = NULL,
  template = "full",
  author = NULL,
  overwrite = FALSE
)
}
\arguments{
\item{name}{Server name (used in package naming and configuration)}

\item{title}{Human-readable server title}

\item{description}{Server description}

\item{version}{Server version (default: "0.1.0")}

\item{path}{Directory to create the server in (default: current directory)}

\item{tools}{List of tool definitions (optional)}

\item{resources}{List of resource definitions (optional)}

\item{prompts}{List of prompt definitions (optional)}

\item{template}{Which template to use: "full" or "minimal" (default: "full")}

\item{author}{Author name (optional)}

\item{overwrite}{Whether to overwrite existing directory (default: FALSE)}
}
\value{
Path to the generated server directory
}
\description{
Creates a complete MCP server package with Node.js wrapper and R server implementation
}
\examples{
\dontrun{
# Generate a simple server
generate_mcp_server("my-analyzer", "My Data Analyzer", 
                    "Analyzes data using R functions")

# Generate with tools
tools <- list(
  analyze = list(
    description = "Analyze a dataset",
    parameters = list(
      data = list(type = "string", description = "Data to analyze")
    )
  )
)
generate_mcp_server("analyzer", "Data Analyzer", "Analyzes data",
                    tools = tools)
}
}
