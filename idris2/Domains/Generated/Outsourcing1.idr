module Domains.Outsourcing1

import Data.String
import Data.List
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
record DateMMDD where
  constructor MkDateMMDD
  month : Nat
  day : Nat

public export
record Percentage where
  constructor MkPercentage
  value : Nat  -- 0 to 100

public export
data ParticipationType = ScaleDeepInitial | ScaleUpFollowup

public export
Eq ParticipationType where
  ScaleDeepInitial == ScaleDeepInitial = True
  ScaleUpFollowup == ScaleUpFollowup = True
  _ == _ = False

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

-- 정부지원금 비율 (≤70%)
public export
data GovernmentGrantRatio : Type where
  MkGrantRatio : (ratio : Nat) 
    -> {auto pf : LTE ratio 70}
    -> GovernmentGrantRatio

public export
getGrantRatio : GovernmentGrantRatio -> Nat
getGrantRatio (MkGrantRatio r) = r

-- 자기부담금 비율 (≥30%)
public export
data SelfContributionRatio : Type where
  MkSelfRatio : (ratio : Nat)
    -> {auto pf : LTE 30 ratio}
    -> SelfContributionRatio

public export
getSelfRatio : SelfContributionRatio -> Nat
getSelfRatio (MkSelfRatio r) = r

-- 현금 비율 (≥10%)
public export
data CashRatio : Type where
  MkCashRatio : (ratio : Nat)
    -> {auto pf : LTE 10 ratio}
    -> CashRatio

public export
getCashRatio : CashRatio -> Nat
getCashRatio (MkCashRatio r) = r

-- 현물 비율 (≤20%)
public export
data InKindRatio : Type where
  MkInKindRatio : (ratio : Nat)
    -> {auto pf : LTE ratio 20}
    -> InKindRatio

public export
getInKindRatio : InKindRatio -> Nat
getInKindRatio (MkInKindRatio r) = r

-- 비율 합계 100% 증명
public export
data RatioSum100 : Type where
  MkRatioSum : (grantRatio : Nat)
    -> (selfRatio : Nat)
    -> (pf : plus grantRatio selfRatio = 100)
    -> RatioSum100

-- 금액 구성 증명
public export
data BudgetComposition : Type where
  MkBudgetComp : (total : Nat)
    -> (grant : Nat)
    -> (selfTotal : Nat)
    -> (cash : Nat)
    -> (inKind : Nat)
    -> (pfTotal : total = plus grant selfTotal)
    -> (pfSelf : selfTotal = plus cash inKind)
    -> BudgetComposition

-- 집행항목 합계 증명
public export
data ExpenseItemTotal : Type where
  MkExpenseTotal : (grant : Nat)
    -> (cash : Nat)
    -> (inKind : Nat)
    -> (total : Nat)
    -> (pf : total = plus grant (plus cash inKind))
    -> ExpenseItemTotal

public export
mkExpenseTotal : (g : Nat) -> (c : Nat) -> (i : Nat) -> ExpenseItemTotal
mkExpenseTotal g c i = MkExpenseTotal g c i (plus g (plus c i)) Refl

-- 날짜 순서 증명 (간단한 버전)
public export
data DateOrder : Type where
  MkDateOrder : (startMonth : Nat)
    -> (startDay : Nat)
    -> (endMonth : Nat)
    -> (endDay : Nat)
    -> (pf : Either (LT startMonth endMonth) 
                    (startMonth = endMonth, LTE startDay endDay))
    -> DateOrder

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record CompanyBasicInfo where
  constructor MkCompanyBasicInfo
  companyName : String
  representative : String
  contact : String
  address : String
  regularEmployees : Nat
  mainIndustry : String
  sector : String

public export
record OperatorInfo where
  constructor MkOperatorInfo
  operatorName : String
  managerName : String

public export
record Personnel where
  constructor MkPersonnel
  seqNo : Nat
  position : String
  responsibility : String
  capability : String
  status : String

public export
record Infrastructure where
  constructor MkInfrastructure
  name : String
  details : String
  itemCount : Maybe Nat

public export
record Schedule where
  constructor MkSchedule
  seqNo : Nat
  content : String
  startDate : DateMMDD
  endDate : DateMMDD
  details : String
  targetCount : Maybe Nat

public export
record ExpenseItem where
  constructor MkExpenseItem
  category : String
  subCategory : String
  details : String
  governmentGrant : Nat
  cashContribution : Nat
  inKindContribution : Nat
  itemTotal : ExpenseItemTotal

