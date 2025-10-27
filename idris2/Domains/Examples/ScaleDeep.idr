module Domains.ScaleDeep

------------------------------------------------------------
-- 1. 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat      -- 단위: 원
  desc  : String   -- 설명

VATRate : Double
VATRate = 0.10


------------------------------------------------------------
-- 2. 문항 단가 및 수량
------------------------------------------------------------

public export
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)
    -> UnitPrice

mkUnitPrice : (perItem : Nat) -> (quantity : Nat) -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl

unitPriceSpirati : UnitPrice
unitPriceSpirati = mkUnitPrice 1000 50650


------------------------------------------------------------
-- 3. 산출물 제출 일정
------------------------------------------------------------

public export
record Deliverable where
  constructor MkDeliverable
  name : String
  format : List String
  dueDate : String

deliverables : List Deliverable
deliverables =
  [ MkDeliverable
      "1차 데이터셋 (누적 10,000문항 이상, 한글파일 5,000문항 이상)"
      ["LaTeX(.tex) 10,000문항", "편집본 HWP(.hwp) 5,000문항 이상"]
      "2025-11-05"
  , MkDeliverable
      "2차 중간검수 결과 (전체 50,650문항 한글파일 100% 완료)"
      ["LaTeX(.tex)", "편집본 HWP(.hwp) 50,650문항 전체 완료"]
      "2025-11-20"
  , MkDeliverable
      "3차 최종보고서 (전체 50,650문항 LaTeX+한글 모두 완료)"
      ["LaTeX(.tex) 50,650문항", "편집본 HWP(.hwp) 50,650문항"]
      "2025-11-30"
  ]


------------------------------------------------------------
-- 4. 과업 명세 (TaskSpec)
------------------------------------------------------------

public export
record TaskSpec where
  constructor MkTaskSpec
  taskName : String
  description : String
  duration : (String, String)  -- (start, end)
  deliverables : List Deliverable
  qualityStandard : String

public export
mathInputSpec : TaskSpec
mathInputSpec = MkTaskSpec
  "수학문항 입력 및 검수 용역"
  "AI 기반 수학문항 데이터베이스 구축을 위한 입력/검수 및 표준화"
  ("2025-10-01", "2025-11-30")
  deliverables
  "문항입력 정확도 98% 이상, 오탈자율 2% 이하"


------------------------------------------------------------
-- 5. 계약 정보 (Contract)
------------------------------------------------------------

public export
record Contract where
  constructor MkContract
  client : String
  contractor : String
  supplyPrice : Nat
  vat : Nat
  totalPrice : Nat
  paymentSchedule : List String
  vatSupported : Bool

-- Contract 검증 함수
validContract : Contract -> Bool
validContract c = c.totalPrice == c.supplyPrice + c.vat

contractSpiratiItsEdu : Contract
contractSpiratiItsEdu = MkContract
  "㈜스피라티"
  "㈜이츠에듀"
  50650000
  5065000
  55715000
  ["선급금 20,000,000원 지급: 계약 체결 후 7일 이내",
   "잔금 35,715,000원 지급: 11월 30일 최종검수 승인 후"]
  False


------------------------------------------------------------
-- 6. 거래명세 정보 (Transaction)
------------------------------------------------------------

public export
record Transaction where
  constructor MkTransaction
  supplier : String
  receiver : String
  item : String
  unitPrice : Nat
  quantity : Nat
  supplyPrice : Nat
  vat : Nat
  totalAmount : Nat

-- Transaction 검증 함수
validTransaction : Transaction -> Bool
validTransaction t = t.totalAmount == t.supplyPrice + t.vat

public export
transactionItsEdu : Transaction
transactionItsEdu = MkTransaction
  "㈜이츠에듀"
  "㈜스피라티"
  "수학문항 입력 및 검수 용역"
  1000
  50650
  50650000
  5065000
  55715000


------------------------------------------------------------
-- 7. 비교견적서 정보 (Quotations)
------------------------------------------------------------

public export
record Quotation where
  constructor MkQuotation
  company : String
  rep : String
  supply : Nat
  vat : Nat
  totalAmount : Nat
  selected : Bool

quotations : List Quotation
quotations =
  [ MkQuotation "㈜이츠에듀" "이철용" 50650000 5065000 55715000 True
  , MkQuotation "㈜공감수학" "지영주" 52000000 5200000 57200000 False
  ]


------------------------------------------------------------
-- 8. 용역계약서 (ServiceContract)
------------------------------------------------------------

-- 계약 당사자 정보
public export
record Party where
  constructor MkParty
  companyName : String
  representative : String
  businessNumber : String
  address : String
  contact : String

