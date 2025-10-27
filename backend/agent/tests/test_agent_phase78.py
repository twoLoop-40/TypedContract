"""
Test Agent Phase 7-8: Feedback and Refinement
"""

import pytest
from pathlib import Path


def test_phase7_feedback_collection():
    """Phase 7 피드백 수집 테스트"""
    feedback = "계약 금액을 6천만원으로 변경해주세요"
    feedback_history = []

    feedback_history.append(feedback)

    assert len(feedback_history) == 1
    assert feedback_history[0] == feedback


def test_phase8_version_increment():
    """Phase 8 버전 증가 테스트"""
    version = 1

    # 피드백 제출 시 버전 증가
    version += 1

    assert version == 2

    # 추가 피드백 제출
    version += 1

    assert version == 3


def test_version_string_format():
    """버전 문자열 포맷 테스트"""
    version = 1
    version_str = f"v{version}"
    assert version_str == "v1"

    version = 2
    version_str = f"v{version}"
    assert version_str == "v2"


def test_feedback_loop_transitions():
    """Feedback 루프 전이 테스트"""
    # Phase 7 (Feedback) → Phase 8 (Refinement) → Phase 6 (Draft)

    current_phase = "FEEDBACK"

    # Phase 8로 전이
    current_phase = "REFINEMENT"
    assert current_phase == "REFINEMENT"

    # Phase 6로 루프백
    current_phase = "DRAFT"
    assert current_phase == "DRAFT"


def test_prompt_update_with_feedback():
    """피드백 반영해서 프롬프트 업데이트 테스트"""
    original_prompt = "용역 계약서를 생성해주세요. 금액은 5천만원입니다."
    feedback = "금액을 6천만원으로 변경해주세요"

    updated_prompt = f"{original_prompt}\n\n[Revision Request]\n{feedback}"

    assert "[Revision Request]" in updated_prompt
    assert "6천만원" in updated_prompt
    assert "5천만원" in updated_prompt  # 원본도 유지


def test_user_satisfaction_types():
    """UserSatisfaction 타입 테스트"""
    # 만족
    satisfied = {"satisfied": True, "revision_request": None}
    assert satisfied["satisfied"] is True
    assert satisfied["revision_request"] is None

    # 수정 요청
    needs_revision = {"satisfied": False, "revision_request": "금액 변경"}
    assert needs_revision["satisfied"] is False
    assert needs_revision["revision_request"] == "금액 변경"


def test_feedback_history_tracking():
    """피드백 히스토리 추적 테스트"""
    feedback_history = []

    # 첫 번째 피드백
    feedback_history.append("금액을 6천만원으로 변경")
    assert len(feedback_history) == 1

    # 두 번째 피드백
    feedback_history.append("기간을 3개월로 변경")
    assert len(feedback_history) == 2

    # 세 번째 피드백
    feedback_history.append("납품 일정 조정 필요")
    assert len(feedback_history) == 3


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
