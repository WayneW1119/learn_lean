# model v6

> 本文档在 v5 基础上扩展。
>
> **相对于 v5 的变化：**
>
> * §3-4：`Term` 拆分为 `SurfaceTerm`（表层）和 `CoreTerm`（核心）
> * `Ann` 从 CoreTerm 中移除，只在 SurfaceTerm 中保留为 `SAnn`
> * 裸 `Pair` 从 CoreTerm 中移除，替换为 `CPairTyped(x, A, B, a, b)`（携带 Σ 类型信息）
> * §7：`exec` 调用 `elab` 把 SurfaceTerm 转换为 CoreTerm
> * §9-14：所有 kernel 函数（HasType、FV、subst、whnf、defeq、infer/check）只作用于 CoreTerm
> * §15a：新增 `elab` 函数（Surface → Core）
> * §21：新增 `elab` 例子
> * §23：更新边界说明
>
> **记号约定：** 本文档中有时使用"令 X = ..."或"简记 X 为 ..."。这是**文本层面的临时缩写**，不是模型中的操作。模型中没有"令"或"赋值"的概念 — State 的修改只能通过 `exec` 执行命令来完成。
>
> **命名约定（v6 新增）：** v6 有两种 term 类型：
> - `SurfaceTerm` 的构造子以 `S` 为前缀（`SConst`、`SApp`、`SAnn` 等）
> - `CoreTerm` 的构造子以 `C` 为前缀（`CConst`、`CApp`、`CPairTyped` 等）
>
> 在不引起歧义时，"写作"格式省略前缀 — 例如 `Const Nat` 既可以表示 `SConst Nat` 也可以表示 `CConst Nat`，具体含义由上下文决定。
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
- 语法对象类型（如 `Term`、`Command`）用**代数数据类型**风格定义。
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
- v6 引入了两种 term 类型：**SurfaceTerm** 和 **CoreTerm**。
  - SurfaceTerm 代表用户/表层可以写的东西（包括 `SAnn`、`SPair` 等）。
  - CoreTerm 代表 elaboration 后、交给 kernel 的核心 term（`Ann` 不在其中，`Pair` 被替换为 `CPairTyped`）。
  - 所有 kernel 函数（`infer_type`、`check_type`、`whnf`、`defeq`、`FV`、`subst`）只作用于 CoreTerm。
  - `elab` 函数负责把 SurfaceTerm 转换为 CoreTerm。
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
## 3. Term 的两个层次                                               【v6 新增】

v5 使用单一的 `Term` 类型。v6 将其拆分为两层：

- **SurfaceTerm**：用户在表层语法中写的东西。包括 `SAnn`（类型标注）和 `SPair`（匿名 pair）。
- **CoreTerm**：elaboration 后交给 kernel 的核心 term。`Ann` 不在其中，裸 `Pair` 被替换为携带类型信息的 `CPairTyped`。

```text
SurfaceTerm                CoreTerm
用户写的东西          →     kernel 检查的东西
                           (via elab)
SConst/SVar/SSort         CConst/CVar/CSort
SApp                       CApp
SLam                       CLam
SForall                    CForall
SSigma                     CSigma
SPair  ──────────────→    CPairTyped(x, A, B, a, b)
SFst/SSnd                  CFst/CSnd
SAnn  ──────────────→    (消失，传递 expected type 给 elab)
```

### 3.1 `SurfaceTerm`

定义数据类型 `SurfaceTerm`：

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
            | SAnn(t : SurfaceTerm, A : SurfaceTerm)     # 写作 (t : A)
```

**评论：** `SurfaceTerm` 与 v5 的 `Term` 几乎完全相同，只是构造子加了 `S` 前缀。`SAnn` 和 `SPair` 保留在表层 — 用户确实可以写 `(t : A)` 和 `⟨a, b⟩`。但它们不会直接进入 kernel。

### 3.2 `CoreTerm`

定义数据类型 `CoreTerm`：

```text
CoreTerm = CConst(name : GlobalName)                    # 写作 Const name
         | CSort(level : Level)                         # 写作 Sort level
         | CVar(name : LocalName)                       # 写作 Var name
         | CApp(fn : CoreTerm, arg : CoreTerm)          # 写作 fn arg
         | CLam(x : LocalName, A : CoreTerm, body : CoreTerm)   # 写作 fun (x : A) => body
         | CForall(x : LocalName, A : CoreTerm, B : CoreTerm)   # 写作 Π (x : A), B
         | CSigma(x : LocalName, A : CoreTerm, B : CoreTerm)    # 写作 Σ (x : A), B
         | CPairTyped(x : LocalName, A : CoreTerm, B : CoreTerm, a : CoreTerm, b : CoreTerm)
         | CFst(t : CoreTerm)                           # 写作 fst t
         | CSnd(t : CoreTerm)                           # 写作 snd t
```

`CPairTyped` 写作 `⟨a, b⟩ : Σ (x : A), B`（即携带 Σ 类型信息的 pair）。

**评论：**

- **Ann 不在 CoreTerm 中。** `SAnn(t, A)` 在 elaboration 时被消耗 — 它把 `A` 作为 expected type 传给 `t` 的 elaboration，自身不出现在输出的 CoreTerm 中。这兑现了 v3 文档中"Ann 是 elaboration-level 构造"的设计承诺。
- **裸 `Pair` 不在 CoreTerm 中。** v5 的 `Pair(a, b)` 不能 infer 类型 — 它不知道自己的 Σ 类型是什么。v6 用 `CPairTyped(x, A, B, a, b)` 替代：elaboration 时把 Σ 类型信息填进去，这样 kernel 的 `infer_type` 就能直接返回 `CSigma(x, A, B)`。
- **`CPairTyped` 是 `Sigma.mk` 的前身。** 在 v7 中，当引入 inductive type 声明机制后，`CPairTyped(x, A, B, a, b)` 可以改写为 `CtorApp(Sigma.mk, [A, B, a, b])`。当前阶段先保留为显式构造子。
- **`CSigma`、`CFst`、`CSnd` 暂时保留。** v7 会把它们环境化为 inductive type + primitive projection。

因此：

```text
若 x : LocalName, A : CoreTerm, B : CoreTerm, a : CoreTerm, b : CoreTerm
则 CPairTyped(x, A, B, a, b) : CoreTerm
```

### 3.3 例子

先假设：

```text
Nat, f : GlobalName
x, y  : LocalName
```

SurfaceTerm 例子：

```text
SConst Nat                    -- 表层全局常量
SApp(SConst f, SVar x)        -- 表层应用
SPair(SConst zero, SConst zero)  -- 表层 pair
SAnn(SConst zero, SConst Nat)    -- 表层类型标注
```

CoreTerm 例子：

```text
CConst Nat                    -- 核心全局常量
CApp(CConst f, CVar x)        -- 核心应用
CPairTyped(x, CConst Nat, CConst Nat, CConst zero, CConst zero)
                              -- 核心 pair（携带 Σ 类型）
CSigma(x, CConst Nat, CConst Nat)
                              -- 核心 Σ 类型
```

注意：CoreTerm 中没有 `Ann`，也没有裸 `Pair`。
---
## 4. `State`                                                【v6 修改】
定义状态类型 `State`：
```text
class State:
    Axioms : PartialMap[g : GlobalName, t : CoreTerm]                 # 写作 g : t
    Defs   : PartialMap[g : GlobalName, Pair[t1 : CoreTerm, t2 : CoreTerm]]  # 写作 g : (t1, t2)
```
若 `S : State`，则：
```text
S.Axioms
S.Defs
```
分别表示该状态中的两个字段。
其中：
- 若 `S.Axioms.get(n) = A`，则表示：
  在当前状态 `S` 中，全局名字 `n` 被声明为一个 `axiom`，其 type 是 `A : CoreTerm`。
- 若 `S.Defs.get(n) = Pair(A, t)`，则表示：
  在当前状态 `S` 中，全局名字 `n` 被声明为一个 `def`，其 type 是 `A : CoreTerm`，body 是 `t : CoreTerm`。
---
## 5. 顶层命令 `Command`                                      【v6 修改】
定义数据类型 `Command`：
```text
Command = AxiomCmd(name : GlobalName, term : SurfaceTerm)             # 写作 AxiomCmd n : A
        | DefCmd(name : GlobalName, term1 : SurfaceTerm, term2 : SurfaceTerm) # 写作 DefCmd n A t
```
也就是说：
```text
AxiomCmd(n, A)     写作 AxiomCmd n : A
DefCmd(n, A, t)    写作 DefCmd n A t
```

用户写 SurfaceTerm；exec 会先通过 elab 转换为 CoreTerm 再存储。
---
## 6. 状态执行函数 `exec`                                   【v6 修改】
定义一个部分函数：
```text
exec(S : State, cmd : Command) -> State
```
写作：
```text
exec(S, cmd)
```
它的含义是：
- 输入当前状态 `S`
- 输入一个顶层命令 `cmd`
- 若该命令在 `S` 下可执行，则返回新状态 `S'`
- 若前置条件不满足，则 `exec(S, cmd)` 不定义
### 6.1 状态转移记号
约定：
```text
S --cmd--> S'
```
作为下面式子的简写：
```text
exec(S, cmd) = S'
```
### 6.2 规则 1：执行 `AxiomCmd`
若：
```text
cmd = AxiomCmd(n, A_surf)
A_core = elab(S, ∅, A_surf, None)
not S.Axioms.contains(n)
not S.Defs.contains(n)
```
则：
```text
exec(S, cmd) = S'
```
其中：
```text
S' = State(
    Axioms = S.Axioms.set(n, A_core),
    Defs   = S.Defs
)
```
### 6.3 规则 2：执行 `DefCmd`
若：
```text
cmd = DefCmd(n, A_surf, t_surf)
A_core = elab(S, ∅, A_surf, None)
t_core = elab(S, ∅, t_surf, A_core)
not S.Axioms.contains(n)
not S.Defs.contains(n)
check_type(S, ∅, t_core, A_core)
```
则：
```text
exec(S, cmd) = S'
```
其中：
```text
S' = State(
    Axioms = S.Axioms,
    Defs   = S.Defs.set(n, Pair(A_core, t_core))
)
```
### 6.4 `exec` 代码
```python
# 写作 exec(S, cmd)
def exec(S: State, cmd: Command) -> State:
    '''
    执行顶层命令并返回更新后的状态。
    v6：Command 中的 term 是 SurfaceTerm，需要先通过 elab 转换为 CoreTerm。
    '''

    if isinstance(cmd, AxiomCmd):
        n, A_surf = cmd.args        # cmd = AxiomCmd n : A_surf
        A_core = elab(S, ∅, A_surf, None)
        if n not in S.Axioms and n not in S.Defs:
            return State(
                Axioms = S.Axioms.set(n, A_core),
                Defs   = S.Defs
            )
        raise Error


    elif isinstance(cmd, DefCmd):
        n, A_surf, t_surf = cmd.args     # cmd = DefCmd n A_surf t_surf
        A_core = elab(S, ∅, A_surf, None)
        t_core = elab(S, ∅, t_surf, A_core)
        if n in S.Axioms or n in S.Defs:
            raise Error
        if not check_type(S, ∅, t_core, A_core):
            raise Error
        return State(
            Axioms = S.Axioms,
            Defs   = S.Defs.set(n, Pair(A_core, t_core))
        )


    raise Error
```

