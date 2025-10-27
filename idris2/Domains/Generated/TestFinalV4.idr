module Domains.TestFinalV4

------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat
  currency : String
  desc : String

public export
record DateInfo where
  constructor MkDateInfo
  dateString : String
  desc : String

public export
data DocumentType 
  = ServiceContract
  | SupplyContract
  | LicenseContract
  | ConsultingContract
  | GeneralContract

public export
Eq DocumentType where
  ServiceContract == ServiceContract = True
  SupplyContract == SupplyContract = True
  LicenseContract == LicenseContract = True
  ConsultingContract == ConsultingContract = True
  GeneralContract == GeneralContract = True
  _ == _ = False

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data ContractAmount : Type where
  MkContractAmount : (supplyValue : Nat)
    -> (vatValue : Nat)
    -> (totalValue : Nat)
    -> (validTotal : totalValue = supplyValue + vatValue)
    -> ContractAmount

public export
mkContractAmount : (supply : Nat) -> (vat : Nat) -> ContractAmount
mkContractAmount s v = MkContractAmount s v (s + v) Refl

public export
data ContractPeriod : Type where
  MkContractPeriod : (startDate : String)
    -> (endDate : String)
    -> (durationDays : Nat)
    -> (nonEmpty : durationDays `GT` Z)
    -> ContractPeriod

public export
mkContractPeriod : (start : String) -> (end : String) -> (days : Nat) -> {auto prf : days `GT` Z} -> ContractPeriod
mkContractPeriod start end days {prf} = MkContractPeriod start end days prf

public export
data PaymentSchedule : Type where
  MkPaymentSchedule : (milestones : List (String, Nat))
    -> (totalAmount : Nat)
    -> (sumValid : totalAmount = sum (map snd milestones))
    -> PaymentSchedule

public export
mkPaymentSchedule : (milestones : List (String, Nat)) -> PaymentSchedule
mkPaymentSchedule ms = MkPaymentSchedule ms (sum (map snd ms)) Refl

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
record ContractScope where
  constructor MkContractScope
  title : String
  description : String
  deliverables : List String
  specifications : List String

public export
record ContractTerms where
  constructor MkContractTerms
  purpose : String
  scopeOfWork : ContractScope
  obligations : List String
  warranties : List String
  liabilities : List String
  terminationClauses : List String

public export
record PaymentTerms where
  constructor MkPaymentTerms
  schedule : PaymentSchedule
  method : String
  bankAccount : String
  dueDate : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record GenericContract where
  constructor MkGenericContract
  documentType : DocumentType
  contractTitle : String
  partyA : Party
  partyB : Party
  contractAmount : ContractAmount
  contractPeriod : ContractPeriod
  terms : ContractTerms
  payment : PaymentTerms
  specialProvisions : List String
  signatureDate : DateInfo
  effectiveDate : DateInfo

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
examplePartyA : Party
examplePartyA = MkParty
  "발주자 주식회사"
  "김갑수"
  "123-45-67890"
  "서울특별시 강남구 테헤란로 123"
  "02-1234-5678"

public export
examplePartyB : Party
examplePartyB = MkParty
  "수주자 주식회사"
  "이을수"
  "098-76-54321"
  "서울특별시 서초구 서초대로 456"
  "02-8765-4321"

public export
exampleScope : ContractScope
exampleScope = MkContractScope
  "소프트웨어 개발 용역"
  "웹 기반 업무 관리 시스템 개발 및 구축"
  ["요구사항 분석서", "설계 문서", "소스 코드", "테스트 보고서", "사용자 매뉴얼"]
  ["웹 기반 시스템", "반응형 디자인", "데이터베이스 연동", "보안 인증"]

public export
exampleTerms : ContractTerms
exampleTerms = MkContractTerms
  "본 계약은 발주자의 업무 효율화를 위한 시스템 개발을 목적으로 한다"
  exampleScope
  ["수주자는 계약 기간 내 시스템을 완성하여 인도한다", "발주자는 필요한 자료를 적시에 제공한다"]
  ["수주자는 개발 결과물의 품질을 보증한다", "하자 발생 시 무상으로 수정한다"]
  ["수주자는 계약 불이행 시 위약금을 부담한다", "발주자는 대금 미지급 시 지연이자를 부담한다"]
  ["중대한 계약 위반 시 즉시 해지 가능", "천재지변 등 불가항력 시 협의하여 조정"]

public export
examplePaymentSchedule : PaymentSchedule
examplePaymentSchedule = mkPaymentSchedule
  [("계약금", 30000000), ("중도금", 30000000), ("잔금", 40000000)]

public export
examplePayment : PaymentTerms
examplePayment = MkPaymentTerms
  examplePaymentSchedule
  "계좌이체"
  "국민은행 123-456-789012 수주자(주)"
  "각 단계 완료 후 7일 이내"

public export
exampleAmount : ContractAmount
exampleAmount = mkContractAmount 100000000 10000000

public export
examplePeriod : ContractPeriod
examplePeriod = mkContractPeriod "2024-01-01" "2024-12-31" 365

public export
exampleContract : GenericContract
exampleContract = MkGenericContract
  ServiceContract
  "소프트웨어 개발 용역 계약서"
  examplePartyA
  examplePartyB
  exampleAmount
  examplePeriod
  exampleTerms
  examplePayment
  ["본 계약서에 명시되지 않은 사항은 상호 협의하여 결정한다", "계약 변경 시 서면 합의가 필요하다"]
  (MkDateInfo "2024-01-01" "계약 체결일")
  (MkDateInfo "2024-01-01" "계약 효력 발생일")