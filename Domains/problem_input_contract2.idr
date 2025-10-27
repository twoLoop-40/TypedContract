module Domains.ProblemInputContract2

------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat
  desc : String

public export
record BusinessPeriod where
  constructor MkBusinessPeriod
  startDate : String
  endDate : String
  desc : String

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

-- 총사업비 = 자기자본 + 차입금
public export
data TotalBudget : Type where
  MkTotalBudget : (equity : Nat)
    -> (loan : Nat)
    -> (total : Nat)
    -> (validTotal : total = equity + loan)
    -> TotalBudget

public export
mkTotalBudget : (equity : Nat) -> (loan : Nat) -> TotalBudget
mkTotalBudget e l = MkTotalBudget e l (e + l) Refl

public export
getEquity : TotalBudget -> Nat
getEquity (MkTotalBudget equity _ _ _) = equity

public export
getLoan : TotalBudget -> Nat
getLoan (MkTotalBudget _ loan _ _) = loan

public export
getTotal : TotalBudget -> Nat
getTotal (MkTotalBudget _ _ total _) = total

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
  businessDescription : String
  mainProducts : List String
  targetMarket : String

public export
record MarketAnalysis where
  constructor MkMarketAnalysis
  marketSize : String
  competitors : List String
  competitiveAdvantage : String
  marketTrend : String

public export
record FinancialPlan where
  constructor MkFinancialPlan
  budget : TotalBudget
  revenueProjection : List (String, Nat)
  costProjection : List (String, Nat)
  profitProjection : String

public export
record OrganizationStructure where
  constructor MkOrganizationStructure
  departments : List String
  keyPersonnel : List (String, String)
  totalEmployees : Nat

public export
record Schedule where
  constructor MkSchedule
  milestones : List (String, String)
  phases : List String
  completionDate : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlanDocument where
  constructor MkBusinessPlanDocument
  documentTitle : String
  company : CompanyInfo
  businessPeriod : BusinessPeriod
  businessContent : BusinessContent
  marketAnalysis : MarketAnalysis
  financialPlan : FinancialPlan
  organization : OrganizationStructure
  schedule : Schedule
  submissionDate : String
  approvalStatus : String

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
exampleBusinessPeriod : BusinessPeriod
exampleBusinessPeriod = MkBusinessPeriod
  "2024-01-01"
  "2026-12-31"
  "3개년 사업기간"

public export
exampleBusinessContent : BusinessContent
exampleBusinessContent = MkBusinessContent
  "기술 서비스업"
  "혁신적인 기술 솔루션 제공"
  ["제품A", "제품B", "서비스C"]
  "국내 중소기업 및 대기업"

public export
exampleMarketAnalysis : MarketAnalysis
exampleMarketAnalysis = MkMarketAnalysis
  "약 5000억원 규모"
  ["경쟁사A", "경쟁사B", "경쟁사C"]
  "차별화된 기술력과 고객 서비스"
  "연평균 15% 성장 예상"

public export
exampleTotalBudget : TotalBudget
exampleTotalBudget = mkTotalBudget 300000000 200000000

public export
exampleFinancialPlan : FinancialPlan
exampleFinancialPlan = MkFinancialPlan
  exampleTotalBudget
  [("2024년", 200000000), ("2025년", 350000000), ("2026년", 500000000)]
  [("인건비", 150000000), ("운영비", 100000000), ("마케팅비", 50000000)]
  "3년차 흑자 전환 예상"

public export
exampleOrganization : OrganizationStructure
exampleOrganization = MkOrganizationStructure
  ["경영지원팀", "개발팀", "영업팀", "마케팅팀"]
  [("대표이사", "홍길동"), ("개발이사", "김철수"), ("영업이사", "이영희")]
  25

public export
exampleSchedule : Schedule
exampleSchedule = MkSchedule
  [("사업 착수", "2024-01-01"), ("중간 점검", "2025-06-30"), ("사업 완료", "2026-12-31")]
  ["준비단계", "실행단계", "완료단계"]
  "2026-12-31"

public export
exampleBusinessPlanDocument : BusinessPlanDocument
exampleBusinessPlanDocument = MkBusinessPlanDocument
  "수정사업계획서"
  exampleCompanyInfo
  exampleBusinessPeriod
  exampleBusinessContent
  exampleMarketAnalysis
  exampleFinancialPlan
  exampleOrganization
  exampleSchedule
  "2024-01-15"
  "검토중"