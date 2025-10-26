"""
LangGraph 기반 Idris2 도메인 모델 생성 에이전트
"""

import subprocess
from typing import TypedDict, List, Optional, Literal
from pathlib import Path

from langgraph.graph import StateGraph, END
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from prompts import (
    ANALYZE_DOCUMENT_PROMPT,
    GENERATE_IDRIS_PROMPT,
    FIX_ERROR_PROMPT,
    FINAL_REVIEW_PROMPT,
    GENERATE_DOCUMENTABLE_PROMPT,
    GENERATE_PIPELINE_PROMPT
)


# ============================================================================
# State Schema
# ============================================================================

class AgentState(TypedDict):
    """에이전트 상태"""
    # 입력
    project_name: str
    document_type: str  # "contract", "approval", "invoice"
    reference_docs: List[str]  # 참고 문서 경로

    # 중간 상태
    analysis: Optional[str]  # 문서 분석 결과
    idris_code: Optional[str]  # 생성된 Idris2 코드
    current_file: str  # Domains/[project].idr

    # 컴파일 상태
    compile_attempts: int
    last_error: Optional[str]
    compile_success: bool

    # 출력
    final_module_path: Optional[str]
    messages: List[str]


# ============================================================================
# Tools
# ============================================================================

def typecheck_idris(file_path: str) -> tuple[bool, str]:
    """
    Idris2 타입 체크 실행

    Returns:
        (success: bool, output: str)
    """
    try:
        result = subprocess.run(
            ["idris2", "--check", file_path],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=Path(__file__).parent.parent  # ScaleDeepSpec/ 디렉토리
        )

        success = result.returncode == 0
        output = result.stdout + result.stderr

        return success, output

    except subprocess.TimeoutExpired:
        return False, "Timeout: 타입 체크가 30초를 초과했습니다."
    except FileNotFoundError:
        return False, "Error: idris2 명령을 찾을 수 없습니다."
    except Exception as e:
        return False, f"Error: {str(e)}"


def save_idris_file(code: str, file_path: str) -> str:
    """Idris2 코드를 파일로 저장"""
    try:
        path = Path(file_path)
        path.parent.mkdir(parents=True, exist_ok=True)

        with open(path, 'w', encoding='utf-8') as f:
            f.write(code)

        return f"✅ File saved: {file_path}"
    except Exception as e:
        return f"❌ Error saving file: {e}"


def read_reference_doc(file_path: str) -> str:
    """
    참고 문서 읽기 (PDF, 이미지, 텍스트 지원)

    Supports:
    - PDF files (.pdf) - PyPDF2로 텍스트 추출
    - Images (.jpg, .png, .jpeg) - OCR은 나중에 추가 가능
    - Text files (.txt, .md)
    """
    from pathlib import Path

    path = Path(file_path)

    if not path.exists():
        return f"Error: File not found: {file_path}"

    try:
        # PDF 처리
        if path.suffix.lower() == '.pdf':
            try:
                from PyPDF2 import PdfReader

                reader = PdfReader(file_path)
                text = ""

                for page_num, page in enumerate(reader.pages, 1):
                    page_text = page.extract_text()
                    text += f"\n--- Page {page_num} ---\n{page_text}\n"

                if not text.strip():
                    return f"Warning: PDF extracted but no text found: {file_path}"

                return text

            except ImportError:
                return "Error: PyPDF2 not installed. Run: pip install PyPDF2"
            except Exception as e:
                return f"Error reading PDF: {e}"

        # 이미지 처리 (현재는 경고만)
        elif path.suffix.lower() in ['.jpg', '.jpeg', '.png', '.gif']:
            return f"Warning: Image file detected: {file_path}\nOCR not yet implemented. Please provide text version."

        # 텍스트 파일
        else:
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()

    except UnicodeDecodeError:
        # 바이너리 파일일 경우
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                return f.read()
        except Exception as e:
            return f"Error: Cannot read file (binary?): {e}"
    except Exception as e:
        return f"Error reading file: {e}"


# ============================================================================
# Agent Nodes
# ============================================================================

