module Domains.Outsourcing3

import Data.Fin
import Data.Vect
import Data.List
import Data.String
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
data Date : Type where
  MkDate : (month : Nat) -> (day : Nat) -> Date

public export
data ParticipationType : Type where
  ScaleDeepInitial : ParticipationType
  ScaleUpFollowUp : ParticipationType
  None : ParticipationType

public export
data ExpenseCategory : Type where
  GeneralService : ExpenseCategory
  GeneralSupplies : ExpenseCategory
  Rent : ExpenseCategory
  Materials : ExpenseCategory
  RentInKind : ExpenseCategory
  LaborInKind : ExpenseCategory

public export
data PersonnelStatus : Type where
  Completed : PersonnelStatus
  InProgress : PersonnelStatus
  Planned : PersonnelStatus

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data BudgetRatio : Type where
  MkBudgetRatio : (percentage : Nat)
    -> (validRange : LTE percentage 100)
    -> BudgetRatio

public export
mkBudgetRatio : (n : Nat) -> {auto prf : LTE n 100} -> BudgetRatio
mkBudgetRatio n {prf} = MkBudgetRatio n prf

public export
data GovernmentSupportRatio : Type where
  MkGovRatio : (percentage : Nat)
    -> (validMax : LTE percentage 70)
    -> GovernmentSupportRatio

public export
mkGovRatio : (n : Nat) -> {auto prf : LTE n 70} -> GovernmentSupportRatio
mkGovRatio n {prf} = MkGovRatio n prf

public export
data SelfFundingRatio : Type where
  MkSelfRatio : (percentage : Nat)
    -> (validMin : LTE 30 percentage)
    -> (validMax : LTE percentage 100)
    -> SelfFundingRatio

public export
mkSelfRatio : (n : Nat) -> {auto prf1 : LTE 30 n} -> {auto prf2 : LTE n 100} -> SelfFundingRatio
mkSelfRatio n {prf1} {prf2} = MkSelfRatio n prf1 prf2

public export
data CashRatio : Type where
  MkCashRatio : (percentage : Nat)
    -> (validMin : LTE 10 percentage)
    -> (validMax : LTE percentage 100)
    -> CashRatio

public export
mkCashRatio : (n : Nat) -> {auto prf1 : LTE 10 n} -> {auto prf2 : LTE n 100} -> CashRatio
mkCashRatio n {prf1} {prf2} = MkCashRatio n prf1 prf2

public export
data InKindRatio : Type where
  MkInKindRatio : (percentage : Nat)
    -> (validMax : LTE percentage 20)
    -> InKindRatio

public export
mkInKindRatio : (n : Nat) -> {auto prf : LTE n 20} -> InKindRatio
mkInKindRatio n {prf} = MkInKindRatio n prf

public export
data ExpenseItemAmount : Type where
  MkExpenseItemAmount : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> (tot : Nat) -> (pf : tot = gov + (cash + inKind)) -> ExpenseItemAmount

public export
mkExpenseItemAmount : (gov : Nat) -> (cash : Nat) -> (inKind : Nat) -> ExpenseItemAmount
mkExpenseItemAmount gov cash inKind =
  MkExpenseItemAmount gov cash inKind (gov + (cash + inKind)) Refl

public export
data TotalBudgetAmount : Type where
  MkTotalBudgetAmount : (tot : Nat) -> (gov : Nat) -> (self : Nat) -> (pf : tot = gov + self) -> TotalBudgetAmount

public export
mkTotalBudgetAmount : (total : Nat) -> (gov : Nat) -> (self : Nat) -> {auto prf : total = gov + self} -> TotalBudgetAmount
mkTotalBudgetAmount total gov self {prf} = MkTotalBudgetAmount total gov self prf

public export
data SelfFundingAmount : Type where
  MkSelfFundingAmount : (tot : Nat) -> (cash : Nat) -> (inKind : Nat) -> (pf : tot = cash + inKind) -> SelfFundingAmount

public export
mkSelfFundingAmount : (total : Nat) -> (cash : Nat) -> (inKind : Nat) -> {auto prf : total = cash + inKind} -> SelfFundingAmount
mkSelfFundingAmount total cash inKind {prf} = MkSelfFundingAmount total cash inKind prf

public export
data QuestionGoal : Type where
  MkQuestionGoal : (curr : Nat) -> (tgt : Nat) -> (add : Nat) -> (pf1 : add = tgt - curr) -> (pf2 : LTE 100000 tgt) -> QuestionGoal

public export
mkQuestionGoal : (curr : Nat) -> (tgt : Nat) -> {auto prf1 : LTE 100000 tgt} -> QuestionGoal
mkQuestionGoal curr tgt {prf1} = MkQuestionGoal curr tgt (tgt - curr) Refl prf1

public export
data ValidSchedule : Type where
  MkValidSchedule : (startMonth : Nat)
    -> (startDay : Nat)
    -> (endMonth : Nat)
    -> (endDay : Nat)
    -> (validOrder : Either (LT startMonth endMonth) 
                            (startMonth = endMonth, LT startDay endDay))
    -> ValidSchedule

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
  operatingBusinessName : String
  managerName : String

