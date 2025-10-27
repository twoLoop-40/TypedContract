module Spec.ErrorHandling

import Data.List
import Data.String

------------------------------------------------------------
-- Idris2 컴파일 에러 처리 명세
-- 목적: 에러 분류 체계 및 대응 전략 정의
------------------------------------------------------------

------------------------------------------------------------
-- 1. 에러 레벨 분류
------------------------------------------------------------

-- 에러의 심각도 및 해결 방법에 따른 분류
public export
data ErrorLevel
  = SyntaxError     -- Level 1: 자동 수정 가능 (문법, 오타 등)
  | ProofFailure    -- Level 2: 증명 실패 - 사용자 확인 필요
  | DomainError     -- Level 3: 도메인 모델링 오류 - 재분석 필요
  | UnknownError    -- 분류 불가능한 에러

-- 에러 레벨을 문자열로 변환
public export
errorLevelToString : ErrorLevel -> String
errorLevelToString SyntaxError = "syntax"
errorLevelToString ProofFailure = "proof"
errorLevelToString DomainError = "domain"
errorLevelToString UnknownError = "unknown"


------------------------------------------------------------
-- 2. 사용자 액션
------------------------------------------------------------

-- 에러 발생 시 사용자가 선택할 수 있는 행동
public export
data UserAction
  = RetryWithFix      -- 자동 수정 후 재시도
  | RemoveProofs      -- 의존 타입 증명 제거하고 단순 타입으로 진행
  | ReanalyzeDocument -- 문서를 재분석하여 도메인 모델 재생성
  | ManualEdit        -- 사용자가 직접 코드 수정
  | AbortGeneration   -- 문서 생성 중단

-- 액션을 문자열로 변환
public export
actionToString : UserAction -> String
actionToString RetryWithFix = "retry"
actionToString RemoveProofs = "fallback"
actionToString ReanalyzeDocument = "reanalyze"
actionToString ManualEdit = "manual"
actionToString AbortGeneration = "abort"


------------------------------------------------------------
-- 3. 에러 위치 정보
------------------------------------------------------------

public export
record ErrorLocation where
  constructor MkErrorLocation
  filePath : String
  lineNumber : Nat

-- 위치 정보를 문자열로 변환
public export
showLocation : ErrorLocation -> String
showLocation loc = loc.filePath ++ ":" ++ show loc.lineNumber


------------------------------------------------------------
-- 4. 분류된 에러 정보
------------------------------------------------------------

public export
record ClassifiedError where
  constructor MkClassifiedError
  level : ErrorLevel
  message : String
  location : Maybe ErrorLocation
  suggestion : String
  availableActions : List UserAction
  autoFixable : Bool

-- 에러 정보 요약 출력
public export
showClassifiedError : ClassifiedError -> String
showClassifiedError err =
  "ErrorLevel: " ++ errorLevelToString err.level ++ "\n" ++
  "Message: " ++ err.message ++ "\n" ++
  (case err.location of
    Nothing => ""
    Just loc => "Location: " ++ showLocation loc ++ "\n") ++
  "Suggestion: " ++ err.suggestion ++ "\n" ++
  "AutoFixable: " ++ (if err.autoFixable then "Yes" else "No")


------------------------------------------------------------
-- 5. 에러 패턴 매칭
------------------------------------------------------------

-- 에러 메시지에서 패턴을 찾는 함수 (간단한 부분 문자열 매칭)
public export
containsPattern : String -> String -> Bool
containsPattern pattern message = isInfixOf pattern message

-- 도메인 에러 패턴
public export
isDomainError : String -> Bool
isDomainError msg =
  containsPattern "Type mismatch between" msg ||
  containsPattern "Expected type" msg ||
  containsPattern "does not have field" msg ||
  containsPattern "Can't find implementation for" msg

-- 증명 실패 패턴
public export
isProofFailure : String -> Bool
isProofFailure msg =
  containsPattern "Can't solve constraint" msg ||
  containsPattern "Mismatch between" msg ||
  containsPattern "Can't unify" msg

-- 문법 에러 패턴
public export
isSyntaxError : String -> Bool
isSyntaxError msg =
  containsPattern "Undefined name" msg ||
  containsPattern "Parse error" msg ||
  containsPattern "Can't find import" msg ||
  containsPattern "Unexpected token" msg


