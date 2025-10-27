"""
LangGraph 기반 Idris2 도메인 모델 생성 에이전트
"""

import os
import subprocess
from typing import TypedDict, List, Optional, Literal
from pathlib import Path

from langgraph.graph import StateGraph, END
from langchain_core.messages import HumanMessage, SystemMessage
from anthropic import Anthropic
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

from agent.prompts import (
    ANALYZE_DOCUMENT_PROMPT,
    GENERATE_IDRIS_PROMPT,
    FIX_ERROR_PROMPT,
    FINAL_REVIEW_PROMPT,
    GENERATE_DOCUMENTABLE_PROMPT,
    GENERATE_PIPELINE_PROMPT
)

from agent.error_classifier import (
    classify_error,
    decide_strategy,
    ErrorLevel,
    ErrorStrategy,
    DEFAULT_RETRY_POLICY,
    format_user_message
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

    # 에러 핸들링 (Phase 4b)
    classified_error: Optional[dict]  # ClassifiedError (JSON)
    error_strategy: Optional[str]  # ErrorStrategy
    user_action: Optional[str]  # 사용자 선택한 액션

    # 출력
    final_module_path: Optional[str]
    messages: List[str]


# ============================================================================
# Tools
# ============================================================================

def to_pascal_case(snake_str: str) -> str:
    """
    snake_case를 PascalCase로 변환 (Idris2 모듈 이름 규칙)

    Examples:
        test_contract_final → TestContractFinal
        problem_input_v3 → ProblemInputV3
        my_contract → MyContract
    """
    components = snake_str.split('_')
    return ''.join(word.capitalize() for word in components)


def call_claude(system_prompt: str, user_message: str = "", temperature: float = 0.0) -> str:
    """
    Claude Sonnet 4.5 API 호출 헬퍼 함수

    Args:
        system_prompt: 시스템 프롬프트
        user_message: 사용자 메시지 (선택)
        temperature: 생성 온도 (0.0 = deterministic)

    Returns:
        LLM 응답 텍스트
    """
    # API Key 확인
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY not found in environment variables. Please set it in .env file.")

    client = Anthropic(api_key=api_key)

    messages = []
    if user_message:
        messages.append({
            "role": "user",
            "content": user_message
        })
    else:
        # user_message가 없으면 system_prompt를 user message로 사용
        messages.append({
            "role": "user",
            "content": system_prompt
        })
        system_prompt = ""

    # API 호출
    api_params = {
        "model": "claude-sonnet-4-5-20250929",
        "max_tokens": 8192,
        "temperature": temperature,
        "messages": messages
    }

    # system은 비어있지 않을 때만 추가
    if system_prompt:
        api_params["system"] = system_prompt

    response = client.messages.create(**api_params)

    return response.content[0].text


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

    # 참고 문서 읽기
    docs_content = "\n\n".join([
        f"[{doc}]\n{read_reference_doc(doc)}"
        for doc in state["reference_docs"]
    ])

    prompt = ANALYZE_DOCUMENT_PROMPT.format(
        document_type=state["document_type"],
        reference_docs=docs_content
    )

    # Claude Sonnet 4.5 호출
    analysis = call_claude(system_prompt=prompt, user_message=docs_content)

    # 분석 결과 저장
    analysis_file = f"direction/analysis_{state['project_name']}.md"
    save_idris_file(analysis, analysis_file)

    state["analysis"] = analysis
    state["messages"].append(f"✅ 문서 분석 완료: {analysis_file}")

    return state


def generate_idris_code(state: AgentState) -> AgentState:
    """Node 2: Idris2 코드 생성"""
    print("\n⚙️  [2/5] Generating Idris2 code...")

    # Idris2 모듈 이름은 PascalCase여야 함
    module_name = to_pascal_case(state["project_name"])
    print(f"   ├─ Project name: {state['project_name']}")
    print(f"   └─ Module name: {module_name}")

    prompt = GENERATE_IDRIS_PROMPT.format(
        project_name=module_name,
        analysis=state["analysis"]
    )

    # Claude Sonnet 4.5 호출
    idris_code = call_claude(system_prompt=prompt).strip()

    # 코드 블록 제거 (```idris ... ```)
    if idris_code.startswith("```"):
        lines = idris_code.split("\n")
        idris_code = "\n".join(lines[1:-1])

    state["idris_code"] = idris_code
    # Use PascalCase for file name to match module name
    state["current_file"] = f"Domains/{module_name}.idr"
    state["messages"].append(f"✅ Idris2 코드 생성 완료")
    print(f"   └─ File path: {state['current_file']}")

    return state


def typecheck_code(state: AgentState) -> AgentState:
    """Node 3: 타입 체크 + 에러 분류"""
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
        state["classified_error"] = None
        state["error_strategy"] = None
    else:
        state["messages"].append(f"❌ 타입 체크 실패:\n{output}")

        # 에러 분류 (Phase 4b)
        print(f"\n🔍 Classifying error...")
        classified = classify_error(output)
        print(f"   ├─ Level: {classified.level.value}")
        print(f"   ├─ Auto-fixable: {classified.auto_fixable}")
        print(f"   └─ Message: {classified.message[:100]}...")

        state["classified_error"] = {
            "level": classified.level.value,
            "message": classified.message,
            "location": str(classified.location) if classified.location else None,
            "suggestion": classified.suggestion,
            "available_actions": [a.value for a in classified.available_actions],
            "auto_fixable": classified.auto_fixable
        }

        # 전략 결정
        strategy = decide_strategy(DEFAULT_RETRY_POLICY, classified, state["compile_attempts"])
        state["error_strategy"] = strategy.value
        print(f"   └─ Strategy decided: {strategy.value}")

        # 사용자 친화적 메시지
        user_msg = format_user_message(classified)
        state["messages"].append(f"\n{user_msg}")
        state["messages"].append(f"권장 전략: {strategy.value}")

    return state


def fix_compilation_error(state: AgentState) -> AgentState:
    """Node 4: 에러 수정"""
    print(f"\n🔧 [4/5] Fixing compilation error (attempt {state['compile_attempts']})...")
    print(f"   ├─ Error type: {state.get('classified_error', {}).get('level', 'unknown')}")
    print(f"   └─ Calling Claude to fix code...")

    prompt = FIX_ERROR_PROMPT.format(
        idris_code=state["idris_code"],
        error_message=state["last_error"]
    )

    # Claude Sonnet 4.5 호출
    fixed_code = call_claude(system_prompt=prompt).strip()
    print(f"   └─ Received fixed code ({len(fixed_code)} chars)")

    # 코드 블록 제거
    if fixed_code.startswith("```"):
        lines = fixed_code.split("\n")
        fixed_code = "\n".join(lines[1:-1])
        print(f"   └─ Removed code block markers")

    state["idris_code"] = fixed_code
    state["messages"].append(f"🔧 코드 수정 완료 (attempt {state['compile_attempts']})")
    print(f"   ✅ Code updated, will retry type checking...")

    return state


def generate_documentable_impl(state: AgentState) -> AgentState:
    """Node 5: Documentable 인스턴스 생성 (Phase 5)"""
    print("\n📝 [5/7] Generating Documentable instance...")

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

    # Convert to PascalCase for module name
    module_name = to_pascal_case(state["project_name"])

    prompt = GENERATE_DOCUMENTABLE_PROMPT.format(
        project_name=module_name,
        domain_code=domain_code
    )

    # Claude Sonnet 4.5 호출
    documentable_code = call_claude(system_prompt=prompt).strip()

    # 코드 블록 제거
    if documentable_code.startswith("```"):
        lines = documentable_code.split("\n")
        documentable_code = "\n".join(lines[1:-1])

    # 파일 저장 (PascalCase file name to match module name)
    documentable_file = f"DomainToDoc/{module_name}.idr"
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

    # Convert to PascalCase for module name
    module_name = to_pascal_case(state["project_name"])

    prompt = GENERATE_PIPELINE_PROMPT.format(
        project_name=module_name
    )

    # Claude Sonnet 4.5 호출
    pipeline_code = call_claude(system_prompt=prompt).strip()

    # 코드 블록 제거
    if pipeline_code.startswith("```"):
        lines = pipeline_code.split("\n")
        pipeline_code = "\n".join(lines[1:-1])

    # 파일 저장 (PascalCase file name to match module name)
    pipeline_file = f"Pipeline/{module_name}.idr"
    save_msg = save_idris_file(pipeline_code, pipeline_file)

    # 타입 체크
    success, output = typecheck_idris(pipeline_file)

    if success:
        state["messages"].append(f"✅ Pipeline 구현 완료: {pipeline_file}")
    else:
        state["messages"].append(f"⚠️ Pipeline 타입 체크 실패:\n{output}")

    return state


def generate_draft_outputs(state: AgentState) -> AgentState:
    """Node 7: 초안 생성 (Phase 6 - Draft Phase)"""
    print("\n📄 [7/7] Generating draft outputs (txt, csv, md)...")

    # Convert to PascalCase for file name
    module_name = to_pascal_case(state["project_name"])
    pipeline_file = f"Pipeline/{module_name}.idr"

    # 렌더러 함수들을 idris2 --exec로 실행
    outputs = {}

    # Text 렌더러
    try:
        result = subprocess.run(
            ["idris2", "--exec", f"exampleText", pipeline_file],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=Path(__file__).parent.parent
        )
        if result.returncode == 0:
            outputs["text"] = result.stdout
            state["messages"].append("✅ Text 렌더링 완료")
        else:
            state["messages"].append(f"⚠️ Text 렌더링 실패: {result.stderr}")
    except Exception as e:
        state["messages"].append(f"⚠️ Text 렌더링 에러: {str(e)}")

    # CSV 렌더러
    try:
        result = subprocess.run(
            ["idris2", "--exec", f"exampleCSV", pipeline_file],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=Path(__file__).parent.parent
        )
        if result.returncode == 0:
            outputs["csv"] = result.stdout
            state["messages"].append("✅ CSV 렌더링 완료")
        else:
            state["messages"].append(f"⚠️ CSV 렌더링 실패: {result.stderr}")
    except Exception as e:
        state["messages"].append(f"⚠️ CSV 렌더링 에러: {str(e)}")

    # Markdown 렌더러
    try:
        result = subprocess.run(
            ["idris2", "--exec", f"exampleMarkdown", pipeline_file],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=Path(__file__).parent.parent
        )
        if result.returncode == 0:
            outputs["markdown"] = result.stdout
            state["messages"].append("✅ Markdown 렌더링 완료")
        else:
            state["messages"].append(f"⚠️ Markdown 렌더링 실패: {result.stderr}")
    except Exception as e:
        state["messages"].append(f"⚠️ Markdown 렌더링 에러: {str(e)}")

    # 출력 저장
    output_dir = Path(f"./output/{project_name}")
    output_dir.mkdir(parents=True, exist_ok=True)

    if outputs.get("text"):
        (output_dir / f"{project_name}_draft.txt").write_text(outputs["text"], encoding='utf-8')
    if outputs.get("csv"):
        (output_dir / f"{project_name}_schedule.csv").write_text(outputs["csv"], encoding='utf-8')
    if outputs.get("markdown"):
        (output_dir / f"{project_name}_draft.md").write_text(outputs["markdown"], encoding='utf-8')

    return state


def handle_user_decision(state: AgentState) -> AgentState:
    """Node: 사용자 결정 처리 (증명 실패 시)"""
    print("\n❓ [4b] Waiting for user decision...")

    # 사용자 액션 대기 (API에서 설정)
    user_action = state.get("user_action")

    if user_action == "fallback":
        state["messages"].append("사용자 선택: 증명 제거 후 계속 진행")
        # 증명 제거 로직은 향후 구현
        state["compile_success"] = True
    elif user_action == "reanalyze":
        state["messages"].append("사용자 선택: 문서 재분석")
        # Phase 2로 돌아가기 (향후 구현)
    elif user_action == "manual":
        state["messages"].append("사용자 선택: 수동 수정 대기")
    else:
        state["messages"].append("사용자 액션 대기 중...")

    return state


def reanalyze_document(state: AgentState) -> AgentState:
    """Node: 도메인 에러 시 문서 재분석"""
    print("\n🔄 [Reanalyze] Re-analyzing document...")

    state["messages"].append("⚠️ 도메인 모델링 오류 감지. 문서를 재분석합니다.")

    # 분석 초기화
    state["analysis"] = None
    state["idris_code"] = None
    state["compile_attempts"] = 0

    # Phase 2로 돌아가기
    # 실제로는 analyze_document를 다시 호출해야 함
    return state


# ============================================================================
# Conditional Logic
# ============================================================================

def should_continue(state: AgentState) -> Literal["finish", "fail", "fix_error", "ask_user", "reanalyze"]:
    """타입 체크 후 다음 행동 결정 (에러 분류 기반)"""
    print(f"\n🔀 Deciding next action...")
    print(f"   ├─ Compile success: {state['compile_success']}")
    print(f"   ├─ Compile attempts: {state['compile_attempts']}")

    if state["compile_success"]:
        print(f"   └─ Decision: finish (success!)")
        return "finish"

    # 에러 전략에 따라 분기
    strategy = state.get("error_strategy")
    print(f"   ├─ Error strategy: {strategy}")

    if strategy == "auto_fix":
        # 문법 에러 - 자동 수정 시도 (최대 5회)
        if state["compile_attempts"] < 5:
            print(f"   └─ Decision: fix_error (attempt {state['compile_attempts'] + 1}/5)")
            return "fix_error"
        else:
            print(f"   └─ Decision: fail (max retries reached)")
            return "fail"

    elif strategy == "ask_user":
        # 증명 실패 또는 알 수 없는 에러 - 사용자에게 물어봄
        print(f"   └─ Decision: ask_user")
        return "ask_user"

    elif strategy == "fallback":
        # 증명 제거 후 계속 진행
        # TODO: 증명 제거 로직 구현
        print(f"   └─ Decision: finish (fallback)")
        return "finish"

    elif strategy == "reanalyze":
        # 도메인 에러 - 재분석 필요
        print(f"   └─ Decision: reanalyze")
        return "reanalyze"

    elif strategy == "terminate":
        # 중단
        print(f"   └─ Decision: fail (terminate)")
        return "fail"

    else:
        # 기본값: 에러 전략이 없으면 기존 로직 사용
        print(f"   ├─ No strategy set, using default logic")
        if state["compile_attempts"] >= 5:
            print(f"   └─ Decision: fail (max retries)")
            return "fail"
        print(f"   └─ Decision: fix_error (default)")
        return "fix_error"


# ============================================================================
# Graph Construction
# ============================================================================

def create_agent() -> StateGraph:
    """LangGraph 에이전트 생성 (에러 핸들링 통합)"""

    workflow = StateGraph(AgentState)

    # 노드 추가
    workflow.add_node("analyze", analyze_document)
    workflow.add_node("generate", generate_idris_code)
    workflow.add_node("typecheck", typecheck_code)
    workflow.add_node("fix_error", fix_compilation_error)
    workflow.add_node("ask_user", handle_user_decision)      # Phase 4b: 사용자 결정
    workflow.add_node("reanalyze", reanalyze_document)       # Phase 4b: 재분석
    workflow.add_node("gen_documentable", generate_documentable_impl)  # Phase 5
    workflow.add_node("gen_pipeline", generate_pipeline_impl)           # Phase 5
    workflow.add_node("gen_draft", generate_draft_outputs)              # Phase 6

    # 엣지 정의
    workflow.add_edge("analyze", "generate")
    workflow.add_edge("generate", "typecheck")

    # 조건부 엣지 (에러 분류 기반 분기)
    workflow.add_conditional_edges(
        "typecheck",
        should_continue,
        {
            "finish": "gen_documentable",  # 성공 시 Phase 5로
            "fail": END,                    # 중단
            "fix_error": "fix_error",       # 문법 에러 - 자동 수정
            "ask_user": "ask_user",         # 증명 실패 - 사용자 결정 대기
            "reanalyze": "reanalyze"        # 도메인 에러 - 재분석
        }
    )

    workflow.add_edge("fix_error", "typecheck")
    workflow.add_edge("ask_user", END)  # 사용자 결정 후 종료 (API에서 재시작)
    workflow.add_edge("reanalyze", "analyze")  # 재분석 → 처음부터

    # Phase 5-6: Documentable → Pipeline → Draft → END
    workflow.add_edge("gen_documentable", "gen_pipeline")
    workflow.add_edge("gen_pipeline", "gen_draft")
    workflow.add_edge("gen_draft", END)

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
        "classified_error": None,
        "error_strategy": None,
        "user_action": None,
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
    from agent.workflow_state import Phase, CompileResult

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
        module_name = to_pascal_case(workflow_state.project_name)
        documentable_file = Path(f"DomainToDoc/{module_name}.idr")
        pipeline_file = Path(f"Pipeline/{module_name}.idr")

        if documentable_file.exists():
            workflow_state.documentable_impl = documentable_file.read_text(encoding='utf-8')
        if pipeline_file.exists():
            workflow_state.pipeline_impl = pipeline_file.read_text(encoding='utf-8')

        # Phase 6 결과 반영
        # 초안 파일들이 생성되었는지 확인
        output_dir = Path(f"./output/{workflow_state.project_name}")
        text_file = output_dir / f"{workflow_state.project_name}_draft.txt"
        csv_file = output_dir / f"{workflow_state.project_name}_schedule.csv"
        md_file = output_dir / f"{workflow_state.project_name}_draft.md"

        if text_file.exists():
            workflow_state.draft_text = text_file.read_text(encoding='utf-8')
        if csv_file.exists():
            workflow_state.draft_csv = csv_file.read_text(encoding='utf-8')
        if md_file.exists():
            workflow_state.draft_markdown = md_file.read_text(encoding='utf-8')

        # Phase 진행: Analysis → Spec Generation → Compilation → Doc Impl → Draft → Feedback
        if workflow_state.draft_text or workflow_state.draft_markdown:
            workflow_state.current_phase = Phase.FEEDBACK  # Phase 7로 이동
        elif workflow_state.documentable_impl and workflow_state.pipeline_impl:
            workflow_state.current_phase = Phase.DRAFT  # Phase 6 진행 중
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
