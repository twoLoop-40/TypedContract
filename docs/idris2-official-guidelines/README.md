# Idris2 Official Guidelines - Knowledge Base

**Purpose**: Comprehensive, structured Idris2 documentation for AI agents and developers

**Source**: Official Idris2 Documentation (https://idris2.readthedocs.io/)

**Last Updated**: 2025-10-27

---

## 📚 Contents

### [01-SYNTAX-BASICS.md](./01-SYNTAX-BASICS.md)
Fundamental Idris2 syntax and language constructs

**Topics**:
- Primitive types (Int, String, Bool, etc.)
- Function definitions and pattern matching
- Data types (basic, parameterized, dependent)
- Records
- List comprehensions
- I/O and do-notation
- Implicit arguments
- Common imports

**Use When**: Starting with Idris2, need basic syntax reference

---

### [02-TYPE-SYSTEM.md](./02-TYPE-SYSTEM.md)
Idris2's advanced type system features

**Topics**:
- **Multiplicities** (0/1/unrestricted) - QTT
- Linear types and resource protocols
- Dependent types and dependent functions
- Implicit and auto-implicit arguments
- Pattern matching on types
- Equality types and decidable equality
- Interfaces (type classes)
- Totality checking
- Proofs and theorems
- Type-level computation

**Use When**: Working with dependent types, proofs, or resource management

---

### [03-MODULES-NAMESPACES.md](./03-MODULES-NAMESPACES.md)
Module system and code organization

**Topics**:
- Module structure and file naming
- Export modifiers (private, export, public export)
- Visibility rules
- Import statements (basic, public re-export, aliased)
- Namespaces and qualified access
- Parameterised blocks
- Fixity declarations
- Standard library structure
- Module best practices

**Use When**: Organizing code, controlling visibility, or resolving name conflicts

---

### [04-ADVANCED-PATTERNS.md](./04-ADVANCED-PATTERNS.md)
Advanced language features and patterns

**Topics**:
- Views and the `with` rule
- Theorem proving techniques
- Dependent pattern matching
- Interactive editing workflow
- Elaborator reflection (metaprogramming)
- Advanced interface usage
- Foreign Function Interface (FFI)
- Performance optimization pragmas
- Common patterns (smart constructors, state machines, refinement types)

**Use When**: Need advanced features, proofs, metaprogramming, or FFI

---

### [05-PRAGMAS-REFERENCE.md](./05-PRAGMAS-REFERENCE.md)
Complete pragma reference

**Topics**:
- **Global pragmas**: %language, %default, %builtin, %logging, etc.
- **Declaration pragmas**: %inline, %foreign, %export, %hint, etc.
- **Expression pragmas**: %runElab, %search, %syntactic
- Common pragma combinations
- Performance tuning
- FFI integration
- Debugging and development

**Use When**: Need compiler directives, optimization, or FFI declarations

---

## 🎯 Quick Reference by Task

### Starting a New Module
1. Read: **01-SYNTAX-BASICS.md** (Module structure)
2. Read: **03-MODULES-NAMESPACES.md** (Export modifiers)

### Working with Dependent Types
1. Read: **02-TYPE-SYSTEM.md** (Dependent types section)
2. Read: **04-ADVANCED-PATTERNS.md** (Dependent pattern matching)

### Proving Theorems
1. Read: **02-TYPE-SYSTEM.md** (Proofs and theorems)
2. Read: **04-ADVANCED-PATTERNS.md** (Theorem proving)

### Performance Optimization
1. Read: **05-PRAGMAS-REFERENCE.md** (%inline, %builtin, %spec)
2. Read: **04-ADVANCED-PATTERNS.md** (Performance tips)

### Using Linear Types
1. Read: **02-TYPE-SYSTEM.md** (Multiplicities section)
2. Read: **04-ADVANCED-PATTERNS.md** (Resource protocols)

### Foreign Function Interface
1. Read: **05-PRAGMAS-REFERENCE.md** (%foreign, %export)
2. Read: **04-ADVANCED-PATTERNS.md** (FFI section)

### Metaprogramming
1. Read: **05-PRAGMAS-REFERENCE.md** (%language ElabReflection, %macro)
2. Read: **04-ADVANCED-PATTERNS.md** (Elaborator reflection)

---

## 🚨 Critical Rules (Must Follow)

These rules override general guidelines and prevent parser errors:

### 1. Short Parameter Names
**❌ FAILS** (3+ params with long names):
```idris
data Expense : Type where
  MkExpense : (govSupport : Nat) -> (cashMatch : Nat) -> (inKindMatch : Nat) -> Expense
```

**✅ WORKS** (short names):
```idris
data Expense : Type where
  MkExpense : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> Expense
```

**See**: Project-specific `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md`

### 2. Use Operators, Not Functions
**❌ FAILS**:
```idris
(pf : total = plus supply vat)
```

**✅ WORKS**:
```idris
(pf : total = supply + vat)
```

### 3. One-Line Declarations Preferred
Multi-line indentation is fragile and can cause parser errors.

---

## 📖 Additional Resources

### Official Documentation
- Main Docs: https://idris2.readthedocs.io/
- API Reference: https://idris-lang.github.io/Idris2/
- Community Docs: https://idris2docs.sinyax.net/

### Learning Resources
- Type-Driven Development with Idris (book)
- Functional Programming in Idris 2 (tutorial)
- Elaborator Reflection Tutorial

### Tools
- Pack (package manager): https://github.com/stefan-hoeck/idris2-pack
- Third-party libraries: https://github.com/idris-lang/Idris2/wiki/Third-party-Libraries

---

## 🤖 For AI Agents

### Context Window Management

**When to load which files**:

1. **Always load first** (if generating Idris2 code):
   - Project `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md` (critical parser rules)

2. **Load based on query**:
   - Syntax question → `01-SYNTAX-BASICS.md`
   - Type system → `02-TYPE-SYSTEM.md`
   - Module organization → `03-MODULES-NAMESPACES.md`
   - Advanced features → `04-ADVANCED-PATTERNS.md`
   - Pragma usage → `05-PRAGMAS-REFERENCE.md`

3. **Load on-demand** (search within file):
   - Specific pragma → Search `05-PRAGMAS-REFERENCE.md`
   - Specific pattern → Search `04-ADVANCED-PATTERNS.md`

### Query Examples

**Q**: "How do I define a dependent function?"
**A**: Load `02-TYPE-SYSTEM.md` → "Dependent Types" → "Dependent Functions"

**Q**: "What's the syntax for linear types?"
**A**: Load `02-TYPE-SYSTEM.md` → "Multiplicities" → "Syntax"

**Q**: "How do I inline a function?"
**A**: Load `05-PRAGMAS-REFERENCE.md` → Search "%inline"

**Q**: "How do I prove a theorem?"
**A**: Load `04-ADVANCED-PATTERNS.md` → "Theorem Proving"

---

## 📝 Maintenance

### Updating Guidelines

When official Idris2 docs change:

1. Update affected `.md` files
2. Update `Last Updated` date
3. Update version compatibility notes
4. Update MCP server resources if needed

### Adding New Sections

1. Create new `NN-TOPIC.md` file
2. Update this README with new section
3. Update "Quick Reference by Task"
4. Update MCP server tool mappings

---

## Version Compatibility

**Idris2 Version**: v0.7.0+

**Notes**:
- These guidelines are based on Idris2 v0.7.0 documentation
- Check official docs for version-specific changes
- Some features may be experimental or unstable

---

## License

These guidelines are derived from official Idris2 documentation, published under Creative Commons CC0 License.

**Original Source**: https://idris2.readthedocs.io/
