# Learn Lean

Building a Lean-style dependently-typed kernel from scratch — formal model + code implementation.

## Structure

```
learn_lean/
├── README.md              # You are here
├── PROGRESS.md            # Progress report: evolution, design decisions, architecture overview
└── docs/
    ├── README.md          # Version document navigation guide
    ├── lean_model_v0.md   # Minimal dependent type kernel
    ├── lean_model_v1.md   # + Σ, Pair
    ├── lean_model_v2.md   # + Fst, Snd
    ├── lean_model_v3.md   # + Ann (elaboration hint)
    ├── lean_model_v4.md   # + whnf
    ├── lean_model_v5.md   # + defeq
    ├── lean_model_v6.md   # + Surface/Core split, elab
    ├── lean_model_v7.md   # + Proj, StructureInfo, Sigma desugared
    ├── lean_model_v8.md   # + ParamInfo, FieldInfo, helper functions
    ├── lean_model_v9.md   # + StructureCmd, all structures user-declared
    └── lean_model_v10.md  # + ProjectionInfo, SProj, SDot (latest)
```

## Quick Links

- **[PROGRESS.md](PROGRESS.md)** — Read this first for an overview of the modeling journey,  key design decisions, and current architecture.
- **[docs/README.md](docs/README.md)** — Reading guide for the version documents.
- **[docs/lean_model_v10.md](docs/lean_model_v10.md)** — The latest and most complete model.

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
