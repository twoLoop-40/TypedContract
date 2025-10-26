# LangGraph 에이전트 시스템 설계

## 개요

문서(PDF/DOC/이미지) → Idris2 도메인 모델 변환을 자동화하는 LangGraph 기반 에이전트 시스템입니다.

**핵심 이유**: Idris2 컴파일-수정-재컴파일 사이클을 반복해야 하므로 에이전트가 필수입니다.

---

## 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                   입력 (Input)                          │
│  - 참고 문서 (PDF/DOC/이미지)                           │
│  - 프로젝트 정보 (프로젝트명, 문서 유형)                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              LangGraph Agent Workflow                   │
│                                                          │
│  ┌──────────────┐                                       │
│  │ 1. Analyze   │ ← 문서 분석                           │
│  └──────┬───────┘                                       │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                       │
│  │ 2. Generate  │ ← Idris2 코드 생성                    │
│  └──────┬───────┘                                       │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                       │
│  │ 3. TypeCheck │ ← idris2 --check 실행                │
│  └──────┬───────┘                                       │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐                                       │
│  │ 4. Decision  │ ← 성공? or 에러?                      │
│  └──────┬───────┘                                       │
│         │                                                │
│    ┌────┴────┐                                          │
│    │         │                                          │
│  성공       실패                                         │
│    │         │                                          │
│    │         ▼                                          │
│    │  ┌──────────────┐                                 │
│    │  │ 5. FixError  │ ← 에러 분석 & 코드 수정         │
│    │  └──────┬───────┘                                 │
│    │         │                                          │
│    │         └──────► (3. TypeCheck로 돌아감)          │
│    │                                                     │
│    ▼                                                     │
│  완료                                                    │
└─────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  출력 (Output)                          │
│  - Domains/[프로젝트명].idr (타입 체크 완료)            │
│  - direction/analysis_[프로젝트명].md                   │
└─────────────────────────────────────────────────────────┘
```

---

## State Schema

```python
from typing import TypedDict, List, Optional

class AgentState(TypedDict):
    # 입력
    project_name: str
    document_type: str  # "contract", "approval", "invoice" etc.
    reference_docs: List[str]  # 참고 문서 경로들

    # 중간 상태
    analysis: Optional[str]  # 문서 분석 결과
    idris_code: Optional[str]  # 생성된 Idris2 코드
    current_file: str  # Domains/[project].idr

    # 컴파일 상태
    compile_attempts: int  # 시도 횟수
    last_error: Optional[str]  # 마지막 에러 메시지
    compile_success: bool

    # 출력
    final_module_path: Optional[str]
    messages: List[str]  # 로그
```

---

## Agent Workflow (LangGraph)

### Node 1: Analyze Document

**입력**: `reference_docs`, `document_type`

**동작**:
1. 참고 문서 읽기 (PDF/이미지 OCR)
2. 문서 구조 파악
3. 필드 추출
4. 불변식 식별

**도구**:
- PDF reader
- Vision API (이미지 문서용)
- 구조 분석 프롬프트

**출력**: `analysis` (마크다운 형식)

```markdown
# 분석 결과

## 문서 유형: 용역계약서

## 주요 필드
- 당사자: 갑, 을
- 금액: 공급가액, VAT, 총액
- 기간: 시작일, 종료일

## 불변식
- 총액 = 공급가액 + VAT
- VAT = 공급가액 × 0.10
```

**프롬프트**:
```
당신은 한국 법률/회계 문서 전문가입니다.

첨부된 문서를 분석하고:
1. 문서 유형 파악 (계약서/신청서/명세서)
2. 모든 데이터 필드 추출
3. 계산 규칙 파악 (예: 총액 = 공급가액 + VAT)
4. 날짜/수량 제약조건 파악

마크다운 형식으로 정리해주세요.
```

---

### Node 2: Generate Idris Code

**입력**: `analysis`, `project_name`

**동작**:
1. 분석 결과를 바탕으로 Idris2 코드 생성
2. Layer 1-5 구조로 작성
3. 의존 타입으로 불변식 표현

**프롬프트**:
```
당신은 Idris2 전문가입니다.

다음 문서 분석 결과를 바탕으로 Idris2 도메인 모델을 작성하세요:

{analysis}

요구사항:
1. module Domains.{project_name} 으로 시작
2. Layer 1-5 구조 준수:
   - Layer 1: Primitive types (Money, Date, etc.)
   - Layer 2: Validated types with proofs (UnitPrice with totalAmount = perItem * quantity)
   - Layer 3: Domain entities (Party, Deliverable, etc.)
   - Layer 4: Aggregate root (전체 문서 타입)
   - Layer 5: Concrete instances (실제 데이터)
3. 모든 불변식을 의존 타입으로 표현
4. Smart constructors 사용 (mkUnitPrice 등)
5. public export로 외부 노출

참고 예제:
{ScaleDeep.idr의 UnitPrice 예제}

완전한 Idris2 코드를 생성하세요.
```

**출력**: `idris_code`

---

### Node 3: TypeCheck

**입력**: `idris_code`, `current_file`

**동작**:
1. Idris2 파일 저장
2. `idris2 --check Domains/{project}.idr` 실행
3. 결과 캡처

**도구**:
```python
def typecheck_idris(file_path: str) -> tuple[bool, str]:
    """
    Idris2 타입 체크 실행

    Returns:
        (success: bool, output: str)
    """
    result = subprocess.run(
        ["idris2", "--check", file_path],
        capture_output=True,
        text=True,
        timeout=30
    )

    success = result.returncode == 0
    output = result.stdout + result.stderr

    return success, output
