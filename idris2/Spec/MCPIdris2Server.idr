||| MCP Server Specification for Idris2 Type-Checking and Code Generation
|||
||| This module defines the formal specification for an MCP server that provides
||| Idris2-specific tools including type-checking, syntax validation, error
||| explanation, and code template generation.
|||
||| @author TypedContract Team
||| @version 1.0.0

module Spec.MCPIdris2Server

import Data.String
import Data.List
import Data.Nat

%default total

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

||| Check if a substring is contained in a string
contains : String -> String -> Bool
contains needle haystack = isInfixOf needle haystack

--------------------------------------------------------------------------------
-- Tool Types
--------------------------------------------------------------------------------

||| Idris2 MCP Tool definitions
public export
data Idris2Tool
  = CheckIdris2      -- Type-check Idris2 code
  | ExplainError     -- Explain compiler errors
  | GetTemplate      -- Get code templates
  | ValidateSyntax   -- Quick syntax validation
  | SuggestFix       -- Suggest error fixes

||| Show instance for Idris2Tool
public export
Show Idris2Tool where
  show CheckIdris2 = "check_idris2"
  show ExplainError = "explain_error"
  show GetTemplate = "get_template"
  show ValidateSyntax = "validate_syntax"
  show SuggestFix = "suggest_fix"

--------------------------------------------------------------------------------
-- Template Patterns
--------------------------------------------------------------------------------

||| Code template patterns available in Idris2
public export
data TemplatePattern
  = RecordTemplate
  | DataTemplate
  | InterfaceTemplate
  | ProofTemplate
  | SmartConstructorTemplate

||| Show instance for TemplatePattern
public export
Show TemplatePattern where
  show RecordTemplate = "record"
  show DataTemplate = "data"
  show InterfaceTemplate = "interface"
  show ProofTemplate = "proof"
  show SmartConstructorTemplate = "smart_constructor"

--------------------------------------------------------------------------------
-- Error Categories
--------------------------------------------------------------------------------

||| Categories of Idris2 compiler errors
public export
data ErrorCategory
  = ExpectedDeclaration    -- "Expected a type declaration"
  | ConstraintError        -- "Can't solve constraint"
  | UndefinedName         -- "Undefined name"
  | TypeMismatch          -- "Type mismatch between..."
  | ImportError           -- "Can't find import"
  | ParseError            -- "Parse error"
  | UnknownError          -- Other errors

||| Classify error by message
public export
classifyError : String -> ErrorCategory
classifyError msg =
  if contains "Expected" msg then ExpectedDeclaration
  else if contains "constraint" msg then ConstraintError
  else if contains "Undefined name" msg then UndefinedName
  else if contains "mismatch" msg then TypeMismatch
  else if contains "import" msg then ImportError
  else if contains "Parse" msg then ParseError
  else UnknownError

||| Get explanation for error category
public export
explainCategory : ErrorCategory -> String
explainCategory ExpectedDeclaration =
  "Idris2 expected a different type or construct than what you provided. Check your type signatures."
explainCategory ConstraintError =
  "Idris2 cannot prove the type-level constraint. Verify your proof terms and type signatures."
explainCategory UndefinedName =
  "You're using a variable or function that hasn't been defined or imported."
explainCategory TypeMismatch =
  "The type provided doesn't match what Idris2 inferred or expected."
explainCategory ImportError =
  "The module you're trying to import doesn't exist or isn't in the search path."
explainCategory ParseError =
  "Syntax error in your code. Check for typos, missing keywords, or incorrect structure."
explainCategory UnknownError =
  "Unknown error type. Please check the Idris2 documentation or compiler output."

--------------------------------------------------------------------------------
-- Tool Input/Output Types
--------------------------------------------------------------------------------

||| Input for type-checking tool
public export
record CheckInput where
  constructor MkCheckInput
  code : String          -- Idris2 source code
  moduleName : String    -- Module name (e.g., "Domains.MyContract")

||| Result of type-checking
public export
data CheckResult
  = CheckSuccess String  -- Success with compiler output
  | CheckFailure String  -- Failure with error message
  | CheckTimeout         -- Timeout (>30 seconds)
  | CheckError String    -- System error (idris2 not found, etc.)

||| Input for error explanation tool
public export
record ExplainInput where
  constructor MkExplainInput
  errorMessage : String
  codeSnippet : Maybe String

||| Result of error explanation
public export
record ExplainResult where
  constructor MkExplainResult
  category : ErrorCategory
  explanation : String
  suggestions : List String

