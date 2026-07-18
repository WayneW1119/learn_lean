# CLAUDE.md

## 项目身份

这是 WayneW1119 学习 Lean 和类型论的工作空间。

### 总目标

**学习 Lean，理解类型论，熟练使用 Lean 进行数学证明。**

这不是一个"读文档学 Lean"的项目。目标是深入理解 Lean 定理证明器从内核到表层的完整工作原理，并最终用 Lean 作为工具来形式化数学定理。数学证明是重点应用场景——理解类型论和证明助手的内核，是为了更有效、更准确地做数学形式化。

### 子目标

```
总目标：学习 Lean + 类型论 + 用 Lean 做数学证明
│
├── 子目标 1：内核建模
│   从零开始建立一个精简的 Lean 风格依赖类型定理证明器内核。
│   目的：理解证明助手内部怎么工作——term 表示、类型检查、
│   definitional equality、elaboration、结构声明——从底层吃透原理。
│   方式：逐版迭代（v0 → v1 → ... → vn），每个版本只关注与上一
│   版的差异，让每步增量小、可理解。
│   不追求实现一个真正的 proof assistant，追求的是理解。
│
├── 子目标 2：类型论基础
│   理解 dependent type theory 的核心概念（不仅限于 Lean）：
│   Π-type（依赖函数类型）、Σ-type（依赖乘积类型）、宇宙层级、
│   归纳类型与递归子、identity type 与相等性、等等。
│   这些概念在建模过程中自然涉及——内核建模本身就是学习类型论
│   的载体。
│
├── 子目标 3：Lean 实操
│   真正写 Lean 代码。包括但不限于：
│   - 熟悉 Lean 4 的标准库组织形式（Init, Std, Mathlib）
│   - 理解 typeclass 机制（如 Add, Mul, Monoid 等）
│   - 理解 tactics（如 intro, apply, rw, simp 等）
│   - 理解 macro、syntax、elaboration 等元编程特性
│   - 可能：在本仓库中实现模型的部分组件（如类型检查器、
│     whnf/normalizer），用 Lean 本身作为实现语言
│
└── 子目标 4：数学证明
    用 Lean 形式化数学定理——这是整个计划的重点应用场景。
    可能的方向：
    - 经典逻辑与集合论基础
    - 代数结构（群、环、域、向量空间）
    - 分析（实数、极限、微积分基本定理）
    - 数论（素数定理的初等形式等）
    具体内容取决于学习进度和兴趣方向。
```

### 各子目标的关系

内核建模（子目标 1）是计划的**第一步**。先把底层的原理吃透——知道 `Sort`、`Π`、`Σ`、`whnf`、`defeq`、`Proj` 这些在 Lean 内部是如何工作和交互的——然后再进入实操和证明阶段。有了内核的理解，写 Lean 代码时就不只是会用语法，而是能理解每个 tactic 背后发生了什么、每个 typeclass 决议为什么成功或失败。

后续的阶段不是严格串行的——可能在建模过程中就穿插 Lean 实操练习，也可能在学数学证明时回头补充内核的某些方面（如归纳类型）。

## 文档系统

| 文档 | 更新频率 | 内容 |
|------|---------|------|
| `CLAUDE.md` | 几乎不改 | 项目身份 + 目标 + 文档系统索引 |
| `STYLE.md` | 偶尔修改 | 写作风格、命名约定、代码习惯、版本原则 |
| `PROGRESS.md` | 经常更新 | 当前进展、版本演化回顾、关键设计决策、下一步计划 |
| `docs/README.md` | 每版更新 | 版本文档导航和阅读指南 |

- `CLAUDE.md` 是**长期稳定**的——只放目标和结构，不放进展状态。
- `STYLE.md` 放工作风格和约定——可能随着项目推进而调整。
- `PROGRESS.md` 放**一切随时间变化的内容**——当前处于哪个阶段、完成了什么、最近做了什么决策、下一步做什么。
- `docs/lean_model_v*.md` 是实际工作内容（内核模型文档），不属于文档系统本身。

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
    ├── lean_model_v1.md   # v1: + Σ, Pair
    ├── lean_model_v2.md   # v2: + Fst, Snd
    ├── lean_model_v3.md   # v3: + Ann
    ├── lean_model_v4.md   # v4: + whnf
    ├── lean_model_v5.md   # v5: + defeq
    ├── lean_model_v6.md   # v6: Surface/Core 分层 + elab
    ├── lean_model_v7.md   # v7: Proj + StructureInfo + Sigma 去特殊化
    ├── lean_model_v8.md   # v8: ParamInfo + FieldInfo + 辅助函数
    ├── lean_model_v9.md   # v9: StructureCmd + 类型生成
    └── lean_model_v10.md  # v10: ProjectionInfo + SProj + SDot
```

不在版本控制中的文件（临时讨论、旧版变体等）见 `.gitignore`。
