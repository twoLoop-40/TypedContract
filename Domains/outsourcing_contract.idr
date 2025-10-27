module Domains.OutsourcingContract

------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat
  desc : String

public export
VATRate : Double
VATRate = 0.10

public export
record DateRange where
  constructor MkDateRange
  startDate : String
  endDate : String
  desc : String

public export
record BusinessNumber where
  constructor MkBusinessNumber
  number : String
  desc : String

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data BudgetAmount : Type where
  MkBudgetAmount : (supply : Nat) ->
                   (vat : Nat) ->
                   (total : Nat) ->
                   (0 validTotal : total = supply + vat) ->
                   BudgetAmount

public export
mkBudgetAmount : (supply : Nat) -> (vat : Nat) -> BudgetAmount
mkBudgetAmount s v = MkBudgetAmount s v (s + v) Refl

public export
data ProjectBudget : Type where
  MkProjectBudget : (totalBudget : Nat) ->
                    (allocatedBudget : Nat) ->
                    (remainingBudget : Nat) ->
                    (0 validRemaining : remainingBudget = minus totalBudget allocatedBudget) ->
                    ProjectBudget

public export
mkProjectBudget : (total : Nat) -> (allocated : Nat) -> ProjectBudget
mkProjectBudget t a = MkProjectBudget t a (minus t a) Refl

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record Company where
  constructor MkCompany
  companyName : String
  businessNumber : BusinessNumber
  representative : String
  address : String
  contact : String

public export
record BusinessPeriod where
  constructor MkBusinessPeriod
  period : DateRange
  durationMonths : Nat
  milestones : List String

public export
record FinancialPlan where
  constructor MkFinancialPlan
  totalBudget : BudgetAmount
  projectBudget : ProjectBudget
  fundingSources : List (String, Nat)
  expenditurePlan : List (String, Nat)

public export
record MarketAnalysis where
  constructor MkMarketAnalysis
  targetMarket : String
  marketSize : Nat
  competitors : List String
  competitiveAdvantage : String
  marketTrends : List String

public export
record OrganizationStructure where
  constructor MkOrganizationStructure
  departments : List String
  keyPersonnel : List (String, String)
  totalEmployees : Nat
  organizationChart : String

public export
record BusinessContent where
  constructor MkBusinessContent
  businessType : String
  mainProducts : List String
  mainServices : List String
  businessModel : String
  valueProposition : String

public export
record Schedule where
  constructor MkSchedule
  phase : String
  period : DateRange
  deliverables : List String
  milestones : List String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record OutsourcingContract where
  constructor MkOutsourcingContract
  company : Company
  businessContent : BusinessContent
  businessPeriod : BusinessPeriod
  marketAnalysis : MarketAnalysis
  financialPlan : FinancialPlan
  organizationStructure : OrganizationStructure
  schedules : List Schedule
  contractType : String
  status : String
  remarks : String

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleCompany : Company
exampleCompany = MkCompany
  "주식회사 스피라티"
  (MkBusinessNumber "000-00-00000" "사업자등록번호")
  "홍길동"
  "서울특별시 강남구"
  "02-0000-0000"

public export
exampleBusinessNumber : BusinessNumber
exampleBusinessNumber = MkBusinessNumber "123-45-67890" "사업자등록번호"

public export
exampleDateRange : DateRange
exampleDateRange = MkDateRange "2024-01-01" "2024-12-31" "사업기간"

public export
exampleBusinessPeriod : BusinessPeriod
exampleBusinessPeriod = MkBusinessPeriod
  exampleDateRange
  12
  ["1분기 완료", "2분기 완료", "3분기 완료", "4분기 완료"]

public export
exampleBudgetAmount : BudgetAmount
exampleBudgetAmount = mkBudgetAmount 100000000 10000000

public export
exampleProjectBudget : ProjectBudget
exampleProjectBudget = mkProjectBudget 110000000 50000000

public export
exampleFinancialPlan : FinancialPlan
exampleFinancialPlan = MkFinancialPlan
  exampleBudgetAmount
  exampleProjectBudget
  [("자체자금", 50000000), ("외부투자", 60000000)]
  [("인건비", 40000000), ("운영비", 30000000), ("마케팅비", 20000000), ("기타", 20000000)]

public export
exampleMarketAnalysis : MarketAnalysis
exampleMarketAnalysis = MkMarketAnalysis
  "IT 아웃소싱 시장"
  500000000000
  ["경쟁사A", "경쟁사B", "경쟁사C"]
  "전문성과 신속한 대응"
  ["디지털 전환 가속화", "클라우드 수요 증가", "AI 기술 도입"]

public export
exampleOrganizationStructure : OrganizationStructure
exampleOrganizationStructure = MkOrganizationStructure
  ["경영지원팀", "개발팀", "영업팀", "운영팀"]
  [("대표이사", "홍길동"), ("개발이사", "김철수"), ("영업이사", "이영희")]
  50
  "대표이사 - 각 부서"

public export
exampleBusinessContent : BusinessContent
exampleBusinessContent = MkBusinessContent
  "IT 아웃소싱"
  ["소프트웨어 개발", "시스템 통합"]
  ["IT 컨설팅", "유지보수", "기술지원"]
  "B2B 아웃소싱 서비스"
  "고품질 IT 서비스 제공"

public export
exampleSchedule : Schedule
exampleSchedule = MkSchedule
  "1단계: 기획 및 설계"
  (MkDateRange "2024-01-01" "2024-03-31" "1분기")
  ["요구사항 분석서", "설계 문서"]
  ["킥오프 미팅", "설계 완료"]

public export
exampleOutsourcingContract : OutsourcingContract
exampleOutsourcingContract = MkOutsourcingContract
  exampleCompany
  exampleBusinessContent
  exampleBusinessPeriod
  exampleMarketAnalysis
  exampleFinancialPlan
  exampleOrganizationStructure
  [exampleSchedule]
  "수정사업계획서"
  "진행중"
  "2024년도 수정 사업계획서"