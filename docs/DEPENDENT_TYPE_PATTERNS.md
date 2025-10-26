# Idris2 의존 타입 디자인 패턴

비즈니스 문서 모델링에서 자주 사용하는 의존 타입 패턴 모음입니다.

---

## 패턴 1: 계산 값 자동 증명

### 문제
금액 계산에서 수동 입력 시 실수 가능:

```idris
-- ❌ 나쁜 예: 실수 가능
record Invoice where
  supply : Nat
  vat : Nat
  total : Nat  -- supply + vat를 수동으로 계산해서 넣어야 함
```

### 해결
의존 타입으로 증명 첨부:

```idris
-- ✅ 좋은 예: 컴파일러가 검증
data Invoice : Type where
  MkInvoice : (supply : Nat)
    -> (vat : Nat)
    -> (total : Nat)
    -> (proof : total = supply + vat)  -- 자동 검증!
    -> Invoice

-- Smart constructor로 자동 증명
mkInvoice : Nat -> Nat -> Invoice
mkInvoice s v = MkInvoice s v (s + v) Refl
```

### 사용
```idris
-- 컴파일 타임에 검증됨
invoice1 : Invoice
invoice1 = mkInvoice 50000000 5000000

-- 잘못된 값은 컴파일 에러
invoice2 : Invoice
invoice2 = MkInvoice 50000000 5000000 60000000 Refl  -- ERROR!
```

---

## 패턴 2: 비율 계산 증명

### 문제
VAT는 공급가액의 10%여야 함:

```idris
-- ❌ 나쁜 예: VAT를 아무 값으로나 넣을 수 있음
record Contract where
  supply : Nat
  vat : Nat  -- 10%인지 보장 없음
```

### 해결
VAT 계산을 타입으로 강제:

```idris
-- ✅ 좋은 예: VAT가 정확히 10%임을 보장
data Contract : Type where
  MkContract : (supply : Nat)
    -> (vat : Nat)
    -> (vatCorrect : vat = supply / 10)  -- 10% 증명
    -> Contract

-- Smart constructor
mkContract : Nat -> Contract
mkContract s =
  let v = s / 10
  in MkContract s v Refl
```

### 사용
```idris
contract : Contract
contract = mkContract 50650000
-- 자동으로 VAT = 5065000 계산되고 증명됨
```

---

## 패턴 3: 단가 × 수량 = 총액

### 문제
```idris
-- ❌ 나쁜 예: 곱셈 실수 가능
record Order where
  unitPrice : Nat
  quantity : Nat
  totalAmount : Nat  -- 수동 계산 필요
```

### 해결
```idris
-- ✅ 좋은 예: 곱셈 자동 검증
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (proof : totalAmount = perItem * quantity)
    -> UnitPrice

-- Smart constructor
mkUnitPrice : Nat -> Nat -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl
```

### 실전 예: 스피라티 계약
```idris
-- 1,000원/문항 × 50,650문항 = 50,650,000원
spiratiPrice : UnitPrice
spiratiPrice = mkUnitPrice 1000 50650
-- 자동으로 총액 계산 및 증명!
```

---

## 패턴 4: 리스트 길이 보장

### 문제
산출물이 정확히 3개여야 하는데 검증 안됨:

```idris
-- ❌ 나쁜 예: 개수 보장 없음
record Project where
  deliverables : List Deliverable  -- 2개? 3개? 10개?
```

### 해결
길이를 타입에 포함:

```idris
-- ✅ 좋은 예: 길이를 타입으로 명시
data Vect : Nat -> Type -> Type where
  Nil : Vect 0 a
  (::) : a -> Vect n a -> Vect (S n) a

record Project where
  deliverables : Vect 3 Deliverable  -- 정확히 3개!
```

### 사용
```idris
-- 컴파일 타임에 개수 검증
deliverables3 : Vect 3 Deliverable
deliverables3 = d1 :: d2 :: d3 :: Nil  -- ✅ OK

deliverables2 : Vect 3 Deliverable
deliverables2 = d1 :: d2 :: Nil  -- ❌ 컴파일 에러!
```

---

## 패턴 5: 날짜 범위 검증

### 문제
```idris
-- ❌ 나쁜 예: 시작일 > 종료일 가능
record Period where
  startDate : String
  endDate : String
```

### 해결
(간단 버전, Date 타입 대신 String 사용)

```idris
-- ✅ 좋은 예: 검증 함수 제공
record Period where
  constructor MkPeriod
  startDate : String
  endDate : String

validPeriod : Period -> Bool
validPeriod p = p.startDate <= p.endDate

-- 또는 의존 타입 버전 (Date 타입 필요)
data ValidPeriod : Type where
  MkValidPeriod : (start : Date)
    -> (end : Date)
    -> (proof : start `isBefore` end)
    -> ValidPeriod
```

---

## 패턴 6: 열거형으로 상태 표현

### 문제
```idris
-- ❌ 나쁜 예: 잘못된 상태값 가능
record Contract where
  status : String  -- "draft", "active", "complted" (오타!)
```

### 해결
```idris
-- ✅ 좋은 예: 타입 안전한 열거형
data ContractStatus
  = Draft
  | Active
  | Completed
  | Terminated

record Contract where
  status : ContractStatus  -- 4가지 값만 가능
```

### 장점: 모든 경우 처리 강제
```idris
statusMessage : ContractStatus -> String
statusMessage Draft = "초안 작성 중"
statusMessage Active = "진행 중"
statusMessage Completed = "완료"
statusMessage Terminated = "종료"
-- 새 상태 추가 시 여기도 추가 안하면 컴파일 에러!
```

---

## 패턴 7: Newtype으로 타입 안전성

