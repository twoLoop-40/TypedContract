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
    error: Optional[str] = None
    classified_error: Optional[dict] = None  # ClassifiedError
    error_strategy: Optional[str] = None
    available_actions: Optional[List[str]] = None
    logs: List[str] = []  # 실시간 로그 (최근 100개)

class FeedbackRequest(BaseModel):
    project_name: str
    feedback: str

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
        try:
            # Phase 2-5: LangGraph agent 실행
            print(f"\n🚀 Starting workflow for {project_name}...")
            updated_state = run_workflow(state)

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

            state.compile_result = CompileResult(success=False, error_msg=error_msg)
            state.add_log(f"❌ 워크플로우 에러: {str(e)}")
            state.save(Path("./output"))

    background_tasks.add_task(run_generation)

    # 즉시 응답 반환
    return {
        "project_name": project_name,
        "status": "started",
        "current_phase": str(state.current_phase),
        "message": "Idris2 generation started. Poll /api/project/{name}/status for progress."
    }

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
    available_actions = None

    if state.compile_result and not state.compile_result.success:
        error_msg = state.compile_result.error_msg

    if state.classified_error:
        classified_error = state.classified_error
        error_strategy = state.error_strategy
        available_actions = state.classified_error.get("available_actions", [])

    return GenerationStatus(
        project_name=project_name,
        current_phase=str(state.current_phase),
        progress=state.progress(),
        completed=state.workflow_complete(),
        error=error_msg,
        classified_error=classified_error,
        error_strategy=error_strategy,
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
