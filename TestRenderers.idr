module TestRenderers

import System.File
import Core.DocumentModel
import Core.DomainToDoc
import Core.LaTeXRenderer
import Core.MarkdownRenderer
import Core.TextRenderer
import Core.CSVRenderer
import Domains.ScaleDeep

------------------------------------------------------------
-- 모든 렌더러 테스트
------------------------------------------------------------

writeTextFile : String -> String -> IO (Either String String)
writeTextFile path content = do
  Right () <- writeFile path content
    | Left err => pure (Left $ "Failed to write file: " ++ show err)
  pure (Right $ "File written: " ++ path)

testAllRenderers : IO ()
testAllRenderers = do
  putStrLn "=== Testing All Renderers ==="
  putStrLn ""

  -- ScaleDeep 계약서를 문서로 변환
  let doc = toDocument serviceContractSpiratiItsEdu

  -- 1. LaTeX 렌더링
  putStrLn "[1/4] LaTeX Renderer"
  let latexDoc = renderDocument doc
  let latexSource = extractSource latexDoc
  Right msg <- writeTextFile "output/test_latex.tex" latexSource
    | Left err => putStrLn $ "ERROR: " ++ err
  putStrLn msg

  -- 2. Markdown 렌더링
  putStrLn "[2/4] Markdown Renderer"
  let mdDoc = MarkdownRenderer.renderDocument doc
  let mdSource = MarkdownRenderer.extractContent mdDoc
  Right msg <- writeTextFile "output/test_markdown.md" mdSource
    | Left err => putStrLn $ "ERROR: " ++ err
  putStrLn msg

  -- 3. Text 렌더링
  putStrLn "[3/4] Text Renderer"
  let textDoc = TextRenderer.renderDocument doc
  let textSource = TextRenderer.extractContent textDoc
  Right msg <- writeTextFile "output/test_text.txt" textSource
    | Left err => putStrLn $ "ERROR: " ++ err
  putStrLn msg

  -- 4. CSV 렌더링
  putStrLn "[4/4] CSV Renderer"
  let csvDoc = CSVRenderer.renderDocument doc
  let csvSource = CSVRenderer.extractCombined csvDoc
  Right msg <- writeTextFile "output/test_csv.csv" csvSource
    | Left err => putStrLn $ "ERROR: " ++ err
  putStrLn msg

  putStrLn ""
  putStrLn "=== All Renderers Tested ==="

main : IO ()
main = testAllRenderers
