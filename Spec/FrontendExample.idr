module Spec.FrontendExample

import Spec.FrontendTypes
import Spec.WorkflowTypes
import Spec.RendererOperations

------------------------------------------------------------
-- 프론트엔드 사용 예제
-- 목적: UI 상태 관리 및 사용자 인터랙션 시연
------------------------------------------------------------

------------------------------------------------------------
-- 1. 앱 초기화 예제
------------------------------------------------------------

export
appInitExample : AppState
appInitExample = initialAppState

------------------------------------------------------------
-- 2. 프로젝트 생성 예제
------------------------------------------------------------

export
createProjectExample : ProjectName -> AppState
createProjectExample name =
  let initial = initialAppState
  in { currentView := ProjectDetailView name
     , activeProject := Just name
     , projects := [name]
     , selectedProject := Just (initialProjectState name)
     } initial

------------------------------------------------------------
-- 3. 파일 업로드 시나리오
------------------------------------------------------------

-- 파일 선택
export
selectFilesExample : FileInfo
selectFilesExample = MkFileInfo
  "contract.pdf"
  1024000  -- 1MB
  "application/pdf"
  "/tmp/uploads/contract.pdf"

-- 업로드 진행 상태 업데이트
export
updateUploadProgress : ProjectState -> Nat -> Nat -> ProjectState
updateUploadProgress project c t = { uploadStatus := UploadInProgress c t } project

-- 업로드 완료
export
completeUpload : ProjectState -> List FileInfo -> ProjectState
completeUpload project files = { uploadStatus := UploadComplete (length files), uploadedFiles := files } project

------------------------------------------------------------
-- 4. 채팅 메시지 예제
------------------------------------------------------------

export
userMessageExample : ChatMessage
userMessageExample = MkChatMessage
  "msg-001"
  UserMessage
  "스피라티와 이츠에듀 간 용역계약서를 생성해주세요"
  "2025-10-26T10:00:00Z"

export
assistantMessageExample : ChatMessage
assistantMessageExample = MkChatMessage
  "msg-002"
  AssistantMessage
  "네, 용역계약서를 생성하겠습니다. 파일을 업로드해주세요."
  "2025-10-26T10:00:05Z"

export
systemMessageExample : ChatMessage
systemMessageExample = MkChatMessage
  "msg-003"
  SystemMessage
  "파일 업로드가 완료되었습니다. 분석을 시작합니다."
  "2025-10-26T10:01:00Z"

-- 채팅 히스토리
export
chatHistoryExample : List ChatMessage
chatHistoryExample =
  [ userMessageExample
  , assistantMessageExample
  , systemMessageExample
  ]

------------------------------------------------------------
-- 5. 워크플로우 진행률 예제
------------------------------------------------------------

export
initialProgressExample : WorkflowProgress
initialProgressExample = MkProgress
  InputPhase
  [ (InputPhase, PhaseCompleted)
  , (AnalysisPhase, PhaseNotStarted)
  , (SpecGenerationPhase, PhaseNotStarted)
  ]
  10  -- 10% 완료
  (Just 300)  -- 5분 남음

export
analysisProgressExample : WorkflowProgress
analysisProgressExample = MkProgress
  AnalysisPhase
  [ (InputPhase, PhaseCompleted)
  , (AnalysisPhase, PhaseInProgress)
  , (SpecGenerationPhase, PhaseNotStarted)
  , (CompilationPhase, PhaseNotStarted)
  ]
  25  -- 25% 완료
  (Just 240)  -- 4분 남음

export
completedProgressExample : WorkflowProgress
completedProgressExample = MkProgress
  FinalPhase
  [ (InputPhase, PhaseCompleted)
  , (AnalysisPhase, PhaseCompleted)
  , (SpecGenerationPhase, PhaseCompleted)
  , (CompilationPhase, PhaseCompleted)
  , (DocImplPhase, PhaseCompleted)
  , (DraftPhase, PhaseCompleted)
  , (FeedbackPhase, PhaseCompleted)
  , (RefinementPhase, PhaseCompleted)
  , (FinalPhase, PhaseCompleted)
  ]
  100  -- 100% 완료
  Nothing  -- 완료됨

