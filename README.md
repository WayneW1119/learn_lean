# Learn Lean

Building a Lean-style dependently-typed kernel from scratch — formal model + code implementation.

## Docs

| 文档 | 说明 |
|------|------|
| [CLAUDE.md](CLAUDE.md) | 项目身份 + 文档系统索引 |
| [STYLE.md](STYLE.md) | 风格约定 |
| [PROGRESS.md](PROGRESS.md) | 进展报告、设计决策、架构概述 |
| [docs/README.md](docs/README.md) | 版本文档导航 |
| [docs/lean_model_v10.md](docs/lean_model_v10.md) | 当前最新模型 |

## What's In Each Version

| Version | Kernel / Elab | Highlights |
|---------|:---:|-----------|
| v0 | unified | Π, Lam, bidirectional typing, minimal kernel |
| v1 | unified | Σ (dependent pair), Pair, check_type upgrade |
| v2 | unified | Fst, Snd — Sigma elimination rules |
| v3 | unified | Ann — type ascription for elaboration |
| v4 | unified | whnf — weak head normalization |
| v5 | unified | defeq — definitional equality |
| v6 | split | SurfaceTerm vs CoreTerm, elab function |
| v7 | split | Proj (general projection), StructureInfo, Sigma desugared |
| v8 | split | ParamInfo, FieldInfo, match_structure_type, projection_type |
| v9 | split | StructureCmd — all structures user-declared, nothing built-in |
| v10 | split | ProjectionInfo, SProj, SDot — projection names and dot notation |

CoreTerm has been stable at 7 constructors since v7. Each version document marks only differences from the previous version.
