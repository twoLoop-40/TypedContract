||| MCP (Model Context Protocol) Integration Specification
|||
||| This module defines the formal specification for MCP server integration
||| in the TypedContract system, providing type-safe file system operations
||| and tool definitions.
|||
||| @author TypedContract Team
||| @version 1.0.0

module Spec.MCPIntegration

import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- MCP Server Types
--------------------------------------------------------------------------------

||| MCP Server configuration
||| Represents a configured MCP server with command and arguments
public export
record MCPServer where
  constructor MkMCPServer
  name : String              -- Server identifier (e.g., "typedcontract-filesystem")
  command : String           -- Command to run (e.g., "npx")
  args : List String         -- Arguments for the command
  description : String       -- Human-readable description

||| Filesystem MCP Server for TypedContract
public export
typedContractFilesystem : MCPServer
typedContractFilesystem = MkMCPServer
  "typedcontract-filesystem"
  "npx"
  [ "-y"
  , "@modelcontextprotocol/server-filesystem"
  , "/Users/joonho/Idris2Projects/TypedContract/output"
  , "/Users/joonho/Idris2Projects/TypedContract/Domains"
  , "/Users/joonho/Idris2Projects/TypedContract/Pipeline"
  , "/Users/joonho/Idris2Projects/TypedContract/Spec"
  ]
  "TypedContract file system access for output, domains, pipelines, and specifications"

--------------------------------------------------------------------------------
-- MCP Resource Types
--------------------------------------------------------------------------------

||| File system resource types
public export
data ResourceType
  = OutputFile      -- Generated output files (PDF, MD, CSV, TXT)
  | DomainFile      -- Idris2 domain model files
  | PipelineFile    -- Idris2 pipeline implementation files
  | SpecFile        -- Idris2 specification files
  | StateFile       -- Workflow state JSON files
  | LogFile         -- Log files

||| Resource path with type safety
public export
record Resource where
  constructor MkResource
  resourceType : ResourceType
  projectName : String
  fileName : String

||| Construct full file path from resource
public export
resourcePath : Resource -> String
resourcePath (MkResource OutputFile proj file) =
  "./output/" ++ proj ++ "/" ++ file
resourcePath (MkResource DomainFile proj file) =
  "./Domains/" ++ file
resourcePath (MkResource PipelineFile proj file) =
  "./Pipeline/" ++ file
resourcePath (MkResource SpecFile proj file) =
  "./Spec/" ++ file
resourcePath (MkResource StateFile proj file) =
  "./output/" ++ proj ++ "/workflow_state.json"
resourcePath (MkResource LogFile proj file) =
  "./output/" ++ proj ++ "/logs/" ++ file

--------------------------------------------------------------------------------
-- MCP Tool Definitions
--------------------------------------------------------------------------------

||| MCP Tool specification
||| Represents a callable tool exposed by the MCP server
public export
record MCPTool where
  constructor MkMCPTool
  toolName : String
  inputSchema : String       -- JSON schema for inputs
  description : String
  outputType : String        -- Expected output type

||| Read file tool
public export
readFileTool : MCPTool
readFileTool = MkMCPTool
  "read_file"
  "{\"path\": \"string\"}"
  "Read the contents of a file from allowed directories"
  "string"

||| Write file tool
public export
writeFileTool : MCPTool
writeFileTool = MkMCPTool
  "write_file"
  "{\"path\": \"string\", \"content\": \"string\"}"
  "Write content to a file in allowed directories"
  "boolean"

||| List directory tool
public export
listDirectoryTool : MCPTool
listDirectoryTool = MkMCPTool
  "list_directory"
  "{\"path\": \"string\"}"
  "List files and directories in a path"
  "array<string>"

||| Search files tool
public export
searchFilesTool : MCPTool
searchFilesTool = MkMCPTool
  "search_files"
  "{\"pattern\": \"string\", \"path\": \"string\"}"
  "Search for files matching a pattern"
  "array<string>"

||| Get file info tool
public export
getFileInfoTool : MCPTool
getFileInfoTool = MkMCPTool
  "get_file_info"
  "{\"path\": \"string\"}"
  "Get metadata about a file (size, modified date, etc.)"
  "object"

--------------------------------------------------------------------------------
-- MCP Operations
--------------------------------------------------------------------------------

||| Result of an MCP operation
public export
data MCPResult : Type -> Type where
  MCPSuccess : (value : a) -> MCPResult a
  MCPError : (message : String) -> MCPResult a

||| Functor instance for MCPResult
public export
Functor MCPResult where
  map f (MCPSuccess x) = MCPSuccess (f x)
  map f (MCPError msg) = MCPError msg

||| Applicative instance for MCPResult
public export
Applicative MCPResult where
  pure = MCPSuccess
  (MCPSuccess f) <*> (MCPSuccess x) = MCPSuccess (f x)
  (MCPError msg) <*> _ = MCPError msg
  _ <*> (MCPError msg) = MCPError msg

||| Monad instance for MCPResult
public export
Monad MCPResult where
  (MCPSuccess x) >>= f = f x
  (MCPError msg) >>= _ = MCPError msg

||| File operation specification
public export
data FileOperation : Type where
  ReadFile : (resource : Resource) -> FileOperation
  WriteFile : (resource : Resource) -> (content : String) -> FileOperation
  ListDir : (path : String) -> FileOperation
  SearchFiles : (pattern : String) -> (path : String) -> FileOperation
  GetFileInfo : (resource : Resource) -> FileOperation

||| Execute a file operation (abstract specification)
|||
||| In practice, this would be implemented by the Python backend
||| calling the MCP server through the protocol
public export
executeFileOp : FileOperation -> MCPResult String
executeFileOp (ReadFile res) =
  MCPSuccess $ "Reading: " ++ resourcePath res
