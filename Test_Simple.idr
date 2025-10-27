module Test_Simple

public export
data SimpleTest : Type where
  MkSimple : (a : Nat) -> 
             (b : Nat) -> 
             (c : Nat) ->
             (pf : c = a + b) ->
             SimpleTest
