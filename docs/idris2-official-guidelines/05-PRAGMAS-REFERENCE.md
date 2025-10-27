# Idris2 Pragmas Reference

**Source**: Official Idris2 Documentation
**Last Updated**: 2025-10-27

---

## Global Pragmas

Affect entire module or compilation.

### %language

Enable language extensions:

```idris
%language ElabReflection

-- Now can use elaborator reflection
%runElab (myMacro `{MyType})
```

**Available extensions**:
- `ElabReflection` - Metaprogramming with elaborator
- `UniqueSearch` - Unique interface resolution
- `AmbigDepth` - Ambiguity resolution depth

---

### %default

Set default totality requirement:

```idris
%default total      -- All functions must be total
%default covering   -- All functions must cover inputs
%default partial    -- No totality checking
```

**Example**:
```idris
%default total

factorial : Nat -> Nat
factorial Z     = 1
factorial (S k) = (S k) * factorial k  -- Must be provably total

partial  -- Override for specific function
forever : Nat
forever = forever
```

---

### %builtin

Convert recursive types to primitive representations:

```idris
%builtin Natural Nat

-- Nat now uses GMP integers instead of unary S(S(S(...)))
-- Massive performance improvement for arithmetic
```

---

### %name

Suggest names for compiler-generated variables:

```idris
%name Foo foo, bar, baz

-- When generating variables of type Foo, use: foo, foo1, bar, bar1, baz, ...
```

---

### %ambiguity_depth

Control ambiguous name resolution depth:

```idris
%ambiguity_depth 5  -- Default: 3

-- Resolve ambiguous identifiers up to depth 5
```

Higher values increase compile time but resolve more complex ambiguities.

---

### %totality_depth

Set constructor matching depth for totality checking:

```idris
%totality_depth 10  -- Default: 5

-- Check termination up to 10 constructor depth
```

---

### %auto_implicit_depth

Search depth for auto-implicit arguments:

```idris
%auto_implicit_depth 100  -- Default: 50

-- Search up to 100 steps for {auto ...} arguments
```

---

### %logging

Adjust compiler logging verbosity:

```idris
%logging "elab" 5       -- Elaboration logging at level 5
%logging "typesearch" 3 -- Type search logging
%logging "coverage" 2   -- Coverage checking logging
```

**Levels**: 0 (off) to 10 (very verbose)

**Topics**: `"elab"`, `"typesearch"`, `"coverage"`, `"compile"`, `"transform"`, etc.

---

### %prefix_record_projections

Control record projection naming (default: on):

```idris
%prefix_record_projections off

record Point where
  constructor MkPoint
  x : Double
  y : Double

-- With prefix: Point.x, Point.y
-- Without prefix: x, y (may cause name conflicts)
```

---

### %transform

Replace function at runtime with optimized implementation:

```idris
%transform "myOptimization" myFunc = optimizedFunc

-- Runtime calls to myFunc use optimizedFunc instead
```

---

### %unbound_implicits

Auto-add implicit bindings for unbound lowercase names (default: on):

```idris
%unbound_implicits off

-- Now must explicitly declare all implicits
foo : {n : Nat} -> Vect n a -> Nat
foo xs = ?hole
```

---

### %auto_lazy

Automatic delay/force insertion for `Inf` types (default: on):

```idris
%auto_lazy off

-- Must manually use Delay/Force constructors
```

---

### %search_timeout

Expression search timeout in milliseconds (default: 1000):

```idris
%search_timeout 5000  -- 5 seconds

-- Allow more time for proof search
```

---

### %nf_metavar_threshold

Maximum stuck applications during meta-variable unification (default: 25):

```idris
%nf_metavar_threshold 50

-- Allow more complex unification problems
```

---

### %cg

Include codegen directives in source:

```idris
%cg chez "optimization-level" "3"
%cg javascript "minify" "true"
```

---

## Declaration Pragmas

Affect specific declarations.

### %inline

Force function inlining at call sites:

```idris
%inline
fastHelper : Nat -> Nat
fastHelper n = n * 2

-- Calls replaced with: n * 2
```

---

### %noinline

Prevent function inlining:

```idris
%noinline
keepSeparate : Nat -> Nat
keepSeparate n = n + 1

-- Always a separate function call
```

---

### %tcinline

Inline function during totality checking only:

```idris
%tcinline
proofHelper : Nat -> Nat
proofHelper n = n + 1

-- Inlined for termination checking, not runtime
```

---

### %deprecate

Mark definitions as deprecated:

```idris
%deprecate "Use newFunc instead. See: https://docs.example.com/migration"
oldFunc : Nat -> Nat
oldFunc n = n + 1
```

---

### %hide

Hide definitions from imports:

```idris
%hide Prelude.(+)

