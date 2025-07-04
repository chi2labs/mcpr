% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mcp-source.R
\name{mcp_source_directory}
\alias{mcp_source_directory}
\title{Load all MCP elements from a directory}
\usage{
mcp_source_directory(server, path, pattern = "\\\\.R$", recursive = TRUE)
}
\arguments{
\item{server}{MCPServer instance}

\item{path}{Directory path}

\item{pattern}{File pattern to match}

\item{recursive}{Whether to scan subdirectories}
}
\value{
The server (invisibly) for chaining
}
\description{
Load all MCP elements from a directory
}
