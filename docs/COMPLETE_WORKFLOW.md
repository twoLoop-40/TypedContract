# 완전한 문서 생성 워크플로우 (개정판)

## 개요

사용자와의 **반복적 상호작용**을 통해 점진적으로 문서를 완성하는 시스템입니다.

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: 명세 생성 (자동)                                  │
│  자료 + 프롬프트 → Idris2 명세 → 컴파일 루프                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: 초안 생성 (자동)                                  │
│  명세 → 문서 구현 함수 → 경량 출력 (txt/csv)                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: 반복 개선 (사용자 주도)                           │
│  초안 검토 → 보강사항 → 명세 수정 → 재생성 → 검토 → ...    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: 최종 출력 (선택)                                  │
│  만족 → PDF 생성 → 완료                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 전체 워크플로우

### 1️⃣ 자료 업로드 + 프롬프트

**입력**:
- 참고 문서 (PDF, DOC, 이미지)
- 사용자 프롬프트
  ```
  "스피라티와 이츠에듀 간 수학문항 입력 용역계약서를 만들어줘.
   총 50,650문항, 단가 1,000원, 기간은 10월 1일부터 11월 30일까지.
   산출물은 3차로 나눠서 납품."
  ```

**출력**:
- `input/` 폴더에 저장
- 프롬프트 파싱

---

### 2️⃣ Idris2 명세 생성 (자동)

**에이전트 작업**:

#### Step 2.1: 문서 분석
- 참고 문서 읽기
- 프롬프트에서 요구사항 추출
- 구조화된 분석 생성

```markdown
# 분석 결과

## 요구사항
- 계약 당사자: 스피라티, 이츠에듀
- 품목: 수학문항 입력 (50,650문항)
- 단가: 1,000원/문항
- 총액: 50,650,000원 + VAT
- 기간: 2025-10-01 ~ 2025-11-30
- 산출물: 3차 납품

## 불변식
- 총액 = 단가 × 수량
- VAT = 공급가액 × 0.10
```

#### Step 2.2: Idris2 명세 생성
```idris
module Domains.SpiratiContract

data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (total : Nat)
    -> (total = perItem * quantity)
    -> UnitPrice

-- ... 전체 명세
```

#### Step 2.3: 컴파일 & 수정 루프 (자동)
```
[Attempt 1] idris2 --check → ❌ Error
[Attempt 2] Fix error → idris2 --check → ❌ Error
[Attempt 3] Fix error → idris2 --check → ✅ Success
```

**출력**:
- `Domains/SpiratiContract.idr` (타입 체크 완료)
- `direction/analysis_SpiratiContract.md`

---

### 3️⃣ 문서 구현 함수 완성 (자동)

**에이전트 작업**:

#### Step 3.1: Documentable 인스턴스 생성
```idris
-- Core/DomainToDoc.idr에 추가
Documentable ServiceContract where
  toDocument sc = MkDoc
    (MkMetadata "용역계약서" ...)
    [ Heading 1 "용역계약서"
    , Para ("계약번호: " ++ sc.contractNumber)
    , ...
    ]
```

#### Step 3.2: 파이프라인 생성
```idris
-- Core/Generator.idr에 추가
spiratiPipeline : GenerationPipeline ServiceContract
spiratiPipeline = createPipeline spiratiContract "output/contract"
```

**출력**:
- `Core/DomainToDoc.idr` (업데이트)
- `Core/Generator.idr` (업데이트)

---

### 4️⃣ 초안 생성 (경량 출력)

**중요**: PDF 바로 생성 ❌, 먼저 가벼운 형식으로 보여주기!

#### Step 4.1: 텍스트 출력
```bash
idris2 --exec generateText Main.idr
```

**생성**:
```
output/contract_draft.txt
───────────────────────────────────────────
용역계약서

계약번호: SPRT-2025-001
계약일자: 2025년 10월 1일

주식회사 스피라티(이하 "갑"이라 한다)와
주식회사 이츠에듀(이하 "을"이라 한다)는
...

제1조 (계약의 목적)
본 계약은 ...

...
───────────────────────────────────────────
```

#### Step 4.2: CSV/Excel 출력 (표 형식 데이터)
```csv
# payment_schedule.csv
항목,금액,일자
선급금,20000000,계약 후 7일
중도금,15000000,2025-11-20
잔금,20715000,2025-11-30
```

#### Step 4.3: Markdown 출력
```markdown
# contract_draft.md

## 용역계약서

**계약번호**: SPRT-2025-001
...
```

**출력**:
- `output/contract_draft.txt`
- `output/payment_schedule.csv`
- `output/contract_draft.md`

**사용자에게 제시**:
```
✅ 초안이 완성되었습니다!

다음 파일을 확인해주세요:
- output/contract_draft.txt (전체 내용)
- output/payment_schedule.csv (지급 일정)

만족하시면 "완료", 수정이 필요하면 요청사항을 말씀해주세요.
```