`elab` 在 §15a 定义。概念上 elaboration 在 kernel 检查之前，但因为 `elab` 内部调用 `infer_type` 和 `check_type`，它必须在它们之后定义。
---
## 7. `Context`                                               【v6 修改】
定义上下文类型 `Context`：
```text
class Context:
    Types : PartialMap[n : LocalName, t : CoreTerm]   # 写作 n : t
```
若 `Γ : Context`，则：
```text
Γ.Types
```
表示这个上下文中记录局部变量类型的那个映射。
其中：
- 若 `Γ.Types.get(x) = A`，则表示：
  在当前局部上下文 `Γ` 中，局部变量 `x` 的类型是 `A : CoreTerm`。
### 7.1 上下文扩展
定义函数：
```python
# 写作 Γ, x : A
# 也写作 expand_context(Γ, x, A)
def expand_context(Γ : Context, x : LocalName, A : CoreTerm) -> Context:
    return Context(
        Types = Γ.Types[x -> A]
    )
```
因此：
```text
expand_context(Γ, x, A)   写作 Γ, x : A
```
---
## 8. typing judgment                                               【v6 修改】
定义一个四元判断 `HasType`：
```text
HasType ⊆ State × Context × CoreTerm × CoreTerm
```
约定：
```text
S ; Γ ⊢ t : A
```
是：
```text
(S, Γ, t, A) ∈ HasType
```
的简写。
其中：
- `S : State`
- `Γ : Context`
- `t : CoreTerm`
- `A : CoreTerm`
它表示：
> 在状态 `S` 和局部上下文 `Γ` 下，term `t` 的类型是 `A`。
---
## 9. `HasType` 的具体定义                                             【v6 修改】
`HasType` 是 `State × Context × CoreTerm × CoreTerm` 的最小子集，满足以下规则。
### 9.1 基本 typing 规则
- Var 规则
  若：
```text
Γ.Types.get(x) = A
```
则：
```text
S ; Γ ⊢ CVar x : A
```
- Const-axiom 规则
  若：
```text
S.Axioms.get(n) = A
```
则：
```text
S ; Γ ⊢ CConst n : A
```
- Const-def 规则
  若：
```text
S.Defs.get(n) = Pair(A, t)
```
则：
```text
S ; Γ ⊢ CConst n : A
```
### 9.2 `Sort / Π / fun / App` 规则                             【v6 修改】
- Sort 规则
  若：
```text
v = succ_level(u)
```
则：
```text
S ; Γ ⊢ CSort u : CSort v
```
- Forall 规则
  若：
```text
S ; Γ ⊢ A : CSort u
S ; (Γ, x : A) ⊢ B : CSort v
```
则：
```text
S ; Γ ⊢ CForall(x, A, B) : CSort (max_level(u, v))
```
- Lam 规则
  若：
```text
S ; Γ ⊢ A : CSort u
S ; (Γ, x : A) ⊢ t : B
S ; (Γ, x : A) ⊢ B : CSort v
```
则：
```text
S ; Γ ⊢ CLam(x, A, t) : CForall(x, A, B)
```
- App 规则
  若：
```text
S ; Γ ⊢ f : CForall(x, A, B)
S ; Γ ⊢ a : A
```
则：
```text
S ; Γ ⊢ CApp(f, a) : B[x := a]
```
其中：
```text
B[x := a]
```
表示：
```text
subst(B, x, a)
```
### 9.3 `CSigma` 规则                                             【v6 修改】
- CSigma 规则（formation rule）
  若：
```text
S ; Γ ⊢ A : CSort u
S ; (Γ, x : A) ⊢ B : CSort v
```
则：
```text
S ; Γ ⊢ CSigma(x, A, B) : CSort (max_level(u, v))
```
**评论：** 这条规则和 `CForall` 的 formation 规则完全平行。它说明了 `CSigma(x,A), B` 本身是一个 type，居于 `CSort (max_level(u, v))`。
### 9.4 `CPairTyped` 规则                                          【v6 修改】
- CPairTyped 规则（introduction rule）
  若：
```text
S ; Γ ⊢ a : A
S ; Γ ⊢ b : B[x := a]
```
则：
```text
S ; Γ ⊢ CPairTyped(x, A, B, a, b) : CSigma(x, A, B)
```
**评论：**
- 这是 `CSigma` 的 introduction rule — 它告诉我们**如何构造**一个 `CSigma(x,A), B` 类型的元素。
- 注意第二个前提：`b` 的类型不是 `B`，而是 `B[x := a]`。因为 `B` 中可能含有对 `x` 的引用，而 `x` 的值现在是 `a`，所以必须把 `x` 替换成 `a`。这正是"依值"的含义。
- v6 中 `CPairTyped` 携带了完整的 Σ 类型信息（`x`, `A`, `B`），因此可以 infer 类型（返回 `CSigma(x, A, B)`），不需要像 v5 的裸 `Pair` 那样只能 check。详见 §14。

### 9.5 `CFst` / `CSnd` 规则                                       【v6 修改】

- CFst 规则（elimination rule — 第一投影）
  若：

```text
S ; Γ ⊢ t : CSigma(x, A, B)
```

则：

```text
S ; Γ ⊢ CFst(t) : A
```

- CSnd 规则（elimination rule — 第二投影）
  若：

```text
S ; Γ ⊢ t : CSigma(x, A, B)
```

则：

```text
S ; Γ ⊢ CSnd(t) : B[x := CFst(t)]
```

**评论：**

- 这两条是 `CSigma` 的 **elimination rules** — 它们告诉我们**如何使用**一个 `CSigma(x:A), B` 类型的元素。
- `CFst` 的类型直接是 `A`，很直观。
- `CSnd` 的类型是 `B[x := CFst(t)]`，不是 `B`。这是因为 `B` 中含有对 `x` 的引用，而 `x` 的值是 `t` 的第一分量 `CFst(t)`，所以必须替换。
- 注意 `CFst(t)` 出现在 `CSnd(t)` 的类型的替换结果中 — 这形成了一种**自引用**：`CSnd(t)` 的类型依赖于 `CFst(t)`。这正是依值对子的消除规则的核心特征。

### 9.6 `Ann` 规则                                                 【v6 修改】

`Ann` 已不再是 CoreTerm 的构造子。类型标注在表层由 `SAnn` 处理，elaboration 时 `SAnn(t, A)` 把 `A` 作为 expected type 传递给 `t` 的 elaboration，自身不出现在 CoreTerm 中。详见 §15a.6。

### 9.7 `Conversion` 规则                                            【v6 修改】

- Conversion 规则（类型转换）
  若：

```text
S ; Γ ⊢ t : A
S ; Γ ⊢ B : CSort u
defeq(S, Γ, A, B) = True
```

则：

```text
S ; Γ ⊢ t : B
```

**评论：**

- 这是 type theory 中的标准 **conversion rule**。它说的是：如果 `t` 有类型 `A`，而 `A` 和 `B` 是 definitionally equal 的类型，那么 `t` 也可以被看作有类型 `B`。
- 在实现层面，我们不直接用这条规则 — 而是通过修改 `check_type` 的默认分支，把 `==` 替换成 `defeq`（见 §14）。
- `defeq` 是 definitional equality 的缩写。它比结构相等更宽松：不仅允许 alpha-renaming，还允许通过 reduction（beta、delta、CFst/CSnd 投影）产生的相等。v6 中不再有 Ann 擦除（CoreTerm 中没有 Ann）。

---
## 10. `FV`                                                          【v6 修改】
定义函数：
```python
# 写作 FV(t)
def FV(t : CoreTerm) -> Set[LocalName]:
    if isinstance(t, CConst):
        return ∅


    if isinstance(t, CSort):
        return ∅


    if isinstance(t, CVar):
        x = t.args              # t = CVar x
        return {x}


    if isinstance(t, CApp):
        f, a = t.args           # t = CApp(f, a)
        return FV(f) ∪ FV(a)


    if isinstance(t, CLam):
        x, A, body = t.args     # t = CLam(x, A, body)
        return FV(A) ∪ (FV(body) \ {x})


    if isinstance(t, CForall):
        x, A, B = t.args        # t = CForall(x, A, B)
        return FV(A) ∪ (FV(B) \ {x})


    if isinstance(t, CSigma):
        x, A, B = t.args        # t = CSigma(x, A, B)
        return FV(A) ∪ (FV(B) \ {x})


    if isinstance(t, CPairTyped):
        x, A, B, a, b = t.args  # t = CPairTyped(x, A, B, a, b)
        return FV(A) ∪ (FV(B) \ {x}) ∪ FV(a) ∪ FV(b)

    if isinstance(t, CFst):
        t1 = t.args               # t = CFst(t1)
        return FV(t1)

    if isinstance(t, CSnd):
        t1 = t.args               # t = CSnd(t1)
        return FV(t1)
```
### 10.1 例子

```text
FV(CConst Nat) = ∅
FV(CVar x) = {x}
FV(CApp(CVar x, CVar y)) = {x, y}
FV(CLam(x, CSort(level 0), CVar x)) = ∅
FV(CForall(x, CSort(level 0), CVar x)) = ∅
FV(CSigma(x, CConst Nat, CApp(CVar f, CVar x))) = {f}
FV(CPairTyped(x, CConst Nat, CConst Nat, CVar x, CVar y)) = {x, y}
FV(CFst(CVar x)) = {x}
FV(CSnd(CPairTyped(x, CConst Nat, CConst Nat, CVar x, CVar y))) = {x, y}
```

