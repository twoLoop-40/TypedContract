# Idris2 MCP Server

MCP (Model Context Protocol) server for Idris2 type-checking, syntax validation, and code generation assistance.

## 🚨 CRITICAL: Code Generation Rules

**Before generating any Idris2 code, be aware of these parser constraints**:

### 1. Short Parameter Names (MOST IMPORTANT!)
```idris
-- ❌ FAILS: Long names with 3+ params → Parser Error
data Expense : Type where
  MkExpense : (govSupport : Nat) -> (cashMatch : Nat) -> (inKindMatch : Nat) -> Expense

-- ✅ WORKS: Short names (≤8 chars)
data Expense : Type where
  MkExpense : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> Expense
```

**Why**: Idris2 parser fails when data constructors have 3+ parameters with long names (>8 characters) on one line.

### 2. Use Operators, Not Functions
```idris
-- ❌ FAILS: plus/minus don't exist in Prelude
(pf : total = plus supply vat)

-- ✅ WORKS: Use operators
(pf : total = supply + vat)
```

### 3. One-Line Declarations Preferred
Multi-line indentation can cause parser errors. Prefer one-line declarations.

**Reference**: See `idris2://guidelines` resource or `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md` for full details.

## Resources

### `idris2://guidelines`
Comprehensive Idris2 code generation guidelines document - **READ THIS FIRST!**

## Tools

1. **check_idris2** - Type-check Idris2 code
2. **explain_error** - Plain language error explanations
3. **get_template** - Generate code templates
4. **validate_syntax** - Quick syntax validation
5. **suggest_fix** - Intelligent error fix suggestions (includes parser error detection)

## Installation

Add to `.mcp-config.json`:
```json
{
  "mcpServers": {
    "idris2-helper": {
      "command": "python",
      "args": ["/path/to/mcp-servers/idris2-mcp/server.py"],
      "description": "Idris2 type-checking and code generation tools"
    }
  }
}
```

## Related Resources

- Guidelines: `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md`
- Skill: `~/.claude/skills/formal-spec-driven-dev/skill.md`
- Project: `CLAUDE.md`

**Version**: 1.0.0 | **Updated**: 2025-10-27
