# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

---

## 🚨 CRITICAL: Read This First

### Idris2 Code Generation
**Before generating any Idris2 code**: Read `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md`

**Top 3 Rules**:
1. ✅ **Short parameter names** (≤6-8 chars): `gov`, `cash`, `tot`
2. ✅ **Use operators**: `+`, `-` (NOT `plus`, `minus`)
3. ✅ **One-line constructors** preferred

```idris
-- ❌ FAILS: Long names with 3+ params
data Expense : Type where
  MkExpense : (govSupport : Nat) -> (cashMatch : Nat) -> (inKindMatch : Nat) -> Expense

-- ✅ WORKS: Short names
data Expense : Type where
  MkExpense : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> Expense
```

**Resources**: `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md` | `idris2://guidelines` (MCP)

### Known Issues & Solutions

**Backend State Sync** (`agent/main.py`):
- ⚠️ Background tasks must reload state: `WorkflowState.load()`
- ⚠️ Save immediately after changes: `.save(Path("./output"))`

**Frontend UX** (`frontend/app/project/[name]/page.tsx`):
- ✅ No auto-navigation after resume - users stay on page to monitor progress

**Phase Display** (`agent.py`):
- ⚠️ TODO: Update `current_phase` during Phase 3, 4 execution

---

## Project Overview

**TypedContract**: Type-safe contract generation system with dependent types

**Stack**:
- **Idris2**: Formal specifications + document generation
- **FastAPI**: Python backend with LangGraph agent
- **Next.js 14**: Frontend UI

**Key Features**:
- Compile-time correctness via dependent types
- Multi-format output (PDF, Markdown, CSV, Text)
- LangGraph-based document generation
- Real-time workflow monitoring

---

## Quick Start

### Prerequisites
```bash
# Required
brew install idris2           # Idris2 v0.7.0+
curl -LsSf https://astral.sh/uv/install.sh | sh  # uv (Python pkg manager)

# Create .env
cp .env.example .env
# Add: ANTHROPIC_API_KEY=sk-ant-api03-...
```

### Development (Docker)
```bash
docker-compose up --build      # Start all services
docker-compose logs -f backend # View logs
```

**Access**:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

### Development (Local)
```bash
# Backend
cd agent/
uv pip install --system -r requirements.txt
uvicorn agent.main:app --reload --host 0.0.0.0 --port 8000

# Frontend
cd frontend/
npm install
npm run dev
```

---

## Directory Structure

```
TypedContract/
├── Core/           # Idris2 document generation framework
├── Domains/        # Domain-specific models (examples)
├── Spec/           # Formal workflow specifications
│   ├── WorkflowTypes.idr       # State machine (10 phases)
│   ├── ErrorHandling.idr       # Error classification
│   ├── ProjectRecovery.idr     # Recovery strategies
│   ├── UIOperations.idr        # UI type system
│   └── WorkflowControl.idr     # Control flow
├── agent/          # FastAPI backend
│   ├── main.py               # REST API
│   ├── agent.py              # LangGraph workflow
│   ├── workflow_state.py     # State management
│   └── tests/                # Unit tests (17 passing)
├── frontend/       # Next.js 14 UI
├── mcp-servers/    # MCP servers
│   └── idris2-mcp/          # Idris2 helper tools
└── docs/           # Documentation
    ├── IDRIS2_CODE_GENERATION_GUIDELINES.md  # ⭐ Must read
    └── TYPE_SAFETY_VERIFICATION.md           # Spec verification
```

---

## Common Commands

### Idris2
```bash
# Type-check files
idris2 --check Core/DocumentModel.idr
idris2 --check Domains/ScaleDeep.idr
idris2 --check Spec/WorkflowTypes.idr
```

### Backend
```bash
cd agent/

# Run tests
pytest tests/ -v
pytest tests/test_workflow_state.py -v

# Run server
uvicorn agent.main:app --reload
```

### Frontend
```bash
cd frontend/

npm run dev    # Development
npm run build  # Production build
npm run lint   # Lint
```

### Git Workflow
```bash
# Commit changes (auto-formats commit message)
git add .
git commit -m "Your message

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push
```