------------------------------------------------------------
-- 6. 에러 분류 함수
------------------------------------------------------------

-- 에러 레벨 결정 (우선순위: Domain > Proof > Syntax)
public export
classifyErrorLevel : String -> ErrorLevel
classifyErrorLevel msg =
  if isDomainError msg then DomainError
  else if isProofFailure msg then ProofFailure
  else if isSyntaxError msg then SyntaxError
  else UnknownError

-- 에러 레벨에 따라 가능한 액션 결정
public export
getAvailableActions : ErrorLevel -> List UserAction
getAvailableActions SyntaxError = [RetryWithFix, ManualEdit, AbortGeneration]
getAvailableActions ProofFailure = [RemoveProofs, ReanalyzeDocument, ManualEdit, AbortGeneration]
getAvailableActions DomainError = [ReanalyzeDocument, ManualEdit, AbortGeneration]
getAvailableActions UnknownError = [RetryWithFix, ManualEdit, AbortGeneration]

-- 에러 레벨에 따라 제안 메시지 생성
public export
getSuggestion : ErrorLevel -> String
getSuggestion SyntaxError = "문법 오류입니다. Claude가 자동으로 수정을 시도합니다."
getSuggestion ProofFailure = "의존 타입 증명 실패입니다. 입력 데이터를 확인하거나 증명 없이 진행하세요."
getSuggestion DomainError = "도메인 모델링 오류입니다. 문서를 재분석해야 합니다."
getSuggestion UnknownError = "알 수 없는 에러입니다. 수동 확인이 필요합니다."

-- 자동 수정 가능 여부 결정
public export
isAutoFixable : ErrorLevel -> Bool
isAutoFixable SyntaxError = True
isAutoFixable _ = False

-- 전체 에러 분류 (메인 함수)
public export
classifyError : String -> ClassifiedError
classifyError message =
  let level = classifyErrorLevel message
      actions = getAvailableActions level
      suggestion = getSuggestion level
      autoFix = isAutoFixable level
  in MkClassifiedError level message Nothing suggestion actions autoFix


------------------------------------------------------------
-- 7. 재시도 정책
------------------------------------------------------------

public export
record RetryPolicy where
  constructor MkRetryPolicy
  maxSyntaxRetries : Nat      -- 문법 에러 최대 재시도 횟수
  maxProofRetries : Nat       -- 증명 에러 최대 재시도 횟수
  maxDomainRetries : Nat      -- 도메인 에러 최대 재시도 횟수
  autoRetryProof : Bool       -- 증명 실패 시 자동 재시도 여부
  autoRetryDomain : Bool      -- 도메인 에러 시 자동 재시도 여부

-- 기본 재시도 정책
public export
defaultRetryPolicy : RetryPolicy
defaultRetryPolicy = MkRetryPolicy
  5      -- 문법 에러: 최대 5회 (실제 사용 경험 반영)
  0      -- 증명 실패: 자동 재시도 없음 (사용자 개입)
  0      -- 도메인 에러: 자동 재시도 없음 (재분석 필요)
  False  -- 증명 실패는 자동 재시도 안함
  False  -- 도메인 에러는 자동 재시도 안함

-- 공격적 재시도 정책 (모든 에러에 대해 재시도)
public export
aggressiveRetryPolicy : RetryPolicy
aggressiveRetryPolicy = MkRetryPolicy
  5      -- 문법 에러: 최대 5회
  2      -- 증명 실패: 2회 시도
  1      -- 도메인 에러: 1회 시도
  True   -- 증명 실패도 자동 재시도
  True   -- 도메인 에러도 자동 재시도

-- 재시도 가능 여부 확인
public export
shouldRetry : RetryPolicy -> ErrorLevel -> Nat -> Bool
shouldRetry policy SyntaxError attemptCount = attemptCount < policy.maxSyntaxRetries
shouldRetry policy ProofFailure attemptCount =
  policy.autoRetryProof && attemptCount < policy.maxProofRetries
shouldRetry policy DomainError attemptCount =
  policy.autoRetryDomain && attemptCount < policy.maxDomainRetries
shouldRetry policy UnknownError attemptCount = attemptCount < 1


------------------------------------------------------------
-- 8. 에러 처리 전략
------------------------------------------------------------