-- 계약 조항
public export
record ContractTerms where
  constructor MkContractTerms
  purpose : String                    -- 제1조: 계약의 목적
  scope : String                      -- 제2조: 용역의 범위
  duration : (String, String)         -- 제3조: 용역 기간 (시작일, 종료일)
  location : String                   -- 제4조: 용역 장소
  deliverables : List Deliverable     -- 제5조: 산출물
  contractAmount : Nat                -- 제6조: 계약금액 (공급가액+부가세)
  paymentTerms : List String          -- 제7조: 대금지급 조건
  rightsOwnership : String            -- 제8조: 지적재산권 귀속
  confidentiality : String            -- 제9조: 비밀유지
  warranties : String                 -- 제10조: 하자담보책임
  forcemajeure : String               -- 제11조: 불가항력
  termination : String                -- 제12조: 계약해지
  disputeResolution : String          -- 제13조: 분쟁해결
  specialProvisions : List String     -- 제14조: 기타 특약사항

-- 용역계약서 전체 구조
public export
record ServiceContract where
  constructor MkServiceContract
  contractNumber : String             -- 계약번호
  contractDate : String               -- 계약 체결일
  client : Party                      -- 갑 (발주자)
  contractor : Party                  -- 을 (수급자)
  terms : ContractTerms               -- 계약 조항
  supplyPrice : Nat                   -- 공급가액
  vat : Nat                          -- 부가가치세
  totalPrice : Nat                    -- 총 계약금액
  attachments : List String           -- 첨부서류 목록

-- 용역계약서 검증 함수
validServiceContract : ServiceContract -> Bool
validServiceContract sc =
  sc.totalPrice == sc.supplyPrice + sc.vat &&
  sc.totalPrice == sc.terms.contractAmount

-- 스피라티-이츠에듀 용역계약 당사자 정보
clientSpirati : Party
clientSpirati = MkParty
  "주식회사 스피라티"
  "대표이사 홍길동"  -- 실제 대표이사명으로 교체 필요
  "123-45-67890"      -- 실제 사업자등록번호로 교체 필요
  "서울특별시 ..."    -- 실제 주소로 교체 필요
  "02-xxxx-xxxx"      -- 실제 연락처로 교체 필요

contractorItsEdu : Party
contractorItsEdu = MkParty
  "주식회사 이츠에듀"
  "대표이사 이철용"
  "987-65-43210"      -- 실제 사업자등록번호로 교체 필요
  "서울특별시 ..."    -- 실제 주소로 교체 필요
  "02-yyyy-yyyy"      -- 실제 연락처로 교체 필요

