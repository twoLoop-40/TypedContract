module Core.Generator

import Core.DocumentModel
import Core.DomainToDoc
import Core.LaTeXRenderer
import Domains.ScaleDeep

------------------------------------------------------------
-- PDF 문서 생성 파이프라인 명세 및 구현
-- 목적: 도메인 모델 → 문서 모델 → LaTeX → PDF 전체 과정
------------------------------------------------------------

------------------------------------------------------------
-- 1. 생성 파이프라인 타입
------------------------------------------------------------

public export
record GenerationPipeline (a : Type) where
  constructor MkPipeline
  domainModel : a                    -- 입력: 도메인 모델
  documentModel : Document           -- 중간: 문서 모델
  latexOutput : LaTeXDocument        -- 출력: LaTeX 문서
  outputPath : String                -- 파일 경로


------------------------------------------------------------
-- 2. 파이프라인 생성 (타입 안전)
------------------------------------------------------------

-- Documentable 타입에 대해서만 파이프라인 생성 가능
public export
createPipeline : Documentable a => a -> String -> GenerationPipeline a
createPipeline domain path =
  let doc = toDocument domain
      latex = renderDocument doc
  in MkPipeline domain doc latex path


------------------------------------------------------------
-- 3. 파이프라인 실행 상태
------------------------------------------------------------

public export
data PipelineStage
  = DomainParsed          -- 도메인 모델 파싱 완료
  | DocumentGenerated     -- 문서 모델 생성 완료
  | LaTeXRendered         -- LaTeX 렌더링 완료
  | FileWritten           -- 파일 쓰기 완료
  | PDFCompiled           -- PDF 컴파일 완료

public export
Show PipelineStage where
  show DomainParsed = "Domain model parsed"
  show DocumentGenerated = "Document model generated"
  show LaTeXRendered = "LaTeX rendered"
  show FileWritten = "File written"
  show PDFCompiled = "PDF compiled"


------------------------------------------------------------
-- 4. 실행 결과 타입
------------------------------------------------------------

public export
data GenerationResult
  = Success String              -- 성공: 파일 경로
  | PartialSuccess String       -- 부분 성공: LaTeX만 생성
  | Failure String              -- 실패: 에러 메시지

public export
Show GenerationResult where
  show (Success path) = "Success: " ++ path
  show (PartialSuccess path) = "Partial success (LaTeX only): " ++ path
  show (Failure msg) = "Failure: " ++ msg


------------------------------------------------------------
-- 5. 파이프라인 검증
------------------------------------------------------------

public export
validatePipeline : GenerationPipeline a -> Bool
validatePipeline pipeline =
  validDocument pipeline.documentModel &&
  nonEmptyLatex pipeline.latexOutput &&
  pipeline.outputPath /= ""


------------------------------------------------------------
-- 6. 구체적인 파이프라인 인스턴스
------------------------------------------------------------

-- ServiceContract → PDF 파이프라인
public export
serviceContractPipeline : ServiceContract -> String -> GenerationPipeline ServiceContract
serviceContractPipeline = createPipeline

-- TaskSpec → PDF 파이프라인
public export
taskSpecPipeline : TaskSpec -> String -> GenerationPipeline TaskSpec
taskSpecPipeline = createPipeline

-- Transaction → PDF 파이프라인
public export
transactionPipeline : Transaction -> String -> GenerationPipeline Transaction
transactionPipeline = createPipeline


------------------------------------------------------------
-- 7. 실제 사용 예시 (명세)
------------------------------------------------------------

-- 스피라티 용역계약서 생성 파이프라인
public export
spiratiContractPipeline : GenerationPipeline ServiceContract
spiratiContractPipeline =
  createPipeline serviceContractSpiratiItsEdu "output/용역계약서"

-- 과업명세서 생성 파이프라인
public export
spiratiTaskPipeline : GenerationPipeline TaskSpec
spiratiTaskPipeline =
  createPipeline mathInputSpec "output/과업명세서"

-- 거래명세서 생성 파이프라인
public export
spiratiTransactionPipeline : GenerationPipeline Transaction
spiratiTransactionPipeline =
  createPipeline transactionItsEdu "output/거래명세서"


------------------------------------------------------------
-- 8. LaTeX 소스 파일 생성 함수 (명세)
------------------------------------------------------------

-- IO 작업은 실제 Main.idr에서 구현
-- 여기서는 타입만 명세

public export
GenerateLatexFile : Type
GenerateLatexFile = {a : Type} -> GenerationPipeline a -> IO (Either String String)

public export
CompilePDF : Type
CompilePDF = String -> IO (Either String String)


------------------------------------------------------------
-- 9. 배치 생성 (여러 문서 한번에)
------------------------------------------------------------

public export
record BatchGeneration where
  constructor MkBatch
  contracts : List (GenerationPipeline ServiceContract)
  tasks : List (GenerationPipeline TaskSpec)
  transactions : List (GenerationPipeline Transaction)

public export
spiratiBatch : BatchGeneration
spiratiBatch = MkBatch
  [spiratiContractPipeline]
  [spiratiTaskPipeline]
  [spiratiTransactionPipeline]


------------------------------------------------------------
-- 10. 파이프라인 정보 추출
------------------------------------------------------------

-- 생성될 문서 정보
public export
record GenerationInfo where
  constructor MkGenInfo
  documentTitle : String
  outputPath : String
  elementCount : Nat
  estimatedPages : Nat

public export
pipelineInfo : GenerationPipeline a -> GenerationInfo
pipelineInfo pipeline =
  let doc = pipeline.documentModel
      elemCount = length doc.body
      pages = 1  -- 간단화: 대략적인 페이지 수
  in MkGenInfo
       doc.meta.title
       pipeline.outputPath
       elemCount
       pages
