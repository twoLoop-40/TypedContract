module TestData5

-- Test with plus function
public export
data TestPlus : Type where
  MkTestPlus : (a : Nat)
    -> (b : Nat)
    -> (c : Nat)
    -> (proof : c = plus a b)
    -> TestPlus
