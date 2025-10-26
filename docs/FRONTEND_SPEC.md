# 프론트엔드 형식 명세

## 개요

이 문서는 ScaleDeepSpec 프론트엔드의 **완전한 타입 명세**입니다.
모든 UI 상태, 사용자 액션, 화면 구성이 **Idris2로 형식적으로 정의**되어 있습니다.

**목적**:
- TypeScript/React 구현의 가이드 제공
- 타입 안전성 보장
- 백엔드 API와의 타입 일관성 유지

**위치**: `Spec/FrontendTypes.idr`, `Spec/FrontendExample.idr`

---

## 전체 구조

```
Frontend
├── Views (7개 화면)
│   ├── HomeView
│   ├── ProjectCreateView
│   ├── ProjectDetailView
│   ├── ChatView
│   ├── PreviewView
│   ├── DownloadView
│   └── SettingsView
│
├── State (상태 관리)
│   ├── AppState (전역 상태)
│   └── ProjectState (프로젝트별 상태)
│
├── Actions (사용자 액션)
│   ├── Navigation (화면 전환)
│   ├── ProjectManagement (프로젝트 관리)
│   ├── FileUpload (파일 업로드)
│   ├── Chat (채팅)
│   ├── WorkflowControl (워크플로우 제어)
│   ├── Feedback (피드백)
│   ├── Preview (미리보기)
│   └── Download (다운로드)
│
└── Components (UI 컴포넌트 상태)
    ├── Button
    ├── Input
    ├── Modal
    └── Toast
```

---

## 1. 화면 (Views)

### 타입 정의 (Idris2)

```idris
data View
  = HomeView
  | ProjectCreateView
  | ProjectDetailView ProjectName
  | ChatView ProjectName
  | PreviewView ProjectName
  | DownloadView ProjectName
  | SettingsView
```

### TypeScript 구현

```typescript
type View =
  | { type: 'home' }
  | { type: 'project-create' }
  | { type: 'project-detail'; projectName: string }
  | { type: 'chat'; projectName: string }
  | { type: 'preview'; projectName: string }
  | { type: 'download'; projectName: string }
  | { type: 'settings' }
```

### 화면별 기능

| 화면 | 주요 기능 | 허용 액션 |
|------|----------|----------|
| **HomeView** | 프로젝트 목록 표시 | 프로젝트 생성, 설정 |
| **ProjectCreateView** | 새 프로젝트 생성 | 파일 선택, 뒤로가기 |
| **ProjectDetailView** | 메인 작업 화면 | 채팅, 미리보기, 다운로드, 파일 업로드, 생성 시작 |
| **ChatView** | AI와 대화 | 메시지 전송, 채팅 지우기, 뒤로가기 |
| **PreviewView** | 초안 미리보기 | 형식 변경, 새로고침, 피드백 제출, 뒤로가기 |
| **DownloadView** | 파일 다운로드 | 형식 선택, 다운로드 요청, 뒤로가기 |
| **SettingsView** | 설정 관리 | 설정 업데이트, 뒤로가기 |

---

## 2. 파일 업로드

### 업로드 상태 (Idris2)

```idris
data UploadStatus
  = UploadIdle              -- 대기 중
  | UploadSelecting         -- 파일 선택 중
  | UploadValidating        -- 검증 중
  | UploadInProgress Nat Nat  -- 진행 중 (현재/전체)
  | UploadComplete Nat      -- 완료 (파일 수)
  | UploadError ErrorMsg    -- 실패
```

### TypeScript 구현

```typescript
type UploadStatus =
  | { type: 'idle' }
  | { type: 'selecting' }
  | { type: 'validating' }
  | { type: 'in-progress'; current: number; total: number }
  | { type: 'complete'; count: number }
  | { type: 'error'; message: string }
```

### 파일 정보

```typescript
interface FileInfo {
  fileName: string
  fileSize: number      // bytes
  fileType: string      // MIME type
  filePath: string
}
```

### UI 예시

```tsx
function UploadProgress({ status }: { status: UploadStatus }) {
  switch (status.type) {
    case 'idle':
      return <div>파일을 선택하세요</div>
    case 'in-progress':
      return (
        <div>
          업로드 중: {status.current}/{status.total}
          <ProgressBar value={(status.current / status.total) * 100} />
        </div>
      )
    case 'complete':
      return <div>✅ {status.count}개 파일 업로드 완료</div>
    case 'error':
      return <div>❌ {status.message}</div>
    default:
      return null
  }
}
```

---

## 3. 채팅 인터페이스

