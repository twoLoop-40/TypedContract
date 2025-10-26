# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **formal document generation system** written in Idris2. The project demonstrates how to use dependent types to:
1. Define domain models (like contracts, transactions) with compile-time correctness guarantees
2. Automatically generate PDF documents from those domain models

The codebase is split into two parts:
- **Domain specifications** (`Domains/`): Business-specific types (e.g., ServiceContract for Spirati)
- **Document generation framework** (root directory): Reusable tools for converting any domain model to PDF

## Directory Structure

```
ScaleDeepSpec/
├── Domains/                    # Domain-specific models (examples)
│   ├── ScaleDeep.idr          # Outsourcing contract domain model
│   └── ApprovalNarrative.idr  # Pre-approval narrative model
│
├── DocumentModel.idr          # Generic document structure (headings, paragraphs, tables)
├── DomainToDoc.idr           # Converts domain models → document models
├── LaTeXRenderer.idr         # Converts document models → LaTeX
├── Generator.idr             # Orchestrates the full pipeline
├── Main.idr                  # Executable (IO operations)
│
├── direction/                # Reference materials
│   └── 외주용역 사전승인 신청서.pdf
│
└── 용역계약서.txt            # Generated text output
```

## Building and Type-Checking

```bash
# Check domain models
idris2 --check Domains/ScaleDeep.idr
idris2 --check Domains/ApprovalNarrative.idr

# Check document framework
idris2 --check DocumentModel.idr
idris2 --check LaTeXRenderer.idr
idris2 --check DomainToDoc.idr
idris2 --check Generator.idr

# Check everything (through Generator)
idris2 --check Generator.idr
```

## Architecture

### 1. Domain Models (`Domains/`)

These are **business-specific** Idris2 types. Each domain represents a real-world contract or document.

**Example: `Domains/ScaleDeep.idr`**
- Models a math question input/review service contract
- Client: ㈜스피라티, Contractor: ㈜이츠에듀
- Uses dependent types to prove `totalPrice = supplyPrice + vat`
- Structured in 9 layers:
  1. Basic data structures (Money, VAT rate)
  2. Unit pricing with proofs (`UnitPrice`)
  3. Deliverables (output specifications)
  4. Task specifications
  5. Contract records
  6. Transaction records
  7. Quotations (vendor comparison)
  8. Service contract (full legal document)
  9. Outsourcing package (combines everything)

**Key types:**
- `ServiceContract`: Complete contract with parties, terms, payment schedule
- `Party`: Company information (name, representative, business number)
- `ContractTerms`: 14 legal articles (purpose, scope, payment, IP rights, etc.)

### 2. Document Model (`DocumentModel.idr`)

**Purpose**: Generic, reusable document structure independent of any specific domain.

**Key types:**
- `DocElement`: Text, Heading, BulletList, OrderedList, Table, HRule, VSpace, PageBreak, Section, Box
- `Metadata`: Title, author, date, document number
- `Document`: Metadata + body (list of DocElement)

**Validation functions:**
- `validDocument`: Ensures document has title and non-empty body

### 3. Domain → Document Conversion (`DomainToDoc.idr`)

**Purpose**: Bridge between domain models and generic documents.

**Key interface:**
```idris
interface Documentable a where
  toDocument : a -> Document
```

**Implementations:**
- `Documentable ServiceContract`: Converts contract to formatted document
- `Documentable TaskSpec`: Converts task specification to document
- `Documentable Transaction`: Converts transaction to invoice-style document

**Helper functions:**
- `partyToElements`: Party → DocElement list (company info block)
- `termsToArticles`: ContractTerms → 14 article sections
- `deliverablesToElements`: Deliverables → formatted list

### 4. LaTeX Rendering (`LaTeXRenderer.idr`)

**Purpose**: Convert abstract Document to concrete LaTeX source code.

**Key functions:**
- `renderElement : DocElement -> String`: Renders one element
- `renderDocument : Document -> LaTeXDocument`: Full document rendering
- `extractSource : LaTeXDocument -> String`: Get LaTeX source code

