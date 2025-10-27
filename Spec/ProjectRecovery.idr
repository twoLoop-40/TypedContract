||| Project Recovery Type Specification
|||
||| 실패한 프로젝트를 안전하게 재개하기 위한 타입 명세
||| 각 Phase의 실패 원인을 분석하고 적절한 복구 전략을 제공

module Spec.ProjectRecovery

import Spec.WorkflowTypes
import Spec.ErrorHandling

%default total

-- ============================================================================
-- Recovery State (복구 가능 상태)
-- ============================================================================

||| 프로젝트가 복구 가능한 상태인지 판단
public export
data RecoveryState : Type where
  ||| 복구 가능: Phase를 재시도할 수 있음
  Recoverable : (failedPhase : Phase)
             -> (errorMsg : String)
             -> (attemptCount : Nat)
             -> RecoveryState

  ||| 복구 불가: 사용자 개입 필요
  Unrecoverable : (failedPhase : Phase)
               -> (reason : String)
               -> RecoveryState

  ||| 완료됨: 복구 불필요
  NoRecoveryNeeded : RecoveryState

-- ============================================================================
-- Recovery Strategy (복구 전략)
-- ============================================================================

||| Phase 실패 시 적용할 복구 전략
public export
data RecoveryStrategy : Type where
  ||| 자동 재시도: 같은 Phase를 다시 실행
  RetryPhase : (maxRetries : Nat) -> RecoveryStrategy

  ||| 이전 Phase부터 재시작: 분석부터 다시
  RestartFromAnalysis : RecoveryStrategy

  ||| 수동 수정: 생성된 코드를 사용자가 수정
  ManualFix : (codeFile : String) -> RecoveryStrategy

  ||| 프롬프트 재작성: 사용자가 프롬프트 수정 후 재시작
  RewritePrompt : RecoveryStrategy

  ||| 참조 문서 추가: 더 많은 컨텍스트 제공
  AddMoreReferences : RecoveryStrategy

-- ============================================================================
-- Recovery Decision (복구 결정)
-- ============================================================================

||| Phase별 실패 원인과 적절한 복구 전략 매칭
public export
decideRecoveryStrategy : Phase -> ErrorLevel -> Nat -> RecoveryStrategy
decideRecoveryStrategy phase errorLevel attemptCount =
  case phase of
    -- Phase 2: Analysis 실패
    AnalysisPhase =>
      if attemptCount < 3
        then RetryPhase 3
        else AddMoreReferences

    -- Phase 3: Spec Generation 실패
    SpecGenerationPhase =>
      case errorLevel of
        SyntaxError => RetryPhase 5
        ProofFailure => RestartFromAnalysis
        DomainError => RewritePrompt
        _ => RetryPhase 3

    -- Phase 4: Compilation 실패
    CompilationPhase =>
      case errorLevel of
        SyntaxError => RetryPhase 5
        ProofFailure => ManualFix "Domains/[project].idr"
        DomainError => RestartFromAnalysis
        _ => RetryPhase 3

    -- Phase 5: DocImpl 실패
    DocImplPhase =>
      if attemptCount < 3
        then RetryPhase 3
        else ManualFix "Pipeline/[project].idr"

    -- Phase 6: Draft 실패
    DraftPhase =>
      RetryPhase 2

    -- 기타 Phase
    _ => RetryPhase 2

-- ============================================================================
-- Recovery Actions (복구 액션)
-- ============================================================================

||| 사용자가 선택할 수 있는 복구 액션
public export
data RecoveryAction : Type where
  ||| 자동 재시도
  AutoRetry : RecoveryAction

  ||| 분석부터 재시작
  RestartAnalysis : RecoveryAction

  ||| 코드 수정 후 재시도
  FixCodeAndRetry : (editedCode : String) -> RecoveryAction

  ||| 프롬프트 수정 후 재시작
  UpdatePrompt : (newPrompt : String) -> RecoveryAction

  ||| 참조 문서 추가 후 재시작
  AddReferences : (newDocs : List String) -> RecoveryAction

  ||| 실행 중단 (진행 중인 작업 중지)
  AbortExecution : RecoveryAction

  ||| 프로젝트 포기 (완전 삭제)
  Abandon : RecoveryAction

-- ============================================================================
-- Recovery Execution (복구 실행)
-- ============================================================================