||| Input for template generation
public export
record TemplateInput where
  constructor MkTemplateInput
  pattern : TemplatePattern
  name : String

||| Generated template code
public export
record TemplateResult where
  constructor MkTemplateResult
  code : String
  description : String

||| Syntax validation input
public export
record ValidateInput where
  constructor MkValidateInput
  code : String

||| Syntax validation result
public export
data SyntaxIssue = MkSyntaxIssue Nat String  -- Line number and message

public export
record ValidateResult where
  constructor MkValidateResult
  issues : List SyntaxIssue
  isValid : Bool

||| Input for fix suggestions
public export
record SuggestInput where
  constructor MkSuggestInput
  errorMessage : String
  code : String

||| Fix suggestion result
public export
record SuggestResult where
  constructor MkSuggestResult
  suggestions : List String
  codeExample : Maybe String

--------------------------------------------------------------------------------
-- MCP Server State
--------------------------------------------------------------------------------

||| Server configuration
public export
record ServerConfig where
  constructor MkServerConfig
  serverName : String
  serverVersion : String
  timeoutSeconds : Nat

||| Default server configuration
public export
defaultConfig : ServerConfig
defaultConfig = MkServerConfig
  "idris2-helper"
  "1.0.0"
  30

||| Server state tracking active requests
public export
record ServerState where
  constructor MkServerState
  config : ServerConfig
  activeRequests : Nat
  totalRequests : Nat
  successCount : Nat
  errorCount : Nat

||| Initial server state
public export
initialState : ServerConfig -> ServerState
initialState cfg = MkServerState cfg 0 0 0 0

||| Update state after successful request
public export
recordSuccess : ServerState -> ServerState
recordSuccess st = { successCount $= (+1),
                     totalRequests $= (+1),
                     activeRequests $= pred } st

||| Update state after failed request
public export
recordError : ServerState -> ServerState
recordError st = { errorCount $= (+1),
                   totalRequests $= (+1),
                   activeRequests $= pred } st

--------------------------------------------------------------------------------
-- Tool Execution Specification
--------------------------------------------------------------------------------

||| Execute a type-check operation (abstract specification)
|||
||| In practice, this would spawn `idris2 --check` subprocess
public export
executeCheck : CheckInput -> CheckResult
executeCheck input =
  -- Abstract specification - actual implementation in Python MCP server
  CheckSuccess "Type-check completed (spec)"

||| Execute error explanation
public export
executeExplain : ExplainInput -> ExplainResult
executeExplain input =
  let category = classifyError input.errorMessage
      explanation = explainCategory category
      suggestions = getSuggestions category
  in MkExplainResult category explanation suggestions
where
  getSuggestions : ErrorCategory -> List String
  getSuggestions ExpectedDeclaration =
    ["Add a type signature before the constructor in 'data' declarations",
     "Example: data MyType : Type where"]
  getSuggestions ConstraintError =
    ["Check that your proof terms match the constraints",
     "Try simplifying complex type-level computations"]
  getSuggestions UndefinedName =
    ["Check if you've imported the required module",
     "Verify the spelling of the identifier"]
  getSuggestions TypeMismatch =
    ["Check that your types align correctly",
     "Use :t in REPL to check inferred types"]
  getSuggestions ImportError =
    ["Verify the module exists in your project",
     "Check the module search path"]
  getSuggestions ParseError =
    ["Check for syntax errors like missing commas or parentheses",
     "Verify keyword usage (where, data, record, etc.)"]
  getSuggestions UnknownError =
    ["Try breaking down complex type signatures",
     "Check the Idris2 documentation"]

||| Execute template generation
public export
executeTemplate : TemplateInput -> TemplateResult
executeTemplate input =
  MkTemplateResult (generateTemplate input.pattern input.name)
                   (templateDescription input.pattern)
where
  generateTemplate : TemplatePattern -> String -> String
  generateTemplate RecordTemplate name =
    "public export\nrecord " ++ name ++ " where\n  constructor Mk" ++ name
  generateTemplate DataTemplate name =
    "public export\ndata " ++ name ++ " : Type where\n  Mk" ++ name ++ " : " ++ name
  generateTemplate InterfaceTemplate name =
    "public export\ninterface " ++ name ++ " a where\n  method : a -> String"
  generateTemplate ProofTemplate name =
    "public export\ndata " ++ name ++ "Proof : Type where\n  Mk" ++ name ++ "Proof : " ++ name ++ "Proof"
  generateTemplate SmartConstructorTemplate name =
    "public export\nmk" ++ name ++ " : (value : Nat) -> " ++ name

  templateDescription : TemplatePattern -> String
  templateDescription RecordTemplate = "Record type with fields"
  templateDescription DataTemplate = "Algebraic data type"
  templateDescription InterfaceTemplate = "Type class interface"
  templateDescription ProofTemplate = "Dependent type proof"
  templateDescription SmartConstructorTemplate = "Smart constructor with constraints"