---

### 5️⃣ 사용자 피드백 수집

**사용자 입력**:
```
"선급금 비율을 30%로 올려주고,
중도금 일자를 11월 15일로 앞당겨줘.
그리고 제14조에 '주차별 진행보고' 조항 추가해줘."
```

**파싱 결과**:
```json
{
  "changes": [
    {
      "field": "payment.advance",
      "value": "30%",
      "old_value": "20,000,000원"
    },
    {
      "field": "payment.interim_date",
      "value": "2025-11-15",
      "old_value": "2025-11-20"
    },
    {
      "field": "terms.special_provisions",
      "action": "add",
      "value": "주차별 진행보고 의무"
    }
  ]
}
```

---

### 6️⃣ 명세 수정 → 재생성 루프

**에이전트 작업**:

#### Step 6.1: 명세 수정
```idris
-- Domains/SpiratiContract.idr 자동 수정

-- Before:
paymentSchedule = [20000000, 15000000, 20715000]

-- After:
paymentSchedule = [33000000, 15000000, 7715000]  -- 30% 선급금
```

#### Step 6.2: 재컴파일
```bash
idris2 --check Domains/SpiratiContract.idr
# ✅ Success (금액 합계 증명도 자동 재계산)
```

#### Step 6.3: 문서 재생성
```bash
idris2 --exec generateText Main.idr
```

**출력**:
```
output/contract_draft_v2.txt
output/contract_draft_v2.md
```

**사용자에게 제시**:
```
✅ 수정 완료!

변경사항:
- 선급금: 20,000,000원 → 33,000,000원 (30%)
- 중도금 일자: 2025-11-20 → 2025-11-15
- 제14조 4항 추가: 주차별 진행보고 의무

output/contract_draft_v2.txt를 확인해주세요.
추가 수정이 필요하면 말씀해주세요.
```

---

### 7️⃣ 반복 (사용자가 만족할 때까지)

```
사용자: "좋아, 이제 완료!"
```

또는

```
사용자: "제8조 지적재산권 부분을 더 명확하게 해줘..."
→ 다시 6단계로
```

---

### 8️⃣ PDF 생성 (최종)

**사용자**:
```
"완료! 이제 PDF로 만들어줘."
```

**에이전트**:
```bash
idris2 --exec main Main.idr
# LaTeX 생성 → pdflatex 실행
```

**출력**:
```
output/contract_final.pdf ✅
```

---

### 9️⃣ 마무리

**최종 산출물**:
```
output/
├── contract_draft.txt        # 초안 (텍스트)
├── contract_draft_v2.txt     # 수정본
├── payment_schedule.csv      # 지급 일정 (CSV)
├── contract_draft.md         # 마크다운
└── contract_final.pdf        # 최종 PDF

Domains/
└── SpiratiContract.idr       # Idris2 명세 (검증 완료)

direction/
└── analysis_SpiratiContract.md  # 분석 결과
```

**버전 관리**:
```bash
git add -A
git commit -m "Complete: Spirati-ItsEdu contract (v2 - 30% advance)"
```

---

## LangGraph State (개정판)

```python
class DocumentGenerationState(TypedDict):
    # ========== Phase 1: 입력 ==========
    project_name: str
    user_prompt: str
    reference_docs: List[str]

    # ========== Phase 2: 명세 생성 ==========
    analysis: Optional[str]
    idris_spec: Optional[str]  # Idris2 명세
    spec_file: str  # Domains/[project].idr
    compile_attempts: int
    compile_success: bool
    compile_errors: List[str]

    # ========== Phase 3: 문서 구현 ==========
    documentable_impl: Optional[str]  # DomainToDoc 구현
    pipeline_impl: Optional[str]      # Generator 파이프라인

    # ========== Phase 4: 초안 생성 ==========
    draft_txt: Optional[str]
    draft_md: Optional[str]
    draft_csv: Optional[Dict[str, str]]  # 표 데이터

    # ========== Phase 5: 반복 개선 ==========
    version: int  # 버전 번호 (v1, v2, ...)
    user_feedback: List[str]  # 사용자 피드백 히스토리
    current_feedback: Optional[str]
    satisfied: bool  # 사용자 만족 여부

    # ========== Phase 6: 최종 출력 ==========
    generate_pdf: bool
    final_pdf_path: Optional[str]

    # ========== 메타 ==========
    messages: List[str]
    current_phase: str  # "spec", "draft", "feedback", "final"
```

---

## LangGraph Workflow (개정판)

