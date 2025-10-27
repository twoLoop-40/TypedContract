"""
LangGraph 에이전트용 프롬프트 템플릿
"""

# 문서 분석 프롬프트
ANALYZE_DOCUMENT_PROMPT = """당신은 한국 법률/회계 문서 전문가입니다.

첨부된 문서를 분석하여 Idris2 도메인 모델 작성에 필요한 정보를 추출하세요.

문서 유형: {document_type}
참고 문서: {reference_docs}

다음 형식으로 분석 결과를 작성하세요:

# 문서 분석 결과

## 1. 문서 유형 및 목적
[계약서/신청서/명세서 등]

## 2. 주요 섹션
1. 섹션명
   - 항목들...

## 3. 데이터 필드

### 기본 정보
| 필드명 | 타입 | 예시 | 비고 |
|--------|------|------|------|
| ... | ... | ... | ... |

### 당사자 정보
| 필드명 | 타입 | 예시 | 비고 |
|--------|------|------|------|
| ... | ... | ... | ... |

### 금액 정보
| 필드명 | 타입 | 예시 | 비고 |
|--------|------|------|------|
| 공급가액 | Nat | 50000000 | |
| 부가세 | Nat | 5000000 | 공급가액 × 0.10 |
| 총액 | Nat | 55000000 | 공급가액 + 부가세 |

## 4. 불변식 (Invariants)

계산 규칙:
```
총액 = 공급가액 + 부가세
VAT = 공급가액 × 0.10
단가 × 수량 = 총액
```

날짜 제약:
```
시작일 < 종료일
납품일 ≤ 계약종료일
```

## 5. 반복 구조 (리스트)

- 산출물 목록
- 납품 일정
- 지급 조건
등

## 6. 계층 구조

```
DocumentRoot
├── metadata
├── parties
├── terms
└── amounts
```

중요: 모든 계산 규칙과 제약조건을 명확히 식별하세요. 이것들은 의존 타입으로 증명될 것입니다.
"""


# Idris2 코드 생성 프롬프트
GENERATE_IDRIS_PROMPT = """당신은 Idris2 전문가입니다.

다음 문서 분석 결과를 바탕으로 **완전한 Idris2 도메인 모델**을 작성하세요.

프로젝트명: {project_name}

문서 분석:
```markdown
{analysis}
```

## 요구사항

1. **모듈 구조**
```idris
module Domains.{project_name}
```

**CRITICAL**: 모듈 이름은 반드시 프로젝트 이름과 정확히 일치해야 합니다.
- 프로젝트: `problem_input_v3` → 모듈: `module Domains.problem_input_v3`
- 프로젝트: `my_contract` → 모듈: `module Domains.my_contract`
- ❌ PascalCase 변환 금지 (ProblemInputV3, MyContract 등)

2. **Layer 1: Primitive Types**
```idris
------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Money where
  constructor MkMoney
  value : Nat
  desc : String

-- 필요한 상수들
VATRate : Double
VATRate = 0.10
```

3. **Layer 2: Validated Types with Proofs**

불변식이 있는 타입은 반드시 의존 타입으로:
```idris
------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data UnitPrice : Type where
  MkUnitPrice : (perItem : Nat)
    -> (quantity : Nat)
    -> (totalAmount : Nat)
    -> (validTotal : totalAmount = perItem * quantity)  -- 증명!
    -> UnitPrice

-- Smart constructor
public export
mkUnitPrice : (perItem : Nat) -> (quantity : Nat) -> UnitPrice
mkUnitPrice p q = MkUnitPrice p q (p * q) Refl
```

4. **Layer 3: Domain Entities**
```idris
------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record Party where
  constructor MkParty
  companyName : String
  representative : String
  -- ... 필요한 필드들
```

5. **Layer 4: Aggregate Root**
```idris
------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record {{DocumentName}} where
  constructor Mk{{DocumentName}}
  -- ... 전체 문서 필드들
```

6. **Layer 5: Concrete Instances**
```idris
------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
example{{DocumentName}} : {{DocumentName}}
example{{DocumentName}} = Mk{{DocumentName}}
  -- ... 실제 데이터
```

## 중요 규칙

1. ✅ 모든 타입에 `public export` 사용
2. ✅ 불변식은 의존 타입으로 표현 (`validTotal : totalAmount = perItem * quantity`)
3. ✅ Smart constructor로 증명 자동화 (`Refl` 사용)
4. ✅ 한글 주석으로 의미 설명
5. ✅ List는 `List T` 사용
6. ✅ Tuple은 `(String, String)` 사용
7. ❌ IO 작업 금지 (순수 타입만)
8. ❌ String은 검증 없이 사용 가능 (Date 타입은 나중에)

## 참고 예제

```idris
-- 좋은 예: 의존 타입으로 증명
data ContractAmount : Type where
  MkAmount : (supply : Nat)
    -> (vat : Nat)
    -> (total : Nat)
    -> (proof : total = supply + vat)
    -> ContractAmount

-- 나쁜 예: 검증 함수만 (컴파일 타임에 증명 안됨)
record ContractAmount where
  supply : Nat
  vat : Nat
  total : Nat

validAmount : ContractAmount -> Bool
validAmount a = a.total == a.supply + a.vat
```

**완전하고 타입 체크 가능한 Idris2 코드를 생성하세요.**

출력 형식: 순수 Idris2 코드만 (설명 없이)
"""


