import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'ScaleDeepSpec - 고정밀 문서 생성',
  description: 'Idris2 기반 형식 명세 문서 생성 시스템',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ko">
      <body className="min-h-screen bg-gray-50">
        <header className="bg-white shadow-sm border-b">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex justify-between items-center">
              <h1 className="text-2xl font-bold text-gray-900">
                ScaleDeepSpec
              </h1>
              <p className="text-sm text-gray-600">
                고정밀 문서 생성 시스템
              </p>
            </div>
          </div>
        </header>
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {children}
        </main>
      </body>
    </html>
  )
}
