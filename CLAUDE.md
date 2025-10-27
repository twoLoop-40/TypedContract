# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview: TypedContract

This is a **type-safe contract and document generation system** with three main components:

1. **Idris2 Core Framework**: Dependent type specifications for domain models and document generation
2. **FastAPI Backend**: Python agent system that orchestrates Idris2 compilation and document generation
3. **Next.js Frontend**: User interface for project creation, workflow monitoring, and document preview

The system uses dependent types to guarantee correctness at compile-time and provides multiple output formats (LaTeX/PDF, Markdown, CSV, Text).

## Directory Structure

```
TypedContract/
├── Core/                       # Idris2 document generation framework
│   ├── DocumentModel.idr      # Generic document structure (headings, paragraphs, tables)
│   ├── DomainToDoc.idr        # Converts domain models → document models
│   ├── LaTeXRenderer.idr      # Converts documents → LaTeX
│   ├── MarkdownRenderer.idr   # Converts documents → Markdown
│   ├── TextRenderer.idr       # Converts documents → plain text
│   ├── CSVRenderer.idr        # Converts documents → CSV
│   └── Generator.idr          # Orchestrates the pipeline
│
├── Domains/                    # Domain-specific models (examples)
│   ├── ScaleDeep.idr          # Outsourcing contract domain model
│   └── ApprovalNarrative.idr  # Pre-approval narrative model
│
├── Spec/                       # Formal workflow specifications
│   ├── WorkflowTypes.idr      # Core workflow state machine types
│   ├── WorkflowExecution.idr  # Execution semantics & transitions
│   ├── AgentOperations.idr    # Agent system operations
│   ├── RendererOperations.idr # Multi-format rendering operations
│   ├── FrontendTypes.idr      # UI state and view types
│   ├── ErrorHandling.idr      # Error classification system
│   └── *Example.idr           # Example workflows & usage
│
├── Pipeline/                   # Generated runtime pipelines (agent-created)
│   └── [project_name].idr     # Project-specific document generation pipeline
│
├── agent/                      # Python FastAPI backend
│   ├── main.py                # FastAPI application
│   ├── agent.py               # LangGraph agent system
│   ├── prompts.py             # Agent prompts
│   ├── workflow_state.py      # Python implementation of Spec/WorkflowTypes.idr
│   ├── error_classifier.py    # Error classification and strategy system
│   ├── requirements.txt       # Python dependencies
│   └── tests/                 # Python unit tests
│       ├── test_workflow_state.py
│       ├── test_api_endpoints.py
│       ├── test_agent_phase*.py
│       └── conftest.py
│
├── frontend/                   # Next.js 14 frontend (TODO)
│   ├── package.json
│   └── README.md
│
├── docker/                     # Docker configuration
│   ├── Dockerfile.backend     # FastAPI + Idris2 + LaTeX
│   └── Dockerfile.frontend    # Next.js 14
│
├── docs/                       # Documentation
│   ├── DOCKER_SETUP.md        # Docker usage guide
│   ├── FRONTEND_SPEC.md       # Frontend architecture
│   ├── AGENT_SYSTEM.md        # Agent system design
│   └── *.md                   # Additional docs
│
├── Main.idr                    # Idris2 executable (IO operations)
├── docker-compose.yml          # Full stack orchestration
└── output/                     # Generated documents
```

## Project Status (Updated: 2025-10-27)

### ✅ Completed Components

