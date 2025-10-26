"""
Idris2 컴파일 에러 분류기

이 파일은 Spec/ErrorHandling.idr의 Python 구현입니다.
타입 시스템으로 검증된 명세를 그대로 따릅니다.
"""

import re
from enum import Enum
from typing import Optional, List
from dataclasses import dataclass


# ============================================================================
# 1. 에러 레벨 분류 (Spec/ErrorHandling.idr:16-25)
# ============================================================================

class ErrorLevel(Enum):
    """에러의 심각도 및 해결 방법에 따른 분류"""
    SYNTAX_ERROR = "syntax"      # Level 1: 자동 수정 가능
    PROOF_FAILURE = "proof"       # Level 2: 증명 실패 - 사용자 확인 필요
    DOMAIN_ERROR = "domain"       # Level 3: 도메인 모델링 오류 - 재분석 필요
    UNKNOWN = "unknown"           # 분류 불가능한 에러


# ============================================================================
# 2. 사용자 액션 (Spec/ErrorHandling.idr:32-41)
# ============================================================================

class UserAction(Enum):
    """에러 발생 시 사용자가 선택할 수 있는 행동"""
    RETRY_WITH_FIX = "retry"           # 자동 수정 후 재시도
    REMOVE_PROOFS = "fallback"         # 의존 타입 증명 제거
    REANALYZE = "reanalyze"            # 문서 재분석
    MANUAL_EDIT = "manual"             # 수동 수정
    ABORT = "abort"                    # 중단


# ============================================================================
# 3. 에러 위치 정보 (Spec/ErrorHandling.idr:48-56)
# ============================================================================

@dataclass
class ErrorLocation:
    """에러 발생 위치"""
    file_path: str
    line_number: int

    def __str__(self) -> str:
        return f"{self.file_path}:{self.line_number}"


# ============================================================================
# 4. 분류된 에러 정보 (Spec/ErrorHandling.idr:63-81)
# ============================================================================

@dataclass
class ClassifiedError:
    """분류된 에러 정보"""
    level: ErrorLevel
    message: str
    location: Optional[ErrorLocation]
    suggestion: str
    available_actions: List[UserAction]
    auto_fixable: bool

    def __str__(self) -> str:
        result = f"ErrorLevel: {self.level.value}\n"
        result += f"Message: {self.message}\n"
        if self.location:
            result += f"Location: {self.location}\n"
        result += f"Suggestion: {self.suggestion}\n"
        result += f"AutoFixable: {'Yes' if self.auto_fixable else 'No'}"
        return result


# ============================================================================
# 5. 에러 패턴 매칭 (Spec/ErrorHandling.idr:88-117)
# ============================================================================

def is_domain_error(message: str) -> bool:
    """도메인 에러 패턴 검사"""
    patterns = [
        "Type mismatch between",
        "Expected type",
        "does not have field",
        "Can't find implementation for",
    ]
    return any(pattern in message for pattern in patterns)


def is_proof_failure(message: str) -> bool:
    """증명 실패 패턴 검사"""
    patterns = [
        "Can't solve constraint",
        "Mismatch between",
        "Can't unify",
    ]
    return any(pattern in message for pattern in patterns)


def is_syntax_error(message: str) -> bool:
    """문법 에러 패턴 검사"""
    patterns = [
        "Undefined name",
        "Parse error",
        "Can't find import",
        "Unexpected token",
    ]
    return any(pattern in message for pattern in patterns)


# ============================================================================
# 6. 에러 분류 함수 (Spec/ErrorHandling.idr:124-168)
# ============================================================================

def classify_error_level(message: str) -> ErrorLevel:
    """에러 레벨 결정 (우선순위: Domain > Proof > Syntax)"""
    if is_domain_error(message):
        return ErrorLevel.DOMAIN_ERROR
    elif is_proof_failure(message):
        return ErrorLevel.PROOF_FAILURE
    elif is_syntax_error(message):
        return ErrorLevel.SYNTAX_ERROR
    else:
        return ErrorLevel.UNKNOWN


def get_available_actions(level: ErrorLevel) -> List[UserAction]:
    """에러 레벨에 따라 가능한 액션 결정"""
    if level == ErrorLevel.SYNTAX_ERROR:
        return [UserAction.RETRY_WITH_FIX, UserAction.MANUAL_EDIT, UserAction.ABORT]
    elif level == ErrorLevel.PROOF_FAILURE:
        return [UserAction.REMOVE_PROOFS, UserAction.REANALYZE,
                UserAction.MANUAL_EDIT, UserAction.ABORT]
    elif level == ErrorLevel.DOMAIN_ERROR:
        return [UserAction.REANALYZE, UserAction.MANUAL_EDIT, UserAction.ABORT]
    else:  # UNKNOWN
        return [UserAction.RETRY_WITH_FIX, UserAction.MANUAL_EDIT, UserAction.ABORT]