------------------------------------------------------------
-- 6. 결과 미리보기 예제
------------------------------------------------------------

export
textPreviewExample : PreviewContent
textPreviewExample = MkPreview
  PreviewText
  "용역 계약서\n\n발주자: ㈜스피라티\n수주자: ㈜이츠에듀\n..."
  1  -- v1

export
markdownPreviewExample : PreviewContent
markdownPreviewExample = MkPreview
  PreviewMarkdown
  "# 용역 계약서\n\n**발주자**: ㈜스피라티\n**수주자**: ㈜이츠에듀\n..."
  2  -- v2

export
csvPreviewExample : PreviewContent
csvPreviewExample = MkPreview
  PreviewCSV
  "단계,일자,금액\n선급금,2025-10-01,15195000\n중도금,2025-11-15,20260000\n..."
  1  -- v1

------------------------------------------------------------
-- 7. 다운로드 상태 시나리오
------------------------------------------------------------

export
downloadReadyExample : DownloadStatus
downloadReadyExample = DownloadReady "/output/SpiratiContract.pdf"

export
downloadProgressExample : DownloadStatus
downloadProgressExample = DownloadInProgress 75  -- 75%

export
downloadCompleteExample : DownloadStatus
downloadCompleteExample = DownloadComplete

------------------------------------------------------------
-- 8. 사용자 액션 처리 예제
------------------------------------------------------------

-- 네비게이션 액션
export
navigationActions : List UserAction
navigationActions =
  [ NavigateTo HomeView
  , NavigateTo ProjectCreateView
  , NavigateTo (ProjectDetailView "MyProject")
  , GoBack
  ]

-- 프로젝트 관리 액션
export
projectActions : List UserAction
projectActions =
  [ CreateProject "NewProject" "Create a contract"
  , SelectProject "ExistingProject"
  , DeleteProject "OldProject"
  ]

-- 워크플로우 제어 액션
export
workflowActions : List UserAction
workflowActions =
  [ StartGeneration
  , PauseGeneration
  , CancelGeneration
  , RetryPhase CompilationPhase
  ]

-- 피드백 액션
export
feedbackActions : List UserAction
feedbackActions =
  [ SubmitFeedback "선급금을 30%로 변경해주세요"
  , ApproveDraft
  , RequestRevision "중도금 일자를 11/15로 수정"
  ]

------------------------------------------------------------
-- 9. 상태 전이 시나리오
------------------------------------------------------------

-- 프로젝트 생성 → 파일 업로드 → 생성 시작
export
fullWorkflowScenario : List (String, AppState)
fullWorkflowScenario =
  let
    -- Step 1: 초기 상태
    s0 = initialAppState

    -- Step 2: 프로젝트 생성
    s1 = createProjectExample "SpiratiContract"

    -- Step 3: 파일 업로드 시작
    s2 = case s1.selectedProject of
      Just proj => { selectedProject := Just ({ uploadStatus := UploadSelecting } proj) } s1
      Nothing => s1

    -- Step 4: 파일 업로드 중
    s3 = case s2.selectedProject of
      Just proj => { selectedProject := Just ({ uploadStatus := UploadInProgress 1 3 } proj) } s2
      Nothing => s2

    -- Step 5: 파일 업로드 완료
    s4 = case s3.selectedProject of
      Just proj => { selectedProject := Just ({ uploadStatus := UploadComplete 3 } proj) } s3
      Nothing => s3

    -- Step 6: 생성 시작
    s5 = case s4.selectedProject of
      Just proj => { selectedProject := Just ({ workflowProgress := analysisProgressExample } proj) } s4
      Nothing => s4

  in [ ("Initial", s0)
     , ("Project Created", s1)
     , ("Upload Selecting", s2)
     , ("Upload In Progress", s3)
     , ("Upload Complete", s4)
     , ("Generation Started", s5)
     ]

