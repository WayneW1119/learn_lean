# model v11

> **相对于 v10 的变化：**
>
> * §5.1d（新增）：`ConstructorInfo` 数据类型 — 记录构造子名和参数类型
> * §5.1e（新增）：`InductiveInfo` 数据类型 — 记录类型名、构造子列表、recursor 名
> * §5.1f（新增）：`RecursorInfo` 数据类型 — 记录 recursor 名和对应 inductive 的构造子列表
> * §5.3：`State` 新增 `Inductives` 和 `Recursors` 两个字段
> * §5c（新增章节）：recursor 类型生成辅助函数 `make_motive_type`、`make_recursor_type`
> * §6：新增 `ConstructorDecl` 数据类型和 `InductiveCmd` 命令
> * §7：`exec` 新增 `InductiveCmd` 分支 — 自动生成 type、constructors、recursor、InductiveInfo、RecursorInfo
> * §12.4（新增）：whnf 新增 iota reduction — recursor 应用到 constructor 时化简
> * §15b.5（新增）：InductiveCmd Bool 完整例子
> * §19.7（新增）：Bool.rec iota reduction 的 whnf 例子
> * §21.7（新增）：用 Bool.rec 定义 not 的 elab 例子
> * v11 不改 `CoreTerm`（7 个构造子不变），不改 `SurfaceTerm`（13 个构造子不变）
>
> **记号约定：** 本文档中有时使用"令 X = ..."或"简记 X 为 ..."。这是**文本层面的临时缩写**，不是模型中的操作。模型中没有"令"或"赋值"的概念 — State 的修改只能通过 `exec` 执行命令来完成。
>
> **命名约定：** 有两种 term 类型：
> - `SurfaceTerm` 的构造子以 `S` 为前缀（`SConst`、`SApp`、`SAnn` 等）
> - `CoreTerm` 的构造子**不再使用** `C` 前缀（`Const`、`App`、`Proj` 等）
>
> 在不引起歧义时，"写作"格式省略前缀 — 例如 `Const Nat` 既可以表示 `SConst Nat` 也可以表示 CoreTerm 的 `Const Nat`，具体含义由上下文决定。
>
> **多参数应用缩写：** 因为 `App` 是二元构造子，下面约定：
>
> ```text
> f a b c
> ```
>
> 是元语言缩写，表示：
>
> ```text
> App(App(App(f, a), b), c)
> ```
>
> 例如 `(Const Bool.rec) motive case_false case_true b` 表示 `App(App(App(App(Const Bool.rec, motive), case_false), case_true), b)`。
>
> ---
>
> 本文档中：
>
> - 只保留**当前最新**的定义与记号。
> - 主要目标是统一格式、统一记号、增强可读性。
> - 在不改变核心内容的前提下，尽量多使用"写作"的格式。
> - 重要的设计决策会附上**理由和评论**，帮助理解"为什么这样做"。
---
## 0. 总约定
本模型中：
- 语法对象类型（如 `CoreTerm`、`Command`）用**代数数据类型**风格定义。
  - 定义时要写出：构造子、参数占位符、参数类型。
  - 例如：
```text
A = C1(b : B)                 # 写作 C1 b
  | C2(b : B, c : C)         # 写作 b C2 c
```
这里：
- 前面的 `b`、`c` 是参数变量名；
- 后面的 `b`、`c` 是"写作"时使用的占位符。
- `isinstance(a, C2)` 用于匹配 `a : A` 是否由构造子 `C2` 构造。
  - 例如 `a` 可以写作 `b C2 c`。
  - 若匹配成功，则可以：
    - 用 `a.b`、`a.c` 进行拆解；
    - 或者通过 `a.args` 进行拆解。
- 状态对象类型（如 `State`、`Context`）用 `class / record` 风格定义。
  - 其字段通过 `S.field` 访问。
- 可使用的对象类包括：`PartialMap[K, V]`、集合等，认为底层已经实现。
  - `PartialMap[k : K, v : V]` 表示从 `K` 到 `V` 的映射。
- 定义函数时使用 python 风格，例如：
```python
# 写作 exec(S, cmd)
def exec(S: State, cmd: Command) -> State:
    ...
```
- 对于各种类型、构造子应用、函数，都尽量给出"写作"的格式。
- `CoreTerm` 有 7 个构造子：`Const`、`Sort`、`Var`、`App`、`Lam`、`Forall`、`Proj`。
  - `Sigma` 不再是 core 构造子 — 它是环境中的全局名字 `Const Sigma`。
  - `Pair` 不再是 core 构造子 — 它是 `Const Sigma.mk` 的应用。
  - `fst/snd` 不再是 core 构造子 — 它们是 `Proj(Sigma, 0/1, target)`。
  - 所有 kernel 函数（`infer_type`、`check_type`、`whnf`、`defeq`、`FV`、`subst`）只作用于 `CoreTerm`。
  - `elab` 函数负责把 `SurfaceTerm` 转换为 `CoreTerm`。
- v10 新增 `ProjectionInfo`（§5.1b）和 `State.Projections`（§5.3）— StructureCmd 自动为每个字段生成投影名。投影名用于 elaboration（§15a），不注册到 Axioms（Method A）。
- v11 新增 `InductiveCmd`（§6）— 用户通过顶层命令声明 inductive 类型。v11 第一版只支持最简单的 non-indexed inductive（Bool/Unit/Empty 级别：零个参数、零个递归参数），暂不支持 Nat 级别的递归 inductive。CoreTerm 不变 — constructors 和 recursor 都是 `Const`，它们的应用都是 `App` 链。`whnf` 新增 iota reduction 规则。
- `StructureCmd`（§6）让用户通过顶层命令声明新结构（包括 Sigma 和 Prod）。当前模型不预置任何结构 — 所有 StructureInfo 都通过 StructureCmd 生成。Kernel 规则无需修改即可处理新声明的结构。
---
## 1. 关于 `PartialMap`
对 `M : PartialMap[K, V]`，约定可以使用以下操作：
```text
M.contains(k)
M.get(k)
M.set(k, v)
```
也允许使用下列等价记号：
```text
k in dom(M)
M(k)
M[k -> v]
```
---
## 2. 名字与 level
### 2.1 `GlobalName`
现在有一个集合 `GlobalName`，里面是所有可能的名字。
可以把它理解为一个可数集合，本质上等价于一个自然数序列。
### 2.2 `LocalName`
现在有一个集合：
```text
LocalName ⊆ GlobalName
```
其中的元素表示可以作为局部变量名字使用的那些名字。
### 2.3 `Level`
当前阶段，定义数据类型 `Level`：
```text
Level = LevelFromNat(n : Nat)   # 写作 level n
```
其中：
- `Nat` 是底层内建的数据类型；
- 自然数的运算也视为底层已经实现。
因此：
```text
level 0 : Level
level 1 : Level
level 2 : Level
```
并定义两个函数：
```python
# 写作 succ_level(l)
def succ_level(l : Level) -> Level:
    if isinstance(l, LevelFromNat):
        n = l.args          # l = level n
        return level (n + 1)
    raise Error            # 之后再补充

# 写作 max_level(l1, l2)
def max_level(l1 : Level, l2 : Level) -> Level:
    if isinstance(l1, LevelFromNat) and isinstance(l2, LevelFromNat):
        m = l1.args        # l1 = level m
        n = l2.args        # l2 = level n
        return level max(m, n)
    raise Error            # 之后再补充
```
---
## 3. `SurfaceTerm`