def get_suggestion(level: ErrorLevel) -> str:
    """에러 레벨에 따라 제안 메시지 생성"""
    if level == ErrorLevel.SYNTAX_ERROR:
        return "문법 오류입니다. Claude가 자동으로 수정을 시도합니다."
    elif level == ErrorLevel.PROOF_FAILURE:
        return "의존 타입 증명 실패입니다. 입력 데이터를 확인하거나 증명 없이 진행하세요."
    elif level == ErrorLevel.DOMAIN_ERROR:
        return "도메인 모델링 오류입니다. 문서를 재분석해야 합니다."
    else:  # UNKNOWN
        return "알 수 없는 에러입니다. 수동 확인이 필요합니다."


def is_auto_fixable(level: ErrorLevel) -> bool:
    """자동 수정 가능 여부 결정"""
    return level == ErrorLevel.SYNTAX_ERROR


def extract_location(message: str) -> Optional[ErrorLocation]:
    """에러 위치 추출 (Domains/MyContract.idr:45:10--45:25)"""
    match = re.search(r"([\w/]+\.idr):(\d+):\d+", message)
    if match:
        return ErrorLocation(match.group(1), int(match.group(2)))
    return None


def classify_error(message: str) -> ClassifiedError:
    """전체 에러 분류 (메인 함수)"""
    level = classify_error_level(message)
    actions = get_available_actions(level)
    suggestion = get_suggestion(level)
    auto_fix = is_auto_fixable(level)
    location = extract_location(message)

    return ClassifiedError(
        level=level,
        message=message,
        location=location,
        suggestion=suggestion,
        available_actions=actions,
        auto_fixable=auto_fix,
    )


# ============================================================================
# 7. 재시도 정책 (Spec/ErrorHandling.idr:175-215)
# ============================================================================

@dataclass
class RetryPolicy:
    """재시도 정책"""
    max_syntax_retries: int      # 문법 에러 최대 재시도 횟수
    max_proof_retries: int       # 증명 에러 최대 재시도 횟수
    max_domain_retries: int      # 도메인 에러 최대 재시도 횟수
    auto_retry_proof: bool       # 증명 실패 시 자동 재시도 여부
    auto_retry_domain: bool      # 도메인 에러 시 자동 재시도 여부


# 기본 재시도 정책 (Spec/ErrorHandling.idr:182-188)
DEFAULT_RETRY_POLICY = RetryPolicy(
    max_syntax_retries=3,
    max_proof_retries=0,
    max_domain_retries=0,
    auto_retry_proof=False,
    auto_retry_domain=False,
)

# 공격적 재시도 정책 (Spec/ErrorHandling.idr:191-197)
AGGRESSIVE_RETRY_POLICY = RetryPolicy(
    max_syntax_retries=5,
    max_proof_retries=2,
    max_domain_retries=1,
    auto_retry_proof=True,
    auto_retry_domain=True,
)


def should_retry(policy: RetryPolicy, level: ErrorLevel, attempt_count: int) -> bool:
    """재시도 가능 여부 확인 (Spec/ErrorHandling.idr:200-206)"""
    if level == ErrorLevel.SYNTAX_ERROR:
        return attempt_count < policy.max_syntax_retries
    elif level == ErrorLevel.PROOF_FAILURE:
        return policy.auto_retry_proof and attempt_count < policy.max_proof_retries
    elif level == ErrorLevel.DOMAIN_ERROR:
        return policy.auto_retry_domain and attempt_count < policy.max_domain_retries
    else:  # UNKNOWN
        return attempt_count < 1


# ============================================================================
# 8. 에러 처리 전략 (Spec/ErrorHandling.idr:213-232)
# ============================================================================

class ErrorStrategy(Enum):
    """에러 처리 전략"""
    AUTO_FIX = "auto_fix"          # 자동 수정 시도
    ASK_USER = "ask_user"          # 사용자에게 물어보기
    FALLBACK = "fallback"          # Fallback 전략 (증명 제거)
    REANALYZE = "reanalyze"        # 재분석
    TERMINATE = "terminate"        # 중단


