||| Workflow Control Specification
|||
||| 워크플로우 시작, 중단, 재개에 대한 타입 안전한 명세
||| UI에서 사용자가 수행하는 모든 제어 동작을 타입으로 보장

module Spec.WorkflowControl

import Spec.WorkflowTypes
import Spec.ProjectRecovery

%default total

-- ============================================================================
-- Workflow Control State (워크플로우 제어 상태)
-- ============================================================================

||| 자동 일시 중단 이유 (ExecutionState보다 먼저 정의해야 함)
public export
data AutoPauseReason : Type where
  ||| 동일한 에러가 3회 연속 반복됨
  IdenticalError3x : (errorPreview : String) -> AutoPauseReason

  ||| 최대 재시도 횟수 초과 (5회)
  MaxRetriesExceeded : (attempts : Nat) -> AutoPauseReason

  ||| 사용자 데이터 검증 필요 (증명 실패 등)
  DataValidationNeeded : (proofError : String) -> AutoPauseReason

||| 워크플로우의 실행 상태
public export
data ExecutionState : Type where
  ||| 아직 시작되지 않음
  NotStarted : ExecutionState

  ||| 현재 실행 중 (백그라운드)
  Running : (currentPhase : Phase) -> ExecutionState

  ||| 일시 중단됨 (사용자가 중단 버튼 클릭)
  Paused : (pausedAt : Phase) -> ExecutionState

  ||| 에러로 인해 멈춤 (자동 재시도 실패)
  Stopped : (stoppedAt : Phase) -> (errorMsg : String) -> ExecutionState

  ||| 동일 에러 3회 반복으로 자동 일시 중단 (사용자 개입 필요)
  AutoPaused : (pausedAt : Phase) -> (reason : AutoPauseReason) -> ExecutionState

  ||| 완료됨
  Completed : ExecutionState

-- ============================================================================
-- Control Actions (제어 액션)
-- ============================================================================

||| 사용자가 워크플로우에 대해 수행할 수 있는 제어 동작
public export
data ControlAction : Type where
  ||| 새 프로젝트 시작
  StartNew : (name : String) -> (prompt : String) -> (files : List String) -> ControlAction

  ||| 진행 중인 작업 중단 (현재 Phase에서 멈춤)
  Pause : (name : String) -> ControlAction

  ||| 중단된/에러난 프로젝트 재개 (같은 Phase부터)
  Resume : (name : String) -> ControlAction

  ||| 프롬프트 수정 후 재시작 (Phase 2부터)
  RestartWithPrompt : (name : String) -> (newPrompt : String) -> ControlAction

  ||| 완전히 처음부터 재시작 (Phase 1부터)
  RestartFromBeginning : (name : String) -> ControlAction

  ||| 프로젝트 취소 (상태 유지, 실행만 중단)
  Cancel : (name : String) -> ControlAction

-- ============================================================================
-- Resume Options (AutoPaused 상태에서 재개 옵션)
-- ============================================================================

||| AutoPaused 상태에서 사용자가 선택할 수 있는 재개 옵션
public export
data ResumeOption : Type where
  ||| 프롬프트 수정 후 Phase 2부터 재시도
  RetryWithNewPrompt : (newPrompt : String) -> ResumeOption

  ||| 참조 문서 추가 후 Phase 2부터 재시도
  RetryWithMoreDocs : (newDocs : List String) -> ResumeOption

  ||| 검증 스킵하고 문서 생성 (증명 제거)
  SkipValidation : ResumeOption

  ||| 사용자가 Idris2 코드 수동 수정 후 재개
  ManualFix : (fixedFilePath : String) -> ResumeOption

  ||| 프로젝트 취소
  CancelProject : ResumeOption

||| AutoPaused 상태에서 사용 가능한 옵션 확인
public export
availableResumeOptions : AutoPauseReason -> List ResumeOption
availableResumeOptions (IdenticalError3x _) =
  [ RetryWithNewPrompt ""  -- 프롬프트 수정
  , RetryWithMoreDocs []   -- 참조 문서 추가
  , ManualFix ""           -- 수동 수정
  , CancelProject          -- 취소
  ]