public export
record GrantInfo where
  constructor MkGrantInfo
  amount : Nat
  ratio : GovernmentGrantRatio

public export
record CashInfo where
  constructor MkCashInfo
  amount : Nat
  ratio : CashRatio

public export
record InKindInfo where
  constructor MkInKindInfo
  amount : Nat
  ratio : InKindRatio

public export
record ContributionInfo where
  constructor MkContributionInfo
  totalAmount : Nat
  ratio : SelfContributionRatio
  cash : CashInfo
  inKind : InKindInfo

public export
record BudgetInfo where
  constructor MkBudgetInfo
  totalBudget : Nat
  grant : GrantInfo
  contribution : ContributionInfo
  composition : BudgetComposition
  expenseItems : List ExpenseItem

public export
record Period where
  constructor MkPeriod
  startDate : DateMMDD
  endDate : DateMMDD

public export
record GoalInfo where
  constructor MkGoalInfo
  contractPeriod : Period
  objectives : List String
  schedules : List Schedule

public export
record BusinessItemInfo where
  constructor MkBusinessItemInfo
  itemIntroduction : String
  supportMotivation : String
  feasibilityAnalysis : String
  strategy : String
  futurePlan : String
  expectedEffect : String
  goals : GoalInfo

public export
record CompanyDetails where
  constructor MkCompanyDetails
  differentiation : String
  personnel : List Personnel
  infrastructure : List Infrastructure
  achievements : List String

public export
record DetailedPlan where
  constructor MkDetailedPlan
  itemName : String
  productServiceIntro : String
  productServiceDiff : String
  goalDetailedPlan : String
  executionStrategy : String
  expectedEffect : String

public export
record Overview where
  constructor MkOverview
  participationType : ParticipationType
  companyInfo : CompanyBasicInfo
  operatorInfo : OperatorInfo

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlan where
  constructor MkBusinessPlan
  overview : Overview
  companyDetails : CompanyDetails
  businessItem : BusinessItemInfo
  detailedPlan : DetailedPlan
  budget : BudgetInfo

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleCompanyInfo : CompanyBasicInfo
exampleCompanyInfo = MkCompanyBasicInfo
  "주식회사 스피라티"
  "이준호"
  "010-4018-2468"
  "서울특별시 강남구 언주로 122, 702호"
  0
  "교육 서비스업"
  "비제조"

public export
exampleOperatorInfo : OperatorInfo
exampleOperatorInfo = MkOperatorInfo
  "어나더 브레인"
  "문영지"

public export
examplePersonnel1 : Personnel
examplePersonnel1 = MkPersonnel
  1
  "대표"
  "개발 총괄 및 S/W 협력사 관리"
  "서울대 경제학 학사, 서울대 수학과 석사 수료"
  "완료"

public export
exampleInfra1 : Infrastructure
exampleInfra1 = MkInfrastructure
  "수학 문제 벡터 데이터 베이스"
  "초중고 수학 문제 60,000문항 보유"
  (Just 60000)

public export
exampleSchedule1 : Schedule
exampleSchedule1 = MkSchedule
  1
  "수학 문제 입력"
  (MkDateMMDD 10 1)
  (MkDateMMDD 11 30)
  "4만문항 이상 보충"
  (Just 40000)

public export
exampleSchedule2 : Schedule
exampleSchedule2 = MkSchedule
  2
  "자동 오류 검수 시스템 개발"
  (MkDateMMDD 10 1)
  (MkDateMMDD 12 30)
  "문제 오류 자동 검수"
  Nothing

public export
exampleSchedule3 : Schedule
exampleSchedule3 = MkSchedule
  3
  "자동 문제 변형 시스템 개발"
  (MkDateMMDD 12 1)
  (MkDateMMDD 2 28)
  "변형 문항 자동 생성"
  Nothing

public export
exampleSchedule4 : Schedule
exampleSchedule4 = MkSchedule
  4
  "AI 튜터 시스템 개발"
  (MkDateMMDD 1 1)
  (MkDateMMDD 3 31)
  "매드튜터 시스템 개발"
  Nothing

public export
exampleExpense1 : ExpenseItem
exampleExpense1 = MkExpenseItem
  "일반용역비"
  "프로그램 고도화"
  "오류검수, 변형문항 및 생성, 매드튜터"
  20000000
  0
  0
  (mkExpenseTotal 20000000 0 0)

