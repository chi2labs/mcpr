#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

// Path to R script
const scriptPath = path.join(__dirname, 'mcp-hello-world-clean.R');

// Spawn Rscript process
const rProcess = spawn('Rscript', ['--no-echo', scriptPath], {
  stdio: ['pipe', 'pipe', 'pipe']
});

// Pipe stdin to R process
process.stdin.pipe(rProcess.stdin);

// Pipe R stdout to our stdout
rProcess.stdout.pipe(process.stdout);

// Filter R stderr to remove debug messages
rProcess.stderr.on('data', (data) => {
  const msg = data.toString();
  // Only pass through actual errors, not debug messages
  if (!msg.includes('Starting MCP Hello World Server') && 
      !msg.includes('R version:') && 
      !msg.includes('Working directory:') &&
      !msg.includes('EOF reached, shutting down')) {
    process.stderr.write(data);
  }
});

// Handle R process exit
rProcess.on('exit', (code) => {
  process.exit(code || 0);
});

// Handle errors
rProcess.on('error', (err) => {
  console.error('Failed to start R process:', err);
  process.exit(1);
});

// Handle our process termination
process.on('SIGTERM', () => {
  rProcess.kill('SIGTERM');
});

process.on('SIGINT', () => {
  rProcess.kill('SIGINT');
});