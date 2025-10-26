module Spec.WorkflowTypes

------------------------------------------------------------
-- 문서 생성 워크플로우 타입 명세
-- 목적: 전체 워크플로우를 타입 시스템으로 검증
------------------------------------------------------------

------------------------------------------------------------
-- 0. 헬퍼 함수들
------------------------------------------------------------

-- Maybe 관련 헬퍼
public export
isJust : Maybe a -> Bool
isJust (Just _) = True
isJust Nothing = False

public export
fromMaybe : a -> Maybe a -> a
fromMaybe def Nothing = def
fromMaybe _ (Just x) = x

------------------------------------------------------------
-- 1. 기본 타입들
------------------------------------------------------------

-- 파일 경로
public export
FilePath : Type
FilePath = String

-- 프로젝트 이름
public export
ProjectName : Type
ProjectName = String

-- 사용자 프롬프트
public export
UserPrompt : Type
UserPrompt = String

-- 에러 메시지
public export
ErrorMsg : Type
ErrorMsg = String

------------------------------------------------------------
-- 2. 워크플로우 단계 (Phase)
------------------------------------------------------------

public export
data Phase
  = InputPhase           -- Phase 1: 입력 수집
  | AnalysisPhase        -- Phase 2: 문서 분석
  | SpecGenerationPhase  -- Phase 3: Idris2 명세 생성
  | CompilationPhase     -- Phase 4: 컴파일 및 수정
  | DocImplPhase         -- Phase 5: 문서 구현 생성
  | DraftPhase           -- Phase 6: 초안 생성
  | FeedbackPhase        -- Phase 7: 사용자 피드백
  | RefinementPhase      -- Phase 8: 반복 개선
  | FinalPhase           -- Phase 9: 최종 출력

public export
Eq Phase where
  InputPhase == InputPhase = True
  AnalysisPhase == AnalysisPhase = True
  SpecGenerationPhase == SpecGenerationPhase = True
  CompilationPhase == CompilationPhase = True
  DocImplPhase == DocImplPhase = True
  DraftPhase == DraftPhase = True
  FeedbackPhase == FeedbackPhase = True
  RefinementPhase == RefinementPhase = True
  FinalPhase == FinalPhase = True
  _ == _ = False

public export
Show Phase where
  show InputPhase = "Phase 1: Input Collection"
  show AnalysisPhase = "Phase 2: Analysis"
  show SpecGenerationPhase = "Phase 3: Spec Generation"
  show CompilationPhase = "Phase 4: Compilation"
  show DocImplPhase = "Phase 5: Document Implementation"
  show DraftPhase = "Phase 6: Draft Generation"
  show FeedbackPhase = "Phase 7: User Feedback"
  show RefinementPhase = "Phase 8: Refinement"
  show FinalPhase = "Phase 9: Finalization"

------------------------------------------------------------
-- 3. 컴파일 결과
------------------------------------------------------------

public export
data CompileResult
  = CompileSuccess
  | CompileError ErrorMsg

public export
Show CompileResult where
  show CompileSuccess = "Compilation succeeded"
  show (CompileError msg) = "Compilation failed: " ++ msg

------------------------------------------------------------
-- 4. 사용자 만족도
------------------------------------------------------------

public export
data UserSatisfaction
  = Satisfied
  | NeedsRevision UserPrompt  -- 수정 요청 포함

public export
Show UserSatisfaction where
  show Satisfied = "User is satisfied"
  show (NeedsRevision req) = "User requests revision: " ++ req

------------------------------------------------------------
-- 5. 출력 형식
------------------------------------------------------------

public export
data OutputFormat
  = TextFormat
  | CSVFormat
  | MarkdownFormat
  | PDFFormat

public export
Show OutputFormat where
  show TextFormat = "Text (.txt)"
  show CSVFormat = "CSV (.csv)"
  show MarkdownFormat = "Markdown (.md)"
  show PDFFormat = "PDF (.pdf)"

------------------------------------------------------------
-- 6. 워크플로우 상태 (핵심!)
------------------------------------------------------------

-- 각 단계별 상태를 추적
public export
record WorkflowState where
  constructor MkWorkflowState

  -- 기본 정보
  projectName : ProjectName
  currentPhase : Phase

  -- Phase 1: 입력
  userPrompt : Maybe UserPrompt
  referenceDocs : List FilePath

  -- Phase 2: 분석
  analysisResult : Maybe String

  -- Phase 3-4: 명세 생성
  specCode : Maybe String
  specFile : Maybe FilePath
  compileAttempts : Nat
  compileResult : Maybe CompileResult

  -- Phase 5: 문서 구현
  documentableImpl : Maybe String
  pipelineImpl : Maybe String

  -- Phase 6: 초안
  draftText : Maybe String
  draftMarkdown : Maybe String
  draftCSV : Maybe String

  -- Phase 7-8: 피드백 및 개선
  version : Nat  -- 버전 번호 (v1, v2, ...)
  feedbackHistory : List String
  userSatisfaction : Maybe UserSatisfaction

  -- Phase 9: 최종
  generatePDF : Bool
  finalPDFPath : Maybe FilePath
  completed : Bool