def analyze_document(state: AgentState) -> AgentState:
    """Node 1: 문서 분석"""
    print("\n📄 [1/5] Analyzing document...")

    # LLM 호출
    llm = ChatOpenAI(model="gpt-4", temperature=0)

    # 참고 문서 읽기
    docs_content = "\n\n".join([
        f"[{doc}]\n{read_reference_doc(doc)}"
        for doc in state["reference_docs"]
    ])

    prompt = ANALYZE_DOCUMENT_PROMPT.format(
        document_type=state["document_type"],
        reference_docs=docs_content
    )

    response = llm.invoke([
        SystemMessage(content=prompt),
        HumanMessage(content=docs_content)
    ])

    analysis = response.content

    # 분석 결과 저장
    analysis_file = f"direction/analysis_{state['project_name']}.md"
    save_idris_file(analysis, analysis_file)

    state["analysis"] = analysis
    state["messages"].append(f"✅ 문서 분석 완료: {analysis_file}")

    return state


def generate_idris_code(state: AgentState) -> AgentState:
    """Node 2: Idris2 코드 생성"""
    print("\n⚙️  [2/5] Generating Idris2 code...")

    llm = ChatOpenAI(model="gpt-4", temperature=0)

    prompt = GENERATE_IDRIS_PROMPT.format(
        project_name=state["project_name"],
        analysis=state["analysis"]
    )

    response = llm.invoke([SystemMessage(content=prompt)])

    idris_code = response.content.strip()

    # 코드 블록 제거 (```idris ... ```)
    if idris_code.startswith("```"):
        lines = idris_code.split("\n")
        idris_code = "\n".join(lines[1:-1])

    state["idris_code"] = idris_code
    state["current_file"] = f"Domains/{state['project_name']}.idr"
    state["messages"].append(f"✅ Idris2 코드 생성 완료")

    return state


def typecheck_code(state: AgentState) -> AgentState:
    """Node 3: 타입 체크"""
    print(f"\n🔍 [3/5] Type checking (attempt {state['compile_attempts'] + 1})...")

    # 파일 저장
    save_msg = save_idris_file(state["idris_code"], state["current_file"])
    state["messages"].append(save_msg)

    # 타입 체크
    success, output = typecheck_idris(state["current_file"])

    state["compile_attempts"] += 1
    state["compile_success"] = success
    state["last_error"] = None if success else output

    if success:
        state["messages"].append(f"✅ 타입 체크 성공!")
        state["final_module_path"] = state["current_file"]
    else:
        state["messages"].append(f"❌ 타입 체크 실패:\n{output}")

    return state


def fix_compilation_error(state: AgentState) -> AgentState:
    """Node 4: 에러 수정"""
    print(f"\n🔧 [4/5] Fixing compilation error...")

    llm = ChatOpenAI(model="gpt-4", temperature=0)

    prompt = FIX_ERROR_PROMPT.format(
        idris_code=state["idris_code"],
        error_message=state["last_error"]
    )

    response = llm.invoke([SystemMessage(content=prompt)])

    fixed_code = response.content.strip()

    # 코드 블록 제거
    if fixed_code.startswith("```"):
        lines = fixed_code.split("\n")
        fixed_code = "\n".join(lines[1:-1])

    state["idris_code"] = fixed_code
    state["messages"].append(f"🔧 코드 수정 완료 (attempt {state['compile_attempts']})")

    return state


def generate_documentable_impl(state: AgentState) -> AgentState:
    """Node 5: Documentable 인스턴스 생성 (Phase 5)"""
    print("\n📝 [5/7] Generating Documentable instance...")

    llm = ChatOpenAI(model="gpt-4", temperature=0)

    # 도메인 코드 읽기
    domain_code = ""
    if state["idris_code"]:
        domain_code = state["idris_code"]
    else:
        # 파일에서 읽기
        try:
            with open(state["current_file"], 'r', encoding='utf-8') as f:
                domain_code = f.read()
        except:
            domain_code = "# Domain code not available"

    prompt = GENERATE_DOCUMENTABLE_PROMPT.format(
        project_name=state["project_name"],
        domain_code=domain_code
    )

    response = llm.invoke([SystemMessage(content=prompt)])

    documentable_code = response.content.strip()

    # 코드 블록 제거
    if documentable_code.startswith("```"):
        lines = documentable_code.split("\n")
        documentable_code = "\n".join(lines[1:-1])

    # 파일 저장
    documentable_file = f"DomainToDoc/{state['project_name']}.idr"
    save_msg = save_idris_file(documentable_code, documentable_file)

    # 타입 체크
    success, output = typecheck_idris(documentable_file)

    if success:
        state["messages"].append(f"✅ Documentable instance 생성 완료: {documentable_file}")
    else:
        state["messages"].append(f"⚠️ Documentable 타입 체크 실패:\n{output}")

    return state


