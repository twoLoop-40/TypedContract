#!/usr/bin/env python3
"""
Idris2 MCP Server
Provides tools for Idris2 type-checking, syntax validation, and code generation
"""

import asyncio
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from mcp.server.models import InitializationOptions
from mcp.server import NotificationOptions, Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    Resource,
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
)

# Initialize MCP server
server = Server("idris2-helper")

# ============================================================================
# Tools
# ============================================================================

@server.list_tools()
async def handle_list_tools() -> list[Tool]:
    """List available Idris2 tools"""
    return [
        Tool(
            name="check_idris2",
            description="Type-check Idris2 code and return compiler output",
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Idris2 source code to check"
                    },
                    "module_name": {
                        "type": "string",
                        "description": "Module name (e.g., 'Domains.MyContract')"
                    }
                },
                "required": ["code", "module_name"]
            }
        ),
        Tool(
            name="explain_error",
            description="Explain Idris2 compiler error in plain language with suggestions",
            inputSchema={
                "type": "object",
                "properties": {
                    "error_message": {
                        "type": "string",
                        "description": "Idris2 compiler error message"
                    },
                    "code_snippet": {
                        "type": "string",
                        "description": "Relevant code snippet (optional)"
                    }
                }
            }
        ),
        Tool(
            name="get_template",
            description="Get Idris2 code template for common patterns",
            inputSchema={
                "type": "object",
                "properties": {
                    "pattern": {
                        "type": "string",
                        "enum": ["record", "data", "interface", "proof", "smart_constructor"],
                        "description": "Type of template to generate"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name for the generated code"
                    }
                },
                "required": ["pattern", "name"]
            }
        ),
        Tool(
            name="validate_syntax",
            description="Quick syntax validation without full type-checking",
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Idris2 code to validate"
                    }
                },
                "required": ["code"]
            }
        ),
        Tool(
            name="suggest_fix",
            description="Suggest fixes for common Idris2 errors",
            inputSchema={
                "type": "object",
                "properties": {
                    "error_message": {
                        "type": "string",
                        "description": "Idris2 error message"
                    },
                    "code": {
                        "type": "string",
                        "description": "Original code"
                    }
                },
                "required": ["error_message", "code"]
            }
        )
    ]


@server.call_tool()
async def handle_call_tool(name: str, arguments: dict[str, Any] | None) -> list[TextContent]:
    """Handle tool execution"""

    if name == "check_idris2":
        return await check_idris2_code(arguments)
    elif name == "explain_error":
        return await explain_idris2_error(arguments)
    elif name == "get_template":
        return await get_idris2_template(arguments)
    elif name == "validate_syntax":
        return await validate_idris2_syntax(arguments)
    elif name == "suggest_fix":
        return await suggest_idris2_fix(arguments)
    else:
        raise ValueError(f"Unknown tool: {name}")


# ============================================================================
# Tool Implementations
# ============================================================================

async def check_idris2_code(args: dict) -> list[TextContent]:
    """Type-check Idris2 code"""
    code = args["code"]
    module_name = args["module_name"]

    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.idr', delete=False) as f:
        f.write(code)
        temp_file = Path(f.name)

    try:
        # Run idris2 --check
        result = subprocess.run(
            ["idris2", "--check", str(temp_file)],
            capture_output=True,
            text=True,
            timeout=30
        )

        success = result.returncode == 0
        output = result.stdout + result.stderr

        if success:
            response = f"✅ Type-check successful!\n\n{output}"
        else:
            response = f"❌ Type-check failed:\n\n{output}"

        return [TextContent(type="text", text=response)]

    except subprocess.TimeoutExpired:
        return [TextContent(type="text", text="⏱️ Timeout: Type-checking took too long (>30s)")]
    except FileNotFoundError:
        return [TextContent(type="text", text="❌ Error: idris2 command not found. Is Idris2 installed?")]
    finally:
        temp_file.unlink(missing_ok=True)