availableResumeOptions (MaxRetriesExceeded _) =
  [ RetryWithNewPrompt ""
  , SkipValidation
  , CancelProject
  ]
availableResumeOptions (DataValidationNeeded _) =
  [ RetryWithNewPrompt ""
  , SkipValidation         -- 증명 제거
  , CancelProject
  ]

-- ============================================================================
-- Control Predicates (제어 가능 여부 검증)
-- ============================================================================

||| 시작 가능한가? (NotStarted 상태에서만)
public export
canStart : ExecutionState -> Bool
canStart NotStarted = True
canStart _ = False

||| 중단 가능한가? (Running 상태에서만)
public export
canPause : ExecutionState -> Bool
canPause (Running _) = True
canPause _ = False

||| 재개 가능한가? (Paused, Stopped, AutoPaused 상태에서)
public export
canResume : ExecutionState -> Bool
canResume (Paused _) = True
canResume (Stopped _ _) = True
canResume (AutoPaused _ _) = True  -- AutoPaused도 재개 가능
canResume _ = False

||| 재시작 가능한가? (Stopped, Paused, AutoPaused, Completed 상태에서)
public export
canRestart : ExecutionState -> Bool
canRestart (Paused _) = True
canRestart (Stopped _ _) = True
canRestart (AutoPaused _ _) = True  -- AutoPaused도 재시작 가능
canRestart Completed = True
canRestart _ = False

||| 취소 가능한가? (Running, Paused 상태에서)
public export
canCancel : ExecutionState -> Bool
canCancel (Running _) = True
canCancel (Paused _) = True
canCancel _ = False

-- ============================================================================
-- State Transitions (상태 전환)
-- ============================================================================

||| 제어 액션 실행 후 상태 전환
public export
data ControlTransition : ExecutionState -> ControlAction -> ExecutionState -> Type where
  ||| 시작: NotStarted → Running
  TransStart : (action : ControlAction)
            -> ControlTransition NotStarted action (Running InputPhase)

  ||| 중단: Running → Paused
  TransPause : (phase : Phase)
            -> ControlTransition (Running phase) (Pause name) (Paused phase)

  ||| 재개 (같은 Phase): Paused → Running
  TransResume : (phase : Phase)
             -> ControlTransition (Paused phase) (Resume name) (Running phase)

  ||| 재개 (에러 후): Stopped → Running
  TransResumeAfterError : (phase : Phase)
                       -> (errorMsg : String)
                       -> ControlTransition (Stopped phase errorMsg) (Resume name) (Running phase)

  ||| 재개 (AutoPaused 후): AutoPaused → Running (ResumeOption 적용)
  TransResumeAfterAutoPause : (phase : Phase)
                           -> (reason : AutoPauseReason)
                           -> (option : ResumeOption)
                           -> ControlTransition (AutoPaused phase reason) (Resume name) (Running phase)

  ||| 자동 일시 중단: Running → AutoPaused (동일 에러 3회)
  TransAutoPause : (phase : Phase)
                -> (reason : AutoPauseReason)
                -> ControlTransition (Running phase) (Pause name) (AutoPaused phase reason)

  ||| 재시작 (프롬프트 수정): Any → Running AnalysisPhase
  TransRestartWithPrompt : (oldState : ExecutionState)
                        -> (newPrompt : String)
                        -> ControlTransition oldState (RestartWithPrompt name newPrompt) (Running AnalysisPhase)

  ||| 재시작 (처음부터): Any → Running InputPhase
  TransRestartFromBeginning : (oldState : ExecutionState)
                           -> ControlTransition oldState (RestartFromBeginning name) (Running InputPhase)

  ||| 취소: Running/Paused/AutoPaused → NotStarted
  TransCancel : (state : ExecutionState)
             -> ControlTransition state (Cancel name) NotStarted

-- ============================================================================
-- Control Safety (제어 안전성)
-- ============================================================================

