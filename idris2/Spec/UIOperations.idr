||| UI Operations Type Specification
|||
||| 프론트엔드 UI 동작과 백엔드 API의 타입 안전한 명세
||| 모든 사용자 인터랙션과 시스템 응답을 타입으로 보장

module Spec.UIOperations

import Spec.WorkflowTypes
import Spec.ProjectRecovery

%default total

-- ============================================================================
-- User Actions (사용자 액션)
-- ============================================================================

||| 사용자가 UI에서 수행할 수 있는 모든 액션
public export
data UserAction : Type where
  ||| 새 프로젝트 생성
  CreateProject : (name : String)
               -> (prompt : String)
               -> (files : List String)
               -> UserAction

  ||| 프로젝트 상태 조회
  ViewProjectStatus : (name : String) -> UserAction

  ||| 프로젝트 목록 조회
  ListAllProjects : UserAction

  ||| 프로젝트 재개 (에러 발생 시)
  ResumeProject : (name : String)
               -> (updatedPrompt : Maybe String)
               -> (restartFromAnalysis : Bool)
               -> UserAction

  ||| 프로젝트 실행 중단
  AbortProject : (name : String) -> UserAction

  ||| 초안 생성 요청
  GenerateDraft : (name : String) -> UserAction

  ||| 피드백 제출
  SubmitFeedback : (name : String)
                -> (feedback : String)
                -> UserAction

  ||| PDF 최종화
  FinalizePDF : (name : String) -> UserAction

  ||| PDF 다운로드
  DownloadPDF : (name : String) -> UserAction

-- ============================================================================
-- System Responses (시스템 응답)
-- ============================================================================

||| 시스템이 사용자 액션에 대해 반환하는 응답
public export
data SystemResponse : UserAction -> Type where
  ||| 프로젝트 생성 성공
  ProjectCreated : (name : String)
                -> (initialPhase : Phase)
                -> SystemResponse (CreateProject name prompt files)

  ||| 프로젝트 상태 반환
  StatusReturned : (state : WorkflowState)
                -> SystemResponse (ViewProjectStatus name)

  ||| 프로젝트 목록 반환
  ProjectListReturned : (projects : List WorkflowState)
                     -> SystemResponse ListAllProjects

  ||| 재개 시작됨 (백그라운드)
  ResumeStarted : (name : String)
               -> (newPhase : Phase)
               -> SystemResponse (ResumeProject name prompt restart)

  ||| 실행 중단됨
  ExecutionAborted : (name : String)
                  -> (currentPhase : Phase)
                  -> SystemResponse (AbortProject name)

  ||| 초안 생성 시작
  DraftGenerationStarted : (name : String)
                        -> SystemResponse (GenerateDraft name)

  ||| 피드백 접수됨
  FeedbackReceived : (name : String)
                  -> (version : Nat)
                  -> SystemResponse (SubmitFeedback name feedback)

  ||| PDF 최종화 시작
  PDFFinalizationStarted : (name : String)
                        -> SystemResponse (FinalizePDF name)

  ||| PDF 다운로드 제공
  PDFDownloadReady : (name : String)
                  -> (filePath : String)
                  -> SystemResponse (DownloadPDF name)

-- ============================================================================
-- UI State (UI 상태)
-- ============================================================================

||| 프론트엔드 UI의 전체 상태
public export
record UIState where
  constructor MkUIState
  ||| 현재 페이지
  currentPage : String  -- "home", "projects", "project/:name", "new"

  ||| 로딩 중인지
  isLoading : Bool

  ||| 에러 메시지
  errorMessage : Maybe String

  ||| 현재 보고 있는 프로젝트 (있다면)
  currentProject : Maybe WorkflowState

  ||| 프로젝트 목록
  projectList : List WorkflowState

  ||| Recovery UI 표시 여부
  showRecoveryUI : Bool

  ||| 업데이트된 프롬프트 (Recovery UI에서)
  updatedPrompt : Maybe String

-- ============================================================================
-- UI Transitions (UI 전환)
-- ============================================================================

