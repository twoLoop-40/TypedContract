#!/usr/bin/env python3
"""
Idris2 MCP Server (Enhanced)
Provides tools for Idris2 type-checking, syntax validation, code generation,
and contextual guideline access from official documentation
"""

import asyncio
import subprocess
import tempfile
import re
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

# Path to guidelines documents
BASE_DIR = Path(__file__).parent.parent.parent
PROJECT_GUIDELINES = BASE_DIR / "docs" / "IDRIS2_CODE_GENERATION_GUIDELINES.md"
OFFICIAL_GUIDELINES_DIR = BASE_DIR / "docs" / "idris2-official-guidelines"

# ============================================================================
# Resources
# ============================================================================

@server.list_resources()
async def handle_list_resources() -> list[Resource]:
    """List available resources"""
    resources = [
        Resource(
            uri="idris2://guidelines/project",
            name="Project-Specific Idris2 Guidelines",
            description="Critical parser constraints and best practices for this project",
            mimeType="text/markdown"
        ),
        Resource(
            uri="idris2://guidelines/syntax",
            name="Idris2 Syntax Basics",
            description="Fundamental syntax and language constructs",
            mimeType="text/markdown"
        ),
        Resource(
            uri="idris2://guidelines/types",
            name="Idris2 Type System",
            description="Advanced type system features (dependent types, multiplicities, proofs)",
            mimeType="text/markdown"
        ),
        Resource(
            uri="idris2://guidelines/modules",
            name="Modules and Namespaces",
            description="Module system and code organization",
            mimeType="text/markdown"
        ),
        Resource(
            uri="idris2://guidelines/advanced",
            name="Advanced Patterns",
            description="Views, theorem proving, FFI, metaprogramming",
            mimeType="text/markdown"
        ),
        Resource(
            uri="idris2://guidelines/pragmas",
            name="Pragmas Reference",
            description="Complete reference for all Idris2 pragmas",
            mimeType="text/markdown"
        ),
        Resource(
            uri="idris2://guidelines/index",
            name="Guidelines Index",
            description="Overview and quick reference for all guidelines",
            mimeType="text/markdown"
        )
    ]
    return resources