public export
record ParticipationTypeInfo where
  constructor MkParticipationTypeInfo
  scaleDeepInitial : Bool
  scaleUpFollowUp : Bool

public export
record CompanyIntroduction where
  constructor MkCompanyIntroduction
  differentiation : String
  competitiveness : String
  organizationDescription : String

public export
record Personnel where
  constructor MkPersonnel
  sequenceNumber : Nat
  position : String
  responsibility : String
  capabilities : String
  status : PersonnelStatus

public export
record Infrastructure where
  constructor MkInfrastructure
  name : String
  details : String
  quantity : Maybe Nat

public export
record BusinessItemInfo where
  constructor MkBusinessItemInfo
  itemIntroduction : String
  supportMotivation : String
  feasibilityAnalysis : String
  strategy : String
  futurePlan : String
  expectedEffect : String
  achievementGoal : String

public export
record BusinessOverview where
  constructor MkBusinessOverview
  basicInfo : CompanyBasicInfo
  participationType : ParticipationTypeInfo
  companyIntro : CompanyIntroduction
  personnelList : List Personnel
  infrastructureList : List Infrastructure
  majorAchievements : List String
  businessItem : BusinessItemInfo

public export
record Schedule where
  constructor MkSchedule
  sequenceNumber : Nat
  content : String
  startDate : Date
  endDate : Date
  details : String

public export
record ExpenseItem where
  constructor MkExpenseItem
  majorCategory : String
  subCategory : String
  details : String
  amount : ExpenseItemAmount

public export
record TotalBudget where
  constructor MkTotalBudget
  totalAmount : Nat
  govSupportAmount : Nat
  govSupportRatio : Nat
  selfFundingTotal : Nat
  selfFundingRatio : Nat
  selfFundingCash : Nat
  selfFundingCashRatio : Nat
  selfFundingInKind : Nat
  selfFundingInKindRatio : Nat
  ratioSumProof : govSupportRatio + selfFundingRatio = 100
  amountSumProof : totalAmount = plus govSupportAmount selfFundingTotal
  selfFundingSumProof : selfFundingTotal = plus selfFundingCash selfFundingInKind
  govRatioConstraint : LTE govSupportRatio 70
  selfRatioConstraint : LTE 30 selfFundingRatio
  cashRatioConstraint : LTE 10 selfFundingCashRatio
  inKindRatioConstraint : LTE selfFundingInKindRatio 20

public export
record BudgetComposition where
  constructor MkBudgetComposition
  totalBudgetInfo : TotalBudget
  expenseItems : List ExpenseItem

public export
record DetailedBusinessPlan where
  constructor MkDetailedBusinessPlan
  businessItemName : String
  productServiceIntro : String
  productServiceDifferentiation : String
  achievementGoalDetailedPlan : String
  scheduleList : List Schedule
  businessStrategy : String
  detailedExpectedEffect : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlan where
  constructor MkBusinessPlan
  overview : BusinessOverview
  detailedPlan : DetailedBusinessPlan
  budget : BudgetComposition

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleCompanyBasicInfo : CompanyBasicInfo
exampleCompanyBasicInfo = MkCompanyBasicInfo
  "주식회사 스피라티"
  "이준호"
  "010-4018-2468"
  "서울특별시 강남구 언주로 122, 702호"
  0
  "교육 서비스업"
  "비제조"
  "어나더 브레인"
  "문영지"

public export
exampleParticipationType : ParticipationTypeInfo
exampleParticipationType = MkParticipationTypeInfo False False

public export
exampleCompanyIntro : CompanyIntroduction
exampleCompanyIntro = MkCompanyIntroduction
  "AI 기반 수학 교육 플랫폼"
  "60,000개 이상의 수학 문제 데이터베이스 보유"
  "대표 1명, 개발팀 구성"

public export
examplePersonnel1 : Personnel
examplePersonnel1 = MkPersonnel
  1
  "대표"
  "개발 총괄 및 S/W 협력사 관리"
  "서울대 경제학 학사, 서울대 수학과 석사 수료"
  Completed

public export
exampleInfrastructure1 : Infrastructure
exampleInfrastructure1 = MkInfrastructure
  "수학 문제 벡터 데이터 베이스"
  "AI 기반 문제 추천 시스템"
  (Just 60000)

public export
exampleBusinessItem : BusinessItemInfo
exampleBusinessItem = MkBusinessItemInfo
  "AI 기반 수학 학습 플랫폼 고도화"
  "교육 시장 확대 및 경쟁력 강화"
  "시장 성장 가능성 높음"
  "문제 데이터베이스 확장 및 AI 알고리즘 개선"
  "B2B 시장 진출 및 해외 진출"
  "매출 증대 및 시장 점유율 확대"
  "문항 수 100,000개 이상 확보"

