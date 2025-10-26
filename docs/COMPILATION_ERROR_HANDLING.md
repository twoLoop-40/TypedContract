# Idris2 컴파일 에러 처리 전략

## 문제 인식

Idris2는 의존 타입 언어이므로, 컴파일 에러가 단순한 문법 오류가 아닌 **논리적/수학적 모순**을 의미할 수 있다.

현재 Agent는 모든 에러를 동일하게 처리하여 최대 5회 자동 수정 후 포기한다.
이는 다음 문제를 야기한다:

1. **증명 실패는 코드 수정으로 해결 불가능**
   - `totalPrice = supplyPrice + vat` 증명 실패 시
   - 입력 데이터 자체가 틀렸을 가능성
   - Claude가 아무리 코드를 수정해도 해결 안됨

2. **도메인 모델 오해는 재분석 필요**
   - 사용자 의도를 잘못 파악한 경우
   - 5회 수정으로는 근본 해결 안됨

3. **사용자 개입 없이 계속 진행**
   - 5회 실패 후 그냥 종료
   - 사용자가 무엇이 잘못되었는지 모름

## 에러 분류 체계

### Level 1: 자동 수정 가능 (Auto-fixable)

**특징:**
- 문법 오류
- 타입 미스매치 (간단한 것)
- 오타, 미정의 이름
- Import 누락

**처리:**
- Claude에게 에러 메시지와 함께 수정 요청
- 최대 3회 재시도
- 대부분 1-2회 안에 해결

**예시:**
```
Error: Undefined name mkContract
→ Fix: MkContract (대문자)

Error: Can't find import Core.DocumentModel
→ Fix: import Core.DocumentModel 추가
```

### Level 2: 논리 에러 - 사용자 확인 필요 (User confirmation needed)

**특징:**
- 의존 타입 증명 실패
- 타입 레벨 계산 불일치
- 불변 조건 위반

**처리:**
- **즉시 사용자에게 알림** (5회 기다리지 않음)
- 에러 메시지 + 입력 데이터 보여주기
- 사용자 선택:
  - [A] 입력 데이터 수정
  - [B] 증명 없는 버전으로 진행 (단순 타입)
  - [C] 프롬프트 재작성

**예시:**
```
Error: Can't solve constraint: 55715000 = 50650000 + 5065000

❌ 의존 타입 증명 실패 감지!

입력하신 데이터:
- 공급가액: 50,650,000원
- VAT: 5,065,000원
- 총액: 55,715,000원

계산 결과: 50,650,000 + 5,065,000 = 55,715,000 ✅
→ 실제로는 맞지만 Idris2가 증명 못함

옵션:
[A] 데이터 재입력
[B] 증명 없이 진행 (record 타입만 사용)
[C] 수동으로 증명 작성
```

### Level 3: 도메인 모델링 실패 - 재분석 필요 (Re-analysis)

**특징:**
- 사용자 요구사항을 잘못 이해
- 필수 필드 누락
- 타입 구조 자체가 틀림

**처리:**
- Phase 2 (Analysis)로 되돌아가기
- 사용자에게 추가 질문
- 참고 문서 재분석

**예시:**
```
Error: Expected type List Deliverable, got List String

🤔 도메인 모델 불일치 감지!

생성된 코드:
  deliverables : List String

하지만 참고 문서에는 Deliverable 타입 정의가 있습니다.
사용자 의도를 재확인하겠습니다.

질문: 산출물을 단순 문자열로 관리하시겠습니까,
      아니면 상세 정보(날짜, 형식 등)를 포함한
      Deliverable 타입으로 관리하시겠습니까?
```

## 개선된 워크플로우

### 현재
```
typecheck → fail → fix_error → typecheck → ... (5회) → END
```

### 개선안
```
typecheck
  ↓
classify_error  ← 새로운 노드!
  ├─ Level 1 (Auto) → fix_error → typecheck (최대 3회)
  ├─ Level 2 (Proof) → ask_user_about_proof
  │                     ├─ [수정] → typecheck
  │                     ├─ [단순화] → remove_proofs → typecheck
  │                     └─ [취소] → END
  └─ Level 3 (Domain) → ask_user_clarification → re_analyze
```

## 에러 분류 알고리즘