**评论：** `CFst` 和 `CSnd` 的 FV 和输入 term 的 FV 相同 — 因为 `CFst(t)` 和 `CSnd(t)` 只包含一个子 term，没有 binder。`CPairTyped` 的 FV 包含四个子部分：`A` 的自由变量、`B` 中除去 binder `x` 的自由变量、以及 `a` 和 `b` 的自由变量。`CPairTyped` 有 binder `x`（在 `B` 中），所以 `B` 的自由变量需要除去 `{x}`，和 `CForall`/`CSigma`/`CLam` 的处理方式一致。
---
## 11. substitution                                                  【v6 修改】
定义函数：
```python
# 写作 subst(t, x, e)
# 也写作 t[x := e]
def subst(t: CoreTerm, x: LocalName, e: CoreTerm) -> CoreTerm:
    '''
    在 t 中，把自由出现的 x 替换为 e
    '''


    if isinstance(t, CConst):
        return t


    if isinstance(t, CSort):
        return t


    if isinstance(t, CVar):
        y = t.args              # t = CVar y
        if y == x:
            return e
        return t


    if isinstance(t, CApp):
        f, a = t.args           # t = CApp(f, a)
        return CApp(
            subst(f, x, e),
            subst(a, x, e)
        )


    if isinstance(t, CLam):
        y, A, body = t.args     # t = CLam(y, A, body)


        A1 = subst(A, x, e)


        if y == x:
            return CLam(y, A1, body)


        if y not in FV(e):
            return CLam(
                y,
                A1,
                subst(body, x, e)
            )


        z = fresh_local_name(FV(body) ∪ FV(e) ∪ {x, y})
        body1 = alpha_rename_binder(body, y, z)
        return CLam(
            z,
            A1,
            subst(body1, x, e)
        )


    if isinstance(t, CForall):
        y, A, B = t.args        # t = CForall(y, A, B)


        A1 = subst(A, x, e)


        if y == x:
            return CForall(y, A1, B)


        if y not in FV(e):
            return CForall(
                y,
                A1,
                subst(B, x, e)
            )


        z = fresh_local_name(FV(B) ∪ FV(e) ∪ {x, y})
        B1 = alpha_rename_binder(B, y, z)
        return CForall(
            z,
            A1,
            subst(B1, x, e)
        )


    if isinstance(t, CSigma):
        y, A, B = t.args        # t = CSigma(y, A, B)


        A1 = subst(A, x, e)


        if y == x:
            return CSigma(y, A1, B)


        if y not in FV(e):
            return CSigma(
                y,
                A1,
                subst(B, x, e)
            )


        z = fresh_local_name(FV(B) ∪ FV(e) ∪ {x, y})
        B1 = alpha_rename_binder(B, y, z)
        return CSigma(
            z,
            A1,
            subst(B1, x, e)
        )


    if isinstance(t, CPairTyped):
        x_var, A, B, a, b = t.args  # t = CPairTyped(x_var, A, B, a, b)
        A1 = subst(A, x, e)
        a1 = subst(a, x, e)
        b1 = subst(b, x, e)
        if x_var == x:
            return CPairTyped(x_var, A1, B, a1, b1)
        if x_var not in FV(e):
            return CPairTyped(x_var, A1, subst(B, x, e), a1, b1)
        z = fresh_local_name(FV(B) ∪ FV(e) ∪ {x, x_var})
        B1 = alpha_rename_binder(B, x_var, z)
        return CPairTyped(z, A1, subst(B1, x, e), a1, b1)

    if isinstance(t, CFst):
        t1 = t.args               # t = CFst(t1)
        return CFst(subst(t1, x, e))

    if isinstance(t, CSnd):
        t1 = t.args               # t = CSnd(t1)
        return CSnd(subst(t1, x, e))
```
**评论：** `CPairTyped` 的 subst 和 `CSigma` 类似 — 它有 binder `x_var` 在 `B` 中，需要处理变量捕获。同时它有四个子 term（`A`, `B`, `a`, `b`），都需要递归替换。`CFst`/`CSnd` 的 subst 只是递归替换子 term。v6 中不再有 `Ann` 的 subst 分支 — `Ann` 不存在于 CoreTerm 中。
这里用了两个辅助函数：
```python
# 写作 fresh_local_name(used)
def fresh_local_name(used : Set[LocalName]) -> LocalName:
    '''
    返回一个不在 used 中的新局部变量名
    '''


# 写作 alpha_rename_binder(t, old, new)
def alpha_rename_binder(t : CoreTerm, old : LocalName, new : LocalName) -> CoreTerm:
    '''
    把 t 中由当前外层 binder 绑定的 old 改名为 new
    要求 new 不在 FV(t) 中
    '''
```
当前阶段，这两个辅助函数可以先当作底层已实现。
### 11.1 例子

```text
subst(CVar x, x, CConst Nat) = CConst Nat
subst(CVar y, x, CConst Nat) = CVar y
subst(CApp(CVar x, CVar y), x, CConst Nat) = CApp(CConst Nat, CVar y)
subst(CLam(x, CSort(level 0), CVar x), x, CConst Nat)
= CLam(x, CSort(level 0), CVar x)
subst(CLam(y, CSort(level 0), CVar x), x, CConst Nat)
= CLam(y, CSort(level 0), CConst Nat)
```

并且：

```text
subst(CLam(y, CSort(level 0), CVar x), x, CVar y)
```

不能直接得到：

```text
CLam(y, CSort(level 0), CVar y)
```

因为这会发生变量捕获。
应先把 binder `y` 改名为一个新名字 `z`，再替换，得到：

```text
CLam(z, CSort(level 0), CVar y)
```

`CSigma`、`CPairTyped`、`CFst`、`CSnd` 的 subst 与已有的构造子完全平行（`CSigma` 同 `CForall`，`CPairTyped` 有 binder 类似 `CSigma`，`CFst`/`CSnd` 递归替换子 term）：

```text
subst(CSigma(y, CConst Nat, CVar x), x, CConst zero) = CSigma(y, CConst Nat, CConst zero)
subst(CPairTyped(x, CConst Nat, CConst Nat, CVar x, CVar y), x, CConst zero)
= CPairTyped(x, CConst Nat, CConst Nat, CConst zero, CVar y)
subst(CFst(CVar x), x, CConst zero) = CFst(CConst zero)
subst(CSnd(CPairTyped(x, CConst Nat, CConst Nat, CVar x, CVar y)), x, CConst zero)
= CSnd(CPairTyped(x, CConst Nat, CConst Nat, CConst zero, CVar y))
```
---
## 12. 计算规则：`whnf`                                              【v6 修改】

`whnf`（weak head normal form）把 CoreTerm 化简到弱头部正规形式。v6 中 `whnf` 作用于 `CoreTerm` — 不再有 `Ann` 擦除分支（CoreTerm 中没有 `Ann`），`CFst`/`CSnd` 匹配 `CPairTyped`。

```text
whnf(S, t) -> CoreTerm
```

它只在 term 的**头部**进行必要的化简 — 不递归进入 body、参数等子结构。"weak" 指不深入内部，"head" 指只处理最外层的 redex。

**评论：** 为什么不直接加入完整的 normalization 或 definitional equality？因为 definitional equality 依赖 whnf — `defeq(S, Γ, A, B)` 的标准实现是把 A 和 B 都 whnf 后比较头部，再递归比较子项。所以 whnf 是 conversion 的基础构件，先加它是最自然的顺序。

### whnf 的核心直觉

一句话：**从外往里，一层一层剥**。

```
whnf(S, CFst(CPairTyped(x, A, B, a, b)))
```

第一步看到 `CFst`，需要先知道它的参数是什么：

```
→ 先算 whnf(S, CPairTyped(x, A, B, a, b))
```

第二步看到 `CPairTyped`，是值（规范形式），不归约，停了：

```
→ 返回 CPairTyped(x, A, B, a, b)
```

回到 `CFst`：现在知道参数是 `CPairTyped` 了，取出第一分量：

```
→ 返回 whnf(S, a)
```

如果 `a` 本身已经是最简形式（比如 `CConst zero`），就停了。结果：`CConst zero`。

整个过程就像**剥洋葱** — 从最外层开始，遇到能化简的就化简，化简不动就停。不会主动去化简 `a` 内部的子结构（比如如果 `a` 是一个 `CApp`，whnf 不会碰它，除非它出现在新的头部位置）。

Ann 擦除分支不再需要 — CoreTerm 中没有 Ann。CPairTyped 是值（规范形式），不归约。

### 12.1 CConst 的 delta reduction

如果 `n` 是一个定义名（即 `n ∈ S.Defs`），则展开它的 body：

```text
whnf(S, CConst n) = whnf(S, body)     当 S.Defs.get(n) = (A, body)
whnf(S, CConst n) = CConst n           当 n ∉ S.Defs（即 n 是 axiom）
```

```python
if isinstance(t, CConst):
    n = t.args
    if n in S.Defs:
        A, body = S.Defs.get(n)
        return whnf(S, body)
    return t
```

**评论：**

- 当前模型认为所有 `def` 都是透明的（transparent），可以展开。将来如果要更接近 Lean，需要加入 reducibility 属性（`reducible` / `semireducible` / `irreducible` / `opaque`），控制哪些定义可以被展开。
- 注意 axiom 不能展开 — 它没有 body。`CConst Nat`、`CConst zero` 等已经是 whnf。

### 12.2 CApp 的 beta reduction

如果函数部分 whnf 后是 lambda，则发生 beta reduction：

```text
whnf(S, CApp(f, a)) = whnf(S, body[x := a])    当 whnf(S, f) = CLam(x, A, body)
whnf(S, CApp(f, a)) = CApp(whnf(S, f), a)       当 whnf(S, f) 不是 CLam
```

```python
if isinstance(t, CApp):
    f, a = t.args
    f0 = whnf(S, f)

    if isinstance(f0, CLam):
        x, A, body = f0.args
        return whnf(S, subst(body, x, a))

    return CApp(f0, a)
```

**评论：**

- Beta reduction 是 `CLam(x, A, body) a ↦ body[x := a]`。注意这里不先化简参数 `a` — 这是 **weak head** reduction 的特点：只化简头部到足够暴露结构，不化简参数或 body 内部。
- 如果 `f` whnf 后不是 `CLam`（比如是一个 axiom，或另一个 `CApp`），则无法继续化简，返回 `CApp(f0, a)`。

### 12.3 CFst 的 pair 投影化简

如果被投影项 whnf 后是 CPairTyped，则取出第一分量：

```text
whnf(S, CFst(p)) = whnf(S, a)             当 whnf(S, p) = CPairTyped(x, A, B, a, b)
whnf(S, CFst(p)) = CFst(whnf(S, p))       当 whnf(S, p) 不是 CPairTyped
```

```python
if isinstance(t, CFst):
    p = t.args
    p0 = whnf(S, p)

    if isinstance(p0, CPairTyped):
        x, A, B, a, b = p0.args
        return whnf(S, a)

    return CFst(p0)
```

### 12.4 CSnd 的 pair 投影化简

如果被投影项 whnf 后是 CPairTyped，则取出第二分量：

```text
whnf(S, CSnd(p)) = whnf(S, b)             当 whnf(S, p) = CPairTyped(x, A, B, a, b)
whnf(S, CSnd(p)) = CSnd(whnf(S, p))       当 whnf(S, p) 不是 CPairTyped
```

```python
if isinstance(t, CSnd):
    p = t.args
    p0 = whnf(S, p)

    if isinstance(p0, CPairTyped):
        x, A, B, a, b = p0.args
        return whnf(S, b)

    return CSnd(p0)
```

### 12.5 其他情况

其他 CoreTerm 已经是 whnf，不做进一步化简：

```python
return t
```

因此 `whnf` 不递归进入：

```text
CLam 的 body
CForall 的 A 和 B
CSigma 的 A 和 B
CPairTyped 的 A、B、a、b
CSort
CVar
```

除非这些 term 出现在需要被化简的头部位置（如 `CApp` 的函数部分、`CFst`/`CSnd` 的被投影项）。

### 12.6 `whnf` 完整代码

```python
# 写作 whnf(S, t)
def whnf(S : State, t : CoreTerm) -> CoreTerm:
    '''
    把 t 化简到 weak head normal form。
    处理：delta 展开、beta reduction、CFst/CSnd 投影化简。
    Ann 擦除分支不再需要 — CoreTerm 中没有 Ann。
    CPairTyped 是值（规范形式），不归约。
    '''

    if isinstance(t, CConst):
        n = t.args
        if n in S.Defs:
            A, body = S.Defs.get(n)
            return whnf(S, body)
        return t

    if isinstance(t, CApp):
        f, a = t.args
        f0 = whnf(S, f)

        if isinstance(f0, CLam):
            x, A, body = f0.args
            return whnf(S, subst(body, x, a))

        return CApp(f0, a)

    if isinstance(t, CFst):
        p = t.args
        p0 = whnf(S, p)

        if isinstance(p0, CPairTyped):
            x, A, B, a, b = p0.args
            return whnf(S, a)

        return CFst(p0)

    if isinstance(t, CSnd):
        p = t.args
        p0 = whnf(S, p)

        if isinstance(p0, CPairTyped):
            x, A, B, a, b = p0.args
            return whnf(S, b)

        return CSnd(p0)

    return t
```