-- Define custom (+) operator
(+) : MyNum -> MyNum -> MyNum
(+) = myAdd
```

---

### %unhide

Restore hidden definitions:

```idris
%hide Prelude.(+)
-- ... use custom (+) ...
%unhide Prelude.(+)
-- Now Prelude.(+) accessible again
```

---

### %unsafe

Mark unsafe functions (like `believe_me`) for highlighting:

```idris
%unsafe
trustMe : a -> b
trustMe = believe_me
```

---

### %spec

Specialize function for specific argument patterns:

```idris
%spec n
power : Nat -> Nat -> Nat
power base Z     = 1
power base (S k) = base * power base k

-- Generate specialized version when n is known at compile-time
result : Nat
result = power 2 10  -- Uses specialized version
```

---

### %foreign

Declare foreign function implementations:

```idris
%foreign "C:puts,libc"
puts : String -> PrimIO Int

%foreign "scheme:display"
schemeDisplay : String -> PrimIO ()

%foreign "javascript:lambda:(x) => console.log(x)"
jsLog : String -> PrimIO ()

-- Multiple backends
%foreign "C:sin,libm"
%foreign "javascript:Math.sin"
sin : Double -> Double
```

---

### %export

Export Idris functions to host language:

```idris
%export "javascript:myIdrisFunc"
myFunc : Int -> Int
myFunc x = x * 2

-- Callable from JavaScript as: myIdrisFunc(42)
```

---

### %hint

Mark function for auto-implicit search:

```idris
%hint
ordNat : Ord Nat
ordNat = ...

-- Used automatically when {auto prf : Ord Nat} needed
```

---

### %defaulthint

Hint used when no other hints match:

```idris
%defaulthint
showDefault : Show a
showDefault = ...

-- Fallback for {auto prf : Show a}
```

---

### %globalhint

Always-tried hint regardless of type:

```idris
%globalhint
globalHint : SomeInterface
globalHint = ...

-- Tried for all auto-implicit searches
```

---

### %extern

Declare externally implemented functions:

```idris
%extern
prim__newIORef : a -> PrimIO (IORef a)
```

---

### %macro

Mark elaboration functions as compile-time macros:

```idris
%macro
myMacro : Elab ()
myMacro = do
  -- Elaborate code here
  pure ()

-- Use: myMacro in source
```

---

## Expression Pragmas

Affect specific expressions.

### %runElab

Run elaboration script at compile-time:

```idris
%language ElabReflection

-- Generate code at compile-time
%runElab (deriveFunctor `{MyType})
```

---

### %search

Fill values using auto-implicit search:

```idris
orderedList : Ord a => List a -> Bool
orderedList xs = isSorted xs %search

-- %search finds appropriate Ord proof
```

---

### %syntactic

Abstract values syntactically (not semantically) after `with`:

```idris
foo : Nat -> Nat -> Nat
foo x y with %syntactic (x + y)
  foo x y | sum = sum * 2

-- sum is syntactically (x + y), not evaluated
```

Used for performance when semantic equality not needed.

---

## Common Pragma Combinations

### High-Performance Module

```idris
%default total
%builtin Natural Nat
%logging "compile" 0

%inline
add : Nat -> Nat -> Nat
add x y = x + y

%spec n
power : Nat -> Nat -> Nat
power base Z     = 1
power base (S k) = base * power base k
```

---

### FFI-Heavy Module

```idris
%foreign "C:malloc,libc"
malloc : Int -> PrimIO Ptr

%foreign "C:free,libc"
free : Ptr -> PrimIO ()

%foreign "C:memcpy,libc"
memcpy : Ptr -> Ptr -> Int -> PrimIO ()
```

---

### Development/Debugging Module

```idris
%default partial  -- Allow incomplete functions during development
%logging "elab" 3
%logging "coverage" 2
%ambiguity_depth 5
```

---

### Metaprogramming Module

```idris
%language ElabReflection

%macro
derive : Name -> Elab ()
derive n = ...

%runElab (derive `{MyType})
```

---

## Pragma Best Practices

1. **Use `%default total`** in production code
2. **Use `%inline`** for tiny frequently-called functions
3. **Use `%builtin Natural`** for Nat-heavy computation
4. **Keep `%logging` off** in production (performance)
5. **Use `%foreign` carefully** (breaks totality guarantees)
6. **Document `%unsafe` usage** thoroughly
7. **Prefer `%spec`** over manual specialization
8. **Use `%deprecate`** when changing APIs
9. **Test with `%default total`** even if starting with `partial`
