# Idris2 Syntax Basics

**Source**: Official Idris2 Documentation
**Last Updated**: 2025-10-27

---

## Primitive Types

- `Int` - Fixed-precision integers
- `Integer` - Arbitrary-precision integers
- `Double` - Floating-point numbers
- `Char` - Single characters
- `String` - Text strings
- `Ptr` - Foreign pointers
- `Bool` - True/False (from standard library)

---

## Function Definitions

Functions require explicit type declarations using `:`:

```idris
add : Int -> Int -> Int
add x y = x + y
```

### Pattern Matching

```idris
factorial : Nat -> Nat
factorial Z = 1
factorial (S k) = (S k) * factorial k
```

### Where Clauses

Local definitions using `where` (must be indented):

```idris
pythagoras : Double -> Double -> Double
pythagoras x y = sqrt (square x + square y)
  where
    square : Double -> Double
    square n = n * n
```

---

## Data Types

### Basic Data Type

```idris
data Nat : Type where
  Z : Nat
  S : Nat -> Nat
```

### Parameterized Types

```idris
data Maybe a = Nothing | Just a

data List a = Nil | (::) a (List a)
```

### Dependent Types

```idris
data Vect : Nat -> Type -> Type where
  Nil  : Vect Z a
  (::) : a -> Vect n a -> Vect (S n) a
```

---

## Records

```idris
record Person where
  constructor MkPerson
  name : String
  age : Nat
```

Usage:
```idris
john : Person
john = MkPerson "John" 30

-- Access fields
john.name  -- "John"
john.age   -- 30

-- Update fields
older : Person
older = { age := 31 } john
```

---

## Pattern Matching Constructs

### Case Expressions

```idris
describe : Nat -> String
describe n = case n of
  Z   => "zero"
  S Z => "one"
  _   => "many"
```

### Let Bindings

```idris
foo : Int -> Int
foo x = let y = x * 2
            z = y + 1
        in z * z
```

---

## List Comprehensions

```idris
pythagTriples : Nat -> List (Nat, Nat, Nat)
pythagTriples n = [(x, y, z) | z <- [1..n],
                                y <- [1..z],
                                x <- [1..y],
                                x * x + y * y == z * z]
```

---

## Covering Requirement

**By default, functions must cover all possible inputs.**

```idris
-- ❌ Partial function (missing pattern)
head : List a -> a
head (x :: xs) = x

-- ✅ Total function
head : (xs : List a) -> {auto ok : NonEmpty xs} -> a
head (x :: xs) = x
```

Mark partial functions explicitly (discouraged):
```idris
partial
unsafeHead : List a -> a
unsafeHead (x :: xs) = x
```

---

## Holes

Use `?name` to mark incomplete code:

```idris
add : Nat -> Nat -> Nat
add Z     y = ?add_rhs_1
add (S k) y = ?add_rhs_2
```

Idris reports required types for holes during type-checking.

---

## I/O and Do-Notation

```idris
main : IO ()
main = do
  putStrLn "What's your name?"
  name <- getLine
  putStrLn ("Hello, " ++ name ++ "!")
```

- `x <- action` - Execute IO and bind result
- `action` - Execute IO and discard result
- `let x = expr` - Pure binding

---

## Implicit Arguments

Arguments appearing in types but not explicitly provided are implicit:

```idris
-- n and a are implicit
length : Vect n a -> Nat
length []        = 0
length (x :: xs) = 1 + length xs

-- Call without providing n or a
len : Nat
len = length [1, 2, 3]  -- n and a inferred
```

Make implicit arguments explicit:
```idris
length {n} {a} xs = ?rhs
```

---

## Dependent Pairs

Pairs where second type depends on first value:

```idris
filter : (a -> Bool) -> Vect n a -> (p ** Vect p a)
filter p []        = (Z ** [])
filter p (x :: xs) with (filter p xs)
  filter p (x :: xs) | (len ** xs') =
    if p x then (S len ** x :: xs') else (len ** xs')
```

---

## Key Differences from Haskell

1. **Explicit type signatures required** for top-level functions
2. **Dependent types** - types can depend on values
3. **Totality checking** - functions must be provably total by default
4. **Multiplicities** - QTT with 0/1/unrestricted usage tracking
5. **Smaller Prelude** - must import modules explicitly

---

## Common Imports

```idris
import Data.List
import Data.Vect
import Data.Nat
import Data.Fin
import Data.String
import Decidable.Equality
```