---
## 13. 类型等价：`defeq`                                              【v6 修改】

v4 的 `whnf` 让 term 可以计算了。例如：

```text
whnf(S, fst p_ann) = Const zero
```

但 `check_type` 的类型比较仍然用 `==`。所以：

```text
infer_type(S, ∅, snd p_ann) = (Const Pred) (fst p_ann)
```

如果你想检查 `snd p_ann` 是否有类型 `(Const Pred) (Const zero)`：

```text
check_type(S, ∅, snd p_ann, (Const Pred) (Const zero))
```

在只用结构相等的模型中会失败 — 因为 `(Const Pred) (fst p_ann) ≠ (Const Pred) (Const zero)`（结构不同）。

直觉上这很荒谬：`fst p_ann` 算出来就是 `Const zero`，两者明明是一样的。但类型检查器如果只看结构，不看值，就不会承认这一点。

`defeq`（definitional equality）解决这个问题：**先把两边算一算（whnf），然后看结构是否匹配，递归比较子项**。

```text
defeq(S, ∅, (Const Pred) (fst p_ann), (Const Pred) (Const zero))
```

推导过程：

1. 两边先 whnf。左边 `(Const Pred) (fst p_ann)` — `Pred` 是 axiom，不能展开为函数，所以 `App(Const Pred, ...)` 不化简。右边同理。两边 whnf 后还是原样。
2. 两边都是 `App`，递归比较函数部分和参数部分。
3. 函数部分：`defeq(S, ∅, Const Pred, Const Pred) = True`（同名 ✓）
4. 参数部分：`defeq(S, ∅, fst p_ann, Const zero)` — 先 whnf，`whnf(S, fst p_ann) = Const zero`，所以两边 whnf 后都是 `Const zero`，结构相同 ✓。
5. 因此 `defeq` 返回 `True`。

### 为什么不能只比较 `whnf`

不能写成：

```python
def defeq(S, Γ, t1, t2):
    return whnf(S, t1) == whnf(S, t2)
```

因为 `whnf` 只化简头部，不递归化简子项。`(Const Pred) (fst p_ann)` 的头部是 `App`，`Pred` 是 axiom 不能继续化简，所以 `whnf` 后不变。必须**递归进入子项**，在参数位置上再次调用 `defeq`（而 `defeq` 内部会再次调用 `whnf`），才能发现 `fst p_ann` 和 `Const zero` 相等。

所以 `defeq` = `whnf` + 递归结构比较 + alpha-renaming。

```text
defeq(S : State, Γ : Context, t1 : CoreTerm, t2 : CoreTerm) -> bool
```

写作 `defeq(S, Γ, t1, t2)`。含义是：在状态 `S` 和上下文 `Γ` 下，判断两个 CoreTerm 是否 definitionally equal。

当前阶段，`defeq` 做三件事：

1. **先对两边做 `whnf`** — 暴露头部结构
2. **头部结构匹配则递归比较子项** — 比如 `CApp` 就递归比函数和参数
3. **binder 用 alpha-renaming** — `CForall(x, Nat, x)` 和 `CForall(y, Nat, y)` 应该相等

### 13.1 基本情况（无子项的构造子）

**CSort：** 两边 whnf 后都是 `CSort`，比较 level。

```python
if isinstance(t1, CSort) and isinstance(t2, CSort):
    return t1.args == t2.args    # 比较两个 Level
```

**CConst：** 两边 whnf 后都是 `CConst`，比较全局名字。注意 whnf 已经展开了定义名（delta reduction），所以到达这里的 `CConst` 一定是 axiom。

```python
if isinstance(t1, CConst) and isinstance(t2, CConst):
    return t1.args == t2.args    # 比较两个 GlobalName
```

**评论：** `defeq(S, Γ, CVar x, CVar y) = False`，即使 `x` 和 `y` 有相同类型 — 比较的是 term 的相等，不是类型的相等。`x` 和 `y` 是两个不同的局部变量。

**CVar：** 两边 whnf 后都是 `CVar`，比较局部名字。

```python
if isinstance(t1, CVar) and isinstance(t2, CVar):
    return t1.args == t2.args    # 比较两个 LocalName
```

### 13.2 递归情况（有子项、无 binder 的构造子）

**CApp：** 递归比较函数部分和参数部分。

```python
if isinstance(t1, CApp) and isinstance(t2, CApp):
    f1, a1 = t1.args
    f2, a2 = t2.args
    return defeq(S, Γ, f1, f2) and defeq(S, Γ, a1, a2)
```

**CFst / CSnd：** 递归比较被投影项。

```python
if isinstance(t1, CFst) and isinstance(t2, CFst):
    return defeq(S, Γ, t1.args, t2.args)

if isinstance(t1, CSnd) and isinstance(t2, CSnd):
    return defeq(S, Γ, t1.args, t2.args)
```

### 13.3 Binder 情况（CLam / CForall / CSigma）

Binder 的处理需要 alpha-renaming。以 `CForall` 为例：

```python
if isinstance(t1, CForall) and isinstance(t2, CForall):
    x1, A1, B1 = t1.args
    x2, A2, B2 = t2.args

    if not defeq(S, Γ, A1, A2):
        return False

    z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
    B1z = alpha_rename_binder(B1, x1, z)
    B2z = alpha_rename_binder(B2, x2, z)

    Γ1 = expand_context(Γ, z, A1)
    return defeq(S, Γ1, B1z, B2z)
```

**评论：** 为什么需要 alpha-renaming？因为 `CForall(x, Nat, x)` 和 `CForall(y, Nat, y)` 只是 binder 名字不同，应该相等。做法是：取一个新名字 `z`，把两个 body 的 binder 都改成 `z`，然后在扩展上下文 `Γ, z : A` 下递归比较。这样 `x` 和 `y` 都变成了 `z`，body 就能正确比较了。

`CLam` 和 `CSigma` 的处理与 `CForall` 完全平行。

### 13.4 CPairTyped 情况                                           【v6 修改】

`CPairTyped` 有 binder `x` 在 `B` 中，处理方式类似 `CSigma`，但还需要比较 `a` 和 `b`：

```python
if isinstance(t1, CPairTyped) and isinstance(t2, CPairTyped):
    x1, A1, B1, a1, b1 = t1.args
    x2, A2, B2, a2, b2 = t2.args
    if not defeq(S, Γ, A1, A2):
        return False
    z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
    B1z = alpha_rename_binder(B1, x1, z)
    B2z = alpha_rename_binder(B2, x2, z)
    Γ1 = expand_context(Γ, z, A1)
    if not defeq(S, Γ1, B1z, B2z):
        return False
    if not defeq(S, Γ, a1, a2):
        return False
    return defeq(S, Γ, b1, b2)
```

### 13.5 其他情况

如果两边 whnf 后的头部构造子不同（比如一边是 `CApp`，另一边是 `CSort`），返回 `False`。

### 13.6 `defeq` 完整代码

```python
# 写作 defeq(S, Γ, t1, t2)
def defeq(S : State, Γ : Context, t1 : CoreTerm, t2 : CoreTerm) -> bool:
    '''
    判断 t1 和 t2 是否 definitionally equal。
    处理：whnf + alpha-equivalence + 递归结构比较。
    '''

    t1 = whnf(S, t1)
    t2 = whnf(S, t2)

    if t1 == t2:
        return True

    if isinstance(t1, CSort) and isinstance(t2, CSort):
        return t1.args == t2.args

    if isinstance(t1, CConst) and isinstance(t2, CConst):
        return t1.args == t2.args

    if isinstance(t1, CVar) and isinstance(t2, CVar):
        return t1.args == t2.args

    if isinstance(t1, CApp) and isinstance(t2, CApp):
        f1, a1 = t1.args
        f2, a2 = t2.args
        return defeq(S, Γ, f1, f2) and defeq(S, Γ, a1, a2)

    if isinstance(t1, CLam) and isinstance(t2, CLam):
        x1, A1, body1 = t1.args
        x2, A2, body2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(body1) ∪ FV(body2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        body1z = alpha_rename_binder(body1, x1, z)
        body2z = alpha_rename_binder(body2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        return defeq(S, Γ1, body1z, body2z)

    if isinstance(t1, CForall) and isinstance(t2, CForall):
        x1, A1, B1 = t1.args
        x2, A2, B2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        B1z = alpha_rename_binder(B1, x1, z)
        B2z = alpha_rename_binder(B2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        return defeq(S, Γ1, B1z, B2z)

    if isinstance(t1, CSigma) and isinstance(t2, CSigma):
        x1, A1, B1 = t1.args
        x2, A2, B2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        B1z = alpha_rename_binder(B1, x1, z)
        B2z = alpha_rename_binder(B2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        return defeq(S, Γ1, B1z, B2z)

    if isinstance(t1, CPairTyped) and isinstance(t2, CPairTyped):
        x1, A1, B1, a1, b1 = t1.args
        x2, A2, B2, a2, b2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        B1z = alpha_rename_binder(B1, x1, z)
        B2z = alpha_rename_binder(B2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        if not defeq(S, Γ1, B1z, B2z):
            return False
        if not defeq(S, Γ, a1, a2):
            return False
        return defeq(S, Γ, b1, b2)

    if isinstance(t1, CFst) and isinstance(t2, CFst):
        return defeq(S, Γ, t1.args, t2.args)

    if isinstance(t1, CSnd) and isinstance(t2, CSnd):
        return defeq(S, Γ, t1.args, t2.args)

    return False
```

---
## 14. `infer_type` 与 `check_type`                                 【v6 修改】
### 14.0 背景：为什么需要两个函数？

如果所有 CoreTerm 都能从自身推断类型，那么 `check_type` 只需要是 `infer_type` 的简单包装：

```text
check_type(S, Γ, t, A) = defeq(S, Γ, infer_type(S, Γ, t), A)
```

这对 `CVar`、`CConst`、`CSort`、`CApp`、`CLam`、`CForall`、`CSigma`、`CFst`、`CSnd`、`CPairTyped` 都够用 — 它们自身携带了足够的信息来确定类型。

v5 中裸 `Pair` 打破了这个假设 — `⟨a, b⟩` 不知道自己的 Σ 类型。但 v6 中 `CPairTyped(x, A, B, a, b)` 携带了完整类型信息，可以 infer。因此 v6 的 `check_type` 回归简单 — 不需要特殊的 `Pair` 分支。bidirectional typing 的概念仍然重要（elaboration 层 `SPair → CPairTyped` 的转换中用到），但 kernel 层的 `check_type` 不再需要 check-only 逻辑。

