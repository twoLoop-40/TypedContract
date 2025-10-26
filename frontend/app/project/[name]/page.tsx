'use client'

import { use, useState, useEffect } from 'react'
import { getStatus, getDraft, submitFeedback, generateDraft, finalizePDF, downloadPDF } from '@/lib/api'
import type { WorkflowStatus, DraftResponse } from '@/types/workflow'

export default function ProjectPage({ params }: { params: Promise<{ name: string }> }) {
  const resolvedParams = use(params)
  const projectName = resolvedParams.name

  const [status, setStatus] = useState<WorkflowStatus | null>(null)
  const [draft, setDraft] = useState<DraftResponse | null>(null)
  const [feedback, setFeedback] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Poll status every 3 seconds
  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const data = await getStatus(projectName)
        setStatus(data)
        setLoading(false)

        // If draft phase, try to fetch draft
        if (data.current_phase.includes('Draft') && !draft) {
          try {
            const draftData = await getDraft(projectName)
            setDraft(draftData)
          } catch (e) {
            // Draft not ready yet
          }
        }
      } catch (err: any) {
        setError(err.response?.data?.detail || err.message)
        setLoading(false)
      }
    }

    fetchStatus()
    const interval = setInterval(fetchStatus, 3000)

    return () => clearInterval(interval)
  }, [projectName, draft])

  const handleGenerateDraft = async () => {
    try {
      await generateDraft(projectName)
      // Reload status
      const data = await getStatus(projectName)
      setStatus(data)
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message)
    }
  }

  const handleSubmitFeedback = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!feedback.trim()) return

    try {
      await submitFeedback(projectName, feedback)
      setFeedback('')
      alert('피드백이 제출되었습니다. 재생성이 시작됩니다.')
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message)
    }
  }

  const handleFinalize = async () => {
    try {
      await finalizePDF(projectName)
      alert('PDF 생성이 완료되었습니다!')
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message)
    }
  }

  const handleDownload = async () => {
    try {
      await downloadPDF(projectName)
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message)
    }
  }

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="text-4xl mb-4">⏳</div>
        <p className="text-gray-600">프로젝트 로딩 중...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="card bg-red-50">
        <h2 className="text-xl font-bold text-red-800 mb-2">오류 발생</h2>
        <p className="text-red-600">{error}</p>
      </div>
    )
  }

  if (!status) return null

  return (
    <div className="space-y-8">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">{projectName}</h1>
        <div className="text-sm text-gray-500">
          {status.completed ? '✅ 완료' : '🔄 진행 중'}
        </div>
      </div>

      {/* Progress Bar */}
      <div className="card">
        <h2 className="text-xl font-semibold mb-4">진행 상황</h2>
        <div className="mb-4">
          <div className="flex justify-between text-sm mb-2">
            <span className="font-medium">{status.current_phase}</span>
            <span className="text-gray-600">{(status.progress * 100).toFixed(0)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-3">
            <div
              className="bg-primary h-3 rounded-full transition-all duration-500"
              style={{ width: `${status.progress * 100}%` }}
            />
          </div>
        </div>

        {status.error && (
          <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded text-red-800 text-sm">
            <strong>컴파일 오류:</strong><br />
            <pre className="mt-2 text-xs overflow-x-auto">{status.error}</pre>
          </div>
        )}
      </div>

      {/* Draft Section */}
      {status.current_phase.includes('DocImpl') && !draft && (
        <div className="card">
          <h2 className="text-xl font-semibold mb-4">초안 생성</h2>
          <p className="text-gray-600 mb-4">
            컴파일이 완료되었습니다. 초안(txt/CSV/Markdown)을 생성하세요.
          </p>
          <button onClick={handleGenerateDraft} className="btn btn-primary">
            초안 생성하기
          </button>
        </div>
      )}

      {draft && (
        <div className="card space-y-6">
          <h2 className="text-xl font-semibold">초안 미리보기</h2>

          {/* Text Draft */}
          {draft.text_content && (
            <div>
              <h3 className="font-semibold mb-2">📄 Text Format</h3>
              <pre className="bg-gray-50 p-4 rounded border text-sm overflow-x-auto max-h-96">
                {draft.text_content}
              </pre>
            </div>
          )}

          {/* Markdown Draft */}
          {draft.markdown_content && (
            <div>
              <h3 className="font-semibold mb-2">📝 Markdown Format</h3>
              <pre className="bg-gray-50 p-4 rounded border text-sm overflow-x-auto max-h-96">
                {draft.markdown_content}
              </pre>
            </div>
          )}

          {/* CSV Draft */}
          {draft.csv_content && (
            <div>
              <h3 className="font-semibold mb-2">📊 CSV Format</h3>
              <pre className="bg-gray-50 p-4 rounded border text-sm overflow-x-auto max-h-96">
                {draft.csv_content}
              </pre>
            </div>
          )}
        </div>
      )}

      {/* Feedback Section */}
      {draft && !status.completed && (
        <div className="card">
          <h2 className="text-xl font-semibold mb-4">피드백 제출</h2>
          <form onSubmit={handleSubmitFeedback} className="space-y-4">
            <textarea
              className="input min-h-[120px]"
              value={feedback}
              onChange={(e) => setFeedback(e.target.value)}
              placeholder="수정 요청 사항을 입력하세요. 예: 금액을 6천만원으로 변경해주세요."
            />
            <div className="flex gap-4">
              <button type="submit" className="btn btn-primary">
                피드백 제출 (재생성)
              </button>
              <button type="button" onClick={handleFinalize} className="btn btn-secondary">
                현재 버전으로 확정
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Download Section */}
      {status.completed && (
        <div className="card bg-green-50">
          <h2 className="text-xl font-semibold mb-4">✅ 생성 완료!</h2>
          <p className="text-gray-700 mb-4">
            최종 문서를 다운로드할 수 있습니다.
          </p>
          <button onClick={handleDownload} className="btn btn-primary">
            📥 PDF 다운로드
          </button>
        </div>
      )}
    </div>
  )
}
