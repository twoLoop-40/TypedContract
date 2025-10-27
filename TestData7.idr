module TestData7

-- Test with different variable name
public export
data TestPlus : Type where
  MkTestPlus : (a : Nat)
    -> (b : Nat)
    -> (c : Nat)
    -> (pf : plus a b = c)
    -> TestPlus
