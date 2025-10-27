# Idris2 Modules and Namespaces

**Source**: Official Idris2 Documentation
**Last Updated**: 2025-10-27

---

## Module Structure

Each file is a module. Files are named according to module hierarchy.

### File Naming Convention

- Module `Foo.Bar.MyModule` → `./Foo/Bar/MyModule.idr`
- Module `Main` → `./Main.idr`

---

## Module Declaration

```idris
module Data.MyList

import Data.Nat
import Data.String

-- Module contents here
```

### Main Module

```idris
module Main

main : IO ()
main = putStrLn "Hello, World!"
```

---

## Export Modifiers

Three visibility levels:

### 1. **private** (default)

Not exported from module:

```idris
private
helper : Nat -> Nat
helper n = n * 2
```

### 2. **export**

Top-level type exported, definitions hidden:

```idris
export
data MyType : Type where
  MkMyType : Nat -> MyType

-- Type visible, constructor MkMyType hidden
```

**Functions**: Runtime-only access, no compile-time reduction

```idris
export
compute : Nat -> Nat
compute n = n + 1
```

### 3. **public export**

Entire definition exported and accessible at compile-time:

```idris
public export
data List a = Nil | (::) a (List a)

-- Both type and constructors visible
```

**Functions**: Available for compile-time reduction (needed for proofs)

```idris
public export
length : List a -> Nat
length []        = 0
length (x :: xs) = 1 + length xs
```

---

## Visibility Rules

**Rule**: Definitions must not refer to anything within a lower visibility level.

```idris
private
secret : Nat
secret = 42

-- ❌ Error: Can't export function using private name
export
reveal : Nat
reveal = secret  -- Error!
```

---

## Import Statements

### Basic Import

```idris
import Data.List
import Data.Vect
```

### Public Re-export

```idris
-- Re-export imported module
import public Data.List
```

Modules importing this one will also see `Data.List`.

### Import with Alias

```idris
import Data.List as L

-- Use with qualifier
sorted : List Nat
sorted = L.sort [3, 1, 2]
```

### Selective Import

```idris
-- Import specific names
import Data.List (map, filter, sort)

-- Import hiding specific names
import Data.String hiding (reverse)
```

---

## Namespaces

Namespaces enable name overloading within modules.

### Basic Namespace

```idris
module MyModule

namespace List
  public export
  length : List a -> Nat
  length []        = 0
  length (x :: xs) = 1 + length xs

namespace Vect
  public export
  length : Vect n a -> Nat
  length []        = 0
  length (x :: xs) = 1 + length xs
```

### Qualified Access

```idris
import MyModule

len1 : Nat
len1 = MyModule.List.length [1, 2, 3]

len2 : Nat
len2 = MyModule.Vect.length [1, 2, 3]
```

### Nested Namespaces

```idris
namespace Outer
  namespace Inner
    foo : Nat
    foo = 42

-- Access with full path
value : Nat
value = Outer.Inner.foo
```

---

## Parameterised Blocks

Add parameters to all contained definitions:

```idris
parameters (x : Nat, y : Nat)
  add : Nat
  add = x + y

  multiply : Nat
  multiply = x * y

-- Equivalent to:
-- add : Nat -> Nat -> Nat
-- add x y = x + y
--
-- multiply : Nat -> Nat -> Nat
-- multiply x y = x * y
```

### With Data Types

```idris
parameters (a : Type)
  data Stack : Type where
    Empty : Stack
    Push : a -> Stack -> Stack

  pop : Stack -> Maybe (a, Stack)
  pop Empty        = Nothing
  pop (Push x xs)  = Just (x, xs)
```

---

## Fixity Declarations

Define operator precedence and associativity:

```idris
-- Infix operators
infixl 5 +   -- Left-associative, precedence 5
infixr 7 *   -- Right-associative, precedence 7
infix  4 ==  -- Non-associative, precedence 4

-- Prefix operators
prefix 10 -  -- Prefix, precedence 10
```

### Exporting Fixities

Fixity declarations are exported by default (no modifier needed):

```idris
module MyOps

-- Automatically exported
infixl 6 +++

public export
(+++) : String -> String -> String
(+++) = (++)
```

---

## Common Module Patterns

### Abstract Data Type

```idris
module MyStack

-- Only type exported, constructors hidden
export
data Stack a = Empty | Push a (Stack a)

-- Public interface
export
empty : Stack a
empty = Empty

export
push : a -> Stack a -> Stack a
push = Push

export
pop : Stack a -> Maybe (a, Stack a)
pop Empty        = Nothing
pop (Push x xs)  = Just (x, xs)
```

### Smart Constructors

```idris
module PositiveNat

-- Hide constructor
export
data Positive = MkPos Nat

-- Public smart constructor with validation
export
mkPositive : Nat -> Maybe Positive
mkPositive Z     = Nothing
mkPositive (S k) = Just (MkPos (S k))

-- Safe operations
export
getValue : Positive -> Nat
getValue (MkPos n) = n
```

---

## Standard Library Structure

Common imports from base library:

```idris
-- Data structures
import Data.List
import Data.Vect
import Data.String
import Data.Fin

-- Numeric types
import Data.Nat
import Data.Bits

-- Proofs and decidability
import Decidable.Equality

-- Control structures
import Control.Monad.Identity
import Control.Monad.State

-- System
import System
import System.File
```

---

## Module Best Practices

1. **One module per file** matching the module hierarchy
2. **Use `public export`** for types/functions needed at compile-time
3. **Use `export`** for runtime-only APIs
4. **Keep `private`** for internal helpers
5. **Namespace collision resolution** with explicit imports or qualifiers
6. **Document visibility choices** in comments
7. **Re-export strategically** with `import public` for convenience modules

---

## Example: Complete Module

```idris
module Data.MyQueue

import Data.List

-- Abstract queue type (constructor hidden)
export
data Queue a = MkQueue (List a) (List a)

-- Public API
export
empty : Queue a
empty = MkQueue [] []

export
enqueue : a -> Queue a -> Queue a
enqueue x (MkQueue front back) = MkQueue front (x :: back)

export
dequeue : Queue a -> Maybe (a, Queue a)
dequeue (MkQueue [] []) = Nothing
dequeue (MkQueue [] back) = dequeue (MkQueue (reverse back) [])
dequeue (MkQueue (x :: xs) back) = Just (x, MkQueue xs back)

-- Helper (not exported)
private
invariant : Queue a -> Bool
invariant (MkQueue [] []) = True
invariant (MkQueue [] _)  = False
invariant _ = True
```
