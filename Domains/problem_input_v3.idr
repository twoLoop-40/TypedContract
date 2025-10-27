module Domains.ProblemInputV3

------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat
  desc : String

public export
record DateRange where
  constructor MkDateRange
  startDate : String
  endDate : String
  desc : String

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data CapitalStructure : Type where
  MkCapitalStructure : (totalBudget : Nat)
    -> (equity : Nat)
    -> (debt : Nat)
    -> (validSum : totalBudget = equity + debt)
    -> CapitalStructure

public export
mkCapitalStructure : (equity : Nat) -> (debt : Nat) -> CapitalStructure
mkCapitalStructure e d = MkCapitalStructure (e + d) e d Refl

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record CompanyInfo where
  constructor MkCompanyInfo
  companyName : String
  businessNumber : String
  representative : String
  address : String

public export
record BusinessContent where
  constructor MkBusinessContent
  businessType : String
  mainProducts : List String
  targetMarket : String
  description : String

public export
record MarketAnalysis where
  constructor MkMarketAnalysis
  marketSize : String
  competitors : List String
  competitiveAdvantage : String
  marketTrends : String

public export
record FinancialPlan where
  constructor MkFinancialPlan
  capital : CapitalStructure
  revenueProjection : List (String, Nat)
  costProjection : List (String, Nat)
  profitProjection : String

public export
record OrganizationStructure where
  constructor MkOrganizationStructure
  departments : List String
  keyPersonnel : List (String, String)
  employeeCount : Nat
  organizationChart : String

public export
record Schedule where
  constructor MkSchedule
  milestones : List (String, String)
  phases : List (String, DateRange)
  criticalPath : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlan where
  constructor MkBusinessPlan
  documentTitle : String
  version : String
  company : CompanyInfo
  businessPeriod : DateRange
  businessContent : BusinessContent
  marketAnalysis : MarketAnalysis
  financialPlan : FinancialPlan
  organization : OrganizationStructure
  schedule : Schedule
  remarks : String

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleCompanyInfo : CompanyInfo
exampleCompanyInfo = MkCompanyInfo
  "주식회사 스피라티"
  "123-45-67890"
  "홍길동"
  "서울특별시 강남구"

public export
exampleBusinessContent : BusinessContent
exampleBusinessContent = MkBusinessContent
  "소프트웨어 개발"
  ["AI 솔루션", "클라우드 서비스", "데이터 분석"]
  "국내 중소기업"
  "혁신적인 AI 기반 비즈니스 솔루션 제공"

public export
exampleMarketAnalysis : MarketAnalysis
exampleMarketAnalysis = MkMarketAnalysis
  "연간 5조원 규모"
  ["경쟁사A", "경쟁사B", "경쟁사C"]
  "차별화된 기술력과 고객 맞춤형 서비스"
  "AI 및 클라우드 시장 지속 성장 예상"

public export
exampleCapital : CapitalStructure
exampleCapital = mkCapitalStructure 300000000 200000000

public export
exampleFinancialPlan : FinancialPlan
exampleFinancialPlan = MkFinancialPlan
  exampleCapital
  [("1차년도", 500000000), ("2차년도", 800000000), ("3차년도", 1200000000)]
  [("인건비", 300000000), ("운영비", 150000000), ("마케팅비", 50000000)]
  "3년차 흑자 전환 예상"

public export
exampleOrganization : OrganizationStructure
exampleOrganization = MkOrganizationStructure
  ["경영지원팀", "개발팀", "영업팀", "마케팅팀"]
  [("대표이사", "홍길동"), ("CTO", "김철수"), ("CFO", "이영희")]
  25
  "CEO 직속 4개 부서 운영"

public export
exampleSchedule : Schedule
exampleSchedule = MkSchedule
  [("사업 개시", "2024-01-01"), ("제품 출시", "2024-06-01"), ("손익분기", "2026-12-31")]
  [("준비단계", MkDateRange "2024-01-01" "2024-03-31" "초기 준비"), 
   ("개발단계", MkDateRange "2024-04-01" "2024-12-31" "제품 개발"), 
   ("성장단계", MkDateRange "2025-01-01" "2026-12-31" "시장 확대")]
  "제품 출시 일정이 전체 사업의 핵심"

public export
exampleBusinessPlan : BusinessPlan
exampleBusinessPlan = MkBusinessPlan
  "수정사업계획서"
  "v3.0"
  exampleCompanyInfo
  (MkDateRange "2024-01-01" "2026-12-31" "3개년 사업기간")
  exampleBusinessContent
  exampleMarketAnalysis
  exampleFinancialPlan
  exampleOrganization
  exampleSchedule
  "본 계획서는 초기 계획 대비 시장 상황을 반영하여 수정됨"