def generate_pipeline_impl(state: AgentState) -> AgentState:
    """Node 6: Pipeline 구현 생성 (Phase 5)"""
    print("\n⚙️ [6/7] Generating pipeline implementation...")

    llm = ChatOpenAI(model="gpt-4", temperature=0)

    prompt = GENERATE_PIPELINE_PROMPT.format(
        project_name=state["project_name"]
    )

    response = llm.invoke([SystemMessage(content=prompt)])

    pipeline_code = response.content.strip()

    # 코드 블록 제거
    if pipeline_code.startswith("```"):
        lines = pipeline_code.split("\n")
        pipeline_code = "\n".join(lines[1:-1])

    # 파일 저장
    pipeline_file = f"Pipeline/{state['project_name']}.idr"
    save_msg = save_idris_file(pipeline_code, pipeline_file)

    # 타입 체크
    success, output = typecheck_idris(pipeline_file)

    if success:
        state["messages"].append(f"✅ Pipeline 구현 완료: {pipeline_file}")
    else:
        state["messages"].append(f"⚠️ Pipeline 타입 체크 실패:\n{output}")

    return state


# ============================================================================
# Conditional Logic
# ============================================================================

def should_continue(state: AgentState) -> Literal["finish", "fail", "fix_error"]:
    """타입 체크 후 다음 행동 결정"""
    if state["compile_success"]:
        return "finish"

    if state["compile_attempts"] >= 5:
        return "fail"

    return "fix_error"


# ============================================================================
# Graph Construction
# ============================================================================

def create_agent() -> StateGraph:
    """LangGraph 에이전트 생성"""

    workflow = StateGraph(AgentState)

    # 노드 추가
    workflow.add_node("analyze", analyze_document)
    workflow.add_node("generate", generate_idris_code)
    workflow.add_node("typecheck", typecheck_code)
    workflow.add_node("fix_error", fix_compilation_error)
    workflow.add_node("gen_documentable", generate_documentable_impl)  # Phase 5
    workflow.add_node("gen_pipeline", generate_pipeline_impl)           # Phase 5

    # 엣지 정의
    workflow.add_edge("analyze", "generate")
    workflow.add_edge("generate", "typecheck")

    # 조건부 엣지 (컴파일 성공 시 Phase 5로)
    workflow.add_conditional_edges(
        "typecheck",
        should_continue,
        {
            "finish": "gen_documentable",  # 성공 시 Phase 5로
            "fail": END,
            "fix_error": "fix_error"
        }
    )

    workflow.add_edge("fix_error", "typecheck")

    # Phase 5: Documentable → Pipeline → END
    workflow.add_edge("gen_documentable", "gen_pipeline")
    workflow.add_edge("gen_pipeline", END)

    # 시작점
    workflow.set_entry_point("analyze")

    return workflow.compile()


# ============================================================================
# Main Entry Point
# ============================================================================