```

**출력**: `compile_success`, `last_error`

---

### Node 4: Decision

**입력**: `compile_success`, `compile_attempts`

**로직**:
```python
def should_continue(state: AgentState) -> str:
    if state["compile_success"]:
        return "finish"

    if state["compile_attempts"] >= 5:
        return "fail"

    return "fix_error"
```

**경로**:
- `finish` → 종료
- `fail` → 실패 (사람 개입 필요)
- `fix_error` → Node 5로

---

### Node 5: Fix Error

**입력**: `last_error`, `idris_code`

**동작**:
1. 컴파일 에러 분석
2. 코드 수정
3. `compile_attempts` 증가

**프롬프트**:
```
다음 Idris2 코드에 컴파일 에러가 발생했습니다.

현재 코드:
```idris
{idris_code}
```

에러 메시지:
```
{last_error}
```

에러를 분석하고 코드를 수정하세요.

흔한 에러들:
1. "Can't find an implementation for Show Nat" → import Data.Nat 필요
2. "Ambiguous elaboration" → 타입 명시 필요
3. "When unifying ..." → 타입 불일치, 패턴 매칭 확인
4. "No such variable" → import 누락 또는 오타

수정된 완전한 코드를 제공하세요.
```

**출력**: 수정된 `idris_code`

**반복**: Node 3 (TypeCheck)로 돌아감

---

## Tools

### Tool 1: idris2_typecheck

```python
@tool
def idris2_typecheck(file_path: str) -> str:
    """
    Idris2 파일 타입 체크

    Args:
        file_path: .idr 파일 경로

    Returns:
        "SUCCESS" 또는 에러 메시지
    """
    success, output = typecheck_idris(file_path)

    if success:
        return "SUCCESS: Type check passed"
    else:
        return f"ERROR:\n{output}"
```

### Tool 2: save_idris_file

```python
@tool
def save_idris_file(code: str, file_path: str) -> str:
    """
    Idris2 코드를 파일로 저장

    Args:
        code: Idris2 소스 코드
        file_path: 저장할 경로

    Returns:
        성공/실패 메시지
    """
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(code)
        return f"File saved: {file_path}"
    except Exception as e:
        return f"Error saving file: {e}"
```

### Tool 3: read_reference_doc

```python
@tool
def read_reference_doc(file_path: str) -> str:
    """
    참고 문서 읽기 (PDF/이미지)

    Args:
        file_path: 문서 경로

    Returns:
        추출된 텍스트
    """
    if file_path.endswith('.pdf'):
        # PDF 파싱
        return extract_pdf_text(file_path)
    elif file_path.endswith(('.png', '.jpg', '.jpeg')):
        # OCR
        return ocr_image(file_path)
    else:
        # 일반 텍스트
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
```

---

## LangGraph Implementation

```python
from langgraph.graph import StateGraph, END

# 그래프 생성
workflow = StateGraph(AgentState)

# 노드 추가
workflow.add_node("analyze", analyze_document)
workflow.add_node("generate", generate_idris_code)
workflow.add_node("typecheck", typecheck_code)
workflow.add_node("fix_error", fix_compilation_error)

# 엣지 정의
workflow.add_edge("analyze", "generate")
workflow.add_edge("generate", "typecheck")

# 조건부 엣지
workflow.add_conditional_edges(
    "typecheck",
    should_continue,
    {
        "finish": END,
        "fail": END,
        "fix_error": "fix_error"
    }
)

workflow.add_edge("fix_error", "typecheck")

# 시작점 설정
workflow.set_entry_point("analyze")

# 컴파일
app = workflow.compile()
```

---

## 사용 예시

```python
# 초기 상태
initial_state = {
    "project_name": "MyContract",
    "document_type": "contract",
    "reference_docs": ["direction/계약서_샘플.pdf"],
    "compile_attempts": 0,
    "compile_success": False,
    "messages": []
}

# 에이전트 실행
result = app.invoke(initial_state)

# 결과 확인
if result["compile_success"]:
    print(f"✅ Success: {result['final_module_path']}")
    print(f"Attempts: {result['compile_attempts']}")
else:
    print(f"❌ Failed after {result['compile_attempts']} attempts")
    print(f"Last error: {result['last_error']}")
```

---

## 실행 흐름 예시

```
[User] 계약서.pdf 업로드

[Agent - Analyze]
  → PDF 읽기
  → 구조 분석
  → "용역계약서, 갑/을 정보, 금액 필드 ..."

[Agent - Generate]
  → Layer 1-5 코드 생성
  → Domains/MyContract.idr 작성

[Agent - TypeCheck]
  → idris2 --check Domains/MyContract.idr
  → ❌ Error: "Can't find an implementation for Show Money"

[Agent - FixError]
  → 에러 분석: Show 인스턴스 누락
  → 코드 수정: "Show Money where show (MkMoney v d) = ..."

[Agent - TypeCheck]
  → idris2 --check Domains/MyContract.idr
  → ❌ Error: "When unifying Nat and String"

[Agent - FixError]
  → 타입 불일치 수정

[Agent - TypeCheck]
  → idris2 --check Domains/MyContract.idr
  → ✅ SUCCESS

[Agent - Finish]
  → 최종 파일: Domains/MyContract.idr
  → 분석 파일: direction/analysis_MyContract.md
```

---

## 장점

1. **자동화**: 문서 → Idris2 변환 자동화
2. **안정성**: 컴파일 에러를 자동으로 수정
3. **반복**: 성공할 때까지 계속 시도
4. **추적**: 전체 과정 로깅
5. **확장성**: 새로운 문서 유형 추가 용이

---

## 다음 단계

1. LangGraph 기본 구조 구현
2. 각 노드별 프롬프트 최적화
3. 에러 패턴 학습 (에러 → 수정 매핑)
4. 통합 테스트
5. 웹 UI 추가 (문서 업로드 → 결과 다운로드)
