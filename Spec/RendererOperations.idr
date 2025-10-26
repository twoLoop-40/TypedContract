module Spec.RendererOperations

import Spec.WorkflowTypes

------------------------------------------------------------
-- 렌더러 작업 타입 명세
-- 목적: 문서 렌더링 작업을 타입으로 정의
-- 특징: Agent가 아닌 순수 함수 (컴파일 타임 검증)
------------------------------------------------------------

------------------------------------------------------------
-- 1. 렌더러 출력 타입
------------------------------------------------------------

-- Text 렌더링 결과
public export
record TextOutput where
  constructor MkTextOutput
  content : String
  filePath : FilePath

-- CSV 렌더링 결과
public export
record CSVOutput where
  constructor MkCSVOutput
  tables : List String      -- 각 테이블을 별도 CSV로
  combined : String         -- 모든 테이블을 하나로 결합
  filePath : FilePath

-- Markdown 렌더링 결과
public export
record MarkdownOutput where
  constructor MkMarkdownOutput
  content : String
  filePath : FilePath

-- LaTeX 렌더링 결과
public export
record LaTeXOutput where
  constructor MkLaTeXOutput
  source : String
  filePath : FilePath

-- PDF 생성 결과
public export
record PDFOutput where
  constructor MkPDFOutput
  pdfPath : FilePath
  success : Bool
  errorMsg : Maybe ErrorMsg

------------------------------------------------------------
-- 2. 문서 추상 타입 (Generic Document)
------------------------------------------------------------

-- 렌더러가 받는 입력 문서의 추상 표현
-- 실제 구현은 Core.DocumentModel의 Document
public export
record DocumentInput where
  constructor MkDocInput
  title : String
  author : String
  date : String
  docNumber : String
  bodyElements : List String  -- 실제로는 List DocElement

------------------------------------------------------------
-- 3. 렌더러 타입 시그니처
------------------------------------------------------------

-- Text 렌더러
public export
RenderText : Type
RenderText = DocumentInput -> TextOutput

-- CSV 렌더러
public export
RenderCSV : Type
RenderCSV = DocumentInput -> CSVOutput

-- Markdown 렌더러
public export
RenderMarkdown : Type
RenderMarkdown = DocumentInput -> MarkdownOutput

-- LaTeX 렌더러
public export
RenderLaTeX : Type
RenderLaTeX = DocumentInput -> LaTeXOutput

-- PDF 생성 (LaTeX 컴파일)
public export
CompilePDF : Type
CompilePDF = LaTeXOutput -> PDFOutput

------------------------------------------------------------
-- 4. 전체 렌더러 묶음
------------------------------------------------------------

public export
record RendererOperations where
  constructor MkRenderers
  renderText : RenderText
  renderCSV : RenderCSV
  renderMarkdown : RenderMarkdown
  renderLaTeX : RenderLaTeX
  compilePDF : CompilePDF

------------------------------------------------------------
-- 5. 렌더러 출력 검증
------------------------------------------------------------

-- Text 출력이 유효한지 확인
public export
validTextOutput : TextOutput -> Bool
validTextOutput output = length output.content > 0

-- CSV 출력이 유효한지 확인
public export
validCSVOutput : CSVOutput -> Bool
validCSVOutput output = length output.tables > 0 || length output.combined > 0

-- Markdown 출력이 유효한지 확인
public export
validMarkdownOutput : MarkdownOutput -> Bool
validMarkdownOutput output = length output.content > 0

-- LaTeX 출력이 유효한지 확인
public export
validLaTeXOutput : LaTeXOutput -> Bool
validLaTeXOutput output =
  length output.source > 0 &&
  length output.filePath > 0

-- PDF 출력이 성공했는지 확인
public export
validPDFOutput : PDFOutput -> Bool
validPDFOutput output =
  output.success &&
  length output.pdfPath > 0

------------------------------------------------------------
-- 6. 렌더러 체이닝 (Pipeline)
------------------------------------------------------------

-- Document → Multiple Formats
public export
record MultiFormatOutput where
  constructor MkMultiFormat
  textOut : Maybe TextOutput
  csvOut : Maybe CSVOutput
  markdownOut : Maybe MarkdownOutput
  latexOut : Maybe LaTeXOutput
  pdfOut : Maybe PDFOutput