**LaTeX setup:**
- Uses `kotex` package for Korean language support
- A4 paper, 25mm margins
- No paragraph indentation (business document style)

### 5. Generation Pipeline (`Generator.idr`)

**Purpose**: Type-safe orchestration of the full generation process.

**Key type:**
```idris
record GenerationPipeline a where
  domainModel : a
  documentModel : Document
  latexOutput : LaTeXDocument
  outputPath : String
```

**Main function:**
```idris
createPipeline : Documentable a => a -> String -> GenerationPipeline a
```

**Pre-configured pipelines:**
- `spiratiContractPipeline`: ServiceContract → PDF
- `spiratiTaskPipeline`: TaskSpec → PDF
- `spiratiTransactionPipeline`: Transaction → PDF

**Batch processing:**
- `BatchGeneration`: Group multiple documents for batch generation

### 6. Execution (`Main.idr`)

**Purpose**: IO operations (file writing, PDF compilation).

**Key functions:**
- `writeLatexFile : GenerationPipeline a -> IO (Either String String)`
- `compilePDF : String -> IO (Either String String)` (TODO: call pdflatex)
- `executePipeline : GenerationPipeline a -> IO ()`
- `executeBatch : BatchGeneration -> IO ()`

## Key Patterns

### Dependent Type Proofs

The `UnitPrice` type carries a compile-time proof:

```idris
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)
    -> UnitPrice
```

Smart constructor auto-generates proof:
```idris
mkUnitPrice : (perItem : Nat) -> (quantity : Nat) -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl
```

### Type Class for Extensibility

The `Documentable` interface enables adding new domain types without modifying framework code:

```idris
-- Add a new domain type
record Invoice where
  number : String
  amount : Nat

-- Make it documentable
Documentable Invoice where
  toDocument inv = MkDoc
    (MkMetadata "Invoice" "" "" inv.number)
    [Heading 1 "Invoice", Para ("Amount: " ++ show inv.amount)]

-- Automatically works with the pipeline
myInvoice = createPipeline (MkInvoice "INV-001" 10000) "invoice.pdf"
```

### Validation at Multiple Levels

1. **Compile-time**: Dependent types prove arithmetic correctness
2. **Runtime**: Boolean validation functions (`validContract`, `validDocument`)
3. **Pipeline-level**: `validatePipeline` checks full generation setup

## Adding New Domain Models

1. Create `Domains/MyDomain.idr`
2. Define your domain types (records, data)
3. Export types with `public export`
4. Add `Documentable MyDomainType where toDocument = ...`
5. Create pipeline: `myPipeline = createPipeline myModel "output.pdf"`

## Example: Spirati Contract

```idris
-- Domain model with proofs
serviceContractSpiratiItsEdu : ServiceContract

-- Automatic conversion to document
doc : Document
doc = toDocument serviceContractSpiratiItsEdu

-- Automatic LaTeX generation
latex : LaTeXDocument
latex = renderDocument doc

-- Full pipeline
pipeline : GenerationPipeline ServiceContract
pipeline = createPipeline serviceContractSpiratiItsEdu "contract.pdf"

-- Execute (in Main.idr)
main = executePipeline pipeline
```

## Domain Context: Spirati Example

The `Domains/ScaleDeep.idr` file models a real contract:
- **Client**: ㈜스피라티 (Spirati Inc.)
- **Contractor**: ㈜이츠에듀 (ItsEdu Inc.)
- **Service**: Math question input/review (50,650 questions @ ₩1,000 each)
- **Amount**: ₩50,650,000 + ₩5,065,000 VAT = ₩55,715,000
- **Timeline**: 2025-10-01 to 2025-11-30
- **Deliverables**:
  - 11/5: 10,000 questions, 5,000 HWP files
  - 11/20: All 50,650 HWP files complete
  - 11/30: All LaTeX + HWP complete

This serves as a reference implementation for creating other contract models.
