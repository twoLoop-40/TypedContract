# Docker 설정 가이드

## 개요

이 프로젝트는 Docker를 사용하여 다음 구성 요소를 컨테이너화합니다:

- **Frontend**: Next.js 14 (포트 3000)
- **Backend**: FastAPI + Idris2 + LaTeX (포트 8000)
- **LangGraph**: Agent 시스템 (backend 컨테이너 내부)

---

## 사전 요구사항

- Docker Desktop 또는 Docker Engine (v20.10 이상)
- Docker Compose (v2.0 이상)
- 최소 8GB RAM 권장 (Idris2 컴파일용)

---

## 프로젝트 구조

```
TypedContract/
├── docker-compose.yml          # 오케스트레이션 설정
├── docker/
│   ├── Dockerfile.backend      # FastAPI + Idris2
│   └── Dockerfile.frontend     # Next.js 14
├── agent/                      # FastAPI 백엔드
│   ├── main.py                # FastAPI 진입점
│   ├── requirements.txt       # Python 의존성
│   └── prompts.py             # LangGraph 프롬프트
├── frontend/                   # Next.js 프론트엔드
│   ├── package.json
│   ├── app/
│   └── components/
├── Spec/                       # Idris2 워크플로우 명세
├── Core/                       # Idris2 프레임워크
└── Domains/                    # Idris2 도메인 모델
```

---

## 빠른 시작

### 1. 환경 설정

프로젝트 루트에 `.env` 파일 생성:

```bash
# .env
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...

# Backend
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000

# Frontend
NEXT_PUBLIC_API_URL=http://localhost:8000
```

### 2. Docker Compose로 전체 시스템 실행

```bash
# 모든 서비스 빌드 및 실행
docker-compose up --build

# 백그라운드 실행
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 특정 서비스만 로그 확인
docker-compose logs -f backend
docker-compose logs -f frontend
```

### 3. 접속

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API 문서**: http://localhost:8000/docs

### 4. 종료

```bash
# 서비스 중지
docker-compose stop

# 서비스 중지 및 컨테이너 삭제
docker-compose down

# 볼륨까지 삭제 (주의: 데이터 손실)
docker-compose down -v
```

---

## 개발 워크플로우

### Backend 개발

```bash
# Backend 컨테이너 접속
docker-compose exec backend bash

# Idris2 타입 체크
idris2 --check Spec/WorkflowTypes.idr

# Python 테스트 실행
pytest agent/tests/

# FastAPI 재시작 (코드 변경 시 자동 reload)
# uvicorn이 --reload 옵션으로 실행되어 자동 반영됨
```

### Frontend 개발

```bash
# Frontend 컨테이너 접속
docker-compose exec frontend sh

# Next.js 의존성 추가
npm install [package-name]

# 빌드 확인
npm run build

# 코드 변경 시 자동 Hot Reload됨
```

### Idris2 개발

```bash
# Backend 컨테이너에서 작업
docker-compose exec backend bash

# 새 도메인 모델 생성
cd Domains/
idris2 --check MyNewDomain.idr

# 문서 생성 테스트
idris2 --exec main MyNewDomain.idr

# 출력 확인
ls -la output/
```

---

## Dockerfile 구조

### Backend (FastAPI + Idris2)

`docker/Dockerfile.backend`는 다음을 포함합니다:

1. **Python 3.11**: FastAPI 실행 환경
2. **Idris2 v0.7.0**: 의존 타입 컴파일러
3. **LaTeX**: PDF 생성 (texlive-xetex, kotex)
4. **LangGraph 및 LangChain**: Agent 시스템
5. **FastAPI**: REST API 서버

### Frontend (Next.js 14)

`docker/Dockerfile.frontend`는 다음을 포함합니다:

1. **Node.js 20**: 최신 LTS 버전
2. **Next.js 14**: React 프레임워크
3. **Hot Reload**: 개발 시 자동 반영

---

## 볼륨 마운트

### Backend 볼륨

```yaml
volumes:
  - ./agent:/app/agent              # FastAPI 코드
  - ./Spec:/app/Spec                # Idris2 명세
  - ./Core:/app/Core                # Idris2 프레임워크
  - ./Domains:/app/Domains          # Idris2 도메인
  - ./output:/app/output            # 생성된 문서
  - ./direction:/app/direction      # 참조 자료
```

**효과**: 로컬 파일 변경 → 컨테이너에 즉시 반영

### Frontend 볼륨

```yaml
volumes:
  - ./frontend:/app                 # Next.js 코드
  - /app/node_modules              # 의존성 캐싱
  - /app/.next                     # 빌드 캐싱
```

---

## 네트워크

```yaml
networks:
  typedcontract_network:
    driver: bridge
```

- **Frontend → Backend**: `http://backend:8000`
- **외부 → Frontend**: `http://localhost:3000`
- **외부 → Backend**: `http://localhost:8000`

---

## 트러블슈팅

### 1. Idris2 컴파일 에러

```bash
# Backend 컨테이너 재빌드
docker-compose build --no-cache backend
docker-compose up backend
```

### 2. 포트 충돌

```bash
# 사용 중인 포트 확인
lsof -i :3000
lsof -i :8000

# docker-compose.yml에서 포트 변경
ports:
  - "3001:3000"  # 3000 → 3001
  - "8001:8000"  # 8000 → 8001
```

### 3. 볼륨 권한 문제

```bash
# 출력 디렉토리 권한 수정
sudo chown -R $USER:$USER output/

# 컨테이너 재시작
docker-compose restart backend
```

### 4. Node.js 의존성 문제

```bash
# node_modules 재설치
docker-compose exec frontend sh
rm -rf node_modules package-lock.json
npm install
```

### 5. 메모리 부족

```bash
# Docker Desktop 설정에서 메모리 증가
# 최소 8GB 권장
```

---

## 프로덕션 배포

### 프로덕션 빌드

```bash
# Frontend 프로덕션 빌드
docker-compose run frontend npm run build

# Backend 프로덕션 설정
# docker-compose.prod.yml 생성하여 사용
```

### 환경 분리

```bash
# 개발 환경
docker-compose up

# 프로덕션 환경
docker-compose -f docker-compose.prod.yml up
```

---

## 참고 자료

- [Docker Compose 공식 문서](https://docs.docker.com/compose/)
- [Next.js Docker 가이드](https://nextjs.org/docs/deployment)
- [FastAPI Docker 가이드](https://fastapi.tiangolo.com/deployment/docker/)
- [Idris2 공식 문서](https://idris2.readthedocs.io/)

---

## 다음 단계

1. **Frontend 초기화**: `frontend/` 디렉토리에 Next.js 14 프로젝트 생성
2. **Backend API 구현**: `agent/main.py`에 FastAPI 엔드포인트 추가
3. **LangGraph Agent 구현**: `agent/agent.py`에 Idris2 생성 워크플로우 추가
4. **통합 테스트**: Frontend → Backend → Idris2 전체 파이프라인 검증