---

## Architecture

### Layer 1: Idris2 Core (`Core/`)
Document generation framework with type-safe multi-format rendering.

**Key Pattern**: `Documentable` interface
```idris
interface Documentable a where
  toDocument : a -> Document

-- Automatic rendering to all formats
doc = toDocument myDomainModel
pdf = renderLaTeX doc
md = renderMarkdown doc
```

### Layer 2: Domain Models (`Domains/`)
Business types with compile-time proofs.

**Example**: `Domains/ScaleDeep.idr` - Service contract with arithmetic proof

### Layer 3: Specifications (`Spec/`)
Formal workflow specifications guiding Python implementation.

### Layer 4: Backend (`agent/`)
LangGraph agent orchestrating Idris2 compilation and document generation.

**10-Phase Workflow**: Init → Analysis → Spec Gen → Compilation → Error Handling → Doc Impl → Draft → Feedback → Refinement → Final

### Layer 5: Frontend (`frontend/`)
Next.js UI for project creation, monitoring, and document preview.

---

## Key Patterns

### Dependent Types (Idris2)
```idris
-- Compile-time proof of arithmetic correctness
data UnitPrice : Type where
  MkUnitPrice : (item : Nat) -> (qty : Nat) -> (tot : Nat)
    -> (pf : tot = item * qty)  -- Proof!
    -> UnitPrice

-- Smart constructor auto-generates proof
mkUnitPrice : (item : Nat) -> (qty : Nat) -> UnitPrice
mkUnitPrice item qty = MkUnitPrice item qty (item * qty) Refl
```

### State Management (Python)
```python
# ✅ GOOD: Reload in background tasks
def run_in_background():
    current_state = WorkflowState.load(project_name, Path("./output"))
    try:
        updated = run_workflow(current_state)
        updated.save(Path("./output"))
    except Exception as e:
        error_state = WorkflowState.load(project_name, Path("./output"))
        error_state.mark_inactive()
        error_state.save(Path("./output"))
```

### Error Handling
3-level classification system:
1. **AutoFixable**: Syntax/import errors → auto-retry
2. **LogicError**: Type/proof failures → user confirmation
3. **DomainModelError**: Wrong requirements → re-analysis

---

## Testing

**Strategy**: Write tests FIRST (Python is runtime language)

```bash
cd agent/
pytest tests/                          # All tests
pytest tests/test_workflow_state.py   # Specific file
pytest tests/ --cov=. --cov-report=term-missing  # Coverage
```

**Current**: 17 unit tests passing ✅

---

## Adding New Domain Models

1. Create `Domains/MyDomain.idr`
2. Define types with `public export`
3. Implement `Documentable MyDomainType`
4. Add dependent type proofs for invariants

**Minimal Example**:
```idris
module Domains.MyDomain
import Core.DocumentModel
import Core.DomainToDoc

public export
record MyContract where
  constructor MkMyContract
  title : String
  amount : Nat

public export
Documentable MyContract where
  toDocument c = MkDoc
    (MkMetadata c.title "" "" "")
    [Heading 1 c.title, Para ("Amount: ₩" ++ show c.amount)]
```

---

## Reference Documents

- **Idris2 Guidelines**: `docs/IDRIS2_CODE_GENERATION_GUIDELINES.md` ⭐
- **Type Safety Verification**: `docs/TYPE_SAFETY_VERIFICATION.md`
- **Agent System**: `docs/AGENT_SYSTEM.md`
- **Frontend Spec**: `docs/FRONTEND_SPEC.md`
- **Docker Setup**: `docs/DOCKER_SETUP.md`

---

## Reference Implementation

See `Domains/ScaleDeep.idr` for complete example:
- Client: ㈜스피라티, Contractor: ㈜이츠에듀
- Service: Math question input/review (50,650 questions @ ₩1,000)
- **Proof**: `totalPrice = supplyPrice + vat` verified at compile-time
- Timeline: 2025-10-01 to 2025-11-30

---

**Last Updated**: 2025-10-27
**Version**: 1.0.0
