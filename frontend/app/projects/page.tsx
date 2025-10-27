'use client'

import Link from 'next/link'
import { useState, useEffect } from 'react'
import { getAllProjects } from '@/lib/api'

interface ProjectInfo {
  name: string
  status: string
  progress: number
  lastUpdated: string
}

export default function ProjectsPage() {
  const [projects, setProjects] = useState<ProjectInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchProjects = async () => {
      try {
        // TODO: 백엔드에 프로젝트 목록 API 구현 필요
        const data = await getAllProjects()
        setProjects(data)
        setLoading(false)
      } catch (err: any) {
        setError(err.message)
        setLoading(false)
      }
    }

    fetchProjects()
  }, [])

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="text-4xl mb-4">⏳</div>
        <p className="text-gray-600">프로젝트 목록 로딩 중...</p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">프로젝트 목록</h1>
        <Link href="/project/new" className="btn btn-primary">
          + 새 프로젝트
        </Link>
      </div>

      {error && (
        <div className="card bg-yellow-50 border-yellow-200">
          <p className="text-yellow-800">⚠️ {error}</p>
        </div>
      )}

      {projects.length === 0 ? (
        <div className="card text-center py-12">
          <div className="text-6xl mb-4">📁</div>
          <h2 className="text-2xl font-semibold mb-2">프로젝트가 없습니다</h2>
          <p className="text-gray-600 mb-6">
            새 프로젝트를 만들어 문서 생성을 시작하세요!
          </p>
          <Link href="/project/new" className="btn btn-primary inline-block">
            첫 프로젝트 만들기
          </Link>
        </div>
      ) : (
        <div className="grid gap-4">
          {projects.map((project) => (
            <Link
              key={project.name}
              href={`/project/${project.name}`}
              className="card hover:shadow-md transition-shadow"
            >
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-xl font-semibold mb-1">{project.name}</h3>
                  <p className="text-sm text-gray-500">
                    마지막 업데이트: {project.lastUpdated}
                  </p>
                </div>
                <span className="px-3 py-1 bg-blue-100 text-blue-800 text-sm rounded-full">
                  {project.status}
                </span>
              </div>

              {/* Progress Bar */}
              <div className="mb-2">
                <div className="flex justify-between text-xs text-gray-600 mb-1">
                  <span>진행률</span>
                  <span>{(project.progress * 100).toFixed(0)}%</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-primary h-2 rounded-full transition-all"
                    style={{ width: `${project.progress * 100}%` }}
                  />
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}

      {/* Info Card */}
      <div className="card bg-blue-50 border-blue-200">
        <h3 className="font-semibold mb-2">💡 참고</h3>
        <ul className="text-sm text-gray-700 space-y-1">
          <li>• 프로젝트 목록은 백엔드에서 자동으로 관리됩니다</li>
          <li>• 각 프로젝트의 상태는 실시간으로 업데이트됩니다</li>
          <li>• 완료된 프로젝트의 PDF는 언제든지 다시 다운로드 가능합니다</li>
        </ul>
      </div>
    </div>
  )
}
