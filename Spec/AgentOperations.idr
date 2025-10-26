module Spec.AgentOperations

import Spec.WorkflowTypes

------------------------------------------------------------
-- 에이전트 작업 타입 명세
-- 목적: LangGraph 에이전트의 작업을 타입으로 정의
------------------------------------------------------------

------------------------------------------------------------
-- 1. 에이전트 작업 결과 타입
------------------------------------------------------------

public export
data AgentResult : Type -> Type where
  Success : a -> AgentResult a
  Failure : ErrorMsg -> AgentResult a

public export
Functor AgentResult where
  map f (Success x) = Success (f x)
  map f (Failure msg) = Failure msg

public export
Applicative AgentResult where
  pure = Success
  (Success f) <*> (Success x) = Success (f x)
  (Failure msg) <*> _ = Failure msg
  _ <*> (Failure msg) = Failure msg

public export
Monad AgentResult where
  (Success x) >>= f = f x
  (Failure msg) >>= _ = Failure msg

------------------------------------------------------------
-- 2. 문서 분석 작업
------------------------------------------------------------

-- 분석 입력
public export
record AnalysisInput where
  constructor MkAnalysisInput
  userPrompt : UserPrompt
  referenceDocs : List FilePath

-- 분석 출력
public export
record AnalysisOutput where
  constructor MkAnalysisOutput
  documentType : String       -- "contract", "approval", etc.
  fields : List (String, String)  -- 필드 목록
  invariants : List String    -- 불변식 목록
  structure : String          -- 계층 구조

public export
Show AnalysisOutput where
  show output = output.structure

-- 분석 작업 타입
public export
AnalyzeDocument : Type
AnalyzeDocument = AnalysisInput -> AgentResult AnalysisOutput

------------------------------------------------------------
-- 3. Idris2 명세 생성 작업
------------------------------------------------------------

-- 명세 생성 입력
public export
record SpecGenerationInput where
  constructor MkSpecGenInput
  projectName : ProjectName
  analysis : AnalysisOutput

-- 명세 생성 출력
public export
record SpecGenerationOutput where
  constructor MkSpecGenOutput
  specCode : String
  specFilePath : FilePath

-- 명세 생성 작업 타입
public export
GenerateSpec : Type
GenerateSpec = SpecGenerationInput -> AgentResult SpecGenerationOutput

------------------------------------------------------------
-- 4. 컴파일 작업
------------------------------------------------------------

-- 컴파일 입력
public export
record CompileInput where
  constructor MkCompileInput
  filePath : FilePath

-- 컴파일 출력
public export
record CompileOutput where
  constructor MkCompileOutput
  success : Bool
  errorMsg : Maybe ErrorMsg
  attempts : Nat

-- 컴파일 작업 타입
public export
CompileIdris : Type
CompileIdris = CompileInput -> AgentResult CompileOutput

------------------------------------------------------------
-- 5. 에러 수정 작업
------------------------------------------------------------

-- 에러 수정 입력
public export
record FixErrorInput where
  constructor MkFixErrorInput
  originalCode : String
  errorMsg : ErrorMsg
  attempt : Nat

-- 에러 수정 출력
public export
record FixErrorOutput where
  constructor MkFixErrorOutput
  fixedCode : String
  explanation : String

-- 에러 수정 작업 타입
public export
FixError : Type
FixError = FixErrorInput -> AgentResult FixErrorOutput

------------------------------------------------------------
-- 6. Documentable 구현 생성 작업
------------------------------------------------------------

-- Documentable 생성 입력
public export
record DocumentableGenInput where
  constructor MkDocGenInput
  projectName : ProjectName
  specCode : String

-- Documentable 생성 출력
public export
record DocumentableGenOutput where
  constructor MkDocGenOutput
  documentableCode : String
  targetFile : FilePath  -- Core/DomainToDoc.idr

-- Documentable 생성 작업 타입
public export
GenerateDocumentable : Type
GenerateDocumentable = DocumentableGenInput -> AgentResult DocumentableGenOutput

------------------------------------------------------------
-- 7. 파이프라인 생성 작업
------------------------------------------------------------

-- 파이프라인 생성 입력
public export
record PipelineGenInput where
  constructor MkPipelineGenInput
  projectName : ProjectName
  specCode : String

-- 파이프라인 생성 출력
public export
record PipelineGenOutput where
  constructor MkPipelineGenOutput
  pipelineCode : String
  targetFile : FilePath  -- Core/Generator.idr

-- 파이프라인 생성 작업 타입
public export
GeneratePipeline : Type
GeneratePipeline = PipelineGenInput -> AgentResult PipelineGenOutput

------------------------------------------------------------
-- 8. 초안 생성 작업
------------------------------------------------------------

-- 초안 생성 입력
public export
record DraftGenInput where
  constructor MkDraftGenInput
  projectName : ProjectName
  outputFormat : OutputFormat

-- 초안 생성 출력
public export
record DraftGenOutput where
  constructor MkDraftGenOutput
  content : String
  filePath : FilePath

-- 초안 생성 작업 타입
public export
GenerateDraft : Type
GenerateDraft = DraftGenInput -> AgentResult DraftGenOutput

------------------------------------------------------------
-- 9. 피드백 파싱 작업
------------------------------------------------------------

-- 피드백 파싱 입력
public export
record FeedbackInput where
  constructor MkFeedbackInput
  userFeedback : String
  currentSpec : String

-- 피드백 파싱 출력
public export
record FeedbackOutput where
  constructor MkFeedbackOutput
  modifications : List (String, String)  -- (field, new_value)
  updatedRequirements : String

-- 피드백 파싱 작업 타입
public export
ParseFeedback : Type
ParseFeedback = FeedbackInput -> AgentResult FeedbackOutput

------------------------------------------------------------
-- 10. 전체 에이전트 작업 묶음
------------------------------------------------------------

public export
record AgentOperations where
  constructor MkAgentOps
  analyzeDocument : AnalyzeDocument
  generateSpec : GenerateSpec
  compileIdris : CompileIdris
  fixError : FixError
  generateDocumentable : GenerateDocumentable
  generatePipeline : GeneratePipeline
  generateDraft : GenerateDraft
  parseFeedback : ParseFeedback

------------------------------------------------------------
-- 11. 에이전트 작업 실행 헬퍼
------------------------------------------------------------

-- 결과 추출 (실패 시 기본값)
public export
getResultOr : AgentResult a -> a -> a
getResultOr (Success x) _ = x
getResultOr (Failure _) def = def

-- 결과가 성공인지 확인
public export
isSuccess : AgentResult a -> Bool
isSuccess (Success _) = True
isSuccess (Failure _) = False

-- 에러 메시지 추출
public export
getErrorMsg : AgentResult a -> Maybe ErrorMsg
getErrorMsg (Success _) = Nothing
getErrorMsg (Failure msg) = Just msg
