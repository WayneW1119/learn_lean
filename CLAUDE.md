# CLAUDE.md

## 项目身份

这个仓库是 **WayneW1119** 学习 Lean 和类型论的工作空间。总目标是：

> 理解 Lean 定理证明器的内部工作原理，熟练使用 Lean 进行数学证明。

当前处于第一阶段：**从零建模一个 Lean 风格的依赖类型定理证明器内核**。通过逐版迭代的方式拆解每个概念，为后续的 Lean 实操和数学证明打下理论基础。

## 目标层级

```
总目标：学习 Lean + 类型论 + 用 Lean 做数学证明
├── 子目标 1：内核建模（当前阶段）
│   └── 从零建立精简的 Lean 风格内核模型，逐版迭代 (v0→v10→...)
├── 子目标 2：类型论基础
│   └── Π, Σ, 宇宙层级, 归纳类型, 递归子, identity type 等
├── 子目标 3：Lean 实操
│   └── 写 Lean 代码、理解标准库、typeclass、tactics、macro 等
└── 子目标 4：数学证明
    └── 用 Lean 形式化数学定理（重点应用场景）
```

内核建模是整个计划的**第一步**——先吃透原理，再动手写代码、做证明。

## 文档系统

| 文档 | 性质 | 内容 |
|------|------|------|
| `CLAUDE.md` | **长期稳定** | 项目目标、风格约定、文件组织、文档系统介绍 |
| `PROGRESS.md` | **经常更新** | 当前进展、版本演化、关键决策、下一步计划 |
| `docs/README.md` | **经常更新** | 版本文档导航和阅读指南 |
| `docs/lean_model_v*.md` | **版本化** | 各版本的内核模型详细文档 |
| `README.md` | **经常更新** | 项目主页，版本表格，快速链接 |

### 文档维护原则

- `CLAUDE.md` 只放**长期不变**的东西：目标、风格、结构。不要放进展状态。
- 进展、当前版本信息、下一步计划 → 写到 `PROGRESS.md`
- 每次完成一个版本或做出重要设计决策后，更新 `PROGRESS.md`
- 版本文档 (`lean_model_v*.md`) 每个版本一份，只标记当前版本与上一版本的差异

## 风格约定

### 写作风格
- 中文写作，混合数学符号和 Python 风格伪代码
- 语法类型用代数数据类型风格；状态类型用 class/record 风格
- `写作 ...` 表示 term 的写法格式；`简记 X 为 ...` 是元语言缩写
- 重要设计决策附**评论**，解释"为什么这样做"
- `SurfaceTerm` 构造子以 `S` 为前缀；`CoreTerm` 构造子无前缀

### 版本原则
- **每个版本只关注与上一版本的差异**
- 只保留当前版本标记（如 `【v10 新增】`），旧版本标记全部去掉
- 当前版本的新增例子保留详细推导；非当前版本例子只保留简要结论
- 内核模型的目的是**理解原理**，不追求实现一个真正的 proof assistant

### 命名约定
- Sigma 的字段名用 `a`/`b`（不是 Lean 的 `fst`/`snd`），所以投影名是 `Sigma.a`/`Sigma.b`
- 构造子参数用描述性名字（`structName`、`index`、`target`）

### 代码习惯
- 读代码时注意匹配周围代码的风格（注释密度、命名、idiom）
- 修改前先读目标文件，确保理解上下文
- 用 `Edit` 工具做精确字符串替换，不要重写整个文件

## 文件组织

```
learn_lean/
├── CLAUDE.md              # 本文件——项目身份和约定（长期稳定）
├── README.md              # 项目主页
├── PROGRESS.md            # 进展报告（经常更新）
└── docs/
    ├── README.md          # 版本文档导航
    ├── lean_model_v0.md   # v0: 最小依赖类型核
    ├── lean_model_v1.md   # v1: + Σ, Pair
    ├── lean_model_v2.md   # v2: + Fst, Snd
    ├── lean_model_v3.md   # v3: + Ann
    ├── lean_model_v4.md   # v4: + whnf
    ├── lean_model_v5.md   # v5: + defeq
    ├── lean_model_v6.md   # v6: Surface/Core 分层, elab
    ├── lean_model_v7.md   # v7: Proj, StructureInfo, Sigma 去特殊化
    ├── lean_model_v8.md   # v8: ParamInfo, FieldInfo, 辅助函数
    ├── lean_model_v9.md   # v9: StructureCmd, 类型生成辅助函数
    └── lean_model_v10.md  # v10: ProjectionInfo, SProj, SDot (最新)
```

不在版本控制中的文件（临时讨论、旧版本变体）：`another_v5.md`、`discuss_about_v6.md`、`discuss_about_v7.md`、`lean_model_v1_ori.md`、`temp_about_v3.md`、`temp_another_v2.md`。

## 当前状态

见 [PROGRESS.md](PROGRESS.md)。

当前版本：**v10**。CoreTerm 自 v7 起稳定在 7 个构造子。v10 的关键进展是 ProjectionInfo + SProj + SDot，Method A 下投影名为 elaboration 元数据。

下一步方向：可能的 v11 或进入 Lean 实操阶段。
