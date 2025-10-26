"""
FastAPI 엔드포인트 테스트
"""

import pytest
from fastapi.testclient import TestClient
import sys
from pathlib import Path
import shutil
import tempfile

sys.path.insert(0, str(Path(__file__).parent.parent))

from main import app
from workflow_state import WorkflowState, Phase, create_initial_state


# FastAPI TestClient
client = TestClient(app)


class TestHealthEndpoints:
    """Health check 엔드포인트 테스트"""

    def test_root(self):
        """루트 엔드포인트"""
        response = client.get("/")
        assert response.status_code == 200
        assert "ScaleDeepSpec API" in response.json()["message"]

    def test_health(self):
        """헬스 체크"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        # Idris2가 설치되어 있으면 버전 정보가 있음
        # assert "idris2" in data


class TestProjectInitialization:
    """프로젝트 초기화 테스트"""

    def setup_method(self):
        """각 테스트 전에 output 디렉토리 정리"""
        output_dir = Path("./output/TestProject")
        if output_dir.exists():
            shutil.rmtree(output_dir)

    def teardown_method(self):
        """각 테스트 후 정리"""
        output_dir = Path("./output/TestProject")
        if output_dir.exists():
            shutil.rmtree(output_dir)

    def test_init_project(self):
        """POST /api/project/init"""
        response = client.post(
            "/api/project/init",
            json={
                "project_name": "TestProject",
                "user_prompt": "Create a service contract",
                "reference_docs": ["doc1.pdf", "doc2.pdf"]
            }
        )

        assert response.status_code == 200
        data = response.json()

        assert data["project_name"] == "TestProject"
        assert data["status"] == "initialized"
        assert "Phase 1" in data["current_phase"]
        assert data["progress"] == 0.0

        # WorkflowState 파일이 생성되었는지 확인
        state_file = Path("./output/TestProject/workflow_state.json")
        assert state_file.exists()

    def test_init_creates_workflow_state(self):
        """프로젝트 초기화 시 WorkflowState가 생성되는지 확인"""
        client.post(
            "/api/project/init",
            json={
                "project_name": "TestProject",
                "user_prompt": "Test prompt",
                "reference_docs": ["test.pdf"]
            }
        )

        # 상태 로드
        state = WorkflowState.load("TestProject", Path("./output"))
        assert state is not None
        assert state.project_name == "TestProject"
        assert state.current_phase == Phase.INPUT
        assert state.user_prompt == "Test prompt"
        assert state.reference_docs == ["test.pdf"]


class TestStatusEndpoint:
    """상태 조회 엔드포인트 테스트"""

    def setup_method(self):
        """테스트용 프로젝트 생성"""
        state = create_initial_state(
            "StatusTest",
            "Test prompt",
            ["test.pdf"]
        )
        state.save(Path("./output"))

    def teardown_method(self):
        """정리"""
        output_dir = Path("./output/StatusTest")
        if output_dir.exists():
            shutil.rmtree(output_dir)

    def test_get_status(self):
        """GET /api/project/{name}/status"""
        response = client.get("/api/project/StatusTest/status")

        assert response.status_code == 200
        data = response.json()

        assert data["project_name"] == "StatusTest"
        assert "Phase" in data["current_phase"]
        assert 0.0 <= data["progress"] <= 1.0
        assert data["completed"] is False

    def test_get_status_nonexistent(self):
        """존재하지 않는 프로젝트 조회"""
        response = client.get("/api/project/NonExistent/status")

        assert response.status_code == 404
        assert "not found" in response.json()["detail"]


class TestFileUpload:
    """파일 업로드 테스트"""

    def setup_method(self):
        """테스트용 프로젝트 생성"""
        client.post(
            "/api/project/init",
            json={
                "project_name": "UploadTest",
                "user_prompt": "Test",
                "reference_docs": []
            }
        )

    def teardown_method(self):
        """정리"""
        output_dir = Path("./output/UploadTest")
        if output_dir.exists():
            shutil.rmtree(output_dir)

    def test_upload_files(self):
        """POST /api/project/{name}/upload"""
        # 임시 파일 생성
        temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt')
        temp_file.write("Test content")
        temp_file.close()

        try:
            with open(temp_file.name, 'rb') as f:
                response = client.post(
                    "/api/project/UploadTest/upload",
                    files={"files": ("test.txt", f, "text/plain")}
                )

            assert response.status_code == 200
            data = response.json()

            assert data["project_name"] == "UploadTest"
            assert data["count"] == 1
            assert len(data["uploaded_files"]) == 1

        finally:
            # 임시 파일 삭제
            Path(temp_file.name).unlink()


class TestGenerateEndpoint:
    """생성 엔드포인트 테스트"""

    def setup_method(self):
        """테스트용 프로젝트 생성"""
        state = create_initial_state(
            "GenerateTest",
            "Create a contract",
            ["test.pdf"]
        )
        state.save(Path("./output"))

    def teardown_method(self):
        """정리"""
        output_dir = Path("./output/GenerateTest")
        if output_dir.exists():
            shutil.rmtree(output_dir)

    def test_generate_requires_init(self):
        """POST /api/project/{name}/generate는 init이 필요함"""
        response = client.post("/api/project/NonExistent/generate")

        assert response.status_code == 404
        assert "not found" in response.json()["detail"]

    def test_generate_starts_workflow(self):
        """POST /api/project/{name}/generate는 즉시 응답"""
        response = client.post("/api/project/GenerateTest/generate")

        assert response.status_code == 200
        data = response.json()

        assert data["project_name"] == "GenerateTest"
        assert data["status"] == "started"
        assert "Poll" in data["message"]


# Note: Draft, Feedback 엔드포인트는 실제 LangGraph 실행이 필요하므로
# 통합 테스트에서 진행


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