```python
workflow = StateGraph(DocumentGenerationState)

# ========== Phase 1: 명세 생성 ==========
workflow.add_node("parse_input", parse_user_input)
workflow.add_node("analyze_docs", analyze_documents)
workflow.add_node("generate_spec", generate_idris_spec)
workflow.add_node("typecheck_spec", typecheck_idris)
workflow.add_node("fix_spec_error", fix_spec_errors)

# ========== Phase 2: 문서 구현 ==========
workflow.add_node("generate_documentable", generate_documentable_impl)
workflow.add_node("generate_pipeline", generate_pipeline_impl)

# ========== Phase 3: 초안 생성 ==========
workflow.add_node("generate_txt", generate_text_output)
workflow.add_node("generate_csv", generate_csv_output)
workflow.add_node("generate_md", generate_markdown_output)

# ========== Phase 4: 사용자 피드백 ==========
workflow.add_node("present_draft", present_to_user)  # 🔴 HUMAN INPUT
workflow.add_node("collect_feedback", collect_user_feedback)  # 🔴 HUMAN INPUT

# ========== Phase 5: 반복 개선 ==========
workflow.add_node("parse_feedback", parse_user_feedback)
workflow.add_node("update_spec", update_idris_spec)
workflow.add_node("recompile", recompile_spec)

# ========== Phase 6: 최종 출력 ==========
workflow.add_node("generate_pdf", generate_pdf_output)
workflow.add_node("finalize", finalize_project)

# ========== 엣지 ==========
workflow.add_edge("parse_input", "analyze_docs")
workflow.add_edge("analyze_docs", "generate_spec")
workflow.add_edge("generate_spec", "typecheck_spec")

# 컴파일 루프
workflow.add_conditional_edges(
    "typecheck_spec",
    lambda s: "success" if s["compile_success"] else "fix",
    {"success": "generate_documentable", "fix": "fix_spec_error"}
)
workflow.add_edge("fix_spec_error", "typecheck_spec")

# 문서 구현
workflow.add_edge("generate_documentable", "generate_pipeline")
workflow.add_edge("generate_pipeline", "generate_txt")
workflow.add_edge("generate_txt", "generate_csv")
workflow.add_edge("generate_csv", "generate_md")

# 🔴 사용자 피드백 루프 (중요!)
workflow.add_edge("generate_md", "present_draft")

workflow.add_conditional_edges(
    "collect_feedback",
    lambda s: "satisfied" if s["satisfied"] else "revise",
    {
        "satisfied": "check_pdf_request",
        "revise": "parse_feedback"
    }
)

# 수정 루프
workflow.add_edge("parse_feedback", "update_spec")
workflow.add_edge("update_spec", "recompile")
workflow.add_edge("recompile", "generate_txt")  # 초안 재생성

# PDF 생성 (선택)
workflow.add_conditional_edges(
    "check_pdf_request",
    lambda s: "yes" if s["generate_pdf"] else "done",
    {"yes": "generate_pdf", "done": "finalize"}
)

workflow.add_edge("generate_pdf", "finalize")
workflow.add_edge("finalize", END)

workflow.set_entry_point("parse_input")
```

---

## 핵심 차이점

| 항목 | 기존 방식 | 새 방식 |
|------|-----------|---------|
| 출력 | PDF 바로 생성 | txt/csv/md 먼저 → 검토 → PDF |
| 피드백 | 없음 | 반복적 수정 루프 |
| 버전 관리 | 1회 생성 | v1, v2, ... 추적 |
| 사용자 참여 | 시작과 끝만 | 초안 검토, 수정 요청 |
| 명세 수정 | 불가 | 자동 수정 & 재컴파일 |

---

## 사용 예시

```python
# 시작
state = {
    "project_name": "SpiratiContract",
    "user_prompt": "스피라티와 이츠에듀 간 수학문항 입력 용역계약서...",
    "reference_docs": ["direction/외주용역.pdf"],
    ...
}

app = create_workflow()

# Phase 1-3: 자동 실행
result = app.invoke(state)

# Phase 4: 사용자에게 초안 제시
print(f"초안: {result['draft_txt']}")

# 🔴 사용자 피드백 대기
user_input = input("수정 사항이 있나요? (없으면 '완료'): ")

if user_input != "완료":
    # Phase 5: 수정 루프
    result["current_feedback"] = user_input
    result["satisfied"] = False
    result = app.invoke(result)  # 재실행
else:
    result["satisfied"] = True

# Phase 6: PDF 생성 여부
pdf_request = input("PDF를 생성할까요? (y/n): ")
result["generate_pdf"] = (pdf_request == "y")

# 최종 실행
final = app.invoke(result)

print(f"✅ 완료: {final['final_pdf_path']}")
```

---

## 다음 단계

1. **Lightweight Renderer 구현**
   - TextRenderer (LaTeX 대신 순수 텍스트)
   - CSVRenderer (표 데이터 추출)
   - MarkdownRenderer

2. **Feedback Parser**
   - 자연어 → 명세 변경사항 매핑
   - "선급금 30%로" → `advance = total * 0.3`

3. **Version Management**
   - v1, v2, ... 자동 추적
   - diff 생성

4. **Human-in-the-loop UI**
   - 웹 인터페이스 또는 CLI