- **infer 模式**（synthesis）：`infer_type(S, Γ, t)` — 给定 CoreTerm，推断出类型。
- **check 模式**：`check_type(S, Γ, t, A)` — 给定 CoreTerm 和目标类型，检查是否合法。
两者的关系是：
```text
check_type 可以调用 infer_type（"先推断，再比较"）
infer_type 可以调用 check_type（如 CApp 中检查参数类型）
```
这和 **Lean 的真实实现**是一致的：
- Lean 的 elaborator 中，anonymous constructor `⟨a, b⟩` 必须知道 expected type 才能处理 — 这对应 elaboration 层 `SPair → CPairTyped` 的转换。
- Lean 的 kernel 中，构造子的类型签名存储在环境中，所以 kernel 可以 infer — 这对应 `CPairTyped` 可以直接 infer `CSigma(x, A, B)`。
### 14.1 `infer_type` 的定义
```text
infer_type(S : State, Γ : Context, t : CoreTerm) -> CoreTerm
```
写作：
```text
infer_type(S, Γ, t)
```
它的含义是：
- 输入状态 `S`
- 输入上下文 `Γ`
- 输入一个 CoreTerm `t`
- 若 `t` 在 `S` 和 `Γ` 下可推断类型，则返回它的类型
- 若不可推断，则 `infer_type(S, Γ, t)` 不定义（代码中写作 `raise Error`）
### 14.2 `check_type` 的定义
```text
check_type(S : State, Γ : Context, t : CoreTerm, A : CoreTerm) -> bool
```
写作：
```text
check_type(S, Γ, t, A)
```
它的含义是：
- 输入状态 `S`
- 输入上下文 `Γ`
- 输入一个 CoreTerm `t`
- 输入一个目标类型 `A`
- 若 `t` 在 `S` 和 `Γ` 下可以拥有类型 `A`，则返回 `True`
- 否则返回 `False`
### 14.3 代码
```python
# 写作 infer_type(S, Γ, t)
def infer_type(S: State, Γ: Context, t: CoreTerm) -> CoreTerm:
    '''
    在 S 和 Γ 下推断 t 的类型（infer 模式）
    若无法推断，则 raise Error
    '''


    if isinstance(t, CVar):
        x = t.args                 # t = CVar x
        A = Γ.Types.get(x)
        if A is None:
            raise Error
        return A


    elif isinstance(t, CConst):
        n = t.args                 # t = CConst n
        if n in S.Axioms:
            return S.Axioms.get(n)
        elif n in S.Defs:
            A, body = S.Defs.get(n)
            return A
        else:
            raise Error


    elif isinstance(t, CSort):
        u = t.args                 # t = CSort u
        return CSort(succ_level(u))


    elif isinstance(t, CForall):
        x, A, B = t.args           # t = CForall(x, A, B)


        TA = whnf(S, infer_type(S, Γ, A))
        if not isinstance(TA, CSort):
            raise Error
        u = TA.args                # TA = CSort u


        Γ1 = expand_context(Γ, x, A)
        TB = whnf(S, infer_type(S, Γ1, B))
        if not isinstance(TB, CSort):
            raise Error
        v = TB.args                # TB = CSort v


        return CSort(max_level(u, v))


    elif isinstance(t, CLam):
        x, A, body = t.args        # t = CLam(x, A, body)


        TA = whnf(S, infer_type(S, Γ, A))
        if not isinstance(TA, CSort):
            raise Error


        Γ1 = expand_context(Γ, x, A)
        B = infer_type(S, Γ1, body)


        TB = whnf(S, infer_type(S, Γ1, B))
        if not isinstance(TB, CSort):
            raise Error


        return CForall(x, A, B)


    elif isinstance(t, CApp):
        f, a = t.args              # t = CApp(f, a)


        Tf = whnf(S, infer_type(S, Γ, f))
        if not isinstance(Tf, CForall):
            raise Error
        x, A, B = Tf.args          # Tf = CForall(x, A, B)


        if not check_type(S, Γ, a, A):
            raise Error


        return subst(B, x, a)


    elif isinstance(t, CSigma):
        x, A, B = t.args          # t = CSigma(x, A, B)


        TA = whnf(S, infer_type(S, Γ, A))
        if not isinstance(TA, CSort):
            raise Error
        u = TA.args                # TA = CSort u


        Γ1 = expand_context(Γ, x, A)
        TB = whnf(S, infer_type(S, Γ1, B))
        if not isinstance(TB, CSort):
            raise Error
        v = TB.args                # TB = CSort v


        return CSort(max_level(u, v))


    elif isinstance(t, CPairTyped):
        x, A, B, a, b = t.args    # t = CPairTyped(x, A, B, a, b)
        # 类型验证（安全检查）
        TA = whnf(S, infer_type(S, Γ, A))
        if not isinstance(TA, CSort):
            raise Error
        if not check_type(S, Γ, a, A):
            raise Error
        if not check_type(S, Γ, b, subst(B, x, a)):
            raise Error
        return CSigma(x, A, B)

    elif isinstance(t, CFst):
        t1 = t.args                # t = CFst(t1)
        Tt1 = whnf(S, infer_type(S, Γ, t1))
        if not isinstance(Tt1, CSigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = CSigma(x, A, B)
        return A

    elif isinstance(t, CSnd):
        t1 = t.args                # t = CSnd(t1)
        Tt1 = whnf(S, infer_type(S, Γ, t1))
        if not isinstance(Tt1, CSigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = CSigma(x, A, B)
        return subst(B, x, CFst(t1))

    raise Error



# 写作 check_type(S, Γ, t, A)
def check_type(S: State, Γ: Context, t: CoreTerm, A: CoreTerm) -> bool:
    '''
    在 S 和 Γ 下检查 t : A（check 模式）
    v6：CPairTyped 可以 infer，不需要特殊分支。
    v5 中 Pair 只能 check，v6 中 CPairTyped 可 infer。
    check 专用逻辑从 kernel 移到了 elaboration 层
    （elab 函数处理 SPair → CPairTyped 的转换）。
    '''
    try:
        return defeq(S, Γ, infer_type(S, Γ, t), A)
    except:
        return False
```
**评论：**
- v6 的 `check_type` 回归了简洁的一行包装 — `defeq(infer_type(...), A)`。v5 中 `Pair` 需要 check-only 分支，但 v6 的 `CPairTyped` 携带类型信息，可以 infer，所以不需要特殊处理。
- bidirectional typing 的逻辑从 kernel 层移到了 elaboration 层。`SPair` 在表层不能 infer（不知道类型），但 elaboration 时 `elab(S, Γ, SPair(a, b), expectedType)` 拿到 expected type 后构造 `CPairTyped(x, A, B, a', b')`，交给 kernel。Kernel 的 `CPairTyped` 可以直接 infer。
- `try/except` 包住整个函数体，确保内部任何 `raise Error`（来自 `infer_type`）都被捕获并返回 `False`。
- 在 `CApp` 规则中，`infer_type` 已经调用了 `check_type` 来检查参数类型。所以 `infer` 和 `check` 是互相调用的，不是单方向的。
- `CFst` 和 `CSnd` 在 `infer_type` 中直接处理 — 它们**可以推断类型**。因为给定 `t : CSigma(x, A, B)`，`CFst(t)` 的类型一定是 `A`，`CSnd(t)` 的类型一定是 `B[x := CFst(t)]`，不存在歧义。
- 注意 `CSnd` 的类型中出现了 `CFst(t1)` — 这是一个**未经化简的项**。`whnf` 可以化简它（如果 `t1` 是 `CPairTyped`），但 `infer_type` 本身不做化简，它返回的类型中可能包含 `CFst(...)` 形式。`check_type` 通过 `defeq` 在比较时自动调用 `whnf` 来处理这种情况。
- `CPairTyped` 的 infer 规则：验证 `A` 是 type，检查 `a : A` 和 `b : B[x := a]`，返回 `CSigma(x, A, B)`。
- `infer_type` 在所有类型头部检查处使用了 `whnf` 展开。具体来说：`CForall`/`CSigma`/`CLam`/`CPairTyped` 分支中检查 `TA : CSort` 和 `TB : CSort` 时、`CApp` 分支中检查 `Tf : CForall` 时、`CFst`/`CSnd` 分支中检查 `Tt1 : CSigma` 时，都先用 `whnf` 展开推断出的类型。
---
## 15. 构建前置状态 `S`                                           【v6 修改】

为了后续展示 `whnf` / `defeq` 的例子，先构建一个共同的前置状态 `S`。

从空状态 `S0` 开始，依次执行：

```text
S1 = exec(S0, AxiomCmd Nat : SSort (level 0))
S2 = exec(S1, AxiomCmd zero : SConst Nat)
S3 = exec(S2, AxiomCmd Pred : SForall (x, SConst Nat, SSort (level 0)))
S  = exec(S3, AxiomCmd choosePred : SForall (x, SConst Nat, SApp (SConst Pred, SVar x)))
```

最终得到的状态 `S`：

```text
S.Axioms = {
  Nat        : CSort (level 0),
  zero       : CConst Nat,
  Pred       : CForall (x, CConst Nat, CSort (level 0)),
  choosePred : CForall (x, CConst Nat, CApp (CConst Pred, CVar x))
}
S.Defs = {}
```

四个 axiom 的角色：
- `Nat`：全局 type
- `zero`：`Nat` 的全局常量
- `Pred`：依值 type family — 对每个 `x : Nat`，`Pred x` 是一个 type
- `choosePred`：依值函数 — 对每个 `x : Nat`，给出 `Pred x` 的一个元素

由这些 axiom 立即可得（任意上下文 `Γ` 下）：

```text
S ; Γ ⊢ CConst Nat        : CSort (level 0)
S ; Γ ⊢ CConst zero       : CConst Nat
S ; Γ ⊢ CConst Pred       : CForall (x, CConst Nat, CSort (level 0))
S ; Γ ⊢ CConst choosePred : CForall (x, CConst Nat, CApp (CConst Pred, CVar x))
S ; Γ ⊢ CApp (CConst Pred, CConst zero) : CSort (level 0)
S ; Γ ⊢ CApp (CConst choosePred, CConst zero) : CApp (CConst Pred, CConst zero)
```

**评论：** 后续 §18-§20 的所有例子都基于这个状态 `S`。需要时会在用到的地方临时扩展状态（如 §19.4 加入 `pair0`）。

---
## 15a. `elab`：从 SurfaceTerm 到 CoreTerm                              【v6 新增】

**位置说明：** 概念上，elaboration 在 kernel 检查之前 — 用户写的 SurfaceTerm 先经 elab 转成 CoreTerm，再交给 kernel。但因为 `elab` 内部调用 `infer_type` 和 `check_type`（§14），它必须在它们之后定义。

定义函数：

```text
elab(S : State, Γ : Context, st : SurfaceTerm, expected : Optional[CoreTerm]) -> CoreTerm
```

写作：

```text
elab(S, Γ, st)
elab(S, Γ, st, A)          -- 有 expected type 时
```

含义是：

> 在状态 `S` 和上下文 `Γ` 下，把表层 term `st` elaboration 成核心 term。
> 如果提供了 `expected`（目标类型），则用它指导 elaboration。

### 15a.1 基本项

表层的基本项直接映射到核心：

```python
if isinstance(st, SConst):
    return CConst(st.args)

if isinstance(st, SSort):
    return CSort(st.args)

if isinstance(st, SVar):
    return CVar(st.args)
```

不需要 expected type。

### 15a.2 App

```python
if isinstance(st, SApp):
    f_s, a_s = st.args
    f_c = elab(S, Γ, f_s, None)
    Tf = whnf(S, infer_type(S, Γ, f_c))
    if not isinstance(Tf, CForall):
        raise Error
    x, A, B = Tf.args
    a_c = elab(S, Γ, a_s, A)
    return CApp(f_c, a_c)
```

