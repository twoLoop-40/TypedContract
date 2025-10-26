# ScaleDeepSpec Frontend (Next.js 14)

## Getting Started

### Docker로 실행 (권장)

```bash
# 프로젝트 루트에서
docker-compose up frontend
```

### 로컬 개발

```bash
# 의존성 설치
npm install

# 개발 서버 실행
npm run dev
```

Open http://localhost:3000

## 프로젝트 구조 (TODO)

```
frontend/
├── app/                    # Next.js 14 App Router
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Home page
│   ├── project/
│   │   └── [id]/page.tsx  # Project detail page
│   └── api/               # API routes (optional)
├── components/            # React components
│   ├── ui/               # UI primitives
│   ├── ProjectForm.tsx   # Project initialization form
│   ├── DraftPreview.tsx  # Draft preview component
│   └── FeedbackForm.tsx  # User feedback form
├── lib/                   # Utilities
│   ├── api.ts            # API client (axios)
│   └── store.ts          # State management (zustand)
├── public/               # Static assets
└── types/                # TypeScript types
    └── workflow.ts       # Workflow types matching Idris2 specs
```

## 주요 화면 (TODO)

1. **프로젝트 생성**: 프롬프트 입력 + 파일 업로드
2. **생성 진행률**: Phase별 진행 상태 표시
3. **초안 미리보기**: txt/md/csv 출력 미리보기
4. **피드백 제출**: 수정 요청 입력
5. **PDF 다운로드**: 최종 문서 다운로드

## API 통합

Backend API: http://localhost:8000

```typescript
// Example API call
const response = await axios.post('/api/project/init', {
  project_name: 'MyContract',
  user_prompt: '...',
  reference_docs: [...]
});
```

## 다음 단계

1. Next.js 14 초기 설정
2. UI 컴포넌트 구현 (shadcn/ui 추천)
3. API 클라이언트 구현
4. 상태 관리 구현 (zustand)
5. 워크플로우 UI 구현
