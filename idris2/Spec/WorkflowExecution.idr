module Spec.WorkflowExecution

import Spec.WorkflowTypes
import Spec.AgentOperations

------------------------------------------------------------
-- 워크플로우 실행 명세
-- 목적: 각 단계의 상태 전이를 타입 안전하게 정의
------------------------------------------------------------

------------------------------------------------------------
-- 1. Phase 1: 입력 수집 → 분석
------------------------------------------------------------

public export
executeInputPhase : WorkflowState -> AnalyzeDocument -> AgentResult WorkflowState
executeInputPhase state analyze =
  case (state.userPrompt, state.referenceDocs) of
    (Just prompt, docs) =>
      let input = MkAnalysisInput prompt docs
      in case analyze input of
        Success analysis =>
          Success $
            { currentPhase := AnalysisPhase
            , analysisResult := Just (show analysis)
            } state
        Failure msg =>
          Failure msg
    _ => Failure "Missing user prompt or reference documents"

------------------------------------------------------------
-- 2. Phase 2: 분석 → 명세 생성
------------------------------------------------------------

public export
executeAnalysisPhase : WorkflowState -> GenerateSpec -> AgentResult WorkflowState
executeAnalysisPhase state genSpec =
  case state.analysisResult of
    Just analysis =>
      let input = MkSpecGenInput state.projectName
                    (MkAnalysisOutput "contract" [] [] analysis)  -- 간소화
      in case genSpec input of
        Success output =>
          Success $
            { currentPhase := SpecGenerationPhase
            , specCode := Just output.specCode
            , specFile := Just output.specFilePath
            } state
        Failure msg =>
          Failure msg
    Nothing => Failure "Analysis not completed"

------------------------------------------------------------
-- 3. Phase 3: 명세 생성 → 컴파일
------------------------------------------------------------

public export
executeSpecGenerationPhase : WorkflowState -> CompileIdris -> AgentResult WorkflowState
executeSpecGenerationPhase state compile =
  case state.specFile of
    Just filePath =>
      let input = MkCompileInput filePath
      in case compile input of
        Success output =>
          if output.success
            then Success $
              { currentPhase := CompilationPhase
              , compileResult := Just CompileSuccess
              , compileAttempts := output.attempts
              } state
            else Success $
              { compileResult := Just (CompileError (fromMaybe "Unknown error" output.errorMsg))
              , compileAttempts := output.attempts
              } state
        Failure msg =>
          Failure msg
    Nothing => Failure "Spec file not generated"

------------------------------------------------------------
-- 4. Phase 4: 컴파일 루프 (에러 수정 반복)
------------------------------------------------------------

public export
executeCompilationPhase : WorkflowState -> FixError -> CompileIdris -> AgentResult WorkflowState
executeCompilationPhase state fixErr compile =
  case state.compileResult of
    Just CompileSuccess =>
      -- 성공 → 다음 단계
      Success $ { currentPhase := DocImplPhase } state

    Just (CompileError errMsg) =>
      -- 에러 → 수정 시도
      if canRetryCompile state
        then case (state.specCode, state.specFile) of
          (Just code, Just filePath) =>
            let fixInput = MkFixErrorInput code errMsg state.compileAttempts
            in case fixErr fixInput of
              Success fixed =>
                -- 수정된 코드로 재컴파일
                let newState = { specCode := Just fixed.fixedCode } state
                    compileInput = MkCompileInput filePath
                in case compile compileInput of
                  Success output =>
                    if output.success
                      then Success $
                        { currentPhase := DocImplPhase
                        , compileResult := Just CompileSuccess
                        , compileAttempts := output.attempts
                        } newState
                      else Success $ incrementCompileAttempts $
                        { compileResult := Just (CompileError (fromMaybe "Unknown" output.errorMsg))
                        } newState
                  Failure msg => Failure msg
              Failure msg => Failure msg
          _ => Failure "Missing spec code or file"
        else Failure "Max compile attempts reached"

    Nothing => Failure "Compilation not started"

------------------------------------------------------------
-- 5. Phase 5: 문서 구현 생성
------------------------------------------------------------

public export
executeDocImplPhase : WorkflowState
  -> GenerateDocumentable
  -> GeneratePipeline
  -> AgentResult WorkflowState
executeDocImplPhase state genDoc genPipe =
  case state.specCode of
    Just code =>
      -- Documentable 생성
      let docInput = MkDocGenInput state.projectName code
      in case genDoc docInput of
        Success docOutput =>
          -- Pipeline 생성
          let pipeInput = MkPipelineGenInput state.projectName code
          in case genPipe pipeInput of
            Success pipeOutput =>
              Success $
                { currentPhase := DraftPhase
                , documentableImpl := Just docOutput.documentableCode
                , pipelineImpl := Just pipeOutput.pipelineCode
                } state
            Failure msg => Failure msg
        Failure msg => Failure msg
    Nothing => Failure "Spec code not available"

------------------------------------------------------------
-- 6. Phase 6: 초안 생성
------------------------------------------------------------