executeFileOp (WriteFile res content) =
  MCPSuccess $ "Writing to: " ++ resourcePath res
executeFileOp (ListDir path) =
  MCPSuccess $ "Listing: " ++ path
executeFileOp (SearchFiles pattern path) =
  MCPSuccess $ "Searching: " ++ pattern ++ " in " ++ path
executeFileOp (GetFileInfo res) =
  MCPSuccess $ "Info for: " ++ resourcePath res

--------------------------------------------------------------------------------
-- Integration with Workflow
--------------------------------------------------------------------------------

||| Workflow state persistence through MCP
public export
record WorkflowStateResource where
  constructor MkWorkflowStateResource
  projectName : String
  stateFile : Resource

||| Create workflow state resource
public export
mkWorkflowStateResource : (projectName : String) -> WorkflowStateResource
mkWorkflowStateResource proj = MkWorkflowStateResource proj $
  MkResource StateFile proj "workflow_state.json"

||| Load workflow state through MCP
public export
loadWorkflowState : (projectName : String) -> MCPResult String
loadWorkflowState proj =
  let res = mkWorkflowStateResource proj
  in executeFileOp (ReadFile res.stateFile)

||| Save workflow state through MCP
public export
saveWorkflowState : (projectName : String) -> (state : String) -> MCPResult String
saveWorkflowState proj stateJson =
  let res = mkWorkflowStateResource proj
  in executeFileOp (WriteFile res.stateFile stateJson)

--------------------------------------------------------------------------------
-- Domain File Operations
--------------------------------------------------------------------------------

||| Domain file resource
public export
mkDomainResource : (projectName : String) -> (moduleName : String) -> Resource
mkDomainResource proj modName =
  MkResource DomainFile proj (modName ++ ".idr")

||| Pipeline file resource
public export
mkPipelineResource : (projectName : String) -> (moduleName : String) -> Resource
mkPipelineResource proj modName =
  MkResource PipelineFile proj (modName ++ ".idr")

||| Read domain file
public export
readDomainFile : (projectName : String) -> (moduleName : String) -> MCPResult String
readDomainFile proj modName =
  executeFileOp (ReadFile $ mkDomainResource proj modName)

||| Write domain file
public export
writeDomainFile : (projectName : String) -> (moduleName : String) -> (code : String) -> MCPResult String
writeDomainFile proj modName code =
  executeFileOp (WriteFile (mkDomainResource proj modName) code)

||| Read pipeline file
public export
readPipelineFile : (projectName : String) -> (moduleName : String) -> MCPResult String
readPipelineFile proj modName =
  executeFileOp (ReadFile $ mkPipelineResource proj modName)

||| Write pipeline file
public export
writePipelineFile : (projectName : String) -> (moduleName : String) -> (code : String) -> MCPResult String
writePipelineFile proj modName code =
  executeFileOp (WriteFile (mkPipelineResource proj modName) code)

--------------------------------------------------------------------------------
-- Output File Operations
--------------------------------------------------------------------------------

||| Output file types
public export
data OutputFormat = PDF | Markdown | CSV | Text | LaTeX

||| Get file extension for output format
public export
outputExtension : OutputFormat -> String
outputExtension PDF = ".pdf"
outputExtension Markdown = ".md"
outputExtension CSV = ".csv"
outputExtension Text = ".txt"
outputExtension LaTeX = ".tex"

||| Create output file resource
public export
mkOutputResource : (projectName : String) -> (format : OutputFormat) -> Resource
mkOutputResource proj fmt =
  MkResource OutputFile proj (proj ++ outputExtension fmt)

||| Read output file
public export
readOutputFile : (projectName : String) -> (format : OutputFormat) -> MCPResult String
readOutputFile proj fmt =
  executeFileOp (ReadFile $ mkOutputResource proj fmt)

||| Write output file
public export
writeOutputFile : (projectName : String) -> (format : OutputFormat) -> (content : String) -> MCPResult String
writeOutputFile proj fmt content =
  executeFileOp (WriteFile (mkOutputResource proj fmt) content)

--------------------------------------------------------------------------------
-- Project Management Operations
--------------------------------------------------------------------------------

||| List all projects
public export
listProjects : MCPResult String
listProjects = executeFileOp (ListDir "./output")

||| Search for Idris2 domain files
public export
searchDomainFiles : (pattern : String) -> MCPResult String
searchDomainFiles pattern =
  executeFileOp (SearchFiles pattern "./Domains")

||| Search for pipeline files
public export
searchPipelineFiles : (pattern : String) -> MCPResult String
searchPipelineFiles pattern =
  executeFileOp (SearchFiles pattern "./Pipeline")

--------------------------------------------------------------------------------
-- Examples
--------------------------------------------------------------------------------

||| Example: Load and save workflow state
public export
exampleWorkflowStatePersistence : String -> String
exampleWorkflowStatePersistence projectName =
  case loadWorkflowState projectName of
    MCPSuccess state => "Loaded state: " ++ state
    MCPError msg => "Error loading state: " ++ msg

||| Example: Create new domain file
public export
exampleCreateDomainFile : String
exampleCreateDomainFile =
  let proj = "example_contract"
      modName = "ExampleContract"
      code = "module Domains.ExampleContract\n\n-- Domain model here"
  in case writeDomainFile proj modName code of
       MCPSuccess msg => msg
       MCPError err => "Error: " ++ err

||| Example: Generate all output formats
public export
exampleGenerateAllFormats : (projectName : String) -> (content : String) -> List (MCPResult String)
exampleGenerateAllFormats proj content =
  [ writeOutputFile proj Markdown content
  , writeOutputFile proj CSV content
  , writeOutputFile proj Text content
  ]
