#!/usr/bin/env node

/**
 * Test script for math-tools MCP Server
 * 
 * This script tests the basic functionality of the generated MCP server
 * by sending JSON-RPC requests and validating responses.
 */

const { spawn } = require('child_process');
const path = require('path');

// Colors for output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m'
};

// Test configuration
const tests = [];
let currentTest = null;
let serverProcess = null;
let testResults = {
  passed: 0,
  failed: 0
};

// Helper to send request and get response
async function sendRequest(request) {
  return new Promise((resolve, reject) => {
    let response = '';
    let errorOutput = '';
    
    const handleData = (data) => {
      response += data.toString();
      // Try to parse complete JSON responses
      try {
        const parsed = JSON.parse(response);
        serverProcess.stdout.removeListener('data', handleData);
        resolve(parsed);
      } catch (e) {
        // Not complete yet, keep accumulating
      }
    };
    
    const handleError = (data) => {
      errorOutput += data.toString();
    };
    
    serverProcess.stdout.on('data', handleData);
    serverProcess.stderr.on('data', handleError);
    
    // Send the request
    serverProcess.stdin.write(JSON.stringify(request) + '\n');
    
    // Timeout after 5 seconds
    setTimeout(() => {
      serverProcess.stdout.removeListener('data', handleData);
      serverProcess.stderr.removeListener('data', handleError);
      reject(new Error(`Timeout waiting for response. stderr: ${errorOutput}`));
    }, 5000);
  });
}

// Test assertion helpers
function assertEqual(actual, expected, message) {
  if (JSON.stringify(actual) === JSON.stringify(expected)) {
    console.log(`  ${colors.green}✓${colors.reset} ${message}`);
    testResults.passed++;
  } else {
    console.log(`  ${colors.red}✗${colors.reset} ${message}`);
    console.log(`    Expected: ${JSON.stringify(expected)}`);
    console.log(`    Actual: ${JSON.stringify(actual)}`);
    testResults.failed++;
  }
}

function assertExists(value, message) {
  if (value !== null && value !== undefined) {
    console.log(`  ${colors.green}✓${colors.reset} ${message}`);
    testResults.passed++;
  } else {
    console.log(`  ${colors.red}✗${colors.reset} ${message}`);
    console.log(`    Value was null or undefined`);
    testResults.failed++;
  }
}

// Define tests
tests.push({
  name: 'Server Initialization',
  run: async () => {
    const request = {
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: {
          name: 'test-client',
          version: '1.0.0'
        }
      }
    };
    
    const response = await sendRequest(request);
    assertExists(response.result, 'Initialize returned a result');
    assertEqual(response.result.protocolVersion, '2024-11-05', 'Protocol version matches');
    assertExists(response.result.capabilities, 'Capabilities exist');
    assertExists(response.result.serverInfo, 'Server info exists');
    assertEqual(response.result.serverInfo.name, 'math-tools', 'Server name matches');
  }
});

tests.push({
  name: 'List Tools',
  run: async () => {
    const request = {
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/list',
      params: {}
    };
    
    const response = await sendRequest(request);
    assertExists(response.result, 'Tools list returned a result');
    assertExists(response.result.tools, 'Tools array exists');
    console.log(`  Found ${response.result.tools.length} tools`);
  }
});

tests.push({
  name: 'List Resources',
  run: async () => {
    const request = {
      jsonrpc: '2.0',
      id: 3,
      method: 'resources/list',
      params: {}
    };
    
    const response = await sendRequest(request);
    assertExists(response.result, 'Resources list returned a result');
    assertExists(response.result.resources, 'Resources array exists');
    console.log(`  Found ${response.result.resources.length} resources`);
  }
});

{{ADDITIONAL_TESTS}}

// Main test runner
async function runTests() {
  console.log(`${colors.blue}Testing math-tools MCP Server${colors.reset}\n`);
  
  // Start the server
  console.log('Starting server...');
  serverProcess = spawn('node', ['index.js'], {
    cwd: __dirname,
    stdio: ['pipe', 'pipe', 'pipe']
  });
  
  serverProcess.on('error', (err) => {
    console.error(`${colors.red}Failed to start server:${colors.reset}`, err);
    process.exit(1);
  });
  
  // Wait a bit for server to start
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Run tests
  for (const test of tests) {
    console.log(`\n${colors.yellow}${test.name}${colors.reset}`);
    try {
      await test.run();
    } catch (error) {
      console.log(`  ${colors.red}✗ Test failed with error: ${error.message}${colors.reset}`);
      testResults.failed++;
    }
  }
  
  // Clean up
  serverProcess.kill();
  
  // Print summary
  console.log(`\n${colors.blue}Test Summary${colors.reset}`);
  console.log(`  Passed: ${colors.green}${testResults.passed}${colors.reset}`);
  console.log(`  Failed: ${colors.red}${testResults.failed}${colors.reset}`);
  
  process.exit(testResults.failed > 0 ? 1 : 0);
}

// Run the tests
runTests().catch(err => {
  console.error(`${colors.red}Test runner failed:${colors.reset}`, err);
  if (serverProcess) serverProcess.kill();
  process.exit(1);
});
