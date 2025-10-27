"""
WorkflowState 테스트
Spec/WorkflowTypes.idr의 명세와 일치하는지 확인
"""

import pytest
from pathlib import Path
import tempfile
import shutil

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from workflow_state import (
    WorkflowState,
    Phase,
    CompileResult,
    UserSatisfaction,
    create_initial_state
)


class TestPhase:
    """Phase enum 테스트"""

    def test_phase_values(self):
        """모든 Phase 값이 존재하는지 확인"""
        assert Phase.INPUT.value == "InputPhase"
        assert Phase.ANALYSIS.value == "AnalysisPhase"
        assert Phase.SPEC_GENERATION.value == "SpecGenerationPhase"
        assert Phase.COMPILATION.value == "CompilationPhase"
        assert Phase.DOC_IMPL.value == "DocImplPhase"
        assert Phase.DRAFT.value == "DraftPhase"
        assert Phase.FEEDBACK.value == "FeedbackPhase"
        assert Phase.REFINEMENT.value == "RefinementPhase"
        assert Phase.FINAL.value == "FinalPhase"

    def test_phase_str(self):
        """Phase의 문자열 표현 확인"""
        assert str(Phase.INPUT) == "Phase 1: Input Collection"
        assert str(Phase.FINAL) == "Phase 9: Finalization"


class TestWorkflowState:
    """WorkflowState 테스트"""

    def test_initial_state(self):
        """초기 상태 생성 테스트 (Spec/WorkflowTypes.idr의 initialState)"""
        state = create_initial_state(
            project_name="TestProject",
            user_prompt="Create a contract",
            reference_docs=["doc1.pdf", "doc2.pdf"]
        )

        assert state.project_name == "TestProject"
        assert state.current_phase == Phase.INPUT
        assert state.user_prompt == "Create a contract"
        assert state.reference_docs == ["doc1.pdf", "doc2.pdf"]
        assert state.version == 1
        assert state.compile_attempts == 0
        assert state.completed is False

    def test_input_phase_complete(self):
        """Phase 1 완료 조건 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])
        assert state.input_phase_complete() is True

        # user_prompt가 없으면 실패
        state.user_prompt = None
        assert state.input_phase_complete() is False

        # reference_docs가 비어있으면 실패
        state.user_prompt = "prompt"
        state.reference_docs = []
        assert state.input_phase_complete() is False

    def test_analysis_phase_complete(self):
        """Phase 2 완료 조건 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])
        assert state.analysis_phase_complete() is False

        state.analysis_result = "Analysis complete"
        assert state.analysis_phase_complete() is True

    def test_spec_generation_phase_complete(self):
        """Phase 3 완료 조건 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])
        assert state.spec_generation_phase_complete() is False

        state.spec_code = "module Test ..."
        assert state.spec_generation_phase_complete() is False

        state.spec_file = "Domains/Test.idr"
        assert state.spec_generation_phase_complete() is True

    def test_compilation_phase_complete(self):
        """Phase 4 완료 조건 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])
        assert state.compilation_phase_complete() is False

        # 실패한 컴파일은 완료 아님
        state.compile_result = CompileResult(success=False, error_msg="Error")
        assert state.compilation_phase_complete() is False

        # 성공한 컴파일만 완료
        state.compile_result = CompileResult(success=True)
        assert state.compilation_phase_complete() is True

    def test_can_advance(self):
        """상태 전이 가능 여부 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])

        # INPUT phase는 완료 조건 충족 시 진행 가능
        assert state.can_advance() is True

        # ANALYSIS phase로 전환
        state.current_phase = Phase.ANALYSIS
        assert state.can_advance() is False  # analysis_result가 없음

        state.analysis_result = "Done"
        assert state.can_advance() is True

    def test_phase_transitions(self):
        """Phase 전이 테스트 (Spec/WorkflowTypes.idr의 nextPhase)"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])

        # INPUT → ANALYSIS
        assert state.next_phase() == Phase.ANALYSIS

        state.current_phase = Phase.ANALYSIS
        assert state.next_phase() == Phase.SPEC_GENERATION

        state.current_phase = Phase.SPEC_GENERATION
        assert state.next_phase() == Phase.COMPILATION

        state.current_phase = Phase.COMPILATION
        assert state.next_phase() == Phase.DOC_IMPL

        state.current_phase = Phase.DOC_IMPL
        assert state.next_phase() == Phase.DRAFT

        state.current_phase = Phase.DRAFT
        assert state.next_phase() == Phase.FEEDBACK

        state.current_phase = Phase.FEEDBACK
        assert state.next_phase() == Phase.REFINEMENT

        # REFINEMENT → DRAFT (루프!)
        state.current_phase = Phase.REFINEMENT
        assert state.next_phase() == Phase.DRAFT

        # FINAL → FINAL (종료)
        state.current_phase = Phase.FINAL
        assert state.next_phase() == Phase.FINAL

    def test_advance(self):
        """전체 상태 전이 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])

        # INPUT phase 완료 후 전진
        assert state.current_phase == Phase.INPUT
        assert state.advance() is True
        assert state.current_phase == Phase.ANALYSIS

        # ANALYSIS phase 미완료 시 전진 실패
        assert state.advance() is False
        assert state.current_phase == Phase.ANALYSIS

        # 완료 후 전진
        state.analysis_result = "Done"
        assert state.advance() is True
        assert state.current_phase == Phase.SPEC_GENERATION

    def test_compile_retry_logic(self):
        """컴파일 재시도 로직 테스트 (Spec/WorkflowTypes.idr의 maxCompileAttempts)"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])

        # 초기 상태: 재시도 가능
        assert state.can_retry_compile() is True
        assert state.compile_attempts == 0

        # 5번까지 재시도 가능
        for i in range(5):
            state.increment_compile_attempts()
            assert state.compile_attempts == i + 1

        # MAX_COMPILE_ATTEMPTS (5) 도달 시 재시도 불가
        assert state.compile_attempts == 5
        assert state.can_retry_compile() is False

    def test_version_management(self):
        """버전 관리 테스트 (Spec/WorkflowTypes.idr의 incrementVersion)"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])

        assert state.version == 1
        assert state.version_string() == "v1"

        state.increment_version()
        assert state.version == 2
        assert state.version_string() == "v2"

        state.increment_version()
        assert state.version == 3
        assert state.version_string() == "v3"

    def test_progress_calculation(self):
        """진행률 계산 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])

        assert state.progress() == 0.0

        state.current_phase = Phase.ANALYSIS
        assert state.progress() == 0.1

        state.current_phase = Phase.COMPILATION
        assert state.progress() == 0.4

        state.current_phase = Phase.DRAFT
        assert state.progress() == 0.7

        state.current_phase = Phase.FINAL
        assert state.progress() == 1.0


