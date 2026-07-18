# CLAUDE.md

## 这是什么项目

WayneW1119 学习 Lean 和类型论的工作空间。

总目标：**理解 Lean 定理证明器的内部工作原理，熟练使用 Lean 进行数学证明。**

四个子目标：
1. **内核建模** — 从零建模 Lean 风格依赖类型核，逐版迭代
2. **类型论基础** — Π, Σ, 宇宙层级, 归纳类型, 递归子, identity type 等
3. **Lean 实操** — 写 Lean 代码，理解标准库、typeclass、tactics、macro
4. **数学证明** — 用 Lean 形式化数学定理（重点应用场景）

## 文档系统

| 文档 | 更新频率 | 内容 |
|------|---------|------|
| `CLAUDE.md` | 几乎不改 | 项目身份 + 文档系统索引 |
| `STYLE.md` | 偶尔修改 | 写作风格、命名约定、代码习惯 |
| `PROGRESS.md` | 经常更新 | 当前进展、版本演化、关键决策、下一步计划 |
| `docs/README.md` | 每版更新 | 版本文档导航和阅读指南 |

## 文件组织

```
learn_lean/
├── CLAUDE.md              # 项目身份 + 文档系统索引（本文件）
├── STYLE.md               # 风格约定
├── PROGRESS.md            # 进展报告
├── README.md              # 项目主页（GitHub 展示）
└── docs/
    ├── README.md          # 版本文档导航
    ├── lean_model_v0.md   # v0: 最小依赖类型核
    ├── ...
    └── lean_model_v10.md  # v10: 最新版本
```

`docs/lean_model_v*.md` 是实际工作内容（内核模型），不属于文档系统本身。
