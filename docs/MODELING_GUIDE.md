# Idris2 도메인 모델링 가이드

## 목차

1. [모델링 원칙](#모델링-원칙)
2. [참고자료 분석](#참고자료-분석)
3. [타입 설계 단계](#타입-설계-단계)
4. [의존 타입 활용](#의존-타입-활용)
5. [실전 예제: 용역계약서](#실전-예제-용역계약서)

---

## 모델링 원칙

### 1. Make Illegal States Unrepresentable

**잘못된 데이터를 타입 시스템으로 방지**합니다.

```idris
-- ❌ 나쁜 예: 잘못된 날짜를 만들 수 있음
record DateRange where
  startDate : String
  endDate : String
  -- "2025-12-31" ~ "2025-01-01" 같은 잘못된 데이터 가능

-- ✅ 좋은 예: 타입으로 강제
data ValidDateRange : Type where
  MkDateRange : (start : Date)
    -> (end : Date)
    -> (proof : start `isBefore` end)
    -> ValidDateRange
```

### 2. 계층적 구성 (Layered Architecture)

복잡한 모델은 **레이어별로 점진적 구성**:

```
Layer 1: Primitives (Money, Date, Rate)
   ↓
Layer 2: Validated Types (UnitPrice with proof)
   ↓
Layer 3: Domain Entities (Party, Contract)
   ↓
Layer 4: Aggregates (ServiceContract)
```

### 3. 불변식을 증명으로 표현

**런타임 검증이 아닌 컴파일 타임 증명**:

```idris
-- 단가 × 수량 = 총액 증명
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)  -- 증명!
    -> UnitPrice
```

---

## 참고자료 분석

### 예시: 용역계약서.pdf 분석

#### 1단계: 문서 스캔

PDF를 열고 **섹션별로 항목 나열**:

```
[문서 제목]
- 용역계약서

[계약 당사자]
- 갑(발주자): 회사명, 대표자, 사업자번호, 주소, 연락처
- 을(수급자): 회사명, 대표자, 사업자번호, 주소, 연락처

[계약 조항]
- 제1조: 계약의 목적
- 제2조: 용역의 범위
- ...
- 제14조: 기타 특약사항

[금액]
- 공급가액: 50,650,000원
- 부가세: 5,065,000원
- 총 계약금액: 55,715,000원

[산출물]
- 1차 납품 (2025-11-05): 10,000문항
- 2차 납품 (2025-11-20): 50,650문항 (누계)
- 3차 납품 (2025-11-30): 최종
```

#### 2단계: 데이터 필드 추출

```markdown
## Party (계약 당사자)
- companyName: String
- representative: String
- businessNumber: String
- address: String
- contact: String

## ContractAmount (계약 금액)
- supplyPrice: Nat
- vat: Nat
- totalPrice: Nat
- **불변식**: totalPrice = supplyPrice + vat

## Deliverable (산출물)
- name: String
- format: List String
- dueDate: String
```

#### 3단계: 관계 및 제약조건 파악

```markdown
## 제약조건
1. VAT는 공급가액의 10%
2. 총액 = 공급가액 + VAT
3. 납품일자 ≤ 계약종료일
4. 산출물 수량의 합 = 총 계약 수량

## 계층 관계
ServiceContract
├── client: Party
├── contractor: Party
├── terms: ContractTerms
│   ├── purpose: String
│   ├── scope: String
│   ├── deliverables: List Deliverable
│   └── ...
└── amounts
```

---

## 타입 설계 단계

### Step 1: Primitive Types

가장 기본적인 타입부터 시작:

```idris
------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat
  desc : String

-- VAT 비율 상수
VATRate : Double
VATRate = 0.10
```

### Step 2: Validated Types with Proofs

불변식이 있는 타입 정의:

```idris
------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 포함)
------------------------------------------------------------

-- 단가 × 수량 = 총액 (자동 증명)
public export
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)
    -> UnitPrice

-- Smart constructor: 증명을 자동 생성
public export
mkUnitPrice : (perItem : Nat) -> (quantity : Nat) -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl
```

**핵심**: `Refl`은 `p * q = p * q`를 자동 증명합니다!

### Step 3: Domain Entities

비즈니스 엔티티 정의:

```idris
------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record Party where
  constructor MkParty
  companyName : String
  representative : String
  businessNumber : String
  address : String
  contact : String

public export
record Deliverable where
  constructor MkDeliverable
  name : String
  format : List String
  dueDate : String
```

### Step 4: Aggregate Root

전체를 아우르는 최상위 타입:

```idris
------------------------------------------------------------
-- Layer 4: 집합 루트 (Aggregate Root)
------------------------------------------------------------

public export
record ServiceContract where
  constructor MkServiceContract
  contractNumber : String
  contractDate : String
  client : Party
  contractor : Party
  terms : ContractTerms
  supplyPrice : Nat
  vat : Nat
  totalPrice : Nat
  attachments : List String

-- 검증 함수 (선택적)
validServiceContract : ServiceContract -> Bool
validServiceContract sc =
  sc.totalPrice == sc.supplyPrice + sc.vat &&
  sc.totalPrice == sc.terms.contractAmount
```

---

## 의존 타입 활용

### 패턴 1: 계산 값 증명

```idris
-- 문제: 공급가액과 VAT를 별도로 받으면 실수 가능
-- 해결: VAT를 자동 계산하고 증명 첨부

data ContractAmount : Type where
  MkAmount : (supply : Nat)
    -> (vat : Nat)
    -> (total : Nat)
    -> (vatCorrect : vat = supply / 10)
    -> (totalCorrect : total = supply + vat)
    -> ContractAmount

-- 사용: VAT와 총액이 자동으로 맞음을 보장
makeAmount : Nat -> ContractAmount
makeAmount supply =
  let vat = supply / 10
      total = supply + vat
  in MkAmount supply vat total Refl Refl
```

### 패턴 2: 리스트 길이 증명

```idris
-- 문제: 산출물 개수가 예상과 다를 수 있음
-- 해결: 길이를 타입에 포함

data DeliverableList : Nat -> Type where
  Nil : DeliverableList 0
  (::) : Deliverable
    -> DeliverableList n
    -> DeliverableList (S n)

-- 사용: 정확히 3개의 산출물이 필요함을 타입으로 명시
threeDeliverables : DeliverableList 3
threeDeliverables = d1 :: d2 :: d3 :: Nil
```

### 패턴 3: 열거형으로 모든 경우 처리

```idris
-- 계약 상태
data ContractStatus
  = Draft
  | Active
  | Completed
  | Terminated

-- 모든 상태를 처리하도록 강제
handleContract : ContractStatus -> String
handleContract Draft = "초안 작성 중"
handleContract Active = "진행 중"
handleContract Completed = "완료"
handleContract Terminated = "종료"
-- 만약 새 상태를 추가하면 컴파일 에러!
```

---

## 실전 예제: 용역계약서

### 참고 문서

```
direction/외주용역_사전승인_신청서.pdf
```

### 분석 결과

| 항목 | 값 |
|------|-----|
| 거래처 | ㈜이츠에듀 |
| 계약기간 | 2025-10-01 ~ 2025-11-30 |
| 공급가액 | 50,650,000원 |
| VAT | 5,065,000원 |
| 총액 | 55,715,000원 |
| 단가 | 1,000원/문항 |
| 수량 | 50,650문항 |

### 모델링 과정

#### Step 1: 기본 타입

```idris
module Domains.ScaleDeep

-- Money
record Money where
  constructor MkMoney
  value : Nat
  desc : String

-- VAT 상수
VATRate : Double
VATRate = 0.10
```

#### Step 2: 단가 모델 (증명 포함)

```idris
-- 단가 × 수량 = 총액 증명
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)
    -> UnitPrice

-- Smart constructor
mkUnitPrice : (perItem : Nat) -> (quantity : Nat) -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl

-- 구체적 데이터
unitPriceSpirati : UnitPrice
unitPriceSpirati = mkUnitPrice 1000 50650
-- 자동으로 1000 × 50650 = 50,650,000 증명됨!
```

#### Step 3: 산출물 일정

```idris
record Deliverable where
  constructor MkDeliverable
  name : String
  format : List String
  dueDate : String

deliverables : List Deliverable
deliverables =
  [ MkDeliverable
      "1차 데이터셋 (누적 10,000문항)"
      ["LaTeX(.tex)", "HWP(.hwp)"]
      "2025-11-05"
  , MkDeliverable
      "2차 중간검수 (50,650문항 완료)"
      ["LaTeX(.tex)", "HWP(.hwp)"]
      "2025-11-20"
  , MkDeliverable
      "3차 최종보고서"
      ["LaTeX(.tex)", "HWP(.hwp)"]
      "2025-11-30"
  ]
```

#### Step 4: 계약 당사자

```idris
record Party where
  constructor MkParty
  companyName : String
  representative : String
  businessNumber : String
  address : String
  contact : String

clientSpirati : Party
clientSpirati = MkParty
  "주식회사 스피라티"
  "대표이사 홍길동"
  "123-45-67890"
  "서울특별시 ..."
  "02-xxxx-xxxx"

contractorItsEdu : Party
contractorItsEdu = MkParty
  "주식회사 이츠에듀"
  "대표이사 이철용"
  "987-65-43210"
  "서울특별시 ..."
  "02-yyyy-yyyy"
```

#### Step 5: 계약 조항

```idris
record ContractTerms where
  constructor MkContractTerms
  purpose : String           -- 제1조
  scope : String            -- 제2조
  duration : (String, String)  -- 제3조
  location : String         -- 제4조
  deliverables : List Deliverable  -- 제5조
  contractAmount : Nat      -- 제6조
  paymentTerms : List String  -- 제7조
  rightsOwnership : String  -- 제8조
  confidentiality : String  -- 제9조
  warranties : String       -- 제10조
  forcemajeure : String     -- 제11조
  termination : String      -- 제12조
  disputeResolution : String  -- 제13조
  specialProvisions : List String  -- 제14조

mathInputContractTerms : ContractTerms
mathInputContractTerms = MkContractTerms
  "본 계약은 갑이 을에게 의뢰하는 수학문항 입력 및 검수 용역..."
  "1. AI 기반 수학문항 데이터베이스 구축\n2. 입력 및 검수..."
  ("2025년 10월 1일", "2025년 11월 30일")
  "을의 사업장 또는 재택근무..."
  deliverables
  55715000
  [ "1. 선급금: 20,000,000원..."
  , "2. 중도금: 15,000,000원..."
  , "3. 잔금: 20,715,000원..."
  ]
  "본 용역의 결과물에 대한 모든 지적재산권은 갑에게 귀속..."
  "을은 본 용역 수행 중 취득한 갑의 영업비밀..."
  "납품일로부터 30일간 하자에 대한 무상 수정..."
  "천재지변, 전쟁, 테러..."
  "일방 당사자가 계약을 위반하고 14일 이내에..."
  "분쟁 발생 시 갑의 본점 소재지 관할 법원..."
  [ "1. 본 계약서에 명시되지 않은 사항은..."
  , "2. 을은 작업 인력의 수학 전문성..."
  ]
```

#### Step 6: 최종 계약서

```idris
record ServiceContract where
  constructor MkServiceContract
  contractNumber : String
  contractDate : String
  client : Party
  contractor : Party
  terms : ContractTerms
  supplyPrice : Nat
  vat : Nat
  totalPrice : Nat
  attachments : List String

-- 검증 함수
validServiceContract : ServiceContract -> Bool
validServiceContract sc =
  sc.totalPrice == sc.supplyPrice + sc.vat &&
  sc.totalPrice == sc.terms.contractAmount

-- 완성된 계약서
public export
serviceContractSpiratiItsEdu : ServiceContract
serviceContractSpiratiItsEdu = MkServiceContract
  "SPRT-2025-001"
  "2025년 10월 1일"
  clientSpirati
  contractorItsEdu
  mathInputContractTerms
  50650000  -- 공급가액
  5065000   -- 부가세
  55715000  -- 총액
  [ "별첨 1: 과업지시서"
  , "별첨 2: 문항 입력 가이드라인"
  , "별첨 3: 메타데이터 규격서"
  , "별첨 4: 품질 검수 기준표"
  ]
```

### 타입 체크

```bash
idris2 --check Domains/ScaleDeep.idr
# ✅ 6/6: Building Domains.ScaleDeep
```

타입이 통과하면 **모든 불변식이 증명된 것**입니다!

---

## 체크리스트

모델링 시 확인:

- [ ] 참고 문서 분석 완료
- [ ] Layer 1: Primitive 타입 정의
- [ ] Layer 2: 불변식 포함된 타입 정의
- [ ] Layer 3: 도메인 엔티티 정의
- [ ] Layer 4: Aggregate 정의
- [ ] Smart constructor 작성 (증명 자동화)
- [ ] 구체적 데이터 인스턴스 작성
- [ ] 타입 체크 통과
- [ ] 검증 함수 작성 (선택)
- [ ] public export로 외부 노출

---

## 다음 단계

모델링 완료 후:

1. `Core/DomainToDoc.idr`에 `Documentable` 인스턴스 추가
2. `Core/Generator.idr`에 파이프라인 생성
3. `Main.idr`에서 실행
4. `output/` 폴더에서 생성된 PDF 확인

자세한 내용은 `docs/WORKFLOW.md` 참고.
