# Testing the Idris2 MCP Server

여러 가지 방법으로 Idris2 MCP 서버를 테스트할 수 있습니다.

---

## 🎯 Quick Start

### 방법 1: CLI Test Suite (가장 빠름)

MCP 없이 core logic 테스트:

```bash
cd mcp-servers/idris2-mcp
python3 test_cli.py
```

**결과**:
- ✅ search_guidelines 테스트
- ✅ get_guideline_section 테스트
- ✅ read_resource 테스트

---

### 방법 2: Interactive CLI (탐색용)

대화형 모드로 기능 탐색:

```bash
cd mcp-servers/idris2-mcp
python3 test_cli.py --interactive
```

**사용 예**:
```
idris2-mcp> search dependent types
idris2-mcp> section multiplicities
idris2-mcp> resource idris2://guidelines/types
idris2-mcp> list
idris2-mcp> quit
```

**사용 가능한 명령어**:
- `search <query> [category]` - 가이드라인 검색
- `section <topic>` - 특정 섹션 가져오기
- `resource <uri>` - 리소스 읽기
- `list` - 사용 가능한 topics/resources 목록
- `help` - 도움말
- `quit` - 종료

---

### 방법 3: MCP Inspector (UI로 테스트)

공식 MCP debugging tool 사용:

```bash
cd mcp-servers/idris2-mcp
npx @modelcontextprotocol/inspector python server.py
```

또는:
```bash
./test_mcp_inspector.sh
```

**결과**:
- 브라우저에서 http://localhost:5173 열림
- UI에서 모든 tools와 resources 테스트 가능

**장점**:
- ✅ 실제 MCP 프로토콜 테스트
- ✅ Tools, Resources 전부 확인
- ✅ 시각적 인터페이스

---

### 방법 4: Unit Test (자동화)

Python unittest:

```bash
cd mcp-servers/idris2-mcp
python3 test_guidelines.py
```

**테스트 항목**:
- ✅ Guideline files exist
- ✅ Search simulation
- ✅ Section extraction
- ✅ Resource URI mapping

---

## 📋 각 방법 비교

| 방법 | 속도 | 의존성 | 용도 | UI |
|------|------|--------|------|-----|
| CLI Test Suite | ⚡ 빠름 | Python만 | 빠른 검증 | CLI |
| Interactive CLI | ⚡ 빠름 | Python만 | 탐색/학습 | CLI |
| MCP Inspector | 🐢 느림 | Node.js + MCP | 완전한 테스트 | Web |
| Unit Test | ⚡ 빠름 | Python만 | 자동화/CI | CLI |

---

## 🧪 테스트 시나리오

### Scenario 1: 개발 중 빠른 확인

```bash
# 1. Core logic 동작 확인
python3 test_cli.py

# 2. 특정 기능 대화형 테스트
python3 test_cli.py --interactive
```

---

### Scenario 2: 완전한 통합 테스트

```bash
# 1. Unit test로 기본 검증
python3 test_guidelines.py

# 2. MCP Inspector로 전체 프로토콜 테스트
npx @modelcontextprotocol/inspector python server.py
```