`SurfaceTerm` 表示用户在表层语法中写的东西。v11 不改 `SurfaceTerm` — 13 个构造子与 v10 完全相同。

```text
SurfaceTerm = SConst(name : GlobalName)                  # 写作 Const name
            | SSort(level : Level)                       # 写作 Sort level
            | SVar(name : LocalName)                     # 写作 Var name
            | SApp(fn : SurfaceTerm, arg : SurfaceTerm)  # 写作 fn arg
            | SLam(x : LocalName, A : SurfaceTerm, body : SurfaceTerm)  # 写作 fun (x : A) => body
            | SForall(x : LocalName, A : SurfaceTerm, B : SurfaceTerm)  # 写作 Π (x : A), B
            | SSigma(x : LocalName, A : SurfaceTerm, B : SurfaceTerm)   # 写作 Σ (x : A), B
            | SPair(a : SurfaceTerm, b : SurfaceTerm)    # 写作 ⟨a, b⟩
            | SFst(t : SurfaceTerm)                      # 写作 fst t
            | SSnd(t : SurfaceTerm)                      # 写作 snd t
            | SProj(projectionName : GlobalName, target : SurfaceTerm)   # 写作 projectionName target
            | SDot(target : SurfaceTerm, fieldName : LocalName)          # 写作 target.fieldName
            | SAnn(t : SurfaceTerm, A : SurfaceTerm)     # 写作 (t : A)
```

**评论：** v11 暂不引入 `SMatch` — 用户直接写 `Bool.rec` 的应用。`SMatch` 是 surface layer 的语法糖，可以在后续版本中加入；elab 时将它转换为 recursor 的应用。v11 先用最朴素的方式：手写 `Bool.rec` application，集中在验证 iota reduction 的正确性。

构造子和 recursor 在 surface 层通过 `SConst` 引用。例如 `SConst Bool.false` elaborate 后变成 `Const Bool.false`，`SConst Bool.rec` elaborate 后变成 `Const Bool.rec`。这与 v10 中 `SConst Sigma` elaborate 为 `Const Sigma` 的模式完全相同。

---
## 4. `CoreTerm`

自 v7 起 `CoreTerm` 有 7 个构造子。**v11 不改 CoreTerm。** 构造子（`Bool.false`、`Bool.true`）和 recursor（`Bool.rec`）都是 `Const`；它们的应用都是普通 `App` 链。

```text
CoreTerm = Const(name : GlobalName)                          # 写作 Const name
         | Sort(level : Level)                               # 写作 Sort level
         | Var(name : LocalName)                             # 写作 Var name
         | App(fn : CoreTerm, arg : CoreTerm)                # 写作 fn arg
         | Lam(x : LocalName, A : CoreTerm, body : CoreTerm) # 写作 fun (x : A) => body
         | Forall(x : LocalName, A : CoreTerm, B : CoreTerm) # 写作 Π (x : A), B
         | Proj(structName : GlobalName, index : Nat, target : CoreTerm)
	                                                           # 写作 Proj structName index target
```

**评论：**

- v11 遵循 v7-v10 的一贯原则：**扩展 State 和 Command，不扩展 CoreTerm。** inductive type、constructors、recursor 都通过 `AxiomCmd` 的方式注册到 State（其类型由 InductiveCmd 自动生成），它们在 CoreTerm 中只是 `Const` + `App`。
- `Bool.rec` 应用到 4 个参数（motive, case_false, case_true, target）在 CoreTerm 中是 4 层嵌套 `App`，不引入新的构造子。
- `whnf` 新增的 iota reduction 通过检查 `S.Recursors` 来识别递归子应用，不依赖新构造子。

### 4.1 例子

```text
Const Bool                                   -- inductive 类型
Const Bool.false                             -- 构造子（nullary）
Const Bool.true                              -- 构造子（nullary）
Const Bool.rec                               -- recursor
(Const Bool.rec) motive case_false case_true b   -- recursor 应用（4 参数缩写）
App(Const Bool.not, Const Bool.false)         -- 函数应用
```

注意：CoreTerm 中没有 `Match`、没有 `Inductive`（作为构造子）。构造子和 recursor 都是普通的 `Const`。

---
## 4a. 辅助函数（CoreTerm 层面）

本节定义几个只依赖 CoreTerm 的辅助函数。v11 不改这些函数。

### 4a.1 `is_sigma_type`

```python
# 写作 is_sigma_type(t)
def is_sigma_type(t : CoreTerm) -> Optional[Pair[CoreTerm, CoreTerm]]:
    '''
    如果 t = App(App(Const Sigma, A), Bfun)，返回 Pair(A, Bfun)
    否则返回 None
    '''
    if isinstance(t, App):
        f_B, Bfun = t.args
        if isinstance(f_B, App):
            f_A, A = f_B.args
            if isinstance(f_A, Const) and f_A.args == Sigma:
                return Pair(A, Bfun)
    return None
```

### 4a.2 `collect_app`

```python
# 写作 collect_app(t)
def collect_app(t : CoreTerm) -> Pair[CoreTerm, List[CoreTerm]]:
    '''
    把 (((f a1) a2) ... an) 拆成 Pair(f, [a1, a2, ..., an])
    '''
    args = []
    while isinstance(t, App):
        f, a = t.args
        args = [a] + args
        t = f
    return Pair(t, args)
```

**评论：** 这个函数在 `whnf` 的 iota reduction 分支中也会用到 — 用于从 recursor 应用链中提取参数。例如对 `(Const Bool.rec) motive case_false case_true target`，`collect_app` 得到 `Pair(Const Bool.rec, [motive, case_false, case_true, target])`。

### 4a.3 元语言辅助函数

```python
# 写作 mk_sigma_type(A, Bfun)
def mk_sigma_type(A : CoreTerm, Bfun : CoreTerm) -> CoreTerm:
    return App(App(Const(Sigma), A), Bfun)

# 写作 mk_sigma_mk(A, Bfun, a, b)
def mk_sigma_mk(A : CoreTerm, Bfun : CoreTerm, a : CoreTerm, b : CoreTerm) -> CoreTerm:
    return App(App(App(App(Const(Sigma.mk), A), Bfun), a), b)
```

---
## 5. `State` 与结构/归纳类型信息

### 5.1 `ParamInfo` 与 `FieldInfo`

```text
class ParamInfo:
    name : LocalName
    type : CoreTerm          # 参数的类型（模板，可能引用前序参数名）

class FieldInfo:
    name : LocalName
    type : CoreTerm          # 字段的类型（模板，可能引用参数名和前序字段名）
```

### 5.1b `ProjectionInfo`

```text
class ProjectionInfo:
    projectionName : GlobalName    # 投影的全局名字（如 Sigma.a、Point.x）
    structName     : GlobalName    # 所属结构类型名（如 Sigma、Point）
    index          : Nat           # 字段下标（0 = 第一个字段，1 = 第二个，...）
```

### 5.1c `ProjectionInfo` well-formedness invariant