### 메시지 타입 (Idris2)

```idris
data MessageRole = UserMessage | AssistantMessage | SystemMessage

record ChatMessage where
  constructor MkChatMessage
  messageId : String
  role : MessageRole
  content : String
  timestamp : String
```

### TypeScript 구현

```typescript
type MessageRole = 'user' | 'assistant' | 'system'

interface ChatMessage {
  messageId: string
  role: MessageRole
  content: string
  timestamp: string  // ISO 8601
}
```

### 채팅 상태

```typescript
type ChatStatus =
  | { type: 'idle' }
  | { type: 'typing' }
  | { type: 'sending' }
  | { type: 'waiting-response' }
  | { type: 'receiving' }
  | { type: 'error'; message: string }
```

### UI 예시

```tsx
function ChatInterface({ messages, status }: ChatProps) {
  return (
    <div className="chat-container">
      <div className="messages">
        {messages.map(msg => (
          <Message key={msg.messageId} message={msg} />
        ))}
      </div>

      {status.type === 'waiting-response' && <TypingIndicator />}

      <ChatInput disabled={status.type !== 'idle'} />
    </div>
  )
}
```

---

## 4. 워크플로우 진행 상황

### Phase 상태 (Idris2)

```idris
data PhaseStatus
  = PhaseNotStarted
  | PhaseInProgress
  | PhaseCompleted
  | PhaseFailed ErrorMsg

record WorkflowProgress where
  currentPhase : Phase
  phaseStatuses : List (Phase, PhaseStatus)
  overallProgress : Nat  -- 0-100
  estimatedTimeRemaining : Maybe Nat
```

### TypeScript 구현

```typescript
type PhaseStatus =
  | { type: 'not-started' }
  | { type: 'in-progress' }
  | { type: 'completed' }
  | { type: 'failed'; message: string }

interface WorkflowProgress {
  currentPhase: Phase
  phaseStatuses: Array<[Phase, PhaseStatus]>
  overallProgress: number  // 0-100
  estimatedTimeRemaining?: number  // seconds
}
```

### Phase 표시 이름

| Phase | 아이콘 | 한국어 이름 |
|-------|--------|------------|
| InputPhase | 📥 | 입력 수집 중 |
| AnalysisPhase | 🔍 | 문서 분석 중 |
| SpecGenerationPhase | 📝 | 명세 생성 중 |
| CompilationPhase | ⚙️ | 컴파일 및 검증 중 |
| DocImplPhase | 📄 | 문서 구현 중 |
| DraftPhase | ✏️ | 초안 생성 중 |
| FeedbackPhase | 💬 | 피드백 대기 중 |
| RefinementPhase | 🔧 | 개선 중 |
| FinalPhase | ✅ | 최종화 중 |

### UI 예시

```tsx
function PhaseProgress({ progress }: { progress: WorkflowProgress }) {
  return (
    <div className="workflow-progress">
      <div className="progress-bar">
        <div
          className="progress-fill"
          style={{ width: `${progress.overallProgress}%` }}
        />
      </div>

      <div className="phases">
        {progress.phaseStatuses.map(([phase, status]) => (
          <PhaseIndicator
            key={phase}
            phase={phase}
            status={status}
            current={phase === progress.currentPhase}
          />
        ))}
      </div>

      {progress.estimatedTimeRemaining && (
        <div className="eta">
          예상 소요 시간: {formatSeconds(progress.estimatedTimeRemaining)}
        </div>
      )}
    </div>
  )
}
```

---

## 5. 결과 미리보기

### 미리보기 형식 (Idris2)

```idris
data PreviewFormat
  = PreviewText
  | PreviewMarkdown
  | PreviewCSV
  | PreviewTable

record PreviewContent where
  format : PreviewFormat
  content : String
  version : Nat
```

### TypeScript 구현

```typescript
type PreviewFormat = 'text' | 'markdown' | 'csv' | 'table'

interface PreviewContent {
  format: PreviewFormat
  content: string
  version: number
}

type PreviewStatus =
  | { type: 'loading' }
  | { type: 'ready'; content: PreviewContent }
  | { type: 'error'; message: string }
```

### UI 예시

