'use client'

import Link from 'next/link'
import { useState, useEffect } from 'react'

export default function Home() {
  const [apiStatus, setApiStatus] = useState<'checking' | 'online' | 'offline'>('checking')

  useEffect(() => {
    // API 상태 확인
    fetch(`${process.env.NEXT_PUBLIC_API_URL}/health`)
      .then(() => setApiStatus('online'))
      .catch(() => setApiStatus('offline'))
  }, [])

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <div className="text-center space-y-4">
        <h1 className="text-4xl font-bold text-gray-900">
          고정밀 문서 생성 시스템
        </h1>
        <p className="text-xl text-gray-600 max-w-2xl mx-auto">
          Idris2 의존 타입으로 정확성이 보장된 계약서와 문서를 자동으로 생성합니다
        </p>

        {/* API 상태 표시 */}
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gray-100">
          <div className={`w-2 h-2 rounded-full ${
            apiStatus === 'online' ? 'bg-green-500' :
            apiStatus === 'offline' ? 'bg-red-500' :
            'bg-yellow-500 animate-pulse'
          }`} />
          <span className="text-sm text-gray-700">
            Backend API: {
              apiStatus === 'online' ? 'Online' :
              apiStatus === 'offline' ? 'Offline' :
              'Checking...'
            }
          </span>
        </div>
      </div>

      {/* CTA Section */}
      <div className="flex justify-center gap-4">
        <Link href="/project/new" className="btn btn-primary text-lg px-8 py-3">
          새 프로젝트 시작
        </Link>
        <Link href="/projects" className="btn btn-secondary text-lg px-8 py-3">
          프로젝트 목록
        </Link>
      </div>

      {/* Features Grid */}
      <div className="grid md:grid-cols-3 gap-6 mt-12">
        <FeatureCard
          icon="🎯"
          title="고정밀 검증"
          description="Idris2 의존 타입으로 금액, 날짜, 수량 등의 정확성을 수학적으로 증명합니다"
        />
        <FeatureCard
          icon="🔄"
          title="피드백 루프"
          description="초안 검토 후 피드백을 제출하면 자동으로 수정된 문서를 재생성합니다"
        />
        <FeatureCard
          icon="📄"
          title="다중 포맷"
          description="가벼운 txt/CSV로 빠르게 검토하고, 최종 확정 시 PDF를 다운로드합니다"
        />
      </div>

      {/* Workflow Steps */}
      <div className="card mt-12">
        <h2 className="text-2xl font-bold mb-6">생성 프로세스</h2>
        <div className="space-y-4">
          <WorkflowStep number={1} title="입력" description="프롬프트와 참조 문서 업로드" />
          <WorkflowStep number={2} title="분석" description="AI 에이전트가 문서 분석" />
          <WorkflowStep number={3} title="명세 생성" description="Idris2 도메인 모델 자동 생성" />
          <WorkflowStep number={4} title="컴파일" description="타입 체크 및 검증 (최대 5회 재시도)" />
          <WorkflowStep number={5} title="초안" description="txt/CSV/Markdown 생성" />
          <WorkflowStep number={6} title="피드백" description="사용자 검토 및 수정 요청" />
          <WorkflowStep number={7} title="최종" description="PDF 다운로드" />
        </div>
      </div>
    </div>
  )
}

function FeatureCard({ icon, title, description }: { icon: string; title: string; description: string }) {
  return (
    <div className="card text-center">
      <div className="text-4xl mb-4">{icon}</div>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-sm text-gray-600">{description}</p>
    </div>
  )
}

function WorkflowStep({ number, title, description }: { number: number; title: string; description: string }) {
  return (
    <div className="flex items-start gap-4">
      <div className="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-semibold">
        {number}
      </div>
      <div>
        <h4 className="font-semibold">{title}</h4>
        <p className="text-sm text-gray-600">{description}</p>
      </div>
    </div>
  )
}
