# LangGraph 에이전트 아키텍처 (최종판)

## 핵심 원칙

**Idris2 생성 및 수정은 반드시 LangGraph 에이전트가 필요합니다.**

이유:
1. 컴파일 에러 → 코드 수정 → 재컴파일 **반복 루프** 필요
2. 의존 타입 증명이 복잡해서 한 번에 성공 어려움
3. 여러 파일 수정 필요 (Domains/, Core/DomainToDoc.idr, Core/Generator.idr)
4. 타입 에러 디버깅은 자동화 필수

---

## 시스템 구성

```
┌─────────────────────────────────────────────────────────┐
│         Idris2 명세 생성 에이전트 (필수)                │
│              LangGraph Agent System                      │
│  - 문서 분석                                             │
│  - Idris2 코드 생성                                      │
│  - 컴파일 & 에러 수정 루프 (자동)                        │
│  - Documentable 구현 생성                                │
│  - Pipeline 생성                                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│            문서 생성 & 피드백 시스템                     │
│          (간단한 LLM 호출 또는 템플릿)                   │
│  - 초안 생성 (txt/csv/md)                               │
│  - 사용자 피드백 수집                                    │
│  - 피드백 → 명세 수정 요청 생성                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                최종 출력 (Idris2 실행)                   │
│  - idris2 --exec generateText                           │
│  - idris2 --exec main (PDF 생성)                        │
└─────────────────────────────────────────────────────────┘
```

---

## Agent 1: Idris2 명세 생성 에이전트 (핵심)

### State Schema

```python
class IdrisSpecState(TypedDict):
    # 입력
    project_name: str
    user_requirements: str  # 사용자 요구사항
    reference_docs: List[str]

    # Phase 1: 분석
    analysis: Optional[str]

    # Phase 2: Domains/[project].idr 생성
    spec_code: Optional[str]
    spec_file: str  # Domains/MyProject.idr
    spec_compile_attempts: int
    spec_compile_success: bool
    spec_errors: Optional[str]

    # Phase 3: Core/DomainToDoc.idr 수정
    documentable_code: Optional[str]
    documentable_compile_attempts: int
    documentable_compile_success: bool
    documentable_errors: Optional[str]

    # Phase 4: Core/Generator.idr 수정
    pipeline_code: Optional[str]
    pipeline_compile_attempts: int
    pipeline_compile_success: bool
    pipeline_errors: Optional[str]

    # 출력
    all_success: bool
    messages: List[str]
```

### Workflow

```python
agent1 = StateGraph(IdrisSpecState)

# ========== Phase 1: 분석 ==========
agent1.add_node("analyze", analyze_requirements)

# ========== Phase 2: Domains/ 생성 ==========
agent1.add_node("generate_spec", generate_domain_spec)
agent1.add_node("typecheck_spec", typecheck_domain)
agent1.add_node("fix_spec", fix_domain_errors)

# ========== Phase 3: DomainToDoc 수정 ==========
agent1.add_node("generate_documentable", generate_documentable_instance)
agent1.add_node("typecheck_documentable", typecheck_domaintodoc)
agent1.add_node("fix_documentable", fix_documentable_errors)

# ========== Phase 4: Generator 수정 ==========
agent1.add_node("generate_pipeline", generate_pipeline_code)
agent1.add_node("typecheck_pipeline", typecheck_generator)
agent1.add_node("fix_pipeline", fix_pipeline_errors)

# ========== 엣지 ==========
agent1.add_edge("analyze", "generate_spec")

# Phase 2 루프
agent1.add_edge("generate_spec", "typecheck_spec")
agent1.add_conditional_edges(
    "typecheck_spec",
    lambda s: "ok" if s["spec_compile_success"] else (
        "fail" if s["spec_compile_attempts"] >= 5 else "fix"
    ),
    {"ok": "generate_documentable", "fix": "fix_spec", "fail": END}
)
agent1.add_edge("fix_spec", "typecheck_spec")

# Phase 3 루프
agent1.add_edge("generate_documentable", "typecheck_documentable")
agent1.add_conditional_edges(
    "typecheck_documentable",
    lambda s: "ok" if s["documentable_compile_success"] else (
        "fail" if s["documentable_compile_attempts"] >= 5 else "fix"
    ),
    {"ok": "generate_pipeline", "fix": "fix_documentable", "fail": END}
)
agent1.add_edge("fix_documentable", "typecheck_documentable")

# Phase 4 루프
agent1.add_edge("generate_pipeline", "typecheck_pipeline")
agent1.add_conditional_edges(
    "typecheck_pipeline",
    lambda s: "done" if s["pipeline_compile_success"] else (
        "fail" if s["pipeline_compile_attempts"] >= 5 else "fix"
    ),
    {"done": END, "fix": "fix_pipeline", "fail": END}
)
agent1.add_edge("fix_pipeline", "typecheck_pipeline")

agent1.set_entry_point("analyze")
```

