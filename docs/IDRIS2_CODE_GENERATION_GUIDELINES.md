# Idris2 Code Generation Guidelines

**작성일**: 2025-10-27
**목적**: AI 에이전트가 Idris2 코드를 생성할 때 반드시 따라야 하는 규칙

---

## 🚨 CRITICAL: Parser 제약사항

### 1. **짧은 인자 이름 사용 (가장 중요!)**

**문제**: Data constructor에서 긴 이름의 인자가 한 줄에 3개 이상 있으면 Idris2 parser가 실패합니다.

**원인**: Idris2 parser의 line length 제한 또는 identifier length 제한

**규칙**:
- ✅ 인자 이름은 **최대 6-8자 이내**로 짧게
- ✅ 약어 사용 권장: `gov`, `cash`, `tot`, `pf`, `curr`, `tgt`
- ❌ 긴 descriptive name은 피할 것: `govSupport`, `cashMatch`, `totalAmount`

**실패 예시**:
```idris
-- ❌ Parser Error: 긴 이름 3개 이상
data ExpenseItemAmount : Type where
  MkExpenseItemAmount : (govSupport : Nat) -> (cashMatch : Nat) -> (inKindMatch : Nat) -> ExpenseItemAmount

-- Error: Couldn't parse any alternatives:
-- 1: Expected 'case', 'if', 'do', application or operator expression.
```

**성공 예시**:
```idris
-- ✅ OK: 짧은 이름
data ExpenseItemAmount : Type where
  MkExpenseItemAmount : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> ExpenseItemAmount
```

**추가 검증**:
```idris
-- ✅ 2개 이하면 긴 이름도 OK
data Foo : Type where
  MkFoo : (govSupport : Nat) -> (cashMatch : Nat) -> Foo

-- ❌ 3개 이상이면서 긴 이름은 실패
data Foo : Type where
  MkFoo : (govSupport : Nat) -> (cashMatch : Nat) -> (total : Nat) -> Foo
```

**해결 방법**:
1. **짧은 이름 사용 (권장)**:
   ```idris
   data Expense : Type where
     MkExpense : (gov : Nat) -> (cash : Nat) -> (tot : Nat) -> Expense
   ```

2. **Multi-line (비권장, 들여쓰기 까다로움)**:
   ```idris
   data Expense : Type where
     MkExpense : (govSupport : Nat)
              -> (cashMatch : Nat)
              -> (total : Nat)
              -> Expense
   ```

---

### 2. **연산자 사용**

**규칙**:
- ✅ 산술 연산은 연산자 사용: `+`, `-`, `*`, `/`
- ❌ 함수 형태 사용 금지: `plus`, `minus`, `mult`

**실패 예시**:
```idris
-- ❌ plus/minus 함수는 존재하지 않음
data TotalBudget : Type where
  MkTotal : (tot : Nat) -> (gov : Nat) -> (self : Nat) -> (pf : tot = plus gov self) -> TotalBudget
```

**성공 예시**:
```idris
-- ✅ 연산자 사용
data TotalBudget : Type where
  MkTotal : (tot : Nat) -> (gov : Nat) -> (self : Nat) -> (pf : tot = gov + self) -> TotalBudget
```

**표준 연산자**:
- `+` : Nat, Integer 덧셈
- `-` : Nat, Integer 뺄셈 (Nat는 음수 불가)
- `*` : 곱셈
- `/` : 나눗셈
- `==` : 동등성 비교
- `<`, `<=`, `>`, `>=` : 대소 비교

---

### 3. **한 줄 작성 권장**

**규칙**:
- ✅ Data constructor는 가능한 한 한 줄로 작성
- ✅ Smart constructor도 한 줄로 작성
- ⚠️ Multi-line 들여쓰기는 parser 문제를 일으킬 수 있음

**권장 패턴**:
```idris
-- ✅ 한 줄 작성
data TotalBudget : Type where
  MkTotal : (tot : Nat) -> (gov : Nat) -> (self : Nat) -> (pf : tot = gov + self) -> TotalBudget

public export
mkTotal : (t : Nat) -> (g : Nat) -> (s : Nat) -> {auto prf : t = g + s} -> TotalBudget
mkTotal t g s {prf} = MkTotal t g s prf
```

**비권장 패턴** (파싱 실패 가능):
```idris
-- ⚠️ Multi-line with arbitrary indentation
data TotalBudget : Type where
  MkTotal : (totalAmount : Nat)
    -> (govSupport : Nat)
    -> (selfFunding : Nat)
    -> (proof : totalAmount = plus govSupport selfFunding)
    -> TotalBudget
```

---

## ✅ 일반 규칙

### 4. **모듈 구조**

