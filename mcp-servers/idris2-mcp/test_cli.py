#!/usr/bin/env python3
"""
CLI tool to test Idris2 MCP Server functions directly
No MCP dependency required - tests the core logic
"""

import sys
import asyncio
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

# Import guideline functions (simulated, no MCP needed)
BASE_DIR = Path(__file__).parent.parent.parent
PROJECT_GUIDELINES = BASE_DIR / "docs" / "IDRIS2_CODE_GENERATION_GUIDELINES.md"
OFFICIAL_GUIDELINES_DIR = BASE_DIR / "docs" / "idris2-official-guidelines"


def simulate_search_guidelines(query: str, category: str = "all"):
    """Simulate search_guidelines tool"""
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

        for i, line in enumerate(lines):
            if query.lower() in line.lower():
                start = max(0, i - 2)
                end = min(len(lines), i + 5)
                context = '\n'.join(lines[start:end])

                results.append({
                    'file': file_path.name,
                    'line': i + 1,
                    'context': context
                })

                if len([r for r in results if r['file'] == file_path.name]) >= 3:
                    break

    return results[:10]


def simulate_get_guideline_section(topic: str):
    """Simulate get_guideline_section tool"""
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
        return None, f"Unknown topic: {topic}"

    file_path, section_name = section_map[topic]

    if not file_path.exists():
        return None, f"Guidelines not found at {file_path}"

    content = file_path.read_text(encoding='utf-8')
    lines = content.split('\n')

    section_lines = []
    in_section = False
    section_level = 0

    for line in lines:
        if section_name.lower() in line.lower() and line.startswith('#'):
            in_section = True
            section_level = len(line) - len(line.lstrip('#'))
            section_lines.append(line)
        elif in_section:
            if line.startswith('#'):
                current_level = len(line) - len(line.lstrip('#'))
                if current_level <= section_level:
                    break
            section_lines.append(line)

    if section_lines:
        return '\n'.join(section_lines), None
    else:
        return None, f"Section '{section_name}' not found"


def read_resource(uri: str):
    """Simulate resource reading"""
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
        return f"Unknown resource: {uri}"


def test_search():
    """Test search_guidelines"""
    print("=" * 70)
    print("TEST: search_guidelines")
    print("=" * 70)

    queries = [
        ("dependent types", "types"),
        ("linear", "all"),
        ("%inline", "pragmas"),
    ]

    for query, category in queries:
        print(f"\n🔍 Query: '{query}' (category: {category})")
        print("-" * 70)
        results = simulate_search_guidelines(query, category)
        print(f"Found {len(results)} results:")

        for i, r in enumerate(results[:3], 1):
            print(f"\n  [{i}] {r['file']} (line {r['line']})")
            context_preview = r['context'].replace('\n', '\n      ')[:200]
            print(f"      {context_preview}...")


def test_section():
    """Test get_guideline_section"""
    print("\n" + "=" * 70)
    print("TEST: get_guideline_section")
    print("=" * 70)

    topics = [
        "parser_constraints",
        "multiplicities",
        "dependent_types",
    ]

    for topic in topics:
        print(f"\n📖 Topic: '{topic}'")
        print("-" * 70)
        content, error = simulate_get_guideline_section(topic)

        if error:
            print(f"❌ Error: {error}")
        else:
            lines = content.split('\n')
            print(f"✅ Extracted {len(lines)} lines")
            preview = '\n'.join(lines[:15])
            print(f"\nPreview:\n{preview}")
            if len(lines) > 15:
                print(f"... ({len(lines) - 15} more lines)")


def test_resources():
    """Test resource reading"""
    print("\n" + "=" * 70)
    print("TEST: read_resource")
    print("=" * 70)

    resources = [
        "idris2://guidelines/project",
        "idris2://guidelines/syntax",
        "idris2://guidelines/types",
    ]

    for uri in resources:
        print(f"\n📚 Resource: {uri}")
        print("-" * 70)
        content = read_resource(uri)
        lines = content.split('\n')
        print(f"✅ Loaded {len(lines)} lines ({len(content)} bytes)")

        # Show first header
        for line in lines[:20]:
            if line.startswith('#'):
                print(f"   First header: {line}")
                break


