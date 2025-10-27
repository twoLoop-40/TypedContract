module Domains.Outsourcing1

import Data.Nat
import Decidable.Equality

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
    -> (validSum : totalBudget = plus equity debt)
    -> CapitalStructure

public export
mkCapitalStructure : (equity : Nat) -> (debt : Nat) -> CapitalStructure
mkCapitalStructure e d = MkCapitalStructure (plus e d) e d Refl

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

public export
record MarketAnalysis where
  constructor MkMarketAnalysis
  marketSize : String
  competitors : List String
  competitiveAdvantage : String
  targetCustomers : String

public export
record FinancialPlan where
  constructor MkFinancialPlan
  capitalStructure : CapitalStructure
  revenueProjection : List (String, Nat)
  costProjection : List (String, Nat)
  profitProjection : List (String, Nat)
  fundingSource : String

public export
record OrganizationStructure where
  constructor MkOrganizationStructure
  departments : List String
  keyPersonnel : List (String, String)
  totalEmployees : Nat
  organizationChart : String

public export
record Schedule where
  constructor MkSchedule
  milestones : List (String, DateRange)
  phases : List String
  criticalPath : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlan where
  constructor MkBusinessPlan
  planId : String
  version : String
  submissionDate : String
  company : CompanyInfo
  projectPeriod : DateRange
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
exampleBusinessNumber : BusinessNumber
exampleBusinessNumber = MkBusinessNumber
  "123-45-67890"
  "사업자등록번호"

public export
exampleCompanyInfo : CompanyInfo
exampleCompanyInfo = MkCompanyInfo
  "주식회사 스피라티"
  exampleBusinessNumber
  "홍길동"
  "서울특별시 강남구"
  "02-1234-5678"

public export
exampleCapitalStructure : CapitalStructure
exampleCapitalStructure = mkCapitalStructure 300000000 200000000

public export
exampleFinancialPlan : FinancialPlan
exampleFinancialPlan = MkFinancialPlan
  exampleCapitalStructure
  [("2024년 1분기", 50000000), ("2024년 2분기", 75000000)]
  [("인건비", 30000000), ("운영비", 20000000)]
  [("1분기 순이익", 10000000), ("2분기 순이익", 15000000)]
  "자기자본 및 은행 대출"

public export
exampleBusinessContent : BusinessContent
exampleBusinessContent = MkBusinessContent
  "소프트웨어 개발 및 컨설팅"
  ["AI 솔루션", "클라우드 서비스", "데이터 분석"]
  "국내 중소기업 및 스타트업"
  "B2B SaaS 모델"

public export
exampleMarketAnalysis : MarketAnalysis
exampleMarketAnalysis = MkMarketAnalysis
  "국내 시장 규모 약 5조원"
  ["경쟁사A", "경쟁사B", "경쟁사C"]
  "차별화된 AI 기술 및 고객 맞춤형 서비스"
  "매출 10억 이상 중소기업"

public export
exampleOrganization : OrganizationStructure
exampleOrganization = MkOrganizationStructure
  ["경영지원팀", "개발팀", "영업팀", "연구소"]
  [("대표이사", "홍길동"), ("CTO", "김철수"), ("CFO", "이영희")]
  25
  "대표이사 - 본부장 - 팀장 - 팀원"

public export
exampleProjectPeriod : DateRange
exampleProjectPeriod = MkDateRange
  "2024-01-01"
  "2024-12-31"
  "사업 수행 기간"

public export
exampleSchedule : Schedule
exampleSchedule = MkSchedule
  [ ("사업 착수", MkDateRange "2024-01-01" "2024-01-31" "착수 단계")
  , ("개발 완료", MkDateRange "2024-02-01" "2024-09-30" "개발 단계")
  , ("상용화", MkDateRange "2024-10-01" "2024-12-31" "상용화 단계")
  ]
  ["기획", "설계", "개발", "테스트", "배포"]
  "개발 완료가 전체 일정의 핵심"

public export
exampleBusinessPlan : BusinessPlan
exampleBusinessPlan = MkBusinessPlan
  "BP-2024-001"
  "수정 1차"
  "2024-01-15"
  exampleCompanyInfo
  exampleProjectPeriod
  exampleBusinessContent
  exampleMarketAnalysis
  exampleFinancialPlan
  exampleOrganization
  exampleSchedule
  "정부 지원 사업 신청용 수정 사업계획서"