@server.read_resource()
async def handle_read_resource(uri: str) -> str:
    """Read resource content"""
    resource_map = {
        "idris2://guidelines/project": PROJECT_GUIDELINES,
        "idris2://guidelines/syntax": OFFICIAL_GUIDELINES_DIR / "01-SYNTAX-BASICS.md",
        "idris2://guidelines/types": OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md",
        "idris2://guidelines/modules": OFFICIAL_GUIDELINES_DIR / "03-MODULES-NAMESPACES.md",
        "idris2://guidelines/advanced": OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md",
        "idris2://guidelines/pragmas": OFFICIAL_GUIDELINES_DIR / "05-PRAGMAS-REFERENCE.md",
        "idris2://guidelines/index": OFFICIAL_GUIDELINES_DIR / "README.md",
    }

    if uri in resource_map:
        file_path = resource_map[uri]
        if file_path.exists():
            return file_path.read_text(encoding='utf-8')
        else:
            return f"Guidelines not found at {file_path}"
    else:
        raise ValueError(f"Unknown resource: {uri}")


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
        ),
        Tool(
            name="search_guidelines",
            description="Search Idris2 guidelines for specific topics or keywords",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query (e.g., 'dependent types', 'linear types', '%inline')"
                    },
                    "category": {
                        "type": "string",
                        "enum": ["all", "syntax", "types", "modules", "advanced", "pragmas"],
                        "description": "Limit search to specific category (default: all)"
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="get_guideline_section",
            description="Get specific section from guidelines (more focused than full resource)",
            inputSchema={
                "type": "object",
                "properties": {
                    "topic": {
                        "type": "string",
                        "enum": [
                            "parser_constraints",
                            "multiplicities",
                            "dependent_types",
                            "interfaces",
                            "modules",
                            "views",
                            "proofs",
                            "ffi",
                            "pragmas_inline",
                            "pragmas_foreign",
                            "totality"
                        ],
                        "description": "Specific topic to retrieve"
                    }
                },
                "required": ["topic"]
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
    elif name == "search_guidelines":
        return await search_guidelines(arguments)
    elif name == "get_guideline_section":
        return await get_guideline_section(arguments)
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
  Mk{name} : (val : Nat) -> (ok : val > 0) -> {name}

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

        # Check for long parameter names (critical!)
        if 'data' in stripped or 'constructor' in stripped.lower():
            params = re.findall(r'\((\w+)\s*:', stripped)
            if len(params) >= 3:
                long_params = [p for p in params if len(p) > 8]
                if long_params:
                    issues.append(f"Line {i}: 🚨 CRITICAL - Long parameter names detected: {', '.join(long_params)}")
                    issues.append(f"         Parser may fail with 3+ params having long names (>8 chars)")

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

    # ⚠️ CRITICAL: Parser errors from long parameter names
    if "Expected 'case', 'if', 'do', application or operator expression" in error_msg:
        suggestions.append("🚨 CRITICAL: This is likely caused by LONG PARAMETER NAMES in data constructors!")
        suggestions.append("Idris2 parser fails when 3+ parameters with long names (>8 chars) are on one line")
        suggestions.append("FIX: Shorten parameter names to 6-8 characters or less")
        suggestions.append("Example: Change (govSupport : Nat) -> (cashMatch : Nat) -> (inKindMatch : Nat)")
        suggestions.append("     To: (gov : Nat) -> (cash : Nat) -> (inKind : Nat)")
        suggestions.append("📖 See: idris2://guidelines/project resource for full details")

    elif "Expected a type declaration" in error_msg:
        suggestions.append("Add a type signature before the constructor in 'data' declarations")
        suggestions.append("Example: data MyType : Type where")
        suggestions.append("OR: Check if the line above has syntax issues (unmatched parens, long names)")

    elif "Can't find name plus" in error_msg or "Can't find name minus" in error_msg:
        suggestions.append("Use operators (+, -, *, /) instead of function names (plus, minus, mult)")
        suggestions.append("Example: Change (pf : total = plus supply vat) to (pf : total = supply + vat)")

    elif "Undefined name" in error_msg:
        suggestions.append("Check if you've imported the required module")
        suggestions.append("Verify the spelling of the identifier")
        suggestions.append("📖 Use search_guidelines tool to find correct import")

    elif "Type mismatch" in error_msg:
        suggestions.append("Check that your types align correctly")
        suggestions.append("Use :t in REPL to check inferred types")
        suggestions.append("📖 See: idris2://guidelines/types for type system help")

    if not suggestions:
        suggestions.append("Try breaking down complex type signatures")
        suggestions.append("Check idris2://guidelines/* resources for common patterns")
        suggestions.append("Ensure parameter names are SHORT (6-8 chars max)")

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

💡 **Tip**: Use the `search_guidelines` tool to find relevant documentation!
"""

    return [TextContent(type="text", text=response)]


async def search_guidelines(args: dict) -> list[TextContent]:
    """Search guidelines for specific topics"""
    query = args["query"].lower()
    category = args.get("category", "all")

    # Determine which files to search
    search_files = []
    if category == "all":
        search_files = list(OFFICIAL_GUIDELINES_DIR.glob("*.md"))
        search_files.append(PROJECT_GUIDELINES)
    elif category == "syntax":
        search_files = [OFFICIAL_GUIDELINES_DIR / "01-SYNTAX-BASICS.md"]
    elif category == "types":
        search_files = [OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md"]
    elif category == "modules":
        search_files = [OFFICIAL_GUIDELINES_DIR / "03-MODULES-NAMESPACES.md"]
    elif category == "advanced":
        search_files = [OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md"]
    elif category == "pragmas":
        search_files = [OFFICIAL_GUIDELINES_DIR / "05-PRAGMAS-REFERENCE.md"]

    results = []

    for file_path in search_files:
        if not file_path.exists():
            continue

        content = file_path.read_text(encoding='utf-8')
        lines = content.split('\n')

        # Search for query in headers and surrounding content
        for i, line in enumerate(lines):
            if query in line.lower():
                # Get context (surrounding lines)
                start = max(0, i - 2)
                end = min(len(lines), i + 5)
                context = '\n'.join(lines[start:end])

                results.append({
                    'file': file_path.name,
                    'line': i + 1,
                    'context': context
                })

                # Limit results per file
                if len([r for r in results if r['file'] == file_path.name]) >= 3:
                    break

    if results:
        response = f"## Search Results for '{query}'\n\n"
        for r in results[:10]:  # Limit total results
            response += f"### {r['file']} (line {r['line']})\n```\n{r['context']}\n```\n\n"
    else:
        response = f"No results found for '{query}'. Try broader terms or check the index at idris2://guidelines/index"

    return [TextContent(type="text", text=response)]


async def get_guideline_section(args: dict) -> list[TextContent]:
    """Get specific guideline section"""
    topic = args["topic"]

    # Map topics to file sections
    section_map = {
        "parser_constraints": (PROJECT_GUIDELINES, "Parser 제약사항"),
        "multiplicities": (OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md", "Multiplicities"),
        "dependent_types": (OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md", "Dependent Types"),
        "interfaces": (OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md", "Interfaces"),
        "modules": (OFFICIAL_GUIDELINES_DIR / "03-MODULES-NAMESPACES.md", "Module Structure"),
        "views": (OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md", "Views"),
        "proofs": (OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md", "Theorem Proving"),
        "ffi": (OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md", "Foreign Function Interface"),
        "pragmas_inline": (OFFICIAL_GUIDELINES_DIR / "05-PRAGMAS-REFERENCE.md", "%inline"),
        "pragmas_foreign": (OFFICIAL_GUIDELINES_DIR / "05-PRAGMAS-REFERENCE.md", "%foreign"),
        "totality": (OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md", "Totality"),
    }

    if topic not in section_map:
        return [TextContent(type="text", text=f"Unknown topic: {topic}")]

    file_path, section_name = section_map[topic]

    if not file_path.exists():
        return [TextContent(type="text", text=f"Guidelines not found at {file_path}")]

    content = file_path.read_text(encoding='utf-8')
    lines = content.split('\n')

    # Find section
    section_lines = []
    in_section = False
    section_level = 0

    for line in lines:
        if section_name.lower() in line.lower() and line.startswith('#'):
            in_section = True
            section_level = len(line) - len(line.lstrip('#'))
            section_lines.append(line)
        elif in_section:
            # Check if we've hit a same-level or higher-level header
            if line.startswith('#'):
                current_level = len(line) - len(line.lstrip('#'))
                if current_level <= section_level:
                    break
            section_lines.append(line)

    if section_lines:
        response = '\n'.join(section_lines)
    else:
        response = f"Section '{section_name}' not found in {file_path.name}"

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
                server_version="2.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


if __name__ == "__main__":
    asyncio.run(main())
