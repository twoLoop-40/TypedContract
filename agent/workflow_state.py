"""
워크플로우 상태 관리
Spec/WorkflowTypes.idr의 Python 구현
"""

from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Optional, List
from pathlib import Path
import json


# ============================================================================
# Phase (Spec/WorkflowTypes.idr의 Phase)
# ============================================================================

class Phase(Enum):
    """워크플로우 단계 (10개 Phase - ErrorHandling 추가)"""
    INPUT = "InputPhase"                    # Phase 1: 입력 수집
    ANALYSIS = "AnalysisPhase"              # Phase 2: 문서 분석
    SPEC_GENERATION = "SpecGenerationPhase" # Phase 3: Idris2 명세 생성
    COMPILATION = "CompilationPhase"        # Phase 4: 컴파일 및 수정
    ERROR_HANDLING = "ErrorHandlingPhase"   # Phase 4b: 에러 분류 및 처리
    DOC_IMPL = "DocImplPhase"               # Phase 5: 문서 구현 생성
    DRAFT = "DraftPhase"                    # Phase 6: 초안 생성
    FEEDBACK = "FeedbackPhase"              # Phase 7: 사용자 피드백
    REFINEMENT = "RefinementPhase"          # Phase 8: 반복 개선
    FINAL = "FinalPhase"                    # Phase 9: 최종 출력

    def __str__(self):
        """Show Phase"""
        labels = {
            Phase.INPUT: "Phase 1: Input Collection",
            Phase.ANALYSIS: "Phase 2: Analysis",
            Phase.SPEC_GENERATION: "Phase 3: Spec Generation",
            Phase.COMPILATION: "Phase 4: Compilation",
            Phase.ERROR_HANDLING: "Phase 4b: Error Handling",
            Phase.DOC_IMPL: "Phase 5: Document Implementation",
            Phase.DRAFT: "Phase 6: Draft Generation",
            Phase.FEEDBACK: "Phase 7: User Feedback",
            Phase.REFINEMENT: "Phase 8: Refinement",
            Phase.FINAL: "Phase 9: Finalization"
        }
        return labels[self]


# ============================================================================
# CompileResult
# ============================================================================

@dataclass
class CompileResult:
    """컴파일 결과"""
    success: bool
    error_msg: Optional[str] = None

    def __str__(self):
        if self.success:
            return "Compilation succeeded"
        return f"Compilation failed: {self.error_msg}"


# ============================================================================
# UserSatisfaction
# ============================================================================

@dataclass
class UserSatisfaction:
    """사용자 만족도"""
    satisfied: bool
    revision_request: Optional[str] = None

    def __str__(self):
        if self.satisfied:
            return "User is satisfied"
        return f"User requests revision: {self.revision_request}"


# ============================================================================
# WorkflowState (핵심!)
# ============================================================================

