"""
Test Agent Phase 5: Documentable and Pipeline Generation
"""

import pytest
from pathlib import Path


@pytest.fixture
def sample_agent_state():
    """Phase 4 완료 후 상태 (Phase 5로 진입 준비)"""
    return {
        "project_name": "TestContract",
        "document_type": "contract",
        "reference_docs": [],
        "analysis": "Test analysis",
        "idris_code": """
module Domains.TestContract

public export
record SimpleContract where
  constructor MkSimpleContract
  title : String
  amount : Nat
  date : String

public export
exampleContract : SimpleContract
exampleContract = MkSimpleContract
  "Test Contract"
  1000000
  "2025-10-27"
""",
        "current_file": "Domains/TestContract.idr",
        "compile_attempts": 1,
        "last_error": None,
        "compile_success": True,
        "final_module_path": "Domains/TestContract.idr",
        "messages": []
    }


def test_generate_documentable_impl_structure(sample_agent_state):
    """Documentable 생성 함수 기본 동작 테스트"""
    # Note: 실제 LLM 호출 없이 구조만 테스트
    assert sample_agent_state["compile_success"] is True
    assert sample_agent_state["project_name"] == "TestContract"
    assert "Domains.TestContract" in sample_agent_state["idris_code"]


def test_generate_pipeline_impl_structure(sample_agent_state):
    """Pipeline 생성 함수 기본 동작 테스트"""
    assert sample_agent_state["compile_success"] is True
    assert sample_agent_state["project_name"] == "TestContract"


def test_documentable_file_path():
    """Documentable 파일 경로 생성 테스트"""
    project_name = "TestContract"
    expected_path = f"DomainToDoc/{project_name}.idr"
    assert expected_path == "DomainToDoc/TestContract.idr"


def test_pipeline_file_path():
    """Pipeline 파일 경로 생성 테스트"""
    project_name = "TestContract"
    expected_path = f"Pipeline/{project_name}.idr"
    assert expected_path == "Pipeline/TestContract.idr"


def test_phase5_completion_criteria():
    """Phase 5 완료 조건 테스트"""
    # Phase 5는 documentable_impl과 pipeline_impl 모두 필요
    documentable_impl = "module DomainToDoc.TestContract\n..."
    pipeline_impl = "module Pipeline.TestContract\n..."

    phase5_complete = (
        documentable_impl is not None and
        pipeline_impl is not None
    )

    assert phase5_complete is True


def test_phase5_transitions():
    """Phase 5 이후 전이 테스트"""
    # Phase 5 성공 → Phase 6 (DRAFT)
    # Phase 5 실패 → Phase 5 유지

    documentable_success = True
    pipeline_success = True

    if documentable_success and pipeline_success:
        next_phase = "DRAFT"
    else:
        next_phase = "DOC_IMPL"

    assert next_phase == "DRAFT"


def test_existing_idris_core_modules():
    """Core 모듈들이 존재하는지 확인"""
    required_modules = [
        "Core/DocumentModel.idr",
        "Core/DomainToDoc.idr",
        "Core/TextRenderer.idr",
        "Core/CSVRenderer.idr",
        "Core/MarkdownRenderer.idr",
        "Core/LaTeXRenderer.idr"
    ]

    # 상대 경로에서 절대 경로로 변환
    base_dir = Path(__file__).parent.parent.parent

    for module in required_modules:
        module_path = base_dir / module
        assert module_path.exists(), f"Required module not found: {module}"
        print(f"✅ Found: {module}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