브라우저에서:
1. **Resources** 탭 클릭
2. 각 resource URI 테스트 (idris2://guidelines/*)
3. **Tools** 탭 클릭
4. 각 tool 실행 (search_guidelines, get_guideline_section 등)

---

### Scenario 3: Claude Code에서 사용

`.mcp-config.json`에 추가:

```json
{
  "mcpServers": {
    "idris2-helper": {
      "command": "python",
      "args": ["/Users/joonho/Idris2Projects/TypedContract/mcp-servers/idris2-mcp/server.py"],
      "description": "Enhanced Idris2 type-checking and intelligent guideline access"
    }
  }
}
```

Claude Code 재시작 후:
- Resources에서 `idris2://guidelines/*` 확인
- Tools에서 `search_guidelines`, `get_guideline_section` 사용

---

## 🎓 Interactive CLI 사용 예

```bash
$ python3 test_cli.py --interactive

🎮 INTERACTIVE MODE
======================================================================

Commands:
  search <query> [category]  - Search guidelines
  section <topic>            - Get guideline section
  resource <uri>             - Read resource
  list                       - List all topics/resources
  help                       - Show this help
  quit                       - Exit

idris2-mcp> list

📋 Available Topics:
  - parser_constraints
  - multiplicities
  - dependent_types
  - interfaces
  - modules
  - views
  - proofs
  - ffi
  - pragmas_inline
  - pragmas_foreign
  - totality

📋 Available Resources:
  - idris2://guidelines/project
  - idris2://guidelines/syntax
  - idris2://guidelines/types
  - idris2://guidelines/modules
  - idris2://guidelines/advanced
  - idris2://guidelines/pragmas
  - idris2://guidelines/index

idris2-mcp> search linear types

🔍 Found 6 results for 'linear':

[1] README.md (line 35)
- Linear types and resource protocols
...

idris2-mcp> section multiplicities

📖 Section 'multiplicities' (60 lines):

## Multiplicities (Quantitative Type Theory)

Idris 2 implements **QTT** where every variable has a quantity/multiplicity.

### Three Multiplicity Types

1. **0 (Erased)** - Compile-time only, absent at runtime
2. **1 (Linear)** - Used exactly once at runtime
3. **Unrestricted** - Default, no usage constraints
...

idris2-mcp> resource idris2://guidelines/types

📚 Resource 'idris2://guidelines/types' (345 lines):

# Idris2 Type System

**Source**: Official Idris2 Documentation
**Last Updated**: 2025-10-27
...

idris2-mcp> quit
👋 Goodbye!
```

---

## 🔍 MCP Inspector 사용 예

1. **서버 시작**:
   ```bash
   npx @modelcontextprotocol/inspector python server.py
   ```

2. **브라우저 접속**: http://localhost:5173

3. **Resources 테스트**:
   - "Resources" 탭 클릭
   - `idris2://guidelines/project` 선택
   - "Read Resource" 클릭
   - 내용 확인

4. **Tools 테스트**:
   - "Tools" 탭 클릭
   - `search_guidelines` 선택
   - Parameters 입력:
     ```json
     {
       "query": "dependent types",
       "category": "types"
     }
     ```
   - "Execute" 클릭
   - 결과 확인

5. **다른 Tools**:
   - `get_guideline_section` - topic 선택
   - `check_idris2` - Idris2 코드 type-check
   - `validate_syntax` - 문법 검증
   - `suggest_fix` - 에러 수정 제안

---

## 📊 예상 결과

### ✅ 성공 케이스

**search_guidelines**:
```json
{
  "query": "multiplicities",
  "category": "types"
}
```
→ 2-3개의 관련 섹션 반환 (line number, context 포함)

**get_guideline_section**:
```json
{
  "topic": "dependent_types"
}
```
→ "Dependent Types" 섹션 전체 반환 (40-50 lines)

**resource read**:
```
idris2://guidelines/types
```
→ 02-TYPE-SYSTEM.md 전체 내용 반환 (345 lines)

---

### ❌ 에러 케이스

**Invalid topic**:
```json
{
  "topic": "nonexistent"
}
```
→ "Unknown topic: nonexistent"

**Empty search**:
```json
{
  "query": "zzznonexistent",
  "category": "all"
}
```
→ "No results found for 'zzznonexistent'"

---

## 🐛 Troubleshooting

### MCP Inspector가 안 열릴 때

```bash
# Node.js 버전 확인
node --version  # v18+ 필요

# npx 캐시 삭제
npx clear-npx-cache

# 다시 시도
npx @modelcontextprotocol/inspector python server.py
```

---

### Python import 에러

```bash
# MCP 패키지 설치 (MCP Inspector 사용 시에만 필요)
pip install mcp

# 또는 uv 사용
uv pip install mcp
```

**Note**: CLI test는 MCP 패키지 없이도 동작합니다!

---

### Idris2 command not found (check_idris2 tool 사용 시)

```bash
# Idris2 설치 확인
idris2 --version

# 없으면 설치
brew install idris2  # macOS
```

**Note**: 다른 tools는 Idris2 없이도 동작합니다!

---

## 📝 테스트 체크리스트

개발 후 확인:

- [ ] `python3 test_guidelines.py` - Unit tests 통과
- [ ] `python3 test_cli.py` - CLI test suite 통과
- [ ] `python3 test_cli.py --interactive` - 대화형 모드 동작
- [ ] MCP Inspector에서 resources 읽기 성공
- [ ] MCP Inspector에서 search_guidelines 동작
- [ ] MCP Inspector에서 get_guideline_section 동작
- [ ] Claude Code에서 MCP 서버 인식 및 사용 가능

---

## 🚀 Next Steps

테스트 완료 후:

1. **Claude Code 통합**: `.mcp-config.json` 설정
2. **실제 사용**: Idris2 코드 생성 시 guideline 참조
3. **피드백 수집**: 부족한 가이드라인 식별
4. **문서 개선**: 필요한 섹션 추가

---

**Last Updated**: 2025-10-27
**Version**: 2.0.0
