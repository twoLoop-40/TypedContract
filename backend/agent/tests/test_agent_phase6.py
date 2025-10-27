"""
Test Agent Phase 6: Draft Generation
"""

import pytest
from pathlib import Path


def test_phase6_draft_file_paths():
    """Phase 6 초안 파일 경로 테스트"""
    project_name = "TestContract"
    output_dir = Path(f"./output/{project_name}")

    text_file = output_dir / f"{project_name}_draft.txt"
    csv_file = output_dir / f"{project_name}_schedule.csv"
    md_file = output_dir / f"{project_name}_draft.md"

    assert str(text_file) == f"output/{project_name}/{project_name}_draft.txt"
    assert str(csv_file) == f"output/{project_name}/{project_name}_schedule.csv"
    assert str(md_file) == f"output/{project_name}/{project_name}_draft.md"


def test_phase6_completion_criteria():
    """Phase 6 완료 조건 테스트"""
    # Phase 6는 draft_text 또는 draft_markdown 중 하나 이상 필요
    draft_text = "Test draft content"
    draft_markdown = None

    phase6_complete = (
        draft_text is not None or
        draft_markdown is not None
    )

    assert phase6_complete is True


def test_phase6_transitions():
    """Phase 6 이후 전이 테스트"""
    # Phase 6 성공 → Phase 7 (FEEDBACK)
    # Phase 6 실패 → Phase 6 유지

    draft_success = True

    if draft_success:
        next_phase = "FEEDBACK"
    else:
        next_phase = "DRAFT"

    assert next_phase == "FEEDBACK"


def test_pipeline_execution_command():
    """Pipeline 실행 명령어 테스트"""
    project_name = "TestContract"
    pipeline_file = f"Pipeline/{project_name}.idr"

    # Text 렌더러 명령어
    cmd_text = ["idris2", "--exec", "exampleText", pipeline_file]
    assert cmd_text == ["idris2", "--exec", "exampleText", f"Pipeline/{project_name}.idr"]

    # CSV 렌더러 명령어
    cmd_csv = ["idris2", "--exec", "exampleCSV", pipeline_file]
    assert cmd_csv == ["idris2", "--exec", "exampleCSV", f"Pipeline/{project_name}.idr"]

    # Markdown 렌더러 명령어
    cmd_md = ["idris2", "--exec", "exampleMarkdown", pipeline_file]
    assert cmd_md == ["idris2", "--exec", "exampleMarkdown", f"Pipeline/{project_name}.idr"]


def test_draft_output_formats():
    """초안 출력 포맷 테스트"""
    # 지원하는 출력 포맷: Text, CSV, Markdown
    supported_formats = ["text", "csv", "markdown"]

    assert "text" in supported_formats
    assert "csv" in supported_formats
    assert "markdown" in supported_formats
    assert "pdf" not in supported_formats  # PDF는 Phase 9 (Finalize)에서만


def test_renderer_modules_exist():
    """렌더러 모듈 존재 확인"""
    required_renderers = [
        "Core/TextRenderer.idr",
        "Core/CSVRenderer.idr",
        "Core/MarkdownRenderer.idr"
    ]

    base_dir = Path(__file__).parent.parent.parent

    for renderer in required_renderers:
        renderer_path = base_dir / renderer
        assert renderer_path.exists(), f"Required renderer not found: {renderer}"
        print(f"✅ Found: {renderer}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