- **Idris2 Core Framework** (100%): All renderers and generator working
- **Domain Models** (100%): ScaleDeep and ApprovalNarrative examples
- **Spec/** (100%): Complete workflow type specifications
- **Backend API** (100%): All major endpoints implemented
  - POST /api/project/init
  - POST /api/project/{name}/generate (LangGraph integration)
  - GET /api/project/{name}/status
  - POST /api/project/{name}/draft
  - GET /api/project/{name}/draft
  - POST /api/project/{name}/feedback
- **WorkflowState** (100%): Python implementation of Spec/WorkflowTypes.idr
  - 17 unit tests passing ✅
- **Tests** (80%): workflow_state and API endpoint tests written

### ⚠️ In Progress

- **Docker Environment**: Debugging Chez Scheme installation for Idris2
- **End-to-End Testing**: Pending Docker environment fix

### ❌ Not Started

- **Frontend**: Next.js 14 UI (0%)

---

## Development Environment Setup

### Prerequisites

- **Idris2 v0.7.0+**: Required for type-checking and compilation
- **Python 3.11+**: Backend runtime
- **Node.js 18+**: Frontend runtime
- **Docker**: For containerized development (recommended)
- **uv**: Fast Python package installer (recommended)

### Local Development Setup (Without Docker)

#### 1. Install Idris2

**Option A: Homebrew (macOS)**
```bash
brew install idris2
```

**Option B: From source**
```bash
# Install Chez Scheme first
brew install chezscheme  # macOS
# OR: apt-get install chezscheme  # Ubuntu

# Build Idris2
git clone https://github.com/idris-lang/Idris2.git
cd Idris2
make bootstrap SCHEME=scheme
make install PREFIX=/usr/local
```

#### 2. Install Python Dependencies

**⚠️ IMPORTANT: Use `uv` for fast, reliable Python dependency management**

```bash
# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install all dependencies with uv (RECOMMENDED)
cd agent/
uv pip install --system -r requirements.txt

# Verify installation
python -c "import anthropic, fastapi, langgraph; print('✅ Dependencies installed')"
```

**Why uv?**
- 10-100x faster than pip
- Better dependency resolution
- Handles compiled packages (pandas, etc.) more reliably

**Troubleshooting:**
If you encounter build errors with optional packages (pandas, openpyxl), you can install only core dependencies:
```bash
# Core packages only (minimal installation)
uv pip install --system anthropic fastapi uvicorn langgraph langchain python-dotenv pydantic
```

#### 3. Configure Environment Variables

```bash
# Create .env file in project root
cp .env.example .env

# Edit .env and add your API keys
# ANTHROPIC_API_KEY=sk-ant-api03-...
```

#### 4. Verify Installation

```bash
# Check Idris2
idris2 --version
# Expected: Idris 2, version 0.7.0

# Check Python packages
python -c "import anthropic, fastapi, langgraph; print('✅ Core packages OK')"

# Check API key
python -c "from dotenv import load_dotenv; import os; load_dotenv(); print('✅ API Key loaded' if os.getenv('ANTHROPIC_API_KEY') else '❌ No API key')"
```

#### 5. Run Backend Server

```bash
cd agent/
uvicorn agent.main:app --reload --host 0.0.0.0 --port 8000
```

Access API docs at: http://localhost:8000/docs

**Quick verification:**
```bash
# Health check
curl http://localhost:8000/health

# Check Idris2 integration
curl http://localhost:8000/api/debug/idris2
```

---

## Common Development Commands

### Docker (Recommended)

```bash
# Start all services (Frontend + Backend)
docker-compose up --build

# Start in background
docker-compose up -d

# View logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Stop services
docker-compose down

# Access backend container for Idris2 development
docker-compose exec backend bash

# Access frontend container
docker-compose exec frontend sh
```

Access points:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Documentation: http://localhost:8000/docs

### Idris2 Type-Checking

```bash
# Check core framework modules
idris2 --check Core/DocumentModel.idr
idris2 --check Core/DomainToDoc.idr
idris2 --check Core/LaTeXRenderer.idr
idris2 --check Core/MarkdownRenderer.idr
idris2 --check Core/TextRenderer.idr
idris2 --check Core/CSVRenderer.idr
idris2 --check Core/Generator.idr

# Check domain models
idris2 --check Domains/ScaleDeep.idr
idris2 --check Domains/ApprovalNarrative.idr

# Check workflow specifications
idris2 --check Spec/WorkflowTypes.idr
idris2 --check Spec/WorkflowExecution.idr
idris2 --check Spec/AgentOperations.idr
idris2 --check Spec/RendererOperations.idr
idris2 --check Spec/FrontendTypes.idr

# Check everything through Main
idris2 --check Main.idr
```

### Backend Development

```bash
# Run all tests
cd agent/
pytest tests/                          # Run all tests
pytest tests/ -v                       # Verbose output
pytest tests/test_workflow_state.py   # Run specific test file
pytest tests/test_workflow_state.py::test_initial_state -v  # Run specific test
pytest tests/ --cov=. --cov-report=term-missing  # With coverage

# Run FastAPI server
cd agent/
uvicorn agent.main:app --reload --host 0.0.0.0 --port 8000
```

**IMPORTANT: Testing Strategy**

Python is a runtime language without compile-time type checking like Idris2. Therefore:

1. **Write tests for every new feature** before or during implementation
2. **Run tests after every change** to catch runtime errors early
3. **Test workflow state transitions** to ensure they match Spec/WorkflowTypes.idr
4. **Test API endpoints** with both success and failure cases

Test structure:
```
agent/tests/
├── test_workflow_state.py    # WorkflowState logic tests (17 tests)
├── test_api_endpoints.py     # FastAPI endpoint tests
├── test_agent_phase5.py      # Phase 5: Documentable implementation
├── test_agent_phase6.py      # Phase 6: Draft generation
├── test_agent_phase78.py     # Phase 7-8: Feedback loop
└── conftest.py                # Pytest fixtures

Current test coverage: 17 unit tests passing ✅
```

### Frontend Development

```bash
# Inside frontend container
cd /app
npm install                     # Install dependencies
npm run dev                     # Development server
npm run build                   # Production build
npm run lint                    # Lint code
```

## Architecture

The system has three layers that work together:

### Layer 1: Idris2 Core Framework (`Core/`)

The document generation framework provides type-safe transformation from domain models to multiple output formats.

**Key modules:**
- `DocumentModel.idr`: Abstract document structure (headings, paragraphs, tables, lists, etc.)
- `DomainToDoc.idr`: Converts domain models to generic documents via `Documentable` interface
- `LaTeXRenderer.idr`: Renders documents as LaTeX (for PDF generation)
- `MarkdownRenderer.idr`: Renders documents as Markdown
- `TextRenderer.idr`: Renders documents as plain text
- `CSVRenderer.idr`: Renders documents as CSV (for tabular data)
- `Generator.idr`: Orchestrates the full pipeline

**Core pattern - `Documentable` interface:**
```idris
interface Documentable a where
  toDocument : a -> Document

-- Any domain model can implement this to become renderable
```

**Multi-format rendering:**
```idris
-- From domain model → multiple outputs
doc = toDocument myDomainModel
latex = renderLaTeX doc
markdown = renderMarkdown doc
text = renderText doc
csv = renderCSV doc
```

### Layer 2: Domain Models (`Domains/`)

Business-specific types with compile-time correctness guarantees.

**Example: `Domains/ScaleDeep.idr`**
- Models a service contract with dependent type proofs
- Proves `totalPrice = supplyPrice + vat` at compile-time using `UnitPrice` with proof terms
- Implements `Documentable ServiceContract` to enable automatic rendering

**Example: `Domains/ApprovalNarrative.idr`**
- Models a pre-approval narrative document
- Demonstrates different domain model structure

### Layer 3: Workflow Specifications (`Spec/`)

Formal specifications for the agent system and UI behavior.

**Core workflow modules:**
- `WorkflowTypes.idr`: State machine for document generation (Init → Draft → Review → Final)
- `WorkflowExecution.idr`: Execution semantics and state transitions
- `AgentOperations.idr`: LangGraph agent operations (prompting, code generation, validation)
- `RendererOperations.idr`: Multi-format rendering operations
- `FrontendTypes.idr`: UI views, upload states, and user actions

**Purpose**: These specifications guide the Python backend implementation and ensure type-safe workflow execution.

### Layer 4: FastAPI Backend (`agent/`)

Python backend that orchestrates the full system.

**Key components:**
- `main.py`: FastAPI REST API (project init, status, feedback, downloads)
- `agent.py`: LangGraph agent system that generates Idris2 code based on user prompts
- `prompts.py`: Agent prompts for code generation
- `workflow_state.py`: Python implementation of Spec/WorkflowTypes.idr
- `error_classifier.py`: Intelligent error handling system (classify → decide strategy → retry/user input)

**API Endpoints:**
- `POST /api/project/init`: Initialize new project
- `POST /api/project/{name}/generate`: Start LangGraph workflow (Phases 2-5)
- `GET /api/project/{name}/status`: Get generation status (with error classification)
- `POST /api/project/{name}/draft`: Generate draft outputs (txt/md/csv)
- `GET /api/project/{name}/draft`: Retrieve draft contents
- `POST /api/project/{name}/feedback`: Submit user feedback (triggers Phase 7-8 loop)
- `POST /api/project/{name}/finalize`: Generate final PDF
- `GET /api/project/{name}/download`: Download final PDF

### Layer 5: Next.js Frontend (`frontend/`)

User interface for the document generation system (TODO - not yet implemented).

**Planned features:**
- Project creation with prompt input and file upload
- Real-time workflow progress monitoring
- Draft preview (txt/md/csv)
- Feedback submission for revisions
- PDF download

## Intelligent Error Handling System

**Problem**: Idris2 compilation errors can be:
1. **Syntax errors** (auto-fixable by Claude)
2. **Type errors** (may require data corrections)
3. **Proof failures** (indicate logical inconsistencies in input data)

The system classifies errors and decides appropriate strategies automatically.

### Error Classification (Spec/ErrorHandling.idr + agent/error_classifier.py)

**Level 1: Auto-fixable** (Syntax/Import errors)
- Strategy: Auto-retry with Claude fixes (max 5 attempts)
- Examples: Missing imports, typos, undefined names
- No user intervention needed

**Level 2: Logic errors** (Type mismatches, proof failures)
- Strategy: Request user confirmation or data correction
- Examples: `totalPrice ≠ supplyPrice + vat` proof failure
- User must verify input data accuracy

**Level 3: Domain model errors** (Misunderstood requirements)
- Strategy: Request detailed user clarification
- Examples: Wrong document structure, missing fields
- Requires re-analysis from Phase 2

**Workflow Integration:**
```
Phase 4: Compilation
    ↓ (if error)
Phase 4b: Error Handling
    ├─ Classify error (error_classifier.py)
    ├─ Decide strategy (auto-retry vs user input)
    ├─ Apply retry policy (max 5 syntax errors, 3 logic errors)
    └─ Continue or request user action
```

**Key files:**
- `Spec/ErrorHandling.idr`: Formal error classification types
- `agent/error_classifier.py`: Python implementation
- `agent/workflow_state.py`: Retry policy management

## Key Patterns

### 1. Dependent Type Proofs

Idris2 enables compile-time correctness guarantees through dependent types.

**Example from `Domains/ScaleDeep.idr`:**
```idris
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)  -- Proof term
    -> UnitPrice

-- Smart constructor auto-generates proof
mkUnitPrice : (perItem : Nat) -> (quantity : Nat) -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl
```

This ensures arithmetic correctness is verified at compile-time, not runtime.

### 2. Type Class for Extensibility

The `Documentable` interface in `Core/DomainToDoc.idr` enables adding new domain models without modifying framework code.

**Adding a new domain model:**
```idris
-- 1. Define your domain type
record Invoice where
  constructor MkInvoice
  number : String
  amount : Nat

-- 2. Make it documentable
Documentable Invoice where
  toDocument inv = MkDoc
    (MkMetadata "Invoice" "" "" inv.number)
    [Heading 1 "Invoice", Para ("Amount: " ++ show inv.amount)]

-- 3. Automatically works with all renderers
myInvoice = MkInvoice "INV-001" 10000
latexDoc = renderLaTeX (toDocument myInvoice)
markdownDoc = renderMarkdown (toDocument myInvoice)
textDoc = renderText (toDocument myInvoice)
```

### 3. Workflow State Machine

The `Spec/WorkflowTypes.idr` module defines a type-safe state machine for document generation:

```idris
data WorkflowPhase
  = InitPhase
  | DraftPhase
  | ReviewPhase
  | FinalPhase

data WorkflowState : WorkflowPhase -> Type where
  -- Each phase has specific data requirements
  Init : ProjectName -> UserPrompt -> WorkflowState InitPhase
  Draft : ProjectName -> DraftOutputs -> WorkflowState DraftPhase
  -- ... etc
```

This ensures transitions follow valid paths and carry appropriate data.

### 4. Multi-Format Rendering

All renderers implement a consistent pattern in `Core/*Renderer.idr`:

```idris
-- Abstract document → Concrete format
renderElement : DocElement -> String
renderDocument : Document -> FormatDocument
extractSource : FormatDocument -> String
```

This separation enables:
- Single domain model → multiple output formats
- Format-specific optimizations (e.g., LaTeX Korean support)
- Easy addition of new formats

## Adding New Domain Models

1. Create `Domains/MyDomain.idr`
2. Define domain types using `record` or `data`
3. Mark types as `public export`
4. Implement `Documentable MyDomainType`
5. Optionally add dependent type proofs for correctness guarantees

**Minimal example:**
```idris
module Domains.MyDomain

import Core.DocumentModel
import Core.DomainToDoc

public export
record MyContract where
  constructor MkMyContract
  title : String
  parties : List String
  amount : Nat

public export
Documentable MyContract where
  toDocument c = MkDoc
    (MkMetadata c.title "" "" "")
    [ Heading 1 c.title
    , Heading 2 "Parties"
    , BulletList c.parties
    , Para ("Amount: ₩" ++ show c.amount)
    ]
```

## System Integration Flow

1. **User input** → Frontend (Next.js)
2. **Project init** → Backend API (`POST /api/project/init`)
3. **Agent generates Idris2 code** → LangGraph agent creates domain model
4. **Type checking** → `idris2 --check` validates correctness (with error classification)
5. **Document generation** → Idris2 compiles and generates outputs
6. **Multi-format rendering** → txt/md/csv for preview, LaTeX for PDF
7. **User feedback** → Optional revision cycle (Phase 7-8 loop)
8. **Final output** → PDF download

## Development Best Practices

### Working with Idris2 + Python

**Rule of thumb:**
- **Idris2 code**: Type-safe, compile-time verification → Modify carefully
- **Python code**: Runtime behavior → Write tests first, run tests after every change

### Common Development Workflow

```bash
# 1. Type-check Idris2 changes
idris2 --check Core/DocumentModel.idr

# 2. Update Python implementation
vim agent/workflow_state.py

# 3. Write/update tests
vim agent/tests/test_workflow_state.py

# 4. Run tests
cd agent/
pytest tests/test_workflow_state.py -v

# 5. Run server and test endpoint
uvicorn agent.main:app --reload &
curl http://localhost:8000/api/project/test/status
```

### Debugging Tips

**Idris2 compilation fails:**
```bash
# Check which phase fails
idris2 --check Domains/YourDomain.idr

# Common issues:
# - Missing import: Add "import Core.DomainToDoc"
# - Type mismatch: Check Documentable implementation
# - Proof failure: Verify dependent type constraints
```

**Python API errors:**
```bash
# Check workflow state
cat output/[project_name]/state.json

# View API logs
docker-compose logs -f backend

# Test specific endpoint
curl -X POST http://localhost:8000/api/project/init \
  -H "Content-Type: application/json" \
  -d '{"project_name": "test", "user_prompt": "test", "reference_docs": []}'
```

**LangGraph agent issues:**
```bash
# Check ANTHROPIC_API_KEY
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.getenv('ANTHROPIC_API_KEY')[:10])"

# Run agent tests
pytest agent/tests/test_agent_phase5.py -v -s
```

## Reference: ScaleDeep Contract Example

The `Domains/ScaleDeep.idr` file demonstrates a complete domain model:
- **Client**: ㈜스피라티, **Contractor**: ㈜이츠에듀
- **Service**: Math question input/review (50,650 questions @ ₩1,000 each)
- **Proof**: `totalPrice = supplyPrice + vat` verified at compile-time
- **Timeline**: 2025-10-01 to 2025-11-30 with milestone-based deliverables

This serves as a reference implementation for creating new contract models.