### 문제
```idris
-- ❌ 나쁜 예: 사업자번호와 전화번호 혼동 가능
record Party where
  businessNumber : String
  phoneNumber : String

-- 실수로 뒤바뀌어도 타입 체크 통과
party : Party
party = MkParty "02-1234-5678" "123-45-67890"  -- 😱
```

### 해결
```idris
-- ✅ 좋은 예: Newtype으로 구분
record BusinessNumber where
  constructor MkBusinessNo
  value : String

record PhoneNumber where
  constructor MkPhoneNo
  value : String

record Party where
  businessNumber : BusinessNumber
  phoneNumber : PhoneNumber

-- 타입 불일치로 컴파일 에러
party : Party
party = MkParty (MkPhoneNo "02-1234") (MkBusinessNo "123-45")  -- ❌
```

---

## 패턴 8: 누적 합계 증명

### 문제
여러 단계의 금액 합계가 맞는지 검증:

```idris
-- ❌ 나쁜 예: 각 단계 금액과 총액이 안맞을 수 있음
record PaymentSchedule where
  advance : Nat      -- 선급금
  interim : Nat      -- 중도금
  final : Nat        -- 잔금
  total : Nat        -- 총액 (수동 입력)
```

### 해결
```idris
-- ✅ 좋은 예: 합계 자동 증명
data PaymentSchedule : Type where
  MkPaymentSchedule : (advance : Nat)
    -> (interim : Nat)
    -> (final : Nat)
    -> (total : Nat)
    -> (proof : total = advance + interim + final)
    -> PaymentSchedule

-- Smart constructor
mkPaymentSchedule : Nat -> Nat -> Nat -> PaymentSchedule
mkPaymentSchedule a i f =
  MkPaymentSchedule a i f (a + i + f) Refl
```

### 실전 예: 스피라티 지급 일정
```idris
spiratiPayment : PaymentSchedule
spiratiPayment = mkPaymentSchedule
  20000000  -- 선급금
  15000000  -- 중도금
  20715000  -- 잔금
-- 자동으로 총 55,715,000원 계산됨
```

---

## 패턴 9: 선택적 필드 (Maybe)

### 문제
```idris
-- ❌ 나쁜 예: 빈 문자열로 "없음" 표현
record Document where
  author : String  -- ""이면 없음?
  reviewedBy : String  -- ""이면 미검수?
```

### 해결
```idris
-- ✅ 좋은 예: Maybe로 명확히 표현
record Document where
  author : String
  reviewedBy : Maybe String  -- Nothing = 미검수, Just name = 검수 완료

-- 패턴 매칭으로 안전하게 처리
getReviewer : Document -> String
getReviewer doc = case doc.reviewedBy of
  Nothing => "미검수"
  Just name => "검수자: " ++ name
```

---

## 패턴 10: 비어있지 않은 리스트

### 문제
```idris
-- ❌ 나쁜 예: 산출물이 0개일 수 있음
record Contract where
  deliverables : List Deliverable  -- []도 가능
```

### 해결
```idris
-- ✅ 좋은 예: 최소 1개 보장
data NonEmpty : Type -> Type where
  MkNonEmpty : a -> List a -> NonEmpty a

record Contract where
  deliverables : NonEmpty Deliverable  -- 최소 1개!

-- 또는 Vect 사용
record Contract where
  deliverables : Vect (S n) Deliverable  -- S n = n+1, 최소 1개
```

---

## 실전 조합 예제

여러 패턴을 조합한 완전한 계약서:

```idris
-- 1. 단가 증명
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (total : Nat)
    -> (total = perItem * quantity)
    -> UnitPrice

-- 2. VAT 계산 증명
data ContractAmount : Type where
  MkAmount : (supply : Nat)
    -> (vat : Nat)
    -> (total : Nat)
    -> (vat = supply / 10)
    -> (total = supply + vat)
    -> ContractAmount

-- 3. 계약 상태
data Status = Draft | Active | Completed

-- 4. 전체 계약서
record ServiceContract where
  constructor MkContract
  contractNumber : String
  status : Status
  pricing : UnitPrice       -- 단가 증명 포함
  amount : ContractAmount   -- 금액 증명 포함
  deliverables : NonEmpty Deliverable  -- 최소 1개 보장

-- 사용
myContract : ServiceContract
myContract = MkContract
  "CONTRACT-2025-001"
  Active
  (mkUnitPrice 1000 50650)       -- 자동 증명
  (mkAmount 50650000)             -- VAT 자동 계산 및 증명
  (MkNonEmpty d1 [d2, d3])        -- 3개 산출물
```

---

## 요약

| 패턴 | 문제 | 해결 |
|------|------|------|
| 계산값 증명 | 수동 계산 실수 | `total = supply + vat` |
| 비율 계산 | VAT 계산 오류 | `vat = supply / 10` |
| 곱셈 증명 | 단가×수량 오류 | `total = price * qty` |
| 리스트 길이 | 개수 불일치 | `Vect n T` |
| 날짜 검증 | 잘못된 기간 | `start < end` 증명 |
| 열거형 | 잘못된 상태값 | `data Status = ...` |
| Newtype | 타입 혼동 | 별도 타입 정의 |
| 누적 합계 | 부분합 불일치 | `total = a + b + c` |
| 선택적 필드 | 빈 문자열 혼란 | `Maybe T` |
| 비어있지 않음 | 빈 리스트 | `NonEmpty T` 또는 `Vect (S n) T` |

---

## 다음 단계

이 패턴들을 조합하여 실제 도메인 모델을 작성할 때:

1. 참고 문서에서 **불변식** 식별
2. 적절한 **패턴 선택**
3. **Layer 1-5** 순서로 구성
4. **Smart constructor**로 증명 자동화
5. **타입 체크** 통과 확인

자세한 예제는 `Domains/ScaleDeep.idr` 참고.
