module Domains.TestFixV1

import Data.String
import Data.Nat

------------------------------------------------------------
-- Layer 1: 기본 데이터 구조
------------------------------------------------------------

public export
record Metadata where
  constructor MkMetadata
  projectName : String
  version : String
  description : String

public export
defaultMetadata : Metadata
defaultMetadata = MkMetadata
  "TestFixV1"
  "1.0.0"
  "기본 도메인 모델 - 문서 분석 대기 중"

------------------------------------------------------------
-- Layer 2: 검증된 타입 (불변식 증명)
------------------------------------------------------------

public export
data NonEmptyString : Type where
  MkNonEmptyString : (value : String)
    -> (nonEmpty : Not (value = ""))
    -> NonEmptyString

public export
data PositiveNat : Type where
  MkPositiveNat : (value : Nat)
    -> (positive : LTE 1 value)
    -> PositiveNat

public export
data ValidatedList : (a : Type) -> Type where
  MkValidatedList : (items : List a)
    -> (minSize : Nat)
    -> (valid : LTE minSize (length items))
    -> ValidatedList a

------------------------------------------------------------
-- Layer 3: 도메인 엔티티
------------------------------------------------------------

public export
record Entity where
  constructor MkEntity
  id : String
  name : String
  description : String

public export
record Placeholder where
  constructor MkPlaceholder
  message : String
  timestamp : String

------------------------------------------------------------
-- Layer 4: 집합 루트
------------------------------------------------------------

public export
record TestFixV1Document where
  constructor MkTestFixV1Document
  metadata : Metadata
  entities : List Entity
  placeholder : Placeholder
  notes : List String

------------------------------------------------------------
-- Layer 5: 구체적 데이터 인스턴스
------------------------------------------------------------

public export
exampleEntity : Entity
exampleEntity = MkEntity
  "entity-001"
  "샘플 엔티티"
  "문서 분석 후 실제 도메인 엔티티로 대체될 예정"

public export
examplePlaceholder : Placeholder
examplePlaceholder = MkPlaceholder
  "문서가 첨부되지 않아 기본 구조만 생성되었습니다"
  "2024-01-01"

public export
exampleTestFixV1Document : TestFixV1Document
exampleTestFixV1Document = MkTestFixV1Document
  defaultMetadata
  [exampleEntity]
  examplePlaceholder
  [ "이 모델은 실제 문서 분석 전 기본 템플릿입니다"
  , "문서를 첨부하면 구체적인 도메인 모델이 생성됩니다"
  , "계약서, 신청서, 명세서 등 다양한 문서 유형을 지원합니다"
  ]

------------------------------------------------------------
-- Layer 6: 유틸리티 함수
------------------------------------------------------------

public export
addEntity : Entity -> TestFixV1Document -> TestFixV1Document
addEntity e doc = { entities := e :: doc.entities } doc

public export
addNote : String -> TestFixV1Document -> TestFixV1Document
addNote note doc = { notes := note :: doc.notes } doc

public export
updateMetadata : Metadata -> TestFixV1Document -> TestFixV1Document
updateMetadata meta doc = { metadata := meta } doc

public export
countEntities : TestFixV1Document -> Nat
countEntities doc = length doc.entities

public export
hasEntities : TestFixV1Document -> Bool
hasEntities doc = case doc.entities of
  [] => False
  _ => True