`S.Projections` 中的每个 `ProjectionInfo` 必须满足 §5.1c（v10 已定义）中的条件。

### 5.1d `ConstructorInfo`                                           【v11 新增】

```text
class ConstructorInfo:
    name : GlobalName                      # 构造子的全局名字（如 Bool.false）
    args : List[Pair[LocalName, CoreTerm]]  # 构造子参数列表（名字 + CoreTerm 类型）
```

**评论：** `ConstructorInfo` 记录 inductive type 的单个构造子信息。v11 第一版中，`args` 总是空列表（只支持 nullary constructors）。将来到 Nat 时，`succ` 会有 `args = [("n", Const Nat)]`（一个递归参数）。`args` 的类型是 CoreTerm（不包含 SurfaceTerm）— 因为 `exec(InductiveCmd)` 在 telescope 检查中已 elaborate 了所有参数类型。

对于 Bool：

```text
ConstructorInfo(Bool.false, [])    # false 无参数
ConstructorInfo(Bool.true, [])     # true 无参数
```

### 5.1e `InductiveInfo`                                             【v11 新增】

```text
class InductiveInfo:
    typeName     : GlobalName            # inductive 类型的全局名字（如 Bool）
    constructors : List[ConstructorInfo]  # 构造子列表
    recursor     : GlobalName            # recursor 的全局名字（如 Bool.rec）
```

**评论：** `InductiveInfo` 是 inductive 类型的元信息，记录类型名、构造子列表和对应 recursor 的名字。它存储在 `State.Inductives` 中。

对于 Bool：

```text
InductiveInfo(
  typeName     = Bool,
  constructors = [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ],
  recursor = Bool.rec
)
```

注意：`ConstructorInfo.name` 是完整全局名字（如 `Bool.false`，由 `typeName + "." + decl.name` 拼接），不是用户提供的短名字（`false`）。用户写在 `ConstructorDecl` 中的是短名字，`exec` 拼接为完整全局名字。

### 5.1f `RecursorInfo`                                              【v11 新增】

```text
class RecursorInfo:
    recursorName  : GlobalName            # recursor 的全局名字（如 Bool.rec）
    inductiveName : GlobalName            # 对应的 inductive 类型名（如 Bool）
    constructors  : List[ConstructorInfo]  # 构造子列表（与 InductiveInfo 中的一致）
```

**评论：** `RecursorInfo` 记录 recursor 的元信息，存储在 `State.Recursors` 中。它包含 inductive 类型名的引用、以及构造子列表 — 这两个字段让 `whnf` 的 iota reduction 可以查到"recursor 应用到哪个 constructor 时应该选择哪个 case"。v11 第一版中所有构造子都是 nullary，所以 reduction 规则很简单：recursor 应用到 constructor_i → 取出第 i 个 case。

对于 Bool：

```text
RecursorInfo(
  recursorName  = Bool.rec,
  inductiveName = Bool,
  constructors  = [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ]
)
```

### 5.2 `StructureInfo`

```text
class StructureInfo:
    typeName    : GlobalName
    constructor : GlobalName
    params      : List[ParamInfo]     # 类型参数列表
    fields      : List[FieldInfo]     # 字段列表
```

### 5.3 `State`                                                    【v11 修改】

```text
class State:
    Axioms      : PartialMap[g : GlobalName, t : CoreTerm]                 # 写作 g : t
    Defs        : PartialMap[g : GlobalName, Pair[t1 : CoreTerm, t2 : CoreTerm]]  # 写作 g : (t1, t2)
    Structures  : PartialMap[g : GlobalName, info : StructureInfo]          # 写作 g ↦ info
    Projections : PartialMap[g : GlobalName, info : ProjectionInfo]         # 写作 g ↦ proj_info
    Inductives  : PartialMap[g : GlobalName, info : InductiveInfo]          # 写作 g ↦ ind_info     【v11 新增】
    Recursors   : PartialMap[g : GlobalName, info : RecursorInfo]           # 写作 g ↦ rec_info     【v11 新增】
```

若 `S : State`，则：

```text
S.Axioms
S.Defs
S.Structures
S.Projections
S.Inductives
S.Recursors
```

分别表示该状态中的六个字段。

其中：
- 若 `S.Axioms.get(n) = A`，则表示：全局名字 `n` 被声明为 axiom，类型是 `A`。
- 若 `S.Defs.get(n) = Pair(A, t)`，则表示：全局名字 `n` 被声明为 def，类型是 `A`，body 是 `t`。
- 若 `S.Structures.get(n) = info`，则表示：`n` 是一个已登记的结构类型。
- 若 `S.Projections.get(n) = proj_info`，则表示：`n` 是一个投影名。
- 若 `S.Inductives.get(n) = info`，则表示：`n` 是一个已登记的 inductive 类型。        【v11 新增】
- 若 `S.Recursors.get(n) = info`，则表示：`n` 是一个已登记的 recursor。               【v11 新增】

**评论：** v11 新增的两个字段遵循与 `Structures` 相同的模式 — `InductiveCmd` 执行后将 inductive 类型的信息注册到 `S.Inductives`，将 recursor 的信息注册到 `S.Recursors`。`whnf` 通过查询 `S.Recursors` 来实现 iota reduction（不需要硬编码任何特定 inductive 类型）。

---
## 5a. 初始状态与结构缩写

v11 的初始状态 S₀ 与 v10 相同 — 空状态，所有结构通过 StructureCmd 定义：

```text
S₀.Axioms = {}
S₀.Defs = {}
S₀.Structures = {}
S₀.Projections = {}
S₀.Inductives = {}
S₀.Recursors = {}
```

SΣ 和 SΣΠ 缩写的定义与 v10 相同（§5a.4）。

为后续 InductiveCmd 例子引用方便，取全局名字：

```text
Bool, Bool.false, Bool.true, Bool.rec : GlobalName
```

要求所有名字互不相同。

---
## 5b. 类型生成辅助函数（StructureCmd 用）

与 v10 完全相同：`make_forall_chain`、`make_type_app`、`make_structure_type`、`make_constructor_type`。此处不重复列出。

---
## 5c. recursor 类型生成辅助函数                                  【v11 新增】

本节定义两个辅助函数，用于从 `InductiveInfo` 生成 recursor 的 CoreTerm 类型。它们只依赖 `CoreTerm`（§4）和 `InductiveInfo`/`ConstructorInfo`（§5.1d）— 不调用 `elab`、`whnf`、`infer_type`。

### 5c.1 `make_motive_type`

```python
# 写作 make_motive_type(info)
def make_motive_type(info : InductiveInfo) -> CoreTerm:
    '''
    从 InductiveInfo 生成 recursor 的 motive 类型。
    motive : Π (_ : typeName), Sort 0
    即一个从 inductive 类型到 Sort 0 的函数类型。
    '''
    x = fresh_local_name(set())  # 取一个不影响结果的新名字
    return Forall(x, Const(info.typeName), Sort(level 0))
```

**例子：** 对于 Bool：

```text
make_motive_type(InductiveInfo(Bool, [...], Bool.rec))
= Π (x : Bool), Sort 0
```

**评论：** 当前模型单宇宙，motive 的返回类型固定为 `Sort(level 0)`。将来支持 universe polymorphism 时需要让 `Sort u` 由 typeName 的 universe 参数化。

