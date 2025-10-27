# Idris2 MCP Server

A Model Context Protocol (MCP) server that provides Idris2 type-checking, syntax validation, error explanation, and code generation tools.

## Features

### 🔧 Tools

1. **check_idris2**
   - Type-check Idris2 code
   - Returns compiler output with success/failure status
   - Timeout: 30 seconds

2. **explain_error**
   - Explains Idris2 compiler errors in plain language
   - Provides common fixes and suggestions
   - Handles most common error patterns

3. **get_template**
   - Generates Idris2 code templates
   - Supports: record, data, interface, proof, smart_constructor
   - Customizable with name parameter

4. **validate_syntax**
   - Quick syntax validation without full type-checking
   - Checks for common syntax issues
   - Detects unmatched parentheses, missing type signatures, etc.

5. **suggest_fix**
   - Suggests fixes for common Idris2 errors
   - Provides step-by-step suggestions
   - Context-aware recommendations

## Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Make server executable
chmod +x server.py
```

## Configuration

Add to your MCP configuration (e.g., `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "idris2-helper": {
      "command": "python",
      "args": [
        "/Users/joonho/Idris2Projects/TypedContract/mcp-servers/idris2-mcp/server.py"
      ]
    }
  }
}
```

## Usage Examples

### Type-checking code

```json
{
  "tool": "check_idris2",
  "arguments": {
    "code": "module Domains.Test\n\ndata Foo : Type where\n  MkFoo : Foo",
    "module_name": "Domains.Test"
  }
}
```

### Getting a template

```json
{
  "tool": "get_template",
  "arguments": {
    "pattern": "record",
    "name": "MyContract"
  }
}
```

### Explaining an error

```json
{
  "tool": "explain_error",
  "arguments": {
    "error_message": "Error: Expected a type declaration."
  }
}
```

## Requirements

- Python 3.10+
- Idris2 installed and available in PATH
- MCP Python SDK

## Integration with TypedContract

This MCP server is specifically designed for the TypedContract project to:
- Validate generated Idris2 code before compilation
- Provide better error messages to Claude during code generation
- Offer templates for common contract patterns
- Speed up the development cycle with quick syntax checks

## Development

### Testing locally

```bash
# Run the server
python server.py

# In another terminal, test with MCP inspector
npx @modelcontextprotocol/inspector python server.py
```

### Adding new tools

1. Add tool definition to `handle_list_tools()`
2. Add tool handler to `handle_call_tool()`
3. Implement the tool function
4. Update README with usage examples

## Error Patterns Supported

- "Expected a type declaration"
- "Can't solve constraint"
- "Undefined name"
- "Type mismatch"
- "Can't find import"
- "Parse error"
- And more...

## License

Part of the TypedContract project.