# 에러 수정 프롬프트
FIX_ERROR_PROMPT = """다음 Idris2 코드에 컴파일 에러가 발생했습니다.

현재 코드:
```idris
{idris_code}
```

에러 메시지:
```
{error_message}
```

## 에러 분석 및 수정

흔한 Idris2 에러 패턴:

1. **"Can't find an implementation for Show X"**
   → Show 인스턴스 추가:
   ```idris
   Show MyType where
     show x = "MyType"
   ```

2. **"Can't find an implementation for Eq X"**
   → Eq 인스턴스 추가:
   ```idris
   Eq MyType where
     (==) x y = True  -- 적절한 구현
   ```

3. **"Ambiguous elaboration"**
   → 타입 명시 추가 또는 모듈 import 확인

4. **"When unifying A and B"**
   → 타입 불일치, 패턴 매칭 또는 함수 시그니처 확인

5. **"No such variable"**
   → import 누락 또는 변수명 오타

6. **"Can't find namespace"**
   → 모듈 import 추가:
   ```idris
   import Data.String
   import Data.List
   import Data.Nat
   ```

7. **"Can't solve constraint"**
   → 증명이 자동으로 안됨, Refl 대신 수동 증명 필요

## 수정 지침

1. 에러 메시지 정확히 읽기
2. 해당 라인 확인
3. 필요한 import 추가
4. 타입 시그니처 확인
5. 증명 부분 재검토

**수정된 완전한 Idris2 코드를 제공하세요** (설명 없이 코드만)
"""


# 최종 검증 프롬프트
FINAL_REVIEW_PROMPT = """생성된 Idris2 도메인 모델이 타입 체크를 통과했습니다.

파일: {file_path}

최종 검토:

1. ✅ 모든 불변식이 의존 타입으로 표현되었나?
2. ✅ public export가 필요한 곳에 사용되었나?
3. ✅ Smart constructor가 제공되나?
4. ✅ 구체적 데이터 인스턴스가 있나?
5. ✅ 한글 주석이 충분한가?

코드 품질: {quality_score}/10

다음 단계:
- Core/DomainToDoc.idr에 Documentable 인스턴스 추가
- Core/Generator.idr에 파이프라인 생성
- Main.idr에서 실행
"""


