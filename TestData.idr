module TestData

public export
data BudgetAmount : Type where
  MkBudgetAmount : (supply : Nat)
    -> (vat : Nat)
    -> (total : Nat)
    -> (validTotal : total = supply + vat)
    -> BudgetAmount
