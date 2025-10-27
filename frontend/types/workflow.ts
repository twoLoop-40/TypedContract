/**
 * Frontend TypeScript types matching Spec/WorkflowTypes.idr
 */

export type Phase =
  | 'InputPhase'
  | 'AnalysisPhase'
  | 'SpecGenerationPhase'
  | 'CompilationPhase'
  | 'ErrorHandlingPhase'  // Phase 4b 추가
  | 'DocImplPhase'
  | 'DraftPhase'
  | 'FeedbackPhase'
  | 'RefinementPhase'
  | 'FinalPhase'

export type ErrorLevel = 'AutoFixable' | 'LogicError' | 'DomainModelError' | 'unknown'

export type UserAction = 'retry' | 'fallback' | 'reanalyze' | 'manual' | 'abort'

export interface ClassifiedError {
  level: ErrorLevel
  message: string
  location: string | null
  suggestion: string
  available_actions: UserAction[]
  auto_fixable: boolean
}

export interface ErrorSuggestion {
  reason: string  // "identical_error_3x"
  message: string
  suggestions: string[]
  error_preview: string
  can_retry: boolean
}

export interface WorkflowStatus {
  project_name: string
  current_phase: string
  progress: number  // 0.0 ~ 1.0
  completed: boolean
  is_active: boolean  // 백엔드가 현재 작업 중인지
  last_activity?: string | null  // 마지막 활동 시간 (ISO format)
  current_action?: string | null  // 현재 수행 중인 작업
  user_prompt?: string | null  // 원래 사용자 프롬프트
  error?: string | null
  classified_error?: ClassifiedError | null
  error_strategy?: string | null
  error_suggestion?: ErrorSuggestion | null  // 동일 에러 3회 시 제안
  available_actions?: UserAction[] | null
  logs?: string[]  // 실시간 로그
}

export interface ProjectInitRequest {
  project_name: string
  user_prompt: string
  reference_docs: string[]
}

export interface DraftResponse {
  project_name: string
  text_content?: string | null
  markdown_content?: string | null
  csv_content?: string | null
}

export interface FeedbackRequest {
  project_name: string
  feedback: string
}

export interface ApiResponse<T = any> {
  data?: T
  error?: string
}