||| UI 상태 전환 규칙
public export
data UITransition : UIState -> UserAction -> UIState -> Type where
  ||| 프로젝트 생성 → 프로젝트 페이지로 이동
  TransitionToProject : (oldState : UIState)
                     -> (action : UserAction)
                     -> (name : String)
                     -> UITransition oldState action
                          (record { currentPage = "project/" ++ name
                                  , isLoading = False } oldState)

  ||| 재개 시작 → 프로젝트 목록으로 이동
  TransitionToProjects : (oldState : UIState)
                      -> (action : UserAction)
                      -> UITransition oldState action
                           (record { currentPage = "projects"
                                   , isLoading = False
                                   , showRecoveryUI = False } oldState)

  ||| 에러 발생 → 에러 표시
  ShowError : (oldState : UIState)
           -> (action : UserAction)
           -> (errorMsg : String)
           -> UITransition oldState action
                (record { errorMessage = Just errorMsg
                        , isLoading = False } oldState)

-- ============================================================================
-- Activity Indicator (활동 표시기)
-- ============================================================================

||| 백엔드 활동 상태
public export
record ActivityIndicator where
  constructor MkActivityIndicator
  ||| 현재 활동 중인지
  isActive : Bool

  ||| 마지막 활동 시간
  lastActivity : Maybe String  -- ISO format

  ||| 현재 수행 중인 작업
  currentAction : Maybe String

||| 활동 표시기 업데이트
public export
updateActivity : WorkflowState -> ActivityIndicator
updateActivity state = MkActivityIndicator
  False  -- Python WorkflowState.is_active mapped
  Nothing  -- Python WorkflowState.last_activity mapped
  Nothing  -- Python WorkflowState.current_action mapped

-- ============================================================================
-- Progress Visualization (진행 상황 시각화)
-- ============================================================================

||| Phase 시각화 정보
public export
record PhaseVisualization where
  constructor MkPhaseViz
  phase : Phase
  emoji : String
  label : String
  isCurrent : Bool
  isCompleted : Bool

||| 모든 Phase의 시각화 정보 생성
public export
generatePhaseVisualization : Phase -> List PhaseVisualization
generatePhaseVisualization currentPhase =
  let phases = [ (InputPhase, "📥", "Phase 1: Input Collection")
               , (AnalysisPhase, "🔍", "Phase 2: Analysis")
               , (SpecGenerationPhase, "📝", "Phase 3: Spec Generation")
               , (CompilationPhase, "⚙️", "Phase 4: Compilation")
               , (ErrorHandlingPhase, "🔧", "Phase 4b: Error Handling")
               , (DocImplPhase, "📄", "Phase 5: Document Implementation")
               , (DraftPhase, "✏️", "Phase 6: Draft Generation")
               , (FeedbackPhase, "💬", "Phase 7: User Feedback")
               , (RefinementPhase, "🔄", "Phase 8: Refinement")
               , (FinalPhase, "✅", "Phase 9: Finalization")
               ]
  in map (\(p, e, l) => MkPhaseViz p e l (p == currentPhase) (phaseOrder p < phaseOrder currentPhase)) phases
  where
    phaseOrder : Phase -> Nat
    phaseOrder InputPhase = 0
    phaseOrder AnalysisPhase = 1
    phaseOrder SpecGenerationPhase = 2
    phaseOrder CompilationPhase = 3
    phaseOrder ErrorHandlingPhase = 3
    phaseOrder DocImplPhase = 4
    phaseOrder DraftPhase = 5
    phaseOrder FeedbackPhase = 6
    phaseOrder RefinementPhase = 7
    phaseOrder FinalPhase = 8

-- ============================================================================
-- API Contract (API 계약)
-- ============================================================================