async def explain_idris2_error(args: dict) -> list[TextContent]:
    """Explain Idris2 error in plain language"""
    error_msg = args["error_message"]

    # Common error patterns and explanations
    explanations = {
        "Expected": "This error means Idris2 expected a different type or construct than what you provided.",
        "Can't solve constraint": "Idris2 cannot prove the type-level constraint you specified. Check your type signatures and proof terms.",
        "Undefined name": "You're using a variable or function that hasn't been defined or imported.",
        "Type mismatch": "The type you provided doesn't match what Idris2 inferred or expected.",
        "Can't find import": "The module you're trying to import doesn't exist or isn't in the search path.",
    }

    explanation = "Unknown error type. Please check the Idris2 documentation."
    for pattern, desc in explanations.items():
        if pattern in error_msg:
            explanation = desc
            break

    response = f"""## Error Explanation

**Error Message:**
```
{error_msg}
```

**What this means:**
{explanation}

**Common fixes:**
- Check your type signatures
- Verify all imports are correct
- Ensure proof terms match the constraints
- Check for typos in variable names
"""

    return [TextContent(type="text", text=response)]


async def get_idris2_template(args: dict) -> list[TextContent]:
    """Get Idris2 code template"""
    pattern = args["pattern"]
    name = args["name"]

    templates = {
        "record": f"""public export
record {name} where
  constructor Mk{name}
  field1 : String
  field2 : Nat
""",
        "data": f"""public export
data {name} : Type where
  Constructor1 : {name}
  Constructor2 : String -> {name}
""",
        "interface": f"""public export
interface {name} a where
  method1 : a -> String
  method2 : a -> a -> a
""",
        "proof": f"""public export
data {name}Proof : (x : Nat) -> (y : Nat) -> Type where
  Mk{name}Proof : (x : Nat) -> (y : Nat) -> (prf : x = y) -> {name}Proof x y
""",
        "smart_constructor": f"""public export
data {name} : Type where
  Mk{name} : (value : Nat) -> (constraint : value > 0) -> {name}

public export
mk{name} : (n : Nat) -> {{auto prf : LTE 1 n}} -> {name}
mk{name} n {{prf}} = Mk{name} n prf
"""
    }

    template = templates.get(pattern, "# Template not found")

    return [TextContent(type="text", text=template)]


async def validate_idris2_syntax(args: dict) -> list[TextContent]:
    """Quick syntax validation"""
    code = args["code"]

    # Basic syntax checks
    issues = []

    lines = code.split('\n')
    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Check for common syntax issues
        if stripped.startswith('data') and ':' not in stripped:
            issues.append(f"Line {i}: 'data' declaration should have a type signature (: Type)")

        if 'where' in stripped and not stripped.endswith('where'):
            if 'where' in stripped.split()[:-1]:
                issues.append(f"Line {i}: 'where' should be at the end of the line")

        # Check for unmatched parentheses
        if stripped.count('(') != stripped.count(')'):
            issues.append(f"Line {i}: Unmatched parentheses")

    if issues:
        response = "⚠️ Potential syntax issues found:\n\n" + "\n".join(f"- {issue}" for issue in issues)
    else:
        response = "✅ No obvious syntax issues detected. Run type-check for full validation."

    return [TextContent(type="text", text=response)]


async def suggest_idris2_fix(args: dict) -> list[TextContent]:
    """Suggest fixes for Idris2 errors"""
    error_msg = args["error_message"]
    code = args["code"]

    suggestions = []

    if "Expected a type declaration" in error_msg:
        suggestions.append("Add a type signature before the constructor in 'data' declarations")
        suggestions.append("Example: data MyType : Type where")

    if "Undefined name" in error_msg:
        suggestions.append("Check if you've imported the required module")
        suggestions.append("Verify the spelling of the identifier")

    if "Type mismatch" in error_msg:
        suggestions.append("Check that your types align correctly")
        suggestions.append("Use :t in REPL to check inferred types")

    if not suggestions:
        suggestions.append("Try breaking down complex type signatures")
        suggestions.append("Check the Idris2 documentation for similar examples")

    response = f"""## Suggested Fixes

**Error:**
```
{error_msg}
```

**Suggestions:**
{chr(10).join(f'{i+1}. {s}' for i, s in enumerate(suggestions))}

**Code Context:**
```idris
{code[:200]}...
```
"""

    return [TextContent(type="text", text=response)]


# ============================================================================
# Main
# ============================================================================

async def main():
    """Run the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="idris2-helper",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


if __name__ == "__main__":
    asyncio.run(main())
