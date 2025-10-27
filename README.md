# TypedContract

**Type-safe contract and document generation system** powered by Idris2 dependent types and Claude AI.

## 🌟 개요

TypedContract는 의존 타입(Dependent Types)을 사용하여 **컴파일 타임에 문서 정확성을 보장**하는 계약서/문서 생성 시스템입니다.

### 핵심 특징

- ✅ **타입 안정성**: Idris2 의존 타입으로 금액 계산, 날짜 검증 등을 컴파일 타임에 보장
- 🤖 **AI 기반 생성**: Claude API를 통해 자연어 프롬프트에서 Idris2 코드 자동 생성
- 📝 **다중 출력 포맷**: LaTeX/PDF, Markdown, CSV, Plain Text 지원
- 🔄 **자동 복구**: 에러 발생 시 자동 분류 및 재시도 (3회 반복 시 사용자 개입)
- 🎯 **MCP 통합**: Idris2 가이드라인을 MCP 서버로 제공하여 코드 품질 향상

---

## 📋 사전 요구사항

### 필수

- **Docker & Docker Compose** (권장) 또는:
  - Idris2 v0.7.0+
  - Python 3.11+
  - LaTeX (PDF 생성용)

### API 키

- **Anthropic API Key** (Claude Sonnet 4.5)
  - `.env` 파일에 `ANTHROPIC_API_KEY=sk-ant-...` 설정

---

## 🚀 빠른 시작 (Docker 사용)

### 1. 환경 설정

```bash
# 저장소 클론
git clone https://github.com/your-username/TypedContract.git
cd TypedContract

# .env 파일 생성 및 API 키 설정
cp .env.example .env
# .env 파일을 열어서 ANTHROPIC_API_KEY 설정
```

### 2. Docker로 실행

```bash
# 백엔드 빌드 및 실행 (최초 5-10분 소요 - Idris2 빌드)
docker-compose up -d backend

# 로그 확인
docker-compose logs -f backend

# 서버 확인 (http://localhost:8000)
curl http://localhost:8000/health
```

### 3. 프로젝트 생성 및 실행

```bash
# 1. 프로젝트 초기화
curl -X POST "http://localhost:8000/api/project/init" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "my_contract",
    "user_prompt": "간단한 용역 계약서. 발주: A사, 수주: B사, 금액: 1000만원",
    "reference_docs": []
  }'

# 2. 문서 생성 시작
curl -X POST "http://localhost:8000/api/project/my_contract/generate"

# 3. 진행 상황 확인
curl "http://localhost:8000/api/project/my_contract/status"

# 4. 완료 후 출력 파일 확인
ls projects/my_contract/output/
```

---

## 🏗️ 프로젝트 구조

```
TypedContract/
├── backend/                # FastAPI 백엔드
│   └── agent/
│       ├── main.py        # REST API 엔드포인트
│       ├── agent.py       # LangGraph 워크플로우
│       ├── prompts.py     # AI 프롬프트
│       └── error_classifier.py  # 에러 분류 시스템
│
├── idris2/                 # Idris2 프레임워크
│   ├── Core/              # 문서 생성 프레임워크
│   ├── Spec/              # 워크플로우 명세
│   └── Domains/
│       ├── Examples/      # 예제 도메인 모델
│       └── Generated/     # 생성된 도메인 모델
│
├── mcp-servers/            # MCP (Model Context Protocol)
│   └── idris2-mcp/        # Idris2 가이드라인 서버
│
├── projects/               # 사용자 프로젝트 저장소
│   └── {project_id}/
│       ├── metadata.json  # 프로젝트 메타데이터
│       ├── state.json     # 워크플로우 상태
│       ├── input/         # 입력 파일
│       ├── generated/     # 생성된 Idris2 코드
│       └── output/        # 최종 문서
│
├── docs/                   # 프로젝트 문서
│   ├── IDRIS2_CODE_GENERATION_GUIDELINES.md
│   └── ...
│
├── docker-compose.yml      # Docker 설정
└── README.md               # 이 파일
```

---

## 🔧 로컬 개발 환경 (Docker 없이)

<details>
<summary>펼치기 (클릭)</summary>

### 1. Idris2 설치

```bash
# macOS (Homebrew)
brew install idris2

# 또는 소스에서 빌드
brew install chezscheme
git clone https://github.com/idris-lang/Idris2.git
cd Idris2
make bootstrap SCHEME=scheme
make install PREFIX=/usr/local
```

### 2. Python 환경 설정