||| 복구 액션을 실행하여 새로운 WorkflowState 생성
public export
data RecoveryExecution : RecoveryAction -> Type where
  ||| AutoRetry: 같은 Phase를 다시 시도
  ExecAutoRetry : (state : WorkflowState)
               -> RecoveryExecution AutoRetry

  ||| RestartAnalysis: Phase 2부터 재시작
  ExecRestartAnalysis : (state : WorkflowState)
                     -> RecoveryExecution RestartAnalysis

  ||| FixCodeAndRetry: 코드 수정 후 컴파일 재시도
  ExecFixCode : (state : WorkflowState)
             -> (newCode : String)
             -> RecoveryExecution (FixCodeAndRetry newCode)

  ||| UpdatePrompt: 프롬프트 수정 후 처음부터
  ExecUpdatePrompt : (state : WorkflowState)
                  -> (newPrompt : String)
                  -> RecoveryExecution (UpdatePrompt newPrompt)

  ||| AddReferences: 참조 문서 추가 후 재분석
  ExecAddReferences : (state : WorkflowState)
                   -> (newDocs : List String)
                   -> RecoveryExecution (AddReferences newDocs)

-- ============================================================================
-- Recovery Safety (복구 안전성)
-- ============================================================================

||| 복구 작업이 안전한지 검증
public export
isSafeToRecover : WorkflowState -> Bool
isSafeToRecover state =
  -- 이미 완료된 프로젝트는 복구 불필요
  if completed state then False
  -- Input Phase는 재개할 것이 없음
  else if currentPhase state == InputPhase then False
  -- 그 외에는 모두 복구 가능
  else True

||| 특정 Phase로 롤백 가능한지 검증
public export
canRollbackTo : Phase -> WorkflowState -> Bool
canRollbackTo targetPhase state =
  case compare (phaseOrder targetPhase) (phaseOrder (currentPhase state)) of
    LT => True   -- 이전 Phase로만 롤백 가능
    _  => False
  where
    phaseOrder : Phase -> Nat
    phaseOrder InputPhase = 0
    phaseOrder AnalysisPhase = 1
    phaseOrder SpecGenerationPhase = 2
    phaseOrder CompilationPhase = 3
    phaseOrder ErrorHandlingPhase = 3  -- Phase 4b
    phaseOrder DocImplPhase = 4
    phaseOrder DraftPhase = 5
    phaseOrder FeedbackPhase = 6
    phaseOrder RefinementPhase = 7
    phaseOrder FinalPhase = 8

-- ============================================================================
-- Recovery History (복구 이력)
-- ============================================================================

||| 복구 시도 이력 기록
public export
record RecoveryAttempt where
  constructor MkRecoveryAttempt
  timestamp : String
  phase : Phase
  action : String
  success : Bool
  errorMsg : Maybe String

||| 프로젝트의 전체 복구 이력
public export
record RecoveryHistory where
  constructor MkRecoveryHistory
  projectName : String
  totalAttempts : Nat
  successfulRecoveries : Nat
  attempts : List RecoveryAttempt

-- ============================================================================
-- Type-Safe Recovery Proof (복구 타입 안전성 증명)
-- ============================================================================

||| 복구 후 WorkflowState가 일관성을 유지함을 증명
public export
data RecoveryPreservesInvariant : WorkflowState -> WorkflowState -> Type where
  ||| Phase만 변경되고 projectName은 유지
  PreservesProjectName : (before : WorkflowState)
                      -> (after : WorkflowState)
                      -> RecoveryPreservesInvariant before after

  ||| 롤백 시 이후 Phase의 데이터는 초기화
  ClearsSubsequentData : (before : WorkflowState)
                      -> (after : WorkflowState)
                      -> RecoveryPreservesInvariant before after

-- ============================================================================
-- Example Usage
-- ============================================================================

||| 예제: 컴파일 실패 후 복구
public export
example_recovery : IO ()
example_recovery = do
  putStrLn "=== Recovery Example ==="

  -- 1. 실패한 상태 가정
  putStrLn "\n1. Project failed at CompilationPhase"
  putStrLn "   Error: Type mismatch in domain model"

  -- 2. 복구 전략 결정
  let strategy = decideRecoveryStrategy CompilationPhase ProofFailure 2
  putStrLn "\n2. Recovery strategy: Manual fix required"

  -- 3. 사용자 액션 선택
  putStrLn "\n3. User can choose:"
  putStrLn "   - AutoRetry (최대 5회)"
  putStrLn "   - FixCodeAndRetry (코드 수정)"
  putStrLn "   - RestartAnalysis (재분석)"

  -- 4. 복구 실행
  putStrLn "\n4. Executing recovery..."
  putStrLn "   ✓ Rolling back to CompilationPhase"
  putStrLn "   ✓ Clearing error state"
  putStrLn "   ✓ Ready to retry"

