# Idris2 MCP Server (Enhanced)

**Version**: 2.0.0
**Last Updated**: 2025-10-27

MCP (Model Context Protocol) server for Idris2 type-checking, syntax validation, code generation assistance, and **intelligent guideline access** from official documentation.

---

## 🎯 What's New in v2.0

### Intelligent Guideline System

- **7 Structured Resources** - Organized official Idris2 documentation
- **Contextual Search** - Find relevant guidelines by keyword
- **Section Extraction** - Get focused information without loading entire documents
- **Project-Specific Rules** - Critical parser constraints discovered during development

### Key Improvements

1. **`search_guidelines`** - Search across all guidelines for specific topics
2. **`get_guideline_section`** - Extract focused sections (e.g., "multiplicities", "proofs", "FFI")
3. **7 Resource URIs** - Access full guideline documents:
   - `idris2://guidelines/project` - Project-specific critical rules
   - `idris2://guidelines/syntax` - Syntax basics
   - `idris2://guidelines/types` - Type system (dependent types, QTT, proofs)
   - `idris2://guidelines/modules` - Module system
   - `idris2://guidelines/advanced` - Advanced patterns (views, FFI, metaprogramming)
   - `idris2://guidelines/pragmas` - Complete pragma reference
   - `idris2://guidelines/index` - Quick reference and overview

---

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

**Reference**: See `idris2://guidelines/project` resource or `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md` for full details.

---

## 📚 Resources

### Available Resource URIs

| URI | Description | Use When |
|-----|-------------|----------|
| `idris2://guidelines/project` | Project-specific parser rules | **Always read first** when generating code |
| `idris2://guidelines/syntax` | Basic syntax and constructs | Learning Idris2, basic syntax questions |
| `idris2://guidelines/types` | Type system features | Working with dependent types, proofs, QTT |
| `idris2://guidelines/modules` | Module organization | Organizing code, imports, visibility |
| `idris2://guidelines/advanced` | Advanced patterns | Views, theorem proving, FFI, metaprogramming |
| `idris2://guidelines/pragmas` | Pragma reference | Need compiler directives, optimization |
| `idris2://guidelines/index` | Quick reference | Overview, finding right document |

---

## 🛠️ Tools

### 1. **check_idris2** - Type-check Idris2 code

**Parameters**:
- `code` (string) - Idris2 source code
- `module_name` (string) - Module name (e.g., `Domains.MyContract`)

**Returns**: Compiler output (success or error messages)

**Example**:
```json
{
  "code": "module Test\n\nfoo : Nat\nfoo = 42",
  "module_name": "Test"
}
```

---

### 2. **explain_error** - Plain language error explanations

**Parameters**:
- `error_message` (string) - Idris2 compiler error
- `code_snippet` (string, optional) - Relevant code

**Returns**: Human-readable explanation and common fixes

---

### 3. **get_template** - Generate code templates

**Parameters**:
- `pattern` (enum) - `record`, `data`, `interface`, `proof`, `smart_constructor`
- `name` (string) - Name for generated code

**Returns**: Ready-to-use Idris2 code template

**Example**:
```json
{
  "pattern": "smart_constructor",
  "name": "Positive"
}
```

Returns:
```idris
public export
data Positive : Type where
  MkPositive : (val : Nat) -> (ok : val > 0) -> Positive

public export
mkPositive : (n : Nat) -> {auto prf : LTE 1 n} -> Positive
mkPositive n {prf} = MkPositive n prf
```

---

### 4. **validate_syntax** - Quick syntax validation

**Parameters**:
- `code` (string) - Idris2 code to validate

**Returns**: List of potential syntax issues (before full type-checking)

**Features**:
- Detects long parameter names (critical parser constraint)
- Checks unmatched parentheses
- Validates `where` placement
- Checks data type declarations

---

### 5. **suggest_fix** - Intelligent error fix suggestions

**Parameters**:
- `error_message` (string) - Idris2 error message
- `code` (string) - Original code

**Returns**: Prioritized fix suggestions with examples

**Special Features**:
- Detects parser errors from long parameter names
- Suggests using operators instead of functions
- Recommends relevant guideline resources

---

### 6. **search_guidelines** ⭐ NEW

**Parameters**:
- `query` (string) - Search query (e.g., `"dependent types"`, `"linear"`, `"%inline"`)
- `category` (enum, optional) - `all`, `syntax`, `types`, `modules`, `advanced`, `pragmas`

**Returns**: Relevant excerpts from guidelines with context

**Example**:
```json
{
  "query": "multiplicities",
  "category": "types"
}
```

