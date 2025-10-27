module Domains.FinalTestV1

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
  year : Nat
  month : Nat
  day : Nat
  desc : String

public export
VATRate : Double
VATRate = 0.10

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data ContractAmount : Type where
  MkContractAmount : (supplyPrice : Nat)
    -> (vat : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = supplyPrice + vat)
    -> ContractAmount

public export
mkContractAmount : (supplyPrice : Nat) -> (vat : Nat) -> ContractAmount
mkContractAmount sp vt = MkContractAmount sp vt (sp + vt) Refl

public export
data ItemPricing : Type where
  MkItemPricing : (unitPrice : Nat)
    -> (quantity : Nat)
    -> (totalPrice : Nat)
    -> (validPrice : totalPrice = unitPrice * quantity)
    -> ItemPricing

public export
mkItemPricing : (unitPrice : Nat) -> (quantity : Nat) -> ItemPricing
mkItemPricing up qty = MkItemPricing up qty (up * qty) Refl

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record Party where
  constructor MkParty
  partyType : String
  companyName : String
  representative : String
  address : String
  businessNumber : String
  contact : String

public export
record ContractClause where
  constructor MkContractClause
  articleNumber : Nat
  title : String
  content : String

public export
record PaymentTerm where
  constructor MkPaymentTerm
  termName : String
  ratio : Nat
  amount : Money
  condition : String
  dueDate : String

public export
record ServiceItem where
  constructor MkServiceItem
  itemName : String
  specification : String
  pricing : ItemPricing
  deliveryDate : String
  remarks : String

public export
record ContractPeriod where
  constructor MkContractPeriod
  startDate : DateInfo
  endDate : DateInfo
  durationDays : Nat
  description : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record ServiceContract where
  constructor MkServiceContract
  contractTitle : String
  contractNumber : String
  contractDate : DateInfo
  clientParty : Party
  providerParty : Party
  contractPurpose : String
  serviceItems : List ServiceItem
  contractAmount : ContractAmount
  contractPeriod : ContractPeriod
  paymentTerms : List PaymentTerm
  clauses : List ContractClause
  specialConditions : List String
  attachments : List String

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleClientParty : Party
exampleClientParty = MkParty
  "발주자(갑)"
  "미정"
  "대표이사 미정"
  "주소 미정"
  "000-00-00000"
  "연락처 미정"

public export
exampleProviderParty : Party
exampleProviderParty = MkParty
  "수주자(을)"
  "미정"
  "대표이사 미정"
  "주소 미정"
  "000-00-00000"
  "연락처 미정"

public export
exampleContractDate : DateInfo
exampleContractDate = MkDateInfo
  2024
  1
  1
  "계약 체결일"

public export
exampleStartDate : DateInfo
exampleStartDate = MkDateInfo
  2024
  1
  1
  "계약 시작일"

public export
exampleEndDate : DateInfo
exampleEndDate = MkDateInfo
  2024
  12
  31
  "계약 종료일"

public export
exampleContractPeriod : ContractPeriod
exampleContractPeriod = MkContractPeriod
  exampleStartDate
  exampleEndDate
  365
  "1년간 용역 계약"

public export
exampleServiceItem : ServiceItem
exampleServiceItem = MkServiceItem
  "용역 서비스"
  "상세 내역 미정"
  (mkItemPricing 1000000 1)
  "2024-12-31"
  "특이사항 없음"

public export
exampleContractAmount : ContractAmount
exampleContractAmount = mkContractAmount 10000000 1000000

public export
examplePaymentTerm : PaymentTerm
examplePaymentTerm = MkPaymentTerm
  "계약금"
  30
  (MkMoney 3000000 "KRW" "계약 체결 시")
  "계약 체결 후 7일 이내"
  "2024-01-08"

public export
exampleClause1 : ContractClause
exampleClause1 = MkContractClause
  1
  "목적"
  "본 계약은 용역 제공에 관한 사항을 정함을 목적으로 한다."

public export
exampleClause2 : ContractClause
exampleClause2 = MkContractClause
  2
  "용역 내용"
  "수주자는 발주자에게 합의된 용역을 제공한다."

public export
exampleClause3 : ContractClause
exampleClause3 = MkContractClause
  3
  "계약 금액"
  "본 계약의 총 금액은 별도 명시된 금액으로 한다."

public export
exampleClause4 : ContractClause
exampleClause4 = MkContractClause
  4
  "계약 기간"
  "계약 기간은 별도 명시된 기간으로 한다."

public export
exampleClause5 : ContractClause
exampleClause5 = MkContractClause
  5
  "대금 지급"
  "발주자는 합의된 지급 조건에 따라 대금을 지급한다."

public export
exampleServiceContract : ServiceContract
exampleServiceContract = MkServiceContract
  "용역 계약서"
  "CONTRACT-2024-001"
  exampleContractDate
  exampleClientParty
  exampleProviderParty
  "용역 제공 계약"
  [exampleServiceItem]
  exampleContractAmount
  exampleContractPeriod
  [examplePaymentTerm]
  [exampleClause1, exampleClause2, exampleClause3, exampleClause4, exampleClause5]
  ["문서 파일을 찾을 수 없어 표준 템플릿으로 생성됨", "실제 계약 내용으로 업데이트 필요"]
  ["별첨 1: 상세 용역 명세서", "별첨 2: 기술 사양서"]