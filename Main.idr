module Main

import System.File
import Generator
import LaTeXRenderer
import Domains.ScaleDeep

------------------------------------------------------------
-- 실제 파일 생성 구현
-- 목적: 명세를 실행 가능한 프로그램으로 만들기
------------------------------------------------------------

------------------------------------------------------------
-- 1. LaTeX 파일 저장
------------------------------------------------------------

writeLatexFile : GenerationPipeline a -> IO (Either String String)
writeLatexFile pipeline = do
  let texPath = pipeline.outputPath ++ ".tex"
  let source = extractSource pipeline.latexOutput
  Right () <- writeFile texPath source
    | Left err => pure (Left $ "Failed to write file: " ++ show err)
  pure (Right $ "LaTeX file written: " ++ texPath)


------------------------------------------------------------
-- 2. PDF 컴파일 (pdflatex 호출)
------------------------------------------------------------

compilePDF : String -> IO (Either String String)
compilePDF texPath = do
  -- TODO: system 함수로 pdflatex 실행
  -- system $ "pdflatex " ++ texPath
  pure (Right $ "PDF would be compiled from: " ++ texPath)


------------------------------------------------------------
-- 3. 전체 파이프라인 실행
------------------------------------------------------------

executePipeline : GenerationPipeline a -> IO ()
executePipeline pipeline = do
  putStrLn "=== PDF Generation Pipeline ==="
  putStrLn $ "Output: " ++ pipeline.outputPath

  -- 1단계: LaTeX 파일 쓰기
  putStrLn "[1/2] Writing LaTeX file..."
  Right msg <- writeLatexFile pipeline
    | Left err => do
        putStrLn $ "ERROR: " ++ err
        pure ()
  putStrLn msg

  -- 2단계: PDF 컴파일
  putStrLn "[2/2] Compiling PDF..."
  Right pdfMsg <- compilePDF (pipeline.outputPath ++ ".tex")
    | Left err => do
        putStrLn $ "ERROR: " ++ err
        pure ()
  putStrLn pdfMsg

  putStrLn "=== Generation Complete ==="


------------------------------------------------------------
-- 4. 배치 실행
------------------------------------------------------------

executeBatch : BatchGeneration -> IO ()
executeBatch batch = do
  putStrLn "=== Batch Generation Started ==="

  putStrLn "\n--- Generating Contracts ---"
  traverse_ executePipeline batch.contracts

  putStrLn "\n--- Generating Task Specs ---"
  traverse_ executePipeline batch.tasks

  putStrLn "\n--- Generating Transactions ---"
  traverse_ executePipeline batch.transactions

  putStrLn "\n=== Batch Generation Complete ==="


------------------------------------------------------------
-- 5. 메인 함수
------------------------------------------------------------

main : IO ()
main = do
  putStrLn "ScaleDeep Document Generator"
  putStrLn "============================\n"

  -- 개별 파이프라인 실행
  executePipeline spiratiContractPipeline

  -- 또는 배치 실행
  -- executeBatch spiratiBatch


------------------------------------------------------------
-- 6. 헬퍼: 파이프라인 정보 출력
------------------------------------------------------------

showPipelineInfo : GenerationPipeline a -> IO ()
showPipelineInfo pipeline = do
  let info = pipelineInfo pipeline
  putStrLn "Document Information:"
  putStrLn $ "  Title: " ++ info.documentTitle
  putStrLn $ "  Output: " ++ info.outputPath
  putStrLn $ "  Elements: " ++ show info.elementCount
  putStrLn $ "  Estimated Pages: " ++ show info.estimatedPages