public export
data ErrorStrategy
  = AutoFix          -- 자동 수정 시도
  | AskUser          -- 사용자에게 물어보기
  | Fallback         -- Fallback 전략 (증명 제거)
  | Reanalyze        -- 재분석
  | Terminate        -- 중단

-- 에러 레벨과 시도 횟수에 따라 전략 결정
public export
decideStrategy : RetryPolicy -> ClassifiedError -> Nat -> ErrorStrategy
decideStrategy policy err attemptCount =
  case err.level of
    SyntaxError =>
      if shouldRetry policy SyntaxError attemptCount
        then AutoFix
        else Terminate
    ProofFailure =>
      if attemptCount == 0
        then AskUser  -- 첫 번째는 사용자에게 물어봄
        else Fallback -- 사용자가 선택하지 않으면 Fallback
    DomainError =>
      if attemptCount == 0
        then Reanalyze  -- 도메인 에러는 재분석
        else Terminate
    UnknownError =>
      if attemptCount == 0
        then AskUser
        else Terminate


------------------------------------------------------------
-- 9. Fallback 전략: 증명 제거
------------------------------------------------------------

-- 증명 제거 옵션
public export
record FallbackOptions where
  constructor MkFallbackOptions
  removeProofs : Bool           -- 의존 타입 증명 제거
  useSimpleTypes : Bool         -- 단순 record 타입 사용
  addRuntimeChecks : Bool       -- 런타임 검증 추가
  notifyUser : Bool             -- 사용자에게 알림

-- 기본 Fallback 옵션
public export
defaultFallback : FallbackOptions
defaultFallback = MkFallbackOptions True True False True


------------------------------------------------------------
-- 10. 사용자 메시지 생성
------------------------------------------------------------

-- 이모지 선택
public export
getErrorEmoji : ErrorLevel -> String
getErrorEmoji SyntaxError = "⚠️"
getErrorEmoji ProofFailure = "🔍"
getErrorEmoji DomainError = "🤔"
getErrorEmoji UnknownError = "❓"

-- 사용자 친화적 메시지 생성
public export
formatUserMessage : ClassifiedError -> String
formatUserMessage err =
  let emoji = getErrorEmoji err.level
      header = emoji ++ " 컴파일 중 문제 발생\n\n"
      level = "에러 레벨: " ++ errorLevelToString err.level ++ "\n"
      location = case err.location of
                   Nothing => ""
                   Just loc => "위치: " ++ showLocation loc ++ "\n"
      cause = "\n원인: " ++ err.suggestion ++ "\n"
      warning = if not err.autoFixable
                  then "\n⚡ 이 에러는 자동 수정이 어렵습니다. 사용자 확인이 필요합니다.\n"
                  else ""
  in header ++ level ++ location ++ cause ++ warning


------------------------------------------------------------
-- 11. 예제: 에러 분류 시연
------------------------------------------------------------

-- 예제 1: 문법 에러
public export
exampleSyntaxError : ClassifiedError
exampleSyntaxError =
  classifyError "Error: Undefined name spiratiContract"

-- 예제 2: 증명 실패
public export
exampleProofError : ClassifiedError
exampleProofError =
  classifyError "Error: Can't solve constraint: 55715000 = 50650000 + 5065000"

-- 예제 3: 도메인 에러
public export
exampleDomainError : ClassifiedError
exampleDomainError =
  classifyError "Error: Type mismatch between List String and List Deliverable"


------------------------------------------------------------
-- 12. 검증 함수
------------------------------------------------------------

-- 모든 에러 레벨이 적절한 액션을 가지는지 검증
public export
validErrorClassification : ClassifiedError -> Bool
validErrorClassification err =
  not (null err.availableActions) &&
  length err.suggestion > 0

-- 재시도 정책이 합리적인지 검증
public export
validRetryPolicy : RetryPolicy -> Bool
validRetryPolicy policy =
  policy.maxSyntaxRetries > 0 &&
  policy.maxProofRetries >= 0 &&
  policy.maxDomainRetries >= 0


------------------------------------------------------------
-- 13. 타입 안전성 보장
------------------------------------------------------------

-- Note: 모든 ErrorLevel은 빈 리스트가 아닌 availableActions를 반환하므로
-- classifyError는 항상 유효한 ClassifiedError를 생성한다.
-- 증명은 getAvailableActions의 정의를 통해 확인 가능.
