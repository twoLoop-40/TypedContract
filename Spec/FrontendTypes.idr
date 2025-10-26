module Spec.FrontendTypes

import Spec.WorkflowTypes
import Spec.AgentOperations
import Spec.RendererOperations

------------------------------------------------------------
-- 프론트엔드 타입 명세
-- 목적: UI 상태, 사용자 액션, 화면 구성을 타입으로 정의
-- 특징: TypeScript 구현의 가이드 역할
------------------------------------------------------------

------------------------------------------------------------
-- 1. 사용자 인터페이스 뷰 (View)
------------------------------------------------------------

public export
data View
  = HomeView                    -- 홈 화면 (프로젝트 목록)
  | ProjectCreateView           -- 프로젝트 생성 화면
  | ProjectDetailView ProjectName  -- 프로젝트 상세 (메인 작업 화면)
  | ChatView ProjectName        -- 채팅 인터페이스
  | PreviewView ProjectName     -- 결과 미리보기
  | DownloadView ProjectName    -- 다운로드 화면
  | SettingsView                -- 설정 화면

public export
Eq View where
  HomeView == HomeView = True
  ProjectCreateView == ProjectCreateView = True
  (ProjectDetailView n1) == (ProjectDetailView n2) = n1 == n2
  (ChatView n1) == (ChatView n2) = n1 == n2
  (PreviewView n1) == (PreviewView n2) = n1 == n2
  (DownloadView n1) == (DownloadView n2) = n1 == n2
  SettingsView == SettingsView = True
  _ == _ = False

public export
Show View where
  show HomeView = "Home"
  show ProjectCreateView = "Create Project"
  show (ProjectDetailView name) = "Project: " ++ name
  show (ChatView name) = "Chat: " ++ name
  show (PreviewView name) = "Preview: " ++ name
  show (DownloadView name) = "Download: " ++ name
  show SettingsView = "Settings"

------------------------------------------------------------
-- 2. 파일 업로드 상태
------------------------------------------------------------

public export
data UploadStatus
  = UploadIdle
  | UploadSelecting
  | UploadValidating
  | UploadInProgress Nat Nat
  | UploadComplete Nat
  | UploadError ErrorMsg

export
Show UploadStatus where
  show UploadIdle = "Ready to upload"
  show UploadSelecting = "Selecting files..."
  show UploadValidating = "Validating files..."
  show (UploadInProgress c t) = "Uploading " ++ show c ++ "/" ++ show t
  show (UploadComplete count) = "Uploaded " ++ show count ++ " files"
  show (UploadError msg) = "Upload failed: " ++ msg

-- 파일 정보
public export
record FileInfo where
  constructor MkFileInfo
  fileName : String
  fileSize : Nat            -- bytes
  fileType : String         -- MIME type
  filePath : FilePath

------------------------------------------------------------
-- 3. 채팅 메시지
------------------------------------------------------------

public export
data MessageRole
  = UserMessage
  | AssistantMessage
  | SystemMessage

public export
Eq MessageRole where
  UserMessage == UserMessage = True
  AssistantMessage == AssistantMessage = True
  SystemMessage == SystemMessage = True
  _ == _ = False

public export
Show MessageRole where
  show UserMessage = "User"
  show AssistantMessage = "Assistant"
  show SystemMessage = "System"

public export
record ChatMessage where
  constructor MkChatMessage
  messageId : String
  role : MessageRole
  content : String
  timestamp : String        -- ISO 8601 format

-- 채팅 상태
public export
data ChatStatus
  = ChatIdle
  | ChatTyping              -- 사용자 입력 중
  | ChatSending             -- 메시지 전송 중
  | ChatWaitingResponse     -- AI 응답 대기 중
  | ChatReceiving           -- AI 응답 수신 중
  | ChatError ErrorMsg

public export
Show ChatStatus where
  show ChatIdle = "Ready"
  show ChatTyping = "Typing..."
  show ChatSending = "Sending..."
  show ChatWaitingResponse = "Waiting for response..."
  show ChatReceiving = "Receiving..."
  show (ChatError msg) = "Error: " ++ msg