### 5c.2 `make_recursor_type`

```python
# 写作 make_recursor_type(info)
def make_recursor_type(info : InductiveInfo) -> CoreTerm:
    '''
    从 InductiveInfo 生成 recursor 的完整类型。
    v11 第一版：只支持 nullary constructors。

    格式：
      Π (motive : Π (_ : T), Sort 0),
      Π (case₁ : motive ctor₁),
      Π (case₂ : motive ctor₂),
      ...
      Π (target : T),
        motive target

    其中 case₁, case₂, ... 是自动生成的不重复局部名字。
    '''

    motiveName = fresh_local_name(set())
    motiveArg  = fresh_local_name({motiveName})
    targetName = fresh_local_name({motiveName, motiveArg})

    # motive : Π (_ : T), Sort 0
    motive_type = Forall(
        motiveArg,
        Const(info.typeName),
        Sort(level 0)
    )

    telescope = [
        Pair(motiveName, motive_type)
    ]

    used = {motiveName, motiveArg, targetName}

    # 为每个 constructor 生成一个 case binder（局部名字）
    for ctor in info.constructors:
        caseName = fresh_local_name(used)
        used.add(caseName)

        # case_i : motive ctor_i（nullary constructor 的特例）
        case_type = App(Var(motiveName), Const(ctor.name))
        telescope.append(Pair(caseName, case_type))

    # target : T
    telescope.append(Pair(targetName, Const(info.typeName)))

    # body = motive target
    body = App(Var(motiveName), Var(targetName))

    return make_forall_chain(telescope, body)
```

**例子：** 对于 Bool：

```text
make_recursor_type(InductiveInfo(Bool, [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ], Bool.rec))
```

motiveName = fresh（例如 `m`），motiveArg = fresh（例如 `_x`），targetName = fresh（例如 `b`），case₁ = fresh（例如 `c₁`），case₂ = fresh（例如 `c₂`）。

生成的类型：

```text
Π (m : Π (_x : Bool), Sort 0),
Π (c₁ : m Bool.false),
Π (c₂ : m Bool.true),
Π (b : Bool),
  m b
```

**也就是：**

```text
Bool.rec :
  Π (motive : Π (_ : Bool), Sort 0),
  Π (case_false : motive Bool.false),
  Π (case_true  : motive Bool.true),
  Π (b : Bool),
    motive b
```

其中 case binder 名 `case_false` / `case_true` 由 `fresh_local_name` 自动生成（不与 motive、motiveArg、targetName 冲突），**不是**构造子全局名 `Bool.false` / `Bool.true`。

这与预期的 Bool.rec 类型完全一致 ✓

**评论：** `make_recursor_type` 的生成规则是通用的 — 不硬编码 Bool。对于任何 inductive type，它自动生成 `motive` binder、每个构造子对应的 case binder、target binder，以及 `motive target` 作为 body。v11 第一版中所有构造子都是 nullary，所以 case 类型简化为 `motive ctor_i`。将来到 Nat 时（`succ : Nat → Nat`），case_succ 需要额外处理递归参数和 minor premise，这个函数需要相应扩展。

### 5c.3 评论

两个 recursor 辅助函数的关键特性：

1. **只构建 CoreTerm**：不调用 `elab`、`whnf`、`infer_type`。它们是纯粹的 term 构建器。

2. **通用的**：`make_recursor_type` 对任何 `InductiveInfo` 都适用 — 它遍历 `info.constructors` 列表生成 case，不硬编码任何特定 inductive 类型。

3. **与 StructureCmd 类型生成函数的对称关系**：`make_structure_type` / `make_constructor_type` 为单构造子结构生成类型；`make_motive_type` / `make_recursor_type` 为多构造子 inductive 生成类型。两者都是 `exec` 调用的纯 term 构建器。

---
## 6. 顶层命令 `Command`                                         【v11 修改】

新增 `ConstructorDecl` 数据类型：

```text
class ConstructorDecl:
    name : LocalName                    # 构造子的名字（如 false）
    args : List[Pair[LocalName, SurfaceTerm]]  # 构造子参数列表（v11 第一版为空）
```

**评论：** `ConstructorDecl` 是 InductiveCmd 的组成部分。`args` 是 SurfaceTerm 参数类型列表 — 用户在 SurfaceTerm 中写参数类型，exec 在 telescope 检查中 elaborate 它们为 CoreTerm。v11 第一版中 `args` 总是空列表。

更新后的 `Command` 类型：

```text
Command = AxiomCmd(name : GlobalName, term : SurfaceTerm)              # 写作 AxiomCmd n : A
        | DefCmd(name : GlobalName, term1 : SurfaceTerm, term2 : SurfaceTerm) # 写作 DefCmd n A t
        | StructureCmd(typeName : GlobalName, constructor : GlobalName,
            params : List[ParamDecl], fields : List[FieldDecl])
        | InductiveCmd(typeName : GlobalName,                          # 写作 InductiveCmd T [ctors]            【v11 新增】
            constructors : List[ConstructorDecl])
```

写作约定例子：

```text
InductiveCmd Bool
  constructors = [false : Bool, true : Bool]
```

这意味着：声明一个 inductive 类型 Bool，有两个构造子 false 和 true（无参数）。`false` 和 `true` 的完整全局名字是 `Bool.false` 和 `Bool.true`（由 `typeName + "." + constructorName` 拼接）。

还可以声明 `Empty`（零构造子）和 `Unit`（单构造子）：

```text
InductiveCmd Empty
  constructors = []

InductiveCmd Unit
  constructors = [unit : Unit]
```

**评论：** `InductiveCmd` 和 `StructureCmd` 是对称的 — 都是 State 生成器，不产生 CoreTerm。区别在于：`StructureCmd` 生成单构造子 + 字段 + 投影；`InductiveCmd` 生成多构造子 + recursor。用户写 `SurfaceTerm` 参数类型（`ConstructorDecl.args`）；`exec` 在 telescope 检查中 elaborate 它们为 CoreTerm。

---
## 7. 状态执行函数 `exec`                                       【v11 修改】

定义一个部分函数：

```text
exec(S : State, cmd : Command) -> State
```

### 7.1–7.3 AxiomCmd / DefCmd / StructureCmd

与 v10 完全相同（§7.2–§7.4）。此处不重复列出。

### 7.4 规则 3：执行 `StructureCmd`

与 v10 完全相同（五步：名字检查、telescope 检查、类型生成、ProjectionInfo 生成、状态更新）。

### 7.5 规则 4：执行 `InductiveCmd`                                 【v11 新增】

若：

```text
cmd = InductiveCmd(typeName, constructor_decls)
typeName ∉ dom(S.Axioms) ∪ dom(S.Defs) ∪ dom(S.Structures) ∪ dom(S.Projections) ∪ dom(S.Inductives)
```

并要求：所有构造子的完整名字 `typeName + "." + constructorDecl.name` 互不相同，且不与已有全局名字冲突。

执行分四步：

**第一步：名字检查** — `typeName` 不与已有名字冲突。构造子名拼接为 `typeName + "." + constructorDecl.name` 后也不与已有名字冲突。recursor 名 `typeName + "." + "rec"` 也不与已有名字冲突。

