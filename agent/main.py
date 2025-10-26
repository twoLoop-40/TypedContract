"""
FastAPI Backend for ScaleDeepSpec
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
from workflow_state import (
    WorkflowState,
    Phase,
    CompileResult,
    UserSatisfaction,
    create_initial_state
)

# LangGraph agent
from agent import run_workflow

app = FastAPI(
    title="ScaleDeepSpec API",
    description="Document generation system with formal specifications",
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
async def generate_spec(project_name: str):
    """
    Start Idris2 specification generation workflow

    Phases 2-5:
    - Analysis (LangGraph Agent)
    - Spec Generation (LangGraph Agent)
    - Compilation Loop (LangGraph Agent)
    - Document Implementation (LangGraph Agent)

    Returns immediately with task ID
    Frontend should poll /api/project/{name}/status
    """
    # TODO: Implement LangGraph agent workflow
    # This will be the core LangGraph Agent 1 from docs/AGENT_ARCHITECTURE.md

    return {
        "project_name": project_name,
        "status": "started",
        "message": "Idris2 generation started (not yet implemented)"
    }

@app.get("/api/project/{project_name}/status")
async def get_status(project_name: str) -> GenerationStatus:
    """
    Get current workflow status
    Polls the LangGraph state for progress
    """
    # TODO: Implement status tracking from LangGraph state

    return GenerationStatus(
        project_name=project_name,
        current_phase="InputPhase",
        progress=0.0,
        completed=False
    )

@app.post("/api/project/{project_name}/draft")
async def generate_draft(project_name: str):
    """
    Generate lightweight draft outputs (txt, csv, md)

    Phase 6: Draft Phase
    - Execute Idris2 renderers
    - Return text/csv/markdown for user preview
    """
    # Check if Idris2 spec is compiled
    spec_file = Path(f"./Domains/{project_name}.idr")
    if not spec_file.exists():
        raise HTTPException(status_code=404, detail="Specification not found")

    # TODO: Execute Idris2 renderers
    # idris2 --exec generateText
    # idris2 --exec generateCSV
    # idris2 --exec generateMarkdown

    return {
        "project_name": project_name,
        "status": "draft_ready",
        "message": "Draft generation not yet implemented"
    }

@app.get("/api/project/{project_name}/draft")
async def get_draft(project_name: str) -> DraftResponse:
    """
    Retrieve generated draft contents
    """
    output_dir = Path(f"./output")

    text_file = output_dir / f"{project_name}_draft.txt"
    md_file = output_dir / f"{project_name}_draft.md"
    csv_file = output_dir / f"{project_name}_schedule.csv"

    return DraftResponse(
        project_name=project_name,
        text_content=text_file.read_text() if text_file.exists() else None,
        markdown_content=md_file.read_text() if md_file.exists() else None,
        csv_content=csv_file.read_text() if csv_file.exists() else None
    )

@app.post("/api/project/{project_name}/feedback")
async def submit_feedback(project_name: str, request: FeedbackRequest):
    """
    Submit user feedback for refinement

    Phase 7-8: Feedback & Refinement
    - Parse feedback (LangGraph Agent 2)
    - Regenerate specification (LangGraph Agent 1)
    - Increment version (v1 → v2)
    """
    # TODO: Implement LangGraph Agent 2 feedback processing

    return {
        "project_name": project_name,
        "status": "feedback_received",
        "message": "Will regenerate specification (not yet implemented)"
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
