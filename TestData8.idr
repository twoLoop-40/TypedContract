module TestData8

-- Test with mult to match * pattern
public export
data TestMult : Type where
  MkTestMult : (a : Nat)
    -> (b : Nat)
    -> (c : Nat)
    -> (pf : c = mult a b)
    -> TestMult