**第二步：Telescope 检查** — v11 第一版只支持 nullary constructors（无参数）。对每个 constructor，检查 `args` 是否为空，非空则直接报错。在后续版本中（如 Nat），此处会对每个构造子的参数类型做与 StructureCmd 类似的 telescope 检查。

**第三步：类型生成** — 构建 `InductiveInfo`，然后调用 `make_recursor_type`（§5c），将生成的结果作为 recursor 的类型。

```text
ctor_infos = []
for decl in constructor_decls:
    # elaborate 每个参数类型（v11 第一版：args 为空）
    arg_infos = []
    Γ = Context(Types={})
    for arg_name, arg_type_surf in decl.args:
        arg_type_core = elab(S, Γ, arg_type_surf, None)
        arg_infos.append(Pair(arg_name, arg_type_core))
        Γ = expand_context(Γ, arg_name, arg_type_core)
    ctor_full_name = typeName + "." + decl.name
    ctor_infos.append(ConstructorInfo(ctor_full_name, arg_infos))

recursor_name = typeName + "." + "rec"

info = InductiveInfo(typeName, ctor_infos, recursor_name)
rec_info = RecursorInfo(recursor_name, typeName, ctor_infos)

# 生成 typeName : Sort 0
type_type = Sort(level 0)

# 生成每个 constructor 的类型
# v11 第一版：所有 constructors 都是 nullary → 类型直接是 typeName
ctor_types = {}
for ctor_info in ctor_infos:
    # len(args) == 0 已在第二步检查中保证
    ctor_types[ctor_info.name] = Const(typeName)

# 验证 type_type 是 type
whnf(S, infer_type(S, ∅, type_type)) 必须是 Sort u₁

# 验证 constructor 类型
S_tmp = S
S_tmp = S_tmp.Axioms.set(typeName, type_type)
for ctor_name, ctor_type in ctor_types:
    S_tmp = S_tmp.Axioms.set(ctor_name, ctor_type)
    whnf(S_tmp, infer_type(S_tmp, ∅, ctor_type)) 必须是 Sort u

# 生成 recursor 类型
rec_type = make_recursor_type(info)

# 验证 recursor 类型
S_tmp = S_tmp.Axioms.set(recursor_name, rec_type)
whnf(S_tmp, infer_type(S_tmp, ∅, rec_type)) 必须是 Sort u
```

**第四步：状态更新**

```text
S' = S_tmp
S' = S'.Inductives.set(typeName, info)
S' = S'.Recursors.set(recursor_name, rec_info)
```

### 7.6 `exec` 完整代码：InductiveCmd 分支                          【v11 新增】

```python
elif isinstance(cmd, InductiveCmd):
    typeName, constructor_decls = cmd.args

    # 第一步：名字检查
    if typeName in S.Axioms or typeName in S.Defs or typeName in S.Structures or typeName in S.Projections or typeName in S.Inductives or typeName in S.Recursors:
        raise Error            # typeName 不能与已有全局名字冲突

    recursor_name = typeName + "." + "rec"
    if recursor_name in S.Axioms or recursor_name in S.Defs or recursor_name in S.Structures or recursor_name in S.Projections or recursor_name in S.Inductives or recursor_name in S.Recursors:
        raise Error            # recursor 名不能与已有名字冲突

    ctor_names = []
    for decl in constructor_decls:
        ctor_full_name = typeName + "." + decl.name
        if ctor_full_name in S.Axioms or ctor_full_name in S.Defs or ctor_full_name in S.Structures or ctor_full_name in S.Projections or ctor_full_name in S.Inductives or ctor_full_name in S.Recursors:
            raise Error        # 构造子名不能与已有名字冲突
        if ctor_full_name in ctor_names:
            raise Error        # 构造子名不能重复
        ctor_names.append(ctor_full_name)

    # 第二步：Telescope 检查（v11 第一版：只支持 nullary constructors）
    ctor_infos = []
    for decl in constructor_decls:
        if len(decl.args) != 0:
            raise Error        # v11 第一版：constructor 不能有参数
        ctor_infos.append(ConstructorInfo(typeName + "." + decl.name, []))

    # 第三步：类型生成 + 验证
    info = InductiveInfo(typeName, ctor_infos, recursor_name)
    rec_info = RecursorInfo(recursor_name, typeName, ctor_infos)

    # typeName : Sort 0
    type_type = Sort(level 0)

    T_type_type = whnf(S, infer_type(S, ∅, type_type))
    if not isinstance(T_type_type, Sort):
        raise Error

    # 加入 typeName 和 constructors
    S_tmp = State(
        Axioms = S.Axioms.set(typeName, type_type),
        Defs = S.Defs,
        Structures = S.Structures,
        Projections = S.Projections,
        Inductives = S.Inductives,
        Recursors = S.Recursors
    )
    for ctor_info in ctor_infos:
        ctor_type = Const(typeName)  # v11 第一版：nullary
        S_tmp = S_tmp.set_Axiom(ctor_info.name, ctor_type)

    # 生成 recursor 类型
    rec_type = make_recursor_type(info)

    T_rec_type = whnf(S_tmp, infer_type(S_tmp, ∅, rec_type))
    if not isinstance(T_rec_type, Sort):
        raise Error

    S_tmp = S_tmp.set_Axiom(recursor_name, rec_type)

    # 第四步：状态更新
    return State(
        Axioms      = S_tmp.Axioms,
        Defs        = S.Defs,
        Structures  = S.Structures,
        Projections = S.Projections,
        Inductives  = S.Inductives.set(typeName, info),
        Recursors   = S.Recursors.set(recursor_name, rec_info)
    )
```

注：`S_tmp.set_Axiom(n, t)` 是 `S_tmp = State(Axioms = S_tmp.Axioms.set(n, t), ...)` 的简写。

**评论：**

- `InductiveCmd` 是 State 生成器，不产生 CoreTerm。它修改 State（加 inductive type、constructors、recursor 的 axiom 声明，加 InductiveInfo 和 RecursorInfo），之后所有已有的 kernel 规则自动生效。
- v11 第一版只支持 nullary constructors（无参数、无递归）。构造子的类型就是 `Const typeName`（裸 inductive 类型）。将来到 Nat 时，`succ` 的类型会是 `Π (n : Nat), Nat`。
- recursor 的类型由 `make_recursor_type` 自动生成 — 对任何 InductiveInfo 都适用。生成的类型中，motive 名、motive 参数名、case binder 名、target 名都由 `fresh_local_name` 独立生成，互不冲突。
- **名字冲突检查：** v11 的 State 已扩展为 6 个字段。`name_is_used` 辅助函数确保新名字不与 Axioms, Defs, Structures, Projections, Inductives, Recursors 中的任何已有名字冲突。注意：v10 的 `AxiomCmd`、`DefCmd`、`StructureCmd` 分支中的名字检查也需要相应扩展为 6 字段检查（这些分支的代码在 v10 文档 §7.5 中，v11 只列出新增的 InductiveCmd 分支）。

---
## 8–11. Context / HasType / FV / subst

与 v10 完全相同。v11 不改这些章节。

## 12. 计算规则：`whnf`                                         【v11 修改】

