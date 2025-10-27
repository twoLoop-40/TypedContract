module Core.CSVRenderer

import Core.DocumentModel
import Data.List
import Data.String
import System.File

------------------------------------------------------------
-- CSV Renderer
-- Purpose: Extract tabular data from Document to CSV
-- Use case: Spreadsheet-compatible output for data analysis
------------------------------------------------------------

------------------------------------------------------------
-- 1. CSV Escaping
------------------------------------------------------------

-- Escape CSV special characters
escapeCSVField : String -> String
escapeCSVField str =
  if any (\c => c == ',' || c == '"' || c == '\n') (unpack str)
    then "\"" ++ replaceQuotes str ++ "\""
    else str
  where
    replaceQuotes : String -> String
    replaceQuotes s =
      let chars = unpack s
          escaped = map (\c => if c == '"' then "\"\"" else pack [c]) chars
      in fastConcat escaped

------------------------------------------------------------
-- 2. Table Extraction
------------------------------------------------------------

-- Extract all tables from a document
extractTablesFromElements : List DocElement -> List (List (List String))
extractTablesFromElements [] = []
extractTablesFromElements (SimpleTable rows :: rest) = rows :: extractTablesFromElements rest
extractTablesFromElements (Section _ elements :: rest) = extractTablesFromElements elements ++ extractTablesFromElements rest
extractTablesFromElements (Box elements :: rest) = extractTablesFromElements elements ++ extractTablesFromElements rest
extractTablesFromElements (_ :: rest) = extractTablesFromElements rest

-- Render a single table as CSV
renderTable : List (List String) -> String
renderTable rows =
  let rowLines = map (\row => fastConcat (intersperse "," (map escapeCSVField row))) rows
  in fastConcat (map (++ "\n") rowLines)

------------------------------------------------------------
-- 3. Full CSV Generation
------------------------------------------------------------

public export
record CSVDocument where
  constructor MkCSVDoc
  tables : List String  -- Each table as separate CSV content
  combined : String     -- All tables combined (with separators)

replicateChar : Nat -> Char -> String
replicateChar n c = pack (replicate n c)

public export
renderDocument : Document -> CSVDocument
renderDocument doc =
  let tables = extractTablesFromElements doc.body
      csvTables = map renderTable tables
      separator = "\n# " ++ replicateChar 60 '-' ++ "\n"
      combined = fastConcat (intersperse separator csvTables)
  in MkCSVDoc csvTables combined

public export
extractCombined : CSVDocument -> String
extractCombined = combined

public export
getCSVTables : CSVDocument -> List String
getCSVTables = tables

------------------------------------------------------------
-- 4. Save to File Helpers
------------------------------------------------------------

public export
saveCSVDocument : CSVDocument -> String -> IO (Either String String)
saveCSVDocument csvDoc filePath = do
  Right () <- writeFile filePath (extractCombined csvDoc)
    | Left err => pure (Left $ "Failed to write CSV file: " ++ show err)
  pure (Right $ "CSV document saved: " ++ filePath)

-- Helper to write multiple CSV files
writeTableFiles : List (String, String) -> IO (Either String (List String))
writeTableFiles [] = pure (Right [])
writeTableFiles ((content, path) :: rest) = do
  Right () <- writeFile path content
    | Left err => pure (Left $ "Failed to write " ++ path ++ ": " ++ show err)
  Right paths <- writeTableFiles rest
    | Left err => pure (Left err)
  pure (Right (path :: paths))

public export
saveSeparateCSVs : CSVDocument -> String -> IO (Either String (List String))
saveSeparateCSVs csvDoc basePathNoExt =
  let tables = getCSVTables csvDoc
      paths = map (\n => basePathNoExt ++ "_table" ++ show n ++ ".csv") [1..length tables]
      pairs = zip tables paths
  in writeTableFiles pairs