public export
executeDraftPhase : WorkflowState -> GenerateDraft -> AgentResult WorkflowState
executeDraftPhase state genDraft =
  -- 텍스트 생성
  let txtInput = MkDraftGenInput state.projectName TextFormat
  in case genDraft txtInput of
    Success txtOutput =>
      -- 마크다운 생성
      let mdInput = MkDraftGenInput state.projectName MarkdownFormat
      in case genDraft mdInput of
        Success mdOutput =>
          -- CSV 생성
          let csvInput = MkDraftGenInput state.projectName CSVFormat
          in case genDraft csvInput of
            Success csvOutput =>
              Success $
                { currentPhase := FeedbackPhase
                , draftText := Just txtOutput.content
                , draftMarkdown := Just mdOutput.content
                , draftCSV := Just csvOutput.content
                } state
            Failure _ =>
              -- CSV 실패해도 진행 (선택적)
              Success $
                { currentPhase := FeedbackPhase
                , draftText := Just txtOutput.content
                , draftMarkdown := Just mdOutput.content
                } state
        Failure msg => Failure msg
    Failure msg => Failure msg

------------------------------------------------------------
-- 7. Phase 7-8: 피드백 처리 및 개선
------------------------------------------------------------

public export
executeFeedbackPhase : WorkflowState -> UserSatisfaction -> AgentResult WorkflowState
executeFeedbackPhase state satisfaction =
  case satisfaction of
    Satisfied =>
      Success $
        { currentPhase := FinalPhase
        , userSatisfaction := Just Satisfied
        } state

    NeedsRevision feedback =>
      Success $
        { currentPhase := RefinementPhase
        , userSatisfaction := Just satisfaction
        , feedbackHistory := feedback :: state.feedbackHistory
        } state

-- 개선 단계: 피드백을 바탕으로 명세 수정
public export
executeRefinementPhase : WorkflowState
  -> ParseFeedback
  -> GenerateSpec
  -> AgentResult WorkflowState
executeRefinementPhase state parseFb genSpec =
  case state.userSatisfaction of
    Just (NeedsRevision feedback) =>
      case state.specCode of
        Just currentSpec =>
          -- 피드백 파싱
          let fbInput = MkFeedbackInput feedback currentSpec
          in case parseFb fbInput of
            Success fbOutput =>
              -- 명세 재생성
              let specInput = MkSpecGenInput state.projectName
                    (MkAnalysisOutput "contract" [] [] fbOutput.updatedRequirements)
              in case genSpec specInput of
                Success output =>
                  Success $ incrementVersion $
                    { currentPhase := CompilationPhase
                    , specCode := Just output.specCode
                    , compileAttempts := 0  -- 재시도 카운터 리셋
                    , compileResult := Nothing
                    } state
                Failure msg => Failure msg
            Failure msg => Failure msg
        Nothing => Failure "No spec code to refine"
    _ => Failure "No revision requested"

------------------------------------------------------------
-- 8. Phase 9: 최종화
------------------------------------------------------------

public export
executeFinalizationPhase : WorkflowState -> Maybe GenerateDraft -> AgentResult WorkflowState
executeFinalizationPhase state maybePDFGen =
  if state.generatePDF
    then case maybePDFGen of
      Just genDraft =>
        let pdfInput = MkDraftGenInput state.projectName PDFFormat
        in case genDraft pdfInput of
          Success output =>
            Success $
              { finalPDFPath := Just output.filePath
              , completed := True
              } state
          Failure msg => Failure msg
      Nothing => Failure "PDF generation requested but not available"
    else Success $ { completed := True } state

------------------------------------------------------------
-- 9. 전체 워크플로우 실행
------------------------------------------------------------

-- 단일 단계 실행
public export
executePhase : WorkflowState -> AgentOperations -> AgentResult WorkflowState
executePhase state ops =
  case state.currentPhase of
    InputPhase => executeInputPhase state ops.analyzeDocument
    AnalysisPhase => executeAnalysisPhase state ops.generateSpec
    SpecGenerationPhase => executeSpecGenerationPhase state ops.compileIdris
    CompilationPhase => executeCompilationPhase state ops.fixError ops.compileIdris
    DocImplPhase => executeDocImplPhase state ops.generateDocumentable ops.generatePipeline
    DraftPhase => executeDraftPhase state ops.generateDraft
    FeedbackPhase => Success state  -- 사용자 입력 대기
    RefinementPhase => Success state  -- 외부에서 처리
    FinalPhase => executeFinalizationPhase state (Just ops.generateDraft)

-- 워크플로우가 완료될 때까지 반복 실행
public export
runWorkflow : WorkflowState -> AgentOperations -> Nat -> AgentResult WorkflowState
runWorkflow state ops Z = Failure "Max iterations reached"
runWorkflow state ops (S k) =
  if workflowComplete state
    then Success state
    else case executePhase state ops of
      Success newState => runWorkflow newState ops k
      Failure msg => Failure msg