||| 제어 액션이 현재 상태에서 안전한지 검증
public export
data ControlSafety : ExecutionState -> ControlAction -> Type where
  ||| Start는 NotStarted에서만 안전
  SafeStart : ControlSafety NotStarted (StartNew name prompt files)

  ||| Pause는 Running에서만 안전
  SafePause : (phase : Phase) -> ControlSafety (Running phase) (Pause name)

  ||| Resume은 Paused/Stopped/AutoPaused에서만 안전
  SafeResumePaused : (phase : Phase) -> ControlSafety (Paused phase) (Resume name)
  SafeResumeStopped : (phase : Phase) -> (err : String) -> ControlSafety (Stopped phase err) (Resume name)
  SafeResumeAutoPaused : (phase : Phase) -> (reason : AutoPauseReason) -> ControlSafety (AutoPaused phase reason) (Resume name)

  ||| Restart는 거의 모든 상태에서 안전
  SafeRestart : (oldState : ExecutionState) -> ControlSafety oldState (RestartWithPrompt name prompt)

  ||| Cancel은 Running/Paused/AutoPaused에서만 안전
  SafeCancelRunning : (phase : Phase) -> ControlSafety (Running phase) (Cancel name)
  SafeCancelPaused : (phase : Phase) -> ControlSafety (Paused phase) (Cancel name)
  SafeCancelAutoPaused : (phase : Phase) -> (reason : AutoPauseReason) -> ControlSafety (AutoPaused phase reason) (Cancel name)

-- ============================================================================
-- UI State Mapping (UI 상태 매핑)
-- ============================================================================

||| WorkflowState를 ExecutionState로 변환
|||
||| Note: Python 구현에는 is_active 필드가 있지만,
||| Idris2 명세는 순수 타입만 다루므로 compileResult로 추론
public export
toExecutionState : WorkflowState -> ExecutionState
toExecutionState state =
  if state.completed
    then Completed
  else case state.compileResult of
    Just (CompileError err) => Stopped state.currentPhase err
    _ => if state.currentPhase == InputPhase
           then NotStarted
           else Paused state.currentPhase

||| ExecutionState에서 사용 가능한 UI 버튼 결정
public export
data AvailableButtons : ExecutionState -> Type where
  ||| NotStarted: "시작" 버튼만
  ShowStartButton : AvailableButtons NotStarted

  ||| Running: "중단" 버튼만
  ShowPauseButton : (phase : Phase) -> AvailableButtons (Running phase)

  ||| Paused: "재개", "재시작" 버튼
  ShowResumeAndRestart : (phase : Phase) -> AvailableButtons (Paused phase)

  ||| Stopped: "재개", "프롬프트 수정", "처음부터" 버튼
  ShowRecoveryOptions : (phase : Phase) -> (err : String) -> AvailableButtons (Stopped phase err)

  ||| AutoPaused: 중단 이유에 따라 다른 재개 옵션 표시
  ShowAutoPauseOptions : (phase : Phase) -> (reason : AutoPauseReason) -> AvailableButtons (AutoPaused phase reason)

  ||| Completed: "다시 생성" 버튼
  ShowRegenerate : AvailableButtons Completed

||| AutoPaused 상태에서 사용자에게 보여줄 UI 메시지
public export
autoPauseMessage : AutoPauseReason -> String
autoPauseMessage (IdenticalError3x preview) =
  "동일한 에러가 3회 반복되어 자동으로 중단되었습니다.\n\n" ++
  "에러 내용: " ++ preview ++ "\n\n" ++
  "다음 중 하나를 선택해주세요:\n" ++
  "1. 프롬프트를 더 구체적으로 수정\n" ++
  "2. 참조 문서 추가\n" ++
  "3. Idris2 파일 수동 수정\n" ++
  "4. 프로젝트 취소"

autoPauseMessage (MaxRetriesExceeded n) =
  "최대 재시도 횟수(" ++ show n ++ "회)를 초과했습니다.\n\n" ++
  "다음 중 하나를 선택해주세요:\n" ++
  "1. 프롬프트 수정 후 재시도\n" ++
  "2. 검증 스킵하고 문서 생성\n" ++
  "3. 프로젝트 취소"

