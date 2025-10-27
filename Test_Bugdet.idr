module Test_Bugdet

public export
data Expense : Type where
  MkExpense : (a : Nat) -> (b : Nat) -> (c : Nat) -> Expense
