# Progress Report

> 本文档经常更新。长期稳定的项目约定见 [CLAUDE.md](CLAUDE.md)。

## 在整体计划中的位置

这个仓库的总目标是：**学习 Lean + 类型论 + 用 Lean 做数学证明**。

```
总目标：学习 Lean + 类型论 + 用 Lean 做数学证明
├── 子目标 1：内核建模（← 你在这里）
│   └── 从零建模 Lean 风格内核，逐版迭代 (v0→v10→...)
├── 子目标 2：类型论基础
├── 子目标 3：Lean 实操
└── 子目标 4：数学证明
```

当前处于**子目标 1（内核建模）**阶段。这个阶段的目的是通过建模理解定理证明器的内部工作原理，为后续实操和证明打下理论基础。不追求实现一个真正的 proof assistant。

核心理念：**每个版本只关注相对上一版本的变化**。每个版本的 diff 都很小，容易阅读。

---

## 版本概览

### 第一阶段：基础类型系统 (v0–v3)

| 版本 | 核心内容 | Kernel / Elab |
|------|---------|--------------|
| **v0** | 最小依赖类型核。`Term` 有 6 个构造子：`Const`、`Sort`、`Var`、`App`、`Lam`、`Forall`。`State` 记录全局 axioms/defs。`Context` 记录局部变量类型。`infer_type` + `check_type`（结构相等）。 | 统一层 |
| **v1** | 引入 Sigma 类型（依赖乘积）和 Pair。`Term` 增至 8 个构造子。新增 Sigma 的 formation/introduction 规则。`check_type` 升级为 bidirectional typing。 | 统一层 |
| **v2** | 引入 Fst 和 Snd（Sigma 的 elimination rules）。`Term` 增至 10 个构造子。Sigma 类型体系完整。 | 统一层 |
| **v3** | 引入 `Ann`（类型标注），用于向 elaboration 传递 expected type。这是 **elaboration-level 构造**——不是 kernel 节点。为 Surface/Core 分层做了铺垫。 | 分层雏形 |

**阶段总结：** v3 结束时，我们有了一个能表达 Π、Σ、类型标注的 term 语言，bidirectional typing，以及 substitution。但 kernel 和 elaboration 还在同一个 term 类型中混在一起。

### 第二阶段：规约与定义相等 (v4–v5)

| **v4** | **whnf**（弱头部正规化）：Ann 擦除、delta 展开（def）、beta 化简、Fst/Snd 投影化简。`infer_type` 在检查类型头部前先 whnf 展开。**不引入 defeq**——`check_type` 仍用结构相等。 | 统一层 |
| **v5** | **defeq**（定义相等）：alpha-renaming + whnf + 递归比较。`check_type` 改用 defeq 而非结构相等。依赖类型核的类型检查现在与 Lean 一致。 | 统一层 |

**阶段总结：** v5 拥有了一个完整（虽然精简）的依赖类型核：Π、Σ、Pair、Fst/Snd、Ann、whnf、defeq、bidirectional typing。所有东西在一个 `Term` 类型中。

### 第三阶段：Surface/Core 分层与结构一般化 (v6–v8)

| **v6** | **Surface/Core 分层**。`SurfaceTerm`（12 构造子，含 `SAnn`）和 `CoreTerm`（9 构造子，含 `CPairTyped`、`CSigma`）。`elab` 函数把 SurfaceTerm → CoreTerm。`Ann` 在 elaboration 中被消耗。`Pair` 被替换为 `CPairTyped`（携带 Σ 类型信息）。所有 kernel 函数只作用于 CoreTerm。 | 分层 |
| **v7** | **CoreTerm 去特殊化**。去掉 `CSigma`、`CPairTyped`、`CFst`、`CSnd`。新增 `Proj(structName, index, target)`——通用投影机制。`State` 新增 `Structures` 字段，存储 `StructureInfo`。Sigma 不再是 core 构造子——它变成了 `Const Sigma`（环境中的全局名字）。Pair 变成了 `Const Sigma.mk` 的普通应用。`fst`/`snd` 变成了 `Proj(Sigma, 0/1, target)`。`whnf`、`infer_type`、`defeq` 的 Proj 分支由 `StructureInfo` 驱动——不硬编码任何具体结构。 | 分层的 Kernel |
| **v8** | **StructureInfo 完善**。`StructureInfo` 扩展为带 `params: List[ParamInfo]` + `fields: List[FieldInfo]` 的完整记录。新增 `subst_many`、`match_structure_type`、`projection_type` 辅助函数。预置状态 `SΣΠ` 包含 Sigma 和 Prod 两个结构。`infer_type(Proj)` 不再硬编码 Sigma，改为调用 `match_structure_type` + `projection_type`。 | 分层的 Kernel |

**阶段总结：** v8 的关键突破是 **Proj 的一般化**——kernel 不再对 Sigma 有特殊处理。新增任何结构（Point、Color 等）只需在 `S.Structures` 中注册 `StructureInfo`，所有 kernel 函数自动适用。但需要手动预置 Sigma 和 Prod。

