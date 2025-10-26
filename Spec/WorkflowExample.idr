module Spec.WorkflowExample

import Spec.WorkflowTypes
import Spec.AgentOperations
import Spec.WorkflowExecution

------------------------------------------------------------
-- 워크플로우 사용 예제
-- 목적: 타입 명세를 실제로 사용하는 방법 시연
------------------------------------------------------------

------------------------------------------------------------
-- 1. Mock 에이전트 작업 구현 (시뮬레이션용)
------------------------------------------------------------

-- Mock 문서 분석
mockAnalyzeDocument : AnalyzeDocument
mockAnalyzeDocument input =
  Success $ MkAnalysisOutput
    "contract"
    [("client", "스피라티"), ("contractor", "이츠에듀")]
    ["total = supply + vat"]
    "ServiceContract { client, contractor, terms }"

-- Mock 명세 생성
mockGenerateSpec : GenerateSpec
mockGenerateSpec input =
  Success $ MkSpecGenOutput
    ("module Domains." ++ input.projectName ++ "\n\n-- Mock spec code")
    ("Domains/" ++ input.projectName ++ ".idr")

-- Mock 컴파일 (항상 성공)
mockCompileIdris : CompileIdris
mockCompileIdris input =
  Success $ MkCompileOutput True Nothing 1

-- Mock 에러 수정
mockFixError : FixError
mockFixError input =
  Success $ MkFixErrorOutput
    (input.originalCode ++ "\n-- Fixed!")
    "Added missing import"

-- Mock Documentable 생성
mockGenerateDocumentable : GenerateDocumentable
mockGenerateDocumentable input =
  Success $ MkDocGenOutput
    ("Documentable " ++ input.projectName ++ " where ...")
    "Core/DomainToDoc.idr"

-- Mock 파이프라인 생성
mockGeneratePipeline : GeneratePipeline
mockGeneratePipeline input =
  Success $ MkPipelineGenOutput
    ("pipeline" ++ input.projectName ++ " = ...")
    "Core/Generator.idr"

-- Mock 초안 생성
mockGenerateDraft : GenerateDraft
mockGenerateDraft input =
  Success $ MkDraftGenOutput
    ("Draft content for " ++ input.projectName ++ " in " ++ show input.outputFormat)
    ("output/" ++ input.projectName ++ "_draft.txt")

-- Mock 피드백 파싱
mockParseFeedback : ParseFeedback
mockParseFeedback input =
  Success $ MkFeedbackOutput
    [("advance", "30%")]
    (input.currentSpec ++ "\n-- Modified based on feedback")

-- Mock 에이전트 전체
mockAgentOps : AgentOperations
mockAgentOps = MkAgentOps
  mockAnalyzeDocument
  mockGenerateSpec
  mockCompileIdris
  mockFixError
  mockGenerateDocumentable
  mockGeneratePipeline
  mockGenerateDraft
  mockParseFeedback

------------------------------------------------------------
-- 2. 예제 1: 단순 워크플로우 (피드백 없음)
------------------------------------------------------------

export
simpleWorkflowExample : AgentResult WorkflowState
simpleWorkflowExample =
  let
    -- 초기 상태
    initial = initialState
      "SpiratiContract"
      "스피라티-이츠에듀 용역계약서 생성"
      ["direction/contract.pdf"]

    -- 워크플로우 실행 (최대 20 단계)
  in runWorkflow initial mockAgentOps 20

------------------------------------------------------------
-- 3. 예제 2: 단계별 수동 실행
------------------------------------------------------------

export
stepByStepExample : List (Phase, Bool)
stepByStepExample =
  let
    -- 초기 상태
    s0 = initialState "MyProject" "Create a contract" ["doc.pdf"]

    -- Phase 1: Input → Analysis
    s1Result = executeInputPhase s0 mockAnalyzeDocument
    s1Success = isSuccess s1Result
    s1 = getResultOr s1Result s0

    -- Phase 2: Analysis → Spec Generation
    s2Result = executeAnalysisPhase s1 mockGenerateSpec
    s2Success = isSuccess s2Result
    s2 = getResultOr s2Result s1

    -- Phase 3: Spec → Compilation
    s3Result = executeSpecGenerationPhase s2 mockCompileIdris
    s3Success = isSuccess s3Result
    s3 = getResultOr s3Result s2

  in [ (s0.currentPhase, True)
     , (s1.currentPhase, s1Success)
     , (s2.currentPhase, s2Success)
     , (s3.currentPhase, s3Success)
     ]

------------------------------------------------------------
-- 4. 예제 3: 피드백 루프
------------------------------------------------------------