class TestStatePersistence:
    """상태 저장/로드 테스트"""

    def setup_method(self):
        """각 테스트 전에 임시 디렉토리 생성"""
        self.temp_dir = Path(tempfile.mkdtemp())

    def teardown_method(self):
        """각 테스트 후 임시 디렉토리 삭제"""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)

    def test_save_and_load(self):
        """상태 저장 및 로드 테스트"""
        # 상태 생성 및 저장
        state = create_initial_state("TestProject", "prompt", ["doc.pdf"])
        state.analysis_result = "Analysis done"
        state.current_phase = Phase.ANALYSIS
        state.compile_attempts = 2

        state.save(self.temp_dir)

        # 저장된 파일 확인
        state_file = self.temp_dir / "TestProject" / "workflow_state.json"
        assert state_file.exists()

        # 로드
        loaded_state = WorkflowState.load("TestProject", self.temp_dir)
        assert loaded_state is not None
        assert loaded_state.project_name == "TestProject"
        assert loaded_state.user_prompt == "prompt"
        assert loaded_state.reference_docs == ["doc.pdf"]
        assert loaded_state.analysis_result == "Analysis done"
        assert loaded_state.current_phase == Phase.ANALYSIS
        assert loaded_state.compile_attempts == 2

    def test_load_nonexistent(self):
        """존재하지 않는 프로젝트 로드 시 None 반환"""
        loaded = WorkflowState.load("NonExistent", self.temp_dir)
        assert loaded is None

    def test_save_with_compile_result(self):
        """CompileResult 포함 저장/로드 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])
        state.compile_result = CompileResult(
            success=False,
            error_msg="Type error at line 10"
        )

        state.save(self.temp_dir)
        loaded = WorkflowState.load("Test", self.temp_dir)

        assert loaded.compile_result is not None
        assert loaded.compile_result.success is False
        assert loaded.compile_result.error_msg == "Type error at line 10"

    def test_save_with_user_satisfaction(self):
        """UserSatisfaction 포함 저장/로드 테스트"""
        state = create_initial_state("Test", "prompt", ["doc.pdf"])
        state.user_satisfaction = UserSatisfaction(
            satisfied=False,
            revision_request="Change the contract terms"
        )

        state.save(self.temp_dir)
        loaded = WorkflowState.load("Test", self.temp_dir)

        assert loaded.user_satisfaction is not None
        assert loaded.user_satisfaction.satisfied is False
        assert loaded.user_satisfaction.revision_request == "Change the contract terms"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