### 사용 예시

```python
# Agent 1 실행
initial_state = {
    "project_name": "SpiratiContract",
    "user_requirements": """
        스피라티와 이츠에듀 간 용역계약서.
        - 품목: 수학문항 입력 (50,650문항)
        - 단가: 1,000원/문항
        - 기간: 2025-10-01 ~ 2025-11-30
        - 산출물: 3차 납품
    """,
    "reference_docs": ["direction/외주용역.pdf"],
    ...
}

result = agent1_app.invoke(initial_state)

if result["all_success"]:
    print("✅ Idris2 명세 생성 완료!")
    print(f"  - {result['spec_file']}")
    print(f"  - Core/DomainToDoc.idr (updated)")
    print(f"  - Core/Generator.idr (updated)")
else:
    print("❌ 생성 실패")
    print(result["messages"])
```

---

## Agent 2: 피드백 처리 에이전트 (간단)

사용자 피드백을 받아서 **Idris2 명세 수정 요청**을 생성합니다.

### State Schema

```python
class FeedbackState(TypedDict):
    # 입력
    current_spec_file: str  # Domains/MyProject.idr
    user_feedback: str

    # 출력
    modification_request: str  # "선급금을 30%로 변경"
    updated_requirements: str  # 수정된 요구사항
```

### Workflow

```python
agent2 = StateGraph(FeedbackState)

agent2.add_node("parse_feedback", parse_user_feedback)
agent2.add_node("generate_mod_request", generate_modification_request)

agent2.add_edge("parse_feedback", "generate_mod_request")
agent2.add_edge("generate_mod_request", END)

agent2.set_entry_point("parse_feedback")
```

### 사용 예시

```python
feedback_state = {
    "current_spec_file": "Domains/SpiratiContract.idr",
    "user_feedback": "선급금을 30%로 올려주고 중도금 일자를 11/15로 변경"
}

result = agent2_app.invoke(feedback_state)

print(result["modification_request"])
# → "paymentSchedule의 advance를 totalAmount * 0.3으로 수정하고,
#    interim_date를 2025-11-15로 변경"
```

---

## 전체 통합 워크플로우

