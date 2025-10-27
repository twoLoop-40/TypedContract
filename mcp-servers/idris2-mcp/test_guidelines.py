#!/usr/bin/env python3
"""
Test script for guideline system (without MCP dependency)
"""

from pathlib import Path

BASE_DIR = Path(__file__).parent.parent.parent
PROJECT_GUIDELINES = BASE_DIR / "docs" / "IDRIS2_CODE_GENERATION_GUIDELINES.md"
OFFICIAL_GUIDELINES_DIR = BASE_DIR / "docs" / "idris2-official-guidelines"

def test_guidelines_exist():
    """Test that all guideline files exist"""
    files = [
        PROJECT_GUIDELINES,
        OFFICIAL_GUIDELINES_DIR / "README.md",
        OFFICIAL_GUIDELINES_DIR / "01-SYNTAX-BASICS.md",
        OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md",
        OFFICIAL_GUIDELINES_DIR / "03-MODULES-NAMESPACES.md",
        OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md",
        OFFICIAL_GUIDELINES_DIR / "05-PRAGMAS-REFERENCE.md",
    ]

    print("=== Testing guideline files existence ===")
    all_exist = True
    for f in files:
        exists = f.exists()
        status = "✅" if exists else "❌"
        print(f"{status} {f.name}")
        if exists:
            size = f.stat().st_size
            print(f"   Size: {size:,} bytes")
        all_exist = all_exist and exists

    return all_exist


def test_search_simulation():
    """Simulate search_guidelines functionality"""
    print("\n=== Testing search simulation ===")
    query = "dependent types"

    search_file = OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md"
    if not search_file.exists():
        print(f"❌ File not found: {search_file}")
        return False

    content = search_file.read_text(encoding='utf-8')
    lines = content.split('\n')

    results = []
    for i, line in enumerate(lines):
        if query.lower() in line.lower():
            start = max(0, i - 2)
            end = min(len(lines), i + 3)
            context = '\n'.join(lines[start:end])
            results.append((i+1, context))
            if len(results) >= 3:
                break

    print(f"Query: '{query}'")
    print(f"Found {len(results)} results in {search_file.name}")
    for line_num, context in results:
        print(f"\nLine {line_num}:")
        print(context[:200] + "..." if len(context) > 200 else context)

    return len(results) > 0


def test_section_extraction():
    """Simulate get_guideline_section functionality"""
    print("\n=== Testing section extraction ===")
    topic = "Multiplicities"
    file_path = OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md"

    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        return False

    content = file_path.read_text(encoding='utf-8')
    lines = content.split('\n')

    section_lines = []
    in_section = False
    section_level = 0

    for line in lines:
        if topic.lower() in line.lower() and line.startswith('#'):
            in_section = True
            section_level = len(line) - len(line.lstrip('#'))
            section_lines.append(line)
        elif in_section:
            if line.startswith('#'):
                current_level = len(line) - len(line.lstrip('#'))
                if current_level <= section_level:
                    break
            section_lines.append(line)

    print(f"Topic: '{topic}'")
    print(f"Extracted {len(section_lines)} lines")
    if section_lines:
        preview = '\n'.join(section_lines[:10])
        print(f"\nPreview:\n{preview}")
        return True
    else:
        print("❌ Section not found")
        return False


def test_resource_mapping():
    """Test that all resource URIs map to valid files"""
    print("\n=== Testing resource URI mapping ===")

    resource_map = {
        "idris2://guidelines/project": PROJECT_GUIDELINES,
        "idris2://guidelines/syntax": OFFICIAL_GUIDELINES_DIR / "01-SYNTAX-BASICS.md",
        "idris2://guidelines/types": OFFICIAL_GUIDELINES_DIR / "02-TYPE-SYSTEM.md",
        "idris2://guidelines/modules": OFFICIAL_GUIDELINES_DIR / "03-MODULES-NAMESPACES.md",
        "idris2://guidelines/advanced": OFFICIAL_GUIDELINES_DIR / "04-ADVANCED-PATTERNS.md",
        "idris2://guidelines/pragmas": OFFICIAL_GUIDELINES_DIR / "05-PRAGMAS-REFERENCE.md",
        "idris2://guidelines/index": OFFICIAL_GUIDELINES_DIR / "README.md",
    }

    all_valid = True
    for uri, file_path in resource_map.items():
        exists = file_path.exists()
        status = "✅" if exists else "❌"
        print(f"{status} {uri}")
        print(f"   → {file_path}")
        all_valid = all_valid and exists

    return all_valid


def main():
    print("=" * 60)
    print("Idris2 MCP Server - Guideline System Test")
    print("=" * 60)

    tests = [
        ("Guideline files exist", test_guidelines_exist),
        ("Search simulation", test_search_simulation),
        ("Section extraction", test_section_extraction),
        ("Resource URI mapping", test_resource_mapping),
    ]

    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"❌ Error in {name}: {e}")
            results.append((name, False))

    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {name}")

    all_passed = all(r[1] for r in results)
    print("\n" + ("=" * 60))
    if all_passed:
        print("✅ All tests passed!")
    else:
        print("❌ Some tests failed")
    print("=" * 60)

    return 0 if all_passed else 1


if __name__ == "__main__":
    exit(main())