autoPauseMessage (DataValidationNeeded proofErr) =
  "데이터 검증이 필요합니다.\n\n" ++
  "증명 실패: " ++ proofErr ++ "\n\n" ++
  "다음 중 하나를 선택해주세요:\n" ++
  "1. 입력 데이터 확인 후 프롬프트 수정\n" ++
  "2. 검증 스킵하고 문서 생성 (증명 제거)\n" ++
  "3. 프로젝트 취소"

-- ============================================================================
-- Backend Background Task (백엔드 백그라운드 작업)
-- ============================================================================

||| 백그라운드 작업의 상태
public export
data BackgroundTask : Type where
  ||| 작업 없음
  NoTask : BackgroundTask

  ||| 작업 진행 중
  TaskRunning : (projectName : String)
             -> (currentPhase : Phase)
             -> (startedAt : String)
             -> BackgroundTask

  ||| 작업 완료됨
  TaskCompleted : (projectName : String)
               -> (completedAt : String)
               -> BackgroundTask

  ||| 작업 실패
  TaskFailed : (projectName : String)
            -> (failedAt : Phase)
            -> (errorMsg : String)
            -> BackgroundTask

||| 백그라운드 작업 시작 가능 여부
public export
canStartBackgroundTask : BackgroundTask -> Bool
canStartBackgroundTask NoTask = True
canStartBackgroundTask (TaskCompleted _ _) = True
canStartBackgroundTask (TaskFailed _ _ _) = True
canStartBackgroundTask _ = False

||| 백그라운드 작업 중단 가능 여부
public export
canStopBackgroundTask : BackgroundTask -> Bool
canStopBackgroundTask (TaskRunning _ _ _) = True
canStopBackgroundTask _ = False

-- ============================================================================
-- Example Workflow Control
-- ============================================================================

||| 예제: 전체 제어 흐름
public export
example_control_workflow : IO ()
example_control_workflow = do
  putStrLn "=== Workflow Control Example ==="

  putStrLn "\n1. 사용자가 '새 프로젝트' 클릭"
  putStrLn "   State: NotStarted"
  putStrLn "   Available: [시작] 버튼"
  putStrLn "   Action: StartNew 'myproject' 'create contract' []"
  putStrLn "   → Transition: NotStarted → Running InputPhase"

  putStrLn "\n2. 백그라운드에서 Phase 2, 3 진행 중"
  putStrLn "   State: Running AnalysisPhase"
  putStrLn "   Available: [중단] 버튼"
  putStrLn "   UI: 녹색 펄스 애니메이션 + 진행률 표시"

  putStrLn "\n3. 사용자가 '중단' 클릭"
  putStrLn "   Action: Pause 'myproject'"
  putStrLn "   → Transition: Running AnalysisPhase → Paused AnalysisPhase"
  putStrLn "   UI: [재개] [재시작] 버튼 표시"

  putStrLn "\n4. 사용자가 '재개' 클릭"
  putStrLn "   Action: Resume 'myproject'"
  putStrLn "   → Transition: Paused AnalysisPhase → Running AnalysisPhase"
  putStrLn "   UI: 백그라운드 작업 계속 진행"

  putStrLn "\n5. Phase 4에서 에러 발생"
  putStrLn "   Backend: 자동 재시도 3회 → 실패"
  putStrLn "   → Transition: Running CompilationPhase → Stopped CompilationPhase 'error msg'"
  putStrLn "   UI: [재개] [프롬프트 수정] [처음부터] 버튼"

  putStrLn "\n6. 사용자가 '프롬프트 수정' 후 재시작"
  putStrLn "   Action: RestartWithPrompt 'myproject' 'updated prompt'"
  putStrLn "   → Transition: Stopped → Running AnalysisPhase"
  putStrLn "   UI: Phase 2부터 재시작"

  putStrLn "\n✅ All transitions are type-safe!"
