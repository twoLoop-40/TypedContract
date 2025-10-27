'use client'

import { useState, useEffect } from 'react'
import { getStatus, getDraft, submitFeedback, generateDraft, finalizePDF, downloadPDF } from '@/lib/api'
import type { WorkflowStatus, DraftResponse } from '@/types/workflow'

export default function ProjectPage({ params }: { params: { name: string } }) {
  const projectName = params.name

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
            <div className="flex items-center gap-2">
              <span className="font-medium">{status.current_phase}</span>
              {/* Compilation retry indicator */}
              {status.current_phase.includes('Compilation') && status.error && (
                <span className="text-xs px-2 py-0.5 bg-yellow-100 text-yellow-700 rounded">
                  🔄 자동 수정 시도 중...
                </span>
              )}
              {/* Error handling indicator */}
              {status.current_phase.includes('ErrorHandling') && (
                <span className="text-xs px-2 py-0.5 bg-orange-100 text-orange-700 rounded">
                  🔍 에러 분석 중...
                </span>
              )}
            </div>
            <span className="text-gray-600">{(status.progress * 100).toFixed(0)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-3">
            <div
              className={`h-3 rounded-full transition-all duration-500 ${
                status.error ? 'bg-yellow-500' : 'bg-primary'
              }`}
              style={{ width: `${status.progress * 100}%` }}
            />
          </div>
        </div>

        {status.error && (
          <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded">
            <div className="flex items-start gap-2 mb-2">
              <span className="text-red-600 text-xl">⚠️</span>
              <div className="flex-1">
                <strong className="text-red-800 text-base">Idris2 타입 체크 오류</strong>
                <p className="text-sm text-red-600 mt-1">
                  의존 타입 검증 중 오류가 발생했습니다. 에이전트가 자동으로 수정을 시도합니다.
                </p>

                {/* Error Classification Info */}
                {status.classified_error && (
                  <div className="mt-3 p-3 bg-white rounded border border-red-300">
                    <div className="text-sm space-y-2">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-gray-700">에러 레벨:</span>
                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                          status.classified_error.level === 'AutoFixable' ? 'bg-yellow-200 text-yellow-800' :
                          status.classified_error.level === 'LogicError' ? 'bg-orange-200 text-orange-800' :
                          'bg-red-200 text-red-800'
                        }`}>
                          {status.classified_error.level === 'AutoFixable' ? '🔧 자동 수정 가능' :
                           status.classified_error.level === 'LogicError' ? '⚠️ 논리 에러' :
                           '🚫 도메인 모델 에러'}
                        </span>
                      </div>
                      {status.error_strategy && (
                        <div>
                          <span className="font-semibold text-gray-700">처리 전략:</span>{' '}
                          <span className="text-gray-900">{status.error_strategy}</span>
                        </div>
                      )}
                      {status.classified_error.level === 'AutoFixable' && (
                        <div className="text-xs text-gray-600 bg-yellow-50 p-2 rounded">
                          💡 Claude가 자동으로 코드를 수정하고 있습니다. 최대 5회 재시도합니다.
                        </div>
                      )}
                      {status.classified_error.level === 'LogicError' && (
                        <div className="text-xs text-gray-600 bg-orange-50 p-2 rounded">
                          💡 데이터 검증이 필요할 수 있습니다. 입력값을 확인해주세요.
                        </div>
                      )}
                      {status.classified_error.level === 'DomainModelError' && (
                        <div className="text-xs text-gray-600 bg-red-50 p-2 rounded">
                          💡 요구사항을 다시 분석해야 할 수 있습니다. 프롬프트를 수정하거나 참조 문서를 추가해보세요.
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            </div>
            <details className="mt-3">
              <summary className="cursor-pointer text-sm text-red-700 font-medium hover:text-red-900">
                📋 상세 오류 메시지 보기
              </summary>
              <pre className="mt-2 text-xs text-red-800 bg-red-100 p-3 rounded overflow-x-auto border border-red-300">
{status.error}
              </pre>
            </details>
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
