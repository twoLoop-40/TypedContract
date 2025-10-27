"""
FastAPI Backend for TypedContract
Handles document upload, Idris2 generation, and user feedback
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Form, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional
import subprocess
import os
from pathlib import Path

# Workflow state management (Spec/WorkflowTypes.idr의 Python 구현)
from agent.workflow_state import (
    WorkflowState,
    Phase,
    CompileResult,
    UserSatisfaction,
    create_initial_state
)

# LangGraph agent
from agent.agent import run_workflow, to_pascal_case

app = FastAPI(
    title="TypedContract API",
    description="Type-safe contract and document generation system with formal specifications",
    version="1.0.0"
)

# CORS middleware for Next.js frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://frontend:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# Models
# ============================================================

class ProjectInitRequest(BaseModel):
    project_name: str
    user_prompt: str
    reference_docs: List[str]

class GenerationStatus(BaseModel):
    project_name: str
    current_phase: str
    progress: float
    completed: bool
    is_active: bool = False  # 백엔드가 현재 작업 중인지 여부
    last_activity: Optional[str] = None  # 마지막 활동 시간 (ISO format)
    current_action: Optional[str] = None  # 현재 수행 중인 작업 설명
    user_prompt: Optional[str] = None  # 원래 사용자 프롬프트
    error: Optional[str] = None
    classified_error: Optional[dict] = None  # ClassifiedError
    error_strategy: Optional[str] = None
    error_suggestion: Optional[dict] = None  # 동일 에러 3회 시 사용자 제안
    available_actions: Optional[List[str]] = None
    logs: List[str] = []  # 실시간 로그 (최근 100개)

class FeedbackRequest(BaseModel):
    project_name: str
    feedback: str

class ResumeRequest(BaseModel):
    updated_prompt: Optional[str] = None  # 수정된 프롬프트 (선택)
    restart_from_analysis: bool = False    # 분석부터 다시 시작할지

class AutoPauseResumeRequest(BaseModel):
    """AutoPaused 상태에서 재개 요청"""
    option: str  # ResumeOption: retry_with_new_prompt, skip_validation, manual_fix, cancel
    new_prompt: Optional[str] = None  # option=retry_with_new_prompt일 때 필요
    new_docs: Optional[List[str]] = None  # option=retry_with_more_docs일 때 필요
    fixed_file_path: Optional[str] = None  # option=manual_fix일 때 필요

class DraftResponse(BaseModel):
    project_name: str
    text_content: Optional[str] = None
    markdown_content: Optional[str] = None
    csv_content: Optional[str] = None

# ============================================================
# Endpoints
# ============================================================

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "ScaleDeepSpec API is running"}

@app.get("/health")
async def health():
    """Health check for Docker"""
    idris_version = subprocess.run(
        ["idris2", "--version"],
        capture_output=True,
        text=True
    )
    return {
        "status": "healthy",
        "idris2": idris_version.stdout.strip() if idris_version.returncode == 0 else "not available"
    }

@app.post("/api/project/init")
async def initialize_project(request: ProjectInitRequest):
    """
    Initialize a new document generation project

    Phase 1: Input Collection (Spec/WorkflowTypes.idr의 InputPhase)
    - Create WorkflowState
    - Store user prompt and reference documents
    - Save state to disk
    """
    project_dir = Path(f"./output/{request.project_name}")
    project_dir.mkdir(parents=True, exist_ok=True)

    # WorkflowState 생성 (Spec/WorkflowTypes.idr의 initialState)
    state = create_initial_state(
        project_name=request.project_name,
        user_prompt=request.user_prompt,
        reference_docs=request.reference_docs
    )

    # 상태 저장
    state.save(Path("./output"))

    # Save user prompt (legacy)
    (project_dir / "prompt.txt").write_text(request.user_prompt)

    return {
        "project_name": request.project_name,
        "status": "initialized",
        "current_phase": str(state.current_phase),
        "progress": state.progress(),
        "message": "Project initialized successfully"
    }

@app.post("/api/project/{project_name}/upload")
async def upload_reference_docs(
    project_name: str,
    files: List[UploadFile] = File(...)
):
    """
    Upload reference documents for analysis
    Supports: PDF, DOCX, images
    """
    project_dir = Path(f"./output/{project_name}/references")
    project_dir.mkdir(parents=True, exist_ok=True)

    uploaded_files = []
    for file in files:
        file_path = project_dir / file.filename
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        uploaded_files.append(str(file_path))

    return {
        "project_name": project_name,
        "uploaded_files": uploaded_files,
        "count": len(uploaded_files)
    }

@app.post("/api/project/{project_name}/generate")
async def generate_spec(project_name: str, background_tasks: BackgroundTasks):
    """
    Start Idris2 specification generation workflow

    Phases 2-5 (Spec/WorkflowTypes.idr):
    - Phase 2: Analysis (LangGraph Agent)
    - Phase 3: Spec Generation (LangGraph Agent)
    - Phase 4: Compilation Loop (LangGraph Agent)
    - Phase 5: Document Implementation (LangGraph Agent)

    Returns immediately with task ID
    Frontend should poll /api/project/{name}/status
    """
    # WorkflowState 로드
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(
            status_code=404,
            detail=f"Project '{project_name}' not found. Call /api/project/init first."
        )

    # Phase 검증
    if not state.input_phase_complete():
        raise HTTPException(
            status_code=400,
            detail="Input phase not complete. Upload reference documents first."
        )

    # 백그라운드에서 LangGraph 실행
    def run_generation():
        # 백그라운드에서 state를 다시 로드하여 동기화 문제 방지
        current_state = WorkflowState.load(project_name, Path("./output"))
        if current_state is None:
            print(f"❌ State not found for {project_name}")
            return

        try:
            # Phase 2-5: LangGraph agent 실행
            print(f"\n🚀 Starting workflow for {project_name}...")
            updated_state = run_workflow(current_state)

            # 상태 저장
            print(f"\n💾 Saving workflow state...")
            updated_state.save(Path("./output"))
            print(f"\n✅ Workflow completed successfully!")

        except Exception as e:
            # 에러 발생 시 상태에 기록 및 로그 출력
            import traceback
            error_msg = f"Workflow error: {str(e)}"
            print(f"\n❌ ERROR in background workflow:")
            print(f"   Project: {project_name}")
            print(f"   Error: {error_msg}")
            print(f"   Traceback:")
            traceback.print_exc()

            # 에러 발생 시 최신 state를 다시 로드하여 저장
            error_state = WorkflowState.load(project_name, Path("./output"))
            if error_state:
                error_state.compile_result = CompileResult(success=False, error_msg=error_msg)
                error_state.add_log(f"❌ 워크플로우 에러: {str(e)}")
                error_state.mark_inactive()
                error_state.save(Path("./output"))

    background_tasks.add_task(run_generation)

    # 즉시 응답 반환
    return {
        "project_name": project_name,
        "status": "started",
        "current_phase": str(state.current_phase),
        "message": "Idris2 generation started. Poll /api/project/{name}/status for progress."
    }

@app.get("/api/projects")
async def list_projects():
    """
    List all projects with their status

    Returns:
        List of project summaries with status
    """
    output_dir = Path("./output")
    projects = []

    if not output_dir.exists():
        return {"projects": []}

    # Iterate through output directory
    for project_dir in output_dir.iterdir():
        if project_dir.is_dir() and (project_dir / "workflow_state.json").exists():
            try:
                state = WorkflowState.load(project_dir.name, output_dir)
                if state:
                    projects.append({
                        "project_name": state.project_name,
                        "current_phase": str(state.current_phase),
                        "progress": state.progress(),
                        "completed": state.completed,
                        "has_error": state.compile_result is not None and not state.compile_result.success,
                        "version": state.version,
                        "is_active": state.is_active,
                        "last_activity": state.last_activity
                    })
            except Exception as e:
                print(f"Error loading project {project_dir.name}: {e}")
                continue

    # Sort by last activity (most recent first)
    projects.sort(key=lambda p: p.get("last_activity") or "", reverse=True)

    return {"projects": projects}

@app.get("/api/project/{project_name}/status")
async def get_status(project_name: str) -> GenerationStatus:
    """
    Get current workflow status

    Returns WorkflowState information (Spec/WorkflowTypes.idr)
    Frontend polls this endpoint to track progress
    """
    # WorkflowState 로드
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(
            status_code=404,
            detail=f"Project '{project_name}' not found"
        )

    # 에러 메시지 및 분류 정보 구성
    error_msg = None
    classified_error = None
    error_strategy = None
    error_suggestion = None
    available_actions = None

    if state.compile_result and not state.compile_result.success:
        error_msg = state.compile_result.error_msg

    if state.classified_error:
        classified_error = state.classified_error
        error_strategy = state.error_strategy
        available_actions = state.classified_error.get("available_actions", [])

    # 에러 제안 (동일 에러 3회 반복 시)
    if state.error_suggestion:
        error_suggestion = state.error_suggestion

    return GenerationStatus(
        project_name=project_name,
        current_phase=str(state.current_phase),
        progress=state.progress(),
        completed=state.workflow_complete(),
        is_active=state.is_active,
        last_activity=state.last_activity,
        current_action=state.current_action,
        user_prompt=state.user_prompt,  # 원래 프롬프트 반환
        error=error_msg,
        classified_error=classified_error,
        error_strategy=error_strategy,
        error_suggestion=error_suggestion,  # 에러 제안 추가
        available_actions=available_actions,
        logs=state.logs  # 실시간 로그 반환
    )

@app.post("/api/project/{project_name}/draft")
async def generate_draft(project_name: str):
    """
    Generate lightweight draft outputs (txt, csv, md)

    Phase 6: Draft Phase (Spec/WorkflowTypes.idr)
    - Execute Idris2 renderers (Text, CSV, Markdown)
    - Generate lightweight formats for user preview
    - NO PDF generation (PDF는 /finalize에서만)
    """
    # WorkflowState 로드
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    # Phase 검증: Doc Impl이 완료되어야 함
    if not state.doc_impl_phase_complete():
        raise HTTPException(
            status_code=400,
            detail="Document implementation not complete. Wait for Phase 5 to finish."
        )

    # Pipeline 파일 확인 (PascalCase file name)
    module_name = to_pascal_case(project_name)
    pipeline_file = Path(f"./Pipeline/{module_name}.idr")
    if not pipeline_file.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Pipeline file not found: {pipeline_file}"
        )

    output_dir = Path(f"./output/{project_name}")
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        # Idris2 Pipeline 실행 (Text, CSV, Markdown)

        # Text 렌더러
        text_result = subprocess.run(
            ["idris2", "--exec", "exampleText", str(pipeline_file)],
            capture_output=True,
            text=True,
            timeout=30
        )

        # CSV 렌더러
        csv_result = subprocess.run(
            ["idris2", "--exec", "exampleCSV", str(pipeline_file)],
            capture_output=True,
            text=True,
            timeout=30
        )

        # Markdown 렌더러
        md_result = subprocess.run(
            ["idris2", "--exec", "exampleMarkdown", str(pipeline_file)],
            capture_output=True,
            text=True,
            timeout=30
        )

        # 결과 파일 저장
        text_file = output_dir / f"{project_name}_draft.txt"
        csv_file = output_dir / f"{project_name}_schedule.csv"
        md_file = output_dir / f"{project_name}_draft.md"

        if text_result.returncode == 0:
            text_file.write_text(text_result.stdout, encoding='utf-8')
            state.draft_text = text_result.stdout
        if csv_result.returncode == 0:
            csv_file.write_text(csv_result.stdout, encoding='utf-8')
            state.draft_csv = csv_result.stdout
        if md_result.returncode == 0:
            md_file.write_text(md_result.stdout, encoding='utf-8')
            state.draft_markdown = md_result.stdout

        # Phase 업데이트: DocImpl → Draft
        state.current_phase = Phase.DRAFT
        state.save(Path("./output"))

        return {
            "project_name": project_name,
            "status": "draft_ready",
            "current_phase": str(state.current_phase),
            "message": "Draft files generated successfully",
            "files": {
                "text": str(text_file) if text_file.exists() else None,
                "csv": str(csv_file) if csv_file.exists() else None,
                "markdown": str(md_file) if md_file.exists() else None
            }
        }

    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="Idris2 renderer timeout")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Draft generation failed: {str(e)}")

@app.get("/api/project/{project_name}/draft")
async def get_draft(project_name: str) -> DraftResponse:
    """
    Retrieve generated draft contents
    """
    output_dir = Path(f"./output/{project_name}")

    text_file = output_dir / f"{project_name}_draft.txt"
    md_file = output_dir / f"{project_name}_draft.md"
    csv_file = output_dir / f"{project_name}_schedule.csv"

    return DraftResponse(
        project_name=project_name,
        text_content=text_file.read_text(encoding='utf-8') if text_file.exists() else None,
        markdown_content=md_file.read_text(encoding='utf-8') if md_file.exists() else None,
        csv_content=csv_file.read_text(encoding='utf-8') if csv_file.exists() else None
    )

@app.post("/api/project/{project_name}/feedback")
async def submit_feedback(project_name: str, request: FeedbackRequest, background_tasks: BackgroundTasks):
    """
    Submit user feedback for refinement

    Phase 7-8: Feedback & Refinement (Spec/WorkflowTypes.idr)
    - Phase 7: Collect user feedback
    - Phase 8: Regenerate specification
    - Increment version (v1 → v2 → v3...)
    - Loop back to DraftPhase
    """
    # WorkflowState 로드
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    # Phase 검증: Draft가 완료되어야 함
    if not state.draft_phase_complete():
        raise HTTPException(
            status_code=400,
            detail="Draft not ready. Call /api/project/{name}/draft first."
        )

    # 피드백 저장
    state.feedback_history.append(request.feedback)
    state.user_satisfaction = UserSatisfaction(
        satisfied=False,
        revision_request=request.feedback
    )

    # Phase 업데이트: Draft → Feedback → Refinement
    state.current_phase = Phase.FEEDBACK
    state.save(Path("./output"))

    # 백그라운드에서 재생성
    def regenerate():
        try:
            # 버전 증가
            state.increment_version()
            state.current_phase = Phase.REFINEMENT

            # 피드백을 반영해서 프롬프트 수정
            # user_prompt에 피드백 추가
            original_prompt = state.user_prompt or ""
            updated_prompt = f"{original_prompt}\n\n[Revision Request]\n{request.feedback}"
            state.user_prompt = updated_prompt

            # LangGraph 재실행
            from agent import run_workflow
            updated_state = run_workflow(state)

            # Phase를 Draft로 되돌림 (루프!)
            updated_state.current_phase = Phase.DRAFT
            updated_state.save(Path("./output"))

        except Exception as e:
            state.compile_result = CompileResult(success=False, error_msg=str(e))
            state.save(Path("./output"))

    background_tasks.add_task(regenerate)

    return {
        "project_name": project_name,
        "status": "regenerating",
        "version": state.version_string(),
        "current_phase": str(state.current_phase),
        "message": f"Regenerating specification with feedback (version {state.version_string()})"
    }

class ResumeRequest(BaseModel):
    updated_prompt: Optional[str] = None  # 수정된 프롬프트 (선택)
    restart_from_analysis: bool = False    # 분석부터 다시 시작할지

@app.post("/api/project/{project_name}/resume")
async def resume_project(
    project_name: str,
    request: ResumeRequest,
    background_tasks: BackgroundTasks
):
    """
    Resume a failed project with optional prompt update

    Implements Spec/ProjectRecovery.idr recovery strategies:
    - RetryPhase: Retry the current phase (default)
    - RestartFromAnalysis: Go back to Phase 2 (if restart_from_analysis=true)
    - UpdatePrompt: Update prompt and restart from analysis
    """
    # Load state
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    # Check if resume is safe
    if state.completed:
        raise HTTPException(status_code=400, detail="Project already completed")

    if state.current_phase == Phase.INPUT:
        raise HTTPException(status_code=400, detail="No work to resume from input phase")

    # 프롬프트 업데이트가 있으면 적용
    if request.updated_prompt:
        state.user_prompt = request.updated_prompt
        state.add_log(f"📝 프롬프트 업데이트됨")
        # 프롬프트가 바뀌면 분석부터 다시
        request.restart_from_analysis = True

    # 분석부터 재시작하는 경우
    if request.restart_from_analysis:
        state.current_phase = Phase.ANALYSIS
        state.analysis_result = None
        state.spec_code = None
        state.compile_attempts = 0
        state.add_log("🔄 Phase 2 (분석)부터 재시작")

    # Reset error state
    state.compile_result = None
    state.classified_error = None
    state.error_strategy = None
    state.mark_active("프로젝트 재개 중...")
    state.save(Path("./output"))

    # Background: Resume workflow
    def resume_workflow():
        # 백그라운드에서 state를 다시 로드하여 동기화 문제 방지
        current_state = WorkflowState.load(project_name, Path("./output"))
        if current_state is None:
            print(f"❌ State not found for {project_name}")
            return

        try:
            print(f"\n🔄 Resuming workflow for {project_name}...")
            current_state.add_log("🔄 프로젝트 재개")

            # Run workflow from current phase
            from agent.agent import run_workflow
            updated_state = run_workflow(current_state)

            updated_state.mark_inactive()
            updated_state.save(Path("./output"))
            print(f"\n✅ Resume completed!")

        except Exception as e:
            import traceback
            error_msg = f"Resume error: {str(e)}"
            print(f"\n❌ ERROR in resume:")
            print(f"   Project: {project_name}")
            print(f"   Error: {error_msg}")
            traceback.print_exc()

            # 에러 발생 시 최신 state를 다시 로드하여 저장
            error_state = WorkflowState.load(project_name, Path("./output"))
            if error_state:
                error_state.compile_result = CompileResult(success=False, error_msg=error_msg)
                error_state.add_log(f"❌ 재개 실패: {str(e)}")
                error_state.mark_inactive()
                error_state.save(Path("./output"))

    background_tasks.add_task(resume_workflow)

    return {
        "project_name": project_name,
        "status": "resuming",
        "message": "Project resume started"
    }

@app.get("/api/project/{project_name}/resume-options")
async def get_resume_options(project_name: str):
    """
    Get available resume options for AutoPaused project

    Implements Spec/WorkflowControl.idr availableResumeOptions
    """
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    # AutoPaused 상태 확인
    if not state.is_paused:
        return {
            "project_name": project_name,
            "is_paused": False,
            "message": "Project is not in AutoPaused state"
        }

    # 재개 옵션 반환
    return {
        "project_name": project_name,
        "is_paused": True,
        "pause_reason": state.pause_reason,
        "resume_options": state.resume_options,
        "error_suggestion": state.error_suggestion,
        "error_preview": state.error_history[-1] if state.error_history else None
    }

@app.post("/api/project/{project_name}/resume-autopause")
async def resume_from_autopause(
    project_name: str,
    request: AutoPauseResumeRequest,
    background_tasks: BackgroundTasks
):
    """
    Resume from AutoPaused state with selected option

    Implements Spec/WorkflowControl.idr TransResumeAfterAutoPause
    """
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    if not state.is_paused:
        raise HTTPException(status_code=400, detail="Project is not in AutoPaused state")

    # Handle different resume options
    if request.option == "retry_with_new_prompt":
        if not request.new_prompt:
            raise HTTPException(status_code=400, detail="new_prompt is required for retry_with_new_prompt")

        state.user_prompt = request.new_prompt
        state.current_phase = Phase.ANALYSIS
        state.analysis_result = None
        state.spec_code = None
        state.compile_attempts = 0
        state.error_history = []  # 에러 히스토리 초기화
        state.add_log(f"🔄 새 프롬프트로 Phase 2부터 재시작")

    elif request.option == "retry_with_more_docs":
        if not request.new_docs:
            raise HTTPException(status_code=400, detail="new_docs is required for retry_with_more_docs")

        state.reference_docs.extend(request.new_docs)
        state.current_phase = Phase.ANALYSIS
        state.analysis_result = None
        state.spec_code = None
        state.compile_attempts = 0
        state.error_history = []
        state.add_log(f"📚 참조 문서 추가 후 Phase 2부터 재시작")

    elif request.option == "skip_validation":
        # 증명 제거하고 Phase 5로 진행
        state.current_phase = Phase.DOC_IMPL
        state.compile_attempts = 0
        state.error_history = []
        state.add_log(f"⚡ 검증 스킵 - Phase 5 (문서 구현)로 진행")

    elif request.option == "manual_fix":
        if not request.fixed_file_path:
            raise HTTPException(status_code=400, detail="fixed_file_path is required for manual_fix")

        # 사용자가 수정한 파일 경로 확인
        fixed_path = Path(request.fixed_file_path)
        if not fixed_path.exists():
            raise HTTPException(status_code=400, detail=f"Fixed file not found: {request.fixed_file_path}")

        # 현재 Phase에서 재개 (수정된 파일로 다시 컴파일)
        state.compile_attempts = 0
        state.error_history = []
        state.add_log(f"🔧 수동 수정 완료 - 현재 Phase에서 재개")

    elif request.option == "cancel":
        state.completed = True
        state.current_phase = Phase.FINAL
        state.add_log(f"❌ 프로젝트 취소됨")
        state.is_paused = False
        state.save(Path("./output"))

        return {
            "project_name": project_name,
            "status": "cancelled",
            "message": "Project cancelled by user"
        }

    else:
        raise HTTPException(status_code=400, detail=f"Invalid option: {request.option}")

    # AutoPaused 상태 해제
    state.is_paused = False
    state.pause_reason = None
    state.resume_options = []
    state.compile_result = None
    state.classified_error = None
    state.error_strategy = None
    state.mark_active(f"AutoPause 재개 중... (option: {request.option})")
    state.save(Path("./output"))

    # Background: Resume workflow
    def resume_workflow():
        current_state = WorkflowState.load(project_name, Path("./output"))
        if current_state is None:
            print(f"❌ State not found for {project_name}")
            return

        try:
            print(f"\n🔄 Resuming from AutoPause for {project_name}...")
            current_state.add_log("🔄 AutoPause에서 재개")

            from agent.agent import run_workflow
            updated_state = run_workflow(current_state)

            updated_state.mark_inactive()
            updated_state.save(Path("./output"))
            print(f"\n✅ Resume completed!")

        except Exception as e:
            import traceback
            error_msg = f"Resume error: {str(e)}"
            print(f"\n❌ ERROR in resume:")
            print(f"   Project: {project_name}")
            print(f"   Error: {error_msg}")
            traceback.print_exc()

            error_state = WorkflowState.load(project_name, Path("./output"))
            if error_state:
                error_state.compile_result = CompileResult(success=False, error_msg=error_msg)
                error_state.add_log(f"❌ 재개 실패: {str(e)}")
                error_state.mark_inactive()
                error_state.save(Path("./output"))

    background_tasks.add_task(resume_workflow)

    return {
        "project_name": project_name,
        "status": "resuming",
        "option_applied": request.option,
        "message": f"Resuming from AutoPause with option: {request.option}"
    }

@app.post("/api/project/{project_name}/skip-validation")
async def skip_validation(
    project_name: str,
    background_tasks: BackgroundTasks
):
    """
    Skip validation and proceed to document generation (Phase 5)

    Shortcut for resume-autopause with skip_validation option
    """
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    # AutoPaused가 아니어도 검증 스킵 가능
    state.current_phase = Phase.DOC_IMPL
    state.compile_attempts = 0
    state.error_history = []
    state.is_paused = False
    state.add_log(f"⚡ 검증 스킵 - Phase 5 (문서 구현)로 진행")
    state.mark_active("검증 스킵 모드")
    state.save(Path("./output"))

    # Background: Continue workflow
    def continue_workflow():
        current_state = WorkflowState.load(project_name, Path("./output"))
        if current_state is None:
            return

        try:
            from agent.agent import run_workflow
            updated_state = run_workflow(current_state)
            updated_state.mark_inactive()
            updated_state.save(Path("./output"))
        except Exception as e:
            print(f"❌ Skip validation error: {e}")

    background_tasks.add_task(continue_workflow)

    return {
        "project_name": project_name,
        "status": "skipping_validation",
        "message": "Skipping validation, proceeding to document generation"
    }

@app.post("/api/project/{project_name}/abort")
async def abort_project(project_name: str):
    """
    Abort a running project execution

    Implements Spec/ProjectRecovery.idr AbortExecution action:
    - Marks project as inactive
    - Preserves current state for later resume
    """
    # Load state
    state = WorkflowState.load(project_name, Path("./output"))

    if state is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_name}' not found")

    if not state.is_active:
        raise HTTPException(status_code=400, detail="Project is not currently running")

    # Mark as inactive
    state.mark_inactive()
    state.add_log("⏸️ 사용자가 실행을 중단했습니다")
    state.save(Path("./output"))

    return {
        "project_name": project_name,
        "status": "aborted",
        "message": "Project execution has been stopped. You can resume it later.",
        "current_phase": str(state.current_phase)
    }

@app.post("/api/project/{project_name}/finalize")
async def finalize_pdf(project_name: str):
    """
    Generate final PDF output

    Phase 9: Finalization
    - Compile PDF with pdflatex
    - Return download link
    """
    # Check if LaTeX file exists
    tex_file = Path(f"./output/{project_name}.tex")
    if not tex_file.exists():
        raise HTTPException(status_code=404, detail="LaTeX file not found")

    # Compile PDF
    result = subprocess.run(
        [
            "pdflatex",
            "-interaction=nonstopmode",
            "-output-directory=output",
            str(tex_file)
        ],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail=f"PDF compilation failed: {result.stderr}"
        )

    return {
        "project_name": project_name,
        "status": "completed",
        "pdf_path": f"/api/project/{project_name}/download"
    }

@app.get("/api/project/{project_name}/download")
async def download_pdf(project_name: str):
    """
    Download final PDF
    """
    pdf_file = Path(f"./output/{project_name}.pdf")
    if not pdf_file.exists():
        raise HTTPException(status_code=404, detail="PDF not found")

    return FileResponse(
        path=pdf_file,
        media_type="application/pdf",
        filename=f"{project_name}.pdf"
    )

# ============================================================
# Development endpoints
# ============================================================

@app.get("/api/debug/idris2")
async def debug_idris2():
    """Check Idris2 compilation"""
    result = subprocess.run(
        ["idris2", "--check", "Spec/WorkflowTypes.idr"],
        capture_output=True,
        text=True
    )
    return {
        "success": result.returncode == 0,
        "stdout": result.stdout,
        "stderr": result.stderr
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
