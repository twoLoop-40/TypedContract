module Spec.RendererExample

import Spec.RendererOperations
import Spec.WorkflowTypes

------------------------------------------------------------
-- 렌더러 사용 예제
-- 목적: 렌더러 명세의 실제 사용 방법 시연
------------------------------------------------------------

------------------------------------------------------------
-- 1. Mock 렌더러 구현
------------------------------------------------------------

-- Mock Text 렌더러
mockRenderText : RenderText
mockRenderText doc =
  MkTextOutput
    (doc.title ++ "\n\n" ++ show doc.bodyElements)
    ("output/" ++ doc.title ++ ".txt")

-- Mock CSV 렌더러
mockRenderCSV : RenderCSV
mockRenderCSV doc =
  MkCSVOutput
    ["Table1,Data1", "Table2,Data2"]
    "Combined,CSV,Data"
    ("output/" ++ doc.title ++ ".csv")

-- Mock Markdown 렌더러
mockRenderMarkdown : RenderMarkdown
mockRenderMarkdown doc =
  MkMarkdownOutput
    ("# " ++ doc.title ++ "\n\n" ++ show doc.bodyElements)
    ("output/" ++ doc.title ++ ".md")

-- Mock LaTeX 렌더러
mockRenderLaTeX : RenderLaTeX
mockRenderLaTeX doc =
  MkLaTeXOutput
    ("\\documentclass{article}\n\\begin{document}\n" ++ doc.title ++ "\n\\end{document}")
    ("output/" ++ doc.title ++ ".tex")

-- Mock PDF 컴파일러
mockCompilePDF : CompilePDF
mockCompilePDF latex =
  MkPDFOutput
    (latex.filePath ++ ".pdf")  -- .tex → .pdf
    True
    Nothing

-- Mock 렌더러 전체
mockRenderers : RendererOperations
mockRenderers = MkRenderers
  mockRenderText
  mockRenderCSV
  mockRenderMarkdown
  mockRenderLaTeX
  mockCompilePDF

------------------------------------------------------------
-- 2. 예제 문서
------------------------------------------------------------

-- 테스트용 문서
exampleDocument : DocumentInput
exampleDocument = MkDocInput
  "SpiratiContract"
  "Claude"
  "2025-10-26"
  "DOC-001"
  ["Heading: Contract", "Para: This is a contract", "Table: Payment Schedule"]

------------------------------------------------------------
-- 3. 예제 1: 단일 포맷 렌더링
------------------------------------------------------------

export
textRenderExample : TextOutput
textRenderExample = mockRenderText exampleDocument

export
csvRenderExample : CSVOutput
csvRenderExample = mockRenderCSV exampleDocument

export
markdownRenderExample : MarkdownOutput
markdownRenderExample = mockRenderMarkdown exampleDocument

------------------------------------------------------------
-- 4. 예제 2: 경량 포맷 렌더링 (txt, csv, md)
------------------------------------------------------------

export
lightweightRenderExample : MultiFormatOutput
lightweightRenderExample =
  renderLightweightFormats mockRenderers exampleDocument

------------------------------------------------------------
-- 5. 예제 3: 모든 포맷 렌더링
------------------------------------------------------------

export
allFormatsExample : MultiFormatOutput
allFormatsExample =
  renderAllFormats mockRenderers exampleDocument

------------------------------------------------------------
-- 6. 예제 4: 사용자 요청에 따른 렌더링
------------------------------------------------------------

export
requestTextExample : MultiFormatOutput
requestTextExample =
  renderByRequest mockRenderers exampleDocument RequestText

export
requestPDFExample : MultiFormatOutput
requestPDFExample =
  renderByRequest mockRenderers exampleDocument RequestPDF

export
requestAllExample : MultiFormatOutput
requestAllExample =
  renderByRequest mockRenderers exampleDocument RequestAll

------------------------------------------------------------
-- 7. 예제 5: 렌더링 결과 검증
------------------------------------------------------------

export
validationExample : List (String, Bool)
validationExample =
  let txtOut = mockRenderText exampleDocument
      csvOut = mockRenderCSV exampleDocument
      mdOut = mockRenderMarkdown exampleDocument
      texOut = mockRenderLaTeX exampleDocument
      pdfOut = mockCompilePDF texOut
  in [ ("Text output valid", validTextOutput txtOut)
     , ("CSV output valid", validCSVOutput csvOut)
     , ("Markdown output valid", validMarkdownOutput mdOut)
     , ("LaTeX output valid", validLaTeXOutput texOut)
     , ("PDF output valid", validPDFOutput pdfOut)
     ]

------------------------------------------------------------
-- 8. 예제 6: MultiFormatOutput 검증
------------------------------------------------------------

export
multiFormatValidationExample : List (String, Bool)
multiFormatValidationExample =
  let lightweight = renderLightweightFormats mockRenderers exampleDocument
      allFormats = renderAllFormats mockRenderers exampleDocument
  in [ ("Lightweight rendering successful", renderingSuccessful lightweight)
     , ("All formats rendering successful", renderingSuccessful allFormats)
     , ("Lightweight has 3 outputs", length (getOutputPaths lightweight) == 3)
     , ("All formats has 4+ outputs", length (getOutputPaths allFormats) >= 4)
     ]

------------------------------------------------------------
-- 9. 예제 7: 렌더링 결과 요약
------------------------------------------------------------

export
renderingSummaryExample : List String
renderingSummaryExample =
  let lightweight = renderLightweightFormats mockRenderers exampleDocument
      allFormats = renderAllFormats mockRenderers exampleDocument
      pdfOnly = renderByRequest mockRenderers exampleDocument RequestPDF
  in [ renderingSummary lightweight
     , renderingSummary allFormats
     , renderingSummary pdfOnly
     ]

------------------------------------------------------------
-- 10. 예제 8: 출력 경로 추출
------------------------------------------------------------

export
outputPathsExample : List (List FilePath)
outputPathsExample =
  let lightweight = renderLightweightFormats mockRenderers exampleDocument
      allFormats = renderAllFormats mockRenderers exampleDocument
  in [ getOutputPaths lightweight
     , getOutputPaths allFormats
     ]

------------------------------------------------------------
-- 11. 사용 시연
------------------------------------------------------------

{-
main : IO ()
main = do
  putStrLn "=== Renderer Type Specification Demo ==="

  -- 예제 1: 경량 포맷 렌더링
  putStrLn "\n[1] Lightweight Formats:"
  let lightweight = renderLightweightFormats mockRenderers exampleDocument
  putStrLn $ renderingSummary lightweight
  traverse_ putStrLn (getOutputPaths lightweight)

  -- 예제 2: 모든 포맷 렌더링
  putStrLn "\n[2] All Formats:"
  let allFormats = renderAllFormats mockRenderers exampleDocument
  putStrLn $ renderingSummary allFormats
  traverse_ putStrLn (getOutputPaths allFormats)

  -- 예제 3: PDF만 생성
  putStrLn "\n[3] PDF Only:"
  let pdfOnly = renderByRequest mockRenderers exampleDocument RequestPDF
  putStrLn $ renderingSummary pdfOnly
  case pdfOnly.pdfOut of
    Just pdf => putStrLn $ "PDF: " ++ pdf.pdfPath
    Nothing => putStrLn "PDF generation failed"

  -- 예제 4: 검증
  putStrLn "\n[4] Validation:"
  traverse_ (\(name, valid) =>
    putStrLn $ name ++ ": " ++ if valid then "✅" else "❌"
  ) validationExample

  putStrLn "\n✅ All examples completed"
-}
