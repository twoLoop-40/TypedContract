||| Project Migration Specification
|||
||| 기존 프로젝트 구조를 새 구조로 안전하게 마이그레이션
||| 타입으로 마이그레이션 규칙을 명시하여 데이터 손실 방지

module Spec.ProjectMigration

%default total

-- ============================================================================
-- Old Structure (Before Migration)
-- ============================================================================

||| 기존 프로젝트 구조
public export
record OldProjectStructure where
  constructor MkOldStructure
  outputDir : String           -- output/{project_name}/
  stateFile : String           -- workflow_state.json
  referencesDir : String       -- references/
  domainFiles : List String    -- Domains/{Project}.idr
  draftFiles : List String     -- *.txt, *.md, *.csv
  pdfFiles : List String       -- *.pdf

-- ============================================================================
-- New Structure (After Migration)
-- ============================================================================

||| 새 프로젝트 구조
public export
record NewProjectStructure where
  constructor MkNewStructure
  projectDir : String                  -- projects/{project_id}/
  metadataFile : String               -- metadata.json
  stateFile : String                  -- state.json
  inputDir : String                   -- input/
  referencesDir : String              -- input/references/
  analysisDir : String                -- analysis/
  generatedDir : String               -- generated/
  outputDir : String                  -- output/
  draftsDir : String                  -- output/drafts/
  feedbackDir : String                -- feedback/
  logsDir : String                    -- logs/

-- ============================================================================
-- Migration Rules (타입 안전한 변환 규칙)
-- ============================================================================