```idris
module Domains.ProjectName

import Data.Fin
import Data.Vect
import Data.List
import Data.String
import Decidable.Equality

%default total
```

**주의사항**:
- 모듈 이름은 **PascalCase** (Idris2 규칙)
- `%default total`로 전체 함수의 totality 보장

---

### 5. **Public Export**

```idris
-- ✅ 모든 타입/함수에 public export
public export
data MyType : Type where
  MkMyType : Nat -> MyType

public export
myFunction : MyType -> Nat
myFunction (MkMyType n) = n
```

---

### 6. **의존 타입 패턴**

**증명이 필요한 타입**:
```idris
-- ✅ 의존 타입으로 불변식 표현
public export
data UnitPrice : Type where
  MkUnitPrice : (item : Nat) -> (qty : Nat) -> (tot : Nat) -> (pf : tot = item * qty) -> UnitPrice

-- ✅ Smart constructor로 자동 증명
public export
mkUnitPrice : (item : Nat) -> (qty : Nat) -> UnitPrice
mkUnitPrice item qty = MkUnitPrice item qty (item * qty) Refl
```

**증명이 불필요한 타입**:
```idris
-- ✅ Record 사용
public export
record Metadata where
  constructor MkMetadata
  title : String
  author : String
  date : String
```

---

### 7. **컬렉션**

```idris
-- ✅ List 사용
items : List String
items = ["item1", "item2", "item3"]

-- ✅ Vect (길이가 타입에 포함)
fixedItems : Vect 3 String
fixedItems = ["a", "b", "c"]

-- ✅ Tuple
pair : (String, Nat)
pair = ("test", 42)
```

---

### 8. **금지 사항**

```idris
-- ❌ IO 작업 금지 (순수 타입만)
myFunction : IO ()  -- 금지!

-- ❌ 부분 함수 금지
head : List a -> a  -- 빈 리스트에서 실패 가능! 금지!

-- ✅ Total 함수 사용
head : (xs : List a) -> {auto ok : NonEmpty xs} -> a
```

---

## 📝 체크리스트

AI 에이전트가 Idris2 코드를 생성한 후 반드시 확인:

- [ ] **Data constructor 인자 이름이 짧은가?** (최대 6-8자)
- [ ] **3개 이상의 인자가 한 줄에 있는가?** (있다면 이름을 짧게)
- [ ] **`plus`, `minus` 대신 `+`, `-` 사용했는가?**
- [ ] **모든 타입/함수에 `public export` 있는가?**
- [ ] **불변식이 의존 타입으로 표현되었는가?**
- [ ] **Smart constructor가 `Refl`로 자동 증명하는가?**
- [ ] **IO 작업이 없는가?**
- [ ] **모든 함수가 total한가?**

---

## 🔧 문제 해결

### Parser Error: "Expected 'case', 'if', 'do', application or operator expression"

**원인**: 긴 인자 이름이 한 줄에 3개 이상

**해결**: 인자 이름을 짧게 변경

```idris
-- Before (❌ 에러)
data Foo : Type where
  MkFoo : (govSupport : Nat) -> (cashMatch : Nat) -> (inKindMatch : Nat) -> Foo

-- After (✅ 성공)
data Foo : Type where
  MkFoo : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> Foo
```

### Error: "Can't find name plus"

**원인**: `plus` 함수 대신 `+` 연산자 사용해야 함

**해결**:
```idris
-- Before (❌)
(pf : total = plus supply vat)

-- After (✅)
(pf : total = supply + vat)
```

---

## 🎯 권장 네이밍 컨벤션

**약어 가이드**:
- `tot` : total
- `gov` : government
- `self` : selfFunding
- `curr` : current
- `tgt` : target
- `pf` : proof
- `qty` : quantity
- `amt` : amount
- `desc` : description
- `addr` : address
- `comp` : company
- `rep` : representative

**규칙**:
- 짧지만 의미를 유추할 수 있는 이름 사용
- 주석으로 full name 명시
- 일관성 유지

**예시**:
```idris
-- ✅ 좋은 예
data Budget : Type where
  -- | gov: government support, self: self-funding, tot: total budget
  MkBudget : (gov : Nat) -> (self : Nat) -> (tot : Nat) -> (pf : tot = gov + self) -> Budget
```

---

## 📚 참고 자료

- [Idris2 Language Reference](https://idris2.readthedocs.io/)
- [Dependent Types in Practice](https://www.cs.ru.nl/~freek/courses/tt-2014/papers/dependent-types-at-work.pdf)
- TypedContract 프로젝트: `/Domains/ScaleDeep.idr` (참고 구현)

---

**Last Updated**: 2025-10-27
**Verified with**: Idris2 v0.7.0