||| Execute syntax validation
public export
executeValidate : ValidateInput -> ValidateResult
executeValidate input =
  let issues = checkSyntax 1 (lines input.code)
  in MkValidateResult issues (null issues)
where
  unbalancedParens : String -> Bool
  unbalancedParens s =
    let openCount = length (filter (== '(') (unpack s))
        closeCount = length (filter (== ')') (unpack s))
    in openCount /= closeCount

  checkLine : Nat -> String -> List SyntaxIssue
  checkLine n line =
    let trimmed = trim line
    in concat
      [ if contains "data" trimmed && not (contains ":" trimmed)
          then [MkSyntaxIssue n "'data' declaration should have a type signature"]
          else []
      , if unbalancedParens trimmed
          then [MkSyntaxIssue n "Unmatched parentheses"]
          else []
      ]

  checkSyntax : Nat -> List String -> List SyntaxIssue
  checkSyntax _ [] = []
  checkSyntax n (line :: rest) =
    checkLine n line ++ checkSyntax (S n) rest

||| Execute fix suggestion
public export
executeSuggest : SuggestInput -> SuggestResult
executeSuggest input =
  let category = classifyError input.errorMessage
      suggestions = getFixSuggestions category
      example = getCodeExample category
  in MkSuggestResult suggestions example
where
  getFixSuggestions : ErrorCategory -> List String
  getFixSuggestions ExpectedDeclaration =
    ["Add type signature: 'data MyType : Type where'",
     "Check constructor placement"]
  getFixSuggestions _ = ["Check documentation", "Simplify code"]

  getCodeExample : ErrorCategory -> Maybe String
  getCodeExample ExpectedDeclaration =
    Just "data Foo : Type where\n  MkFoo : Foo"
  getCodeExample _ = Nothing

--------------------------------------------------------------------------------
-- Tool Registration
--------------------------------------------------------------------------------

||| Tool metadata for MCP protocol
public export
record ToolMetadata where
  constructor MkToolMetadata
  tool : Idris2Tool
  description : String
  requiresCode : Bool
  requiresModuleName : Bool

||| Get metadata for all tools
public export
allTools : List ToolMetadata
allTools =
  [ MkToolMetadata CheckIdris2 "Type-check Idris2 code" True True
  , MkToolMetadata ExplainError "Explain compiler errors" False False
  , MkToolMetadata GetTemplate "Get code templates" False False
  , MkToolMetadata ValidateSyntax "Quick syntax validation" True False
  , MkToolMetadata SuggestFix "Suggest error fixes" True False
  ]

--------------------------------------------------------------------------------
-- Integration with Workflow
--------------------------------------------------------------------------------

||| Integration point with TypedContract workflow
public export
record WorkflowIntegration where
  constructor MkWorkflowIntegration
  projectName : String
  currentPhase : String
  lastCheckResult : Maybe CheckResult

||| Create workflow integration
public export
mkWorkflowIntegration : String -> String -> WorkflowIntegration
mkWorkflowIntegration proj phase =
  MkWorkflowIntegration proj phase Nothing

||| Update integration with check result
public export
updateCheckResult : WorkflowIntegration -> CheckResult -> WorkflowIntegration
updateCheckResult wf result = { lastCheckResult := Just result } wf

--------------------------------------------------------------------------------
-- Examples
--------------------------------------------------------------------------------

||| Example: Type-check a simple contract
public export
exampleCheck : CheckResult
exampleCheck =
  let input = MkCheckInput
        "module Domains.Example\n\ndata Foo : Type where\n  MkFoo : Foo"
        "Domains.Example"
  in executeCheck input

||| Example: Explain an error
public export
exampleExplain : ExplainResult
exampleExplain =
  let input = MkExplainInput "Error: Expected a type declaration." Nothing
  in executeExplain input

||| Example: Generate a record template
public export
exampleTemplate : TemplateResult
exampleTemplate =
  let input = MkTemplateInput RecordTemplate "MyContract"
  in executeTemplate input

||| Example: Validate syntax
public export
exampleValidate : ValidateResult
exampleValidate =
  let input = MkValidateInput "data Foo\n  MkFoo : Foo"
  in executeValidate input
