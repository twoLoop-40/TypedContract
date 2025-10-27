'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createProject, uploadFiles, startGeneration } from '@/lib/api'

export default function NewProject() {
  const router = useRouter()
  const [step, setStep] = useState<'input' | 'uploading' | 'generating'>('input')
  const [formData, setFormData] = useState({
    projectName: '',
    userPrompt: '',
  })
  const [files, setFiles] = useState<File[]>([])
  const [error, setError] = useState<string | null>(null)

  // Validate project name (only alphanumeric and underscore)
  const validateProjectName = (name: string): boolean => {
    return /^[a-zA-Z0-9_]+$/.test(name)
  }

  const handleProjectNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value
    // Only allow valid characters
    if (value === '' || validateProjectName(value)) {
      setFormData({ ...formData, projectName: value })
      setError(null)
    } else {
      setError('프로젝트 이름은 영문, 숫자, 언더스코어(_)만 사용 가능합니다')
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    try {
      // Step 1: Create project
      await createProject({
        project_name: formData.projectName,
        user_prompt: formData.userPrompt,
        reference_docs: files.map((f) => f.name),
      })

      // Step 2: Upload files
      if (files.length > 0) {
        setStep('uploading')
        await uploadFiles(formData.projectName, files)
      }

      // Step 3: Start generation
      setStep('generating')
      await startGeneration(formData.projectName)

      // Redirect to project page
      router.push(`/project/${formData.projectName}`)
    } catch (err: any) {
      setError(err.response?.data?.detail || err.message || '프로젝트 생성 실패')
      setStep('input')
    }
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setFiles(Array.from(e.target.files))
    }
  }

  return (
    <div className="max-w-3xl mx-auto">
      <h1 className="text-3xl font-bold mb-8">새 프로젝트 생성</h1>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="card space-y-6">
        {/* Project Name */}
        <div>
          <label htmlFor="projectName" className="label">
            프로젝트 이름 *
          </label>
          <input
            id="projectName"
            type="text"
            className="input"
            value={formData.projectName}
            onChange={handleProjectNameChange}
            placeholder="예: scale_deep_contract"
            required
            disabled={step !== 'input'}
            pattern="[a-zA-Z0-9_]+"
            title="영문, 숫자, 언더스코어(_)만 사용 가능합니다"
          />
          <p className="mt-1 text-sm text-gray-500">
            ⚠️ 영문, 숫자, 언더스코어(_)만 사용 (한글 불가)
          </p>
        </div>

        {/* User Prompt */}
        <div>
          <label htmlFor="userPrompt" className="label">
            문서 생성 요청 *
          </label>
          <textarea
            id="userPrompt"
            className="input min-h-[150px]"
            value={formData.userPrompt}
            onChange={(e) => setFormData({ ...formData, userPrompt: e.target.value })}
            placeholder="예: 용역 계약서를 생성해주세요. 계약 금액은 5천만원, 기간은 2개월입니다..."
            required
            disabled={step !== 'input'}
          />
          <p className="mt-1 text-sm text-gray-500">
            생성할 문서의 목적, 내용, 조건 등을 자세히 설명해주세요
          </p>
        </div>

        {/* File Upload */}
        <div>
          <label htmlFor="files" className="label">
            참조 문서 (선택)
          </label>
          <input
            id="files"
            type="file"
            multiple
            className="input"
            onChange={handleFileChange}
            accept=".pdf,.txt,.md,.doc,.docx"
            disabled={step !== 'input'}
          />
          <p className="mt-1 text-sm text-gray-500">
            PDF, 텍스트, Word 문서 등을 업로드할 수 있습니다
          </p>
          {files.length > 0 && (
            <div className="mt-2 space-y-1">
              {files.map((file, idx) => (
                <div key={idx} className="text-sm text-gray-600">
                  📄 {file.name} ({(file.size / 1024).toFixed(1)} KB)
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Submit Button */}
        <div className="flex gap-4">
          <button
            type="submit"
            className="btn btn-primary flex-1"
            disabled={step !== 'input'}
          >
            {step === 'input' && '프로젝트 생성'}
            {step === 'uploading' && '파일 업로드 중...'}
            {step === 'generating' && '생성 시작 중...'}
          </button>
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => router.push('/')}
            disabled={step !== 'input'}
          >
            취소
          </button>
        </div>
      </form>

      {/* Info Section */}
      <div className="mt-8 card bg-blue-50">
        <h3 className="font-semibold mb-2">💡 생성 프로세스</h3>
        <ol className="text-sm text-gray-700 space-y-1 list-decimal list-inside">
          <li>AI 에이전트가 요청을 분석합니다</li>
          <li>Idris2 도메인 모델을 자동 생성합니다</li>
          <li>타입 체크 및 컴파일 검증 (최대 5회 재시도)</li>
          <li>txt/CSV/Markdown 초안을 생성합니다</li>
          <li>검토 후 피드백을 제출하여 수정 가능합니다</li>
        </ol>
      </div>
    </div>
  )
}