@dataclass
class WorkflowState:
    """
    워크플로우 상태
    Spec/WorkflowTypes.idr의 WorkflowState record와 동일
    """
    # 기본 정보
    project_name: str
    current_phase: Phase = Phase.INPUT

    # Phase 1: 입력
    user_prompt: Optional[str] = None
    reference_docs: List[str] = field(default_factory=list)

    # Phase 2: 분석
    analysis_result: Optional[str] = None

    # Phase 3-4: 명세 생성
    spec_code: Optional[str] = None
    spec_file: Optional[str] = None
    compile_attempts: int = 0
    compile_result: Optional[CompileResult] = None

    # Phase 4b: 에러 핸들링
    classified_error: Optional[dict] = None  # ClassifiedError (JSON)
    error_strategy: Optional[str] = None     # ErrorStrategy
    error_suggestion: Optional[dict] = None  # 동일 에러 3회 시 사용자 제안
    user_action: Optional[str] = None        # 사용자 선택한 액션
    error_history: List[str] = field(default_factory=list)  # 최근 에러 메시지 추적

    # Phase 5: 문서 구현
    documentable_impl: Optional[str] = None
    pipeline_impl: Optional[str] = None

    # Phase 6: 초안
    draft_text: Optional[str] = None
    draft_markdown: Optional[str] = None
    draft_csv: Optional[str] = None

    # Phase 7-8: 피드백 및 개선
    version: int = 1
    feedback_history: List[str] = field(default_factory=list)
    user_satisfaction: Optional[UserSatisfaction] = None

    # Phase 9: 최종
    generate_pdf: bool = False
    final_pdf_path: Optional[str] = None
    completed: bool = False

    # 실시간 로그 (프론트엔드 모니터링용)
    logs: List[str] = field(default_factory=list)  # 최근 100개 로그 유지

    # 활동 추적 (백엔드 활동 상태)
    is_active: bool = False  # 현재 작업 중인지
    last_activity: Optional[str] = None  # 마지막 활동 시간 (ISO format)
    current_action: Optional[str] = None  # 현재 수행 중인 작업

    # ========================================================================
    # 상태 검증 (Spec/WorkflowTypes.idr의 검증 함수들)
    # ========================================================================

    def input_phase_complete(self) -> bool:
        """Phase 1 완료 조건"""
        return self.user_prompt is not None  # reference_docs는 optional

    def analysis_phase_complete(self) -> bool:
        """Phase 2 완료 조건"""
        return self.analysis_result is not None

    def spec_generation_phase_complete(self) -> bool:
        """Phase 3 완료 조건"""
        return self.spec_code is not None and self.spec_file is not None

    def compilation_phase_complete(self) -> bool:
        """Phase 4 완료 조건"""
        return (
            self.compile_result is not None and
            self.compile_result.success
        )

    def error_handling_phase_complete(self) -> bool:
        """Phase 4b 완료 조건"""
        return (
            self.classified_error is not None and
            self.error_strategy is not None
        )

    def doc_impl_phase_complete(self) -> bool:
        """Phase 5 완료 조건"""
        return (
            self.documentable_impl is not None and
            self.pipeline_impl is not None
        )

    def draft_phase_complete(self) -> bool:
        """Phase 6 완료 조건"""
        return (
            self.draft_text is not None or
            self.draft_markdown is not None
        )

    def workflow_complete(self) -> bool:
        """전체 워크플로우 완료 조건"""
        return self.completed and self.current_phase == Phase.FINAL

    # ========================================================================
    # 로그 관리
    # ========================================================================

    def add_log(self, message: str) -> None:
        """
        로그 메시지 추가 (최근 100개만 유지)

        Args:
            message: 로그 메시지
        """
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.logs.append(log_entry)
        # 최근 100개만 유지
        if len(self.logs) > 100:
            self.logs = self.logs[-100:]

    def mark_active(self, action: str):
        """백엔드 활동 시작 표시"""
        from datetime import datetime
        self.is_active = True
        self.last_activity = datetime.now().isoformat()
        self.current_action = action
        self.add_log(f"🔵 {action}")

    def mark_inactive(self):
        """백엔드 활동 종료 표시"""
        from datetime import datetime
        self.is_active = False
        self.last_activity = datetime.now().isoformat()
        self.current_action = None

    # ========================================================================
    # 상태 전이 (Spec/WorkflowTypes.idr의 전이 함수들)
    # ========================================================================

    def can_advance(self) -> bool:
        """다음 단계로 전진 가능한지 확인"""
        phase_checks = {
            Phase.INPUT: self.input_phase_complete,
            Phase.ANALYSIS: self.analysis_phase_complete,
            Phase.SPEC_GENERATION: self.spec_generation_phase_complete,
            Phase.COMPILATION: self.compilation_phase_complete,
            Phase.DOC_IMPL: self.doc_impl_phase_complete,
            Phase.DRAFT: self.draft_phase_complete,
            Phase.FEEDBACK: lambda: True,  # 항상 가능
            Phase.REFINEMENT: lambda: self.user_satisfaction is not None,
            Phase.FINAL: lambda: True
        }
        return phase_checks[self.current_phase]()

    def next_phase(self) -> Phase:
        """다음 Phase 결정"""
        transitions = {
            Phase.INPUT: Phase.ANALYSIS,
            Phase.ANALYSIS: Phase.SPEC_GENERATION,
            Phase.SPEC_GENERATION: Phase.COMPILATION,
            Phase.COMPILATION: Phase.DOC_IMPL,
            Phase.DOC_IMPL: Phase.DRAFT,
            Phase.DRAFT: Phase.FEEDBACK,
            Phase.FEEDBACK: Phase.REFINEMENT,
            Phase.REFINEMENT: Phase.DRAFT,  # 루프!
            Phase.FINAL: Phase.FINAL  # 종료
        }
        return transitions[self.current_phase]

    def advance(self) -> bool:
        """상태 전이 (검증 포함)"""
        if self.can_advance():
            self.current_phase = self.next_phase()
            return True
        return False

    # ========================================================================
    # 컴파일 재시도 로직
    # ========================================================================

    MAX_COMPILE_ATTEMPTS = 5

    def can_retry_compile(self) -> bool:
        """재시도 가능 여부"""
        return self.compile_attempts < self.MAX_COMPILE_ATTEMPTS

    def increment_compile_attempts(self):
        """컴파일 시도 증가"""
        self.compile_attempts += 1

    # ========================================================================
    # 버전 관리
    # ========================================================================

    def increment_version(self):
        """새 버전 생성"""
        self.version += 1

    def version_string(self) -> str:
        """버전 번호를 문자열로"""
        return f"v{self.version}"

    # ========================================================================
    # 진행률 계산
    # ========================================================================

    def progress(self) -> float:
        """현재 진행률 (0.0 ~ 1.0)"""
        phase_weights = {
            Phase.INPUT: 0.0,
            Phase.ANALYSIS: 0.1,
            Phase.SPEC_GENERATION: 0.2,
            Phase.COMPILATION: 0.4,
            Phase.DOC_IMPL: 0.6,
            Phase.DRAFT: 0.7,
            Phase.FEEDBACK: 0.8,
            Phase.REFINEMENT: 0.85,
            Phase.FINAL: 1.0
        }
        return phase_weights.get(self.current_phase, 0.0)

    # ========================================================================
    # 저장/로드
    # ========================================================================

    def save(self, output_dir: Path):
        """상태를 JSON 파일로 저장"""
        state_file = output_dir / self.project_name / "workflow_state.json"
        state_file.parent.mkdir(parents=True, exist_ok=True)

        # dataclass → dict → JSON
        data = asdict(self)

        # Enum → string 변환
        data['current_phase'] = self.current_phase.value

        # CompileResult 변환
        if self.compile_result:
            data['compile_result'] = {
                'success': self.compile_result.success,
                'error_msg': self.compile_result.error_msg
            }

        # UserSatisfaction 변환
        if self.user_satisfaction:
            data['user_satisfaction'] = {
                'satisfied': self.user_satisfaction.satisfied,
                'revision_request': self.user_satisfaction.revision_request
            }

        with open(state_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    @classmethod
    def load(cls, project_name: str, output_dir: Path) -> Optional['WorkflowState']:
        """JSON 파일에서 상태 로드"""
        state_file = output_dir / project_name / "workflow_state.json"

        if not state_file.exists():
            return None

        with open(state_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # string → Enum 변환
        data['current_phase'] = Phase(data['current_phase'])

        # CompileResult 복원
        if data.get('compile_result'):
            data['compile_result'] = CompileResult(**data['compile_result'])

        # UserSatisfaction 복원
        if data.get('user_satisfaction'):
            data['user_satisfaction'] = UserSatisfaction(**data['user_satisfaction'])

        return cls(**data)


# ============================================================================
# 헬퍼 함수
# ============================================================================

def create_initial_state(
    project_name: str,
    user_prompt: str,
    reference_docs: List[str]
) -> WorkflowState:
    """
    초기 상태 생성
    Spec/WorkflowTypes.idr의 initialState 함수
    """
    return WorkflowState(
        project_name=project_name,
        current_phase=Phase.INPUT,
        user_prompt=user_prompt,
        reference_docs=reference_docs
    )