**评论：** 先 elab 函数部分，推断其类型，获取参数的 expected type，再用它 elab 参数。这和 v5 的 `infer_type` 中 App 分支逻辑一致 — 但现在是 elaboration 层在做，而不是 kernel。

### 15a.3 Lam

```python
if isinstance(st, SLam):
    x, A_s, body_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, CSort):
        raise Error
    Γ1 = expand_context(Γ, x, A_c)
    body_c = elab(S, Γ1, body_s, None)
    return CLam(x, A_c, body_c)
```

### 15a.4 Forall

```python
if isinstance(st, SForall):
    x, A_s, B_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, CSort):
        raise Error
    Γ1 = expand_context(Γ, x, A_c)
    B_c = elab(S, Γ1, B_s, None)
    return CForall(x, A_c, B_c)
```

### 15a.5 Sigma

```python
if isinstance(st, SSigma):
    x, A_s, B_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, CSort):
        raise Error
    Γ1 = expand_context(Γ, x, A_c)
    B_c = elab(S, Γ1, B_s, None)
    return CSigma(x, A_c, B_c)
```

### 15a.6 Ann（**关键**）                                         【v6 关键变化】

```python
if isinstance(st, SAnn):
    t_s, A_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, CSort):
        raise Error
    t_c = elab(S, Γ, t_s, A_c)
    return t_c
```

**评论：**

- `SAnn(t, A)` 的 elaboration 结果是 `t_c` — **Ann 不出现在输出中**。
- 它的唯一作用是：先 elab 类型 `A`，验证 `A` 是 type，然后把 `A_c` 作为 expected type 传给 `t` 的 elaboration。
- 这就是 v5 中 `Ann` 的语义，但现在更清晰：`Ann` 是 elaboration 层的指令，不是 core term。
- 特别地，当 `t` 是 `SPair` 时，`A_c`（一个 `CSigma`）提供了 SPair elaboration 所需的类型信息（见 §15a.7）。

### 15a.7 Pair（**关键**）                                        【v6 关键变化】

```python
if isinstance(st, SPair):
    a_s, b_s = st.args
    if expected is None:
        raise Error
    expected_whnf = whnf(S, expected)
    if not isinstance(expected_whnf, CSigma):
        raise Error
    x, A, B = expected_whnf.args
    a_c = elab(S, Γ, a_s, A)
    if not check_type(S, Γ, a_c, A):
        raise Error
    B_subst = subst(B, x, a_c)
    b_c = elab(S, Γ, b_s, B_subst)
    if not check_type(S, Γ, b_c, B_subst):
        raise Error
    return CPairTyped(x, A, B, a_c, b_c)
```

**评论：**

- `SPair` **必须有 expected type**，且 expected type 的 whnf 必须是 `CSigma(x, A, B)`。否则 elab 失败。
- 第一个分量用 `A` 作为 expected type。
- 第二个分量用 `subst(B, x, a_c)` 作为 expected type — 这体现了依值性。
- 返回 `CPairTyped(x, A, B, a_c, b_c)`，把完整的 Σ 类型信息嵌入 core term。
- 这就是 v5 中 `check_type` 的 Pair 特殊分支 — 在 v6 中，这段逻辑从 kernel 移到了 elaboration 层。
- 如果用户写 `SPair(a, b)` 但没有类型上下文（如没有 `SAnn` 包装、没有目标类型），则 elaboration 失败。这和 Lean 的行为一致：`⟨a, b⟩` 需要 expected type。

### 15a.8 Fst

```python
if isinstance(st, SFst):
    t_s = st.args
    t_c = elab(S, Γ, t_s, None)
    Tt = whnf(S, infer_type(S, Γ, t_c))
    if not isinstance(Tt, CSigma):
        raise Error
    return CFst(t_c)
```

### 15a.9 Snd

```python
if isinstance(st, SSnd):
    t_s = st.args
    t_c = elab(S, Γ, t_s, None)
    Tt = whnf(S, infer_type(S, Γ, t_c))
    if not isinstance(Tt, CSigma):
        raise Error
    return CSnd(t_c)
```

### 15a.10 `elab` 完整代码

```python
# 写作 elab(S, Γ, st) 或 elab(S, Γ, st, expected)
def elab(S: State, Γ: Context, st: SurfaceTerm, expected: Optional[CoreTerm] = None) -> CoreTerm:
    '''
    把 SurfaceTerm elaboration 成 CoreTerm。
    如果有 expected type，用它指导 elaboration（特别是 SPair 和 SAnn）。
    '''

    if isinstance(st, SConst):
        return CConst(st.args)

    if isinstance(st, SSort):
        return CSort(st.args)

    if isinstance(st, SVar):
        return CVar(st.args)

    if isinstance(st, SApp):
        f_s, a_s = st.args
        f_c = elab(S, Γ, f_s, None)
        Tf = whnf(S, infer_type(S, Γ, f_c))
        if not isinstance(Tf, CForall):
            raise Error
        x, A, B = Tf.args
        a_c = elab(S, Γ, a_s, A)
        return CApp(f_c, a_c)

    if isinstance(st, SLam):
        x, A_s, body_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, CSort):
            raise Error
        Γ1 = expand_context(Γ, x, A_c)
        body_c = elab(S, Γ1, body_s, None)
        return CLam(x, A_c, body_c)

    if isinstance(st, SForall):
        x, A_s, B_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, CSort):
            raise Error
        Γ1 = expand_context(Γ, x, A_c)
        B_c = elab(S, Γ1, B_s, None)
        return CForall(x, A_c, B_c)

    if isinstance(st, SSigma):
        x, A_s, B_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, CSort):
            raise Error
        Γ1 = expand_context(Γ, x, A_c)
        B_c = elab(S, Γ1, B_s, None)
        return CSigma(x, A_c, B_c)

    if isinstance(st, SPair):
        a_s, b_s = st.args
        if expected is None:
            raise Error
        expected_whnf = whnf(S, expected)
        if not isinstance(expected_whnf, CSigma):
            raise Error
        x, A, B = expected_whnf.args
        a_c = elab(S, Γ, a_s, A)
        if not check_type(S, Γ, a_c, A):
            raise Error
        B_subst = subst(B, x, a_c)
        b_c = elab(S, Γ, b_s, B_subst)
        if not check_type(S, Γ, b_c, B_subst):
            raise Error
        return CPairTyped(x, A, B, a_c, b_c)

    if isinstance(st, SFst):
        t_s = st.args
        t_c = elab(S, Γ, t_s, None)
        Tt = whnf(S, infer_type(S, Γ, t_c))
        if not isinstance(Tt, CSigma):
            raise Error
        return CFst(t_c)

    if isinstance(st, SSnd):
        t_s = st.args
        t_c = elab(S, Γ, t_s, None)
        Tt = whnf(S, infer_type(S, Γ, t_c))
        if not isinstance(Tt, CSigma):
            raise Error
        return CSnd(t_c)

    if isinstance(st, SAnn):
        t_s, A_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, CSort):
            raise Error
        t_c = elab(S, Γ, t_s, A_c)
        return t_c

    raise Error
```

**总结：** `elab` 把 SurfaceTerm 转换成 CoreTerm。两个构造子需要特别注意：
- `SAnn(t, A)`：消耗 Ann，把 `A` 作为 expected type 传给 `t`。
- `SPair(a, b)`：需要 expected type `CSigma(x, A, B)`，用它 elaboration 出 `CPairTyped(x, A, B, a_c, b_c)`。
其他构造子基本是简单的递归映射（加上必要的类型验证）。

---
## 16. `State` 与 `Context` 的角色

简短回顾两者的分工：

- **State**：记录全局名字（axiom 和 def）的类型。`Const n` 的类型由 `S.Axioms` 或 `S.Defs` 决定。
- **Context**：记录当前 binder 打开的局部变量类型。`Var x` 的类型由 `Γ.Types` 决定。

例如：

```text
S ; Γ ⊢ Const Nat : Sort (level 0)           -- 类型来自 S.Axioms
S ; (Γ, x : Const Nat) ⊢ Var x : Const Nat   -- 类型来自 Γ.Types
```

State 是顶层、长期的（贯穿整个文件的推导）；Context 是局部、临时的（只在打开 binder 时存在）。

---
## 17. 关于 bidirectional typing                                  【v6 修改】

v6 将 bidirectional typing 分为两层：
- **elaboration 层**：`elab` 处理 SurfaceTerm → CoreTerm 的转换。`SPair` 需要 expected type 才能 elaborate。
- **kernel 层**：`infer_type` / `check_type` 只作用于 CoreTerm。`CPairTyped` 可以 infer。

### 17.1 哪些 CoreTerm 可以 infer？

以下 CoreTerm 可以在 `infer_type` 中成功推断类型：

```text
CVar x              → 从 Context 中查到
CConst n            → 从 State 中查到
CSort u             → 总是 CSort (succ_level(u))
CApp f a            → 从 f 的类型中算出
CLam x A body       → 自带类型注解 A，可以算出 CForall(x, A, B)
CForall x A B       → 可以算出 CSort(max(u, v))
CSigma x A B        → 可以算出 CSort(max(u, v))
CPairTyped x A B a b → 返回 CSigma(x, A, B)
CFst t              → 从 t 的类型 CSigma(x, A, B) 中取出 A
CSnd t              → 从 t 的类型 CSigma(x, A, B) 中取出 B[x := CFst(t)]
```

它们的共同特点是：**自身携带了足够的信息来确定类型**。注意 `CPairTyped` 携带了 Σ 类型信息，所以可以 infer — 这是 v6 相对于 v5 的关键变化。

### 17.2 哪些 SurfaceTerm 需要 expected type 才能 elaborate？

```text
SPair a b  → 需要 expected type 是 CSigma(x, A, B)
```

原因是：同样的 `⟨a, b⟩`，在不同的目标 `Σ(x:A), B` 下可能有不同的合法性。`SPair` 自身不携带 `B` 的信息。

但通过 `SAnn`，可以把 `SPair` 包装起来，让 elab 有 expected type：

```text
SAnn(SPair(a, b), SSigma(x, A, B))  →  elab 得到 CPairTyped(x, A_core, B_core, a_core, b_core)
```

### 17.3 调用链

v6 的函数调用链：

```text
elab 调用 infer_type / check_type：
  - SApp 规则中，推断函数类型
  - SPair 规则中，check 分量类型
  - SAnn 规则中，验证类型标注
  - SLam/SForall/SSigma 规则中，验证 domain 是 type

infer_type 调用 check_type：
  - CApp 规则中，检查参数类型

check_type 调用 infer_type：
  - 默认分支：先 infer 再 defeq 比较
```

### 17.4 和 Lean 的关系

| 我们的模型                                     | Lean 中的对应                                              |
| ----------------------------------------- | ------------------------------------------------------ |
| `SPair` 需要 expected type 才能 elaborate   | Lean elaborator 中 `⟨a, b⟩` 需要 expected type            |
| `elab` 把 `SPair` 转换为 `CPairTyped`        | Lean elaborator 用 expected type 来 elaboration `⟨a, b⟩` |
| `CPairTyped` 可以 infer                     | 将来对应 `Sigma.mk` 的类型可从环境查到                          |
| `SAnn` 消耗 Ann，传递 expected type          | Lean 表面语法中的类型标注帮助 elaborator                         |