v11 的 `whnf` 在 v10 的基础上新增一类计算：**recursor iota reduction**。

### 12.1–12.3 Const delta / App beta / Proj 结构投影

与 v10 完全相同。

### 12.4 recursor iota reduction                                    【v11 新增】

如果应用链的 head 是一个 recursor，并且 target（最后一个参数）whnf 后是某个 constructor，则选择对应的 case：

```text
whnf(S, (Const recName) motive case₁ ... caseₙ target)
  = whnf(S, case_i)
      当 S.Recursors.get(recName) 提供了 RecursorInfo
        且 target whnf 后 = Const ctor_i
        且 ctor_i 是 RecursorInfo.constructors 中的第 i 个构造子
        且 应用链的参数数量 = 2 + num_ctors（motive + target + n 个 cases）
  = 不化简
      当不满足上述条件
```

```python
if isinstance(t, App):
    # ... 先检查 beta reduction（12.2）...

    # 如果 beta reduction 不适用，检查是否是 recursor iota reduction
    head_args = collect_app(t)
    head, args = head_args.args

    if isinstance(head, Const) and head.args in S.Recursors:
        rec_info = S.Recursors.get(head.args)

        if len(args) < 1:
            return t  # 至少需要一个 target

        # args 格式: [motive, case₁, case₂, ..., caseₙ, target]
        # 对 Bool: [motive, case_false, case_true, target]
        num_ctors = len(rec_info.constructors)
        expected_args = 2 + num_ctors  # motive + target + cases

        if len(args) != expected_args:
            return t  # 参数数量不对，不化简

        target = args[-1]
        target_whnf = whnf(S, target)

        if not isinstance(target_whnf, Const):
            return t  # target 不是 constructor，不化简

        ctor_name = target_whnf.args

        # 找到对应的构造子在 constructors 列表中的位置
        idx = None
        for j, ctor_info in enumerate(rec_info.constructors):
            if ctor_info.name == ctor_name:
                idx = j
                break

        if idx is None:
            return t  # ctor_name 不是这个 inductive 的构造子

        # cases 在 args 中的位置：1 + idx（跳过 motive）
        case_idx = 1 + idx
        return whnf(S, args[case_idx])

    return App(head, args[0]) if len(args) == 1 else t  # 处理一般 App
```

上面这个写法不太对——现有的 whnf 已经有一个 `App` 分支处理 beta reduction。合并后的逻辑应该是：在现有 `App` 分支中，beta reduction 检查在前，iota reduction 检查在后。

更准确的写法——修改现有的 §12.2 `App` 分支，插入 iota reduction：

```python
if isinstance(t, App):
    f, a = t.args
    f0 = whnf(S, f)

    if isinstance(f0, Lam):
        # beta reduction（不变）
        x, A, body = f0.args
        return whnf(S, subst(body, x, a))

    # iota reduction：检查 head 是否是 recursor     【v11 新增】
    head_args = collect_app(t)
    head, args = head_args.args

    if isinstance(head, Const) and head.args in S.Recursors:
        rec_info = S.Recursors.get(head.args)
        num_ctors = len(rec_info.constructors)
        if len(args) == 2 + num_ctors:   # [motive, case₁, ..., caseₙ, target]
            target = args[-1]
            target_whnf = whnf(S, target)

            if isinstance(target_whnf, Const):
                ctor_name = target_whnf.args
                for j, ctor_info in enumerate(rec_info.constructors):
                    if ctor_info.name == ctor_name:
                        return whnf(S, args[1 + j])  # 选择对应 case

    return App(f0, a)
```

**评论：**

- iota reduction 不硬编码任何特定 inductive 类型。它通过 `S.Recursors` 查找 recursor 对应的构造子列表，然后根据 target 是第几个构造子选择对应的 case。
- 对于 Bool：`collect_app((Const Bool.rec) motive case_false case_true target)` → `(Const Bool.rec, [motive, case_false, case_true, target])`。`S.Recursors.get(Bool.rec)` → `RecursorInfo(Bool.rec, Bool, [false, true])`。如果 `target_whnf = Const Bool.false`（构造子列表第 0 个），则取出 `args[1 + 0] = case_false`。
- iota reduction 检查 `target` 的 whnf 是否是 `Const`（即 constructor）。对于 nullary constructor（如 `Bool.false`），直接匹配 `Const Bool.false`。对于未来有参数的 constructor（如 `Nat.succ n`），`target_whnf` 的 head 需要是 `Const Nat.succ`，然后递归化简时需要把 constructor 的参数传递给 minor premise — 这留到后续版本处理。
- `len(args) == 2 + num_ctors` 这个条件检查是否每个构造子有一个 case + motive 占一个位置。注意 iota reduction 要求 recursor **完全应用** — 如果少了某个 case，不化简。
- 如果 target whnf 后不是已知 constructor（比如是一个变量），不化简 — 这和 `Proj` 规则的行为一致。

### 12.4 其他情况 → 12.5

与 v10 相同（原来的 12.4 重新编号为 12.5）。

### 12.5 `whnf` 完整代码                                         【v11 修改】

```python
# 写作 whnf(S, t)
def whnf(S : State, t : CoreTerm) -> CoreTerm:
    '''
    把 t 化简到 weak head normal form。
    处理：delta 展开（Const）、beta reduction（App）、
    Proj 结构投影化简、recursor iota reduction（App）。                      【v11 新增】
    '''

    if isinstance(t, Const):
        n = t.args
        if n in S.Defs:
            A, body = S.Defs.get(n)
            return whnf(S, body)
        return t

    if isinstance(t, App):
        f, a = t.args
        f0 = whnf(S, f)

        if isinstance(f0, Lam):
            x, A, body = f0.args
            return whnf(S, subst(body, x, a))

        # iota reduction：检查 head 是否是 recursor       【v11 新增】
        head_args = collect_app(t)
        head, args = head_args.args

        if isinstance(head, Const) and head.args in S.Recursors:
            rec_info = S.Recursors.get(head.args)
            num_ctors = len(rec_info.constructors)
            if len(args) == 2 + num_ctors:  # [motive, case1, ..., caseN, target]
                target_whnf = whnf(S, args[-1])
                if isinstance(target_whnf, Const):
                    for j, ctor_info in enumerate(rec_info.constructors):
                        if ctor_info.name == target_whnf.args:
                            return whnf(S, args[1 + j])

        return App(f0, a)

    if isinstance(t, Proj):
        # 与 v10 完全相同
        structName, index, target = t.args
        target0 = whnf(S, target)

        info = S.Structures.get(structName)
        if info is None:
            return Proj(structName, index, target0)

        if index >= len(info.fields):
            raise Error

        head_args = collect_app(target0)
        head, args = head_args.args

        if isinstance(head, Const) and head.args == info.constructor:
            expected_arity = len(info.params) + len(info.fields)
            if len(args) != expected_arity:
                return Proj(structName, index, target0)
            field_pos = len(info.params) + index
            return whnf(S, args[field_pos])

        return Proj(structName, index, target0)

    return t
```

**评论：** `whnf` 现在有四类计算：Const delta、App beta、recursor iota、Proj 结构投影。递归子 iota 和结构投影的机制类似 — 都通过查询 State 中的元信息（`Recursors` / `Structures`）来驱动，不硬编码任何特定类型。