-- 모든 포맷으로 렌더링
public export
renderAllFormats : RendererOperations -> DocumentInput -> MultiFormatOutput
renderAllFormats renderers doc =
  MkMultiFormat
    (Just $ renderers.renderText doc)
    (Just $ renderers.renderCSV doc)
    (Just $ renderers.renderMarkdown doc)
    (Just $ renderers.renderLaTeX doc)
    Nothing  -- PDF는 별도로 생성

-- Lightweight 포맷만 (txt, csv, md)
public export
renderLightweightFormats : RendererOperations -> DocumentInput -> MultiFormatOutput
renderLightweightFormats renderers doc =
  MkMultiFormat
    (Just $ renderers.renderText doc)
    (Just $ renderers.renderCSV doc)
    (Just $ renderers.renderMarkdown doc)
    Nothing
    Nothing

------------------------------------------------------------
-- 7. 출력 형식 선택
------------------------------------------------------------

-- 사용자가 요청한 출력 형식
public export
data RequestedFormat
  = RequestText
  | RequestCSV
  | RequestMarkdown
  | RequestLaTeX
  | RequestPDF
  | RequestAll

public export
Eq RequestedFormat where
  RequestText == RequestText = True
  RequestCSV == RequestCSV = True
  RequestMarkdown == RequestMarkdown = True
  RequestLaTeX == RequestLaTeX = True
  RequestPDF == RequestPDF = True
  RequestAll == RequestAll = True
  _ == _ = False

public export
Show RequestedFormat where
  show RequestText = "Text (.txt)"
  show RequestCSV = "CSV (.csv)"
  show RequestMarkdown = "Markdown (.md)"
  show RequestLaTeX = "LaTeX (.tex)"
  show RequestPDF = "PDF (.pdf)"
  show RequestAll = "All formats"

-- 요청된 형식에 따라 렌더링
public export
renderByRequest : RendererOperations
  -> DocumentInput
  -> RequestedFormat
  -> MultiFormatOutput
renderByRequest renderers doc RequestText =
  MkMultiFormat (Just $ renderers.renderText doc) Nothing Nothing Nothing Nothing
renderByRequest renderers doc RequestCSV =
  MkMultiFormat Nothing (Just $ renderers.renderCSV doc) Nothing Nothing Nothing
renderByRequest renderers doc RequestMarkdown =
  MkMultiFormat Nothing Nothing (Just $ renderers.renderMarkdown doc) Nothing Nothing
renderByRequest renderers doc RequestLaTeX =
  MkMultiFormat Nothing Nothing Nothing (Just $ renderers.renderLaTeX doc) Nothing
renderByRequest renderers doc RequestPDF =
  let latex = renderers.renderLaTeX doc
      pdf = renderers.compilePDF latex
  in MkMultiFormat Nothing Nothing Nothing (Just latex) (Just pdf)
renderByRequest renderers doc RequestAll =
  renderAllFormats renderers doc

------------------------------------------------------------
-- 8. 렌더러 실행 헬퍼
------------------------------------------------------------

-- 렌더러가 성공했는지 확인
public export
renderingSuccessful : MultiFormatOutput -> Bool
renderingSuccessful output =
  isJust output.textOut ||
  isJust output.csvOut ||
  isJust output.markdownOut ||
  isJust output.latexOut ||
  (isJust output.pdfOut && maybe False validPDFOutput output.pdfOut)

-- 생성된 파일 경로 목록
public export
getOutputPaths : MultiFormatOutput -> List FilePath
getOutputPaths output =
  let paths = []
      paths = case output.textOut of
        Just txt => txt.filePath :: paths
        Nothing => paths
      paths = case output.csvOut of
        Just csv => csv.filePath :: paths
        Nothing => paths
      paths = case output.markdownOut of
        Just md => md.filePath :: paths
        Nothing => paths
      paths = case output.latexOut of
        Just tex => tex.filePath :: paths
        Nothing => paths
      paths = case output.pdfOut of
        Just pdf => pdf.pdfPath :: paths
        Nothing => paths
  in paths

-- 렌더링 결과 요약
public export
renderingSummary : MultiFormatOutput -> String
renderingSummary output =
  let count = length (getOutputPaths output)
      formats = []
      formats = if isJust output.textOut then "txt" :: formats else formats
      formats = if isJust output.csvOut then "csv" :: formats else formats
      formats = if isJust output.markdownOut then "md" :: formats else formats
      formats = if isJust output.latexOut then "tex" :: formats else formats
      formats = if isJust output.pdfOut then "pdf" :: formats else formats
  in "Generated " ++ show count ++ " files: " ++ show formats