```tsx
function PreviewPane({ status }: { status: PreviewStatus }) {
  if (status.type === 'loading') {
    return <Spinner />
  }

  if (status.type === 'error') {
    return <ErrorMessage message={status.message} />
  }

  const { content } = status

  return (
    <div className="preview-pane">
      <div className="preview-header">
        <FormatSelector
          current={content.format}
          onChange={handleFormatChange}
        />
        <VersionBadge version={content.version} />
      </div>

      <div className="preview-content">
        {renderContent(content)}
      </div>
    </div>
  )
}

function renderContent(content: PreviewContent) {
  switch (content.format) {
    case 'text':
      return <pre>{content.content}</pre>
    case 'markdown':
      return <MarkdownRenderer source={content.content} />
    case 'csv':
      return <pre>{content.content}</pre>
    case 'table':
      return <CSVTable data={parseCSV(content.content)} />
  }
}
```

---

## 6. 다운로드

### 다운로드 형식 (Idris2)

```idris
data DownloadFormat
  = DownloadText
  | DownloadCSV
  | DownloadMarkdown
  | DownloadLaTeX
  | DownloadPDF
  | DownloadAll

data DownloadStatus
  = DownloadIdle
  | DownloadPreparing
  | DownloadReady FilePath
  | DownloadInProgress Nat  -- %
  | DownloadComplete
  | DownloadError ErrorMsg
```

### TypeScript 구현

```typescript
type DownloadFormat = 'text' | 'csv' | 'markdown' | 'latex' | 'pdf' | 'all'

type DownloadStatus =
  | { type: 'idle' }
  | { type: 'preparing' }
  | { type: 'ready'; filePath: string }
  | { type: 'in-progress'; percentage: number }
  | { type: 'complete' }
  | { type: 'error'; message: string }
```

### UI 예시

```tsx
function DownloadPanel({ status, onDownload }: DownloadPanelProps) {
  return (
    <div className="download-panel">
      <h3>다운로드</h3>

      <div className="format-selection">
        {['text', 'csv', 'markdown', 'latex', 'pdf', 'all'].map(format => (
          <Button
            key={format}
            onClick={() => onDownload(format)}
            disabled={status.type !== 'idle' && status.type !== 'ready'}
          >
            {formatLabel(format)}
          </Button>
        ))}
      </div>

      {status.type === 'ready' && (
        <a href={status.filePath} download>
          <Button variant="primary">📥 파일 다운로드</Button>
        </a>
      )}

      {status.type === 'in-progress' && (
        <ProgressBar value={status.percentage} />
      )}
    </div>
  )
}
```

---

## 7. 사용자 액션

### 액션 타입 (Idris2)

```idris
data UserAction
  = NavigateTo View
  | GoBack
  | CreateProject ProjectName UserPrompt
  | SelectProject ProjectName
  | DeleteProject ProjectName
  | SelectFiles
  | UploadFiles (List FileInfo)
  | CancelUpload
  | SendChatMessage String
  | ClearChat
  | StartGeneration
  | PauseGeneration
  | CancelGeneration
  | RetryPhase Phase
  | SubmitFeedback String
  | ApproveDraft
  | RequestRevision String
  | ChangePreviewFormat PreviewFormat
  | RefreshPreview
  | RequestDownload DownloadFormat
  | CancelDownload
  | UpdateSettings (List (String, String))
```

### TypeScript 구현

```typescript
type UserAction =
  // Navigation
  | { type: 'navigate-to'; view: View }
  | { type: 'go-back' }

  // Project Management
  | { type: 'create-project'; name: string; prompt: string }
  | { type: 'select-project'; name: string }
  | { type: 'delete-project'; name: string }

  // File Upload
  | { type: 'select-files' }
  | { type: 'upload-files'; files: FileInfo[] }
  | { type: 'cancel-upload' }

  // Chat
  | { type: 'send-chat-message'; content: string }
  | { type: 'clear-chat' }

  // Workflow Control
  | { type: 'start-generation' }
  | { type: 'pause-generation' }
  | { type: 'cancel-generation' }
  | { type: 'retry-phase'; phase: Phase }

  // Feedback
  | { type: 'submit-feedback'; feedback: string }
  | { type: 'approve-draft' }
  | { type: 'request-revision'; request: string }

  // Preview
  | { type: 'change-preview-format'; format: PreviewFormat }
  | { type: 'refresh-preview' }

  // Download
  | { type: 'request-download'; format: DownloadFormat }
  | { type: 'cancel-download' }

  // Settings
  | { type: 'update-settings'; settings: Record<string, string> }
```

---

## 8. 애플리케이션 상태

### AppState (전역 상태)

```typescript
interface AppState {
  currentView: View
  activeProject?: string
  projects: string[]
  selectedProject?: ProjectState
  errorMessage?: string
  isLoading: boolean
}
```

### ProjectState (프로젝트별 상태)