------------------------------------------------------------
-- 10. 뷰별 허용 액션 검증
------------------------------------------------------------

export
viewActionValidation : List (View, List UserAction)
viewActionValidation =
  [ (HomeView, allowedActions HomeView)
  , (ProjectCreateView, allowedActions ProjectCreateView)
  , (ProjectDetailView "Test", allowedActions (ProjectDetailView "Test"))
  , (ChatView "Test", allowedActions (ChatView "Test"))
  , (PreviewView "Test", allowedActions (PreviewView "Test"))
  , (DownloadView "Test", allowedActions (DownloadView "Test"))
  , (SettingsView, allowedActions SettingsView)
  ]

------------------------------------------------------------
-- 11. 에러 핸들링 예제
------------------------------------------------------------

export
errorExamples : List UIError
errorExamples =
  [ UINetworkError "Connection timeout"
  , UIValidationError "Invalid file format"
  , UIUploadError "File size exceeds limit"
  , UIWorkflowError "Compilation failed"
  , UIRenderError "PDF generation failed"
  , UIDownloadError "File not found"
  , UIUnknownError "Unexpected error occurred"
  ]

export
recoverableErrors : List (UIError, Bool)
recoverableErrors =
  map (\err => (err, isRecoverable err)) errorExamples

------------------------------------------------------------
-- 12. UI 컴포넌트 상태 예제
------------------------------------------------------------

export
buttonStates : List ButtonState
buttonStates =
  [ ButtonEnabled
  , ButtonDisabled
  , ButtonLoading
  , ButtonSuccess
  , ButtonError
  ]

export
inputStates : List InputState
inputStates =
  [ InputIdle
  , InputFocused
  , InputValidating
  , InputValid
  , InputInvalid "Invalid project name"
  ]

export
toastExamples : List Toast
toastExamples =
  [ MkToast ToastInfo "Processing your request" 3000
  , MkToast ToastSuccess "Project created successfully" 3000
  , MkToast ToastWarning "This action cannot be undone" 5000
  , MkToast ToastError "Failed to upload file" 5000
  ]

------------------------------------------------------------
-- 13. 반응형 레이아웃 예제
------------------------------------------------------------

export
responsiveLayoutExample : List (ScreenSize, LayoutMode)
responsiveLayoutExample =
  [ (Mobile, layoutForScreen Mobile)
  , (Tablet, layoutForScreen Tablet)
  , (Desktop, layoutForScreen Desktop)
  ]

------------------------------------------------------------
-- 14. Phase 표시 이름 예제
------------------------------------------------------------

export
phaseDisplayExamples : List (Phase, String)
phaseDisplayExamples =
  [ (InputPhase, phaseDisplayName InputPhase)
  , (AnalysisPhase, phaseDisplayName AnalysisPhase)
  , (SpecGenerationPhase, phaseDisplayName SpecGenerationPhase)
  , (CompilationPhase, phaseDisplayName CompilationPhase)
  , (DocImplPhase, phaseDisplayName DocImplPhase)
  , (DraftPhase, phaseDisplayName DraftPhase)
  , (FeedbackPhase, phaseDisplayName FeedbackPhase)
  , (RefinementPhase, phaseDisplayName RefinementPhase)
  , (FinalPhase, phaseDisplayName FinalPhase)
  ]

------------------------------------------------------------
-- 15. 다운로드 형식 변환 예제
------------------------------------------------------------

export
downloadFormatConversion : List (DownloadFormat, Maybe RequestedFormat)
downloadFormatConversion =
  [ (DownloadText, toRequestedFormat DownloadText)
  , (DownloadCSV, toRequestedFormat DownloadCSV)
  , (DownloadMarkdown, toRequestedFormat DownloadMarkdown)
  , (DownloadLaTeX, toRequestedFormat DownloadLaTeX)
  , (DownloadPDF, toRequestedFormat DownloadPDF)
  , (DownloadAll, toRequestedFormat DownloadAll)
  ]
