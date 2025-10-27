module TestData3

-- Test with + operator
public export
data TestPlus : Type where
  MkTestPlus : (a : Nat)
    -> (b : Nat)
    -> (c : Nat)
    -> (proof : c = a + b)
    -> TestPlus
