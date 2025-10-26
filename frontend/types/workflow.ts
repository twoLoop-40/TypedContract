/**
 * Frontend TypeScript types matching Spec/WorkflowTypes.idr
 */

export type Phase =
  | 'InputPhase'
  | 'AnalysisPhase'
  | 'SpecGenerationPhase'
  | 'CompilationPhase'
  | 'DocImplPhase'
  | 'DraftPhase'
  | 'FeedbackPhase'
  | 'RefinementPhase'
  | 'FinalPhase'

export interface WorkflowStatus {
  project_name: string
  current_phase: string
  progress: number  // 0.0 ~ 1.0
  completed: boolean
  error?: string | null
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
