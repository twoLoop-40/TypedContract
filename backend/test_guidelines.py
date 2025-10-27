#!/usr/bin/env python3
"""Test script for load_idris2_guidelines function"""

from pathlib import Path

def load_idris2_guidelines() -> dict:
    """
    Load Idris2 guidelines for prompt caching

    Loads from docs/IDRIS2_CODE_GENERATION_GUIDELINES.md (used by MCP server)

    Returns:
        dict with 'text' and 'cache_control' for Anthropic API, or None if not found
    """
    # Idris2 코드 생성 가이드라인 경로 (MCP 서버와 동일)
    project_root = Path(__file__).parent.parent
    guidelines_path = project_root / "docs" / "IDRIS2_CODE_GENERATION_GUIDELINES.md"

    print(f"Looking for guidelines at: {guidelines_path}")

    if not guidelines_path.exists():
        print(f"⚠️ Idris2 guidelines not found at {guidelines_path}")
        return None

    try:
        content = guidelines_path.read_text(encoding='utf-8')
        print(f"✅ Loaded guidelines ({len(content)} chars)")

        # Anthropic prompt caching format
        return {
            "type": "text",
            "text": content,
            "cache_control": {"type": "ephemeral"}  # 5분간 캐시
        }
    except Exception as e:
        print(f"⚠️ Failed to load guidelines: {e}")
        return None


if __name__ == "__main__":
    print("Testing load_idris2_guidelines()...")
    print("="*60)

    guidelines = load_idris2_guidelines()

    if guidelines:
        print("\n✅ Guidelines loaded successfully!")
        print(f"   Type: {guidelines['type']}")
        print(f"   Cache control: {guidelines['cache_control']}")
        print(f"   Total content length: {len(guidelines['text'])} characters")
        print()
        print("Preview (first 500 chars):")
        print("-"*60)
        print(guidelines["text"][:500])
        print("-"*60)
    else:
        print("\n❌ Failed to load guidelines")
