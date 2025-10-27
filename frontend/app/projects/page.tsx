'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'

interface ProjectSummary {
  project_name: string
  current_phase: string
  progress: number
  completed: boolean
  has_error: boolean
  version: number
  is_active: boolean
  last_activity?: string
}

export default function ProjectsPage() {
  const [projects, setProjects] = useState<ProjectSummary[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchProjects = async () => {
      try {
        const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/projects`)
        const data = await response.json()
        setProjects(data.projects || [])
        setLoading(false)
      } catch (err: any) {
        setError(err.message)
        setLoading(false)
      }
    }

    fetchProjects()
    // Refresh every 5 seconds
    const interval = setInterval(fetchProjects, 5000)
    return () => clearInterval(interval)
  }, [])

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="text-4xl mb-4">⏳</div>
        <p className="text-gray-600">프로젝트 목록 로딩 중...</p>
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

  return (
    <div>
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">프로젝트 목록</h1>
        <Link href="/project/new" className="btn btn-primary">
          + 새 프로젝트
        </Link>
      </div>

      {projects.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-6xl mb-4">📁</div>
          <h2 className="text-2xl font-bold text-gray-700 mb-2">
            프로젝트가 없습니다
          </h2>
          <p className="text-gray-600 mb-6">
            새 프로젝트를 생성하여 문서 생성을 시작하세요
          </p>
          <Link href="/project/new" className="btn btn-primary">
            + 새 프로젝트 만들기
          </Link>
        </div>
      ) : (
        <div className="grid gap-4">
          {projects.map((project) => (
            <Link
              key={project.project_name}
              href={`/project/${project.project_name}`}
              className="card hover:shadow-lg transition-shadow cursor-pointer"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h2 className="text-xl font-bold text-gray-900">
                      {project.project_name}
                    </h2>
                    {project.is_active && (
                      <span className="flex items-center gap-1 text-xs px-2 py-1 bg-green-100 text-green-700 rounded-full">
                        <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                        작업 중
                      </span>
                    )}
                    {project.completed && (
                      <span className="text-xs px-2 py-1 bg-green-100 text-green-700 rounded-full">
                        ✅ 완료
                      </span>
                    )}
                    {project.has_error && !project.is_active && (
                      <span className="text-xs px-2 py-1 bg-red-100 text-red-700 rounded-full">
                        ⚠️ 에러
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-4 text-sm text-gray-600 mb-3">
                    <span>📍 {project.current_phase}</span>
                    <span>📦 v{project.version}</span>
                    {project.last_activity && (
                      <span>
                        🕒 {new Date(project.last_activity).toLocaleString('ko-KR')}
                      </span>
                    )}
                  </div>

                  {/* Progress Bar */}
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className={`h-2 rounded-full transition-all ${
                        project.has_error
                          ? 'bg-red-500'
                          : project.completed
                          ? 'bg-green-500'
                          : 'bg-blue-500'
                      }`}
                      style={{ width: `${project.progress * 100}%` }}
                    />
                  </div>
                  <div className="text-xs text-gray-500 mt-1">
                    진행률: {(project.progress * 100).toFixed(0)}%
                  </div>
                </div>

                <div className="ml-4">
                  {project.has_error && !project.is_active ? (
                    <button
                      onClick={(e) => {
                        e.preventDefault()
                        window.location.href = `/project/${project.project_name}`
                      }}
                      className="btn btn-secondary text-sm"
                    >
                      🔄 재시도
                    </button>
                  ) : (
                    <div className="text-gray-400 text-2xl">→</div>
                  )}
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