---
## 12a. 辅助函数（结构投影层面）

与 v10 完全相同。`subst_many`、`match_structure_type`、`projection_type` 不受 v11 影响。

## 13–14. defeq / infer_type / check_type

与 v10 完全相同。v11 不改这些函数。

**评论：** `infer_type` 和 `check_type` 不需要修改 — `Bool`、`Bool.false`、`Bool.true`、`Bool.rec` 都通过 Axioms 注册到 `S.Axioms`，`Const` 规则自动从 `S.Axioms` 获取类型。`Bool.rec` 的应用通过 `App` 规则链式推断类型。iota reduction 发生在 `whnf` 层面，`defeq` 通过调用 `whnf` 自然得到 iota reduction 的收益。

---
## 15. 构建前置状态 `S`

v11 的前置状态 S 在 v10 的 S 基础上，额外执行 InductiveCmd Bool：

```text
S  = v10 中构建的状态（包含 Sigma, Prod, Nat, zero, Pred, choosePred）

S' = exec(S, InductiveCmd Bool
  constructors = [false : Bool, true : Bool])

S_v11 = S'
```

因此在 `S_v11` 中：

```text
S_v11.Axioms 在 S.Axioms 基础上新增：
  Bool       : Sort (level 0)
  Bool.false : Const Bool
  Bool.true  : Const Bool
  Bool.rec   : ...（由 make_recursor_type 自动生成）

S_v11.Inductives = {
  Bool : InductiveInfo(Bool, [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ], Bool.rec)
}

S_v11.Recursors = {
  Bool.rec : RecursorInfo(Bool.rec, Bool, [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ])
}
```

后续的 §18–§21 例子基于 `S_v11`（或 `S`，当不需要 Bool 时）。

---
## 15b. InductiveCmd 例子                                       【v11 新增】

### 15b.5 InductiveCmd Bool — v11 的核心例子

**输入：**

```text
cmd = InductiveCmd Bool
  constructors = [
    ConstructorDecl(false, []),
    ConstructorDecl(true, [])
  ]
```

即用户声明：`inductive Bool where | false : Bool | true : Bool`

**执行过程（在从 v10 继承的状态 S 中）：**

**第一步：名字检查**

```text
Bool ∉ S.Axioms     ✓
Bool.false ∉ S.Axioms ✓
Bool.true ∉ S.Axioms  ✓
Bool.rec ∉ S.Axioms    ✓
```

**第二步：Telescope 检查**

两个构造子都是 nullary（args=[]），telescope 检查直接通过。

**第三步：类型生成**

```text
ctor_infos = [
  ConstructorInfo(Bool.false, []),
  ConstructorInfo(Bool.true, [])
]

info = InductiveInfo(Bool, [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ], Bool.rec)
rec_info = RecursorInfo(Bool.rec, Bool, [
    ConstructorInfo(Bool.false, []),
    ConstructorInfo(Bool.true, [])
  ])
```

`type_type = Sort(level 0)` → `Bool : Sort 0` ✓

构造子类型：两个都是 `Const Bool` → `Bool.false : Bool, Bool.true : Bool` ✓

recursor 类型由 `make_recursor_type` 生成：

```text
Bool.rec :
  Π (motive : Π (_ : Bool), Sort 0),
  Π (case_false : motive Bool.false),
  Π (case_true  : motive Bool.true),
  Π (b : Bool),
    motive b
```

**第四步：状态更新**

```text
S' = S
S'.Axioms 加入 Bool, Bool.false, Bool.true, Bool.rec 的声明
S'.Inductives 加入 Bool ↦ InductiveInfo(...)
S'.Recursors 加入 Bool.rec ↦ RecursorInfo(...)
```

**验证：** 执行后：
- `Const Bool` 的类型可以通过 `infer_type` 推断 ✓
- `Const Bool.false` 的类型可以通过 `infer_type` 推断（→ `Bool`）✓
- `Const Bool.true` 的类型可以通过 `infer_type` 推断（→ `Bool`）✓
- `Const Bool.rec` 的类型可以通过 `infer_type` 推断 ✓
- `Bool.rec` 应用到构造子的 iota reduction 可以工作 ✓（见 §19.7）

**评论：** 这是 v11 最核心的例子 — 用 `InductiveCmd` 声明一个有两个 nullary 构造子的 inductive 类型，`exec` 自动生成 recursor 类型和元信息。整个过程中 `CoreTerm` 不变、`infer_type` 不变、`defeq` 不变 — 只有 `whnf` 新增了 iota reduction。这遵循了 v7-v10 一贯的"扩展 State 和 Command、不扩展 CoreTerm"原则。

---
## 15a. `elab`：从 SurfaceTerm 到 CoreTerm

与 v10 完全相同。v11 不改 `elab`。

构造子在 surface 层的写法：用户写 `SConst Bool.false`，elaborate 后得到 `Const Bool.false`。recursor 同理：`SConst Bool.rec` → `Const Bool.rec`。后续版本的 `SMatch` 会新增专门的 elab 分支。

---
## 16–18

与 v10 完全相同。

## 19. `whnf` 例子

### 19.1–19.6 beta reduction / Proj / Prod / Point 例子

与 v10 完全相同。

### 19.7 Bool.rec iota reduction 例子                            【v11 新增】

**前置状态：** `S_v11`（§15）。

定义 `not` 函数（通过 DefCmd）：

```text
S'' = exec(S_v11, DefCmd not
  (SForall(b, SConst Bool, SConst Bool))
  (SLam(b, SConst Bool,
    SApp(SApp(SApp(SApp(SConst Bool.rec,
      SLam(_, SConst Bool, SConst Bool)),
      SConst Bool.true),
      SConst Bool.false),
    SVar b))))
```

elab 后，`not` 的 body 是：

```text
not_body =
  Lam(b, Const Bool,
    (Const Bool.rec)
      (Lam(_, Const Bool, Const Bool))
      (Const Bool.true)
      (Const Bool.false)
      (Var b)
  )
```

即 `not = λ b. Bool.rec (λ_.Bool) true false b`。

**例子 1：`not false`**

```text
whnf(S'', App(Const not, Const Bool.false))
```

1. `Const not` delta 展开 → `not_body`（Lambda）
2. App beta reduction → `subst(rec_app, b, Const Bool.false)`
3. = `(Const Bool.rec) (Lam(_, Const Bool, Const Bool)) (Const Bool.true) (Const Bool.false) (Const Bool.false)`
4. Iota reduction：`S.Recursors.get(Bool.rec)` → `RecursorInfo(Bool.rec, Bool, [false, true])`
5. target = `Const Bool.false`，whnf 后不变
6. `Bool.false` 是 constructors 列表中的第 0 个
7. 返回 `whnf(S'', Const Bool.true)` = `Const Bool.true` ✓

**例子 2：`not true`**

```text
whnf(S'', App(Const not, Const Bool.true))
```

1–2. 同上，得到 `(Const Bool.rec) motive true false Bool.true`
3. target = `Const Bool.true`，是第 1 个构造子
4. 返回 `Const Bool.false` ✓