-- 계약 조항
mathInputContractTerms : ContractTerms
mathInputContractTerms = MkContractTerms
  -- 제1조: 계약의 목적
  "본 계약은 갑이 을에게 의뢰하는 수학문항 입력 및 검수 용역(이하 '본 용역'이라 한다)의 수행에 관한 제반 사항을 정함을 목적으로 한다."

  -- 제2조: 용역의 범위
  "1. AI 기반 수학문항 데이터베이스 구축을 위한 문항 입력 작업\n2. 입력된 문항에 대한 1차 검수 및 오류 수정\n3. LaTeX 원본 및 한글 편집본 동시 제작\n4. 스피라티 메타데이터 규격에 따른 표준화 작업\n5. 총 50,650문항에 대한 입력/검수 완료"

  -- 제3조: 용역 기간
  ("2025년 10월 1일", "2025년 11월 30일")

  -- 제4조: 용역 장소
  "을의 사업장 또는 재택근무가 가능한 장소. 단, 갑의 요청이 있을 경우 갑의 사업장에서 작업할 수 있다."

  -- 제5조: 산출물
  deliverables

  -- 제6조: 계약금액
  55715000  -- 공급가액 50,650,000원 + 부가세 5,065,000원

  -- 제7조: 대금지급 조건
  [ "1. 선급금: 계약 체결 후 7일 이내에 금 20,000,000원(공급가액 18,181,818원, 부가세 1,818,182원)을 을의 지정 계좌로 지급한다."
  , "2. 중도금: 2차 납품(2025년 11월 20일) 검수 완료 후 7일 이내에 금 15,000,000원(공급가액 13,636,364원, 부가세 1,363,636원)을 지급할 수 있다."
  , "3. 잔금: 최종 산출물 납품 및 검수 완료(2025년 11월 30일) 후 7일 이내에 금 20,715,000원(공급가액 18,831,818원, 부가세 1,883,182원)을 지급한다."
  , "4. 모든 대금은 을이 적법한 세금계산서를 발행한 후 지급한다."
  ]

  -- 제8조: 지적재산권 귀속
  "본 용역의 수행 결과물에 대한 모든 지적재산권(저작권, 데이터베이스권 등)은 갑에게 귀속되며, 을은 갑의 사전 서면 동의 없이 제3자에게 양도, 대여, 공개할 수 없다."

  -- 제9조: 비밀유지
  "을은 본 용역 수행 중 취득한 갑의 영업비밀, 기술정보, 고객정보 등 일체의 비밀정보를 제3자에게 누설하거나 본 용역 이외의 목적으로 사용할 수 없으며, 이는 계약 종료 후에도 유효하다."

  -- 제10조: 하자담보책임
  "1. 을은 납품일로부터 30일간 산출물의 하자에 대한 무상 수정 의무를 진다.\n2. 하자의 범위: 오탈자, 수식 오류, 메타데이터 누락, 형식 불일치 등\n3. 정확도 98% 미달 시 을은 미달 부분에 대해 무상 재작업을 수행한다."

  -- 제11조: 불가항력
  "천재지변, 전쟁, 테러, 감염병 확산 등 불가항력적 사유로 본 계약의 이행이 불가능한 경우, 당사자는 상대방에게 즉시 통보하고 계약 이행 기간의 연장 또는 계약 해지를 협의할 수 있다."

  -- 제12조: 계약해지
  "1. 일방 당사자가 본 계약을 위반하고 14일 이내에 시정하지 않을 경우 상대방은 계약을 해지할 수 있다.\n2. 을의 귀책사유로 계약이 해지될 경우, 을은 수령한 선급금을 반환하고 갑의 손해를 배상한다.\n3. 갑의 귀책사유로 계약이 해지될 경우, 갑은 기 수행된 용역에 대한 대금을 지급하고 을의 손해를 배상한다."

  -- 제13조: 분쟁해결
  "본 계약과 관련하여 분쟁이 발생할 경우, 당사자는 우선 상호 협의하여 해결하며, 협의가 이루어지지 않을 경우 갑의 본점 소재지 관할 법원을 전속 관할 법원으로 한다."

  -- 제14조: 기타 특약사항
  [ "1. 본 계약서에 명시되지 않은 사항은 관련 법령 및 상관례에 따른다."
  , "2. 을은 작업 인력의 수학 전문성 및 LaTeX 편집 숙련도를 보증한다."
  , "3. 갑은 을에게 문항 원본 데이터 및 입력 가이드라인을 제공한다."
  , "4. 주차별 진행 상황 보고 및 품질 리포트 제출은 을의 의무사항이다."
  ]

-- 스피라티-이츠에듀 용역계약서
public export
serviceContractSpiratiItsEdu : ServiceContract
serviceContractSpiratiItsEdu = MkServiceContract
  "SPRT-2025-001"                    -- 계약번호
  "2025년 10월 1일"                  -- 계약 체결일
  clientSpirati                      -- 갑
  contractorItsEdu                   -- 을
  mathInputContractTerms             -- 계약 조항
  50650000                           -- 공급가액
  5065000                            -- 부가세
  55715000                           -- 총 계약금액
  [ "별첨 1: 과업지시서"
  , "별첨 2: 문항 입력 가이드라인"
  , "별첨 3: 메타데이터 규격서"
  , "별첨 4: 품질 검수 기준표"
  ]


------------------------------------------------------------
-- 9. 전체 외주용역 패키지 (OutsourcingPackage)
------------------------------------------------------------

public export
record OutsourcingPackage where
  constructor MkOutsourcingPackage
  task : TaskSpec
  contract : Contract
  serviceContract : ServiceContract   -- 상세 용역계약서 추가
  transaction : Transaction
  quotes : List Quotation

-- 검증 함수들
validPriceConsistency : OutsourcingPackage -> Bool
validPriceConsistency pkg =
  pkg.contract.supplyPrice == pkg.transaction.supplyPrice &&
  pkg.contract.supplyPrice == pkg.serviceContract.supplyPrice

validDeadline : OutsourcingPackage -> Bool
validDeadline pkg = (snd pkg.task.duration) == "2025-11-30"

validContractTermsConsistency : OutsourcingPackage -> Bool
validContractTermsConsistency pkg =
  pkg.task.duration == pkg.serviceContract.terms.duration

outsourcingSpirati : OutsourcingPackage
outsourcingSpirati = MkOutsourcingPackage
  mathInputSpec
  contractSpiratiItsEdu
  serviceContractSpiratiItsEdu
  transactionItsEdu
  quotations