------------------------------------------------------------
-- 4. 워크플로우 진행 상황 UI
------------------------------------------------------------

-- Phase별 진행 상태
public export
data PhaseStatus
  = PhaseNotStarted
  | PhaseInProgress
  | PhaseCompleted
  | PhaseFailed ErrorMsg

public export
Show PhaseStatus where
  show PhaseNotStarted = "Not Started"
  show PhaseInProgress = "In Progress"
  show PhaseCompleted = "Completed"
  show (PhaseFailed msg) = "Failed: " ++ msg

-- 워크플로우 진행률
public export
record WorkflowProgress where
  constructor MkProgress
  currentPhase : Phase
  phaseStatuses : List (Phase, PhaseStatus)
  overallProgress : Nat     -- 0-100
  estimatedTimeRemaining : Maybe Nat  -- seconds

-- Phase별 UI 표시 정보
public export
phaseDisplayName : Phase -> String
phaseDisplayName InputPhase = "📥 Collecting Input"
phaseDisplayName AnalysisPhase = "🔍 Analyzing Documents"
phaseDisplayName SpecGenerationPhase = "📝 Generating Specification"
phaseDisplayName CompilationPhase = "⚙️ Compiling & Validating"
phaseDisplayName DocImplPhase = "📄 Implementing Document"
phaseDisplayName DraftPhase = "✏️ Creating Draft"
phaseDisplayName FeedbackPhase = "💬 Waiting for Feedback"
phaseDisplayName RefinementPhase = "🔧 Refining"
phaseDisplayName FinalPhase = "✅ Finalizing"

------------------------------------------------------------
-- 5. 결과 미리보기
------------------------------------------------------------

-- 미리보기 형식
public export
data PreviewFormat
  = PreviewText
  | PreviewMarkdown
  | PreviewCSV
  | PreviewTable            -- CSV를 테이블로 렌더링

public export
Eq PreviewFormat where
  PreviewText == PreviewText = True
  PreviewMarkdown == PreviewMarkdown = True
  PreviewCSV == PreviewCSV = True
  PreviewTable == PreviewTable = True
  _ == _ = False

public export
Show PreviewFormat where
  show PreviewText = "Text"
  show PreviewMarkdown = "Markdown"
  show PreviewCSV = "CSV"
  show PreviewTable = "Table"

-- 미리보기 내용
public export
record PreviewContent where
  constructor MkPreview
  format : PreviewFormat
  content : String
  version : Nat             -- 문서 버전 (v1, v2, ...)

-- 미리보기 상태
public export
data PreviewStatus
  = PreviewLoading
  | PreviewReady PreviewContent
  | PreviewError ErrorMsg

------------------------------------------------------------
-- 6. 다운로드 상태
------------------------------------------------------------

public export
data DownloadFormat
  = DownloadText
  | DownloadCSV
  | DownloadMarkdown
  | DownloadLaTeX
  | DownloadPDF
  | DownloadAll             -- 모든 포맷 zip

public export
Eq DownloadFormat where
  DownloadText == DownloadText = True
  DownloadCSV == DownloadCSV = True
  DownloadMarkdown == DownloadMarkdown = True
  DownloadLaTeX == DownloadLaTeX = True
  DownloadPDF == DownloadPDF = True
  DownloadAll == DownloadAll = True
  _ == _ = False

public export
Show DownloadFormat where
  show DownloadText = "Text (.txt)"
  show DownloadCSV = "CSV (.csv)"
  show DownloadMarkdown = "Markdown (.md)"
  show DownloadLaTeX = "LaTeX (.tex)"
  show DownloadPDF = "PDF (.pdf)"
  show DownloadAll = "All Formats (.zip)"

-- 다운로드 형식 → 렌더러 요청 형식 매핑
public export
toRequestedFormat : DownloadFormat -> Maybe RequestedFormat
toRequestedFormat DownloadText = Just RequestText
toRequestedFormat DownloadCSV = Just RequestCSV
toRequestedFormat DownloadMarkdown = Just RequestMarkdown
toRequestedFormat DownloadLaTeX = Just RequestLaTeX
toRequestedFormat DownloadPDF = Just RequestPDF
toRequestedFormat DownloadAll = Just RequestAll

