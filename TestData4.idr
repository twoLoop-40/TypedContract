module TestData4

-- Test with parentheses around +
public export
data TestPlus : Type where
  MkTestPlus : (a : Nat)
    -> (b : Nat)
    -> (c : Nat)
    -> (proof : c = (a + b))
    -> TestPlus
