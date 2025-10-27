module Domains.test_contract_final

import Data.String
import Decidable.Equality

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
data CapitalStructure : Type where
  MkCapitalStructure : (totalBudget : Nat)
    -> (equity : Nat)
    -> (debt : Nat)
    -> (validSum : totalBudget = equity + debt)
    -> CapitalStructure

public export
mkCapitalStructure : (equity : Nat) -> (debt : Nat) -> CapitalStructure
mkCapitalStructure e d = MkCapitalStructure (e + d) e d Refl

public export
getEquity : CapitalStructure -> Nat
getEquity (MkCapitalStructure _ e _ _) = e

public export
getDebt : CapitalStructure -> Nat
getDebt (MkCapitalStructure _ _ d _) = d

public export
getTotalBudget : CapitalStructure -> Nat
getTotalBudget (MkCapitalStructure t _ _ _) = t

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record CompanyInfo where
  constructor MkCompanyInfo
  companyName : String
  businessNumber : BusinessNumber
  representative : String
  address : String
  contact : String

public export
record BusinessContent where
  constructor MkBusinessContent
  businessType : String
  mainProducts : List String
  targetMarket : String
  businessModel : String
  description : String

public export
record MarketAnalysis where
  constructor MkMarketAnalysis
  marketSize : Money
  targetSegment : String
  competitors : List String
  competitiveAdvantage : String
  marketTrends : List String

public export
record FinancialPlan where
  constructor MkFinancialPlan
  capitalStructure : CapitalStructure
  revenueProjection : List Money
  costProjection : List Money
  profitProjection : List Money
  breakEvenPoint : String
  fundingSource : String

public export
record OrganizationStructure where
  constructor MkOrganizationStructure
  departments : List String
  keyPersonnel : List (String, String)
  totalEmployees : Nat
  organizationChart : String

public export
record SchedulePlan where
  constructor MkSchedulePlan
  milestones : List (String, DateRange)
  phases : List String
  criticalPath : List String
  riskFactors : List String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlanDocument where
  constructor MkBusinessPlanDocument
  documentTitle : String
  version : String
  submissionDate : String
  company : CompanyInfo
  businessPeriod : DateRange
  businessContent : BusinessContent
  marketAnalysis : MarketAnalysis
  financialPlan : FinancialPlan
  organization : OrganizationStructure
  schedule : SchedulePlan
  appendix : List String

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleBusinessNumber : BusinessNumber
exampleBusinessNumber = MkBusinessNumber
  "000-00-00000"
  "사업자등록번호"

public export
exampleCompanyInfo : CompanyInfo
exampleCompanyInfo = MkCompanyInfo
  "주식회사 스피라티"
  exampleBusinessNumber
  "홍길동"
  "서울특별시 강남구"
  "02-0000-0000"

public export
exampleDateRange : DateRange
exampleDateRange = MkDateRange
  "2024-01-01"
  "2026-12-31"
  "사업기간"

public export
exampleCapitalStructure : CapitalStructure
exampleCapitalStructure = mkCapitalStructure 300000000 200000000

public export
exampleBusinessContent : BusinessContent
exampleBusinessContent = MkBusinessContent
  "소프트웨어 개발 및 공급"
  ["AI 솔루션", "클라우드 서비스", "데이터 분석 플랫폼"]
  "국내 중소기업 및 스타트업"
  "B2B SaaS 모델"
  "혁신적인 AI 기반 비즈니스 솔루션 제공"

public export
exampleMarketAnalysis : MarketAnalysis
exampleMarketAnalysis = MkMarketAnalysis
  (MkMoney 5000000000000 "KRW" "국내 AI 시장 규모")
  "중소기업 디지털 전환 시장"
  ["경쟁사A", "경쟁사B", "경쟁사C"]
  "차별화된 AI 기술과 고객 맞춤형 서비스"
  ["AI 시장 급성장", "디지털 전환 가속화", "클라우드 전환 증가"]

public export
exampleFinancialPlan : FinancialPlan
exampleFinancialPlan = MkFinancialPlan
  exampleCapitalStructure
  [ MkMoney 100000000 "KRW" "1차년도 매출"
  , MkMoney 250000000 "KRW" "2차년도 매출"
  , MkMoney 500000000 "KRW" "3차년도 매출"
  ]
  [ MkMoney 80000000 "KRW" "1차년도 비용"
  , MkMoney 180000000 "KRW" "2차년도 비용"
  , MkMoney 350000000 "KRW" "3차년도 비용"
  ]
  [ MkMoney 20000000 "KRW" "1차년도 이익"
  , MkMoney 70000000 "KRW" "2차년도 이익"
  , MkMoney 150000000 "KRW" "3차년도 이익"
  ]
  "2차년도 3분기"
  "자기자본 및 정책자금"

public export
exampleOrganization : OrganizationStructure
exampleOrganization = MkOrganizationStructure
  ["경영지원팀", "개발팀", "영업팀", "마케팅팀"]
  [ ("대표이사", "홍길동")
  , ("CTO", "김철수")
  , ("개발팀장", "이영희")
  , ("영업팀장", "박민수")
  ]
  25
  "CEO 직속 4개 부서 체계"

public export
exampleSchedule : SchedulePlan
exampleSchedule = MkSchedulePlan
  [ ("사업 준비", MkDateRange "2024-01-01" "2024-03-31" "준비단계")
  , ("제품 개발", MkDateRange "2024-04-01" "2024-12-31" "개발단계")
  , ("시장 진입", MkDateRange "2025-01-01" "2025-06-30" "출시단계")
  , ("사업 확장", MkDateRange "2025-07-01" "2026-12-31" "확장단계")
  ]
  ["준비", "개발", "출시", "확장"]
  ["핵심 기술 개발", "초기 고객 확보", "시장 점유율 확대"]
  ["기술 개발 지연", "시장 진입 장벽", "자금 조달 리스크"]

public export
exampleBusinessPlanDocument : BusinessPlanDocument
exampleBusinessPlanDocument = MkBusinessPlanDocument
  "수정사업계획서"
  "v2.0"
  "2024-01-15"
  exampleCompanyInfo
  exampleDateRange
  exampleBusinessContent
  exampleMarketAnalysis
  exampleFinancialPlan
  exampleOrganization
  exampleSchedule
  ["재무제표", "시장조사 자료", "기술개발 계획서", "인허가 서류"]