Returns sections from `02-TYPE-SYSTEM.md` containing "multiplicities" with surrounding context.

---

### 7. **get_guideline_section** ⭐ NEW

**Parameters**:
- `topic` (enum) - Specific topic:
  - `parser_constraints` - Critical parser rules
  - `multiplicities` - QTT and linear types
  - `dependent_types` - Dependent type patterns
  - `interfaces` - Type classes
  - `modules` - Module organization
  - `views` - Views and `with` rule
  - `proofs` - Theorem proving
  - `ffi` - Foreign Function Interface
  - `pragmas_inline` - %inline pragma
  - `pragmas_foreign` - %foreign pragma
  - `totality` - Totality checking

**Returns**: Focused section from guidelines (not entire document)

**Example**:
```json
{
  "topic": "dependent_types"
}
```

Returns only the "Dependent Types" section from `02-TYPE-SYSTEM.md`.

---

## 💡 Usage Patterns

### Pattern 1: Before Generating Code

```
1. Read: idris2://guidelines/project (critical rules)
2. Search: search_guidelines("similar pattern")
3. Generate: (your code)
4. Validate: validate_syntax
5. Check: check_idris2
6. Fix errors: suggest_fix (if needed)
```

### Pattern 2: Learning a Feature

```
1. Overview: Read idris2://guidelines/index
2. Search: search_guidelines("feature name")
3. Deep dive: get_guideline_section("specific topic")
4. Template: get_template (if applicable)
5. Practice: check_idris2
```

### Pattern 3: Debugging Errors

```
1. Error occurs: check_idris2 fails
2. Explain: explain_error
3. Fix suggestions: suggest_fix
4. Search guidelines: search_guidelines("error keyword")
5. Apply fix and retry
```

---

## 🔧 Installation

Add to `.mcp-config.json`:

```json
{
  "mcpServers": {
    "idris2-helper": {
      "command": "python",
      "args": ["/path/to/mcp-servers/idris2-mcp/server.py"],
      "description": "Enhanced Idris2 type-checking and intelligent guideline access"
    }
  }
}
```

**Requirements**:
- Python 3.11+
- Idris2 v0.7.0+ (for `check_idris2` tool)
- `mcp` Python package

---

## 📖 Related Resources

### Project Documentation
- **Guidelines**: `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md`
- **Official Guidelines**: `docs/idris2-official-guidelines/`
- **Skill**: `~/.claude/skills/formal-spec-driven-dev/skill.md`
- **Project**: `CLAUDE.md`

### External Resources
- [Official Idris2 Docs](https://idris2.readthedocs.io/)
- [API Reference](https://idris-lang.github.io/Idris2/)
- [Community Docs](https://idris2docs.sinyax.net/)

---

## 🎓 Example: Using the Server

### Scenario: Implementing a Contract Type

**Step 1: Check critical rules**
```
Read resource: idris2://guidelines/project
→ Learn about parser constraints
```

**Step 2: Search for similar patterns**
```
Tool: search_guidelines
Query: "proof term"
Category: "types"
→ Find examples of dependent types with proofs
```

**Step 3: Get detailed info**
```
Tool: get_guideline_section
Topic: "dependent_types"
→ Learn about dependent types in detail
```

**Step 4: Generate template**
```
Tool: get_template
Pattern: "proof"
Name: "ContractValid"
→ Get proof type template
```

**Step 5: Validate and check**
```
Tool: validate_syntax → Check for parser issues
Tool: check_idris2 → Full type-check
Tool: suggest_fix (if errors) → Get fix suggestions
```

---

## 🚀 Future Enhancements

- [ ] Add caching for frequently accessed guidelines
- [ ] Support for custom project-specific guidelines
- [ ] Integration with REPL for interactive queries
- [ ] Code generation from natural language descriptions
- [ ] Automatic refactoring suggestions

---

## 📝 Changelog

### v2.0.0 (2025-10-27)
- ✨ Added 7 structured resource URIs for official guidelines
- ✨ Added `search_guidelines` tool for keyword search
- ✨ Added `get_guideline_section` tool for focused retrieval
- ✨ Enhanced `validate_syntax` with long parameter name detection
- ✨ Organized official Idris2 documentation in `docs/idris2-official-guidelines/`
- 🐛 Fixed `suggest_fix` to recommend guideline resources
- 📚 Comprehensive documentation updates

### v1.0.0 (2025-10-27)
- Initial release with basic type-checking and validation
- Project-specific guideline resource

---

**Version**: 2.0.0
**License**: MIT
**Maintainer**: TypedContract Project