### 17.5 v6 的架构变化

v5 中，裸 `Pair` 不能 infer，需要三种方式绕过（Ann、DefCmd、将来 inductive type）。v6 中，这个问题被根本性地解决了：

- **elaboration 层**：`SPair` 需要 expected type，`SAnn` 提供它。
- **kernel 层**：`CPairTyped` 自带类型信息，可以直接 infer。
- **Ann 消失**：`SAnn` 在 elaboration 时被消耗，不出现在 CoreTerm 中。

---
## 18. 关键 term：`p_ann`                                          【v6 修改】

本节目的：构建后续 §19、§20 中要用到的关键 term `p_ann`，展示它的 Surface 和 Core 两种形式。

### 18.1 Surface 形式（文本缩写）

**文本缩写（非模型操作）：** 以下简记 `p_ann_surf` 为：

```text
SAnn(
  SPair(SConst zero, SApp(SConst choosePred, SConst zero)),
  SSigma(x, SConst Nat, SApp(SConst Pred, SVar x))
)
```

这就是用户写的：

```text
(⟨Const zero, (Const choosePred) (Const zero)⟩
  : Σ (x : Const Nat), (Const Pred) (Var x))
```

### 18.2 Core 形式（elaboration 后）

经过 `elab(S, ∅, p_ann_surf, None)` 后得到（推导见 §21）：

**文本缩写（非模型操作）：** 以下简记 `p_ann_core` 为：

```text
CPairTyped(
  x,
  CConst Nat,
  CApp(CConst Pred, CVar x),
  CConst zero,
  CApp(CConst choosePred, CConst zero)
)
```

**评论：** 注意 core 形式中没有 `Ann` — 它在 elaboration 时被消耗了。`SSigma` 类型信息被嵌入到了 `CPairTyped` 中。

### 18.3 `CFst` / `CSnd` 在 `p_ann_core` 上的类型

由 `CFst` 和 `CSnd` 规则：

```text
infer_type(S, ∅, CFst(p_ann_core)) = CConst Nat
infer_type(S, ∅, CSnd(p_ann_core)) = CApp(CConst Pred, CFst(p_ann_core))
```

**评论（重要）：** 注意 `CSnd(p_ann_core)` 的类型是 `CApp(CConst Pred, CFst(p_ann_core))`，**不是** `CApp(CConst Pred, CConst zero)` — 类型中包含未化简的 `CFst(p_ann_core)`。`defeq` 通过 `whnf` 把 `CFst(p_ann_core)` 化简为 `CConst zero`，从而让 check 通过（详见 §20）。

---

## 19. `whnf` 例子                                                  【v6 修改】

### 19.1 beta reduction

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）：

```text
S.Axioms = {
  Nat        : CSort (level 0),
  zero       : CConst Nat,
  Pred       : CForall(x, CConst Nat, CSort (level 0)),
  choosePred : CForall(x, CConst Nat, CApp(CConst Pred, CVar x))
}
S.Defs = {}
```

**计算 `whnf`**

考虑 CoreTerm：

```text
CApp(CLam(x, CConst Nat, CVar x), CConst zero)
```

计算：

```text
whnf(S, CApp(CLam(x, CConst Nat, CVar x), CConst zero))
```

**推导过程：**

1. `t = CApp(CLam(x, CConst Nat, CVar x), CConst zero)`，匹配 `CApp` 分支 (§12.2)。
2. 先化简函数部分：

```text
whnf(S, CLam(x, CConst Nat, CVar x)) = CLam(x, CConst Nat, CVar x)
```

`CLam` 不是任何 whnf 规则的头部 redex，直接返回 (§12.5)。

3. `f0 = CLam(...)`，是 `CLam`，触发 beta reduction (§12.2)：

```text
whnf(S, subst(CVar x, x, CConst zero))
= whnf(S, CConst zero)
```

4. `CConst zero`：`zero` 不在 `S.Defs` 中（是 axiom），所以 (§12.1)：

```text
whnf(S, CConst zero) = CConst zero
```

**结论：**

```text
whnf(S, CApp(CLam(x, CConst Nat, CVar x), CConst zero)) = CConst zero
```

### 19.2 `CFst` 作用在 `CPairTyped` 上

**前置状态**

同 §19.1，状态 `S`。

**计算 `whnf`**

文本缩写（非模型操作）：令 `p_ann_core` 表示 §18.2 中定义的 `CPairTyped(x, CConst Nat, CApp(CConst Pred, CVar x), CConst zero, CApp(CConst choosePred, CConst zero))`。

考虑 CoreTerm：

```text
CFst(p_ann_core)
```

计算：

```text
whnf(S, CFst(p_ann_core))
```

**推导过程：**

1. `t = CFst(p_ann_core)`，匹配 `CFst` 分支 (§12.3)。
2. 先化简被投影项：

```text
whnf(S, p_ann_core)
```

`CPairTyped` 不是任何 whnf 规则的头部 redex（它是值），直接返回 (§12.5)：

```text
whnf(S, p_ann_core) = p_ann_core = CPairTyped(...)
```

3. `p0 = CPairTyped(...)`，匹配 `CPairTyped`，触发 fst 投影化简 (§12.3)：

```text
→ 返回 whnf(S, CConst zero) = CConst zero
```

**结论：**

```text
whnf(S, CFst(p_ann_core)) = CConst zero
```

**评论：** v5 中需要先擦除 Ann、再匹配 Pair，两步。v6 中直接匹配 `CPairTyped`，一步完成。

### 19.3 `CSnd` 作用在 `CPairTyped` 上

**前置状态**

同 §19.1，状态 `S`。

**计算 `whnf`**

考虑 CoreTerm：

```text
CSnd(p_ann_core)
```

**推导过程：**

1. `t = CSnd(p_ann_core)`，匹配 `CSnd` 分支 (§12.4)。
2. 先化简被投影项（同 §19.2 第 2 步）：

```text
whnf(S, p_ann_core) = p_ann_core = CPairTyped(...)
```

3. `p0 = CPairTyped(...)`，匹配 `CPairTyped`，触发 snd 投影化简 (§12.4)：

```text
→ 返回 whnf(S, CApp(CConst choosePred, CConst zero))
```

4. `CApp(CConst choosePred, CConst zero)`：先化简函数部分：

```text
whnf(S, CConst choosePred) = CConst choosePred
```

`choosePred` 是 axiom（不在 `S.Defs` 中），不能展开为 `CLam`。beta reduction 不触发 (§12.2)。

**结论：**

```text
whnf(S, CSnd(p_ann_core)) = CApp(CConst choosePred, CConst zero)
```

### 19.4 `CFst` / `CSnd` 作用在全局定义上

**前置状态**

在状态 `S` 的基础上，通过 `DefCmd` 注册一个 pair：

```text
pair0 : GlobalName
pair0 ∉ dom(S.Axioms)
pair0 ∉ dom(S.Defs)
```

执行：

```text
S' = exec(S, DefCmd pair0
  (SSigma(x, SConst Nat, SApp(SConst Pred, SVar x)))
  SPair(SConst zero, SApp(SConst choosePred, SConst zero)))
```

exec 内部会先 elab 类型注解 `SAnn(SPair(...), SSigma(...))`，得到：

```text
S'.Defs.get(pair0) = Pair(
  CSigma(x, CConst Nat, CApp(CConst Pred, CVar x)),
  CPairTyped(x, CConst Nat, CApp(CConst Pred, CVar x), CConst zero, CApp(CConst choosePred, CConst zero))
)
```

执行后：

```text
S'.Axioms = {
  Nat        : CSort (level 0),
  zero       : CConst Nat,
  Pred       : CForall(x, CConst Nat, CSort (level 0)),
  choosePred : CForall(x, CConst Nat, CApp(CConst Pred, CVar x))
}
S'.Defs = {
  pair0 : (CSigma(x, CConst Nat, CApp(CConst Pred, CVar x)),
           CPairTyped(x, CConst Nat, CApp(CConst Pred, CVar x), CConst zero, CApp(CConst choosePred, CConst zero)))
}
```

### 计算 `whnf(S', CFst(CConst pair0))`

**推导过程：**

1. `t = CFst(CConst pair0)`，匹配 `CFst` 分支 (§12.3)。
2. `pair0 ∈ S'.Defs`，触发 delta reduction (§12.1)：

```text
whnf(S', CConst pair0) = whnf(S', CPairTyped(...))
                       = CPairTyped(...)
```

3. `p0 = CPairTyped(...)`，触发 fst 投影化简 (§12.3)：

```text
whnf(S', CConst zero) = CConst zero
```

**结论：** `whnf(S', CFst(CConst pair0)) = CConst zero`

同理 `whnf(S', CSnd(CConst pair0)) = CApp(CConst choosePred, CConst zero)`

---

## 20. `defeq` 例子                                                  【v6 修改】

### 20.1 `CSnd(p_ann_core)` 现在可以通过 `check_type`

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）。

文本缩写（非模型操作）：令 `p_ann_core` 表示 §18.2 中的 `CPairTyped(x, CConst Nat, CApp(CConst Pred, CVar x), CConst zero, CApp(CConst choosePred, CConst zero))`。

**推导过程**

由 `CSnd` 规则 (§14)：

```text
infer_type(S, ∅, CSnd(p_ann_core)) = CApp(CConst Pred, CFst(p_ann_core))
```

需要证明：

```text
defeq(S, ∅, CApp(CConst Pred, CFst(p_ann_core)), CApp(CConst Pred, CConst zero)) = True
```

这样 `check_type(S, ∅, CSnd(p_ann_core), CApp(CConst Pred, CConst zero))` 就会通过。

**defeq 推导：**

1. 两边先 `whnf`。`CApp(CConst Pred, CFst(p_ann_core))` — `Pred` 是 axiom，whnf 后不变。`CApp(CConst Pred, CConst zero)` — 同理不变。

2. 两边都是 `CApp`（§13.2），递归比较函数部分和参数部分。

3. 函数部分：`defeq(S, ∅, CConst Pred, CConst Pred)`

   两边 whnf 后都是 `CConst Pred`，比较名字 `Pred == Pred` ✓

4. 参数部分：`defeq(S, ∅, CFst(p_ann_core), CConst zero)`

   先 whnf 左边：`whnf(S, CFst(p_ann_core)) = CConst zero`（§19.2 已证）

   两边 whnf 后都是 `CConst zero`，`t1 == t2` ✓

5. 函数部分 ✓ 且参数部分 ✓，因此 `CApp` 整体 ✓。

**结论：**

```text
defeq(S, ∅, CApp(CConst Pred, CFst(p_ann_core)), CApp(CConst Pred, CConst zero)) = True
```

因此：

```text
check_type(S, ∅, CSnd(p_ann_core), CApp(CConst Pred, CConst zero)) = True
```

**评论：** 类型比较承认计算结果 — `defeq` 通过 `whnf` 发现 `CFst(p_ann_core) = CConst zero`，从而让两个结构不同但语义相同的类型通过检查。

### 20.2 alpha-renaming

**证明**

```text
defeq(S, ∅,
  CForall(x, CConst Nat, CApp(CConst Pred, CVar x)),
  CForall(y, CConst Nat, CApp(CConst Pred, CVar y))) = True
```

**推导过程：**