def interactive_mode():
    """Interactive CLI for testing"""
    print("\n" + "=" * 70)
    print("🎮 INTERACTIVE MODE")
    print("=" * 70)
    print("\nCommands:")
    print("  search <query> [category]  - Search guidelines")
    print("  section <topic>            - Get guideline section")
    print("  resource <uri>             - Read resource")
    print("  list                       - List all topics/resources")
    print("  help                       - Show this help")
    print("  quit                       - Exit")
    print()

    while True:
        try:
            cmd = input("idris2-mcp> ").strip()

            if not cmd:
                continue

            if cmd == "quit":
                print("👋 Goodbye!")
                break

            elif cmd == "help":
                print("\nCommands:")
                print("  search <query> [category]")
                print("  section <topic>")
                print("  resource <uri>")
                print("  list")
                print("  quit")

            elif cmd == "list":
                print("\n📋 Available Topics:")
                topics = ["parser_constraints", "multiplicities", "dependent_types",
                         "interfaces", "modules", "views", "proofs", "ffi",
                         "pragmas_inline", "pragmas_foreign", "totality"]
                for t in topics:
                    print(f"  - {t}")

                print("\n📋 Available Resources:")
                resources = ["idris2://guidelines/project", "idris2://guidelines/syntax",
                           "idris2://guidelines/types", "idris2://guidelines/modules",
                           "idris2://guidelines/advanced", "idris2://guidelines/pragmas",
                           "idris2://guidelines/index"]
                for r in resources:
                    print(f"  - {r}")

            elif cmd.startswith("search "):
                parts = cmd.split(maxsplit=2)
                query = parts[1] if len(parts) > 1 else ""
                category = parts[2] if len(parts) > 2 else "all"

                if query:
                    results = simulate_search_guidelines(query, category)
                    print(f"\n🔍 Found {len(results)} results for '{query}':")
                    for i, r in enumerate(results[:5], 1):
                        print(f"\n[{i}] {r['file']} (line {r['line']})")
                        print(r['context'][:200] + "...")
                else:
                    print("❌ Usage: search <query> [category]")

            elif cmd.startswith("section "):
                topic = cmd.split(maxsplit=1)[1] if len(cmd.split()) > 1 else ""

                if topic:
                    content, error = simulate_get_guideline_section(topic)
                    if error:
                        print(f"❌ {error}")
                    else:
                        lines = content.split('\n')
                        print(f"\n📖 Section '{topic}' ({len(lines)} lines):\n")
                        print('\n'.join(lines[:30]))
                        if len(lines) > 30:
                            print(f"\n... ({len(lines) - 30} more lines)")
                else:
                    print("❌ Usage: section <topic>")

            elif cmd.startswith("resource "):
                uri = cmd.split(maxsplit=1)[1] if len(cmd.split()) > 1 else ""

                if uri:
                    content = read_resource(uri)
                    lines = content.split('\n')
                    print(f"\n📚 Resource '{uri}' ({len(lines)} lines):\n")
                    print('\n'.join(lines[:30]))
                    if len(lines) > 30:
                        print(f"\n... ({len(lines) - 30} more lines)")
                else:
                    print("❌ Usage: resource <uri>")

            else:
                print(f"❌ Unknown command: {cmd}")
                print("   Type 'help' for available commands")

        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except EOFError:
            print("\n\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")


def main():
    """Main entry point"""
    if len(sys.argv) > 1 and sys.argv[1] == "--interactive":
        interactive_mode()
    else:
        print("🧪 Idris2 MCP Server - CLI Test Suite")
        print("=" * 70)

        test_search()
        test_section()
        test_resources()

        print("\n" + "=" * 70)
        print("✅ All tests completed!")
        print("=" * 70)
        print("\nTip: Run with --interactive for interactive mode")
        print("     python test_cli.py --interactive")


if __name__ == "__main__":
    main()