------------------------------------------------------------
-- 7. 초기 상태
------------------------------------------------------------

public export
initialState : ProjectName -> UserPrompt -> List FilePath -> WorkflowState
initialState name prompt docs = MkWorkflowState
  { projectName = name
  , currentPhase = InputPhase
  , userPrompt = Just prompt
  , referenceDocs = docs
  , analysisResult = Nothing
  , specCode = Nothing
  , specFile = Nothing
  , compileAttempts = 0
  , compileResult = Nothing
  , documentableImpl = Nothing
  , pipelineImpl = Nothing
  , draftText = Nothing
  , draftMarkdown = Nothing
  , draftCSV = Nothing
  , version = 1
  , feedbackHistory = []
  , userSatisfaction = Nothing
  , generatePDF = False
  , finalPDFPath = Nothing
  , completed = False
  }

------------------------------------------------------------
-- 8. 상태 검증
------------------------------------------------------------

-- Phase 1 완료 조건
public export
inputPhaseComplete : WorkflowState -> Bool
inputPhaseComplete state =
  isJust state.userPrompt && not (null state.referenceDocs)

-- Phase 2 완료 조건
public export
analysisPhaseComplete : WorkflowState -> Bool
analysisPhaseComplete state =
  isJust state.analysisResult

-- Phase 3 완료 조건
public export
specGenerationPhaseComplete : WorkflowState -> Bool
specGenerationPhaseComplete state =
  isJust state.specCode && isJust state.specFile

-- Phase 4 완료 조건
public export
compilationPhaseComplete : WorkflowState -> Bool
compilationPhaseComplete state =
  case state.compileResult of
    Just CompileSuccess => True
    _ => False

-- Phase 5 완료 조건
public export
docImplPhaseComplete : WorkflowState -> Bool
docImplPhaseComplete state =
  isJust state.documentableImpl && isJust state.pipelineImpl

-- Phase 6 완료 조건
public export
draftPhaseComplete : WorkflowState -> Bool
draftPhaseComplete state =
  isJust state.draftText || isJust state.draftMarkdown

-- 전체 워크플로우 완료 조건
public export
workflowComplete : WorkflowState -> Bool
workflowComplete state =
  state.completed && state.currentPhase == FinalPhase

------------------------------------------------------------
-- 9. 상태 전이 (Phase Transition)
------------------------------------------------------------

-- 다음 단계로 전진 가능한지 확인
public export
canAdvance : WorkflowState -> Phase -> Bool
canAdvance state InputPhase = inputPhaseComplete state
canAdvance state AnalysisPhase = analysisPhaseComplete state
canAdvance state SpecGenerationPhase = specGenerationPhaseComplete state
canAdvance state CompilationPhase = compilationPhaseComplete state
canAdvance state DocImplPhase = docImplPhaseComplete state
canAdvance state DraftPhase = draftPhaseComplete state
canAdvance state FeedbackPhase = True  -- 항상 가능
canAdvance state RefinementPhase = isJust state.userSatisfaction
canAdvance state FinalPhase = True

-- 다음 Phase 결정
public export
nextPhase : Phase -> Phase
nextPhase InputPhase = AnalysisPhase
nextPhase AnalysisPhase = SpecGenerationPhase
nextPhase SpecGenerationPhase = CompilationPhase
nextPhase CompilationPhase = DocImplPhase
nextPhase DocImplPhase = DraftPhase
nextPhase DraftPhase = FeedbackPhase
nextPhase FeedbackPhase = RefinementPhase
nextPhase RefinementPhase = DraftPhase  -- 루프!
nextPhase FinalPhase = FinalPhase  -- 종료

-- 상태 전이 (검증 포함)
public export
advance : WorkflowState -> Maybe WorkflowState
advance state =
  if canAdvance state state.currentPhase
    then Just ({ currentPhase := nextPhase state.currentPhase } state)
    else Nothing

------------------------------------------------------------
-- 10. 컴파일 재시도 로직
------------------------------------------------------------

-- 최대 재시도 횟수
maxCompileAttempts : Nat
maxCompileAttempts = 5

-- 재시도 가능 여부
public export
canRetryCompile : WorkflowState -> Bool
canRetryCompile state =
  state.compileAttempts < maxCompileAttempts

-- 컴파일 시도 증가
public export
incrementCompileAttempts : WorkflowState -> WorkflowState
incrementCompileAttempts state =
  { compileAttempts := S state.compileAttempts } state

------------------------------------------------------------
-- 11. 버전 관리
------------------------------------------------------------

-- 새 버전 생성
public export
incrementVersion : WorkflowState -> WorkflowState
incrementVersion state =
  { version := S state.version } state

-- 버전 번호를 문자열로
public export
versionString : Nat -> String
versionString n = "v" ++ show n