1. 两边先 `whnf`。`CForall` 不是头部 redex，不变。

2. 两边都是 `CForall`（§13.3），处理 binder：

   - 先比较 domain 类型：`defeq(S, ∅, CConst Nat, CConst Nat) = True` ✓
   - 取新名字 `z`（不在 `FV(B1) ∪ FV(B2) ∪ ...` 中）
   - 左边 body `CApp(CConst Pred, CVar x)` 改名为 `CApp(CConst Pred, CVar z)`
   - 右边 body `CApp(CConst Pred, CVar y)` 改名为 `CApp(CConst Pred, CVar z)`
   - 在扩展上下文 `∅, z : CConst Nat` 下递归比较

3. 递归比较 `CApp(CConst Pred, CVar z)` 和 `CApp(CConst Pred, CVar z)`：

   两边都是 `CApp`。函数部分 `CConst Pred` vs `CConst Pred` ✓。参数部分 `CVar z` vs `CVar z` ✓。

**结论：** `defeq` 返回 `True`。

**评论：** binder 名字不同的 `CForall` 通过 alpha-renaming 被视为相等。

### 20.3 `CFst` / `CSnd` 作用在全局定义上的 `defeq`

**前置状态**

沿用 §19.4 的状态 `S'`（`pair0` 已注册为全局定义，文本缩写，非模型操作）。

**证明**

```text
check_type(S', ∅, CSnd(CConst pair0), CApp(CConst Pred, CConst zero)) = True
```

**推导过程：**

1. 先推断类型：

```text
infer_type(S', ∅, CSnd(CConst pair0)) = CApp(CConst Pred, CFst(CConst pair0))
```

2. `check_type` 调用：

```text
defeq(S', ∅, CApp(CConst Pred, CFst(CConst pair0)), CApp(CConst Pred, CConst zero))
```

3. 两边都是 `CApp`，递归比较：

   - 函数部分：`CConst Pred` vs `CConst Pred` ✓
   - 参数部分：`defeq(S', ∅, CFst(CConst pair0), CConst zero)`

4. 参数部分的比较：

   先 whnf 左边：`whnf(S', CFst(CConst pair0)) = CConst zero`（§19.4 已证：delta 展开 `pair0` → `CPairTyped` → fst 取第一分量 → `CConst zero`）

   两边 whnf 后都是 `CConst zero` ✓

**结论：**

```text
check_type(S', ∅, CSnd(CConst pair0), CApp(CConst Pred, CConst zero)) = True
```

**评论：** `defeq` 在比较参数部分时调用了 `whnf`，`whnf` 做了 delta 展开（`CConst pair0` → body → `CPairTyped`）和 fst 投影化简（`CFst(CPairTyped(a, ...))` → `a`）。

---

## 21. `elab` 例子                                                  【v6 新增】

本节展示 `elab` 函数的逐步推导过程，每步引用 §15a 中的规则。

### 21.1 `p_ann_surf` 的完整 elaboration

**输入：**

```text
elab(S, ∅, SAnn(
  SPair(SConst zero, SApp(SConst choosePred, SConst zero)),
  SSigma(x, SConst Nat, SApp(SConst Pred, SVar x))
), None)
```

**推导过程：**

**步骤 1：** 匹配 `SAnn` (§15a.6)。

**步骤 2：** 先 elab 类型注解 `SSigma(x, SConst Nat, SApp(SConst Pred, SVar x))`。

- 匹配 `SSigma` (§15a.5)。
- elab `SConst Nat` → `CConst Nat` (§15a.1)。验证 `infer_type(S, ∅, CConst Nat) = CSort(level 0)` ✓
- 在扩展上下文 `∅, x : CConst Nat` 下，elab `SApp(SConst Pred, SVar x)`：
  - 匹配 `SApp` (§15a.2)。
  - elab `SConst Pred` → `CConst Pred` (§15a.1)。
  - `infer_type(S, ∅, CConst Pred) = CForall(x, CConst Nat, CSort(level 0))`。
  - 参数 expected type 为 `CConst Nat`。
  - elab `SVar x` → `CVar x` (§15a.1)。
  - `check_type(S, (∅, x : CConst Nat), CVar x, CConst Nat) = True` ✓
  - 返回 `CApp(CConst Pred, CVar x)`。
- 返回 `CSigma(x, CConst Nat, CApp(CConst Pred, CVar x))`。

**步骤 3：** 验证类型注解是 type：

```text
infer_type(S, ∅, CSigma(x, CConst Nat, CApp(CConst Pred, CVar x))) = CSort(level 0)
```

✓

**步骤 4：** 用 `CSigma(x, CConst Nat, CApp(CConst Pred, CVar x))` 作为 expected type，elab 内部项 `SPair(SConst zero, SApp(SConst choosePred, SConst zero))`。

- 匹配 `SPair` (§15a.7)。
- `expected = CSigma(x, CConst Nat, CApp(CConst Pred, CVar x))`，非空。
- `whnf(S, expected) = CSigma(x, CConst Nat, CApp(CConst Pred, CVar x))`，是 `CSigma` ✓
- 提取 `x, A = CConst Nat, B = CApp(CConst Pred, CVar x)`。

- **第一个分量**：expected type = `CConst Nat`。
  - elab `SConst zero` → `CConst zero` (§15a.1)。
  - `check_type(S, ∅, CConst zero, CConst Nat) = True` ✓

- **第二个分量**：expected type = `subst(B, x, CConst zero) = CApp(CConst Pred, CConst zero)`。
  - elab `SApp(SConst choosePred, SConst zero)`：
    - 匹配 `SApp` (§15a.2)。
    - elab `SConst choosePred` → `CConst choosePred` (§15a.1)。
    - `infer_type(S, ∅, CConst choosePred) = CForall(x, CConst Nat, CApp(CConst Pred, CVar x))`。
    - 参数 expected type = `CConst Nat`。
    - elab `SConst zero` → `CConst zero` (§15a.1)。
    - `check_type(S, ∅, CConst zero, CConst Nat) = True` ✓
    - 返回 `CApp(CConst choosePred, CConst zero)`。
  - `check_type(S, ∅, CApp(CConst choosePred, CConst zero), CApp(CConst Pred, CConst zero)) = True` ✓

- 返回 `CPairTyped(x, CConst Nat, CApp(CConst Pred, CVar x), CConst zero, CApp(CConst choosePred, CConst zero))`。

**步骤 5：** `SAnn` 被消耗 — 返回步骤 4 的结果（不带 Ann 包装）。

**最终结果：**

```text
elab(S, ∅, p_ann_surf, None)
=
CPairTyped(
  x,
  CConst Nat,
  CApp(CConst Pred, CVar x),
  CConst zero,
  CApp(CConst choosePred, CConst zero)
)
= p_ann_core
```

**评论：** `SAnn` 在 elaboration 过程中被消耗了。它的唯一作用是为 `SPair` 提供了 expected type `CSigma(...)`，使得 `SPair` 能够成功 elaborate 为 `CPairTyped`。输出的 CoreTerm 中没有 `Ann`。

### 21.2 `SPair` 在没有 expected type 时失败

尝试：

```text
elab(S, ∅, SPair(SConst zero, SConst zero), None)
```

**推导过程：**

1. 匹配 `SPair` (§15a.7)。
2. `expected = None`。
3. **raise Error** — `SPair` 没有 expected type，无法 elaborate。

**评论：** 这和 Lean 的行为一致：裸 `⟨a, b⟩` 不能没有类型上下文地 elaboration。用户必须提供类型标注或把它放在已知目标类型的位置中。

### 21.3 `SFst(SSnd(p_ann_surf))` 的 elaboration

**输入：**

```text
elab(S, ∅, SFst(SSnd(p_ann_surf)), None)
```

其中 `p_ann_surf` 如 §21.1。

**推导过程：**

1. 匹配 `SFst` (§15a.8)。递归 elab 内部项 `SSnd(p_ann_surf)`。

2. elab `SSnd(p_ann_surf)`：
   - 匹配 `SSnd` (§15a.9)。递归 elab `p_ann_surf`。
   - elab `p_ann_surf` = `SAnn(SPair(...), SSigma(...))` → `CPairTyped(...)` (§21.1 已证)。
   - `infer_type(S, ∅, CPairTyped(...)) = CSigma(x, CConst Nat, CApp(CConst Pred, CVar x))` ✓
   - 返回 `CSnd(CPairTyped(...))`。

3. 回到 `SFst`：
   - `t_c = CSnd(CPairTyped(...))`。
   - `infer_type(S, ∅, CSnd(CPairTyped(...))) = CApp(CConst Pred, CFst(CPairTyped(...)))`。
   - `whnf` 后 `CFst(CPairTyped(...)) → CConst zero`，所以类型是 `CApp(CConst Pred, CConst zero)`。
   - 但 `SFst` 需要验证类型是 `CSigma`。`CApp(CConst Pred, CConst zero)` whnf 后不是 `CSigma`。
   - **raise Error**。

**评论：** `SFst(SSnd(p_ann_surf))` 会 elaboration 失败 — 因为 `CSnd(p_ann_core)` 的类型是 `CApp(CConst Pred, ...)`，不是 `CSigma`。`CFst` 要求参数类型是 `CSigma`。这个行为是正确的：`fst (snd pair)` 在这个例子中确实没有意义（`snd pair` 的类型不是 pair 类型）。

---

## 22. 当前阶段的边界                                             【v6 修改】

当前阶段，模型包含：

```text
SurfaceTerm 构造子：SConst, SSort, SVar, SApp, SLam, SForall, SSigma, SPair, SFst, SSnd, SAnn

CoreTerm 构造子：CConst, CSort, CVar, CApp, CLam, CForall, CSigma, CPairTyped, CFst, CSnd

函数：FV(CoreTerm), subst(CoreTerm), exec, infer_type, check_type, whnf, defeq, elab
```

类型系统特性：

```text
Surface/Core 分层
elaboration（SurfaceTerm → CoreTerm，携带 expected type）
bidirectional typing（infer / check）on CoreTerm
whnf（弱头部正规化）on CoreTerm
definitional equality（alpha-renaming + reduction + 递归比较）on CoreTerm
conversion-based checking（check_type 用 defeq）on CoreTerm
```

计算规则：

```text
CFst(CPairTyped(x, A, B, a, b)) → a
CSnd(CPairTyped(x, A, B, a, b)) → b
CApp(CLam(x, A, body), a) → body[x := a]
CConst defName → body（delta 展开）
```

注意：`(t : A) ↦ t`（Ann 擦除）不再出现在计算规则中 — `Ann` 不是 CoreTerm 构造子。

尚未加入：

```text
eta 规则
proof irrelevance
universe constraints / level metavariable
reducibility control（opaque / semireducible）
de Bruijn index / fvar
inductive type 声明机制
Sigma/Pair/Fst/Snd 环境化（v7）
Proj primitive（v7）
```

v6 的定位：

> Term 被拆分为 SurfaceTerm 和 CoreTerm；
> elaboration 层（elab）负责 Surface → Core 的转换；
> kernel 层（infer/check/whnf/defeq）只处理 CoreTerm；
> Ann 从 CoreTerm 中消失，被 elab 消耗；
> 裸 Pair 从 CoreTerm 中消失，被 CPairTyped 替代；
> CPairTyped 是 v7 Sigma.mk 的前身。