### 第四阶段：命令式结构声明 (v9–v10)

| **v9** | **StructureCmd**——用户通过顶层命令声明新结构。新增 `StructureCmd`、`ParamDecl`、`FieldDecl` 数据类型。`exec` 新增 StructureCmd 分支，自动生成 type constructor 类型、constructor 类型、`StructureInfo`。新增 `make_forall_chain`、`make_structure_type`、`make_constructor_type` 等类型生成辅助函数。**v9 不再预置任何结构**——Sigma 和 Prod 都通过 StructureCmd 定义。SΣ 和 SΣΠ 变为方便缩写。Kernel 函数完全不变。 | 分层 + Command |
| **v10** | **ProjectionInfo + SProj + SDot**。新增 `ProjectionInfo` 类型（投影名、结构名、字段下标）。`State` 新增 `Projections` 字段。`SurfaceTerm` 新增 `SProj` 和 `SDot` 两个构造子。`elab` 新增 SProj 和 SDot 分支。`exec(StructureCmd)` 新增第五步——自动为每个字段生成 ProjectionInfo。投影名 = `typeName + "." + fieldName`（如 `Sigma.a`、`Point.x`）。**Method A**：投影名注册到 `State.Projections`（elaboration 元数据），不注册到 Axioms。Kernel 不变。 | 分层 + Command + 投影名 |

**阶段总结：** v9–v10 完成了从"预置状态"到"用户可声明"的转变。所有结构（包括 Sigma）都通过 StructureCmd 定义。投影名通过 ProjectionInfo 管理——属于 surface/elab 层，不影响 kernel。用户可以通过 `Point.x p` 或 `p.x` 访问字段。

---

## 关键设计决策

### 1. Surface/Core 分层（v6）

**问题：** Ann（类型标注）、裸 Pair（缺少类型信息）在 kernel 层面没有意义。
**决策：** 引入两个 term 类型——用户写的 `SurfaceTerm` 和 kernel 处理的 `CoreTerm`。`elab` 负责转换。
**收益：** 关注点分离。Kernel 只看到它需要的东西。为后续所有版本的 elaboration 改进打下了基础。

### 2. Proj 的一般化（v7）

**问题：** `CFst`/`CSnd` 只能处理 Sigma。每个新结构都需要新的投影构造子。
**决策：** 用一个 `Proj(structName, index, target)` 替代所有专门的投影构造子。投影规则由 `StructureInfo` 驱动。
**收益：** kernel 不再硬编码任何结构。添加新结构不需要修改 kernel 代码。

### 3. Sigma 与构造子的去特殊化（v7）

**问题：** Sigma 和 Pair 作为 core 构造子存在时，kernel 必须知道它们是"特殊的"。
**决策：** Sigma 变成全局常量 `Const Sigma`，Pair 变成 `Const Sigma.mk` 的普通应用。类型信息存储在 `State.Axioms` 和 `State.Structures` 中，而非 term 构造子中。
**收益：** `CoreTerm` 从 10 个构造子缩减到 7 个。Sigma 不再是特殊的——它和其他结构一样。

### 4. StructureCmd（v9）

**问题：** v8 仍然预置 Sigma 和 Prod 在初始状态中，用户无法声明自己的结构。
**决策：** 引入 `StructureCmd`——一个顶层命令，让用户声明结构的名字、参数和字段。`exec` 自动生成所有类型签名和 StructureInfo。
**收益：** v9 不再预置任何结构。所有结构都通过相同机制创建。这是从"系统内置"到"用户定义"的关键转变。

### 5. Method A：投影名为 elaboration 元数据（v10）

**问题：** 如何让用户用名字而非下标访问结构字段？
**两个方案：**
- **Method A：** 投影名为 elaboration 元数据（`State.Projections`），不进入 Axioms。`SProj(Sigma.a, p)` 直接 elaborate 为 `Proj(Sigma, 0, p_core)`。
- **Method B：** 投影名作为全局常量进入 Axioms，有类型和 reduction rule。`Const Sigma.a A B p` whnf 归约为 `Proj(Sigma, 0, p)`。

**决策：** v10 采用 Method A。不需要修改 kernel，不需要 DefCmd。更简单，且可以在将来切换到 Method B。
**收益：** `SProj` 和 `SDot` 提供了通用的投影语法——适用于所有结构。用户不再需要记住字段下标。

---

## 当前架构 (v10)

```
┌──────────────────────────────────────────────┐
│                  Surface Layer               │
│  SSigma, SPair, SFst, SSnd, SAnn             │
│  SProj (projection name syntax)   ← v10 新增 │
│  SDot  (dot notation)             ← v10 新增 │
│       ↓                                      │
│     elab()                                   │
│       ↓                                      │
│                  Kernel Layer                 │
│  CoreTerm: Const, Sort, Var, App, Lam,       │
│            Forall, Proj          (7 构造子)   │
│  whnf, defeq, infer_type, check_type        │
│       ↓                                      │
│                  State Layer                  │
│  Axioms, Defs, Structures, Projections       │
└──────────────────────────────────────────────┘
```