public export
exampleExpense2 : ExpenseItem
exampleExpense2 = MkExpenseItem
  "일반용역비"
  "문제 입력"
  "수학 문제 4만 문항 이상 입력"
  40000000
  10650000
  0
  (mkExpenseTotal 40000000 10650000 0)

public export
exampleExpense3 : ExpenseItem
exampleExpense3 = MkExpenseItem
  "일반용역비"
  "마케팅 외주"
  "온라인 마케팅 대행"
  7500000
  0
  0
  (mkExpenseTotal 7500000 0 0)

public export
exampleExpense4 : ExpenseItem
exampleExpense4 = MkExpenseItem
  "재료비"
  "개발용 컴퓨터 구입"
  "고성능 개발 장비"
  12500000
  1500000
  0
  (mkExpenseTotal 12500000 1500000 0)

public export
exampleExpense5 : ExpenseItem
exampleExpense5 = MkExpenseItem
  "인건비(현물)"
  "대표자 인건비"
  "대표자 급여"
  0
  0
  24280000
  (mkExpenseTotal 0 0 24280000)

public export
exampleGrantInfo : GrantInfo
exampleGrantInfo = MkGrantInfo
  85000000
  (MkGrantRatio 70)

public export
exampleCashInfo : CashInfo
exampleCashInfo = MkCashInfo
  12150000
  (MkCashRatio 10)

public export
exampleInKindInfo : InKindInfo
exampleInKindInfo = MkInKindInfo
  24280000
  (MkInKindRatio 20)

public export
exampleContributionInfo : ContributionInfo
exampleContributionInfo = MkContributionInfo
  36430000
  (MkSelfRatio 30)
  exampleCashInfo
  exampleInKindInfo

public export
exampleBudgetComposition : BudgetComposition
exampleBudgetComposition = MkBudgetComp
  121430000
  85000000
  36430000
  12150000
  24280000
  Refl
  Refl

public export
exampleBudgetInfo : BudgetInfo
exampleBudgetInfo = MkBudgetInfo
  121430000
  exampleGrantInfo
  exampleContributionInfo
  exampleBudgetComposition
  [ exampleExpense1
  , exampleExpense2
  , exampleExpense3
  , exampleExpense4
  , exampleExpense5
  ]

public export
examplePeriod : Period
examplePeriod = MkPeriod
  (MkDateMMDD 10 1)
  (MkDateMMDD 3 31)

public export
exampleGoalInfo : GoalInfo
exampleGoalInfo = MkGoalInfo
  examplePeriod
  [ "수학 문제 4만 문항 이상 추가 입력"
  , "자동 오류 검수 시스템 개발"
  , "자동 문제 변형 시스템 개발"
  , "AI 튜터 시스템 개발"
  ]
  [ exampleSchedule1
  , exampleSchedule2
  , exampleSchedule3
  , exampleSchedule4
  ]

public export
exampleBusinessItemInfo : BusinessItemInfo
exampleBusinessItemInfo = MkBusinessItemInfo
  "AI 기반 수학 학습 플랫폼"
  "교육 서비스 고도화를 통한 경쟁력 강화"
  "수학 교육 시장의 성장성과 AI 기술 접목 가능성"
  "단계별 시스템 개발 및 문항 확보"
  "서비스 확장 및 시장 점유율 확대"
  "교육 품질 향상 및 매출 증대"
  exampleGoalInfo

public export
exampleCompanyDetails : CompanyDetails
exampleCompanyDetails = MkCompanyDetails
  "AI 기반 맞춤형 수학 교육 솔루션"
  [examplePersonnel1]
  [exampleInfra1]
  ["수학 문제 데이터베이스 60,000문항 구축"]

public export
exampleDetailedPlan : DetailedPlan
exampleDetailedPlan = MkDetailedPlan
  "AI 수학 학습 플랫폼"
  "자동 오류 검수, 문제 변형, AI 튜터 기능 제공"
  "대규모 문항 DB와 AI 기술 결합"
  "4단계 개발 일정에 따른 순차적 구현"
  "외주 개발 및 내부 역량 활용"
  "교육 서비스 품질 향상 및 시장 경쟁력 강화"

public export
exampleOverview : Overview
exampleOverview = MkOverview
  ScaleUpFollowup
  exampleCompanyInfo
  exampleOperatorInfo

public export
exampleBusinessPlan : BusinessPlan
exampleBusinessPlan = MkBusinessPlan
  exampleOverview
  exampleCompanyDetails
  exampleBusinessItemInfo
  exampleDetailedPlan
  exampleBudgetInfo