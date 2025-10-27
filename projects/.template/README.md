# Project Template

This is the template structure for new TypedContract projects.

## Directory Structure

```
{project_id}/
├── metadata.json       # Project metadata (DB reference)
├── state.json         # Workflow state (resume point)
├── input/             # Phase 1: User input
│   ├── prompt.txt
│   └── references/    # Reference documents
├── analysis/          # Phase 2: Analysis results
├── generated/         # Phase 3-5: Generated Idris2 code
├── output/            # Phase 6-9: Final outputs
│   └── drafts/        # Version-controlled drafts
├── feedback/          # Phase 7-8: User feedback
└── logs/              # Project logs
```

## Workflow

1. **Input**: User provides prompt + references
2. **Analysis**: Claude analyzes requirements
3. **Generation**: Idris2 domain model generated
4. **Compilation**: Type-checking with auto-pause on 3x error
5. **Document Implementation**: Documentable + Pipeline
6. **Draft**: txt/md/csv outputs
7. **Feedback**: User reviews and provides feedback
8. **Refinement**: Iterate on feedback
9. **Final**: Generate PDF

## State Management

- `state.json`: Tracks current phase, errors, pause status
- Auto-paused on identical error 3x
- Resume options: retry, skip validation, manual fix, cancel

## Database Integration

- `metadata.json.db_ref`: References central database
- File system: Actual content storage
- Database: Metadata + search/filter
