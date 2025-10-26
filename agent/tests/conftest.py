"""
Pytest 설정 및 공통 fixtures
"""

import pytest
import sys
from pathlib import Path

# agent/ 디렉토리를 Python path에 추가
sys.path.insert(0, str(Path(__file__).parent.parent))