**评论：** 这两个例子验证了 v11 的完整流程：
1. `DefCmd` 注册 `not` — 使用 delta reduction
2. `App(Const not, Const Bool.false)` — delta 展开 + beta reduction
3. `Bool.rec` 应用到 `Bool.false` — iota reduction 选择 `case_false`
4. 最终得到 `Bool.true`

### 19.8 Bool.rec 不在已知 recursor 中时不化简                  【v11 新增】

如果 recursor 名不在 `S.Recursors` 中（或者 target 不是 constructor），iota reduction 不触发 — recursor 应用保持不变。这与 `Proj` 遇到不认识的 `structName` 时的行为一致。

---
## 20. `defeq` 例子

### 20.1–20.5

与 v10 完全相同。

### 20.6 `not false` 与 `true` 定义相等                           【v11 新增】

**前置状态：** `S''`（包含 `not` 的 def）。

```text
defeq(S'', ∅, App(Const not, Const Bool.false), Const Bool.true)
```

1. 两边 whnf。左边 whnf → `Const Bool.true`（§19.7 已证）。右边 whnf → `Const Bool.true`（Bool.true 是 axiom）。
2. 两边相同 ✓

**结论：** `defeq` 返回 `True`。这意味着 `check_type(S'', ∅, App(Const not, Const Bool.false), Const Bool)` 也会成功（因为 `true` 和 `not false` 类型相同且定义相等）。`defeq` 通过 `whnf` 的 iota reduction 发现了 `not false = true`。

---
## 21. `elab` 例子

### 21.1–21.6

与 v10 完全相同。

### 21.7 使用 Bool.rec 定义 `not`（elab 层面）                    【v11 新增】

用户写的 surface term（在 DefCmd 中）：

```text
SLam(b, SConst Bool,
  SApp(SApp(SApp(SApp(SConst Bool.rec,
    SLam(_, SConst Bool, SConst Bool)),
    SConst Bool.true),
    SConst Bool.false),
  SVar b))
```

elab 过程：

1. 最外层 `SLam` → `Lam(b, Bool, body_c)`，其中 body_c 是内部 applicaton 的 elab 结果
2. 最内层是 `SApp(SConst Bool.rec, ...)` → elab `SConst Bool.rec` → `Const Bool.rec`；`infer_type` 获取 `Bool.rec` 的类型；然后逐层 App elab

最终得到 core term：

```text
Lam(b, Const Bool,
  (Const Bool.rec)
    (Lam(_, Const Bool, Const Bool))
    (Const Bool.true)
    (Const Bool.false)
    (Var b)
)
```

**评论：** v11 没有 `SMatch`，所以用户（在 SurfaceTerm 层面）直接写 `Bool.rec` 的显式应用。这和 v10 中用户直接写 `Proj(Sigma, 0, ...)` 而不是高层的 `p.x` 类似 — 高层的语法糖（SMatch）是后续版本的工作。当前的重点是验证 `Bool.rec` 的类型推断正确、iota reduction 正确。

---
## 22. 当前阶段的边界                                         【v11 修改】

当前阶段，模型包含：

```text
SurfaceTerm 构造子：SConst, SSort, SVar, SApp, SLam, SForall, SSigma, SPair, SFst, SSnd, SProj, SDot, SAnn
  （13 个构造子，v11 不变）

CoreTerm 构造子：Const, Sort, Var, App, Lam, Forall, Proj
  （7 个构造子，v11 不变）

数据类型：ParamDecl, FieldDecl, ConstructorDecl, ParamInfo, FieldInfo, ConstructorInfo,
          ProjectionInfo, StructureInfo, InductiveInfo, RecursorInfo                  【v11 新增 ConstructorDecl, ConstructorInfo, InductiveInfo, RecursorInfo】

Command 构造子：AxiomCmd, DefCmd, StructureCmd, InductiveCmd                          【v11 新增 InductiveCmd】

State 字段：Axioms, Defs, Structures, Projections, Inductives, Recursors              【v11 新增 Inductives, Recursors】

函数：FV(CoreTerm), subst(CoreTerm), subst_many, exec, infer_type, check_type, whnf, defeq, elab, elab_raw,
      is_sigma_type, collect_app, match_structure_type, projection_type,
      make_forall_chain, make_type_app, make_structure_type, make_constructor_type,
      make_motive_type, make_recursor_type                                             【v11 新增 2 个 recursor 类型生成函数】
```

类型系统特性：

```text
Surface/Core 分层
elaboration（SurfaceTerm → CoreTerm，携带 expected type）
bidirectional typing（infer / check）on CoreTerm
whnf（弱头部正规化）on CoreTerm — 包括 delta, beta, Proj 结构投影, recursor iota reduction  【v11 新增 iota】
definitional equality（alpha-renaming + reduction + 递归比较）on CoreTerm
conversion-based checking（check_type 用 defeq）on CoreTerm
StructureInfo + Proj（结构信息 + 一般投影）
StructureCmd（用户声明新结构）
ProjectionInfo + SProj/SDot（投影名 + 投影语法）
InductiveInfo + RecursorInfo + InductiveCmd（inductive 类型 + recursor + iota reduction）    【v11 新增】
```

计算规则：

```text
Proj(structName, index, (Const constructor) params... fields...) → fields[index]
App(Lam(x, A, body), a) → body[x := a]
Const defName → body（delta 展开）
(Const recName) motive case₁ ... caseₙ (Const ctor_i) → case_i（iota reduction）       【v11 新增】
```

**v11 的关键进展：** **InductiveCmd 让用户可以声明 inductive 类型（当前支持 nullary constructors）。exec 自动生成构造子类型、recursor 类型（`make_recursor_type`）、InductiveInfo 和 RecursorInfo。CoreTerm 不变 — 构造子和 recursor 都是 `Const`，它们的应用是 `App` 链。Kernel 层只在 `whnf` 新增 iota reduction — `infer_type`、`check_type`、`defeq` 无需修改。**

尚未加入：

```text
eta 规则
proof irrelevance
universe constraints / level metavariable
reducibility control（opaque / semireducible）
de Bruijn index / fvar
universe polymorphism
implicit arguments
anonymous constructor for custom structures
recursive structures
Method B：投影名作为全局常量
real Lean Expr
SMatch（match ... with ... 的 surface 语法）— v11 用户直接写 recursor 应用
recursive constructors（如 succ : Nat → Nat）— 下一版（v12）
indexed inductive（如 Eq）— 后续版本
parametric inductive（如 List (A : Type)）— 后续版本
large elimination 限制
auto-generation of recursor with minor premises for recursive arguments
```

v11 的定位：

> v11 的核心进展是"从 Structure 到 Inductive 的跨越" — 从单构造子（structure）到多构造子（inductive），从投影（projection）到递归消除（recursor），从 Proj 化简到 iota reduction。
>
> Kernel 层只有 `whnf` 新增 iota reduction；
> State 层新增 Inductives 和 Recursors；
> exec 层新增 InductiveCmd 分支；
> CoreTerm 不变（7 个构造子）。
> 当前以 Bool（两个 nullary 构造子）为核心例子。构造子均为 nullary，暂不支持递归构造子和参数化 inductive。

v11 是后续递归 inductive（Nat）和 indexed inductive（Eq）的基石 — 它建立了 `InductiveCmd → RecursorInfo → iota reduction` 这条完整管线。
