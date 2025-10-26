module Core.MarkdownRenderer

import Core.DocumentModel
import Data.List
import Data.String
import System.File

------------------------------------------------------------
-- Markdown Renderer
-- Purpose: Convert Document to Markdown (.md)
-- Use case: Human-readable preview with formatting
------------------------------------------------------------

------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------

replicateChar : Nat -> Char -> String
replicateChar n c = pack (replicate n c)

------------------------------------------------------------
-- 1. Markdown Escaping
------------------------------------------------------------

-- Escape markdown special characters (minimal - most are okay in markdown)
escapeMarkdown : String -> String
escapeMarkdown str =
  let chars = unpack str
      escaped = map escapeChar chars
  in fastConcat escaped
  where
    escapeChar : Char -> String
    escapeChar '\\' = "\\\\"
    escapeChar '*' = "\\*"
    escapeChar '_' = "\\_"
    escapeChar '`' = "\\`"
    escapeChar '[' = "\\["
    escapeChar ']' = "\\]"
    escapeChar c = pack [c]

------------------------------------------------------------
-- 2. Element Rendering
------------------------------------------------------------

-- Render a single document element as Markdown
renderElement : DocElement -> String
renderElement (Text str) = str
renderElement (StyledText str style) =
  let text = if style.bold then "**" ++ str ++ "**" else str
  in if style.italic then "*" ++ text ++ "*" else text
renderElement (Para str) = str ++ "\n\n"
renderElement (Heading 1 title) = "\n# " ++ title ++ "\n"
renderElement (Heading 2 title) = "\n## " ++ title ++ "\n"
renderElement (Heading 3 title) = "\n### " ++ title ++ "\n"
renderElement (Heading n title) = "\n" ++ replicateChar n '#' ++ " " ++ title ++ "\n"
renderElement (BulletList items) =
  "\n" ++ fastConcat (map (\item => "- " ++ item ++ "\n") items) ++ "\n"
renderElement (OrderedList items) =
  let indexed = zip [1..length items] items
  in "\n" ++ fastConcat (map (\(n, item) => show n ++ ". " ++ item ++ "\n") indexed) ++ "\n"
renderElement (SimpleTable rows) =
  case rows of
    [] => ""
    (headers :: dataRows) =>
      let headerLine = "| " ++ fastConcat (intersperse " | " headers) ++ " |"
          separator = "| " ++ fastConcat (intersperse " | " (map (\h => replicateChar (length h) '-') headers)) ++ " |"
          rowLines = map (\row => "| " ++ fastConcat (intersperse " | " row) ++ " |") dataRows
          allLines = [headerLine, separator] ++ rowLines
      in "\n" ++ fastConcat (map (++ "\n") allLines) ++ "\n"
    _ => ""
renderElement HRule = "\n---\n"
renderElement (VSpace n) = replicateChar n '\n'
renderElement PageBreak = "\n<div style=\"page-break-after: always;\"></div>\n"
renderElement (Section title elements) =
  "\n## " ++ title ++ "\n\n" ++
  concat (map renderElement elements)
renderElement (Box elements) =
  let content = concat (map renderElement elements)
      contentLines = lines content
      quotedLines = map (\line => "> " ++ line) contentLines
  in "\n> **Box Content:**\n> \n" ++ fastConcat (map (++ "\n") quotedLines) ++ "\n"

------------------------------------------------------------
-- 3. Metadata Rendering (YAML front matter)
------------------------------------------------------------

renderMetadata : Metadata -> String
renderMetadata meta =
  let hasMetadata = meta.author /= "" || meta.date /= "" || meta.docNumber /= ""
      metaLines = [ "---"
                  , "title: " ++ meta.title
                  , if meta.author == "" then "" else "author: " ++ meta.author
                  , if meta.date == "" then "" else "date: " ++ meta.date
                  , if meta.docNumber == "" then "" else "document_number: " ++ meta.docNumber
                  , "---"
                  , ""
                  ]
  in if hasMetadata
    then fastConcat (map (++ "\n") metaLines)
    else "# " ++ meta.title ++ "\n\n"

------------------------------------------------------------
-- 4. Full Document Rendering
------------------------------------------------------------

public export
record MarkdownDocument where
  constructor MkMarkdownDoc
  content : String

public export
renderDocument : Document -> MarkdownDocument
renderDocument doc =
  let header = renderMetadata doc.meta
      body = concat (map renderElement doc.body)
  in MkMarkdownDoc (header ++ body)

public export
extractContent : MarkdownDocument -> String
extractContent = content

------------------------------------------------------------
-- 5. Save to File Helper
------------------------------------------------------------

public export
saveMarkdownDocument : MarkdownDocument -> String -> IO (Either String String)
saveMarkdownDocument mdDoc filePath = do
  Right () <- writeFile filePath (extractContent mdDoc)
    | Left err => pure (Left $ "Failed to write markdown file: " ++ show err)
  pure (Right $ "Markdown document saved: " ++ filePath)