```bash
# uv로 의존성 설치 (권장)
curl -LsSf https://astral.sh/uv/install.sh | sh
cd backend/agent
uv pip install --system -r requirements.txt

# 또는 pip 사용
pip install -r backend/agent/requirements.txt
```

### 3. 백엔드 실행

```bash
cd backend/agent
uvicorn agent.main:app --reload --host 0.0.0.0 --port 8000
```

</details>

---

## 🧪 워크플로우 동작 방식

### Phase별 진행 과정

1. **Phase 1: Input** - 프로젝트 초기화 및 프롬프트 입력
2. **Phase 2: Analysis** - 문서 요구사항 분석
3. **Phase 3: Generation** - Idris2 도메인 모델 생성
4. **Phase 4: Compilation** - 타입 체크 및 에러 처리
   - 동일 에러 3회 반복 → 자동 중단 (사용자 개입 필요)
5. **Phase 5: Documentable** - Documentable 인스턴스 구현
6. **Phase 6: Draft** - txt/md/csv 초안 생성
7. **Phase 7-8: Feedback** - 사용자 피드백 및 수정
9. **Phase 9: Final** - PDF 최종 문서 생성

### 에러 처리 시스템

- **Level 1 (Syntax)**: 자동 수정 시도 (최대 5회)
- **Level 2 (Logic)**: 사용자 확인 필요 (데이터 검증)
- **Level 3 (Domain)**: 요구사항 재분석 필요

---

## 📡 API 엔드포인트

### 프로젝트 관리

```bash
# 프로젝트 초기화
POST /api/project/init
{
  "project_name": "string",
  "user_prompt": "string",
  "reference_docs": []
}

# 생성 시작
POST /api/project/{name}/generate

# 상태 확인
GET /api/project/{name}/status

# 모든 프로젝트 목록
GET /api/project/list
```

### AutoPause 상태 처리

```bash
# 재개 옵션 확인
GET /api/project/{name}/resume-options

# 재개 (새 프롬프트)
POST /api/project/{name}/resume-autopause
{
  "resume_option": "retry_with_new_prompt",
  "new_prompt": "수정된 프롬프트"
}

# 검증 스킵
POST /api/project/{name}/skip-validation
```

---

## 🎯 MCP 서버 사용 (선택사항)

MCP(Model Context Protocol) 서버는 Claude Code에서 Idris2 가이드라인을 제공합니다.

### 설정 방법

`.mcp-config.json` (이미 설정되어 있음):

```json
{
  "mcpServers": {
    "idris2-helper": {
      "command": "python3",
      "args": ["/absolute/path/to/mcp-servers/idris2-mcp/server.py"],
      "env": {}
    }
  }
}
```

### Claude Code에서 사용

```
# Idris2 가이드라인 조회
idris2://guidelines/syntax
idris2://guidelines/types
idris2://guidelines/modules
```

---

## 🐛 문제 해결

### Docker 빌드 느림 (5-10분)

- **원인**: Idris2를 매번 새로 빌드
- **해결**: 추후 Idris2 base image 제공 예정

### "No module named 'agent'" 에러

```bash
# Docker 컨테이너 재시작
docker-compose restart backend

# 변경사항 확인
docker-compose logs backend --tail 50
```

### 프로젝트가 AutoPause 상태

```bash
# 상태 확인
curl http://localhost:8000/api/project/{name}/status

# 재개 옵션 확인
curl http://localhost:8000/api/project/{name}/resume-options

# 새 프롬프트로 재시작
curl -X POST http://localhost:8000/api/project/{name}/resume-autopause \
  -H "Content-Type: application/json" \
  -d '{"resume_option":"retry_with_new_prompt","new_prompt":"..."}'
```

---

## 📚 추가 문서

- [CLAUDE.md](./CLAUDE.md) - 개발 가이드 (Claude Code용)
- [docs/IDRIS2_CODE_GENERATION_GUIDELINES.md](./docs/IDRIS2_CODE_GENERATION_GUIDELINES.md) - Idris2 코드 생성 가이드라인
- [docs/DOCKER_SETUP.md](./docs/DOCKER_SETUP.md) - Docker 설정 상세
- [Spec/](./idris2/Spec/) - Idris2 워크플로우 명세

---

## 🤝 기여

이슈 및 Pull Request 환영합니다!

---

## 📄 라이선스

MIT License

---

## 🙏 감사

- [Idris2](https://www.idris-lang.org/) - 의존 타입 언어
- [Anthropic Claude](https://www.anthropic.com/) - AI 코드 생성
- [LangGraph](https://github.com/langchain-ai/langgraph) - 워크플로우 오케스트레이션
