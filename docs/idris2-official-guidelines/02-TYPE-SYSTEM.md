# Idris2 Type System

**Source**: Official Idris2 Documentation
**Last Updated**: 2025-10-27

---

## Multiplicities (Quantitative Type Theory)

Idris 2 implements **QTT** where every variable has a quantity/multiplicity.

### Three Multiplicity Types

1. **0 (Erased)** - Compile-time only, absent at runtime
2. **1 (Linear)** - Used exactly once at runtime
3. **Unrestricted** - Default, no usage constraints

### Syntax

```idris
-- Erased argument (compile-time only)
vlen : {0 n : Nat} -> Vect n a -> Nat
vlen []        = 0
vlen (x :: xs) = 1 + vlen xs

-- Linear argument (used exactly once)
consume : (1 x : Resource) -> IO ()
consume x = releaseResource x

-- Unrestricted (default)
duplicate : (x : a) -> (a, a)
duplicate x = (x, x)  -- OK, x used twice
```

### Linearity Constraints

```idris
-- ❌ Cannot implement - x used twice
impossibleDup : (1 x : a) -> (a, a)
impossibleDup x = (x, x)
-- Error: "There are 2 uses of linear name x"
```

### Resource Protocols

Linear types enforce state machine protocols:

```idris
data DoorState = Open | Closed

data Door : DoorState -> Type where
  MkDoor : Door s

openDoor : (1 d : Door Closed) -> Door Open
closeDoor : (1 d : Door Open) -> Door Closed

-- ✅ Valid sequence
validUse : Door Closed -> Door Closed
validUse d = closeDoor (openDoor d)

-- ❌ Invalid - door used twice
invalid : (1 d : Door Closed) -> (Door Open, Door Open)
invalid d = (openDoor d, openDoor d)  -- Error!
```

---

## Implicit Arguments

### Automatic Inference

```idris
id : {a : Type} -> a -> a
id x = x

-- Call without explicit type
result : Int
result = id 42  -- a inferred as Int
```

### Auto Implicits

```idris
-- Automatically search for proof
mySort : {auto prf : Ord a} => List a -> List a
mySort xs = sort xs

-- Call without providing Ord proof
sorted : List Int
sorted = mySort [3, 1, 2]  -- Ord Int found automatically
```

### Named Implicits

```idris
lengthExplicit : {n : Nat} -> {a : Type} -> Vect n a -> Nat
lengthExplicit {n} {a} xs = n

-- Call with explicit names
len : Nat
len = lengthExplicit {n=3} {a=Int} [1, 2, 3]
```

---

## Dependent Types

Types that depend on values.

### Length-Indexed Vectors

```idris
data Vect : Nat -> Type -> Type where
  Nil  : Vect Z a
  (::) : a -> Vect n a -> Vect (S n) a

-- Type guarantees length
safeHead : Vect (S n) a -> a
safeHead (x :: xs) = x
-- No pattern for Nil needed - type makes it impossible!
```

### Dependent Functions

```idris
-- Return type depends on input value
replicate : (n : Nat) -> a -> Vect n a
replicate Z     x = []
replicate (S k) x = x :: replicate k x
```

### Dependent Pairs

```idris
-- Sigma type: (x : A) ** B x
filter : (a -> Bool) -> Vect n a -> (p ** Vect p a)
filter pred []        = (Z ** [])
filter pred (x :: xs) with (filter pred xs)
  filter pred (x :: xs) | (len ** xs') =
    if pred x
      then (S len ** x :: xs')
      else (len ** xs')
```

---

## Pattern Matching on Types

Types are first-class values (with multiplicity > 0):

```idris
-- Pattern match on types
showType : Type -> String
showType Int    = "Int"
showType String = "String"
showType Bool   = "Bool"
showType _      = "Unknown"

-- Dependent on type values
sizeof : (t : Type) -> Nat
sizeof Int    = 8
sizeof Double = 8
sizeof Char   = 4
sizeof _      = 0
```

---

## Equality Types

### Propositional Equality

```idris
data Equal : a -> b -> Type where
  Refl : Equal x x

-- Proof that 2 + 2 = 4
twoPlusTwo : Equal (2 + 2) 4
twoPlusTwo = Refl
```

### Decidable Equality

```idris
-- DecEq interface for decidable equality
interface DecEq a where
  decEq : (x : a) -> (y : a) -> Dec (x = y)

-- Usage
checkEqual : (x : Nat) -> (y : Nat) -> String
checkEqual x y = case decEq x y of
  Yes prf => "Equal"
  No contra => "Not equal"
```

---

## Interfaces (Type Classes)

### Basic Interface

```idris
interface Show a where
  show : a -> String

-- Implementation
Show Nat where
  show Z     = "Z"
  show (S k) = "S(" ++ show k ++ ")"
```

### Interface Constraints

```idris
interface Eq a where
  (==) : a -> a -> Bool
  (/=) : a -> a -> Bool

  -- Default implementation
  x /= y = not (x == y)

-- Extending interfaces
interface Eq a => Ord a where
  compare : a -> a -> Ordering
```

### Multi-Parameter Interfaces

```idris
interface Functor (0 f : Type -> Type) where
  map : (a -> b) -> f a -> f b

-- 0 f means f is erased at runtime
```

### Named Implementations

```idris
[reverseOrd] Ord Nat where
  compare x y = compare y x  -- Reverse ordering

-- Use named implementation
sortReverse : List Nat -> List Nat
sortReverse = sort @{reverseOrd}
```

---

## Totality

### Total Functions

Functions that:
1. **Cover all inputs** (no missing patterns)
2. **Terminate** (all recursive calls decrease argument size)

```idris
%default total

-- ✅ Total
factorial : Nat -> Nat
factorial Z     = 1
factorial (S k) = (S k) * factorial k
```

### Partial Functions

```idris
-- ❌ Partial - non-terminating
partial
forever : Nat
forever = forever

-- ❌ Partial - incomplete patterns
partial
unsafeHead : List a -> a
unsafeHead (x :: xs) = x
```

### Covering Functions

```idris
covering
maybeHead : List a -> Maybe a
maybeHead []        = Nothing
maybeHead (x :: xs) = Just x
```

---

## Proofs and Theorems

### Proof Terms

```idris
-- Theorem: addition is commutative
plusCommutative : (n : Nat) -> (m : Nat) -> n + m = m + n
plusCommutative Z     m = sym (plusZeroRightNeutral m)
plusCommutative (S k) m =
  rewrite plusCommutative k m in
    plusSuccRightSucc m k
```

### Proof Tactics

```idris
-- Using rewrite
proofWithRewrite : (n : Nat) -> n + 0 = n
proofWithRewrite n = rewrite plusZeroRightNeutral n in Refl

-- Using impossible
absurd : (0 = S n) -> Void
absurd Refl impossible
```

---

## Type-Level Computation

Types can compute at compile-time:

```idris
-- Type-level addition
data SNat : Nat -> Type where
  SZ : SNat Z
  SS : SNat n -> SNat (S n)

-- Compute type-level addition
add : SNat n -> SNat m -> SNat (n + m)
add SZ     m = m
add (SS n) m = SS (add n m)
```

---

## Key Type System Features Summary

1. **Dependent types** - Types depend on values
2. **Multiplicities** - 0/1/unrestricted usage tracking
3. **First-class types** - Types as values
4. **Totality checking** - Provably terminating functions
5. **Proof terms** - Types-as-propositions, programs-as-proofs
6. **Linear types** - Resource protocol enforcement
7. **Compile-time computation** - Type-level evaluation