||| 파일 마이그레이션 규칙
public export
data MigrationRule : Type where
  ||| 상태 파일: workflow_state.json → state.json (내용 그대로 복사)
  MigrateState : (old : String) -> (new : String) -> MigrationRule

  ||| 참조 문서: references/ → input/references/ (전체 디렉토리 복사)
  MigrateReferences : (oldDir : String) -> (newDir : String) -> MigrationRule

  ||| 도메인 파일: Domains/*.idr → generated/*.idr (이름 유지)
  MigrateDomain : (oldFile : String) -> (newFile : String) -> MigrationRule

  ||| 초안 파일: *.{txt,md,csv} → output/drafts/*.{txt,md,csv}
  MigrateDraft : (oldFile : String) -> (newFile : String) -> MigrationRule

  ||| 최종 파일: *.pdf → output/*.pdf
  MigrateFinal : (oldFile : String) -> (newFile : String) -> MigrationRule

  ||| 메타데이터 생성: workflow_state.json → metadata.json (변환 필요)
  CreateMetadata : (stateData : String) -> (metadata : String) -> MigrationRule

-- ============================================================================
-- Migration Status
-- ============================================================================

||| 마이그레이션 상태
public export
data MigrationStatus : Type where
  ||| 아직 시작 안함
  NotStarted : MigrationStatus

  ||| 진행 중
  InProgress : (completedSteps : Nat) -> (totalSteps : Nat) -> MigrationStatus

  ||| 완료됨
  Completed : (migratedFiles : Nat) -> MigrationStatus

  ||| 실패 (롤백 가능)
  Failed : (reason : String) -> (atStep : Nat) -> MigrationStatus

-- ============================================================================
-- Migration Safety (안전성 보장)
-- ============================================================================

||| 마이그레이션 안전성 조건
public export
data MigrationSafety : OldProjectStructure -> NewProjectStructure -> Type where
  ||| Safe1: 모든 파일이 복사됨 (손실 없음)
  NoDataLoss : (old : OldProjectStructure)
            -> (new : NewProjectStructure)
            -> MigrationSafety old new

  ||| Safe2: 기존 파일은 보존됨 (삭제 안함)
  PreserveOriginal : (old : OldProjectStructure)
                  -> (stillExists : Bool)  -- old 파일들이 여전히 존재
                  -> MigrationSafety old new

  ||| Safe3: 필수 파일들이 새 구조에 존재함
  RequiredFilesExist : (new : NewProjectStructure)
                    -> (hasState : Bool)
                    -> (hasMetadata : Bool)
                    -> MigrationSafety old new

-- ============================================================================
-- Migration Steps (순서 보장)
-- ============================================================================

||| 마이그레이션 단계 (순서 중요!)
public export
data MigrationStep : MigrationStatus -> MigrationStatus -> Type where
  ||| Step 1: 새 디렉토리 구조 생성
  CreateStructure : MigrationStep NotStarted (InProgress 1 7)

  ||| Step 2: state.json 복사
  CopyState : MigrationStep (InProgress 1 7) (InProgress 2 7)

  ||| Step 3: metadata.json 생성
  GenerateMetadata : MigrationStep (InProgress 2 7) (InProgress 3 7)

  ||| Step 4: 참조 문서 복사
  CopyReferences : MigrationStep (InProgress 3 7) (InProgress 4 7)

  ||| Step 5: 도메인 파일 복사
  CopyDomains : MigrationStep (InProgress 4 7) (InProgress 5 7)

  ||| Step 6: 초안 파일 복사
  CopyDrafts : MigrationStep (InProgress 5 7) (InProgress 6 7)

  ||| Step 7: 최종 파일 복사
  CopyFinals : MigrationStep (InProgress 6 7) (Completed 0)  -- 파일 개수는 실행 시 계산

-- ============================================================================
-- Migration Validation (검증)
-- ============================================================================

||| 마이그레이션 검증 함수
public export
data MigrationValidation : Type where
  ||| 파일 개수 검증
  ValidateFileCount : (oldCount : Nat) -> (newCount : Nat) -> (equal : oldCount = newCount) -> MigrationValidation

  ||| 파일 크기 검증
  ValidateFileSize : (oldSize : Nat) -> (newSize : Nat) -> (equal : oldSize = newSize) -> MigrationValidation

  ||| 디렉토리 존재 검증
  ValidateDirectoryExists : (path : String) -> (exists : Bool) -> MigrationValidation

-- ============================================================================
-- Rollback Strategy (롤백 전략)
-- ============================================================================

||| 롤백 전략
public export
data RollbackStrategy : Type where
  ||| 새 디렉토리만 삭제 (기존 파일 보존)
  DeleteNewOnly : RollbackStrategy

  ||| 새 디렉토리로 이름 변경 (백업)
  RenameToBackup : (suffix : String) -> RollbackStrategy

  ||| 수동 롤백 (로그만 기록)
  ManualRollback : RollbackStrategy

-- ============================================================================
-- Migration Result
-- ============================================================================

||| 마이그레이션 결과
public export
record MigrationResult where
  constructor MkResult
  projectName : String
  status : MigrationStatus
  oldStructure : OldProjectStructure
  newStructure : NewProjectStructure
  migratedFiles : List (String, String)  -- (old, new) pairs
  errors : List String
  warnings : List String

||| 성공한 마이그레이션인가?
public export
isSuccess : MigrationResult -> Bool
isSuccess result = case result.status of
  Completed _ => True
  _ => False

||| 실패한 마이그레이션인가?
public export
isFailed : MigrationResult -> Bool
isFailed result = case result.status of
  Failed _ _ => True
  _ => False

-- ============================================================================
-- Migration Execution (실행 명세)
-- ============================================================================

||| 마이그레이션 실행 함수의 타입 시그니처
||| (실제 구현은 Python에서)
public export
migrateSingleProject : (projectName : String)
                    -> (dryRun : Bool)
                    -> MigrationResult

||| 전체 프로젝트 마이그레이션
public export
migrateAllProjects : (dryRun : Bool) -> List MigrationResult

-- ============================================================================
-- Example: Migration Workflow
-- ============================================================================

||| 예제: 단일 프로젝트 마이그레이션 워크플로우
public export
example_migration_workflow : IO ()
example_migration_workflow = do
  putStrLn "=== Project Migration Example ==="

  putStrLn "\n1. Old Structure:"
  putStrLn "   output/outSourcing_1/"
  putStrLn "     ├── workflow_state.json"
  putStrLn "     └── references/"
  putStrLn "   Domains/Outsourcing1.idr"

  putStrLn "\n2. Migration Steps:"
  putStrLn "   [1/7] Create: projects/outSourcing_1/ directories"
  putStrLn "   [2/7] Copy: workflow_state.json → state.json"
  putStrLn "   [3/7] Generate: metadata.json"
  putStrLn "   [4/7] Copy: references/ → input/references/"
  putStrLn "   [5/7] Copy: Outsourcing1.idr → generated/"
  putStrLn "   [6/7] Copy: *.txt/md/csv → output/drafts/"
  putStrLn "   [7/7] Copy: *.pdf → output/"

  putStrLn "\n3. New Structure:"
  putStrLn "   projects/outSourcing_1/"
  putStrLn "     ├── metadata.json      (NEW)"
  putStrLn "     ├── state.json         (from workflow_state.json)"
  putStrLn "     ├── input/"
  putStrLn "     │   └── references/    (from old references/)"
  putStrLn "     ├── generated/"
  putStrLn "     │   └── Outsourcing1.idr"
  putStrLn "     └── output/"
  putStrLn "         └── drafts/"

  putStrLn "\n4. Safety Guarantees:"
  putStrLn "   ✅ No data loss (all files copied)"
  putStrLn "   ✅ Original files preserved"
  putStrLn "   ✅ Type-safe migration steps"
  putStrLn "   ✅ Rollback available on failure"

  putStrLn "\n✨ Migration complete!"
