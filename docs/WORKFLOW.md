# 문서 생성 프로젝트 워크플로우

## 개요

이 프로젝트는 **참고 문서 → Idris2 도메인 모델 → 정형 문서 생성**의 3단계 프로세스를 따릅니다.

```
┌─────────────────┐
│ 1. 참고자료 수집 │
│  (PDF/DOC/IMG)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 2. 도메인 모델링 │
│  (Idris2 타입)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 3. 문서 생성    │
│  (LaTeX → PDF)  │
└─────────────────┘
```

---

## 1단계: 참고자료 수집 및 분석

### 1.1 참고자료 저장

프로젝트 시작 시 받은 참고 문서들을 `direction/` 폴더에 저장합니다.

```bash
direction/
├── 외주용역_사전승인_신청서.pdf
├── 용역계약서_샘플.docx
└── 거래명세서_양식.png
```

### 1.2 문서 구조 분석

참고 문서를 보고 다음을 파악합니다:

1. **문서의 목적**: 계약서? 신청서? 명세서?
2. **필수 섹션**: 어떤 항목들이 있는가?
3. **데이터 필드**: 각 섹션에 어떤 데이터가 들어가는가?
4. **검증 규칙**: 금액 계산, 날짜 관계 등 불변식이 있는가?
5. **반복 패턴**: 리스트나 테이블 구조가 있는가?

### 1.3 분석 결과 정리

`direction/analysis_[문서명].md` 파일 작성:

```markdown
# [문서명] 구조 분석

## 문서 유형
- 용역계약서

## 주요 섹션
1. 계약 당사자 (갑, 을)
2. 계약 조항 (14개 조항)
3. 금액 및 지급 조건
4. 산출물 및 납품 일정

## 데이터 필드
- 당사자 정보: 회사명, 대표자, 사업자번호, 주소, 연락처
- 금액: 공급가액, 부가세, 총액 (불변식: 총액 = 공급가액 + 부가세)
- 일정: 계약기간, 납품일자

## 검증 규칙
- 총액 = 공급가액 + 부가세 (자동 증명 필요)
- 납품일 ≤ 계약종료일
```

---

## 2단계: Idris2 도메인 모델링

### 2.1 새 도메인 모듈 생성

`Domains/[프로젝트명].idr` 파일을 생성합니다.

```bash
# 예시
Domains/
├── ScaleDeep.idr          # 스피라티 용역계약
├── ApprovalNarrative.idr  # 사전승인 신청서
└── MyNewProject.idr       # 새 프로젝트
```

### 2.2 모델링 레이어 구성

도메인 모델은 **계층적으로** 구성합니다:

```idris
module Domains.MyProject

------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------
-- Money, Date, Rate 등 primitive 타입

------------------------------------------------------------
-- Layer 2: 복합 데이터 + 불변식 증명
------------------------------------------------------------
-- UnitPrice (수량 × 단가 = 총액 증명)
-- DateRange (시작일 < 종료일 증명)

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------
-- Party (계약 당사자)
-- ContractTerms (계약 조항)

------------------------------------------------------------
-- Layer 4: 집합 도메인 모델
------------------------------------------------------------
-- ServiceContract (전체 계약서)
```

### 2.3 의존 타입으로 불변식 표현

**잘못된 데이터를 컴파일 시점에 방지**합니다:

```idris
-- ❌ 나쁜 예: 런타임에만 검증
record Contract where
  supply : Nat
  vat : Nat
  total : Nat
  -- validTotal 함수로 나중에 검증해야 함

-- ✅ 좋은 예: 컴파일 타임에 증명
data Contract : Type where
  MkContract : (supply : Nat)
    -> (vat : Nat)
    -> (total : Nat)
    -> (proof : total = supply + vat)  -- 증명 필요!
    -> Contract
```

### 2.4 구체적 데이터 인스턴스 작성

모델을 정의한 후 실제 프로젝트 데이터를 작성합니다:

```idris
-- 구체적인 계약서 데이터
public export
myProjectContract : ServiceContract
myProjectContract = MkServiceContract
  "CONTRACT-2025-001"
  "2025년 10월 1일"
  clientParty
  contractorParty
  contractTerms
  50000000  -- 공급가액
  5000000   -- 부가세
  55000000  -- 총액
  attachments
```

---

## 3단계: 문서 변환 및 생성

### 3.1 Documentable 인스턴스 구현

`Core/DomainToDoc.idr`에 변환 로직 추가:

```idris
-- 새 도메인 타입을 문서로 변환
Documentable MyContract where
  toDocument contract = MkDoc
    (MkMetadata "계약서" ... )
    [ Heading 1 "계약서"
    , Para "..."
    , ...
    ]
```

### 3.2 파이프라인 생성

`Core/Generator.idr`에 파이프라인 추가:

```idris
public export
myProjectPipeline : GenerationPipeline MyContract
myProjectPipeline =
  createPipeline myProjectContract "output/mycontract"
```

### 3.3 Main.idr에서 실행

```idris
main : IO ()
main = do
  putStrLn "MyProject Document Generator"
  executePipeline myProjectPipeline
```

### 3.4 문서 생성

```bash
# 타입 체크
idris2 --check Domains/MyProject.idr

# 문서 생성
idris2 --exec main Main.idr

# 결과 확인
ls output/
# mycontract.tex
# mycontract.pdf
```

---

## 모범 사례 (Best Practices)

### ✅ DO

1. **계층적 모델링**: 단순한 타입부터 복잡한 타입으로
2. **불변식 증명**: 의존 타입으로 잘못된 데이터 방지
3. **명확한 이름**: `clientParty`, `contractorParty` (갑/을보다 명확)
4. **문서화**: 각 필드에 한글 주석으로 의미 설명
5. **단계별 커밋**: 모델 정의 → 데이터 작성 → 변환 로직 순으로 커밋

### ❌ DON'T

1. **한 파일에 모두 작성**: 도메인별로 파일 분리
2. **검증 생략**: "나중에 확인하면 돼" → 컴파일 타임에 증명
3. **매직 넘버**: `50000000` 대신 `unitPrice * quantity`로 계산
4. **영어만 사용**: 한국 법률 문서는 한글 용어 그대로 사용
5. **참고자료 무시**: direction/ 폴더의 원본 문서 항상 참고

---

## 체크리스트

프로젝트 시작 시:

- [ ] direction/ 폴더에 참고 문서 저장
- [ ] 문서 구조 분석 노트 작성
- [ ] Domains/[프로젝트명].idr 생성
- [ ] Layer 1-4 순서대로 타입 정의
- [ ] 타입 체크 통과 확인
- [ ] 구체적 데이터 인스턴스 작성
- [ ] Documentable 인스턴스 구현
- [ ] 파이프라인 생성
- [ ] 문서 생성 테스트
- [ ] Git 커밋

---

## 참고 예제

- `Domains/ScaleDeep.idr`: 완전한 용역계약서 모델
- `Domains/ApprovalNarrative.idr`: 사전승인 신청서 모델
- `docs/MODELING_GUIDE.md`: 상세 모델링 가이드
