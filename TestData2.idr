module TestData2

public export
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)
    -> UnitPrice
