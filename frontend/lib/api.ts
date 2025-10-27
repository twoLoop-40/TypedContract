/**
 * API Client for ScaleDeepSpec Backend
 * Backend API: http://localhost:8000
 */

import axios from 'axios'
import type {
  WorkflowStatus,
  ProjectInitRequest,
  DraftResponse,
  FeedbackRequest,
} from '@/types/workflow'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// ============================================================================
// Project Management
// ============================================================================

export async function getAllProjects() {
  // TODO: 백엔드에 GET /api/projects 엔드포인트 구현 필요
  // const response = await api.get('/api/projects')
  // return response.data

  // 임시: 빈 배열 반환
  return []
}

export async function createProject(data: ProjectInitRequest) {
  const response = await api.post('/api/project/init', data)
  return response.data
}

export async function uploadFiles(projectName: string, files: File[]) {
  const formData = new FormData()
  files.forEach((file) => {
    formData.append('files', file)
  })

  const response = await api.post(`/api/project/${projectName}/upload`, formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  })
  return response.data
}

// ============================================================================
// Workflow Execution
// ============================================================================

export async function startGeneration(projectName: string) {
  const response = await api.post(`/api/project/${projectName}/generate`)
  return response.data
}

export async function getStatus(projectName: string): Promise<WorkflowStatus> {
  const response = await api.get(`/api/project/${projectName}/status`)
  return response.data
}

// ============================================================================
// Draft & Feedback
// ============================================================================

export async function generateDraft(projectName: string) {
  const response = await api.post(`/api/project/${projectName}/draft`)
  return response.data
}

export async function getDraft(projectName: string): Promise<DraftResponse> {
  const response = await api.get(`/api/project/${projectName}/draft`)
  return response.data
}

export async function submitFeedback(projectName: string, feedback: string) {
  const data: FeedbackRequest = {
    project_name: projectName,
    feedback,
  }
  const response = await api.post(`/api/project/${projectName}/feedback`, data)
  return response.data
}

// ============================================================================
// Finalization
// ============================================================================

export async function finalizePDF(projectName: string) {
  const response = await api.post(`/api/project/${projectName}/finalize`)
  return response.data
}

export async function downloadPDF(projectName: string) {
  const response = await api.get(`/api/project/${projectName}/download`, {
    responseType: 'blob',
  })

  // Create download link
  const url = window.URL.createObjectURL(new Blob([response.data]))
  const link = document.createElement('a')
  link.href = url
  link.setAttribute('download', `${projectName}.pdf`)
  document.body.appendChild(link)
  link.click()
  link.remove()
}

// ============================================================================
// Health Check
// ============================================================================

export async function healthCheck() {
  const response = await api.get('/health')
  return response.data
}

export default api