```typescript
interface ProjectState {
  projectName: string
  currentView: View
  workflowState: WorkflowState      // from Spec/WorkflowTypes
  workflowProgress: WorkflowProgress
  uploadStatus: UploadStatus
  uploadedFiles: FileInfo[]
  chatMessages: ChatMessage[]
  chatStatus: ChatStatus
  previewStatus: PreviewStatus
  downloadStatus: DownloadStatus
}
```

---

## 9. 상태 관리 (State Management)

### Zustand 예시

```typescript
import create from 'zustand'

interface AppStore extends AppState {
  // Actions
  navigate: (view: View) => void
  createProject: (name: string, prompt: string) => void
  selectProject: (name: string) => void
  uploadFiles: (files: FileInfo[]) => void
  sendMessage: (content: string) => void
  submitFeedback: (feedback: string) => void
  requestDownload: (format: DownloadFormat) => void
}

const useAppStore = create<AppStore>((set, get) => ({
  // Initial state
  currentView: { type: 'home' },
  projects: [],
  isLoading: false,

  // Actions
  navigate: (view) => set({ currentView: view }),

  createProject: async (name, prompt) => {
    set({ isLoading: true })
    try {
      const response = await api.post('/api/project/init', { name, prompt })
      set(state => ({
        projects: [...state.projects, name],
        activeProject: name,
        selectedProject: initializeProjectState(name),
        currentView: { type: 'project-detail', projectName: name },
        isLoading: false
      }))
    } catch (error) {
      set({ errorMessage: error.message, isLoading: false })
    }
  },

  // ... more actions
}))
```

---

## 10. API 통합

### API 클라이언트

```typescript
import axios from 'axios'

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'
})

export const projectAPI = {
  create: (data: { name: string; prompt: string }) =>
    api.post('/api/project/init', data),

  uploadFiles: (projectName: string, files: File[]) => {
    const formData = new FormData()
    files.forEach(file => formData.append('files', file))
    return api.post(`/api/project/${projectName}/upload`, formData)
  },

  startGeneration: (projectName: string) =>
    api.post(`/api/project/${projectName}/generate`),

  getStatus: (projectName: string) =>
    api.get<WorkflowProgress>(`/api/project/${projectName}/status`),

  getDraft: (projectName: string) =>
    api.get<DraftResponse>(`/api/project/${projectName}/draft`),

  submitFeedback: (projectName: string, feedback: string) =>
    api.post(`/api/project/${projectName}/feedback`, { feedback }),

  finalize: (projectName: string) =>
    api.post(`/api/project/${projectName}/finalize`),

  download: (projectName: string) =>
    api.get(`/api/project/${projectName}/download`, { responseType: 'blob' })
}
```

---

## 11. 에러 핸들링

### 에러 타입 (Idris2)

```idris
data UIError
  = UINetworkError String
  | UIValidationError String
  | UIUploadError String
  | UIWorkflowError String
  | UIRenderError String
  | UIDownloadError String
  | UIUnknownError String
```

### TypeScript 구현

```typescript
type UIError =
  | { type: 'network'; message: string; recoverable: true }
  | { type: 'validation'; message: string; recoverable: false }
  | { type: 'upload'; message: string; recoverable: true }
  | { type: 'workflow'; message: string; recoverable: false }
  | { type: 'render'; message: string; recoverable: false }
  | { type: 'download'; message: string; recoverable: true }
  | { type: 'unknown'; message: string; recoverable: false }

function isRecoverable(error: UIError): boolean {
  return error.recoverable
}
```

### 에러 처리 예시

```tsx
function ErrorBoundary({ error, onRetry }: ErrorBoundaryProps) {
  return (
    <div className="error-container">
      <h3>⚠️ 오류가 발생했습니다</h3>
      <p>{error.message}</p>

      {error.recoverable && (
        <Button onClick={onRetry}>🔄 재시도</Button>
      )}

      <Button onClick={() => window.location.href = '/'}>
        🏠 홈으로 돌아가기
      </Button>
    </div>
  )
}
```

---

## 12. UI 컴포넌트 상태

### Button 상태

```typescript
type ButtonState = 'enabled' | 'disabled' | 'loading' | 'success' | 'error'

<Button
  state={buttonState}
  onClick={handleClick}
>
  {buttonState === 'loading' ? <Spinner /> : '제출'}
</Button>
```

### Input 상태

```typescript
type InputState =
  | { type: 'idle' }
  | { type: 'focused' }
  | { type: 'validating' }
  | { type: 'valid' }
  | { type: 'invalid'; message: string }

<Input
  state={inputState}
  onChange={handleChange}
  errorMessage={inputState.type === 'invalid' ? inputState.message : undefined}
/>
```