### CoreTerm 构造子（自 v7 以来不变）

| 构造子 | 用途 | Lean 对应 |
|--------|------|----------|
| `Const` | 全局常量引用 | `Expr.const` |
| `Sort` | universe | `Expr.sort` |
| `Var` | 局部变量 | `Expr.bvar` 或 `fvar` |
| `App` | 函数应用 | `Expr.app` |
| `Lam` | lambda 抽象 | `Expr.lam` |
| `Forall` | 依赖 Π 类型 | `Expr.forall` |
| `Proj` | 一般投影 | 简化版（Lean 用 `Expr.proj`） |

### State 结构

| 字段 | 内容 | 引入版本 |
|------|------|---------|
| `Axioms` | 全局名字 → 类型 | v0 |
| `Defs` | 全局名字 → (类型, body) | v0 |
| `Structures` | 结构名字 → StructureInfo | v7 |
| `Projections` | 投影名 → ProjectionInfo | v10 |

### Command 构造子

| 命令 | 作用 | 引入版本 |
|------|------|---------|
| `AxiomCmd n : A` | 声明一个类型为 A 的 axiom | v0 |
| `DefCmd n A t` | 定义一个类型为 A、body 为 t 的 def | v0 |
| `StructureCmd` | 声明一个新结构（type constructor + constructor + fields） | v9 |

---

## 演化统计

| 版本 | CoreTerm 构造子 | SurfaceTerm 构造子 | State 字段 | 主要新增 |
|------|:---:|:---:|:---:|---------|
| v0 | 6 | — | 2 | Π, Lam, bidirectional typing 雏形 |
| v1 | 8 | — | 2 | Σ, Pair, check_type 升级 |
| v2 | 10 | — | 2 | Fst, Snd, elimination rules |
| v3 | 10 | — | 2 | Ann (elaboration hint) |
| v4 | 10 | — | 2 | whnf |
| v5 | 10 | — | 2 | defeq |
| v6 | 9 | 12 | 2 | Surface/Core 分层, elab |
| v7 | 7 | 11 | 3 | Proj, StructureInfo, Sigma 去特殊化 |
| v8 | 7 | 11 | 3 | ParamInfo, FieldInfo, match_structure_type, projection_type |
| v9 | 7 | 11 | 3 | StructureCmd, 类型生成辅助函数, 不预置任何结构 |
| v10 | 7 | **13** | **4** | ProjectionInfo, SProj, SDot, Method A |

**趋势：** CoreTerm 从膨胀（v0→v2: 6→10 构造子）到精简（v6→v7: 9→7 构造子）。SurfaceTerm 持续增长以支持更丰富的用户语法。State 逐步增长以支持结构信息管理。

---

## 尚未加入（v10 边界）

v10 刻意不包含以下内容，它们属于后续版本的工作：

### 类型系统
- eta 规则（对于 Π 和 Σ）
- proof irrelevance
- universe constraints 和 level metavariables
- universe polymorphism
- reducibility control（opaque / semireducible）

### 内核表示
- de Bruijn indices / fvar（当前用 named representation）
- 完整的 Lean `Expr`（包括 `mdata`、`let` 等）
- 真正的 `Expr.proj`（带 `ProjectionInfo` 索引）

### 声明机制
- `InductiveCmd`——归纳类型的声明（包括递归子自动生成）
- `DefCmd` 的完整 whnf reduction rule（当前 whnf 只 delta-expand def）
- Method B——投影名作为带类型和 reduction rule 的全局常量

### 表层语法
- 通用 anonymous constructor（`⟨a, b⟩` 语法泛化到所有结构）
- 自定义结构的 surface syntax（当前 elab 只对 Sigma 有 `SSigma`/`SPair`/`SFst`/`SSnd`）
- implicit arguments
- 递归结构（StructureCmd 当前不支持：字段类型不能引用正在声明的 typeName）

---

## 下一步

当前阶段（内核建模）可能继续的方向：

### v11 候选主题
- **Method B**：投影名作为全局常量进入 Axioms，有类型和 reduction rule。需要先完善 DefCmd 的 whnf reduction
- **InductiveCmd**：归纳类型的声明命令，包括 recursor 自动生成
- **de Bruijn indices**：用 de Bruijn indices 替换 named representation，更接近真实 Lean 实现
- **eta 规则**：Π 和 Σ 的 eta 等价
- **universe polymorphism**：Level 参数化

### 从建模到实操
- 在 Lean 中实现模型的某些部分
- 用 Lean 写类型检查器或 whnf/normalizer
- 学习 Lean 标准库中 `Expr`、`Lean.Meta` 等的实际实现

### 文档改进
- 为每个版本补充更多直观图示
- 添加常见问题的 FAQ

---

## 文件组织

```
learn_lean/
├── CLAUDE.md              # 项目身份 + 文档系统索引（几乎不改）
├── STYLE.md               # 风格约定（偶尔修改）
├── PROGRESS.md            # 本文档——进展报告（经常更新）
├── README.md              # 项目主页
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

---

*最后更新：2026-07-19*
