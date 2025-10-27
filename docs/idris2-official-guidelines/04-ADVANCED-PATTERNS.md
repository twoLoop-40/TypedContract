# Idris2 Advanced Patterns

**Source**: Official Idris2 Documentation
**Last Updated**: 2025-10-27

---

## Views and the `with` Rule

### The Problem

When intermediate computation affects pattern matching in dependent types:

```idris
-- Problem: Can't pattern match on filter result directly
badFilter : (a -> Bool) -> Vect n a -> ???
badFilter p [] = []
badFilter p (x :: xs) = ???  -- What's the return type?
```

### Solution: The `with` Rule

Match on intermediate results while preserving type information:

```idris
filter : (a -> Bool) -> Vect n a -> (p ** Vect p a)
filter p [] = (Z ** [])
filter p (x :: xs) with (filter p xs)
  filter p (x :: xs) | (len ** xs') =
    if p x
      then (S len ** x :: xs')
      else (len ** xs')
```

**Syntax**: `with (expression) ... | pattern = rhs`

### Multiple `with` Clauses

```idris
foo : Nat -> Nat -> String
foo n m with (n + m)
  foo n m | Z     = "zero"
  foo n m | (S k) with (k * 2)
    foo n m | (S k) | result = show result
```

---

## Views

Views abstract pattern information for cleaner code.

### Parity View Example

```idris
data Parity : Nat -> Type where
  Even : {n : Nat} -> Parity (n + n)
  Odd  : {n : Nat} -> Parity (S (n + n))

parity : (n : Nat) -> Parity n
parity Z = Even {n = Z}
parity (S Z) = Odd {n = Z}
parity (S (S k)) with (parity k)
  parity (S (S (j + j)))     | Even = Even {n = S j}
  parity (S (S (S (j + j)))) | Odd  = Odd {n = S j}
```

### Using Views

```idris
natToBin : Nat -> List Bool
natToBin Z = []
natToBin k with (parity k)
  natToBin (j + j)     | Even = False :: natToBin j
  natToBin (S (j + j)) | Odd  = True  :: natToBin j
```

When view returns `Even`, `k` refines to `(j + j)` in the pattern.

---

## Theorem Proving

### Basic Proofs

```idris
-- Proof by reflexivity
plusZero : (n : Nat) -> n + 0 = n
plusZero Z     = Refl
plusZero (S k) = cong S (plusZero k)
```

### Using `rewrite`

```idris
plusCommutative : (n : Nat) -> (m : Nat) -> n + m = m + n
plusCommutative Z m = sym (plusZeroRightNeutral m)
plusCommutative (S k) m =
  rewrite plusCommutative k m in
    plusSuccRightSucc m k
```

### Impossible Patterns

```idris
-- Prove that 0 ≠ S n
zeroNotSucc : (0 = S n) -> Void
zeroNotSucc Refl impossible

-- Use in proofs
nonZeroSucc : (n : Nat) -> Not (S n = 0)
nonZeroSucc n = \prf => zeroNotSucc (sym prf)
```

### Proof Tactics

```idris
-- cong: Apply function to both sides
cong : (f : a -> b) -> x = y -> f x = f y

-- sym: Symmetry of equality
sym : x = y -> y = x

-- trans: Transitivity
trans : x = y -> y = z -> x = z

-- replace: Substitute in type
replace : {P : a -> Type} -> x = y -> P x -> P y
```

---

## Dependent Pattern Matching

### Matching on Indices

```idris
(++) : Vect n a -> Vect m a -> Vect (n + m) a
(++) {n = Z}   []        ys = ys
(++) {n = S k} (x :: xs) ys = x :: xs ++ ys
```

The implicit `n` must match the vector structure.

### Dotted Patterns (Implicit)

When patterns are forced by types:

```idris
-- n is determined by the vector
same : (xs : Vect n a) -> (ys : Vect n a) -> Type
same {n = Z}   []        []        = ()
same {n = S k} (x :: xs) (y :: ys) = (x = y, same xs ys)
```

---

## Interactive Editing

### Holes and Case Splitting