public export
data DownloadStatus
  = DownloadIdle
  | DownloadPreparing       -- 파일 준비 중
  | DownloadReady FilePath  -- 다운로드 준비 완료
  | DownloadInProgress Nat  -- 다운로드 진행 중 (%)
  | DownloadComplete        -- 다운로드 완료
  | DownloadError ErrorMsg

------------------------------------------------------------
-- 7. 사용자 액션 (User Actions)
------------------------------------------------------------

public export
data UserAction
  -- Navigation
  = NavigateTo View
  | GoBack

  -- Project Management
  | CreateProject ProjectName UserPrompt
  | SelectProject ProjectName
  | DeleteProject ProjectName

  -- File Upload
  | SelectFiles
  | UploadFiles (List FileInfo)
  | CancelUpload

  -- Chat
  | SendChatMessage String
  | ClearChat

  -- Workflow Control
  | StartGeneration
  | PauseGeneration
  | CancelGeneration
  | RetryPhase Phase

  -- Feedback
  | SubmitFeedback String
  | ApproveDraft
  | RequestRevision String

  -- Preview
  | ChangePreviewFormat PreviewFormat
  | RefreshPreview

  -- Download
  | RequestDownload DownloadFormat
  | CancelDownload

  -- Settings
  | UpdateSettings (List (String, String))

------------------------------------------------------------
-- 8. 애플리케이션 상태 (App State)
------------------------------------------------------------

public export
record ProjectState where
  constructor MkProjectState
  projectName : ProjectName
  currentView : View
  workflowState : WorkflowState
  workflowProgress : WorkflowProgress
  uploadStatus : UploadStatus
  uploadedFiles : List FileInfo
  chatMessages : List ChatMessage
  chatStatus : ChatStatus
  previewStatus : PreviewStatus
  downloadStatus : DownloadStatus

-- 전체 앱 상태
public export
record AppState where
  constructor MkAppState
  currentView : View
  activeProject : Maybe ProjectName
  projects : List ProjectName
  selectedProject : Maybe ProjectState
  errorMessage : Maybe ErrorMsg
  isLoading : Bool

-- 초기 앱 상태
public export
initialAppState : AppState
initialAppState = MkAppState
  HomeView
  Nothing
  []
  Nothing
  Nothing
  False

-- 초기 프로젝트 상태
public export
initialProjectState : ProjectName -> ProjectState
initialProjectState name =
  let ws = initialState name "" []
  in MkProjectState
    name
    (ProjectDetailView name)
    ws
    (MkProgress InputPhase [] 0 Nothing)
    UploadIdle
    []
    []
    ChatIdle
    PreviewLoading
    DownloadIdle

------------------------------------------------------------
-- 9. 상태 전이 (State Transitions)
------------------------------------------------------------

-- 뷰 전환 가능 여부
public export
canNavigateTo : AppState -> View -> Bool
canNavigateTo state HomeView = True
canNavigateTo state ProjectCreateView = True
canNavigateTo state (ProjectDetailView name) =
  elem name state.projects
canNavigateTo state (ChatView name) =
  elem name state.projects
canNavigateTo state (PreviewView name) =
  elem name state.projects
canNavigateTo state (DownloadView name) =
  elem name state.projects
canNavigateTo state SettingsView = True

-- 파일 업로드 가능 여부
public export
canUploadFiles : ProjectState -> Bool
canUploadFiles project =
  case project.uploadStatus of
    UploadIdle => True
    UploadComplete _ => True
    _ => False

-- 생성 시작 가능 여부
public export
canStartGeneration : ProjectState -> Bool
canStartGeneration project =
  project.workflowState.currentPhase == InputPhase &&
  length project.uploadedFiles > 0

-- 피드백 제출 가능 여부
public export
canSubmitFeedback : ProjectState -> Bool
canSubmitFeedback project =
  project.workflowState.currentPhase == FeedbackPhase