export
feedbackLoopExample : AgentResult WorkflowState
feedbackLoopExample =
  let
    -- 초기 상태로 워크플로우 실행 (DraftPhase까지)
    initial = initialState "FeedbackTest" "Test feedback" ["test.pdf"]
    draftState = runWorkflow initial mockAgentOps 10

  in case draftState of
    Success state =>
      if state.currentPhase == FeedbackPhase
        then
          -- 사용자 피드백 시뮬레이션
          let fbState = executeFeedbackPhase state (NeedsRevision "선급금 30%로 변경")
          in case fbState of
            Success stateWithFeedback =>
              -- 개선 단계 실행
              executeRefinementPhase stateWithFeedback
                mockParseFeedback
                mockGenerateSpec
            Failure msg => Failure msg
        else Success state
    Failure msg => Failure msg

------------------------------------------------------------
-- 5. 예제 4: 상태 검증
------------------------------------------------------------

export
stateValidationExample : List (String, Bool)
stateValidationExample =
  let
    -- 다양한 상태 생성
    s0 = initialState "Test" "prompt" ["doc.pdf"]

    s1 =
      { analysisResult := Just "Analysis complete"
      } s0

    s2 =
      { specCode := Just "module Test"
      , specFile := Just "Domains/Test.idr"
      } s1

    s3 =
      { compileResult := Just CompileSuccess
      } s2

  in [ ("Input phase complete", inputPhaseComplete s0)
     , ("Analysis phase complete", analysisPhaseComplete s1)
     , ("Spec generation complete", specGenerationPhaseComplete s2)
     , ("Compilation complete", compilationPhaseComplete s3)
     ]

------------------------------------------------------------
-- 6. 예제 5: 버전 관리
------------------------------------------------------------

export
versioningExample : List String
versioningExample =
  let
    s0 = initialState "VersionTest" "test" ["doc.pdf"]
    s1 = incrementVersion s0
    s2 = incrementVersion s1
    s3 = incrementVersion s2
  in [ versionString s0.version
     , versionString s1.version
     , versionString s2.version
     , versionString s3.version
     ]

------------------------------------------------------------
-- 7. 예제 6: 컴파일 재시도
------------------------------------------------------------

export
retryExample : List (Nat, Bool)
retryExample =
  let
    s0 = initialState "RetryTest" "test" ["doc.pdf"]
    s1 = incrementCompileAttempts s0
    s2 = incrementCompileAttempts s1
    s3 = incrementCompileAttempts s2
    s4 = incrementCompileAttempts s3
    s5 = incrementCompileAttempts s4
    s6 = incrementCompileAttempts s5
  in [ (s0.compileAttempts, canRetryCompile s0)
     , (s1.compileAttempts, canRetryCompile s1)
     , (s2.compileAttempts, canRetryCompile s2)
     , (s3.compileAttempts, canRetryCompile s3)
     , (s4.compileAttempts, canRetryCompile s4)
     , (s5.compileAttempts, canRetryCompile s5)
     , (s6.compileAttempts, canRetryCompile s6)
     ]

------------------------------------------------------------
-- 8. 타입 안전성 시연
------------------------------------------------------------

-- 잘못된 상태 전이는 컴파일 에러!
-- 예: AnalysisPhase를 건너뛰고 SpecGenerationPhase로 가려고 하면?

{-
wrongTransition : WorkflowState -> Maybe WorkflowState
wrongTransition state =
  -- state.analysisResult가 Nothing이면 실패
  executeAnalysisPhase state mockGenerateSpec
  -- ↑ 타입은 통과하지만, Maybe WorkflowState 반환으로 실패 가능성 표현
-}

------------------------------------------------------------
-- 9. 사용 시연
------------------------------------------------------------

{-
main : IO ()
main = do
  putStrLn "=== Workflow Type Specification Demo ==="

  -- 예제 1: 단순 워크플로우
  case simpleWorkflowExample of
    Success finalState => do
      putStrLn $ "✅ Workflow completed!"
      putStrLn $ "   Final phase: " ++ show finalState.currentPhase
      putStrLn $ "   Version: " ++ versionString finalState.version
      putStrLn $ "   Completed: " ++ show finalState.completed
    Failure msg =>
      putStrLn $ "❌ Workflow failed: " ++ msg

  -- 예제 2: 단계별 실행
  putStrLn "\n=== Step-by-step execution ==="
  traverse_ (\(phase, success) =>
    putStrLn $ show phase ++ ": " ++ if success then "✅" else "❌"
  ) stepByStepExample

  -- 예제 3: 버전 관리
  putStrLn "\n=== Version management ==="
  traverse_ (\v => putStrLn $ "Version: " ++ v) versioningExample

  -- 예제 4: 재시도
  putStrLn "\n=== Retry logic ==="
  traverse_ (\(attempts, canRetry) =>
    putStrLn $ "Attempts: " ++ show attempts ++
               ", Can retry: " ++ if canRetry then "Yes" else "No"
  ) retryExample
-}