```python
def complete_workflow(user_input):
    # ========== 1. Idris2 명세 생성 (Agent 1) ==========
    print("[Phase 1] Idris2 명세 생성 중...")

    spec_state = {
        "project_name": extract_project_name(user_input),
        "user_requirements": user_input["prompt"],
        "reference_docs": user_input["files"],
    }

    spec_result = agent1_app.invoke(spec_state)

    if not spec_result["all_success"]:
        return {"error": "명세 생성 실패"}

    # ========== 2. 초안 생성 (Idris2 실행) ==========
    print("[Phase 2] 초안 생성 중...")

    subprocess.run([
        "idris2", "--exec", "generateText",
        f"--package", spec_result["project_name"]
    ])

    draft_txt = read_file(f"output/{spec_result['project_name']}_draft.txt")
    draft_csv = read_file(f"output/{spec_result['project_name']}_schedule.csv")

    # ========== 3. 사용자에게 제시 ==========
    print("\n✅ 초안이 완성되었습니다!")
    print(draft_txt[:500])  # 미리보기
    print("\n파일:")
    print(f"  - output/{spec_result['project_name']}_draft.txt")
    print(f"  - output/{spec_result['project_name']}_schedule.csv")

    # ========== 4. 피드백 수집 ==========
    user_feedback = input("\n수정 사항을 입력하세요 (없으면 '완료'): ")

    while user_feedback != "완료":
        # ========== 5. 피드백 처리 (Agent 2) ==========
        print("[Phase 3] 피드백 처리 중...")

        feedback_state = {
            "current_spec_file": spec_result["spec_file"],
            "user_feedback": user_feedback
        }

        feedback_result = agent2_app.invoke(feedback_state)

        # ========== 6. 명세 재생성 (Agent 1 재실행) ==========
        print("[Phase 4] 명세 수정 중...")

        spec_state["user_requirements"] = feedback_result["updated_requirements"]
        spec_result = agent1_app.invoke(spec_state)

        # ========== 7. 초안 재생성 ==========
        print("[Phase 5] 초안 재생성 중...")

        subprocess.run(["idris2", "--exec", "generateText", ...])

        draft_txt = read_file(f"output/{spec_result['project_name']}_draft_v2.txt")

        print("\n✅ 수정 완료!")
        print(draft_txt[:500])

        # 다시 피드백
        user_feedback = input("\n추가 수정 사항: ")

    # ========== 8. PDF 생성 (선택) ==========
    pdf_request = input("\nPDF를 생성할까요? (y/n): ")

    if pdf_request == "y":
        print("[Phase 6] PDF 생성 중...")

        subprocess.run(["idris2", "--exec", "main", ...])

        print(f"✅ 완료: output/{spec_result['project_name']}_final.pdf")

    return {
        "success": True,
        "spec_file": spec_result["spec_file"],
        "draft": draft_txt,
        "pdf": f"output/{spec_result['project_name']}_final.pdf" if pdf_request == "y" else None
    }
```

---

## 핵심 포인트

### ✅ LangGraph Agent 필수 영역

1. **Idris2 도메인 명세 생성** (Domains/[project].idr)
   - 여러 번 컴파일-수정 반복 필요
   - 의존 타입 증명 복잡

2. **Documentable 인스턴스 생성** (Core/DomainToDoc.idr)
   - 기존 코드에 추가해야 함
   - 타입 에러 가능성

3. **Pipeline 생성** (Core/Generator.idr)
   - 마찬가지로 기존 코드 수정

### ⚡ 간단한 LLM 호출 가능 영역

4. **피드백 파싱**
   - 자연어 → 수정 요청 변환
   - 단순 텍스트 처리

5. **초안 생성**
   - Idris2 실행만 하면 됨
   - `idris2 --exec generateText`

---

## 필요한 도구 (Tools)

```python
# Agent 1용
@tool
def typecheck_idris(file_path: str) -> tuple[bool, str]:
    """Idris2 타입 체크"""
    ...

@tool
def read_idris_file(file_path: str) -> str:
    """Idris2 파일 읽기"""
    ...

@tool
def update_idris_file(file_path: str, old_code: str, new_code: str) -> str:
    """Idris2 파일 수정 (부분 수정)"""
    ...

@tool
def append_to_idris_file(file_path: str, code: str) -> str:
    """Idris2 파일에 추가 (Documentable 인스턴스 등)"""
    ...

# Agent 2용
@tool
def parse_feedback_to_requirements(feedback: str, current_spec: str) -> str:
    """피드백을 요구사항으로 변환"""
    ...
```

---

## 다음 단계

1. **Agent 1 구현** (최우선)
   - Idris2 생성 & 수정 루프
   - 3단계 파일 생성 (Domains, DomainToDoc, Generator)

2. **경량 렌더러 추가**
   - TextRenderer.idr
   - CSVRenderer.idr
   - MarkdownRenderer.idr

3. **Agent 2 구현**
   - 피드백 파싱

4. **통합 CLI**
   - `python agent/main.py --input "..." --files ...`
