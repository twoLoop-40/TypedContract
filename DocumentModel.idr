module DocumentModel

------------------------------------------------------------
-- 범용 문서 모델 타입 명세
-- 목적: 모든 종류의 문서를 표현할 수 있는 추상 구조
------------------------------------------------------------

------------------------------------------------------------
-- 1. 기본 문서 요소 (Primitive Elements)
------------------------------------------------------------

public export
data Alignment = LeftAlign | CenterAlign | RightAlign | Justify

public export
record TextStyle where
  constructor MkTextStyle
  bold : Bool
  italic : Bool
  fontSize : Nat

public export
defaultStyle : TextStyle
defaultStyle = MkTextStyle False False 12


------------------------------------------------------------
-- 2. 문서 요소 (Document Elements)
------------------------------------------------------------

public export
data DocElement : Type where
  -- 텍스트
  Text : String -> DocElement
  StyledText : String -> TextStyle -> DocElement
  Para : String -> DocElement

  -- 제목
  Heading : Nat -> String -> DocElement  -- 레벨, 내용

  -- 리스트
  BulletList : List String -> DocElement
  OrderedList : List String -> DocElement

  -- 표
  SimpleTable : List (List String) -> DocElement

  -- 레이아웃
  HRule : DocElement  -- 수평선
  VSpace : Nat -> DocElement  -- 세로 공백 (mm)
  PageBreak : DocElement

  -- 컨테이너
  Section : String -> List DocElement -> DocElement
  Box : List DocElement -> DocElement


------------------------------------------------------------
-- 3. 문서 메타데이터
------------------------------------------------------------

public export
record Metadata where
  constructor MkMetadata
  title : String
  author : String
  date : String
  docNumber : String


------------------------------------------------------------
-- 4. 문서 전체 구조
------------------------------------------------------------

public export
record Document where
  constructor MkDoc
  meta : Metadata
  body : List DocElement


------------------------------------------------------------
-- 5. 문서 검증
------------------------------------------------------------

public export
hasTitle : Document -> Bool
hasTitle doc = doc.meta.title /= ""

public export
hasBody : Document -> Bool
hasBody doc = case doc.body of
  [] => False
  _ => True

public export
validDocument : Document -> Bool
validDocument doc = hasTitle doc && hasBody doc