```python
def classify_compilation_error(error_message: str) -> ErrorLevel:
    """
    Idris2 컴파일 에러를 분류
    """
    # Level 3: 도메인 모델링 오류 (우선순위 높음)
    domain_patterns = [
        "Expected type .*, got .*",  # 타입 구조 불일치
        "Type mismatch between .* and .*",
        "Record .* does not have field",
    ]

    # Level 2: 의존 타입 증명 실패
    proof_patterns = [
        "Can't solve constraint",
        "Can't find implementation",
        "Mismatch between: .* and .*",  # 숫자 계산 불일치
    ]

    # Level 1: 자동 수정 가능
    syntax_patterns = [
        "Undefined name",
        "Parse error",
        "Can't find import",
        "Unexpected token",
    ]

    for pattern in domain_patterns:
        if re.search(pattern, error_message):
            return ErrorLevel.DOMAIN_ERROR

    for pattern in proof_patterns:
        if re.search(pattern, error_message):
            return ErrorLevel.PROOF_FAILURE

    for pattern in syntax_patterns:
        if re.search(pattern, error_message):
            return ErrorLevel.SYNTAX_ERROR

    # 기본값: 문법 에러로 간주
    return ErrorLevel.SYNTAX_ERROR
```

## Fallback 전략: 증명 제거

증명이 실패하면 **단순 타입으로 Fallback**:

```idris
-- 원본 (의존 타입 + 증명)
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (total : Nat)
    -> (validTotal : total = perItem * quantity)  -- 증명
    -> UnitPrice

-- Fallback (단순 record)
record UnitPrice where
  constructor MkUnitPrice
  perItem : Nat
  quantity : Nat
  total : Nat
  -- 증명 제거, 런타임 검증으로 대체
```

이렇게 하면:
- ✅ 문서는 생성됨
- ⚠️ 컴파일 타임 증명은 없지만
- ℹ️ 사용자에게 "증명 없음" 경고 표시

## 사용자 인터페이스 개선

### Frontend에 에러 상세 페이지 추가

```typescript
interface CompilationError {
  level: 'syntax' | 'proof' | 'domain'
  message: string
  location: { file: string, line: number }
  suggestion: string
  userActions?: {
    retry: boolean
    fallback: boolean  // 증명 제거
    reanalyze: boolean  // 재분석
    manual: boolean     // 수동 수정
  }
}
```

화면 예시:
```
⚠️ 컴파일 중 문제 발생

[ 에러 레벨: 증명 실패 ]

파일: Domains/MyContract.idr:45
에러: Can't solve constraint: 55715000 = 50650000 + 5065000

원인: 의존 타입 증명을 자동으로 해결하지 못했습니다.

옵션:
☑️ 증명 없이 계속 진행 (권장)
   → 문서는 생성되지만, 타입 레벨 검증은 없습니다

⚪ 데이터 재입력
   → 입력값이 잘못되었을 수 있습니다

⚪ 전문가 모드로 수동 수정
   → Idris2 코드를 직접 수정합니다

[계속 진행]  [처음부터 다시]  [취소]
```

## Phase 추가: Error Handling Phase

```python
# Spec/WorkflowTypes.idr에 추가
data WorkflowPhase
  = InputPhase
  | AnalysisPhase
  | SpecGenerationPhase
  | CompilationPhase
  | ErrorHandlingPhase  -- ← 새로 추가!
  | DocImplPhase
  | DraftPhase
  | FeedbackPhase
  | RefinementPhase
  | FinalPhase

data ErrorHandlingState : Type where
  MkErrorHandling :
    (errorLevel : ErrorLevel)
    -> (errorMessage : String)
    -> (attemptCount : Nat)
    -> (userChoice : Maybe UserChoice)
    -> ErrorHandlingState

data UserChoice
  = RetryWithFix
  | RemoveProofs
  | ReanalyzeDocument
  | ManualEdit
  | AbortGeneration
```

## 구현 우선순위

1. **High Priority** (즉시)
   - [ ] `classify_error()` 함수 구현
   - [ ] Level 2 (증명 실패) 감지 시 사용자 알림
   - [ ] Fallback: 증명 제거 옵션

2. **Medium Priority** (다음 버전)
   - [ ] Level 3 (도메인 오류) 재분석 루프
   - [ ] Frontend 에러 상세 페이지
   - [ ] 수동 수정 모드

3. **Low Priority** (나중에)
   - [ ] 에러 패턴 학습 (ML)
   - [ ] 자동 데이터 검증
   - [ ] 증명 힌트 생성

## 결론

Idris2 컴파일 에러는 일반 언어와 달리:
1. **수학적 모순**을 나타낼 수 있음
2. **도메인 이해 부족**을 반영할 수 있음
3. **무한 재시도로 해결 안될 수 있음**

따라서:
- ✅ 에러 분류 체계 도입
- ✅ 사용자 개입 시점 명확화
- ✅ Fallback 전략 (증명 제거)
- ✅ 재분석 루프 추가

이를 통해 더 견고하고 사용자 친화적인 시스템 구축!
