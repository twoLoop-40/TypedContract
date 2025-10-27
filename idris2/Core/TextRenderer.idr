module Core.TextRenderer

import Core.DocumentModel
import Data.List
import Data.String
import System.File

------------------------------------------------------------
-- Plain Text Renderer
-- Purpose: Convert Document to plain text (.txt)
-- Use case: Lightweight preview for user feedback
------------------------------------------------------------

------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------

replicateChar : Nat -> Char -> String
replicateChar n c = pack (replicate n c)

------------------------------------------------------------
-- 1. Element Rendering
------------------------------------------------------------

-- Render a single document element as plain text
renderElement : DocElement -> String
renderElement (Text str) = str
renderElement (StyledText str _) = str
renderElement (Para str) = str ++ "\n\n"
renderElement (Heading 1 title) = "\n" ++ title ++ "\n" ++ replicateChar (length title) '=' ++ "\n"
renderElement (Heading 2 title) = "\n" ++ title ++ "\n" ++ replicateChar (length title) '-' ++ "\n"
renderElement (Heading n title) = "\n" ++ replicateChar n '#' ++ " " ++ title ++ "\n"
renderElement (BulletList items) =
  fastConcat (map (\item => "  • " ++ item ++ "\n") items)
renderElement (OrderedList items) =
  let indexed = zip [1..length items] items
  in fastConcat (map (\(n, item) => "  " ++ show n ++ ". " ++ item ++ "\n") indexed)
renderElement (SimpleTable rows) =
  let rowLines = map (\row => "| " ++ fastConcat (intersperse " | " row) ++ " |") rows
      separator = "+" ++ replicateChar 60 '-' ++ "+"
      allLines = [separator] ++ rowLines ++ [separator]
  in fastConcat (map (++ "\n") allLines)
renderElement HRule = "\n" ++ replicateChar 60 '-' ++ "\n"
renderElement (VSpace n) = replicateChar n '\n'
renderElement PageBreak = "\n" ++ replicateChar 60 '=' ++ "\n[PAGE BREAK]\n" ++ replicateChar 60 '=' ++ "\n"
renderElement (Section title elements) =
  "\n## " ++ title ++ "\n" ++
  concat (map renderElement elements)
renderElement (Box elements) =
  let content = concat (map renderElement elements)
      border = replicateChar 60 '*'
  in "\n" ++ border ++ "\n" ++ content ++ "\n" ++ border ++ "\n"

------------------------------------------------------------
-- 2. Metadata Rendering
------------------------------------------------------------

renderMetadata : Metadata -> String
renderMetadata meta =
  let titleLine = meta.title ++ "\n" ++ replicateChar (length meta.title) '='
      authorLine = if meta.author == "" then "" else "Author: " ++ meta.author
      dateLine = if meta.date == "" then "" else "Date: " ++ meta.date
      docNumLine = if meta.docNumber == "" then "" else "Document #: " ++ meta.docNumber
      metaLines = filter (\s => s /= "") [titleLine, authorLine, dateLine, docNumLine]
  in fastConcat (map (++ "\n") metaLines) ++ "\n"

------------------------------------------------------------
-- 3. Full Document Rendering
------------------------------------------------------------

public export
record TextDocument where
  constructor MkTextDoc
  content : String

public export
renderDocument : Document -> TextDocument
renderDocument doc =
  let header = renderMetadata doc.meta
      body = concat (map renderElement doc.body)
  in MkTextDoc (header ++ body)

public export
extractContent : TextDocument -> String
extractContent = content

------------------------------------------------------------
-- 4. Save to File Helper
------------------------------------------------------------

public export
saveTextDocument : TextDocument -> String -> IO (Either String String)
saveTextDocument textDoc filePath = do
  Right () <- writeFile filePath (extractContent textDoc)
    | Left err => pure (Left $ "Failed to write text file: " ++ show err)
  pure (Right $ "Text document saved: " ++ filePath)
