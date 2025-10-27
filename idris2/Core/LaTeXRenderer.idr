module Core.LaTeXRenderer

import Core.DocumentModel
import Data.List
import Data.String

------------------------------------------------------------
-- LaTeX 렌더러 명세 및 구현
-- 목적: Document를 LaTeX 코드로 변환
------------------------------------------------------------

------------------------------------------------------------
-- 1. LaTeX 문서 타입
------------------------------------------------------------

public export
record LaTeXDocument where
  constructor MkLaTeX
  source : String


------------------------------------------------------------
-- 2. LaTeX 헬퍼 함수들
------------------------------------------------------------

-- LaTeX 특수문자 이스케이프
escapeChar : Char -> String
escapeChar '&' = "\\&"
escapeChar '%' = "\\%"
escapeChar '$' = "\\$"
escapeChar '#' = "\\#"
escapeChar '_' = "\\_"
escapeChar '{' = "\\{"
escapeChar '}' = "\\}"
escapeChar '~' = "\\textasciitilde{}"
escapeChar '^' = "\\textasciicircum{}"
escapeChar '\\' = "\\textbackslash{}"
escapeChar c = singleton c

public export
escapeLatex : String -> String
escapeLatex s = concat (map escapeChar (unpack s))

-- 들여쓰기
public export
indent : Nat -> String -> String
indent n s = pack (replicate n ' ') ++ s


------------------------------------------------------------
-- 3. DocElement → LaTeX 변환
------------------------------------------------------------

public export
renderElement : DocElement -> String
renderElement (Text s) = escapeLatex s ++ "\n\n"
renderElement (StyledText s style) =
  (if style.bold then "\\textbf{" else "") ++
  (if style.italic then "\\textit{" else "") ++
  escapeLatex s ++
  (if style.italic then "}" else "") ++
  (if style.bold then "}" else "") ++
  "\n\n"
renderElement (Para s) = escapeLatex s ++ "\n\n"
renderElement (Heading 1 title) =
  "\\begin{center}\n" ++
  "{\\LARGE \\textbf{" ++ escapeLatex title ++ "}}\n" ++
  "\\end{center}\n\n"
renderElement (Heading 2 title) =
  "\\section*{" ++ escapeLatex title ++ "}\n\n"
renderElement (Heading 3 title) =
  "\\subsection*{" ++ escapeLatex title ++ "}\n\n"
renderElement (Heading _ title) =
  "\\textbf{" ++ escapeLatex title ++ "}\n\n"
renderElement (BulletList items) =
  "\\begin{itemize}\n" ++
  concat (map (\x => "  \\item " ++ escapeLatex x ++ "\n") items) ++
  "\\end{itemize}\n\n"
renderElement (OrderedList items) =
  "\\begin{enumerate}\n" ++
  concat (map (\x => "  \\item " ++ escapeLatex x ++ "\n") items) ++
  "\\end{enumerate}\n\n"
renderElement (SimpleTable rows) =
  let cols = case rows of
               [] => 0
               (r :: _) => length r
      colSpec = pack (replicate cols 'l')
  in "\\begin{tabular}{" ++ colSpec ++ "}\n" ++
     "\\hline\n" ++
     concat (map (\row => concat (intersperse " & " (map escapeLatex row)) ++ " \\\\\n") rows) ++
     "\\hline\n" ++
     "\\end{tabular}\n\n"
renderElement HRule =
  "\\noindent\\rule{\\textwidth}{0.4pt}\n\n"
renderElement (VSpace n) =
  "\\vspace{" ++ show n ++ "mm}\n\n"
renderElement PageBreak =
  "\\newpage\n\n"
renderElement (Section title content) =
  "\\subsection*{" ++ escapeLatex title ++ "}\n\n" ++
  concat (map renderElement content)
renderElement (Box content) =
  "\\begin{center}\n" ++
  "\\fbox{\\begin{minipage}{0.9\\textwidth}\n" ++
  concat (map renderElement content) ++
  "\\end{minipage}}\n" ++
  "\\end{center}\n\n"


------------------------------------------------------------
-- 4. Document → LaTeX 변환
------------------------------------------------------------

public export
latexPreamble : String
latexPreamble =
  "\\documentclass[12pt,a4paper]{article}\n" ++
  "\\usepackage{kotex}\n" ++
  "\\usepackage[margin=25mm]{geometry}\n" ++
  "\\usepackage{fancyhdr}\n" ++
  "\\usepackage{enumitem}\n" ++
  "\\setlength{\\parindent}{0pt}\n" ++
  "\\setlength{\\parskip}{1em}\n" ++
  "\n"

public export
renderDocument : Document -> LaTeXDocument
renderDocument doc =
  let
    body = concat (map renderElement doc.body)
    fullSource = latexPreamble ++
                 "\\begin{document}\n\n" ++
                 body ++
                 "\\end{document}\n"
  in MkLaTeX fullSource


------------------------------------------------------------
-- 5. LaTeX 문서 저장
------------------------------------------------------------

-- LaTeX 소스 추출
public export
extractSource : LaTeXDocument -> String
extractSource (MkLaTeX src) = src


------------------------------------------------------------
-- 6. 검증 함수
------------------------------------------------------------

-- LaTeX 문서가 비어있지 않은지
public export
nonEmptyLatex : LaTeXDocument -> Bool
nonEmptyLatex (MkLaTeX src) = length src > 0

-- begin/end가 매칭되는지 (간단한 검증)
public export
validLatex : LaTeXDocument -> Bool
validLatex doc = nonEmptyLatex doc  -- TODO: 실제로는 더 정교한 검증