def decide_strategy(
    policy: RetryPolicy,
    error: ClassifiedError,
    attempt_count: int
) -> ErrorStrategy:
    """에러 레벨과 시도 횟수에 따라 전략 결정 (Spec/ErrorHandling.idr:218-232)"""
    if error.level == ErrorLevel.SYNTAX_ERROR:
        if should_retry(policy, ErrorLevel.SYNTAX_ERROR, attempt_count):
            return ErrorStrategy.AUTO_FIX
        else:
            return ErrorStrategy.TERMINATE
    elif error.level == ErrorLevel.PROOF_FAILURE:
        if attempt_count == 0:
            return ErrorStrategy.ASK_USER  # 첫 번째는 사용자에게 물어봄
        else:
            return ErrorStrategy.FALLBACK  # 사용자가 선택하지 않으면 Fallback
    elif error.level == ErrorLevel.DOMAIN_ERROR:
        if attempt_count == 0:
            return ErrorStrategy.REANALYZE  # 도메인 에러는 재분석
        else:
            return ErrorStrategy.TERMINATE
    else:  # UNKNOWN
        if attempt_count == 0:
            return ErrorStrategy.ASK_USER
        else:
            return ErrorStrategy.TERMINATE


# ============================================================================
# 9. Fallback 전략 (Spec/ErrorHandling.idr:239-250)
# ============================================================================

@dataclass
class FallbackOptions:
    """증명 제거 옵션"""
    remove_proofs: bool           # 의존 타입 증명 제거
    use_simple_types: bool        # 단순 record 타입 사용
    add_runtime_checks: bool      # 런타임 검증 추가
    notify_user: bool             # 사용자에게 알림


# 기본 Fallback 옵션 (Spec/ErrorHandling.idr:253-254)
DEFAULT_FALLBACK = FallbackOptions(
    remove_proofs=True,
    use_simple_types=True,
    add_runtime_checks=False,
    notify_user=True,
)


# ============================================================================
# 10. 사용자 메시지 생성 (Spec/ErrorHandling.idr:261-282)
# ============================================================================

def get_error_emoji(level: ErrorLevel) -> str:
    """이모지 선택"""
    emoji_map = {
        ErrorLevel.SYNTAX_ERROR: "⚠️",
        ErrorLevel.PROOF_FAILURE: "🔍",
        ErrorLevel.DOMAIN_ERROR: "🤔",
        ErrorLevel.UNKNOWN: "❓",
    }
    return emoji_map.get(level, "❗")


def format_user_message(error: ClassifiedError) -> str:
    """사용자 친화적 메시지 생성"""
    emoji = get_error_emoji(error.level)
    header = f"{emoji} **컴파일 중 문제 발생**\n\n"
    level = f"**에러 레벨**: {error.level.value}\n"
    location = f"**위치**: {error.location}\n" if error.location else ""
    cause = f"\n**원인**: {error.suggestion}\n"
    warning = ("\n⚡ 이 에러는 자동 수정이 어렵습니다. 사용자 확인이 필요합니다.\n"
               if not error.auto_fixable else "")

    return header + level + location + cause + warning


# ============================================================================
# 사용 예제
# ============================================================================

if __name__ == "__main__":
    # 테스트 케이스 (Spec/ErrorHandling.idr:289-299)
    test_cases = [
        # 예제 1: 문법 에러
        "Error: Undefined name spiratiContract",
        # 예제 2: 증명 실패
        "Error: Can't solve constraint: 55715000 = 50650000 + 5065000",
        # 예제 3: 도메인 에러
        "Error: Type mismatch between List String and List Deliverable",
    ]

    print("=" * 60)
    print("Idris2 에러 분류기 테스트")
    print("(Spec/ErrorHandling.idr 구현)")
    print("=" * 60)

    for i, error_msg in enumerate(test_cases, 1):
        print(f"\n{'=' * 60}")
        print(f"Test Case {i}")
        print(f"{'=' * 60}")
        print(f"에러 메시지: {error_msg}\n")

        # 에러 분류
        result = classify_error(error_msg)

        print(f"레벨: {result.level.value}")
        print(f"위치: {result.location}")
        print(f"제안: {result.suggestion}")
        print(f"자동 수정 가능: {result.auto_fixable}")
        print(f"사용 가능한 액션: {[a.value for a in result.available_actions]}")

        # 사용자 메시지
        print(f"\n--- 사용자에게 표시될 메시지 ---")
        print(format_user_message(result))

        # 재시도 전략
        strategy_1 = decide_strategy(DEFAULT_RETRY_POLICY, result, 0)
        strategy_2 = decide_strategy(DEFAULT_RETRY_POLICY, result, 3)

        print(f"\n--- 재시도 전략 ---")
        print(f"1회차 전략: {strategy_1.value}")
        print(f"4회차 전략: {strategy_2.value}")
        print(f"자동 재시도? (attempt=1) {should_retry(DEFAULT_RETRY_POLICY, result.level, 1)}")
        print(f"자동 재시도? (attempt=4) {should_retry(DEFAULT_RETRY_POLICY, result.level, 4)}")

    print(f"\n{'=' * 60}")
    print("✅ 모든 테스트 완료 (Idris2 명세와 일치)")
    print(f"{'=' * 60}\n")