# Documentable 인스턴스 생성 프롬프트 (Phase 5)
GENERATE_DOCUMENTABLE_PROMPT = """당신은 Idris2 전문가입니다.

다음 도메인 모델에 대한 **Documentable 인스턴스**를 생성하세요.

프로젝트명: {project_name}

도메인 모델 코드:
```idris
{domain_code}
```

## 요구사항

1. **모듈 구조**
```idris
module DomainToDoc.{project_name}

import Core.DocumentModel
import Domains.{project_name}
import Data.List
```

2. **헬퍼 함수들**

도메인의 각 레코드 타입을 DocElement로 변환하는 헬퍼 함수를 작성하세요:

```idris
------------------------------------------------------------
-- 헬퍼 함수: 각 타입 → DocElement
------------------------------------------------------------

-- Party 정보를 DocElement로 변환 (있다면)
partyToElements : String -> Party -> List DocElement
partyToElements role party =
  [ Heading 3 ("[" ++ role ++ "]")
  , Para ("회 사 명: " ++ party.companyName)
  , Para ("대 표 자: " ++ party.representative)
  -- ... 필요한 필드들
  , VSpace 5
  ]

-- 다른 복합 타입들도 변환 함수 작성
```

3. **Documentable 인스턴스**

메인 도메인 타입(예: ServiceContract, ApprovalForm 등)에 대한 Documentable 인스턴스:

```idris
------------------------------------------------------------
-- Documentable 인스턴스
------------------------------------------------------------

public export
Documentable {{MainDomainType}} where
  toDocument obj =
    let
      -- 헤더
      header =
        [ Heading 1 "{문서 제목}"
        , VSpace 5
        , Para ("번호: " ++ obj.documentNumber)
        , Para ("날짜: " ++ obj.date)
        , VSpace 10
        ]

      -- 본문 섹션들
      body =
        [ Heading 2 "제1절"
        , Para "내용..."
        -- ... 문서 구조에 맞게
        ]

      -- 전체 본문
      fullBody = header ++ body

      -- 메타데이터
      metadata = MkMetadata
        "{문서 제목}"
        "{작성자}"
        "{날짜}"
        "{문서 번호}"

    in MkDoc metadata fullBody
```

## 참고: Core/DomainToDoc.idr 예제

ServiceContract의 Documentable 구현을 참고하세요:

```idris
Documentable ServiceContract where
  toDocument sc =
    let
      header = [ Heading 1 "용 역 계 약 서", VSpace 5, ... ]
      preamble = [ Para (sc.client.companyName ++ "..."), ... ]
      articles = termsToArticles sc.terms
      closing = [ VSpace 10, Para "본 계약의 성립을...", ... ]
      parties = partyToElements "갑" sc.client ++ partyToElements "을" sc.contractor
      fullBody = header ++ preamble ++ articles ++ closing ++ parties
      metadata = MkMetadata "용역계약서" ...
    in MkDoc metadata fullBody
```

## 중요 규칙

1. ✅ 모든 함수에 `public export` 사용
2. ✅ 문서 구조는 논리적으로 구성 (헤더 → 본문 → 결어 → 당사자)
3. ✅ VSpace로 적절한 여백 추가
4. ✅ Heading 레벨 올바르게 사용 (1=제목, 2=섹션, 3=항목)
5. ✅ 리스트는 OrderedList, BulletList 활용
6. ✅ 표가 필요하면 SimpleTable 사용
7. ✅ PageBreak로 페이지 구분 (필요시)

**완전하고 타입 체크 가능한 Idris2 코드를 생성하세요.**

출력 형식: 순수 Idris2 코드만 (설명 없이)
"""


# 파이프라인 생성 프롬프트 (Phase 5)
GENERATE_PIPELINE_PROMPT = """당신은 Idris2 전문가입니다.

다음 프로젝트에 대한 **실행 가능한 파이프라인**을 생성하세요.

프로젝트명: {project_name}

## 요구사항

1. **모듈 구조**
```idris
module Pipeline.{project_name}

import Domains.{project_name}
import DomainToDoc.{project_name}
import Core.DocumentModel
import Core.TextRenderer
import Core.CSVRenderer
import Core.MarkdownRenderer
import Core.LaTeXRenderer
```

2. **렌더링 함수들**

```idris
------------------------------------------------------------
-- 렌더러 실행
------------------------------------------------------------

-- Text 렌더링
public export
generateText : {{MainDomainType}} -> String
generateText obj =
  let doc = toDocument obj
  in renderText doc

-- CSV 렌더링
public export
generateCSV : {{MainDomainType}} -> String
generateCSV obj =
  let doc = toDocument obj
  in renderCSV doc

-- Markdown 렌더링
public export
generateMarkdown : {{MainDomainType}} -> String
generateMarkdown obj =
  let doc = toDocument obj
  in renderMarkdown doc

-- LaTeX 렌더링
public export
generateLaTeX : {{MainDomainType}} -> String
generateLaTeX obj =
  let doc = toDocument obj
      latexDoc = renderDocument doc
  in extractSource latexDoc
```

3. **구체적 인스턴스 사용**

도메인 모델에 정의된 구체적 인스턴스(예: `exampleContract`, `sampleForm`)를 사용:

```idris
------------------------------------------------------------
-- 구체적 인스턴스 렌더링
------------------------------------------------------------

public export
exampleText : String
exampleText = generateText example{{MainDomainType}}

public export
exampleCSV : String
exampleCSV = generateCSV example{{MainDomainType}}

public export
exampleMarkdown : String
exampleMarkdown = generateMarkdown example{{MainDomainType}}

public export
exampleLaTeX : String
exampleLaTeX = generateLaTeX example{{MainDomainType}}
```

## 참고 예제

Core/Generator.idr의 파이프라인 구조를 참고하세요.

**완전하고 실행 가능한 Idris2 코드를 생성하세요.**

출력 형식: 순수 Idris2 코드만 (설명 없이)
"""