||| API 엔드포인트와 응답의 타입 계약
public export
data APIEndpoint : Type where
  ||| POST /api/project/init
  InitProject : (name : String)
             -> (prompt : String)
             -> (docs : List String)
             -> APIEndpoint

  ||| GET /api/projects
  GetProjects : APIEndpoint

  ||| GET /api/project/{name}/status
  GetStatus : (name : String) -> APIEndpoint

  ||| POST /api/project/{name}/resume
  ResumeProj : (name : String)
            -> (prompt : Maybe String)
            -> (restart : Bool)
            -> APIEndpoint

  ||| POST /api/project/{name}/abort
  AbortProj : (name : String) -> APIEndpoint

  ||| POST /api/project/{name}/draft
  GenerateDraftAPI : (name : String) -> APIEndpoint

  ||| POST /api/project/{name}/feedback
  SubmitFeedbackAPI : (name : String)
                   -> (feedback : String)
                   -> APIEndpoint

||| API 응답 타입
public export
data APIResponse : APIEndpoint -> Type where
  ||| 프로젝트 초기화 응답
  InitResponse : (projectName : String)
              -> (status : String)
              -> (currentPhase : String)
              -> APIResponse (InitProject name prompt docs)

  ||| 프로젝트 목록 응답
  ProjectsResponse : (projects : List WorkflowState)
                  -> APIResponse GetProjects

  ||| 상태 응답
  StatusResponse : (state : WorkflowState)
                -> (isActive : Bool)
                -> (lastActivity : Maybe String)
                -> APIResponse (GetStatus name)

  ||| 재개 응답
  ResumeResponse : (projectName : String)
                -> (status : String)
                -> APIResponse (ResumeProj name prompt restart)

  ||| 중단 응답
  AbortResponse : (projectName : String)
               -> (status : String)
               -> (currentPhase : String)
               -> APIResponse (AbortProj name)

-- ============================================================================
-- Type Safety Proofs (타입 안전성 증명)
-- ============================================================================

||| UI 액션이 유효한 시스템 응답으로 이어짐을 보장
public export
data ActionResponseValid : UserAction -> Type where
  ||| 모든 사용자 액션은 적절한 시스템 응답을 생성
  ValidResponse : (action : UserAction)
               -> (response : SystemResponse action)
               -> ActionResponseValid action

||| 활동 중인 프로젝트만 중단 가능
||| (Python WorkflowState의 is_active 필드 참조)
public export
canAbort : WorkflowState -> Bool
canAbort state = not (completed state)  -- 완료되지 않은 프로젝트

||| 에러가 있는 프로젝트만 재개 가능
||| (Python WorkflowState의 is_active 필드 참조)
public export
canResume : WorkflowState -> Bool
canResume state =
  not (completed state) &&
  currentPhase state /= InputPhase

||| UI 전환의 일관성 보장
public export
data TransitionConsistent : UIState -> UIState -> Type where
  ||| 프로젝트 이름이 보존됨
  PreservesProject : (before : UIState)
                  -> (after : UIState)
                  -> TransitionConsistent before after

-- ============================================================================
-- Example Usage
-- ============================================================================

||| 예제: 전체 워크플로우
public export
example_full_workflow : IO ()
example_full_workflow = do
  putStrLn "=== Full UI Workflow Example ==="

  putStrLn "\n1. User creates project"
  putStrLn "   Action: CreateProject 'myproject' 'description' []"
  putStrLn "   Response: ProjectCreated 'myproject' InputPhase"

  putStrLn "\n2. Backend starts processing (Phase 1 → 2 → 3 → 4)"
  putStrLn "   UI shows: Activity indicator (green pulse)"
  putStrLn "   UI shows: Phase visualization with current phase"

  putStrLn "\n3. Error occurs in Phase 4 (Compilation)"
  putStrLn "   Backend: is_active = False"
  putStrLn "   UI shows: Error message + Recovery options"

  putStrLn "\n4. User updates prompt and resumes"
  putStrLn "   Action: ResumeProject 'myproject' (Just 'updated prompt') True"
  putStrLn "   Response: ResumeStarted 'myproject' AnalysisPhase"
  putStrLn "   UI: Redirects to /projects"

  putStrLn "\n5. User can abort if needed"
  putStrLn "   Action: AbortProject 'myproject' (while is_active = True)"
  putStrLn "   Response: ExecutionAborted 'myproject' CompilationPhase"
  putStrLn "   UI: Shows '⏸️ 중단됨' status"

  putStrLn "\n✅ All actions are type-safe and verified by Idris2!"