public export
exampleOverview : BusinessOverview
exampleOverview = MkBusinessOverview
  exampleCompanyBasicInfo
  exampleParticipationType
  exampleCompanyIntro
  [examplePersonnel1]
  [exampleInfrastructure1]
  ["수학 문제 60,000개 보유", "AI 추천 시스템 개발"]
  exampleBusinessItem

public export
exampleSchedule1 : Schedule
exampleSchedule1 = MkSchedule
  1
  "수학 문제 입력"
  (MkDate 10 1)
  (MkDate 11 30)
  "4만문항 이상 보충"

public export
exampleExpenseItem1 : ExpenseItem
exampleExpenseItem1 = MkExpenseItem
  "일반용역비"
  "프로그램 고도화"
  "오류검수, 변형문항 및 생성, 매드튜터"
  (mkExpenseItemAmount 20000000 0 0)

public export
exampleExpenseItem2 : ExpenseItem
exampleExpenseItem2 = MkExpenseItem
  "일반용역비"
  "문제 입력"
  "4만문항 이상 입력"
  (mkExpenseItemAmount 40000000 0 0)

public export
exampleExpenseItem3 : ExpenseItem
exampleExpenseItem3 = MkExpenseItem
  "일반용역비"
  "마케팅 외주"
  "홍보 및 마케팅 활동"
  (mkExpenseItemAmount 10000000 0 0)

public export
exampleExpenseItem4 : ExpenseItem
exampleExpenseItem4 = MkExpenseItem
  "일반수용비"
  "수수료 및 사용료"
  "클라우드 서버 사용료"
  (mkExpenseItemAmount 5000000 0 0)

public export
exampleExpenseItem5 : ExpenseItem
exampleExpenseItem5 = MkExpenseItem
  "일반수용비"
  "홍보비"
  "온라인 광고"
  (mkExpenseItemAmount 3000000 0 0)

public export
exampleExpenseItem6 : ExpenseItem
exampleExpenseItem6 = MkExpenseItem
  "일반수용비"
  "전문가 활용비"
  "컨설팅 비용"
  (mkExpenseItemAmount 2000000 0 0)

public export
exampleExpenseItem7 : ExpenseItem
exampleExpenseItem7 = MkExpenseItem
  "일반수용비"
  "해외진출비"
  "해외 마케팅"
  (mkExpenseItemAmount 3000000 0 0)

public export
exampleExpenseItem8 : ExpenseItem
exampleExpenseItem8 = MkExpenseItem
  "임차료"
  "임차비"
  "사무실 임차료"
  (mkExpenseItemAmount 2000000 12150000 0)

public export
exampleExpenseItem9 : ExpenseItem
exampleExpenseItem9 = MkExpenseItem
  "재료비"
  "개발용 컴퓨터 구입"
  "개발 장비"
  (mkExpenseItemAmount 0 0 0)

public export
exampleExpenseItem10 : ExpenseItem
exampleExpenseItem10 = MkExpenseItem
  "임차료(현물)"
  "임차비"
  "사무실 임차료 현물"
  (mkExpenseItemAmount 0 0 12150000)

public export
exampleExpenseItem11 : ExpenseItem
exampleExpenseItem11 = MkExpenseItem
  "인건비(현물)"
  "대표자 인건비"
  "대표 인건비"
  (mkExpenseItemAmount 0 0 12130000)

public export
exampleTotalBudget : TotalBudget
exampleTotalBudget = MkTotalBudget
  121430000
  85000000
  70
  36430000
  30
  12150000
  10
  24280000
  20
  Refl
  Refl
  Refl
  (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc LTEZero))))))))))))))))))))))))))))))
  (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc LTEZero))))))))))))))))))))))))))))))
  (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc (LTESucc LTEZero))))))))))
  LTERefl

public export
exampleBudget : BudgetComposition
exampleBudget = MkBudgetComposition
  exampleTotalBudget
  [ exampleExpenseItem1
  , exampleExpenseItem2
  , exampleExpenseItem3
  , exampleExpenseItem4
  , exampleExpenseItem5
  , exampleExpenseItem6
  , exampleExpenseItem7
  , exampleExpenseItem8
  , exampleExpenseItem9
  , exampleExpenseItem10
  , exampleExpenseItem11
  ]

public export
exampleDetailedPlan : DetailedBusinessPlan
exampleDetailedPlan = MkDetailedBusinessPlan
  "AI 기반 수학 학습 플랫폼"
  "개인 맞춤형 수학 문제 추천 서비스"
  "대규모 문제 데이터베이스와 AI 알고리즘"
  "문항 수 100,000개 이상 확보 및 AI 고도화"
  [exampleSchedule1]
  "데이터베이스 확장 및 AI 알고리즘 개선"
  "매출 증대 및 시장 점유율 확대"

public export
exampleBusinessPlan : BusinessPlan
exampleBusinessPlan = MkBusinessPlan
  exampleOverview
  exampleDetailedPlan
  exampleBudget