-- 다운로드 가능 여부
public export
canDownload : ProjectState -> DownloadFormat -> Bool
canDownload project DownloadPDF =
  project.workflowState.currentPhase == FinalPhase &&
  project.workflowState.completed
canDownload project _ =
  project.workflowState.currentPhase == FeedbackPhase ||
  project.workflowState.currentPhase == FinalPhase

------------------------------------------------------------
-- 10. UI 이벤트 핸들링
------------------------------------------------------------

-- 액션 처리 결과
public export
data ActionResult
  = ActionSuccess AppState
  | ActionError ErrorMsg
  | ActionPending AppState  -- 비동기 작업 대기 중

-- 뷰에 따른 허용 액션
public export
allowedActions : View -> List UserAction
allowedActions HomeView =
  [NavigateTo ProjectCreateView, NavigateTo SettingsView]
allowedActions ProjectCreateView =
  [GoBack, SelectFiles]
allowedActions (ProjectDetailView name) =
  [ NavigateTo (ChatView name)
  , NavigateTo (PreviewView name)
  , NavigateTo (DownloadView name)
  , SelectFiles
  , StartGeneration
  ]
allowedActions (ChatView name) =
  [GoBack, SendChatMessage "", ClearChat]
allowedActions (PreviewView name) =
  [GoBack, ChangePreviewFormat PreviewText, RefreshPreview, SubmitFeedback ""]
allowedActions (DownloadView name) =
  [GoBack, RequestDownload DownloadPDF]
allowedActions SettingsView =
  [GoBack]

------------------------------------------------------------
-- 11. 에러 핸들링
------------------------------------------------------------

public export
data UIError
  = UINetworkError String
  | UIValidationError String
  | UIUploadError String
  | UIWorkflowError String
  | UIRenderError String
  | UIDownloadError String
  | UIUnknownError String

public export
Show UIError where
  show (UINetworkError msg) = "Network Error: " ++ msg
  show (UIValidationError msg) = "Validation Error: " ++ msg
  show (UIUploadError msg) = "Upload Error: " ++ msg
  show (UIWorkflowError msg) = "Workflow Error: " ++ msg
  show (UIRenderError msg) = "Render Error: " ++ msg
  show (UIDownloadError msg) = "Download Error: " ++ msg
  show (UIUnknownError msg) = "Unknown Error: " ++ msg

-- 에러 복구 가능 여부
public export
isRecoverable : UIError -> Bool
isRecoverable (UINetworkError _) = True
isRecoverable (UIUploadError _) = True
isRecoverable (UIDownloadError _) = True
isRecoverable _ = False

------------------------------------------------------------
-- 12. UI 컴포넌트 상태
------------------------------------------------------------

-- 버튼 상태
public export
data ButtonState
  = ButtonEnabled
  | ButtonDisabled
  | ButtonLoading
  | ButtonSuccess
  | ButtonError

-- 입력 필드 상태
public export
data InputState
  = InputIdle
  | InputFocused
  | InputValidating
  | InputValid
  | InputInvalid ErrorMsg

-- 모달 상태
public export
data ModalState
  = ModalClosed
  | ModalOpen String        -- 모달 제목

-- 토스트 알림
public export
data ToastType
  = ToastInfo
  | ToastSuccess
  | ToastWarning
  | ToastError

public export
record Toast where
  constructor MkToast
  toastType : ToastType
  message : String
  duration : Nat            -- milliseconds

------------------------------------------------------------
-- 13. 반응형 레이아웃
------------------------------------------------------------

public export
data ScreenSize
  = Mobile              -- < 640px
  | Tablet              -- 640-1024px
  | Desktop             -- > 1024px

public export
data LayoutMode
  = CompactLayout       -- 모바일용
  | NormalLayout        -- 태블릿용
  | WideLayout          -- 데스크톱용

public export
layoutForScreen : ScreenSize -> LayoutMode
layoutForScreen Mobile = CompactLayout
layoutForScreen Tablet = NormalLayout
layoutForScreen Desktop = WideLayout