```idris
myFunc : Nat -> String
myFunc x = ?hole

-- In REPL:
-- :cs 1 x           -- Case split on x
-- :ml 1             -- Make lemma
-- :ps 1             -- Proof search
```

### Type-Driven Development Workflow

1. Write type signature
2. Add holes (`?name`)
3. Type-check to see required types
4. Case split on variables
5. Recursively fill holes
6. Proof search for simple cases

---

## Elaborator Reflection

Use compile-time metaprogramming:

```idris
%language ElabReflection

-- Run elaboration script
deriveFunctor : Name -> Elab ()
deriveFunctor n = do
  -- Inspect type definition
  -- Generate Functor implementation
  -- Declare implementation
  pure ()

-- Use macro
%runElab (deriveFunctor `{MyType})
```

---

## Interfaces: Advanced Usage

### Determining Parameters

Control which parameters find implementations:

```idris
interface MonadState s (0 m : Type -> Type) | m where
  get : m s
  put : s -> m ()
```

`| m` means: only `m` determines implementation, `s` is inferred from `m`.

### Interface Hints

```idris
%hint
myHint : Ord Nat
myHint = ...

-- Used automatically in auto-implicit search
```

### Default Hints

```idris
%defaulthint
fallbackHint : Show a
fallbackHint = ...

-- Used when no other hint matches
```

---

## Foreign Function Interface

### Calling Foreign Functions

```idris
%foreign "C:puts,libc"
puts : String -> PrimIO Int

%foreign "scheme:display"
display : String -> PrimIO ()

%foreign "javascript:lambda:(x) => console.log(x)"
jsLog : String -> PrimIO ()
```

### Exporting to Foreign Code

```idris
%export "javascript:myIdrisFunc"
myFunc : Int -> Int
myFunc x = x * 2
```

---

## Pragmas for Optimization

### Inlining

```idris
%inline
fastHelper : Nat -> Nat
fastHelper n = n * 2

%noinline
dontInline : Nat -> Nat
dontInline n = n + 1
```

### Specialization

```idris
%spec n
power : Nat -> Nat -> Nat
power base Z     = 1
power base (S k) = base * power base k

-- Generate specialized version for specific n
optimized : Nat
optimized = power 2 10  -- Specialized for n=10
```

### Builtin Natural Numbers

```idris
%builtin Natural Nat

-- Use GMP for Nat operations instead of unary
```

---

## Totality Pragmas

### %default total

```idris
%default total

-- All functions must be total from here
foo : Nat -> Nat
foo n = n + 1  -- Must be total

%default partial
-- Now partial functions allowed
```

### Totality Depth

```idris
%totality_depth 10

-- Check deeper for termination
recursive : Nat -> Nat
recursive n = recursive (n - 1)
```

---

## Debugging and Logging

### Logging Levels

```idris
%logging "elab" 5

-- Log elaboration at level 5
```

Levels: 0 (off) to 10 (verbose)

### Ambiguity Depth

```idris
%ambiguity_depth 5

-- Resolve ambiguous names up to depth 5
```

---

## Common Patterns

### Smart Constructors with Proofs

```idris
data ValidList : List a -> Type where
  IsValid : (xs : List a) -> {auto ok : NonEmpty xs} -> ValidList xs

safeHead : (xs : List a) -> {auto prf : ValidList xs} -> a
safeHead (x :: _) = x
```

### Indexed State Machines

```idris
data Protocol : State -> Type where
  Start   : Protocol Init
  Send    : String -> Protocol Init -> Protocol Sending
  Receive : Protocol Sending -> Protocol Done
  End     : Protocol Done -> Protocol Init
```

### Refinement Types

```idris
data InRange : Nat -> Nat -> Nat -> Type where
  MkInRange : (value : Nat)
           -> {auto lower : LTE min value}
           -> {auto upper : LTE value max}
           -> InRange min max value
```

---

## Performance Tips

1. **Use `%inline`** for small frequently-called functions
2. **Use `0` multiplicity** for compile-time only data
3. **Use `%builtin Natural`** for Nat arithmetic
4. **Avoid excessive proof terms** in hot paths
5. **Use `assert_smaller`** to help termination checker
6. **Prefer tail recursion** when possible
7. **Use specialized backends** (Chez for speed, Racket for portability)
