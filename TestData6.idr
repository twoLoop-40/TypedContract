module TestData6

-- Test reversing equality
public export
data TestPlus : Type where
  MkTestPlus : (a : Nat)
    -> (b : Nat)
    -> (c : Nat)
    -> (proof : plus a b = c)
    -> TestPlus