def generate_domain_model(
    project_name: str,
    document_type: str,
    reference_docs: List[str]
) -> dict:
    """
    문서 → Idris2 도메인 모델 생성

    Args:
        project_name: 프로젝트명 (예: "MyContract")
        document_type: 문서 유형 (예: "contract")
        reference_docs: 참고 문서 경로 리스트

    Returns:
        최종 상태 dict
    """
    print("=" * 60)
    print("🚀 Idris2 Domain Model Generator")
    print("=" * 60)

    # 초기 상태
    initial_state: AgentState = {
        "project_name": project_name,
        "document_type": document_type,
        "reference_docs": reference_docs,
        "analysis": None,
        "idris_code": None,
        "current_file": "",
        "compile_attempts": 0,
        "last_error": None,
        "compile_success": False,
        "final_module_path": None,
        "messages": []
    }

    # 에이전트 실행
    app = create_agent()
    result = app.invoke(initial_state)

    # 결과 출력
    print("\n" + "=" * 60)
    print("📊 RESULT")
    print("=" * 60)

    for msg in result["messages"]:
        print(msg)

    if result["compile_success"]:
        print(f"\n✅ SUCCESS: {result['final_module_path']}")
        print(f"   Attempts: {result['compile_attempts']}")
    else:
        print(f"\n❌ FAILED after {result['compile_attempts']} attempts")
        if result["last_error"]:
            print(f"\nLast error:\n{result['last_error']}")

    return result


# ============================================================================
# WorkflowState Integration
# ============================================================================

def run_workflow(workflow_state):
    """
    WorkflowState를 받아서 LangGraph 워크플로우 실행

    Args:
        workflow_state: WorkflowState 객체

    Returns:
        업데이트된 WorkflowState
    """
    # WorkflowState → AgentState 변환
    agent_state: AgentState = {
        "project_name": workflow_state.project_name,
        "document_type": "contract",  # TODO: 프롬프트에서 추론
        "reference_docs": workflow_state.reference_docs,
        "analysis": workflow_state.analysis_result,
        "idris_code": workflow_state.spec_code,
        "current_file": workflow_state.spec_file or f"Domains/{workflow_state.project_name}.idr",
        "compile_attempts": workflow_state.compile_attempts,
        "last_error": workflow_state.compile_result.error_msg if workflow_state.compile_result else None,
        "compile_success": workflow_state.compilation_phase_complete(),
        "final_module_path": workflow_state.spec_file,
        "messages": []
    }

    # Phase에 따라 시작점 결정
    from workflow_state import Phase, CompileResult

    # Phase 2: Analysis부터 시작 (Phase 1은 이미 완료)
    if workflow_state.current_phase == Phase.INPUT:
        workflow_state.current_phase = Phase.ANALYSIS

    # LangGraph 실행
    app = create_agent()
    result = app.invoke(agent_state)

    # 결과를 WorkflowState에 반영
    workflow_state.analysis_result = result.get("analysis")
    workflow_state.spec_code = result.get("idris_code")
    workflow_state.spec_file = result.get("final_module_path")
    workflow_state.compile_attempts = result.get("compile_attempts", 0)

    if result["compile_success"]:
        workflow_state.compile_result = CompileResult(success=True)

        # Phase 5 결과 반영
        # Documentable과 Pipeline 파일이 생성되었는지 확인
        from pathlib import Path
        documentable_file = Path(f"DomainToDoc/{workflow_state.project_name}.idr")
        pipeline_file = Path(f"Pipeline/{workflow_state.project_name}.idr")

        if documentable_file.exists():
            workflow_state.documentable_impl = documentable_file.read_text(encoding='utf-8')
        if pipeline_file.exists():
            workflow_state.pipeline_impl = pipeline_file.read_text(encoding='utf-8')

        # Phase 진행: Analysis → Spec Generation → Compilation → Doc Impl → Draft
        if workflow_state.documentable_impl and workflow_state.pipeline_impl:
            workflow_state.current_phase = Phase.DRAFT  # Phase 6로 이동
        else:
            workflow_state.current_phase = Phase.DOC_IMPL  # Phase 5 미완성
    else:
        error_msg = result.get("last_error", "Unknown error")
        workflow_state.compile_result = CompileResult(success=False, error_msg=error_msg)

    return workflow_state


# ============================================================================
# CLI
# ============================================================================

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: python agent.py <project_name> <document_type> <reference_doc>")
        print("Example: python agent.py MyContract contract direction/계약서.pdf")
        sys.exit(1)

    project = sys.argv[1]
    doc_type = sys.argv[2]
    ref_docs = sys.argv[3:]

    generate_domain_model(project, doc_type, ref_docs)