### Toast 알림

```typescript
interface Toast {
  type: 'info' | 'success' | 'warning' | 'error'
  message: string
  duration: number  // ms
}

function showToast(toast: Toast) {
  // ... toast implementation
}

// Usage
showToast({ type: 'success', message: '프로젝트가 생성되었습니다', duration: 3000 })
```

---

## 13. 반응형 레이아웃

### 화면 크기

```typescript
type ScreenSize = 'mobile' | 'tablet' | 'desktop'
type LayoutMode = 'compact' | 'normal' | 'wide'

function getLayoutMode(screenSize: ScreenSize): LayoutMode {
  switch (screenSize) {
    case 'mobile': return 'compact'
    case 'tablet': return 'normal'
    case 'desktop': return 'wide'
  }
}

// Tailwind CSS 예시
<div className={`
  ${layoutMode === 'compact' ? 'flex-col' : 'flex-row'}
  ${layoutMode === 'wide' ? 'max-w-7xl' : 'max-w-4xl'}
`}>
  {/* content */}
</div>
```

---

## 14. 폴링 (Polling)

### 워크플로우 상태 폴링

```typescript
import { useEffect } from 'react'

function useWorkflowStatus(projectName: string) {
  const [progress, setProgress] = useState<WorkflowProgress | null>(null)

  useEffect(() => {
    let interval: NodeJS.Timeout

    if (projectName) {
      interval = setInterval(async () => {
        const response = await projectAPI.getStatus(projectName)
        setProgress(response.data)

        // 완료되면 폴링 중단
        if (response.data.overallProgress === 100) {
          clearInterval(interval)
        }
      }, 2000)  // 2초마다
    }

    return () => clearInterval(interval)
  }, [projectName])

  return progress
}
```

---

## 15. 전체 워크플로우 시나리오

### 사용자 여정

```
1. 홈 화면 (HomeView)
   ↓ 프로젝트 생성 버튼 클릭

2. 프로젝트 생성 (ProjectCreateView)
   ↓ 프로젝트 이름 + 프롬프트 입력

3. 파일 업로드
   ↓ PDF/DOCX 파일 선택 및 업로드

4. 생성 시작
   ↓ StartGeneration 액션

5. 워크플로우 진행 (ProjectDetailView)
   - InputPhase ✓
   - AnalysisPhase ... (진행 중)
   - SpecGenerationPhase (대기)
   - ...

6. 초안 완성 (PreviewView)
   ↓ Text/Markdown/CSV 미리보기

7-a. 피드백 제출 (수정 필요한 경우)
   ↓ SubmitFeedback 액션
   ↓ 다시 5번으로 (버전 증가: v1 → v2)

7-b. 초안 승인
   ↓ ApproveDraft 액션

8. PDF 생성 (DownloadView)
   ↓ RequestDownload 'pdf' 액션

9. 다운로드 완료
```

---

## 16. 참고 자료

- **Idris2 명세**: `Spec/FrontendTypes.idr`
- **사용 예제**: `Spec/FrontendExample.idr`
- **백엔드 API**: `agent/main.py`
- **워크플로우 명세**: `Spec/WorkflowTypes.idr`
- **렌더러 명세**: `Spec/RendererOperations.idr`

---

## 다음 단계

1. **Next.js 14 프로젝트 초기화**
   ```bash
   cd frontend
   npx create-next-app@latest . --typescript --tailwind --app
   ```

2. **상태 관리 라이브러리 설치**
   ```bash
   npm install zustand axios
   npm install @tanstack/react-query
   ```

3. **컴포넌트 구현 순서**
   - Layout 컴포넌트 (Navigation, Sidebar)
   - HomeView 구현
   - ProjectCreateView 구현
   - FileUploadComponent 구현
   - WorkflowProgressComponent 구현
   - ChatInterface 구현
   - PreviewPane 구현
   - DownloadPanel 구현

4. **API 통합**
   - API 클라이언트 구현
   - React Query 설정
   - Polling 구현

5. **에러 핸들링**
   - Error Boundary 구현
   - Toast 알림 구현
   - 재시도 로직 구현

6. **스타일링**
   - Tailwind CSS 커스텀 테마
   - 반응형 레이아웃
   - 다크 모드 지원

**완료 기준**: 모든 View와 UserAction이 구현되고, API와 통합되어 전체 워크플로우가 작동하는 상태
