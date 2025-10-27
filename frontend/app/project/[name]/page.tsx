'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { getStatus, getDraft, submitFeedback, generateDraft, finalizePDF, downloadPDF, resumeProject, abortProject } from '@/lib/api'
import type { WorkflowStatus, DraftResponse } from '@/types/workflow'

export default function ProjectPage({ params }: { params: { name: string } }) {
  const projectName = params.name
  const router = useRouter()

  const [status, setStatus] = useState<WorkflowStatus | null>(null)
  const [draft, setDraft] = useState<DraftResponse | null>(null)
  const [feedback, setFeedback] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Recovery state
  const [showRecoveryUI, setShowRecoveryUI] = useState(false)
  const [updatedPrompt, setUpdatedPrompt] = useState('')
  const [restartFromAnalysis, setRestartFromAnalysis] = useState(false)

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

  const handleResume = async (withPromptUpdate: boolean = false) => {
    try {
      if (withPromptUpdate) {
        // 프롬프트 수정하는 경우
        await resumeProject(projectName, updatedPrompt || undefined, restartFromAnalysis)
        alert('🔄 프롬프트가 수정되었습니다. 백그라운드에서 재생성이 시작됩니다.')
      } else {
        // 그냥 재시도
        await resumeProject(projectName)
        alert('🔄 프로젝트 재시도가 시작되었습니다. 백그라운드에서 계속 진행됩니다.')
      }

      // Stay on current page to monitor progress (removed router.push('/projects'))
      // User can manually navigate back using "← 프로젝트 목록" button

      // Reload status immediately to show updated state
      const data = await getStatus(projectName)
      setStatus(data)
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message)
    }
  }

  const handleAbort = async () => {
    if (!confirm('⏸️ 정말로 실행을 중단하시겠습니까?\n\n중단 후에도 나중에 다시 재개할 수 있습니다.')) {
      return
    }

    try {
      await abortProject(projectName)
      alert('⏸️ 프로젝트 실행이 중단되었습니다.')
      // Reload status
      const data = await getStatus(projectName)
      setStatus(data)
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message)
    }
  }

  // Initialize updated prompt when showing recovery UI
  useEffect(() => {
    if (showRecoveryUI && status?.user_prompt) {
      setUpdatedPrompt(status.user_prompt)
    }
  }, [showRecoveryUI, status?.user_prompt])

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
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push('/projects')}
            className="btn btn-secondary text-sm"
          >
            ← 프로젝트 목록
          </button>
          {status.is_active && (
            <button
              onClick={handleAbort}
              className="btn btn-secondary text-sm"
            >
              ⏸️ 중단
            </button>
          )}
          <div className="text-sm text-gray-500">
            {status.completed ? '✅ 완료' : status.is_active ? '🔄 진행 중' : '⏸️ 대기 중'}
          </div>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="card">
        <h2 className="text-xl font-semibold mb-4">진행 상황</h2>

        {/* Backend Activity Indicator */}
        <div className="mb-4 p-3 bg-gray-50 rounded-lg border border-gray-200">
          <div className="flex items-center gap-3">
            <div className={`w-3 h-3 rounded-full ${
              status.is_active ? 'bg-green-500 animate-pulse' : 'bg-gray-400'
            }`} />
            <div className="flex-1">
              <div className="font-medium text-sm">
                {status.is_active ? '🟢 백엔드 작업 중' : '⚪ 백엔드 대기 중'}
              </div>
              {status.current_action && (
                <div className="text-xs text-gray-600 mt-1">
                  {status.current_action}
                </div>
              )}
              {status.last_activity && (
                <div className="text-xs text-gray-500 mt-1">
                  마지막 활동: {new Date(status.last_activity).toLocaleTimeString('ko-KR')}
                </div>
              )}
            </div>
          </div>
        </div>

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
                  의존 타입 검증 중 오류가 발생했습니다.
                </p>

                {/* Recovery Actions */}
                {!status.is_active && (
                  <div className="mt-4 flex gap-2">
                    <button
                      onClick={() => setShowRecoveryUI(!showRecoveryUI)}
                      className="btn btn-primary text-sm"
                    >
                      {showRecoveryUI ? '❌ 취소' : '📝 프롬프트 수정 후 재시도'}
                    </button>
                    <button
                      onClick={() => handleResume(false)}
                      className="btn btn-secondary text-sm"
                    >
                      ⚡ 그냥 재시도
                    </button>
                  </div>
                )}
                <p className="text-xs text-gray-600 mt-2">
                  💡 재시도를 시작하면 이 페이지에서 진행 상황을 모니터링할 수 있습니다.
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

            {/* Error Suggestion (동일 에러 3회 반복 시) */}
            {status.error_suggestion && (
              <div className="mt-4 p-4 bg-orange-50 border-2 border-orange-400 rounded-lg">
                <div className="flex items-start gap-2 mb-3">
                  <span className="text-2xl">⚠️</span>
                  <div className="flex-1">
                    <h4 className="font-bold text-orange-900 text-base mb-1">
                      {status.error_suggestion.message}
                    </h4>
                    <p className="text-sm text-orange-700 mb-3">
                      자동 수정이 어려워 보입니다. 다음 방법을 시도해보세요:
                    </p>
                    <ul className="space-y-2 mb-4">
                      {status.error_suggestion.suggestions.map((suggestion, idx) => (
                        <li key={idx} className="flex items-start gap-2 text-sm text-gray-800">
                          <span className="text-orange-500 font-bold">{idx + 1}.</span>
                          <span>{suggestion}</span>
                        </li>
                      ))}
                    </ul>
                    {status.error_suggestion.can_retry && (
                      <div className="flex gap-2">
                        <button
                          onClick={() => setShowRecoveryUI(true)}
                          className="btn btn-primary text-sm"
                        >
                          📝 프롬프트 수정하기
                        </button>
                        <button
                          onClick={() => handleResume(false)}
                          className="btn btn-secondary text-sm"
                        >
                          🔄 다시 시도하기
                        </button>
                      </div>
                    )}
                  </div>
                </div>
                {status.error_suggestion.error_preview && (
                  <details className="mt-3">
                    <summary className="cursor-pointer text-xs text-orange-700 font-medium">
                      에러 미리보기
                    </summary>
                    <pre className="mt-2 text-xs text-orange-800 bg-white p-2 rounded border border-orange-300 overflow-x-auto">
{status.error_suggestion.error_preview}
                    </pre>
                  </details>
                )}
              </div>
            )}

            {/* Recovery UI */}
            {showRecoveryUI && (
              <div className="mt-4 p-4 bg-white border-2 border-blue-300 rounded-lg">
                <h4 className="font-bold text-gray-900 mb-3">🛠️ 프롬프트 수정</h4>

                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    원래 프롬프트:
                  </label>
                  <textarea
                    value={updatedPrompt}
                    onChange={(e) => setUpdatedPrompt(e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-lg font-mono text-sm"
                    rows={8}
                    placeholder="프롬프트를 수정하세요..."
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    💡 팁: 더 구체적인 정보를 추가하거나, 금액/날짜 등을 명확히 하세요.
                  </p>
                </div>

                <div className="mb-4">
                  <label className="flex items-center gap-2 text-sm text-gray-700">
                    <input
                      type="checkbox"
                      checked={restartFromAnalysis}
                      onChange={(e) => setRestartFromAnalysis(e.target.checked)}
                      className="rounded"
                    />
                    분석 단계부터 재시작 (Phase 2부터 다시)
                  </label>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleResume(true)}
                    className="btn btn-primary"
                  >
                    ✅ 수정된 프롬프트로 재시작
                  </button>
                  <button
                    onClick={() => setShowRecoveryUI(false)}
                    className="btn btn-secondary"
                  >
                    취소
                  </button>
                </div>
                <p className="text-xs text-gray-500 mt-2">
                  * 재시작하면 백그라운드에서 작업이 진행되며, 이 페이지에서 모니터링할 수 있습니다.
                </p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Resume Button for Paused Projects (no error) */}
      {!status.completed && !status.is_active && !status.error && status.current_phase !== 'Phase 1: Input Collection' && (
        <div className="card bg-blue-50 border-2 border-blue-300">
          <div className="flex items-start gap-3">
            <span className="text-3xl">⏸️</span>
            <div className="flex-1">
              <h3 className="text-lg font-bold text-gray-900 mb-2">프로젝트 대기 중</h3>
              <p className="text-sm text-gray-700 mb-4">
                이 프로젝트는 {status.current_phase}에서 멈춰있습니다. 계속 진행하시겠습니까?
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => handleResume(false)}
                  className="btn btn-primary text-sm"
                >
                  🔄 계속 진행하기
                </button>
                <button
                  onClick={() => setShowRecoveryUI(!showRecoveryUI)}
                  className="btn btn-secondary text-sm"
                >
                  📝 프롬프트 수정 후 진행
                </button>
              </div>
              <p className="text-xs text-gray-600 mt-2">
                💡 진행을 시작하면 이 페이지에서 실시간으로 진행 상황을 확인할 수 있습니다.
              </p>
            </div>
          </div>

          {/* Recovery UI for paused projects */}
          {showRecoveryUI && (
            <div className="mt-4 p-4 bg-white border-2 border-blue-300 rounded-lg">
              <h4 className="font-bold text-gray-900 mb-3">🛠️ 프롬프트 수정</h4>

              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  프롬프트 수정:
                </label>
                <textarea
                  value={updatedPrompt}
                  onChange={(e) => setUpdatedPrompt(e.target.value)}
                  className="w-full p-3 border border-gray-300 rounded-lg font-mono text-sm"
                  rows={8}
                  placeholder="프롬프트를 수정하세요..."
                />
              </div>

              <div className="mb-4">
                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={restartFromAnalysis}
                    onChange={(e) => setRestartFromAnalysis(e.target.checked)}
                    className="rounded"
                  />
                  분석 단계부터 재시작 (Phase 2부터 다시)
                </label>
              </div>

              <div className="flex gap-2">
                <button
                  onClick={() => handleResume(true)}
                  className="btn btn-primary"
                >
                  ✅ 수정된 프롬프트로 재시작
                </button>
                <button
                  onClick={() => setShowRecoveryUI(false)}
                  className="btn btn-secondary"
                >
                  취소
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Workflow Phase Visualization */}
      <div className="card">
        <h2 className="text-xl font-semibold mb-4">워크플로우 단계</h2>
        <div className="space-y-3">
          {[
            { phase: 'Phase 1: Input Collection', emoji: '📥', key: 'Input' },
            { phase: 'Phase 2: Analysis', emoji: '🔍', key: 'Analysis' },
            { phase: 'Phase 3: Spec Generation', emoji: '📝', key: 'SpecGeneration' },
            { phase: 'Phase 4: Compilation', emoji: '⚙️', key: 'Compilation' },
            { phase: 'Phase 4b: Error Handling', emoji: '🔧', key: 'ErrorHandling' },
            { phase: 'Phase 5: Document Implementation', emoji: '📄', key: 'DocImpl' },
            { phase: 'Phase 6: Draft Generation', emoji: '✏️', key: 'Draft' },
            { phase: 'Phase 7: User Feedback', emoji: '💬', key: 'Feedback' },
            { phase: 'Phase 8: Refinement', emoji: '🔄', key: 'Refinement' },
            { phase: 'Phase 9: Finalization', emoji: '✅', key: 'Final' },
          ].map((item) => {
            const isCurrent = status.current_phase.includes(item.key) || status.current_phase === item.phase
            const isCompleted = status.progress > (item.phase.match(/\d+/)?.[0] ? parseInt(item.phase.match(/\d+/)![0]) / 10 : 0)

            return (
              <div
                key={item.phase}
                className={`flex items-center gap-3 p-3 rounded-lg border-2 transition-all ${
                  isCurrent
                    ? 'border-primary bg-blue-50 shadow-md'
                    : isCompleted
                    ? 'border-green-300 bg-green-50'
                    : 'border-gray-200 bg-gray-50'
                }`}
              >
                <div className={`text-2xl ${isCurrent ? 'animate-bounce' : ''}`}>
                  {item.emoji}
                </div>
                <div className="flex-1">
                  <div className={`font-medium ${isCurrent ? 'text-primary' : isCompleted ? 'text-green-700' : 'text-gray-600'}`}>
                    {item.phase}
                  </div>
                  {isCurrent && status.current_action && (
                    <div className="text-xs text-gray-600 mt-1">
                      {status.current_action}
                    </div>
                  )}
                </div>
                {isCurrent && (
                  <div className="text-primary font-bold text-sm">
                    ← 현재 단계
                  </div>
                )}
                {isCompleted && !isCurrent && (
                  <div className="text-green-600 text-sm">
                    ✓
                  </div>
                )}
              </div>
            )
          })}
        </div>
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
