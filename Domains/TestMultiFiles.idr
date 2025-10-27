module Domains.TestMultiFiles

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
data ItemCost : Type where
  MkItemCost : (unitPrice : Nat) ->
               (quantity : Nat) ->
               (totalCost : Nat) ->
               (0 validCost : totalCost = unitPrice * quantity) ->
               ItemCost

public export
mkItemCost : (unitPrice : Nat) -> (quantity : Nat) -> ItemCost
mkItemCost u q = MkItemCost u q (u * q) Refl

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
record ProjectInfo where
  constructor MkProjectInfo
  projectName : String
  projectCode : String
  projectPeriod : (String, String)
  projectObjective : String

public export
record BudgetItem where
  constructor MkBudgetItem
  category : String
  itemName : String
  specification : String
  cost : ItemCost
  remarks : String

public export
record Deliverable where
  constructor MkDeliverable
  deliverableName : String
  deliverableType : String
  dueDate : String
  description : String

public export
record OutsourcingRequest where
  constructor MkOutsourcingRequest
  requestDate : String
  requestor : String
  department : String
  taskDescription : String
  taskPeriod : (String, String)
  estimatedAmount : BudgetAmount
  justification : String
  approvalStatus : String

public export
record AgreementTerm where
  constructor MkAgreementTerm
  termNumber : String
  termTitle : String
  termContent : String
  subTerms : List String

public export
record ParticipationRequirement where
  constructor MkParticipationRequirement
  requirementType : String
  requirementDescription : String
  mandatoryFlag : Bool

public export
record SupportDetail where
  constructor MkSupportDetail
  supportCategory : String
  supportAmount : Nat
  supportCondition : String
  supportPeriod : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record BusinessPlan where
  constructor MkBusinessPlan
  planVersion : String
  submissionDate : String
  contractor : Party
  client : Party
  projectInfo : ProjectInfo
  budgetItems : List BudgetItem
  totalBudget : BudgetAmount
  deliverables : List Deliverable
  milestones : List (String, String)
  riskManagement : List String

public export
record OutsourcingApprovalForm where
  constructor MkOutsourcingApprovalForm
  formNumber : String
  submissionDate : String
  applicant : Party
  approver : String
  outsourcingRequest : OutsourcingRequest
  vendorInfo : Party
  contractAmount : BudgetAmount
  attachments : List String

public export
record AgreementBriefing where
  constructor MkAgreementBriefing
  briefingTitle : String
  briefingDate : String
  programName : String
  programCode : String
  organizingBody : Party
  agreementTerms : List AgreementTerm
  participationRequirements : List ParticipationRequirement
  supportDetails : List SupportDetail
  applicationProcedure : List String
  contactInfo : (String, String)

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleParty : Party
exampleParty = MkParty
  "주식회사 스피라티"
  "홍길동"
  "123-45-67890"
  "서울특별시 강남구"
  "02-1234-5678"

public export
exampleClient : Party
exampleClient = MkParty
  "한국산업기술진흥원"
  "김철수"
  "987-65-43210"
  "서울특별시 서초구"
  "02-9876-5432"

public export
exampleProjectInfo : ProjectInfo
exampleProjectInfo = MkProjectInfo
  "LIPS II 기술개발 프로젝트"
  "LIPS-2024-001"
  ("2024-01-01", "2024-12-31")
  "혁신 기술 개발 및 상용화"

public export
exampleBudgetItem : BudgetItem
exampleBudgetItem = MkBudgetItem
  "인건비"
  "선임연구원"
  "12개월"
  (mkItemCost 5000000 12)
  "프로젝트 전체 기간"

public export
exampleDeliverable : Deliverable
exampleDeliverable = MkDeliverable
  "최종 결과보고서"
  "문서"
  "2024-12-31"
  "프로젝트 전체 결과 종합 보고서"

public export
exampleOutsourcingRequest : OutsourcingRequest
exampleOutsourcingRequest = MkOutsourcingRequest
  "2024-03-15"
  "이영희"
  "기술개발팀"
  "소프트웨어 개발 외주"
  ("2024-04-01", "2024-09-30")
  (mkBudgetAmount 30000000 3000000)
  "내부 인력 부족으로 외부 전문가 필요"
  "승인대기"

public export
exampleAgreementTerm : AgreementTerm
exampleAgreementTerm = MkAgreementTerm
  "제1조"
  "목적"
  "본 협약은 LIPS II 프로그램의 효율적 운영을 목적으로 한다"
  ["세부 목적 1", "세부 목적 2"]

public export
exampleParticipationRequirement : ParticipationRequirement
exampleParticipationRequirement = MkParticipationRequirement
  "기술요건"
  "3년 이상 관련 기술 개발 경험"
  True

public export
exampleSupportDetail : SupportDetail
exampleSupportDetail = MkSupportDetail
  "연구개발비"
  100000000
  "정부 50%, 민간 50% 매칭"
  "12개월"

public export
exampleBusinessPlan : BusinessPlan
exampleBusinessPlan = MkBusinessPlan
  "v2.0"
  "2024-03-01"
  exampleParty
  exampleClient
  exampleProjectInfo
  [exampleBudgetItem]
  (mkBudgetAmount 60000000 6000000)
  [exampleDeliverable]
  [("중간보고", "2024-06-30"), ("최종보고", "2024-12-31")]
  ["기술 리스크 관리", "일정 리스크 관리"]

public export
exampleOutsourcingApprovalForm : OutsourcingApprovalForm
exampleOutsourcingApprovalForm = MkOutsourcingApprovalForm
  "OA-2024-001"
  "2024-03-15"
  exampleParty
  "박승인"
  exampleOutsourcingRequest
  exampleClient
  (mkBudgetAmount 30000000 3000000)
  ["견적서.pdf", "사업자등록증.pdf"]

public export
exampleAgreementBriefing : AgreementBriefing
exampleAgreementBriefing = MkAgreementBriefing
  "LIPS II 협약 설명회"
  "2024-02-20"
  "LIPS II 프로그램"
  "LIPS-II-2024"
  exampleClient
  [exampleAgreementTerm]
  [exampleParticipationRequirement]
  [exampleSupportDetail]
  ["온라인 신청", "서류 제출", "심사", "협약 체결"]
  ("담당자: 김지원", "연락처: 02-1111-2222")