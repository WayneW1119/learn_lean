# model v11

> **本模型建立在 model v10 的所有定义之上。**
>
> **本版主题：从 structure 跨到最简单的 inductive。**
>
> v10 已经能声明 structure：一个结构类型、一个构造子、若干字段，以及按字段取值的 projection。但一般的归纳类型不一定只有一个构造子，也不一定通过字段投影来使用。例如 `Bool` 有两个构造子：
>
> ```text
> Bool.false : Bool
> Bool.true  : Bool
> ```
>
> 要使用一个 `Bool`，关键操作不是投影字段，而是覆盖所有构造情况进行消去。因此 v11 加入第一版 `InductiveCmd`，并建立以下完整管线：
>
> ```text
> InductiveCmd
>   ↓ exec
> type + constructors + recursor
>   ↓
> InductiveInfo + RecursorInfo
>   ↓
> whnf 中的 iota reduction
> ```
>
> 用户执行：
>
> ```text
> InductiveCmd Bool
>   constructors = [false, true]
> ```
>
> `exec` 自动生成：
>
> ```text
> Bool       : Sort 0
> Bool.false : Bool
> Bool.true  : Bool
> Bool.rec   :
>   Π (motive : Π (_ : Bool), Sort 0),
>   Π (case_0 : motive Bool.false),
>   Π (case_1 : motive Bool.true),
>   Π (target : Bool),
>     motive target
> ```
>
> `Bool.rec` 是 Bool 的消去器：给出目标类型族 `motive`、false case、true case 和一个 `target : Bool`，得到 `motive target`。当 target 是具体构造子时，v11 新增的 iota reduction 选择对应 case：
>
> ```text
> Bool.rec motive case_false case_true Bool.false
>   → case_false
>
> Bool.rec motive case_false case_true Bool.true
>   → case_true
> ```
>
> 本版以 `not` 为贯穿例子：
>
> ```text
> not = fun b =>
>   Bool.rec (fun _ => Bool) Bool.true Bool.false b
> ```
>
> 它同时展示了自动生成的 recursor 类型、现有 elaborator 对 recursor 应用的处理，以及：
>
> ```text
> not false → true
> not true  → false
> ```
>
> 这些计算还会被现有的 `defeq` 自动看到，因为 `defeq` 本来就调用 `whnf`。因此 v11 不需要修改 `infer_type`、`check_type` 或 `defeq`。
>
> **为什么本版只支持 nullary constructors？**
>
> v11 先建立“多构造子声明 → 自动 recursor → iota reduction”这条最小闭环。`Bool.false` 和 `Bool.true` 都没有参数，所以每个 case 目前只是一个值。像 `Nat.succ : Nat → Nat` 这样的递归构造子还需要 constructor arguments、recursive arguments、case 参数和 induction hypothesis；这些作为 v12 的独立增量处理。
>
> **架构上的关键点：** v11 不增加 SurfaceTerm 或 CoreTerm 构造子。归纳类型、构造子和 recursor 在 term 中仍然只是 `Const` 及其 `App` 链；新能力主要来自 Command/State 元数据，kernel 只在 `whnf` 中增加由 `RecursorInfo` 驱动的 iota reduction。
>
> **相对于 v10 的变化：**
>
> * §2.4：新增 recursor 后缀 `rec` 和确定性的 binder 名生成函数 `recursor_binder_name`
> * §5.1d–§5.1f：新增 `InductiveInfo`、`RecursorInfo` 及其 State-level invariant
> * §5.3：`State` 新增 `Inductives` 和 `Recursors` 两个字段
> * §6.5：新增 nullary inductive 的 recursor 类型生成函数 `make_recursor_type`
> * §7：新增 `ConstructorDecl` 和 `InductiveCmd`
> * §9.5 / §9.6：`exec` 新增 `InductiveCmd` 分支，自动生成类型、构造子、recursor 和元数据
> * §12.3：`whnf` 的 `App` 分支新增 recursor iota reduction
> * §17.5：新增 `InductiveCmd Bool` 完整例子
> * §19.7、§20.6、§21.7：新增 `Bool.rec`、`not` 和 iota/defeq/elab 例子
> * v11 只支持无参数的 nullary constructors；递归构造子留到 v12
> * v11 不改 `SurfaceTerm`（13 个构造子），不改 `CoreTerm`（7 个构造子），不改 `infer_type` / `check_type` / `defeq`
>
> **记号约定：** 本文档中有时使用"令 X = ..."或"简记 X 为 ..."。这是**文本层面的临时缩写**，不是模型中的操作。模型中没有"令"或"赋值"的概念 — State 的修改只能通过 `exec` 执行命令来完成。
>
> **命名约定：** 有两种 term 类型：
> - `SurfaceTerm` 的构造子以 `S` 为前缀（`SConst`、`SApp`、`SAnn` 等）
> - `CoreTerm` 的构造子**不再使用** `C` 前缀（`Const`、`App`、`Proj` 等）
>
> 在不引起歧义时，"写作"格式省略前缀 — 例如 `Const Nat` 既可以表示 `SConst Nat` 也可以表示 CoreTerm 的 `Const Nat`，具体含义由上下文决定。
>
> **Projection 写法约定：** v10 引入两种 SurfaceTerm：
> - `SProj(projectionName, target)` — 写作 `projectionName target`
> - `SDot(target, fieldName)` — 写作 `target.fieldName`
>
> 两者 elaboration 后都变成 `Proj(structName, index, target)`，其中 `structName` 和 `index` 通过 `ProjectionInfo` 查找得到。区别仅在于表层语法：`SProj` 直接使用完整投影名，`SDot` 从 target 的类型推断结构名，再与字段名拼接成完整投影名。
>
> 名字拼接：投影的全局名字通过 Name 拼接得到，例如 `Sigma.a = Name([Sigma]).a = Name([Sigma, a])`。这个名字在 elab 和 exec 中使用。
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
> 例如 `(Const Sigma) A B` 表示 `App(App(Const Sigma, A), B)`。
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
- `CoreTerm` 有 7 个构造子：`Const`、`Sort`、`Var`、`App`、`Lam`、`Forall`、`Proj`（v11 不变）。
  - `Sigma` 不再是 core 构造子 — 它是环境中的全局名字 `Const Sigma`。
  - `Pair` 不再是 core 构造子 — 它是 `Const Sigma.mk` 的应用。
  - `fst/snd` 不再是 core 构造子 — 它们是 `Proj(Sigma, 0/1, target)`。
  - 所有 kernel 函数（`infer_type`、`check_type`、`whnf`、`defeq`、`FV`、`subst`）只作用于 `CoreTerm`。
  - `elab` 函数负责把 `SurfaceTerm` 转换为 `CoreTerm`。
- v9 新增 `StructureCmd`（§7），用户可以通过顶层命令声明新结构（包括 Sigma 和 Prod）。v9 不再预置任何结构 — 所有 StructureInfo 都通过 StructureCmd 生成。Kernel 规则无需修改即可处理新声明的结构。
- v11 新增 `InductiveCmd`（§7）：当前只支持 nullary constructors，自动生成 recursor，并由 `whnf` 通过 `RecursorInfo` 执行 iota reduction。`CoreTerm` 和 `SurfaceTerm` 均不扩张。
---
## 1. 关于 `PartialMap`
对 `M : PartialMap[K, V]`，约定可以使用以下操作：
```text
M.contains(k)
M.get(k)
M.set(k, v)
merge(M1, M2)
```
也允许使用下列等价记号：
```text
k in dom(M)
M(k)
M[k -> v]
```

其中 `merge(M1, M2)` 返回包含两张偏映射全部条目的新映射；若 key 重复，则取 `M2` 中的值。模型只在已经检查 key 不冲突后调用它。
---
## 2. 名字与 level
### 2.1 `Name`

首先把一个名字分成若干个组成部分。

```text
NamePart = NamePart(text : String)
```

其中，`text` 是非空字符串，并且不包含字符 `"."`。

例如：

```text
Nat, Sigma, mk, Point, x, y : NamePart
```

定义：

```text
class Name:
    parts : List[NamePart]
```

并要求：

```text
len(parts) ≥ 1
```

即一个 `Name` 是由一个或多个 `NamePart` 构成的非空有限序列。

显示一个 `Name` 时，在相邻的 `NamePart` 之间加入 `"."`。例如：

```text
Name([Nat])              # 写作 Nat
Name([Sigma])            # 写作 Sigma
Name([Sigma, mk])        # 写作 Sigma.mk
Name([Point, x])         # 写作 Point.x
Name([A, B, C])          # 写作 A.B.C
```

两个 `Name` 相等，当且仅当其 `parts` 列表长度相同，并且每个位置上的 `NamePart` 都相等。因此：

```text
Sigma.mk ≠ Sigma
Sigma.mk ≠ Sigma.a
A.B.C   ≠ A.B
```

名字中的 `"."` 只是各组成部分之间的显示分隔符，不属于任何一个 `NamePart`。

**名字拼接记号**

若：

```text
n : Name
x : NamePart
```

则规定：

```text
n.x
```

表示在 `n.parts` 的末尾追加 `x` 所得到的新名字：

```text
(n.x).parts = n.parts ++ [x]
```

例如：

```text
Sigma.mk
Point.x
Point.y
A.B.C
```

分别表示：

```text
Name([Sigma]).mk       = Name([Sigma, mk])
Name([Point]).x        = Name([Point, x])
Name([Point]).y        = Name([Point, y])
Name([A, B]).C         = Name([A, B, C])
```

这里的名字拼接是元语言中的名字构造，不是 CoreTerm 中的函数应用，也不是字符串层面的普通 term 运算。

当前模型直接以 `n.x` 作为元语言中的名字拼接记号，不再另外定义 `qualified_name` 一类功能重复的函数。

### 2.2 `GlobalName` 与 `LocalName`

定义：

```text
GlobalName = Name
```

即任何合法的 `Name` 都可以作为全局名字。

例如：

```text
Nat, zero, Sigma, Sigma.mk, Sigma.a, Point, Point.mk, Point.x
    : GlobalName
```

这里说某个对象是 `GlobalName`，只表示它具有可以作为全局名字使用的结构；并不表示该名字已经存在于当前状态 `S` 中。一个全局名字是否已经声明或被占用，通过查询：

```text
S.Axioms
S.Defs
S.Projections
```

判断。`S.Structures`、`S.Inductives` 和 `S.Recursors` 是附加在已有 Axiom 声明上的元数据：它们的 key 已经同时存在于 `S.Axioms`，因此不需要重复查询。`S.Projections` 不同：投影名会占用独立的全局名字，但不是可以写成 `Const` 的 term-level 声明，所以必须单独查询。

定义：

```text
LocalName = {n : Name | len(n.parts) = 1}
```

因此：

```text
LocalName ⊆ GlobalName
```

`LocalName` 只包含由一个 `NamePart` 构成的名字。例如：

```text
x, y, A, B, a, b : LocalName
```

而：

```text
Sigma.mk, Point.x, A.B : GlobalName
```

但不是 `LocalName`。

当前模型中，`LocalName` 用于：

- 局部变量名字
- binder 名字
- Context 中的名字
- structure 参数名
- structure 字段名

例如：

```text
Lam(x, A, body)
Forall(x, A, B)
ParamDecl(A, ...)
FieldDecl(x, ...)
```

都要求其中的名字是 `LocalName`。

单段名字也可以作为全局名字。例如：

```text
Nat : GlobalName
x   : GlobalName
```

因此，"局部名字"和"全局名字"并不是两种互不相容的名字结构。一个单段名字 `x` 可以在某处作为局部变量名使用，也可以在另一处作为全局声明名使用；它的具体作用由其出现的位置和当前状态决定。

当前 v11 尚未加入一般的名称解析机制。表层语法仍然通过：

```text
SConst(name : GlobalName)
SVar(name : LocalName)
```

显式区分全局常量引用和局部变量引用。

为了把单段局部名字追加到全局名字后面，定义：

```python
# 写作 append_local(parent, child)
def append_local(parent : GlobalName, child : LocalName) -> GlobalName:
    # child.parts 恰好只有一个元素
    return Name(parent.parts ++ child.parts)
```

因此：

```text
append_local(Sigma, a) = Sigma.a
append_local(Point, x) = Point.x
```

后文为了简洁，也把 `append_local(n, x)` 写作 `n.x`。这里要求右侧的 `x` 是 `LocalName`；因为它只有一个 `NamePart`，该记号与 §2.1 对 `NamePart` 的追加定义一致。

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

### 2.4 Recursor 自动生成名                                   【v11 新增】

v11 需要自动生成 recursor 名和 recursor 类型内部的 binder 名。

首先取一个固定的局部名：

```text
rec : LocalName
```

作为 recursor 的名字后缀。于是类型 `Bool` 的 recursor 全局名是：

```text
append_local(Bool, rec) = Bool.rec
```

对于 recursor 类型内部的 binder，定义有限的数据类型：

```text
RecursorBinderTag
  = MotiveTag
  | MotiveArgTag
  | TargetTag
  | CaseTag(index : Nat)
```

然后具体定义：

```python
# 写作 recursor_binder_name(tag)
def recursor_binder_name(tag : RecursorBinderTag) -> LocalName:
    if isinstance(tag, MotiveTag):
        return Name([NamePart("__recursor_motive")])

    if isinstance(tag, MotiveArgTag):
        return Name([NamePart("__recursor_motive_arg")])

    if isinstance(tag, TargetTag):
        return Name([NamePart("__recursor_target")])

    if isinstance(tag, CaseTag):
        i = tag.args
        return Name([NamePart("__recursor_case_" + decimal(i))])

    raise Error
```

其中 `decimal(i)` 是自然数的标准十进制字符串表示，视为底层已实现。上述字符串都非空且不含 `"."`，所以构造出的对象确实是单段 `Name`，即 `LocalName`。

该函数满足：

```text
recursor_binder_name(tag₁) = recursor_binder_name(tag₂)
⟺ tag₁ = tag₂
```

因此不同用途和不同 case 下标一定产生不同 binder 名；对同一个 tag 则总是产生相同名字。

这里**不要求**自动 binder 名与所有用户可能书写的局部名互不相同。`make_recursor_type` 构造的是一个完全由系统生成的 closed telescope，其中不会嵌入用户提供的局部 binder；它只需要内部名字互不相同。若未来生成的类型需要嵌入用户 telescope，再使用 `fresh_local_name` 做 capture avoidance。

确定性很重要：`make_recursor_type(info)` 对同一个 `info` 多次调用时，必须生成语法相同的 CoreTerm，而不只是 alpha-equivalent 的 CoreTerm。
---
## 3. `SurfaceTerm`

`SurfaceTerm` 表示用户在表层语法中写的东西。用户仍然写 `Σ (x : A), B`、`⟨a, b⟩`、`fst p`、`snd p`、`(t : A)`。v10 引入了 `projectionName target` 和 `target.fieldName` 两种投影语法。

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
            | SProj(projectionName : GlobalName, target : SurfaceTerm)
                                                      # 写作 projectionName target
            | SDot(target : SurfaceTerm, fieldName : LocalName)
                                                      # 写作 target.fieldName
```

**评论：** `SurfaceTerm` 保留了 `SSigma / SPair / SFst / SSnd / SAnn`。用户确实会写这些东西。但从 v7 起，elaboration 后它们分别变成：

```text
SSigma(x, A, B) → (Const Sigma) A (fun (x : A) => B)
SPair(a, b)     → (Const Sigma.mk) A (fun (x : A) => B) a b    (需 expected type)
SFst(t)         → Proj(Sigma, 0, t_core)
SSnd(t)         → Proj(Sigma, 1, t_core)
SAnn(t, A)      → t_core                                        (Ann 被消耗)

v10 引入（详见 §15.10-§15.11）：
SProj(projectionName, t) → Proj(structName, index, t_core)   （用完整投影名查 ProjectionInfo）
SDot(t, fieldName)       → Proj(structName, index, t_core)   （从 target 类型推断 structName）
```

---
## 4. `CoreTerm`

自 v7 起 `CoreTerm` 有 7 个构造子。相比 v6：

- **去掉**：`CSigma`、`CPairTyped`、`CFst`、`CSnd`
- **新增**：`Proj`
- **保留**：`Const`、`Sort`、`Var`、`App`、`Lam`、`Forall`（但去掉 `C` 前缀）

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

- **`Sigma` 不再是 core 构造子。** 表层 `Σ (x : A), B` 在 elaboration 后变成 `(Const Sigma) A (fun (x : A) => B)` — 一个普通的全局常量应用。Sigma 的类型信息存在 `State.Axioms` 中。
- **`Pair` 不再是 core 构造子。** 表层 `⟨a, b⟩` 在 elaboration 后变成 `(Const Sigma.mk) A Bfun a b` — 构造子的普通应用。
- **`fst / snd` 不再是 core 构造子。** 它们变成 `Proj(Sigma, 0, target)` 和 `Proj(Sigma, 1, target)` — 一般的投影机制。
- **`Proj` 是新的 core 构造子。** 它记录：投影哪个结构（`structName`）、投影第几个字段（`index`）、对哪个目标投影（`target`）。
- 暂时**不引入** `Sigma.fst / Sigma.snd / Prod.fst / Prod.snd` 全局名字。因为 `Proj(structName, index, p)` 已经编码了投影的全部信息。
- v10 引入 `ProjectionInfo`（见 §5.1b），记录每个字段的投影全局名字。`StructureInfo` 记录 `typeName`、`constructor`、`params`、`fields`。

### 4.1 例子

先假设：

```text
Nat, f, Sigma, Sigma.mk : GlobalName
x, y                    : LocalName
```

CoreTerm 例子：

```text
Const Nat                                  -- 全局常量
App(Const f, Var x)                        -- 应用
Proj(Sigma, 0, Var x)                      -- 第一投影
(Const Sigma) (Const Nat) (fun (x : Const Nat) => App(Const Pred, Var x))
                                           -- Sigma 类型（元语言缩写，底层是嵌套 App）
(Const Sigma.mk) (Const Nat) Bfun (Const zero) (Const choosePred_zero)
                                           -- 构造子应用（4 参数缩写）
```

注意：CoreTerm 中没有 `Ann`、`Sigma`（作为构造子）、`Pair`、`Fst`、`Snd`。

### 4.2 `Proj` 的直觉

`Proj(structName, index, target)` 可以理解为一个**通用的字段提取器**：

```text
Proj(Sigma, 0, p)   ≈   "取 p 的第 0 个字段"   ≈   p.fst
Proj(Sigma, 1, p)   ≈   "取 p 的第 1 个字段"   ≈   p.snd
```

如果你熟悉任何编程语言中的 struct/class，可以这样对应：

```text
// C/Java/Python 中的 struct 字段访问
point.x            // 第 0 个字段
point.y            // 第 1 个字段

// 自 v7 起 Proj 表达同一件事
Proj(Point, 0, point)   // 第 0 个字段（x）
Proj(Point, 1, point)   // 第 1 个字段（y）
```

三个参数的含义：

- **`structName`**：告诉我 target 属于哪个结构。就像 `point.x` 中，编译器需要知道 `point` 的类型才能找到 `x` 的位置。
- **`index`**：第几个字段。从 0 开始数。`0` = 第一个字段，`1` = 第二个字段。
- **`target`**：被投影的值。就是 `point.x` 中的 `point`。

**为什么不用专门的 `CFst` / `CSnd`？**

因为 `CFst(t)` 和 `CSnd(t)` 只能处理 Sigma 这一种结构。如果将来模型里加入了 `Point`（两个字段 x、y）、`Color`（三个字段 r、g、b）、`Prod`（两个字段但第二字段不依赖第一字段），难道每个都加一套 `CPointX` / `CPointY` / `CColorR` / `CColorG` / ...？

`Proj` 用一个构造子解决了所有结构的字段提取。这就是"一般化"的具体收益。v9 中所有结构（包括 Sigma）都通过 StructureCmd 定义，Proj 规则自动适用 — 不需要修改 kernel 代码（见 §17 和 §19.6 的 Point 例子）。

---
## 5. `State` 与 `StructureInfo`

### 5.1 `ParamInfo` 与 `FieldInfo`

新增两个 record 类型：

```text
class ParamInfo:
    name : LocalName
    type : CoreTerm          # 参数的类型（模板，可能引用前序参数名）

class FieldInfo:
    name : LocalName
    type : CoreTerm          # 字段的类型（模板，可能引用参数名和前序字段名）
```

**评论：** `ParamInfo.type` 和 `FieldInfo.type` 是**CoreTerm 形式的 schema template**。它们在语法上是合法的 CoreTerm，但可能含有**schema variables** — 即用 `Var` 引用参数名和前序字段名（如 `Var A`、`Var B`、`Var a`），这些名字属于 structure 的 schema 名字空间，不在任何真实的对象层 Γ 上下文中。因此，模板通常不是 closed CoreTerm，也不一定能在普通对象上下文中直接 type-check。`projection_type` 在返回前会替换掉所有 schema 变量，所以模板中的 `Var` 永远不会作为裸 term 进入 typing 判断。


### 5.1b `ProjectionInfo`

```text
class ProjectionInfo:
    projName    : GlobalName     # 投影的全局名字，如 Sigma.a
    structName  : GlobalName     # 所属结构名
    fieldIndex  : Nat            # 字段下标（从 0 开始）
```

每个 `ProjectionInfo` 记录：一个投影名字 `projName`（全局唯一）、它属于哪个结构 `structName`、对应结构中的第几个字段 `fieldIndex`。

**例子（Sigma）：**

```text
ProjectionInfo(Sigma.a, Sigma, 0)    # 投影名 Sigma.a，属于 Sigma，第 0 个字段（a）
ProjectionInfo(Sigma.b, Sigma, 1)    # 投影名 Sigma.b，属于 Sigma，第 1 个字段（b）
```

**例子（Prod）：**

```text
ProjectionInfo(Prod.a, Prod, 0)      # 投影名 Prod.a，属于 Prod，第 0 个字段（a）
ProjectionInfo(Prod.b, Prod, 1)      # 投影名 Prod.b，属于 Prod，第 1 个字段（b）
```

**评论：** `ProjectionInfo` 的引入使得 `SProj` 和 `SDot` 可以在 elaboration 时查找投影名对应的结构名和字段下标。`projName` 由 `typeName.fieldName` 生成，在 `exec(StructureCmd)` 时自动创建并写入 `S.Projections`。

### 5.1c `ProjectionInfo` 的 State-level invariant

对状态中的每个映射 `S.Projections.get(g) = pi`，要求：

1. `g = pi.projName`；
2. `S.Structures.get(pi.structName) = info`；
3. `pi.fieldIndex < len(info.fields)`；
4. `pi.projName = append_local(pi.structName, info.fields[pi.fieldIndex].name)`。

这些条件说明 `ProjectionInfo` 不是独立声明：它必须准确指向某个已注册结构的一个真实字段。条件由 `exec(StructureCmd)` 在同一次原子状态更新中保证。

### 5.1d `InductiveInfo`                                      【v11 新增】

```text
class InductiveInfo:
    typeName     : GlobalName        # inductive 类型名，如 Bool
    constructors : List[GlobalName]  # 按声明顺序排列的完整构造子名
    recursor     : GlobalName        # recursor 完整名字，如 Bool.rec
```

v11 只支持 nullary constructors，所以构造子暂时只需记录完整名字，不需要记录参数 telescope。对于 Bool：

```text
InductiveInfo(
  typeName = Bool,
  constructors = [Bool.false, Bool.true],
  recursor = Bool.rec
)
```

### 5.1e `RecursorInfo`                                       【v11 新增】

```text
class RecursorInfo:
    recursorName  : GlobalName        # recursor 完整名字
    inductiveName : GlobalName        # 对应的 inductive 类型名
    constructors  : List[GlobalName]  # 与 InductiveInfo 中顺序相同
```

`whnf` 使用 `RecursorInfo` 判断一个全局常量是否是已注册 recursor，并根据 target 的构造子在列表中的位置选择对应 case。v11 的构造子没有参数，所以 iota reduction 只需选择 case，不需要向 case 传递 constructor arguments。

### 5.1f Inductive / Recursor 的 State-level invariant         【v11 新增】

对每个 `S.Inductives.get(T) = info`，要求：

1. `T = info.typeName`；
2. `S.Axioms.get(T) = Sort(level 0)`；
3. `info.constructors` 中的名字互不相同；
4. `info.recursor = append_local(info.typeName, rec)`；
5. 对每个 `ctorName ∈ info.constructors`，存在 `c : LocalName`，使得 `ctorName = append_local(info.typeName, c)`；
6. `info.recursor ∉ info.constructors`；
7. 对每个 `ctorName ∈ info.constructors`，有 `S.Axioms.get(ctorName) = Const(T)`；
8. `S.Axioms.get(info.recursor) = make_recursor_type(info)`；
9. `S.Recursors.get(info.recursor) = RecursorInfo(info.recursor, T, info.constructors)`。

反过来，对每个 `S.Recursors.get(r) = recInfo`，要求：

1. `r = recInfo.recursorName`；
2. `S.Inductives.get(recInfo.inductiveName) = info`；
3. `info.recursor = r`；
4. `info.constructors = recInfo.constructors`。

`Inductives` 和 `Recursors` 与 `Structures` 一样，是已有 Axiom 声明的附加元数据：inductive 类型名、构造子名和 recursor 名都已经同时存在于 `Axioms`。`Projections` 不同：其条目会占用独立的全局名字，但该名字不是 term-level 常量。

### 5.2 `StructureInfo`

```text
class StructureInfo:
    typeName    : GlobalName
    constructor : GlobalName
    params      : List[ParamInfo]     # 类型参数列表
    fields      : List[FieldInfo]     # 字段列表
```

其中：
- `typeName` 是结构类型的全局名字；
- `constructor` 是该结构的构造子名字；
- `params` 是类型参数列表，每个 `ParamInfo` 记录参数名和类型模板；
- `fields` 是字段列表，每个 `FieldInfo` 记录字段名和类型模板；
- `numParams = len(params)`、`numFields = len(fields)`。不再单独存储这两个字段，改用 `len()`。whnf 中的引用也相应更新。

对于 `Sigma`（见 §10）：

```text
StructureInfo(
  typeName    = Sigma,
  constructor = Sigma.mk,
  params = [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Π (x : Var A), Sort(level 0))
  ],
  fields = [
    FieldInfo(a, Var A),
    FieldInfo(b, App(Var B, Var a))
  ]
)
```

含义：`ParamInfo(A, Sort(level 0))` 表示 Sigma 有一个参数名为 A、类型为 Sort 0。`FieldInfo(a, Var A)` 表示 Sigma 的第一个字段名为 a、类型模板为 Var A（经替换后变成实际的 A 值）。`FieldInfo(b, App(Var B, Var a))` 表示第二个字段名为 b、类型模板为 B 应用到 a（依赖第一个字段）。

**评论：** v10 引入 `ProjectionInfo`（§5.1b），记录每个字段的投影全局名字。`Proj(structName, index, target)` 仍然编码了投影的全部信息；`ProjectionInfo` 额外提供了从投影名到结构名和字段下标的映射，使得 `SProj` 和 `SDot` 的 elaboration 成为可能。

### 5.2a `StructureInfo` 自身的 well-formedness invariant

每个 `StructureInfo` 必须满足以下条件（这些条件由 `exec(StructureCmd)` 在生成时自动保证，见 §9.4）：

1. **参数名互不相同：** `info.params` 中所有 `ParamInfo.name` 互不相等。
2. **字段名互不相同：** `info.fields` 中所有 `FieldInfo.name` 互不相等。
3. **参数名和字段名互不相同：** 任何 `ParamInfo.name` 不等于任何 `FieldInfo.name`。
4. **ParamInfo.type 的自由 schema variables 只引用前序 params：** `FV(info.params[i].type) ⊆ { info.params[0].name, ..., info.params[i-1].name }`。注意：此处说的是**自由变量**（FV），不是所有 `Var`。被 `Forall` 或 `Lam` binder 绑定的 `Var`（如 `Π (x : Var A), Sort 0` 中的 `Var x`）不是 schema variable，不受此约束。
5. **FieldInfo.type 的自由 schema variables 只引用 params 和前序 fields：** `FV(info.fields[j].type) ⊆ { param names } ∪ { info.fields[0].name, ..., info.fields[j-1].name }`。

**例子（Sigma）：**

```text
params:
  A : Sort 0          # 只引用底层类型
  B : Π (x : A), Sort 0   # B 引用了前序参数 A ✓

fields:
  a : A               # a 引用了参数 A ✓（不引用后续字段）
  b : B a             # b 引用了参数 B 和前序字段 a ✓
```

注意 `b` 可以引用 `a`（因为 `a` 是前序字段），但 `a` 不能引用 `b`（因为 `b` 是后续字段）。这保证了 `projection_type` 的替换是完整的 — 所有 schema 变量都能被参数值和前序投影替换掉，不存在未解释的 schema variable。

**评论：** 以上五项只检查 `StructureInfo` 自身保存的名字和类型模板，不查询 `State`。v9 中所有 StructureInfo 都通过 `exec(StructureCmd)` 生成 — telescope 检查（§9.4）自动保证参数/字段类型都是 Sort（即 universe level 可计算），参数和字段的名字互不重复，字段类型模板中的 Var 引用只指向参数名或前序字段名。没有 StructureInfo 是预置的。

### 5.2b `StructureInfo` 的 State-level invariant

构造子的实际类型签名存储在 `S.Axioms`，而不存储在 `StructureInfo` 中。因此，结构类型与构造子声明之间的一致性必须作为 State-level invariant 单独规定。

对每个 `S.Structures.get(T) = info`，要求：

1. `T = info.typeName`；
2. `info.typeName ≠ info.constructor`；
3. `S.Axioms.get(T) = make_structure_type(info)`；
4. `S.Axioms.get(info.constructor) = make_constructor_type(info)`。

第 4 项同时规定了构造子类型中的 binder 顺序必须先是 `params`、再是 `fields`，并且返回类型必须是 `(Const info.typeName)` 应用到所有参数变量。这里需要查询 `S.Axioms`，所以它不是 `StructureInfo` 自身的 well-formedness 条件。四项条件由 `exec(StructureCmd)` 的类型生成、验证和原子状态更新共同保证（§9.4）。

### 5.3 `State`

```text
class State:
    Axioms      : PartialMap[g : GlobalName, t : CoreTerm]                 # 写作 g : t
    Defs        : PartialMap[g : GlobalName, Pair[t1 : CoreTerm, t2 : CoreTerm]]  # 写作 g : (t1, t2)
    Structures  : PartialMap[g : GlobalName, info : StructureInfo]          # 写作 g ↦ info
    Projections : PartialMap[g : GlobalName, pi : ProjectionInfo]           # 写作 g ↦ pi
    Inductives  : PartialMap[g : GlobalName, info : InductiveInfo]           # 写作 g ↦ info     【v11 新增】
    Recursors   : PartialMap[g : GlobalName, info : RecursorInfo]            # 写作 g ↦ info     【v11 新增】
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
- 若 `S.Structures.get(n) = info`，则表示：`n` 是一个已登记的结构类型，结构信息是 `info`。
- 若 `S.Projections.get(g) = pi`，则表示：`g` 是一个已登记的投影名，投影信息是 `pi`。
- 若 `S.Inductives.get(g) = info`，则表示：`g` 是一个已登记的 inductive 类型。
- 若 `S.Recursors.get(g) = info`，则表示：`g` 是一个已登记的 recursor。

普通全局声明名使用 `Axioms` / `Defs`，投影名使用 `Projections`。本模型采用统一的名字占用策略：`Structures`、`Inductives` 和 `Recursors` 都是已有 axiom 声明的附加元数据；新声明名不得与已有的 axiom、def 或 projection 名冲突。

正式地，任何合法状态都满足：

```text
dom(S.Axioms) ∩ dom(S.Defs)        = ∅
dom(S.Axioms) ∩ dom(S.Projections) = ∅
dom(S.Defs)   ∩ dom(S.Projections) = ∅
```

也就是说，`dom(S.Axioms)`、`dom(S.Defs)` 和 `dom(S.Projections)` 两两不相交。`Structures`、`Inductives` 和 `Recursors` 不构成第四、第五或第六个独立名字空间；它们与对应 Axiom 声明的关系分别由 §5.2b 和 §5.1f 的 State-level invariant 规定。`declaration_name_is_used`（§9）正是对这一统一名字占用策略的可执行判断。

注意：`S.Structures.get(Sigma)` 不是天生存在的。它必须来自某个具体状态。v9 中 Sigma 的 StructureInfo 来自 `exec(StructureCmd Sigma ...)`（见 §17.1），不再预置。

---
## 6. 类型生成辅助函数

### 6.0 `collect_app`

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

例如：

```text
collect_app((Const Sigma.mk) A B a b)
=
Pair(Const Sigma.mk, [A, B, a, b])
```

**评论：** 这个函数在 `whnf` 的 `Proj` 分支中用于识别构造子应用。因为 constructor application 在 CoreTerm 里就是嵌套 `App`，没有特殊构造子。

---
除 §6.0 的应用链分解函数 `collect_app` 外，本节定义五个类型生成辅助函数：前四个支持 structure 的 type constructor 与 constructor 类型生成，第五个生成 nullary inductive 的 recursor 类型。它们只依赖 `CoreTerm`（§4）和 §5 中的元数据 — 不调用 `elab`、`whnf`、`infer_type`。

`exec(StructureCmd)` 和 `exec(InductiveCmd)` 会调用相应函数（§9），把生成的类型写入 `S.Axioms`。

### 6.1 `make_forall_chain`

```python
# 写作 make_forall_chain(telescope, body)
def make_forall_chain(telescope : List[Pair[LocalName, CoreTerm]], body : CoreTerm) -> CoreTerm:
    '''
    从 telescope 列表和 body 构建 Forall 链。
    telescope = [(x1, T1), (x2, T2), ..., (xn, Tn)]
    结果 = Π (x1 : T1), Π (x2 : T2), ..., Π (xn : Tn), body
    '''
    if len(telescope) == 0:
        return body
    name, type = telescope[0]
    rest = telescope[1:]
    return Forall(name, type, make_forall_chain(rest, body))
```

**例子：**

```text
make_forall_chain([(A, Sort(level 0)), (B, Forall(x, Var A, Sort(level 0)))], Sort(level 0))
= Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Sort 0
```

空 telescope：

```text
make_forall_chain([], Sort(level 0))
= Sort(level 0)
```

**评论：** `telescope` 中的 `type` 可能含有 `Var` 引用前序名字 — 这些会被 `Forall` 的 binder 正确绑定。例如第二个参数 `Forall(x, Var A, Sort(level 0))` 中的 `Var A` 被外层 `Forall(A, ...)` 的 binder 绑定，不会成为自由变量。

### 6.2 `make_type_app`

```python
# 写作 make_type_app(typeName, paramNames)
def make_type_app(typeName : GlobalName, paramNames : List[LocalName]) -> CoreTerm:
    '''
    构建 (Const typeName) (Var p1) (Var p2) ... (Var pn)
    如果 paramNames 为空，返回 Const typeName。
    '''
    result = Const(typeName)
    for name in paramNames:
        result = App(result, Var(name))
    return result
```

**例子：**

```text
make_type_app(Sigma, [A, B]) = (Const Sigma) (Var A) (Var B)
make_type_app(Prod, [A, B])  = (Const Prod) (Var A) (Var B)
make_type_app(Point, [X])    = (Const Point) (Var X)
make_type_app(UnitLike, [])  = Const UnitLike
```

**评论：** 这是构造子返回类型的构建器。在 constructor 的类型签名中，返回类型是 `(Const typeName)` 应用到所有参数变量上。

### 6.3 `make_structure_type`

```python
# 写作 make_structure_type(info)
def make_structure_type(info : StructureInfo) -> CoreTerm:
    '''
    从 StructureInfo 生成 type constructor 的类型。
    结果 = Π params..., Sort(level 0)
    v9 简化：所有结构的结果类型固定为 Sort(level 0)。
    Universe polymorphism 和自动 universe inference 以后再加。
    '''
    telescope = []
    for param in info.params:
        telescope.append(Pair(param.name, param.type))

    return make_forall_chain(telescope, Sort(level 0))
```

**评论（简化版 universe）：** 当前模型暂时只支持单宇宙结构 — 所有 StructureCmd 生成的结构类型结果都固定为 `Sort(level 0)`。这不是通过参数类型的 universe 自动推导出来的，而是 v9 的简化约定。例如 Sigma 中参数 B 的类型 `Π (x : A), Sort 0` 本身生活在 Sort 1，但 `Sigma A B` 仍被本模型规定为 `Sort 0`。完整实现需要显式处理 universe 参数和 result sort，或进行 universe constraint inference；结构结果 universe 不是简单从 `param.type` 的 universe 自动取 `max` 得到（否则 Sigma 会得到 Sort 1，而非期望的 Sort 0）。v9 暂时不处理这些机制，直接固定结构结果为 `Sort(level 0)`。Universe polymorphism 和更真实的 universe inference 以后再加。

**例子：**

对于 Sigma：

```text
make_structure_type(StructureInfo(Sigma, Sigma.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Forall(x, Var A, Sort(level 0)))
  ], [...]))
```

telescope = `[(A, Sort(level 0)), (B, Forall(x, Var A, Sort(level 0)))]`

结果：

```text
Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Sort 0
```

这与 `SΣ.Axioms[Sigma]` 中由 StructureCmd 生成的 Sigma 类型完全一致 ✓

对于 Point（将在 §17 定义）：

```text
make_structure_type(StructureInfo(Point, Point.mk, [
    ParamInfo(X, Sort(level 0))
  ], [
    FieldInfo(x, Var X),
    FieldInfo(y, Var X)
  ]))
```

telescope = `[(X, Sort(level 0))]`

结果：

```text
Π (X : Sort 0), Sort 0
```

即 `Point : Π (X : Sort 0), Sort 0`。

### 6.4 `make_constructor_type`

```python
# 写作 make_constructor_type(info)
def make_constructor_type(info : StructureInfo) -> CoreTerm:
    '''
    从 StructureInfo 生成 constructor 的类型。
    结果 = Π params..., Π fields..., (Const typeName) (Var p1) ... (Var pn)
    '''
    telescope = []
    for param in info.params:
        telescope.append(Pair(param.name, param.type))
    for field in info.fields:
        telescope.append(Pair(field.name, field.type))

    body = make_type_app(info.typeName, [param.name for param in info.params])

    return make_forall_chain(telescope, body)
```

**例子：**

对于 Sigma：

```text
make_constructor_type(StructureInfo(Sigma, Sigma.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Forall(x, Var A, Sort(level 0)))
  ], [
    FieldInfo(a, Var A),
    FieldInfo(b, App(Var B, Var a))
  ]))
```

telescope = `[(A, Sort(level 0)), (B, Forall(x, Var A, Sort(level 0))), (a, Var A), (b, App(Var B, Var a))]`

body = `make_type_app(Sigma, [A, B])` = `(Const Sigma) (Var A) (Var B)`

结果：

```text
Π (A : Sort 0),
Π (B : Π (x : A), Sort 0),
Π (a : A),
Π (b : B a),
Sigma A B
```

这与 `SΣ.Axioms[Sigma.mk]` 中由 StructureCmd 生成的 Sigma.mk 类型完全一致 ✓

对于 Point：

```text
make_constructor_type(StructureInfo(Point, Point.mk, [
    ParamInfo(X, Sort(level 0))
  ], [
    FieldInfo(x, Var X),
    FieldInfo(y, Var X)
  ]))
```

telescope = `[(X, Sort(level 0)), (x, Var X), (y, Var X)]`

body = `make_type_app(Point, [X])` = `(Const Point) (Var X)`

结果：

```text
Π (X : Sort 0),
Π (x : X),
Π (y : X),
Point X
```

即 `Point.mk : Π (X : Sort 0), Π (x : X), Π (y : X), Point X`。

对于 Prod：

```text
make_constructor_type(StructureInfo(Prod, Prod.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Sort(level 0))
  ], [
    FieldInfo(a, Var A),
    FieldInfo(b, Var B)
  ]))
```

telescope = `[(A, Sort(level 0)), (B, Sort(level 0)), (a, Var A), (b, Var B)]`

body = `make_type_app(Prod, [A, B])` = `(Const Prod) (Var A) (Var B)`

结果：

```text
Π (A : Sort 0),
Π (B : Sort 0),
Π (a : A),
Π (b : B),
Prod A B
```

### 6.5 `make_recursor_type`                                  【v11 新增】

`make_recursor_type` 把一个 nullary inductive 的**消去原则**翻译成 CoreTerm 类型。

假设：

```text
T : Sort 0

ctor_0 : T
ctor_1 : T
...
ctor_n : T
```

我们的目标是生成一个函数：给定关于 `T` 中元素的某个性质，以及这个性质在每个构造子上成立的证明，就能对任意 `target : T` 得到该性质的证明。

这里的“性质”由 motive 表示：

```text
motive : Π (_ : T), Sort 0
```

`motive t` 可以理解为“关于 `t : T` 想要证明或构造的类型”。它允许结果类型依赖具体的 `t`，所以 recursor 是依值的消去器，而不只是普通的分支选择函数。

接下来，每个构造子都需要一个对应的 case：

```text
case_0 : motive ctor_0
case_1 : motive ctor_1
...
case_n : motive ctor_n
```

这些 case 说明 motive 对所有可能的构造方式都成立。由于 v11 的构造子都是 nullary，没有构造子参数，所以每个 case 目前只是一个值；还不需要额外的参数或 induction hypothesis。

最后给出：

```text
target : T
```

recursor 应返回：

```text
motive target
```

把这些输入按顺序组成 Π 链，就得到：

```text
Π (motive : Π (_ : T), Sort 0),
Π (case_0 : motive ctor_0),
...
Π (case_n : motive ctor_n),
Π (target : T),
  motive target
```

所以代码的构造过程可以读成四步：

1. 创建 motive binder；
2. 按构造子声明顺序创建所有 case binder；
3. 创建 target binder；
4. 把 `motive target` 作为整条 Π 链的 body。

```python
# 写作 make_recursor_type(info)
def make_recursor_type(info : InductiveInfo) -> CoreTerm:
    '''
    为 nullary inductive 生成 recursor 类型：

      Π (motive : Π (_ : T), Sort 0),
      Π (case_0 : motive ctor_0),
      ...
      Π (target : T),
        motive target
    '''
    motiveName = recursor_binder_name(MotiveTag)
    motiveArg  = recursor_binder_name(MotiveArgTag)
    targetName = recursor_binder_name(TargetTag)

    motiveType = Forall(
        motiveArg,
        Const(info.typeName),
        Sort(level 0)
    )

    telescope = [Pair(motiveName, motiveType)]

    for i, ctorName in enumerate(info.constructors):
        caseName = recursor_binder_name(CaseTag(i))
        caseType = App(Var(motiveName), Const(ctorName))
        telescope.append(Pair(caseName, caseType))

    telescope.append(Pair(targetName, Const(info.typeName)))
    body = App(Var(motiveName), Var(targetName))

    return make_forall_chain(telescope, body)
```

对于：

```text
InductiveInfo(Bool, [Bool.false, Bool.true], Bool.rec)
```

生成：

```text
Π (motive : Π (_ : Bool), Sort 0),
Π (case_0 : motive Bool.false),
Π (case_1 : motive Bool.true),
Π (target : Bool),
  motive target
```

对 Bool 而言，这个类型表达的是：

> 要处理任意 `target : Bool`，先告诉我目标类型族 `motive`；再分别告诉我 `target = Bool.false` 和 `target = Bool.true` 时应该得到什么；我就能返回 `motive target`。

例如定义 `not` 时选择常值 motive：

```text
motive = fun (_ : Bool) => Bool
```

于是：

```text
case_0 : motive Bool.false  定义相等于 Bool
case_1 : motive Bool.true   定义相等于 Bool
```

分别传入 `Bool.true` 和 `Bool.false`，就得到：

```text
Bool.rec motive Bool.true Bool.false target : Bool
```

`make_recursor_type` 只负责生成上述**类型**，不负责执行分支。真正的计算行为由 §12.3 的 iota reduction 提供：target 是第 `i` 个构造子时，完整 recursor 应用规约到 `case_i`。

`recursor_binder_name` 保证所有自动 binder 名互不相同，并使生成结果具有确定性。v11 的 motive 结果固定为 `Sort(level 0)`；universe-polymorphic elimination 和 large-elimination 限制留到后续版本。

### 6.6 评论

五个类型生成辅助函数的关键特性：

1. **只构建 CoreTerm**：不调用 `elab`、`whnf`、`infer_type`。它们是纯粹的 term 构建器。

2. **ParamInfo.type 和 FieldInfo.type 中的 Var 被 Forall binder 正确绑定**：`make_forall_chain` 生成的 Forall 链中，每个参数/字段名对应一个 Forall binder。例如 `ParamInfo(B, Forall(x, Var A, Sort(level 0)))` 中的 `Var A` 被外层 `Forall(A, ...)` 绑定；`FieldInfo(b, App(Var B, Var a))` 中的 `Var B` 和 `Var a` 分别被对应的 Forall binder 绑定。生成的类型是**closed CoreTerm** — 所有 Var 都被 binder 绑定，没有自由变量。

3. **constructor 返回类型的构建**：`make_type_app(typeName, paramNames)` 只引用参数名（不引用字段名）。因为构造子应用到参数后返回 `(Const typeName) params...`，字段值是在更内层的 Forall binder 下才提供的。

4. **exec 调用这些函数时，ParamInfo.type 和 FieldInfo.type 已经是 elaborated 的 CoreTerm**：用户在 StructureCmd 中写的是 SurfaceTerm（ParamDecl/FieldDecl），exec 先 elaborates 每个类型得到 CoreTerm，然后构建 ParamInfo/FieldInfo，最后调用 make_structure_type 和 make_constructor_type。

5. **recursor 类型生成也是纯构建过程**：`make_recursor_type` 只读取 `InductiveInfo` 并构造 CoreTerm，不调用 `elab`、`infer_type` 或 `whnf`。生成结果由 `exec(InductiveCmd)` 统一验证后才写入 State。

---
## 7. 顶层命令 `Command`

`ParamDecl` 和 `FieldDecl` 与 v10 相同。v11 新增 `ConstructorDecl`：

```text
class ParamDecl:
    name : LocalName
    type : SurfaceTerm        # 用户写的表层参数类型

class FieldDecl:
    name : LocalName
    type : SurfaceTerm        # 用户写的表层字段类型

class ConstructorDecl:
    name : LocalName          # 构造子的短名字，如 false、true          【v11 新增】
```

**评论：** ParamDecl 和 FieldDecl 是 StructureCmd 的组成部分。它们的 type 是 SurfaceTerm（用户写表层语法），与 kernel 层的 ParamInfo/FieldInfo（type 是 CoreTerm 模板）对应。exec 会把前者 elaborate 成后者。

为了让例子更简洁，约定在 `InductiveCmd` 的 `constructors` 列表中：

```text
[false, true]
```

是以下正式写法的元语言缩写：

```text
[ConstructorDecl(false), ConstructorDecl(true)]
```

一般地，列表中的短名字 `c` 缩写 `ConstructorDecl(c)`；需要强调数据结构本身时，仍写完整形式。

定义数据类型 `Command`：

```text
Command = AxiomCmd(name : GlobalName, term : SurfaceTerm)              # 写作 AxiomCmd n : A
        | DefCmd(name : GlobalName, term1 : SurfaceTerm, term2 : SurfaceTerm) # 写作 DefCmd n A t
        | StructureCmd(typeName : GlobalName, constructor : GlobalName,       # 写作 StructureCmd T T.mk params fields
            params : List[ParamDecl], fields : List[FieldDecl])
        | InductiveCmd(typeName : GlobalName, constructors : List[ConstructorDecl])
                                                                         # 写作 InductiveCmd T constructors  【v11 新增】
```

写作约定例子：

```text
StructureCmd Point Point.mk
  params = [X : Sort 0]
  fields = [x : X, y : X]
```

这意味着：声明一个 structure 名为 Point，构造子为 Point.mk，一个参数 X : Sort 0，两个字段 x : X, y : X。

v11 的归纳类型命令例如：

```text
InductiveCmd Bool
  constructors = [false, true]
```

`exec` 会用 `append_local` 生成完整名字 `Bool.false`、`Bool.true` 和 `Bool.rec`。`ConstructorDecl` 当前没有参数类型字段，这精确表达了 v11 的边界：只能声明 nullary constructors。v12 加入递归构造子时，再扩展这一数据类型。

因此 v11 也能表达：

```text
InductiveCmd Empty constructors = []
InductiveCmd Unit  constructors = [unit]
```

但不能表达 `Nat.succ : Nat → Nat`。

**评论：** StructureCmd 是 v9 的核心新增。它让用户声明一个 structure，exec 会自动生成 type constructor 的类型签名、constructor 的类型签名，以及 StructureInfo。用户必须同时给出 typeName 和 constructor 名字（如 Point 和 Point.mk）— 这避免了自动命名策略的复杂性。

用户写 `SurfaceTerm`；`exec` 会先通过 `elab` 转换为 `CoreTerm` 再存储。

---
## 8. `Context`

定义上下文类型 `Context`：

```text
class Context:
    Types : PartialMap[n : LocalName, t : CoreTerm]   # 写作 n : t
```

若 `Γ : Context`，则 `Γ.Types` 表示这个上下文中记录局部变量类型的映射。

### 8.1 上下文扩展

```python
# 写作 Γ, x : A
# 也写作 expand_context(Γ, x, A)
def expand_context(Γ : Context, x : LocalName, A : CoreTerm) -> Context:
    return Context(
        Types = Γ.Types[x -> A]
    )
```

---
## 9. 状态执行函数 `exec`

> **前向引用说明：** `exec` 内部调用以下函数，它们都在文档后面才详细定义。这里给出每个函数的简要功能，阅读时可将它们视为已定义的操作：
>
> | 函数 | 简要功能 | 详细定义 |
> |------|---------|---------|
> | `elab(S, Γ, st, expected)` | 将 SurfaceTerm 转换为 CoreTerm（elaboration） | §15 |
> | `infer_type(S, Γ, t)` | 推断 CoreTerm 的类型 | §14.3 |
> | `check_type(S, Γ, t, A)` | 检查 CoreTerm 是否具有给定类型 | §14.3 |
> | `whnf(S, t)` | 弱头部正规化（化简 term） | §12 |
>
> 文档按依赖关系的反向顺序组织：先定义底层 kernel 函数（`whnf`、`defeq`、`infer_type`），再定义上层（`elab`、`exec`）。`exec` 紧跟在 `Command`（§7）定义之后，便于读者理解命令如何执行。

定义一个部分函数：

```text
exec(S : State, cmd : Command) -> State
```

定义名字占用辅助函数：

```python
# 写作 declaration_name_is_used(S, n)
def declaration_name_is_used(S : State, n : GlobalName) -> Bool:
    return (
        S.Axioms.contains(n)
        or S.Defs.contains(n)
        or S.Projections.contains(n)
    )
```

`Structures`、`Inductives` 和 `Recursors` 不单独加入这个判断，因为它们的 key 已经同时存在于 `Axioms`；三者都是声明的附加元数据，不是独立名字空间。

### 9.1 状态转移记号

约定：

```text
S --cmd--> S'
```

作为 `exec(S, cmd) = S'` 的简写。

### 9.2 规则 1：执行 `AxiomCmd`

若：

```text
cmd = AxiomCmd(n, A_surf)
A_core = elab(S, ∅, A_surf, None)
infer_type(S, ∅, A_core) : Sort u                    （声明的类型本身必须是 type）
not declaration_name_is_used(S, n)
```

则：

```text
exec(S, cmd) = S'
```

其中：

```text
S' = State(
    Axioms = S.Axioms.set(n, A_core),
    Defs   = S.Defs,
    Structures = S.Structures,
    Projections = S.Projections,
    Inductives = S.Inductives,
    Recursors = S.Recursors
)
```

**评论：** `infer_type(S, ∅, A_core) : Sort u` 确保声明的类型本身是一个 type。否则用户可以错误地声明 `AxiomCmd bad : Const zero` — `Const zero : Const Nat` 不是 type。`declaration_name_is_used` 还保证新名字不会占用已有的 axiom、def 或 projection 名。

### 9.3 规则 2：执行 `DefCmd`

若：

```text
cmd = DefCmd(n, A_surf, t_surf)
A_core = elab(S, ∅, A_surf, None)
infer_type(S, ∅, A_core) : Sort u                    （声明的类型本身必须是 type）
t_core = elab(S, ∅, t_surf, A_core)
not declaration_name_is_used(S, n)
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
    Defs   = S.Defs.set(n, Pair(A_core, t_core)),
    Structures = S.Structures,
    Projections = S.Projections,
    Inductives = S.Inductives,
    Recursors = S.Recursors
)
```

### 9.4 规则 3：执行 `StructureCmd`

若：

```text
cmd = StructureCmd(typeName, constructor, param_decls, field_decls)
typeName ≠ constructor
not declaration_name_is_used(S, typeName)
not declaration_name_is_used(S, constructor)
```

执行分五步：

**第一步：名字检查** — `typeName ≠ constructor`（避免同名导致状态更新时覆盖），且 `typeName` 和 `constructor` 不与已有全局名字冲突。

**第二步：Telescope 检查** — 逐个 elaborate params 和 fields 的类型，在每个步骤中验证类型是 Sort，并在扩展上下文中处理后续项。

```text
Γ0 = ∅

对于 param_decls 中的每个 ParamDecl(p_i : LocalName, T_i_surf : SurfaceTerm):
  T_i_core = elab(S, Γ_i, T_i_surf, None)
  whnf(S, infer_type(S, Γ_i, T_i_core)) 必须是 Sort u_i
  Γ_{i+1} = Γ_i, p_i : T_i_core

对于 field_decls 中的每个 FieldDecl(f_j : LocalName, F_j_surf : SurfaceTerm):
  F_j_core = elab(S, Γ_{n+j}, F_j_surf, None)
  whnf(S, infer_type(S, Γ_{n+j}, F_j_core)) 必须是 Sort v_j
  Γ_{n+j+1} = Γ_{n+j}, f_j : F_j_core
```

其中 `n = len(param_decls)`。注意 fields 的 elaboration 在扩展了所有 params 的上下文中进行 — 这保证了依值类型（如 `b : B a` 中 `B` 引用前序参数 `A`、`a` 引用前序字段 `a`）的正确性。

**第三步：类型生成** — 构建 StructureInfo，然后调用 `make_structure_type` 和 `make_constructor_type`（§6）。

```text
info = StructureInfo(
  typeName    = typeName,
  constructor = constructor,
  params      = [ParamInfo(p_i, T_i_core) for each param],
  fields      = [FieldInfo(f_j, F_j_core) for each field]
)

type_type = make_structure_type(info)

# 验证 type_type 本身是一个 type
whnf(S, infer_type(S, ∅, type_type)) 必须是 Sort u₁

# constructor_type 的返回类型中引用 Const typeName，
# 所以先临时加入 typeName，再验证 constructor_type
S_tmp = State(
    Axioms = S.Axioms.set(typeName, type_type),
    Defs = S.Defs,
    Structures = S.Structures,
    Projections = S.Projections,
    Inductives = S.Inductives,
    Recursors = S.Recursors
)
constructor_type = make_constructor_type(info)

whnf(S_tmp, infer_type(S_tmp, ∅, constructor_type)) 必须是 Sort u₂
```

**第四步：生成 ProjectionInfo** — 为每个字段生成投影信息。

```text
proj_infos = {}
for field_index, field in enumerate(info.fields):
    proj_name = append_local(info.typeName, field.name)
    if declaration_name_is_used(S, proj_name)
       or proj_name = typeName
       or proj_name = constructor:
        raise Error
    proj_infos[proj_name] = ProjectionInfo(proj_name, info.typeName, field_index)
```

**评论：** 第四步为每个字段生成唯一的投影名（如 `Sigma.a`、`Sigma.b`），并将 `ProjectionInfo` 写入 `S.Projections`。这使得后续 `SProj` 和 `SDot` 的 elaboration 可以通过投影名查找到结构名和字段下标。

**第五步：状态更新**

```text
S' = State(
    Axioms      = S_tmp.Axioms.set(constructor, constructor_type),
    Defs        = S.Defs,
    Structures  = S.Structures.set(typeName, info),
    Projections = merge(S.Projections, proj_infos),
    Inductives  = S.Inductives,
    Recursors   = S.Recursors
)
```

**评论：**

- StructureCmd 是 State 生成器，不产生 CoreTerm。它修改 State（加两个 Axiom、一个 StructureInfo 和每个字段的 ProjectionInfo），之后所有已有的 kernel 规则自动生效。
- Telescope 检查保证 §5.2a 的 well-formedness invariant：每个 param/field 类型在正确的上下文中 elaborated，确保类型正确、引用合法。
- 第三步生成并验证 `make_structure_type(info)` 与 `make_constructor_type(info)`，第五步再将两者和 `StructureInfo` 原子写入 State，因此保证 §5.2b 的 State-level invariant。
- 字段类型的 elaboration 在包含所有参数的上下文中进行。例如 `b : B a` 中，`B` 和 `a` 都可以在上下文中找到 — `B` 是参数名（在前面的 Γ 扩展中加入），`a` 是前序字段名（在更前面的 Γ 扩展中加入）。这正是 telescope 的含义：参数和字段组成一个逐步扩展的上下文链。
- `make_structure_type` 和 `make_constructor_type` 在 §6 定义，只依赖 CoreTerm 和 StructureInfo。它们不调用 elab/whnf/infer_type。
- 第三步新增对生成类型的验证：`type_type` 和 `constructor_type` 都必须通过 `infer_type` 检查（结果必须是 Sort）。`constructor_type` 的返回类型中引用 `Const typeName`，所以需要先临时将 `typeName` 加入状态，才能正确验证 `constructor_type`。这防止了 `make_constructor_type` 的潜在 bug 导致 ill-typed 的 constructor type 被写入 Axioms。

### 9.5 规则 4：执行 `InductiveCmd`                           【v11 新增】

本节给出通用执行规则；以 `Bool` 为输入的完整四步推导见 §17.5。

若：

```text
cmd = InductiveCmd(typeName, constructor_decls)
not declaration_name_is_used(S, typeName)
```

执行分四步。

**第一步：生成名字并检查冲突**

```text
recursor_name = append_local(typeName, rec)
ctor_names = [
  append_local(typeName, decl.name)
  for decl in constructor_decls
]
```

要求：

- `ctor_names` 互不相同；
- `recursor_name` 不等于任何构造子名；
- `typeName`、`recursor_name` 和所有构造子名都没有被当前 State 占用。

**第二步：生成元数据和声明类型**

```text
info = InductiveInfo(typeName, ctor_names, recursor_name)
rec_info = RecursorInfo(recursor_name, typeName, ctor_names)

type_type = Sort(level 0)
ctor_types[ctorName] = Const(typeName)       # 每个构造子都是 nullary
recursor_type = make_recursor_type(info)
```

**第三步：在临时 State 中验证生成类型**

先验证 `type_type` 本身是 type，再把 `typeName` 和所有构造子临时加入 `Axioms`。构造子类型必须能推断出 Sort；最后生成并验证 recursor 类型：

```text
whnf(S, infer_type(S, ∅, type_type)) 必须是 Sort

S_tmp.Axioms = S.Axioms.set(typeName, type_type)
对每个 ctorName：
  ctor_type = Const(typeName)
  whnf(S_tmp, infer_type(S_tmp, ∅, ctor_type)) 必须是 Sort
  S_tmp.Axioms = S_tmp.Axioms.set(ctorName, ctor_type)

recursor_type = make_recursor_type(info)
whnf(S_tmp, infer_type(S_tmp, ∅, recursor_type)) 必须是 Sort
```

**第四步：原子状态更新**

```text
S' = State(
    Axioms      = S_tmp.Axioms.set(recursor_name, recursor_type),
    Defs        = S.Defs,
    Structures  = S.Structures,
    Projections = S.Projections,
    Inductives  = S.Inductives.set(typeName, info),
    Recursors   = S.Recursors.set(recursor_name, rec_info)
)
```

构造临时状态不会修改输入 `S`；只有所有检查成功后才返回 `S'`。因此 `InductiveCmd` 与其他命令一样具有原子性。

### 9.6 `exec` 完整代码                                      【v11 修改】

```python
# 写作 exec(S, cmd)
def exec(S: State, cmd: Command) -> State:
    '''
    执行顶层命令并返回更新后的状态。
    Command 中的 term 是 SurfaceTerm，需要先通过 elab 转换为 CoreTerm。
    v9：exec 新增 StructureCmd 分支；
    v10：StructureCmd 还会生成 ProjectionInfo；
    AxiomCmd / DefCmd 不修改任何元数据映射；
    StructureCmd 会新增 typeName、constructor（Axioms）、
    StructureInfo（Structures）和字段投影元数据（Projections）；
    v11 的 InductiveCmd 会新增类型、构造子、recursor 及对应元数据。
    '''

    if isinstance(cmd, AxiomCmd):
        n, A_surf = cmd.args
        A_core = elab(S, ∅, A_surf, None)
        TA = whnf(S, infer_type(S, ∅, A_core))
        if not isinstance(TA, Sort):
            raise Error
        if not declaration_name_is_used(S, n):
            return State(
                Axioms = S.Axioms.set(n, A_core),
                Defs   = S.Defs,
                Structures = S.Structures,
                Projections = S.Projections,
                Inductives = S.Inductives,
                Recursors = S.Recursors
            )
        raise Error

    elif isinstance(cmd, DefCmd):
        n, A_surf, t_surf = cmd.args
        A_core = elab(S, ∅, A_surf, None)
        TA = whnf(S, infer_type(S, ∅, A_core))
        if not isinstance(TA, Sort):
            raise Error
        t_core = elab(S, ∅, t_surf, A_core)
        if declaration_name_is_used(S, n):
            raise Error
        if not check_type(S, ∅, t_core, A_core):
            raise Error
        return State(
            Axioms = S.Axioms,
            Defs = S.Defs.set(n, Pair(A_core, t_core)),
            Structures = S.Structures,
            Projections = S.Projections,
            Inductives = S.Inductives,
            Recursors = S.Recursors
        )

    elif isinstance(cmd, StructureCmd):
        typeName, constructor, param_decls, field_decls = cmd.args

        # 第一步：名字检查
        if typeName == constructor:
            raise Error                    # typeName 和 constructor 不能相同
        if declaration_name_is_used(S, typeName):
            raise Error
        if declaration_name_is_used(S, constructor):
            raise Error

        # 第二步：Telescope 检查 — 逐个 elaborate param/field 类型
        # 同时检查所有 param/field 名字互不重复
        Γ = Context(Types={})
        used_names = set()
        param_infos = []
        for p_decl in param_decls:
            if p_decl.name in used_names:
                raise Error                # 参数名不能与已有名字重复
            used_names.add(p_decl.name)
            T_core = elab(S, Γ, p_decl.type, None)
            T_type = whnf(S, infer_type(S, Γ, T_core))
            if not isinstance(T_type, Sort):
                raise Error
            param_infos.append(ParamInfo(p_decl.name, T_core))
            Γ = expand_context(Γ, p_decl.name, T_core)

        field_infos = []
        for f_decl in field_decls:
            if f_decl.name in used_names:
                raise Error                # 字段名不能与参数名或其他字段名重复
            used_names.add(f_decl.name)
            F_core = elab(S, Γ, f_decl.type, None)
            F_type = whnf(S, infer_type(S, Γ, F_core))
            if not isinstance(F_type, Sort):
                raise Error
            field_infos.append(FieldInfo(f_decl.name, F_core))
            Γ = expand_context(Γ, f_decl.name, F_core)

        # 第三步：类型生成 + 验证
        info = StructureInfo(typeName, constructor, param_infos, field_infos)
        type_type = make_structure_type(info)

        # 验证 type_type 本身是一个 type
        T_type_type = whnf(S, infer_type(S, ∅, type_type))
        if not isinstance(T_type_type, Sort):
            raise Error

        # constructor_type 的返回类型中引用 Const typeName，
        # 所以先临时加入 typeName，再验证 constructor_type
        S_tmp = State(
            Axioms = S.Axioms.set(typeName, type_type),
            Defs = S.Defs,
            Structures = S.Structures,
            Projections = S.Projections,
            Inductives = S.Inductives,
            Recursors = S.Recursors
        )
        constructor_type = make_constructor_type(info)

        T_constructor_type = whnf(S_tmp, infer_type(S_tmp, ∅, constructor_type))
        if not isinstance(T_constructor_type, Sort):
            raise Error

        # 第四步：生成 ProjectionInfo
        proj_infos = {}
        for idx, field in enumerate(field_infos):
            proj_name = append_local(typeName, field.name)
            if (declaration_name_is_used(S, proj_name)
                    or proj_name == typeName
                    or proj_name == constructor):
                raise Error
            proj_infos[proj_name] = ProjectionInfo(proj_name, typeName, idx)

        # 第五步：状态更新
        return State(
            Axioms      = S_tmp.Axioms.set(constructor, constructor_type),
            Defs        = S.Defs,
            Structures  = S.Structures.set(typeName, info),
            Projections = merge(S.Projections, proj_infos),
            Inductives  = S.Inductives,
            Recursors   = S.Recursors
        )

    elif isinstance(cmd, InductiveCmd):
        typeName, constructor_decls = cmd.args

        # 第一步：生成名字并检查冲突
        if declaration_name_is_used(S, typeName):
            raise Error

        recursor_name = append_local(typeName, rec)
        if declaration_name_is_used(S, recursor_name):
            raise Error

        ctor_names = []
        for decl in constructor_decls:
            ctor_name = append_local(typeName, decl.name)
            if declaration_name_is_used(S, ctor_name):
                raise Error
            if ctor_name == recursor_name or ctor_name in ctor_names:
                raise Error
            ctor_names.append(ctor_name)

        # 第二步：生成元数据和声明类型
        info = InductiveInfo(typeName, ctor_names, recursor_name)
        rec_info = RecursorInfo(recursor_name, typeName, ctor_names)
        type_type = Sort(level 0)

        # 第三步：在临时 State 中验证生成类型
        T_type_type = whnf(S, infer_type(S, ∅, type_type))
        if not isinstance(T_type_type, Sort):
            raise Error

        S_tmp = State(
            Axioms = S.Axioms.set(typeName, type_type),
            Defs = S.Defs,
            Structures = S.Structures,
            Projections = S.Projections,
            Inductives = S.Inductives,
            Recursors = S.Recursors
        )

        for ctor_name in ctor_names:
            ctor_type = Const(typeName)
            T_ctor_type = whnf(S_tmp, infer_type(S_tmp, ∅, ctor_type))
            if not isinstance(T_ctor_type, Sort):
                raise Error
            S_tmp = State(
                Axioms = S_tmp.Axioms.set(ctor_name, ctor_type),
                Defs = S_tmp.Defs,
                Structures = S_tmp.Structures,
                Projections = S_tmp.Projections,
                Inductives = S_tmp.Inductives,
                Recursors = S_tmp.Recursors
            )

        recursor_type = make_recursor_type(info)
        T_recursor_type = whnf(S_tmp, infer_type(S_tmp, ∅, recursor_type))
        if not isinstance(T_recursor_type, Sort):
            raise Error

        # 第四步：原子状态更新
        return State(
            Axioms = S_tmp.Axioms.set(recursor_name, recursor_type),
            Defs = S.Defs,
            Structures = S.Structures,
            Projections = S.Projections,
            Inductives = S.Inductives.set(typeName, info),
            Recursors = S.Recursors.set(recursor_name, rec_info)
        )

    raise Error
```

（关于 `elab` 和 `infer_type` 的前向引用说明见 §9 开头。）

---
## 10. 初始状态与结构缩写

### 10.1 初始状态 S₀

v9 不再预置任何结构。初始状态为空：

```text
S₀.Axioms = {}
S₀.Defs = {}
S₀.Structures = {}
S₀.Projections = {}
S₀.Inductives = {}
S₀.Recursors = {}
```

所有结构（包括 Sigma 和 Prod）都通过 StructureCmd 定义（见 §17）。

为后续引用方便，取全局名字：

```text
Sigma, Sigma.mk, Prod, Prod.mk : GlobalName
Bool, Bool.false, Bool.true, Bool.rec : GlobalName
```

前四个名字在 StructureCmd 中由用户提供。`Bool.false`、`Bool.true` 和 `Bool.rec` 由 `InductiveCmd Bool` 自动生成。要求这些名字互不相同。

当前模型暂时**不引入** `Sigma.fst / Sigma.snd / Prod.fst / Prod.snd`。因为 `Proj(Sigma, 0, p)` 和 `Proj(Sigma, 1, p)` 已经表达了投影。

### 10.2 `Sigma` 与 `Sigma.mk` 的类型

为避免 universe polymorphism，当前模型使用单宇宙版本。以下类型由 StructureCmd Sigma 自动生成（完整推导见 §17.1），此处列出供参考：

```text
Sigma : Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Sort 0
Sigma.mk : Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Π (a : A), Π (b : B a), Sigma A B
```

含义：给定 `A : Sort 0` 和 `B : Π (x : A), Sort 0`，得到 `Sigma A B : Sort 0`。给定 `a : A` 和 `b : B a`，得到 `Sigma.mk A B a b : Sigma A B`。

**评论：** 完整 Lean 版本的 `Sigma` 是 universe-polymorphic 且有 implicit arguments。当前模型没有这些机制，所以用单宇宙显式版本。

### 10.3 缩写：SΣ 与 SΣΠ

定义方便缩写：

```text
SΣ  = exec(S₀, StructureCmd Sigma Sigma.mk
  params = [A : SSort 0, B : SForall(x, SVar A, SSort 0)]
  fields = [a : SVar A, b : SApp(SVar B, SVar a)])      （完整推导见 §17.1）

SΣΠ = exec(SΣ, StructureCmd Prod Prod.mk
  params = [A : SSort 0, B : SSort 0]
  fields = [a : SVar A, b : SVar B])                     （完整推导见 §17.2）
```

SΣ 的内容（供参考）：

```text
SΣ.Axioms = {
  Sigma :
    Π (A : Sort (level 0)),
    Π (B : Π (x : Var A), Sort (level 0)),
    Sort (level 0),

  Sigma.mk :
    Π (A : Sort (level 0)),
    Π (B : Π (x : Var A), Sort (level 0)),
    Π (a : Var A),
    Π (b : (Var B) (Var a)),
    (Const Sigma) (Var A) (Var B)
}

SΣ.Defs = {}
SΣ.Projections = {
  Sigma.a : ProjectionInfo(Sigma.a, Sigma, 0),
  Sigma.b : ProjectionInfo(Sigma.b, Sigma, 1)
}
SΣ.Inductives = {}
SΣ.Recursors = {}

SΣ.Structures = {
  Sigma : StructureInfo(Sigma, Sigma.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Π (x : Var A), Sort(level 0))
  ], [
    FieldInfo(a, Var A),
    FieldInfo(b, App(Var B, Var a))
  ])
}
```

**评论：** `Sigma` 不是模型宇宙里自动存在的魔法对象。v9 中 `Sigma` 的类型签名和 StructureInfo 由 `exec(StructureCmd Sigma Sigma.mk ...)` 自动生成 — 不再预置。这类似于 Lean 的 prelude，但 prelude 中的结构声明在 v9 中由 StructureCmd 显式执行，而非隐式硬编码。

---
## 11. FV 与 substitution

FV（自由变量）和 substitution（替换）是 CoreTerm 上的两个基本操作，合称 term 的"变量基础设施"。

- **FV(t)**：收集 term `t` 中所有未被 binder 绑定的变量名。例如 `FV(Lam(x, A, Var x)) = FV(A)`，因为 `x` 被 `Lam` 的 binder 绑定，从自由变量集中移除。
- **subst(t, x, e)**：把 `t` 中自由出现的变量 `x` 全部替换为 `e`。例如 `subst(Var x, x, Const zero) = Const zero`。

两者紧密关联：subst 的 binder 分支（Lam、Forall）需要调用 FV 来判断是否需要 alpha-rename 以避免**变量捕获**。具体来说，当替换 `subst(Lam(y, A, body), x, e)` 且 `y ≠ x` 时，如果 `y` 出现在 `FV(e)` 中（即替换项 `e` 包含一个与 binder 同名的自由变量），直接替换会使得 `e` 中原本自由的 `y` 被 binder `y`"捕获"，改变其语义。此时必须先把 binder 改名为一个新名字，再进行替换。

### 11.1 `FV`

计算 CoreTerm 的自由变量集合。

```python
# 写作 FV(t)
def FV(t : CoreTerm) -> Set[LocalName]:
    if isinstance(t, Const):
        return ∅


    if isinstance(t, Sort):
        return ∅


    if isinstance(t, Var):
        x = t.args              # t = Var x
        return {x}


    if isinstance(t, App):
        f, a = t.args           # t = App(f, a)
        return FV(f) ∪ FV(a)


    if isinstance(t, Lam):
        x, A, body = t.args     # t = Lam(x, A, body)
        return FV(A) ∪ (FV(body) \ {x})


    if isinstance(t, Forall):
        x, A, B = t.args        # t = Forall(x, A, B)
        return FV(A) ∪ (FV(B) \ {x})


    if isinstance(t, Proj):
        structName, index, target = t.args  # t = Proj(structName, index, target)
        return FV(target)
```

**评论：** v7 只有 7 个构造子，只有 `Lam` 和 `Forall` 有 binder — FV 的定义极为简洁。`Proj` 的 FV 就是其 `target` 的 FV，`structName` 和 `index` 不贡献自由变量。v6 中 `CSigma`（binder）、`CPairTyped`（binder + 四个子 term）、`CFst`/`CSnd` 各需要一个分支，在 v7 中全部消失。

### 11.2 例子（FV）

```text
FV(Const Nat) = ∅
FV(Var x) = {x}
FV(App(Var x, Var y)) = {x, y}
FV(Lam(x, Sort(level 0), Var x)) = ∅
FV(Forall(x, Sort(level 0), Var x)) = ∅
FV(Proj(Sigma, 0, Var x)) = {x}
FV(Proj(Sigma, 1, App(Const f, Var y))) = {y}
```

---
### 11.3 substitution

替换 term 中某个自由变量的所有出现。

```python
# 写作 subst(t, x, e)
# 也写作 t[x := e]
def subst(t: CoreTerm, x: LocalName, e: CoreTerm) -> CoreTerm:
    '''
    在 t 中，把自由出现的 x 替换为 e
    '''


    if isinstance(t, Const):
        return t


    if isinstance(t, Sort):
        return t


    if isinstance(t, Var):
        y = t.args              # t = Var y
        if y == x:
            return e
        return t


    if isinstance(t, App):
        f, a = t.args           # t = App(f, a)
        return App(
            subst(f, x, e),
            subst(a, x, e)
        )


    if isinstance(t, Lam):
        y, A, body = t.args     # t = Lam(y, A, body)


        A1 = subst(A, x, e)


        if y == x:
            return Lam(y, A1, body)


        if y not in FV(e):
            return Lam(
                y,
                A1,
                subst(body, x, e)
            )


        z = fresh_local_name(FV(body) ∪ FV(e) ∪ {x, y})
        body1 = alpha_rename_binder(body, y, z)
        return Lam(
            z,
            A1,
            subst(body1, x, e)
        )


    if isinstance(t, Forall):
        y, A, B = t.args        # t = Forall(y, A, B)


        A1 = subst(A, x, e)


        if y == x:
            return Forall(y, A1, B)


        if y not in FV(e):
            return Forall(
                y,
                A1,
                subst(B, x, e)
            )


        z = fresh_local_name(FV(B) ∪ FV(e) ∪ {x, y})
        B1 = alpha_rename_binder(B, y, z)
        return Forall(
            z,
            A1,
            subst(B1, x, e)
        )


    if isinstance(t, Proj):
        structName, index, target = t.args  # t = Proj(structName, index, target)
        return Proj(structName, index, subst(target, x, e))
```

**评论：** v7 的 subst 只需要处理 `Lam` 和 `Forall` 的 binder 捕获问题 — 7 个构造子中只有这两个有 binder。`Proj` 的 subst 只是递归替换 `target`，`structName` 和 `index` 不受替换影响。`App` 递归替换两边。v6 中 `CSigma`（binder）、`CPairTyped`（binder + 四个子 term）各需要一个完整分支，`CFst`/`CSnd` 各需要一个分支，在 v7 中全部消失。这是 v7 简化的一个核心体现。

这里用了两个辅助函数（与 v6 完全相同）：

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

### 11.4 例子（substitution）

```text
subst(Var x, x, Const Nat) = Const Nat
subst(Var y, x, Const Nat) = Var y
subst(App(Var x, Var y), x, Const Nat) = App(Const Nat, Var y)
subst(Lam(x, Sort(level 0), Var x), x, Const Nat)
= Lam(x, Sort(level 0), Var x)     # binder x 遮蔽了外部的 x
subst(Lam(y, Sort(level 0), Var x), x, Const Nat)
= Lam(y, Sort(level 0), Const Nat)
```

并且：

```text
subst(Lam(y, Sort(level 0), Var x), x, Var y)
```

不能直接得到：

```text
Lam(y, Sort(level 0), Var y)
```

因为这会发生变量捕获。应先把 binder `y` 改名为一个新名字 `z`，再替换，得到：

```text
Lam(z, Sort(level 0), Var y)
```

`Proj` 的 subst 例子：

```text
subst(Proj(Sigma, 0, Var x), x, Const zero) = Proj(Sigma, 0, Const zero)
subst(Proj(Sigma, 1, App(Const f, Var y)), y, Const zero)
= Proj(Sigma, 1, App(Const f, Const zero))
```



### 11.5 `subst_simul`（simultaneous substitution）

```python
# 写作 subst_simul(t, [(x1,e1), ..., (xn,en)])
def subst_simul(t : CoreTerm, substitutions : List[Pair[LocalName, CoreTerm]]) -> CoreTerm:
    '''
    Simultaneous substitution：一次性替换多个变量，避免逐个替换时
    后面的替换项干扰前面的替换结果。

    关键语义：subst_simul(Lam(y, A, Var x), [(x, Var y), (y, Const zero)])
    = Lam(z, A, Var y)  — x 被替换为 Var y，但此 Var y 不会被二次替换为 Const zero
    （因为替换是同时发生的，替换项 Var y 中的 y 不参与本次替换）。

    要求 substitutions 中的变量名互不相同。
    '''

    names = [name for name, replacement in substitutions]
    if len(set(names)) != len(names):
        raise Error

    if isinstance(t, Const) or isinstance(t, Sort):
        return t

    if isinstance(t, Var):
        x = t.args
        for name, replacement in substitutions:
            if x == name:
                return replacement
        return t

    if isinstance(t, App):
        f, a = t.args
        return App(
            subst_simul(f, substitutions),
            subst_simul(a, substitutions)
        )

    if isinstance(t, Proj):
        structName, index, target = t.args
        return Proj(
            structName,
            index,
            subst_simul(target, substitutions)
        )

    if isinstance(t, Lam):
        y, A, body = t.args
        A1 = subst_simul(A, substitutions)  # y 的作用域不包含 A
        body_substitutions = [
            Pair(name, replacement)
            for name, replacement in substitutions
            if name != y
        ]

        replacement_fv = ⋃ {
            FV(replacement)
            for name, replacement in body_substitutions
        }
        if y in replacement_fv:
            used = (
                FV(body)
                ∪ replacement_fv
                ∪ {name for name, replacement in body_substitutions}
                ∪ {y}
            )
            z = fresh_local_name(used)
            body = alpha_rename_binder(body, y, z)
            y = z

        return Lam(y, A1, subst_simul(body, body_substitutions))

    if isinstance(t, Forall):
        y, A, B = t.args
        A1 = subst_simul(A, substitutions)  # y 的作用域不包含 A
        body_substitutions = [
            Pair(name, replacement)
            for name, replacement in substitutions
            if name != y
        ]

        replacement_fv = ⋃ {
            FV(replacement)
            for name, replacement in body_substitutions
        }
        if y in replacement_fv:
            used = (
                FV(B)
                ∪ replacement_fv
                ∪ {name for name, replacement in body_substitutions}
                ∪ {y}
            )
            z = fresh_local_name(used)
            B = alpha_rename_binder(B, y, z)
            y = z

        return Forall(y, A1, subst_simul(B, body_substitutions))

    raise Error
```

其中 `⋃` 表示对有限集合族取并集。

**评论：** schema 变量名互不重复，并不足以保证逐个替换总是正确：实际参数或 `Proj(...)` 的 target 仍可能含有与其他 schema 变量同名的自由局部变量。`subst_simul` 确保每个变量只根据原 term 的结构替换一次，替换项本身不参与本轮替换。这是 `projection_type`（§13.3）正确性的保证。

---
## 12. 计算规则：`whnf`

`whnf`（weak head normal form）把 CoreTerm 化简到弱头部正规形式。自 v7 起 `whnf` 作用于 `CoreTerm` — 不再有 `Ann` 擦除分支（CoreTerm 中没有 `Ann`），不再有 `CFst`/`CSnd` 匹配 `CPairTyped` 的分支（这些构造子已不存在），取而代之的是 `Proj` 分支。

v11 在 `App` 分支中再加入 recursor iota reduction；CoreTerm 本身仍然不增加新构造子。

```text
whnf(S, t) -> CoreTerm
```

它只在 term 的**头部**进行必要的化简 — 不递归进入 body、参数等子结构。"weak" 指不深入内部，"head" 指只处理最外层的 redex。

**评论：** 为什么不直接加入完整的 normalization 或 definitional equality？因为 definitional equality 依赖 whnf — `defeq(S, Γ, A, B)` 的标准实现是把 A 和 B 都 whnf 后比较头部，再递归比较子项。所以 whnf 是 conversion 的基础构件，先加它是最自然的顺序。

**whnf 的核心直觉：** 一句话：**从外往里，一层一层剥**。

```
whnf(S, Proj(Sigma, 0, App(App(App(App(Const Sigma.mk, A), Bfun), a), b)))
```

第一步看到 `Proj`，需要先知道它的 target 是什么：

```
→ 先算 whnf(S, App(App(App(App(Const Sigma.mk, A), Bfun), a), b))
```

第二步看到 `App`，继续剥 — `Sigma.mk` 是 axiom，不能展开为函数，但 whnf 会继续剥 App 链，直到无法继续。如果 `Sigma.mk` 没有定义体，那么整个 App 链的 whnf 就是它本身：

```
→ 返回 App(App(App(App(Const Sigma.mk, A), Bfun), a), b)
```

回到 `Proj`：现在知道 target 的 whnf 是一个应用链了。检查 `S.Structures.get(Sigma)` 找到结构信息 `StructureInfo(constructor=Sigma.mk, params=[...], fields=[...])`。用 `collect_app` 拆分：head = `Const Sigma.mk`，args = `[A, Bfun, a, b]`。head 匹配构造子，index=0，field_pos = len(info.params) + index = 2 + 0 = 2，取出 args[2] = a。

```
→ 返回 whnf(S, a)
```

如果 `a` 本身已经是最简形式（比如 `Const zero`），就停了。结果：`Const zero`。

整个过程就像**剥洋葱** — 从最外层开始，遇到能化简的就化简，化简不动就停。不会主动去化简 `a` 内部的子结构（比如如果 `a` 是一个 `App`，whnf 不会碰它，除非它出现在新的头部位置）。

自 v7 起 `Proj` 规则是**通用的** — 它不硬编码 Sigma，而是通过 `S.Structures` 查找结构信息。这意味着将来添加新的 structure（如 Prod、Subtype 等），`whnf` 不需要任何修改，只需要在 `S.Structures` 中注册即可。

### 12.1 Const 的 delta reduction

如果 `n` 是一个定义名（即 `n ∈ S.Defs`），则展开它的 body：

```text
whnf(S, Const n) = whnf(S, body)     当 S.Defs.get(n) = (A, body)
whnf(S, Const n) = Const n           当 n ∉ S.Defs（即 n 是 axiom）
```

```python
if isinstance(t, Const):
    n = t.args
    if n in S.Defs:
        A, body = S.Defs.get(n)
        return whnf(S, body)
    return t
```

**评论：**

- 当前模型认为所有 `def` 都是透明的（transparent），可以展开。将来如果要更接近 Lean，需要加入 reducibility 属性（`reducible` / `semireducible` / `irreducible` / `opaque`），控制哪些定义可以被展开。
- 注意 axiom 不能展开 — 它没有 body。`Const Nat`、`Const zero` 等已经是 whnf。

### 12.2 App 的 beta reduction

如果函数部分 whnf 后是 lambda，则发生 beta reduction：

```text
whnf(S, App(f, a)) = whnf(S, body[x := a])    当 whnf(S, f) = Lam(x, A, body)
whnf(S, App(f, a)) 继续检查 iota                当 whnf(S, f) 不是 Lam
```

```python
if isinstance(t, App):
    f, a = t.args
    f0 = whnf(S, f)

    if isinstance(f0, Lam):
        x, A, body = f0.args
        return whnf(S, subst(body, x, a))

    # beta 不适用时，继续执行 §12.3 的 iota 检查
```

**评论：**

- Beta reduction 是 `Lam(x, A, body) a ↦ body[x := a]`。注意这里不先化简参数 `a` — 这是 **weak head** reduction 的特点：只化简头部到足够暴露结构，不化简参数或 body 内部。
- 如果 `f` whnf 后不是 `Lam`，beta reduction 不适用；此时进入 §12.3，检查完整应用链是否形成 recursor iota redex。

### 12.3 App 的 recursor iota reduction                       【v11 新增】

beta reduction 不适用时，把规约后的应用重新拆成 head 和参数列表。若 head 是已登记的 recursor、应用恰好完全饱和，并且最后一个参数规约为某个 nullary constructor，则选择相同位置的 case：

```text
whnf(S, (Const recName) motive case_0 ... case_n target)
  = whnf(S, case_i)

当：
  S.Recursors.get(recName) = recInfo
  recInfo.constructors[i] = ctorName
  whnf(S, target) = Const(ctorName)
  参数数量 = 2 + len(recInfo.constructors)
```

App 分支因此修改为：

```python
if isinstance(t, App):
    f, a = t.args
    f0 = whnf(S, f)

    if isinstance(f0, Lam):
        x, A, body = f0.args
        return whnf(S, subst(body, x, a))

    t0 = App(f0, a)
    head, args = collect_app(t0).args

    if isinstance(head, Const):
        recInfo = S.Recursors.get(head.args)
        if recInfo is not None:
            numCases = len(recInfo.constructors)
            if len(args) == numCases + 2:
                target0 = whnf(S, args[-1])
                if isinstance(target0, Const):
                    for i, ctorName in enumerate(recInfo.constructors):
                        if target0.args == ctorName:
                            return whnf(S, args[1 + i])

    return t0
```

参数顺序是 `[motive, case_0, ..., case_n, target]`，所以第 `i` 个构造子对应 `args[1 + i]`。部分应用、target 为变量、target 不是该 inductive 的构造子时都不化简。

该规则不硬编码 Bool；它完全由 `S.Recursors` 驱动。v12 支持带参数构造子后，target 将可能是 constructor application，届时 iota reduction 还需要把构造子参数传给相应 case。

### 12.4 Proj 的结构投影化简

如果被投影项 whnf 后是一个已知结构的构造子应用，则取出对应字段：

```text
whnf(S, Proj(structName, index, target))
  = whnf(S, args[len(info.params) + index])
      当 whnf(S, target) 展开后 head = Const(constructor)
        且 S.Structures.get(structName) 提供了结构信息 info
        且 args 的数量 == len(info.params) + len(info.fields)（构造子完整应用）
  = Proj(structName, index, whnf(S, target))
      当不满足上述条件
```

```python
if isinstance(t, Proj):
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
```

**评论：**

- 这个规则是**通用的** — 它通过 `S.Structures` 查找结构信息，不硬编码任何特定结构。对于 Sigma：`len(info.params)=2`（A 和 Bfun），`len(info.fields)=2`（a 和 b）。所以 `Proj(Sigma, 0, Sigma.mk A Bfun a b) → a`，`Proj(Sigma, 1, Sigma.mk A Bfun a b) → b`。对于 Prod：`len(info.params)=2`（A 和 B），`len(info.fields)=2`（a 和 b），规则完全相同。
- 检查 `index >= len(info.fields)` 防止越界访问。
- 检查 `len(args) != expected_arity` 防止对未完全应用（或过度应用）的构造子做投影。例如 `Proj(Sigma, 0, (Const Sigma.mk) A B a)` 缺少第二个字段 `b`，不应该被化简 — 返回 `Proj` 不化简。
- 如果 `structName` 不在 `S.Structures` 中，返回 `Proj` 不化简（类似 axiom 无法展开）。
- 如果 target 的 head 不是构造子（比如 target 是一个变量），也返回 `Proj` 不化简。
- v6 中 `CFst`/`CSnd` 各需要一个分支，各自硬编码取出 `a` 或 `b`。v7 用一个 `Proj` 分支取代了两个分支，并且是通用的。

### 12.5 其他情况

其他 CoreTerm 已经是 whnf，不做进一步化简：

```python
return t
```

因此 `whnf` 不递归进入：

```text
Lam 的 body
Forall 的 A 和 B
Sort
Var
```

除非这些 term 出现在需要被化简的头部位置（如 `App` 的函数部分、`Proj` 的 target）。

### 12.6 `whnf` 完整代码                                    【v11 修改】

```python
# 写作 whnf(S, t)
def whnf(S : State, t : CoreTerm) -> CoreTerm:
    '''
    把 t 化简到 weak head normal form。
    处理：delta 展开（Const）、beta reduction（App）、
    recursor iota reduction（App）、Proj 结构投影化简。
    其他构造子（Sort, Var, Lam, Forall）是值，不归约。
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

        t0 = App(f0, a)
        head, args = collect_app(t0).args

        if isinstance(head, Const):
            recInfo = S.Recursors.get(head.args)
            if recInfo is not None:
                numCases = len(recInfo.constructors)
                if len(args) == numCases + 2:
                    target0 = whnf(S, args[-1])
                    if isinstance(target0, Const):
                        for i, ctorName in enumerate(recInfo.constructors):
                            if target0.args == ctorName:
                                return whnf(S, args[1 + i])

        return t0

    if isinstance(t, Proj):
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

**评论：** `whnf` 有四类计算（Const delta、App beta、App iota、Proj 结构投影），其余四个构造子（Sort, Var, Lam, Forall）是值。iota 与 Proj 一样由 State 元数据驱动，不增加 CoreTerm 构造子。

---

## 13. 辅助函数（结构投影层面）

本节定义结构投影层面的通用辅助函数。它们对任何在 `S.Structures` 中注册的结构都适用，是 `infer_type` Proj 分支和 `HasType` Proj 规则的基础设施。Sigma 专用的辅助函数（`is_sigma_type`、`mk_sigma_type`、`mk_sigma_mk`）放在 §15 内，因为它们仅供 `elab` 的 Sigma 专属分支使用。

### 13.1 `match_structure_type`

给定一个类型 `T` 和一个结构名 `structName`，判断 `T` 是否是 `(Const structName)` 应用到若干参数上。如果是，返回参数值列表；否则返回 `None`。

```python
# 写作 match_structure_type(S, structName, T)
def match_structure_type(S : State, structName : GlobalName, T : CoreTerm) -> Optional[List[CoreTerm]]:
    '''
    如果 T 是 structName 应用到若干参数上的类型，返回这些参数值。
    否则返回 None。
    '''
    T0 = whnf(S, T)
    head_args = collect_app(T0)
    head, args = head_args.args
    if not (isinstance(head, Const) and head.args == structName):
        return None
    info = S.Structures.get(structName)
    if info is None:
        return None
    if len(args) != len(info.params):
        return None
    return args
```

**评论：** 这是结构类型识别的入口。三步检查对应三个前提条件：(1) whnf 后的头部是目标结构名；(2) 该结构已在 `S.Structures` 中注册；(3) 参数数量匹配（`len(args) = len(info.params)`）。严格相等确保部分应用的类型不会被匹配。此函数被 `infer_type` 的 Proj 分支和 `HasType` 的 Proj 规则调用。

**例子：** 假设 Sigma 已注册（`S.Structures.get(Sigma) = info`，其中 `len(info.params) = 2`）：

```text
match_structure_type(S, Sigma, App(App(Const Sigma, Const Nat), Bfun))
→ whnf 后 head = Const Sigma, args = [Const Nat, Bfun]
→ len(args) = 2 = len(info.params)  ✓
→ 返回 [Const Nat, Bfun]

match_structure_type(S, Sigma, Const Nat)
→ whnf 后 head = Const Nat ≠ Const Sigma
→ 返回 None

match_structure_type(S, Sigma, App(Const Sigma, Const Nat))
→ whnf 后 head = Const Sigma, args = [Const Nat]
→ len(args) = 1 ≠ 2 = len(info.params)
→ 返回 None
```

第三个例子展示了为什么需要严格相等：`App(Const Sigma, Const Nat)` 是部分应用（缺少 `Bfun` 参数），匹配它会导致后续 `projection_type` 替换时参数值数量不足。

### 13.2 `subst_many`

对单个 term 同时执行多个替换。这是 `projection_type` 的替换引擎——将 schema 模板中的参数名和前序字段名替换为实际值。

```python
# 写作 subst_many(t, [(x1,e1), ..., (xn,en)])
def subst_many(t : CoreTerm, substitutions : List[Pair[LocalName, CoreTerm]]) -> CoreTerm:
    '''
    在 t 中同时替换多个自由变量。
    substitutions 是 [(x1, e1), ..., (xn, en)] 列表。
    替换项本身不参与本轮替换。
    '''
    return subst_simul(t, substitutions)
```

**评论：** v10 中 `subst_many` 改为调用 `subst_simul`（定义在 §11.5），以保证 capture-avoiding simultaneous substitution。替换列表的顺序不影响结果；实际参数或 target 中恰好出现其他 schema 名字时，也不会被二次替换。

**例子：** 对 Sigma 的第二字段类型模板做替换：

```text
subst_many(App(Var B, Var a), [(A, Const Nat), (B, Bfun), (a, Proj(Sigma, 0, p))])

同时遍历原 term：
  Var B → Bfun
  Var a → Proj(Sigma, 0, p)

替换项 Bfun 和 Proj(Sigma, 0, p) 本身不再接受本轮替换。

最终结果: App(Bfun, Proj(Sigma, 0, p))
```

`A` 不出现在原 term 中，所以对应替换没有效果。由于这是 simultaneous substitution，参数替换与字段替换在列表中的先后顺序不影响结果。

### 13.3 `projection_type`

已知 `target` 的类型是 `(Const structName) params[0] ... params[n-1]`，计算 `Proj(structName, index, target)` 的类型。核心操作是：取出 `FieldInfo.type` 模板，把其中的参数名替换为实际参数值，把前序字段名替换为对应的 `Proj`。

```python
# 写作 projection_type(S, Γ, info, index, target, params)
def projection_type(S : State, Γ : Context, info : StructureInfo, index : Nat, target : CoreTerm, params : List[CoreTerm]) -> CoreTerm:
    '''
    已知 target : (Const structName) params[0] ... params[n-1]，
    计算 Proj(structName, index, target) 的类型。
    注意：Γ 当前未使用 — 保留 Γ 是为了与 typing judgment 的接口一致，
    以及将来检查字段类型 well-formedness 时使用。
    '''
    if index >= len(info.fields):
        raise Error
    fieldType = info.fields[index].type

    # Build one simultaneous substitution:
    # param names → param values, prior field names → Proj
    substitutions = []
    for i, param in enumerate(info.params):
        substitutions.append(Pair(param.name, params[i]))
    for j in range(index):
        substitutions.append(Pair(info.fields[j].name, Proj(info.typeName, j, target)))

    return subst_many(fieldType, substitutions)
```

**评论：** 字段类型是 schema 模板（用 `Var` 引用参数名和前序字段名）。替换后得到一个不再含 schema 变量的合法 CoreTerm。注意替换结果中可能包含 `Proj(...)` 形式（如 Sigma 第二字段类型中的 `Proj(Sigma, 0, target)`）——这些由 `defeq` 在类型比较时通过 `whnf` 化简。`match_structure_type` + `projection_type` 的组合是对任何结构都适用的通用机制，构成 `infer_type` Proj 分支的核心。

**例子：** 以下演示 `projection_type` 对 Sigma 的字段 0 和字段 1 的完整计算过程。

**前置状态 S**（与 §16 一致，已执行 StructureCmd Sigma + Prod，并声明了 Nat、zero、Pred、choosePred 四个 axiom）：

```text
S.Axioms = {
  Sigma      : Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Sort 0,
  Sigma.mk   : Π (A : Sort 0), Π (B : Π (x : A), Sort 0),
                 Π (a : A), Π (b : B a), Sigma A B,
  Prod       : Π (A : Sort 0), Π (B : Sort 0), Sort 0,
  Prod.mk    : Π (A : Sort 0), Π (B : Sort 0),
                 Π (a : A), Π (b : B), Prod A B,
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), App (Const Pred, Var x)
}

S.Defs = {}

S.Structures = {
  Sigma : StructureInfo(
    typeName    = Sigma,
    constructor = Sigma.mk,
    params = [
      ParamInfo(A, Sort(level 0)),
      ParamInfo(B, Π (x : Var A), Sort(level 0))
    ],
    fields = [
      FieldInfo(a, Var A),
      FieldInfo(b, App(Var B, Var a))
    ]
  ),
  Prod : StructureInfo(
    typeName    = Prod,
    constructor = Prod.mk,
    params = [
      ParamInfo(A, Sort(level 0)),
      ParamInfo(B, Sort(level 0))
    ],
    fields = [
      FieldInfo(a, Var A),
      FieldInfo(b, Var B)
    ]
  )
}

S.Projections = {
  Sigma.a : ProjectionInfo(Sigma.a, Sigma, 0),
  Sigma.b : ProjectionInfo(Sigma.b, Sigma, 1),
  Prod.a  : ProjectionInfo(Prod.a, Prod, 0),
  Prod.b  : ProjectionInfo(Prod.b, Prod, 1)
}
S.Inductives = {}
S.Recursors = {}
```

注意 `S.Axioms` 中 `Sigma.mk` 的签名决定了 `infer_type(S, Γ, Const Sigma.mk)` 的结果——它是一个嵌套 Π 类型，四参数应用后返回 `Sigma A B`。下面例子中的 `info` 就是 `S.Structures.get(Sigma)`。

给定一个变量 `p`，假设它的类型是 `Sigma Nat Bfun`，其中 `Bfun = Lam(x, Const Nat, App(Const Pred, Var x))`（写作 `fun (x : Nat) => Pred x`）。通过 `infer_type` 的 Proj 分支（§14.3），先调用 `match_structure_type(S, Sigma, infer_type(S, Γ, p))` 得到参数列表 `[Const Nat, Bfun]`，然后调用 `projection_type` 计算投影类型。下面是两次调用的逐步推导：

**字段 0（非依值）：`Proj(Sigma, 0, p)` 的类型**

```text
projection_type(S, Γ, info, 0, p, [Const Nat, Bfun])

输入：
  info   = S.Structures.get(Sigma)  （上述 StructureInfo）
  index  = 0
  target = p
  params = [Const Nat, Bfun]        ← match_structure_type 返回的参数值

步骤 1: 检查 index
  index = 0 < len(info.fields) = 2  ✓

步骤 2: 取出字段类型模板
  fieldType = info.fields[0].type = Var A

步骤 3: 构建替换列表
  参数替换（所有 params 都加入）：
    i=0: (A, Const Nat)           # params[0] = Const Nat
    i=1: (B, Bfun)                # params[1] = Bfun
  前序字段替换（j < index = 0）：无
  substitutions = [(A, Const Nat), (B, Bfun)]

步骤 4: 执行 simultaneous substitution
  subst_many(Var A, [(A, Const Nat), (B, Bfun)])
  → 原 term 的 Var A 直接匹配 (A, Const Nat)
  → Const Nat

结果: Const Nat
```

所以 `infer_type(S, Γ, Proj(Sigma, 0, p)) = Const Nat`。

**字段 1（依值）：`Proj(Sigma, 1, p)` 的类型**

```text
projection_type(S, Γ, info, 1, p, [Const Nat, Bfun])

输入同上，仅 index 不同：index = 1

步骤 1: 检查 index
  index = 1 < len(info.fields) = 2  ✓

步骤 2: 取出字段类型模板
  fieldType = info.fields[1].type = App(Var B, Var a)

步骤 3: 构建替换列表
  参数替换：
    (A, Const Nat)                  # params[0]
    (B, Bfun)                       # params[1]
  前序字段替换（j = 0, j < index = 1）：
    j=0: (a, Proj(Sigma, 0, p))    # fields[0].name = a
  substitutions = [(A, Const Nat), (B, Bfun), (a, Proj(Sigma, 0, p))]

步骤 4: 执行 simultaneous substitution
  subst_many(App(Var B, Var a), [(A, Const Nat), (B, Bfun), (a, Proj(Sigma, 0, p))])
  → 原 term 的 Var B 直接替换为 Bfun
  → 原 term 的 Var a 直接替换为 Proj(Sigma, 0, p)
  → replacement 内部不再接受本轮替换

结果: App(Bfun, Proj(Sigma, 0, p))
```

所以 `infer_type(S, Γ, Proj(Sigma, 1, p)) = App(Bfun, Proj(Sigma, 0, p))`。

**对比总结：** 字段 0（`Var A`）替换后是纯参数值 `Const Nat`——非依值，结果不含 `Proj`。字段 1（`App(Var B, Var a)`）替换后含 `Proj(Sigma, 0, p)`——依值字段的类型依赖前序投影。这个含 `Proj` 的结果不需在此处化简：当 `p` 是具体的构造子应用（如 `Sigma.mk Nat Bfun zero (choosePred zero)`）时，`whnf` 可将 `Proj(Sigma, 0, p)` 化简为 `zero`，而 `defeq` 在类型比较时会自动调用 `whnf`。对于 Prod（非依值结构），两个字段类型分别为 `Var A` 和 `Var B`，替换后都是纯参数值，不含 `Proj`。

---

## 14. 类型系统

本节将定义相等（defeq）、形式化 typing 规则（HasType）、算法实现（infer_type / check_type）整合为一章，因为它们共同构成模型的类型系统：

- **defeq（§14.1）**：term 的计算性相等——whnf + 递归结构比较。它是 conversion-based type checking 的基础。
- **HasType（§14.2）**：类型系统声明式规范——以推理规则的形式定义怎样的 term 可以拥有怎样的类型。
- **infer_type / check_type（§14.3）**：类型系统的算法实现——bidirectional type checker，调用 defeq 做 conversion checking，调用 match_structure_type + projection_type 处理 Proj。

三者的关系：HasType 是"什么是对的"，infer_type/check_type 是"怎么算出来"，defeq 是 infer/check 用来判断类型是否等价的底层机制。

### 14.1 定义相等（defeq）

自 v7 起 `whnf` 让 term 可以计算了。例如：

```text
whnf(S, Proj(Sigma, 0, Sigma.mk A B a b)) = a
```

但 `check_type` 的类型比较仍然用 `==`。所以：

```text
infer_type(S, ∅, Proj(Sigma, 1, p)) = App(Bfun, Proj(Sigma, 0, p))
```

如果你想检查 `Proj(Sigma, 1, p)` 是否有类型 `App(Bfun, a)`：

```text
check_type(S, ∅, Proj(Sigma, 1, p), App(Bfun, a))
```

在只用结构相等的模型中会失败 — 因为 `App(Bfun, Proj(Sigma, 0, p)) ≠ App(Bfun, a)`（结构不同）。

直觉上这很荒谬：如果 `p` 是 `Sigma.mk A B a b`，那么 `Proj(Sigma, 0, p)` 算出来就是 `a`，两者明明是一样的。但类型检查器如果只看结构，不看值，就不会承认这一点。

`defeq`（definitional equality）解决这个问题：**先把两边算一算（whnf），然后看结构是否匹配，递归比较子项**。

```text
defeq(S, ∅, App(Bfun, Proj(Sigma, 0, p)), App(Bfun, a))
```

推导过程：

1. 两边先 whnf。左边 `App(Bfun, Proj(Sigma, 0, p))` — 如果 `Bfun = Lam(x, A, body)`，则 whnf 先 beta-reduce 得到 `body[x := Proj(Sigma, 0, p)]`。如果 `body = App(Const Pred, Var x)`，则结果是 `App(Const Pred, Proj(Sigma, 0, p))`。注意：**whnf 不会化简参数位置的 `Proj`** — 它只处理头部。所以 whnf 后左边是 `App(Const Pred, Proj(Sigma, 0, p))`，不是 `App(Const Pred, a)`。右边 whnf 后是 `App(Bfun, a)`，如果 `Bfun = Lam(...)` 则 beta-reduce 后是 `App(Const Pred, a)`。
2. 两边都是 `App`，`defeq` 递归比较函数部分和参数部分。函数部分 `Const Pred` vs `Const Pred` ✓。参数部分 `defeq(S, ∅, Proj(Sigma, 0, p), a)` — **这里 `defeq` 再次调用 whnf**，把 `Proj(Sigma, 0, p)` 化简为 `a`。两边 whnf 后都是 `a` ✓。
3. 整体 `True`。

#### 为什么不能只比较 `whnf`

不能写成：

```python
def defeq(S, Γ, t1, t2):
    return whnf(S, t1) == whnf(S, t2)
```

因为 `whnf` 只化简头部，不递归化简子项。`(Const Pred) (Proj(Sigma, 0, p))` 的头部是 `App`，`Pred` 是 axiom 不能继续化简，所以 `whnf` 后不变。必须**递归进入子项**，在参数位置上再次调用 `defeq`（而 `defeq` 内部会再次调用 `whnf`），才能发现 `Proj(Sigma, 0, p)` 和 `a` 相等。

所以 `defeq` = `whnf` + 递归结构比较 + alpha-renaming。

```text
defeq(S : State, Γ : Context, t1 : CoreTerm, t2 : CoreTerm) -> bool
```

写作 `defeq(S, Γ, t1, t2)`。含义是：在状态 `S` 和上下文 `Γ` 下，判断两个 CoreTerm 是否 definitionally equal。

当前阶段，`defeq` 做三件事：

1. **先对两边做 `whnf`** — 暴露头部结构
2. **头部结构匹配则递归比较子项** — 比如 `App` 就递归比函数和参数
3. **binder 用 alpha-renaming** — `Forall(x, Nat, x)` 和 `Forall(y, Nat, y)` 应该相等

#### 基本情况（无子项的构造子）

**Sort：** 两边 whnf 后都是 `Sort`，比较 level。

```python
if isinstance(t1, Sort) and isinstance(t2, Sort):
    return t1.args == t2.args    # 比较两个 Level
```

**Const：** 两边 whnf 后都是 `Const`，比较全局名字。注意 whnf 已经展开了定义名（delta reduction），所以到达这里的 `Const` 一定是 axiom。

```python
if isinstance(t1, Const) and isinstance(t2, Const):
    return t1.args == t2.args    # 比较两个 GlobalName
```

**评论：** `defeq(S, Γ, Var x, Var y) = False`，即使 `x` 和 `y` 有相同类型 — 比较的是 term 的相等，不是类型的相等。`x` 和 `y` 是两个不同的局部变量。

**Var：** 两边 whnf 后都是 `Var`，比较局部名字。

```python
if isinstance(t1, Var) and isinstance(t2, Var):
    return t1.args == t2.args    # 比较两个 LocalName
```

#### 递归情况（有子项、无 binder 的构造子）

**App：** 递归比较函数部分和参数部分。

```python
if isinstance(t1, App) and isinstance(t2, App):
    f1, a1 = t1.args
    f2, a2 = t2.args
    return defeq(S, Γ, f1, f2) and defeq(S, Γ, a1, a2)
```

**Proj：** 递归比较被投影项（structName 和 index 必须相同）。

```python
if isinstance(t1, Proj) and isinstance(t2, Proj):
    s1, i1, t1_ = t1.args
    s2, i2, t2_ = t2.args
    return s1 == s2 and i1 == i2 and defeq(S, Γ, t1_, t2_)
```

**评论：** v6 中这里需要 `CFst` 和 `CSnd` 两个分支。v7 用一个 `Proj` 分支取代了两个，并且 `Proj` 还需要比较 `structName` 和 `index`（确保是同一个结构的同一个字段）。

#### Binder 情况（Lam / Forall）

Binder 的处理需要 alpha-renaming。以 `Forall` 为例：

```python
if isinstance(t1, Forall) and isinstance(t2, Forall):
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

**评论：** 为什么需要 alpha-renaming？因为 `Forall(x, Nat, x)` 和 `Forall(y, Nat, y)` 只是 binder 名字不同，应该相等。做法是：取一个新名字 `z`，把两个 body 的 binder 都改成 `z`，然后在扩展上下文 `Γ, z : A` 下递归比较。这样 `x` 和 `y` 都变成了 `z`，body 就能正确比较了。

`Lam` 的处理与 `Forall` 完全平行：

```python
if isinstance(t1, Lam) and isinstance(t2, Lam):
    x1, A1, body1 = t1.args
    x2, A2, body2 = t2.args

    if not defeq(S, Γ, A1, A2):
        return False

    z = fresh_local_name(FV(body1) ∪ FV(body2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
    body1z = alpha_rename_binder(body1, x1, z)
    body2z = alpha_rename_binder(body2, x2, z)

    Γ1 = expand_context(Γ, z, A1)
    return defeq(S, Γ1, body1z, body2z)
```

**评论：** v6 中这里还需要 `CSigma`（同 `CForall`）和 `CPairTyped`（五个字段比较 + binder）的分支。v7 中 `CSigma` 和 `CPairTyped` 不存在 — Sigma 类型是 `App(App(Const Sigma, A), Bfun)`，它的 defeq 由 `App` 分支的递归比较自动处理。

#### 其他情况

如果两边 whnf 后的头部构造子不同（比如一边是 `App`，另一边是 `Sort`），返回 `False`。

#### `defeq` 完整代码

```python
# 写作 defeq(S, Γ, t1, t2)
def defeq(S : State, Γ : Context, t1 : CoreTerm, t2 : CoreTerm) -> bool:
    '''
    判断 t1 和 t2 是否 definitionally equal。
    处理：whnf + alpha-equivalence + 递归结构比较。
    v7：只有 Lam 和 Forall 需要处理 binder，其余构造子要么无子项，
    要么（App, Proj）递归比较子项。不再有 CSigma, CPairTyped, CFst, CSnd 分支。
    '''

    t1 = whnf(S, t1)
    t2 = whnf(S, t2)

    if t1 == t2:
        return True

    if isinstance(t1, Sort) and isinstance(t2, Sort):
        return t1.args == t2.args

    if isinstance(t1, Const) and isinstance(t2, Const):
        return t1.args == t2.args

    if isinstance(t1, Var) and isinstance(t2, Var):
        return t1.args == t2.args

    if isinstance(t1, App) and isinstance(t2, App):
        f1, a1 = t1.args
        f2, a2 = t2.args
        return defeq(S, Γ, f1, f2) and defeq(S, Γ, a1, a2)

    if isinstance(t1, Lam) and isinstance(t2, Lam):
        x1, A1, body1 = t1.args
        x2, A2, body2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(body1) ∪ FV(body2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        body1z = alpha_rename_binder(body1, x1, z)
        body2z = alpha_rename_binder(body2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        return defeq(S, Γ1, body1z, body2z)

    if isinstance(t1, Forall) and isinstance(t2, Forall):
        x1, A1, B1 = t1.args
        x2, A2, B2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        B1z = alpha_rename_binder(B1, x1, z)
        B2z = alpha_rename_binder(B2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        return defeq(S, Γ1, B1z, B2z)

    if isinstance(t1, Proj) and isinstance(t2, Proj):
        s1, i1, t1_ = t1.args
        s2, i2, t2_ = t2.args
        return s1 == s2 and i1 == i2 and defeq(S, Γ, t1_, t2_)

    return False
```

**评论：**

- v7 的 `defeq` 有 7 个分支：Sort, Const, Var, App, Lam, Forall, Proj。v6 有 10 个分支（多了 CSigma, CPairTyped, CFst, CSnd）。v7 的简化来源于构造子数量的减少。
- `Proj` 的 defeq 语义清晰：同一个结构、同一个索引、target 定义相等。
- `App` 分支递归比较两边，这意味着 `App(App(Const Sigma, A1), B1)` 和 `App(App(Const Sigma, A2), B2)` 的比较会递归进入 `Const Sigma` vs `Const Sigma`（显然相等）、`A1` vs `A2`、`B1` vs `B2`。这自动处理了 Sigma 类型的 defeq — 不需要专门的 `CSigma` 分支。

---
### 14.2 形式化 Typing 规则（HasType）

`HasType` 是 `State × Context × CoreTerm × CoreTerm` 的最小子集，满足以下规则。

核心设计：**Sigma 类型的 formation、pair 的 introduction、fst/snd 的 elimination 不再需要专门的 HasType 规则。** 它们由基础的 `Const` 和 `App` 规则覆盖 — 因为 Sigma 现在是 `Const Sigma`，pair 是 `(Const Sigma.mk) A B a b`，它们的类型通过普通函数应用规则计算。

唯一新增的规则是 `Proj` 的 elimination rule。

#### 基本 typing 规则

- **Var 规则**

  若：

  ```text
  Γ.Types.get(x) = A
  ```

  则：

  ```text
  S ; Γ ⊢ Var x : A
  ```

- **Const-axiom 规则**

  若：

  ```text
  S.Axioms.get(n) = A
  ```

  则：

  ```text
  S ; Γ ⊢ Const n : A
  ```

- **Const-def 规则**

  若：

  ```text
  S.Defs.get(n) = Pair(A, t)
  ```

  则：

  ```text
  S ; Γ ⊢ Const n : A
  ```

#### `Sort / Π / fun / App` 规则

- **Sort 规则**

  若：

  ```text
  v = succ_level(u)
  ```

  则：

  ```text
  S ; Γ ⊢ Sort u : Sort v
  ```

- **Forall 规则**

  若：

  ```text
  S ; Γ ⊢ A : Sort u
  S ; (Γ, x : A) ⊢ B : Sort v
  ```

  则：

  ```text
  S ; Γ ⊢ Forall(x, A, B) : Sort (max_level(u, v))
  ```

- **Lam 规则**

  若：

  ```text
  S ; Γ ⊢ A : Sort u
  S ; (Γ, x : A) ⊢ t : B
  S ; (Γ, x : A) ⊢ B : Sort v
  ```

  则：

  ```text
  S ; Γ ⊢ Lam(x, A, t) : Forall(x, A, B)
  ```

- **App 规则**

  若：

  ```text
  S ; Γ ⊢ f : Forall(x, A, B)
  S ; Γ ⊢ a : A
  ```

  则：

  ```text
  S ; Γ ⊢ App(f, a) : B[x := a]
  ```

#### `Proj` 规则

- **Proj 规则**（一般投影 elimination rule）

  若：

  ```text
  S ; Γ ⊢ p : T
  info = S.Structures.get(structName)
  info ≠ None
  params = match_structure_type(S, structName, T)
  params ≠ None
  index < len(info.fields)
  A = projection_type(S, Γ, info, index, p, params)
  ```

  则：

  ```text
  S ; Γ ⊢ Proj(structName, index, p) : A
  ```

  **Sigma 的特例：** 当 `structName = Sigma`、`T = App(App(Const Sigma, A_val), Bfun_val)` 时：
  - `params = [A_val, Bfun_val]`
  - `Proj(Sigma, 0, p) : A_val`（第一字段类型 `Var A` 替换 `A → A_val`，得到 `A_val`）
  - `Proj(Sigma, 1, p) : App(Bfun_val, Proj(Sigma, 0, p))`（第二字段类型 `App(Var B, Var a)` 替换 `B → Bfun_val`、`a → Proj(Sigma, 0, p)`，得到 `App(Bfun_val, Proj(Sigma, 0, p))`）

  **Prod 的特例：** 当 `structName = Prod`、`T = App(App(Const Prod, A_val), B_val)` 时：
  - `params = [A_val, B_val]`
  - `Proj(Prod, 0, p) : A_val`
  - `Proj(Prod, 1, p) : B_val`（非依值 — 第二字段类型 `Var B` 替换 `B → B_val`，不依赖第一投影）

**评论：**

- HasType 规则与 `infer_type` 实现一致 — 都使用 `match_structure_type` + `projection_type`，不硬编码任何特定结构。
- 一般规则的三个前提条件：(1) `S.Structures` 中注册了该结构；(2) target 的类型能匹配该结构的参数；(3) index 在合法范围内。这三条对应 `infer_type` 中 `Proj` 分支的三个检查。
- v6 中的 `CSigma` formation rule、`CPairTyped` introduction rule、`CFst/CSnd` elimination rule 已全部消失 — 被更基础的 `Const/App/Proj` 规则取代。

#### `Ann` 规则

`Ann` 不再是 CoreTerm 的构造子（从 v6 开始）。类型标注在表层由 `SAnn` 处理，elaboration 时被消耗。详见 §15.6。

#### `Conversion` 规则

- **Conversion 规则**（类型转换）

  注意：`defeq` 已在 §14.1 定义，不再构成前向引用。HasType 规则的所有依赖（`whnf`、`match_structure_type`、`projection_type`、`defeq`）均在 §12-§14.1 已定义。

  若：

  ```text
  S ; Γ ⊢ t : A
  S ; Γ ⊢ B : Sort u
  defeq(S, Γ, A, B) = True
  ```

  则：

  ```text
  S ; Γ ⊢ t : B
  ```

---
### 14.3 算法实现（infer_type / check_type）

#### 背景：为什么需要两个函数？

如果所有 CoreTerm 都能从自身推断类型，那么 `check_type` 只需要是 `infer_type` 的简单包装：

```text
check_type(S, Γ, t, A) = defeq(S, Γ, infer_type(S, Γ, t), A)
```

这对 `Var`、`Const`、`Sort`、`App`、`Lam`、`Forall` 都完全成立。`Proj` 也可以 infer — **Proj infer_type 已通过 `StructureInfo` 的 params/fields 信息一般化**，不再硬编码 Sigma。任何在 `S.Structures` 中注册且带有完整 `ParamInfo`/`FieldInfo` 的结构，`Proj` 都能推断类型。

- **infer 模式**（synthesis）：`infer_type(S, Γ, t)` — 给定 CoreTerm，推断出类型。
- **check 模式**：`check_type(S, Γ, t, A)` — 给定 CoreTerm 和目标类型，检查是否合法。
两者的关系是：
```text
check_type 可以调用 infer_type（"先推断，再比较"）
infer_type 可以调用 check_type（如 App 中检查参数类型）
```
这和 **Lean 的真实实现**是一致的：
- Lean 的 kernel 中，每个构造子的类型签名存储在环境中，kernel 可以 infer — 比如 `Sigma.mk` 的类型签名是 `forall (A : Type u) (B : A → Type v) (a : A) (b : B a), Sigma A B`，所以给定应用链就能推断类型。
- Lean 的 elaborator 中，anonymous constructor `⟨a, b⟩` 必须知道 expected type — 这对应 elaboration 层的处理。

核心设计：**Sigma 类型的 formation、pair 的 introduction、fst/snd 的 elimination 不再需要 `infer_type` 中的专门分支。** 它们由基础规则覆盖：

- **Sigma formation**：`Const Sigma` 由 Const 规则处理（从 `S.Axioms` 查找类型），然后 `App(App(Const Sigma, A), Bfun)` 由 App 规则链式处理。
- **Pair introduction**：`App(App(App(App(Const Sigma.mk, A), Bfun), a), b)` 由 App 规则链式处理 — 每次应用推断类型，最终得到 `App(App(Const Sigma, A), Bfun)` 即 Sigma 类型。
- **Elimination**：`Proj(structName, i, p)` 需要专门的分支来计算字段类型 — 通过 `match_structure_type` + `projection_type` 实现，对任何在 `S.Structures` 中注册的结构都适用。

#### `infer_type` 的定义

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

#### `check_type` 的定义

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

#### 代码

```python
# 写作 infer_type(S, Γ, t)
def infer_type(S: State, Γ: Context, t: CoreTerm) -> CoreTerm:
    '''
    在 S 和 Γ 下推断 t 的类型（infer 模式）
    若无法推断，则 raise Error
    Proj 分支不再硬编码 Sigma，改用 match_structure_type + projection_type。
    Sigma formation 和 pair introduction 由 Const + App 规则链处理。
    '''


    if isinstance(t, Var):
        x = t.args                 # t = Var x
        A = Γ.Types.get(x)
        if A is None:
            raise Error
        return A


    elif isinstance(t, Const):
        n = t.args                 # t = Const n
        if n in S.Axioms:
            return S.Axioms.get(n)
        elif n in S.Defs:
            A, body = S.Defs.get(n)
            return A
        else:
            raise Error


    elif isinstance(t, Sort):
        u = t.args                 # t = Sort u
        return Sort(succ_level(u))


    elif isinstance(t, Forall):
        x, A, B = t.args           # t = Forall(x, A, B)


        TA = whnf(S, infer_type(S, Γ, A))
        if not isinstance(TA, Sort):
            raise Error
        u = TA.args                # TA = Sort u


        Γ1 = expand_context(Γ, x, A)
        TB = whnf(S, infer_type(S, Γ1, B))
        if not isinstance(TB, Sort):
            raise Error
        v = TB.args                # TB = Sort v


        return Sort(max_level(u, v))


    elif isinstance(t, Lam):
        x, A, body = t.args        # t = Lam(x, A, body)


        TA = whnf(S, infer_type(S, Γ, A))
        if not isinstance(TA, Sort):
            raise Error


        Γ1 = expand_context(Γ, x, A)
        B = infer_type(S, Γ1, body)


        TB = whnf(S, infer_type(S, Γ1, B))
        if not isinstance(TB, Sort):
            raise Error


        return Forall(x, A, B)


    elif isinstance(t, App):
        f, a = t.args              # t = App(f, a)


        Tf = whnf(S, infer_type(S, Γ, f))
        if not isinstance(Tf, Forall):
            raise Error
        x, A, B = Tf.args          # Tf = Forall(x, A, B)


        if not check_type(S, Γ, a, A):
            raise Error


        return subst(B, x, a)


    elif isinstance(t, Proj):
        structName, index, target = t.args  # t = Proj(structName, index, target)

        info = S.Structures.get(structName)
        if info is None:
            raise Error
        if index >= len(info.fields):
            raise Error

        Ttarget = whnf(S, infer_type(S, Γ, target))

        params = match_structure_type(S, structName, Ttarget)
        if params is None:
            raise Error

        return projection_type(S, Γ, info, index, target, params)

    raise Error


# 写作 check_type(S, Γ, t, A)
def check_type(S: State, Γ: Context, t: CoreTerm, A: CoreTerm) -> bool:
    '''
    在 S 和 Γ 下检查 t : A（check 模式）
    check_type 是 infer_type 的简单包装。
    Proj 可以 infer（通过 match_structure_type + projection_type），不需要 check-only 分支。
    '''
    try:
        return defeq(S, Γ, infer_type(S, Γ, t), A)
    except:
        return False
```

**评论：**

- v7 的 `check_type` 与 v6 一样简洁 — `defeq(infer_type(...), A)` 一行。`try/except` 包住整个函数体，确保内部任何 `raise Error`（来自 `infer_type`）都被捕获并返回 `False`。

- **Sigma formation 的类型推断路径：**
  1. `infer_type(S, Γ, Const Sigma)` → 从 `S.Axioms` 查到 Sigma 的类型（一个 Π 类型）。
  2. `infer_type(S, Γ, App(Const Sigma, A))` → App 规则：`Const Sigma` 的类型是 `Forall(_, Sort u, ...)`，检查 `A : Sort u`，返回替换后的类型。
  3. `infer_type(S, Γ, App(App(Const Sigma, A), Bfun))` → 继续 App 规则链，最终得到 Sigma 的结果类型。在当前单宇宙 v9 中，`Sigma A Bfun` 的类型由 `Const Sigma` 的签名推出，结果是 `Sort(level 0)`。更一般的 universe-polymorphic 版本以后再加。
  整个过程由 Const + App 规则自动处理，不需要专门的 CSigma 分支。

- **Pair introduction 的类型推断路径：**
  1. `infer_type(S, Γ, Const Sigma.mk)` → 从 `S.Axioms` 查到 `Sigma.mk` 的类型（一个嵌套 Π 类型）。
  2. 依次应用参数 `A`, `Bfun`, `a`, `b`，每次 App 规则推断类型。
  3. 最终得到 `App(App(Const Sigma, A), Bfun)` 即 Sigma 类型。
  整个过程由 Const + App 规则自动处理，不需要专门的 CPairTyped 分支。

- **Proj 的类型推断** 已一般化。`match_structure_type(S, structName, Ttarget)`（定义在 §13.1）从目标类型中提取结构参数值，`projection_type(S, Γ, info, index, target, params)`（定义在 §13.3）用 `FieldInfo.type` 模板计算字段类型。两者对任何在 `S.Structures` 中注册的结构都适用。

- **一般化机制对 Sigma 的工作方式：** 对于 `Proj(Sigma, 0, p)`：
  1. `match_structure_type(S, Sigma, Ttarget)` 从 `p` 的类型中提取 `[A_val, Bfun_val]`。
  2. `projection_type(S, Γ, info, 0, p, [A_val, Bfun_val])` — `fields[0].type = Var A`，替换 `A → A_val`，得到 `A_val`。
  对于 `Proj(Sigma, 1, p)`：
  3. 同上提取 `[A_val, Bfun_val]`。
  4. `projection_type` — `fields[1].type = App(Var B, Var a)`，替换 `A → A_val`、`B → Bfun_val`、`a → Proj(Sigma, 0, p)`，得到 `App(Bfun_val, Proj(Sigma, 0, p))`。

- **一般化机制对 Prod 的工作方式：** 对于 `Proj(Prod, 0, p)`：
  1. `match_structure_type(S, Prod, Ttarget)` 从 `p` 的类型中提取 `[A_val, B_val]`。
  2. `projection_type` — `fields[0].type = Var A`，替换 `A → A_val`，得到 `A_val`。
  对于 `Proj(Prod, 1, p)`：
  3. 同上提取 `[A_val, B_val]`。
  4. `projection_type` — `fields[1].type = Var B`（非依值！），替换 `A → A_val`、`B → B_val`，得到 `B_val`。
  注意 Prod 的第二字段类型是 `Var B` 而非 `App(Var B, Var a)` — 这个区别完全由 `FieldInfo.type` 模板表达。

- 注意 `projection_type` 返回的类型中可能包含 `Proj(...)` 形式（如 Sigma 的第二字段类型中的 `Proj(Sigma, 0, target)`）— 这是未经化简的项。`whnf` 可以化简它（如果 target 是构造子应用），但 `infer_type` 本身不做化简。`check_type` 通过 `defeq` 在比较时自动调用 `whnf` 来处理这种情况。

- 在 `App` 规则中，`infer_type` 已经调用了 `check_type` 来检查参数类型。所以 `infer` 和 `check` 是互相调用的，不是单方向的。

- `infer_type` 在所有类型头部检查处使用了 `whnf` 展开。具体来说：`Forall`/`Lam` 分支中检查 `TA : Sort` 和 `TB : Sort` 时、`App` 分支中检查 `Tf : Forall` 时、`Proj` 分支中通过 `match_structure_type` 检查 `Ttarget` 是否匹配结构类型时，都先用 `whnf` 展开推断出的类型。

---
## 15. `elab`：从 SurfaceTerm 到 CoreTerm

**位置说明：** 概念上，elaboration 在 kernel 检查之前 — 用户写的 SurfaceTerm 先经 elab 转成 CoreTerm，再交给 kernel。但因为 `elab` 内部调用 `infer_type` 和 `check_type`（§14.3），它必须在它们之后定义。

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

模型采用 bidirectional typing：elab 处理 Surface→Core（`SPair` 需要 expected type，其余构造子自带足够信息），kernel 层 `infer_type`/`check_type` 只作用于 CoreTerm，所有 CoreTerm 构造子均可 infer。

`elab` 实际由两个函数组成：

```text
elab(S, Γ, st, expected) = check(elab_raw(S, Γ, st, expected), expected)
```

- `elab_raw`：做结构转换（Surface → Core），用 `expected` 指导需要目标类型的分支（如 `SPair`、`SAnn`），但不验证最终结果是否满足 `expected`。
- `elab`（外层包装）：调用 `elab_raw` 得到 `core`，然后**统一检查** `check_type(S, Γ, core, expected)`（当 `expected` 非空时）。

**为什么需要两层？** 如果不分层，很多分支会忽略 `expected` — 比如 `SConst` 直接返回 `Const(name)`，不检查它是否真的有 expected type。拆分后，只要调用 `elab` 时传入了 `expected`，最终结果一定通过 `check_type` 验证。分支内部的 `check_type` 调用（如 `SPair` 中对分量的检查）仍然保留，用于指导 elaboration 过程和提前发现错误；外层的统一检查则作为兜底。

### 15.0 Sigma 专用辅助函数

以下函数硬编码 `Sigma` 和 `Sigma.mk`，供 `elab` 的 Sigma 专属分支（`SSigma`/`SPair`/`SFst`/`SSnd`，§15.5-§15.9）使用。一般化的结构处理应使用 `match_structure_type`（§13.1）。

#### `is_sigma_type`

```python
# 写作 is_sigma_type(t)
def is_sigma_type(t : CoreTerm) -> Optional[Pair[CoreTerm, CoreTerm]]:
    '''
    如果 t = App(App(Const Sigma, A), Bfun)，返回 Pair(A, Bfun)
    否则返回 None
    此函数只做模式匹配，不调用 whnf（调用者需要预先 whnf 输入）。
    一般化的类型识别应使用 match_structure_type（§13.1）。
    '''
    if isinstance(t, App):
        f_B, Bfun = t.args
        if isinstance(f_B, App):
            f_A, A = f_B.args
            if isinstance(f_A, Const) and f_A.args == Sigma:
                return Pair(A, Bfun)
    return None
```

也就是说：

```text
is_sigma_type((Const Sigma) A Bfun) = Pair(A, Bfun)
```

其中 `Bfun` 通常是一个 lambda：`Bfun = fun (x : A) => B_body`。

#### 元语言辅助函数

为了写例子方便，定义两个**元语言**函数（不是 CoreTerm 构造子）：

```python
# 写作 mk_sigma_type(A, Bfun)
def mk_sigma_type(A : CoreTerm, Bfun : CoreTerm) -> CoreTerm:
    return App(App(Const(Sigma), A), Bfun)

# 写作 mk_sigma_mk(A, Bfun, a, b)
def mk_sigma_mk(A : CoreTerm, Bfun : CoreTerm, a : CoreTerm, b : CoreTerm) -> CoreTerm:
    return App(App(App(App(Const(Sigma.mk), A), Bfun), a), b)
```

即：

```text
mk_sigma_type(A, Bfun) = (Const Sigma) A Bfun
mk_sigma_mk(A, Bfun, a, b) = (Const Sigma.mk) A Bfun a b
```

---
### 15.1 基本项

表层的基本项直接映射到核心：

```python
if isinstance(st, SConst):
    return Const(st.args)

if isinstance(st, SSort):
    return Sort(st.args)

if isinstance(st, SVar):
    return Var(st.args)
```

不需要 expected type。注意自 v7 起 CoreTerm 构造子没有 `C` 前缀。

### 15.2 App

```python
if isinstance(st, SApp):
    f_s, a_s = st.args
    f_c = elab(S, Γ, f_s, None)
    Tf = whnf(S, infer_type(S, Γ, f_c))
    if not isinstance(Tf, Forall):
        raise Error
    x, A, B = Tf.args
    a_c = elab(S, Γ, a_s, A)
    return App(f_c, a_c)
```

**评论：** 先 elab 函数部分，推断其类型，获取参数的 expected type，再用它 elab 参数。逻辑与 v6 完全相同，只是输出使用非 C 前缀的构造子。

### 15.3 Lam

```python
if isinstance(st, SLam):
    x, A_s, body_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, Sort):
        raise Error
    Γ1 = expand_context(Γ, x, A_c)
    body_c = elab(S, Γ1, body_s, None)
    return Lam(x, A_c, body_c)
```

**评论：** `SLam` 要求用户显式写出参数类型 `A`，因此 `elab` 可以在没有 expected type 的情况下处理 `SLam`（`expected` 传入 `None`）。更接近 Lean 的实现会在有 expected type `Forall(x, A, B)` 时，将 `A` 作为参数的 expected type 传入，从而支持隐式参数类型推断 — 但当前模型不做这个优化。

### 15.4 Forall

```python
if isinstance(st, SForall):
    x, A_s, B_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, Sort):
        raise Error
    Γ1 = expand_context(Γ, x, A_c)
    B_c = elab(S, Γ1, B_s, None)
    return Forall(x, A_c, B_c)
```

### 15.5 Sigma

```python
if isinstance(st, SSigma):
    x, A_s, B_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, Sort):
        raise Error
    Γ1 = expand_context(Γ, x, A_c)
    B_c = elab(S, Γ1, B_s, None)
    Bfun = Lam(x, A_c, B_c)
    return mk_sigma_type(A_c, Bfun)
```

**评论：** 这是 v7 相对于 v6 的重大变化。v6 中 `SSigma(x, A, B)` 产生 `CSigma(x, A, B)` — 一个专门的 core 构造子。v7 中 `SSigma(x, A, B)` 产生：

```text
(Const Sigma) A_c (fun (x : A_c) => B_c)
```

即 `App(App(Const Sigma, A_c), Lam(x, A_c, B_c))`。

关键要点：

- `Bfun = Lam(x, A_c, B_c)` 把依值类型 `B` 打包成一个函数。这个函数的参数是 `x : A_c`，返回值是 `B_c`。
- `mk_sigma_type(A_c, Bfun)` 构造 `App(App(Const Sigma, A_c), Bfun)`。
- 从 v7 开始，`Σ (x : A), B` 是**记号（notation）**，不是 CoreTerm 的 primitive 构造子。它的 elaboration 结果是一个函数应用 — 把 `Const Sigma` 这个全局常量应用到 `A_c` 和 `Bfun` 上。
- 表层仍然可以写 `Σ (x : A), B`，但底层只是 `Sigma A (fun x => B)` 的语法糖。
- **在 v9 中，`SSigma` 不是无条件可用的 primitive。** 它的 elaboration 结果引用 `Const Sigma`；因此必须先执行 StructureCmd Sigma（见 §17.1），使 `Sigma` 和 `Sigma.mk` 出现在 State 中，后续类型检查才能成功。如果用户在 StructureCmd Sigma 执行之前就写 `SSigma(...)`，elab 会生成 `(Const Sigma) A Bfun`，但此时 `Sigma ∉ S.Axioms`，后续 `infer_type` 会失败。

### 15.6 Ann

```python
if isinstance(st, SAnn):
    t_s, A_s = st.args
    A_c = elab(S, Γ, A_s, None)
    TA = whnf(S, infer_type(S, Γ, A_c))
    if not isinstance(TA, Sort):
        raise Error
    t_c = elab(S, Γ, t_s, A_c)
    return t_c
```

**评论：** 与 v6 完全相同。`SAnn(t, A)` 的 elaboration 结果是 `t_c` — Ann 不出现在输出中。它的唯一作用是：先 elab 类型 `A`，验证 `A` 是 type，然后把 `A_c` 作为 expected type 传给 `t` 的 elaboration。

### 15.7 Pair

```python
if isinstance(st, SPair):
    a_s, b_s = st.args
    if expected is None:
        raise Error
    expected_whnf = whnf(S, expected)
    AB = is_sigma_type(expected_whnf)
    if AB is None:
        raise Error
    A, Bfun = AB.args
    a_c = elab(S, Γ, a_s, A)
    if not check_type(S, Γ, a_c, A):
        raise Error
    B_at_a = App(Bfun, a_c)
    b_c = elab(S, Γ, b_s, B_at_a)
    if not check_type(S, Γ, b_c, B_at_a):
        raise Error
    return mk_sigma_mk(A, Bfun, a_c, b_c)
```

**评论：** 这是 v7 相对于 v6 最核心的变化之一。

v6 中 `SPair(a, b)` 在 expected type `CSigma(x, A, B)` 下 elaborate 成 `CPairTyped(x, A, B, a_c, b_c)` — 一个专门的 core 构造子。

v7 中 `SPair(a, b)` 在 expected type `(Const Sigma) A Bfun` 下 elaborate 成：

```text
(Const Sigma.mk) A Bfun a_c b_c
```

即 `App(App(App(App(Const Sigma.mk, A), Bfun), a_c), b_c)`。

关键要点：

- `SPair` **必须有 expected type**，且 expected type 的 whnf 必须能被 `is_sigma_type` 识别。否则 elab 失败。
- `is_sigma_type` 检查 expected type 是否形如 `App(App(Const Sigma, A), Bfun)`，若是则提取 `A` 和 `Bfun`。
- 第一个分量用 `A` 作为 expected type。
- 第二个分量用 `App(Bfun, a_c)` 作为 expected type。注意 `App(Bfun, a_c)` 就是 `Bfun` 应用到 `a_c`，对应之前的 `subst(B, x, a_c)` — 但现在不再用 `subst`，而是直接把 `Bfun` 作为一个函数应用到 `a_c` 上。这个应用会 beta-reduce 为 `B[x := a_c]`。
- 返回 `mk_sigma_mk(A, Bfun, a_c, b_c)` — 这是一个纯 `App` 嵌套，没有特殊构造子。
- 这就是 v6 中 `CPairTyped` 的逻辑移到了 elaboration 层，但产生的是 constructor application 而非特殊 core term。

### 15.8 Fst

```python
if isinstance(st, SFst):
    t_s = st.args
    t_c = elab(S, Γ, t_s, None)
    Tt = whnf(S, infer_type(S, Γ, t_c))
    AB = is_sigma_type(Tt)
    if AB is None:
        raise Error
    return Proj(Sigma, 0, t_c)
```

**评论：** v6 中 `SFst(t)` elaborate 成 `CFst(t_c)` — 一个专门的 core 构造子。v7 中 `SFst(t)` elaborate 成 `Proj(Sigma, 0, t_c)` — 一个一般的 projection。表层 `fst t` 变成了 core 中的 `Proj(Sigma, 0, t_c)`。

### 15.9 Snd

```python
if isinstance(st, SSnd):
    t_s = st.args
    t_c = elab(S, Γ, t_s, None)
    Tt = whnf(S, infer_type(S, Γ, t_c))
    AB = is_sigma_type(Tt)
    if AB is None:
        raise Error
    return Proj(Sigma, 1, t_c)
```

**评论：** 与 Fst 完全平行。`SSnd(t)` elaborate 成 `Proj(Sigma, 1, t_c)`。表层 `snd t` 变成了 core 中的 `Proj(Sigma, 1, t_c)`。


### 15.10 SProj

```python
if isinstance(st, SProj):
    projectionName, t_s = st.args
    t_c = elab(S, Γ, t_s, None)
    pi = S.Projections.get(projectionName)
    if pi is None:
        raise Error
    return Proj(pi.structName, pi.fieldIndex, t_c)
```

**评论：** `SProj(projectionName, t)` 的 elaboration：先 elab target，然后用完整投影名查找 `ProjectionInfo`，从中同时取得 `structName` 和 `fieldIndex`。用户写 `Sigma.a p`，elaboration 后变成 `Proj(Sigma, 0, p)`。

### 15.11 SDot

```python
if isinstance(st, SDot):
    t_s, fieldName = st.args
    t_c = elab(S, Γ, t_s, None)
    Tt = whnf(S, infer_type(S, Γ, t_c))
    # 从 target 类型推断结构名
    head_args = collect_app(Tt)
    head, args = head_args.args
    if not isinstance(head, Const):
        raise Error
    structName = head.args
    proj_name = append_local(structName, fieldName)
    pi = S.Projections.get(proj_name)
    if pi is None or pi.structName != structName:
        raise Error
    return Proj(pi.structName, pi.fieldIndex, t_c)
```

**评论：** `SDot(target, fieldName)` 的 elaboration：先 elab target，推断其类型，从类型的头部提取结构名（如 `(Const Sigma) A Bfun` → `Sigma`），然后用 `structName.fieldName` 查找投影信息。用户写 `p.a`，elaboration 后变成 `Proj(Sigma, 0, p)`。

**SProj vs SDot：** `SProj` 显式给出完整投影名，不需要从 target 类型推断结构名；`SDot` 从 target 的类型推断结构名。两者最终都产生相同的 `Proj`。

### 15.12 `elab` 完整代码

```python
# 写作 elab(S, Γ, st) 或 elab(S, Γ, st, expected)
def elab(S: State, Γ: Context, st: SurfaceTerm, expected: Optional[CoreTerm] = None) -> CoreTerm:
    '''
    把 SurfaceTerm elaboration 成 CoreTerm。
    外层包装：调用 elab_raw 做结构转换，然后统一检查 expected type。
    '''
    core = elab_raw(S, Γ, st, expected)

    if expected is not None:
        if not check_type(S, Γ, core, expected):
            raise Error

    return core


def elab_raw(S: State, Γ: Context, st: SurfaceTerm, expected: Optional[CoreTerm] = None) -> CoreTerm:
    '''
    elab 的核心逻辑：把 SurfaceTerm 结构转换为 CoreTerm。
    expected 用于指导需要目标类型的分支（SPair、SAnn）。
    不检查最终结果是否满足 expected — 由外层 elab 统一检查。
    自 v7 起：Sigma/Pair/Fst/Snd 不再产生特殊 core 构造子，
    而是产生 Const Sigma/Sigma.mk 的应用和 Proj 投影。
    '''

    if isinstance(st, SConst):
        return Const(st.args)

    if isinstance(st, SSort):
        return Sort(st.args)

    if isinstance(st, SVar):
        return Var(st.args)

    if isinstance(st, SApp):
        f_s, a_s = st.args
        f_c = elab(S, Γ, f_s, None)
        Tf = whnf(S, infer_type(S, Γ, f_c))
        if not isinstance(Tf, Forall):
            raise Error
        x, A, B = Tf.args
        a_c = elab(S, Γ, a_s, A)
        return App(f_c, a_c)

    if isinstance(st, SLam):
        x, A_s, body_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, Sort):
            raise Error
        Γ1 = expand_context(Γ, x, A_c)
        body_c = elab(S, Γ1, body_s, None)
        return Lam(x, A_c, body_c)

    if isinstance(st, SForall):
        x, A_s, B_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, Sort):
            raise Error
        Γ1 = expand_context(Γ, x, A_c)
        B_c = elab(S, Γ1, B_s, None)
        return Forall(x, A_c, B_c)

    if isinstance(st, SSigma):
        x, A_s, B_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, Sort):
            raise Error
        Γ1 = expand_context(Γ, x, A_c)
        B_c = elab(S, Γ1, B_s, None)
        Bfun = Lam(x, A_c, B_c)
        return mk_sigma_type(A_c, Bfun)

    if isinstance(st, SAnn):
        t_s, A_s = st.args
        A_c = elab(S, Γ, A_s, None)
        TA = whnf(S, infer_type(S, Γ, A_c))
        if not isinstance(TA, Sort):
            raise Error
        t_c = elab(S, Γ, t_s, A_c)
        return t_c

    if isinstance(st, SPair):
        a_s, b_s = st.args
        if expected is None:
            raise Error
        expected_whnf = whnf(S, expected)
        AB = is_sigma_type(expected_whnf)
        if AB is None:
            raise Error
        A, Bfun = AB.args
        a_c = elab(S, Γ, a_s, A)
        if not check_type(S, Γ, a_c, A):
            raise Error
        B_at_a = App(Bfun, a_c)
        b_c = elab(S, Γ, b_s, B_at_a)
        if not check_type(S, Γ, b_c, B_at_a):
            raise Error
        return mk_sigma_mk(A, Bfun, a_c, b_c)

    if isinstance(st, SFst):
        t_s = st.args
        t_c = elab(S, Γ, t_s, None)
        Tt = whnf(S, infer_type(S, Γ, t_c))
        AB = is_sigma_type(Tt)
        if AB is None:
            raise Error
        return Proj(Sigma, 0, t_c)

    if isinstance(st, SSnd):
        t_s = st.args
        t_c = elab(S, Γ, t_s, None)
        Tt = whnf(S, infer_type(S, Γ, t_c))
        AB = is_sigma_type(Tt)
        if AB is None:
            raise Error
        return Proj(Sigma, 1, t_c)

    if isinstance(st, SProj):
        projectionName, t_s = st.args
        t_c = elab(S, Γ, t_s, None)
        pi = S.Projections.get(projectionName)
        if pi is None:
            raise Error
        return Proj(pi.structName, pi.fieldIndex, t_c)

    if isinstance(st, SDot):
        t_s, fieldName = st.args
        t_c = elab(S, Γ, t_s, None)
        Tt = whnf(S, infer_type(S, Γ, t_c))
        head_args = collect_app(Tt)
        head, args = head_args.args
        if not isinstance(head, Const):
            raise Error
        structName = head.args
        proj_name = append_local(structName, fieldName)
        pi = S.Projections.get(proj_name)
        if pi is None or pi.structName != structName:
            raise Error
        return Proj(pi.structName, pi.fieldIndex, t_c)

    raise Error
```

**注意：** `elab_raw` 内部的递归调用使用 `elab`（外层包装）而非 `elab_raw`。这保证每层递归的 expected type 都被检查。例如 `SApp` 分支中 `a_c = elab(S, Γ, a_s, A)` 会检查 `a_c : A`，即使 `a_s` 是 `SConst` 这样的基本项。

**总结：** `elab` 把 SurfaceTerm 转换成 CoreTerm。v7 的重要变化：

- `SSigma(x, A, B)` 不再产生 `CSigma(x, A, B)`，而是产生 `(Const Sigma) A (fun (x : A) => B)` — 一个全局常量的应用。
- `SPair(a, b)` 不再产生 `CPairTyped(x, A, B, a, b)`，而是产生 `(Const Sigma.mk) A B a b` — 一个构造子的应用。
- `SFst(t)` 不再产生 `CFst(t_c)`，而是产生 `Proj(Sigma, 0, t_c)` — 一个一般的 projection。
- `SSnd(t)` 不再产生 `CSnd(t_c)`，而是产生 `Proj(Sigma, 1, t_c)` — 一个一般的 projection。
- `SAnn(t, A)` 仍然被消耗，不出现在输出中。

**注意：** `elab` 的 Sigma 专属分支（`SSigma`、`SPair`、`SFst`、`SSnd`）硬编码引用 `Const Sigma` — 只在 StructureCmd Sigma 执行后才可用。v10 引入的 `SProj` 和 `SDot` 分支通过 `ProjectionInfo` 查找投影信息，对任何已注册的结构都适用。

---


## 16. 构建前置状态 `S`

为了后续展示 `elab` / `whnf` / `defeq` / `StructureCmd` 的例子，先构建一个共同的前置状态 `S`。

v9 不预置任何结构。从空初始状态 `S₀`（§10）开始，先通过 StructureCmd 定义 Sigma 和 Prod，再添加 axiom。

```text
S₁ = exec(S₀, StructureCmd Sigma Sigma.mk
  params = [A : SSort 0, B : SForall(x, SVar A, SSort 0)]
  fields = [a : SVar A, b : SApp(SVar B, SVar a)])       （完整推导见 §17.1）

SΣ = S₁  （缩写）

S₂ = exec(SΣ, StructureCmd Prod Prod.mk
  params = [A : SSort 0, B : SSort 0]
  fields = [a : SVar A, b : SVar B])                     （完整推导见 §17.2）

SΣΠ = S₂  （缩写）

S₃ = exec(SΣΠ, AxiomCmd Nat : SSort (level 0))
S₄ = exec(S₃, AxiomCmd zero : SConst Nat)
S₅ = exec(S₄, AxiomCmd Pred : SForall (x, SConst Nat, SSort (level 0)))
S₆ = exec(S₅, AxiomCmd choosePred : SForall (x, SConst Nat, SApp (SConst Pred, SVar x)))

S = S₆
```

以上得到继承自 v10 的基础状态 `S`。v11 在这个状态上执行一次 `InductiveCmd Bool`：

```text
S_v11 = exec(S, InductiveCmd Bool
  constructors = [ConstructorDecl(false), ConstructorDecl(true)])
```

因此，`S_v11` 正是执行该 `InductiveCmd` 后返回的新状态。这里先给出状态构造序列和最终内容；命令内部的名字检查、类型生成、验证和原子更新过程见 §17.5。

基础状态 `S` 的内容：

```text
S.Axioms = {
  Sigma      : Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Sort 0,
  Sigma.mk   : Π (A : Sort 0), Π (B : Π (x : A), Sort 0), Π (a : A), Π (b : B a), Sigma A B,
  Prod       : Π (A : Sort 0), Π (B : Sort 0), Sort 0,
  Prod.mk    : Π (A : Sort 0), Π (B : Sort 0), Π (a : A), Π (b : B), Prod A B,
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Forall (x, Const Nat, Sort (level 0)),
  choosePred : Forall (x, Const Nat, App (Const Pred, Var x))
}
S.Defs = {}
S.Projections = {
  Sigma.a : ProjectionInfo(Sigma.a, Sigma, 0),
  Sigma.b : ProjectionInfo(Sigma.b, Sigma, 1),
  Prod.a  : ProjectionInfo(Prod.a, Prod, 0),
  Prod.b   : ProjectionInfo(Prod.b, Prod, 1)
}
S.Structures = {
  Sigma : StructureInfo(Sigma, Sigma.mk, params=[A, B], fields=[(a, Var A), (b, App(Var B, Var a))]),
  Prod  : StructureInfo(Prod, Prod.mk, params=[A, B], fields=[(a, Var A), (b, Var B)])
}
S.Inductives = {}
S.Recursors = {}
```

执行上述 `InductiveCmd Bool` 后，`S_v11` 在 `S` 上继续加入：

```text
S_v11.Axioms 额外包含：
  Bool       : Sort 0
  Bool.false : Const Bool
  Bool.true  : Const Bool
  Bool.rec   :
    Π (motive : Π (_ : Bool), Sort 0),
    Π (case_0 : motive Bool.false),
    Π (case_1 : motive Bool.true),
    Π (target : Bool),
      motive target

S_v11.Inductives = {
  Bool : InductiveInfo(Bool, [Bool.false, Bool.true], Bool.rec)
}

S_v11.Recursors = {
  Bool.rec : RecursorInfo(Bool.rec, Bool, [Bool.false, Bool.true])
}
```

四个 axiom 的角色：
- `Nat`：全局 type
- `zero`：`Nat` 的全局常量
- `Pred`：依值 type family — 对每个 `x : Nat`，`Pred x` 是一个 type
- `choosePred`：依值函数 — 对每个 `x : Nat`，给出 `Pred x` 的一个元素

由这些 axiom 立即可得（任意上下文 `Γ` 下）：

```text
S ; Γ ⊢ Const Nat        : Sort (level 0)
S ; Γ ⊢ Const zero       : Const Nat
S ; Γ ⊢ Const Pred       : Forall (x, Const Nat, Sort (level 0))
S ; Γ ⊢ Const choosePred : Forall (x, Const Nat, App (Const Pred, Var x))
S ; Γ ⊢ App (Const Pred, Const zero) : Sort (level 0)
S ; Γ ⊢ App (Const choosePred, Const zero) : App (Const Pred, Const zero)
```

**评论：** v10 继承的例子继续使用 `S`；v11 的 Bool 例子使用 `S_v11`。需要时会临时扩展状态（如 §19.4 加入 `pair0`，§19.6 加入 `Point`，§19.7 加入 `not`）。

---

## 17. 声明例子

v11 不修改 `StructureCmd`、`ProjectionInfo` 或结构投影机制。以下只保留结论；完整推导见 model v10 的 §17–§21。

### 17.1 StructureCmd Sigma

执行 `StructureCmd Sigma Sigma.mk` 后，生成 `Sigma`、`Sigma.mk`、对应 `StructureInfo`，以及 `Sigma.a` / `Sigma.b` 两个 `ProjectionInfo`。依值字段 `b : B a` 的类型模板仍由 `projection_type` 正确实例化。

### 17.2 StructureCmd Prod

执行 `StructureCmd Prod Prod.mk` 后，生成非依值结构 `Prod`。两个字段分别具有参数类型 `A` 和 `B`；kernel 与 Sigma 使用同一套 `Proj` 规则。

### 17.3 StructureCmd Point

执行 `StructureCmd Point Point.mk` 后，`Point.x p`、`p.x` 和 core 的 `Proj(Point, 0, p)` 通过 v10 的投影元数据机制对应起来。

### 17.4 StructureCmd UnitLike

无参数结构仍可由同一个命令生成；其 type constructor 类型是裸 `Sort 0`。

### 17.5 InductiveCmd Bool                                    【v11 新增】

在 §16 的状态 `S` 上执行：

```text
cmd = InductiveCmd Bool
  constructors = [
    ConstructorDecl(false),
    ConstructorDecl(true)
  ]
```

**第一步：生成名字并检查冲突**

```text
recursor_name = append_local(Bool, rec) = Bool.rec
ctor_names = [
  append_local(Bool, false),
  append_local(Bool, true)
] = [Bool.false, Bool.true]
```

四个声明名 `Bool`、`Bool.false`、`Bool.true`、`Bool.rec` 都未被 `S` 占用；两个构造子名互不相同，也都不等于 recursor 名。

**第二步：生成元数据和声明类型**

```text
info = InductiveInfo(
  Bool,
  [Bool.false, Bool.true],
  Bool.rec
)

rec_info = RecursorInfo(
  Bool.rec,
  Bool,
  [Bool.false, Bool.true]
)

Bool       : Sort 0
Bool.false : Bool
Bool.true  : Bool
```

`make_recursor_type(info)` 生成：

```text
Bool.rec :
  Π (motive : Π (_ : Bool), Sort 0),
  Π (case_0 : motive Bool.false),
  Π (case_1 : motive Bool.true),
  Π (target : Bool),
    motive target
```

**第三步：验证**

- `Sort 0 : Sort 1`，所以 `Bool` 的声明类型合法；
- 临时加入 `Bool : Sort 0` 后，`Const Bool : Sort 0`，所以两个构造子的声明类型合法；
- 临时加入两个构造子后，生成的 `Bool.rec` 类型是 closed CoreTerm，并可推断出某个 Sort。

**第四步：原子更新**

```text
S_v11.Axioms =
  S.Axioms
    .set(Bool, Sort 0)
    .set(Bool.false, Const Bool)
    .set(Bool.true, Const Bool)
    .set(Bool.rec, make_recursor_type(info))

S_v11.Inductives =
  S.Inductives.set(Bool, info)

S_v11.Recursors =
  S.Recursors.set(Bool.rec, rec_info)
```

`Defs`、`Structures` 和 `Projections` 保持不变。执行后满足 §5.1f 的交叉引用不变量。CoreTerm、SurfaceTerm 和通用类型推断规则都不需要增加构造子；只有 `whnf` 通过 `Recursors` 获得新的 iota 计算行为。

---


## 18. 继承自 v10 的关键 Sigma term

v11 沿用 v10 的：

```text
p_ann_surf =
  SAnn(
    SPair(SConst zero, SApp(SConst choosePred, SConst zero)),
    SSigma(x, SConst Nat, SApp(SConst Pred, SVar x))
  )
```

它 elaborate 为 `Sigma.mk` 的普通 App 链；两个分量分别由 `Proj(Sigma, 0, p_core)` 和 `Proj(Sigma, 1, p_core)` 访问。完整推导见 model v10 的 §18。

---

## 19. `whnf` 例子

### 19.1–19.6 继承自 v10 的例子

beta、Sigma/Prod/Point 投影以及对全局定义的 delta reduction 均与 v10 相同。v11 没有修改这些规则。

### 19.7 `Bool.rec` 的 iota reduction                         【v11 新增】

在 `S_v11` 中定义：

```text
not_type_surf =
  SForall(b, SConst Bool, SConst Bool)

not_body_surf =
  SLam(b, SConst Bool,
    SApp(
      SApp(
        SApp(
          SApp(
            SConst Bool.rec,
            SLam(q, SConst Bool, SConst Bool)),
          SConst Bool.true),
        SConst Bool.false),
      SVar b))

S_not = exec(S_v11, DefCmd not not_type_surf not_body_surf)
```

elaboration 后：

```text
not_body =
  Lam(b, Const Bool,
    (Const Bool.rec)
      (Lam(q, Const Bool, Const Bool))
      (Const Bool.true)
      (Const Bool.false)
      (Var b))
```

计算 `not false`：

```text
whnf(S_not, App(Const not, Const Bool.false))
```

1. delta 展开 `Const not`；
2. beta reduction 把 `b` 替换为 `Const Bool.false`；
3. 得到完全应用的 `Bool.rec`：

   ```text
   (Const Bool.rec)
     (Lam(q, Const Bool, Const Bool))
     (Const Bool.true)
     (Const Bool.false)
     (Const Bool.false)
   ```

4. `S_not.Recursors.get(Bool.rec)` 给出构造子顺序 `[Bool.false, Bool.true]`；
5. target 是第 0 个构造子，选择 `case_0 = Const Bool.true`。

所以：

```text
whnf(S_not, App(Const not, Const Bool.false))
= Const Bool.true
```

同理：

```text
whnf(S_not, App(Const not, Const Bool.true))
= Const Bool.false
```

如果 recursor 没有完全应用、target 是变量，或者 target 不是 `RecursorInfo` 中登记的构造子，iota reduction 不触发，应用保持在 whnf。

---

## 20. `defeq` 例子

### 20.1–20.5 继承自 v10 的例子

alpha-renaming、delta/beta/Proj 规约下的定义相等，以及 Sigma、Prod、Point 的 `check_type` 结果均与 v10 相同。

### 20.6 `not false` 与 `true` 定义相等                       【v11 新增】

沿用 §19.7 的状态 `S_not`：

```text
defeq(
  S_not,
  ∅,
  App(Const not, Const Bool.false),
  Const Bool.true
)
```

左边经 delta、beta、iota reduction 规约为 `Const Bool.true`；右边已经是 whnf。因此 `defeq` 返回 `True`。

同理：

```text
defeq(
  S_not,
  ∅,
  App(Const not, Const Bool.true),
  Const Bool.false
) = True
```

`defeq` 本身没有新增分支；它原本就先调用 `whnf`。v11 对定义相等的扩展完全来自 `whnf` 新增的 iota 计算规则。

---

## 21. `elab` 例子

### 21.1–21.6 继承自 v10 的例子

`SAnn`、`SPair`、Sigma 投影、`SProj` 和 `SDot` 的 elaboration 与 v10 相同。v11 不新增 SurfaceTerm 构造子，也不修改 `elab`。

### 21.7 使用 `Bool.rec` 定义 `not`                         【v11 新增】

对 §19.7 的 `not_body_surf` 执行：

```text
elab(
  S_v11,
  ∅,
  not_body_surf,
  Forall(b, Const Bool, Const Bool)
)
```

最外层 `SLam` 产生 `Lam(b, Const Bool, ...)`。内部四层 `SApp` 依次读取 `Bool.rec` 的 Π 类型：

1. motive 必须具有 `Π (_ : Bool), Sort 0`，所以 `SLam(q, Bool, Bool)` 合法；
2. `case_0` 必须具有 `motive Bool.false`，在该 motive 下定义相等于 `Bool`，所以 `Bool.true` 合法；
3. `case_1` 必须具有 `motive Bool.true`，同样定义相等于 `Bool`，所以 `Bool.false` 合法；
4. target 必须具有 `Bool`，所以局部变量 `b` 合法。

最终得到：

```text
Lam(b, Const Bool,
  (Const Bool.rec)
    (Lam(q, Const Bool, Const Bool))
    (Const Bool.true)
    (Const Bool.false)
    (Var b))
```

v11 没有增加 `SMatch`。用户目前直接写 recursor 应用；这一节验证的是已有 `SConst`、`SApp`、`SLam` 和通用 expected-type checking 已足以 elaborate 自动生成的 recursor。

---

## 22. 当前阶段的边界

当前阶段，模型包含：

```text
SurfaceTerm 构造子：SConst, SSort, SVar, SApp, SLam, SForall, SSigma, SPair, SFst, SSnd, SAnn, SProj, SDot

CoreTerm 构造子：Const, Sort, Var, App, Lam, Forall, Proj

数据类型：RecursorBinderTag, ParamDecl, FieldDecl, ConstructorDecl, ParamInfo, FieldInfo,
          StructureInfo, ProjectionInfo, InductiveInfo, RecursorInfo

Command 构造子：AxiomCmd, DefCmd, StructureCmd, InductiveCmd

State 字段：Axioms, Defs, Structures, Projections, Inductives, Recursors

函数：append_local, recursor_binder_name, declaration_name_is_used,
      FV(CoreTerm), subst(CoreTerm), subst_simul, subst_many,
      exec, infer_type, check_type, whnf, defeq, elab, elab_raw, is_sigma_type, collect_app,
      match_structure_type, projection_type, make_forall_chain, make_type_app,
      make_structure_type, make_constructor_type, make_recursor_type
```

类型系统特性：

```text
Surface/Core 分层
elaboration（SurfaceTerm → CoreTerm，携带 expected type）
bidirectional typing（infer / check）on CoreTerm
whnf（弱头部正规化）on CoreTerm，包括 delta、beta、Proj 和 recursor iota
definitional equality（alpha-renaming + reduction + 递归比较）on CoreTerm
conversion-based checking（check_type 用 defeq）on CoreTerm
StructureInfo + Proj（结构信息 + 一般投影，whnf 和 infer_type 都一般化）
StructureCmd（用户声明新结构，exec 自动生成 type constructor 类型、constructor 类型、StructureInfo）
ProjectionInfo + SProj/SDot（投影元数据、完整投影名语法和 dot notation）
InductiveInfo + RecursorInfo + InductiveCmd（nullary inductive、recursor 和 iota reduction）
```

计算规则：

```text
Proj(structName, index, (Const constructor) params... fields...) → fields[index]
App(Lam(x, A, body), a) → body[x := a]
Const defName → body（delta 展开）
(Const recursor) motive case_0 ... case_n (Const ctor_i) → case_i（iota）
```

**评论：** `Proj` 的 whnf 规则由 `StructureInfo` 中的 `constructor`、`len(params)`、`len(fields)` 驱动 — 不需要对任何特定结构硬编码投影化简。添加新结构时，只要通过 StructureCmd 注册到 `Structures` 中，`Proj` 的 whnf 规则自动适用。

**v9 的关键进展：** **StructureCmd 让用户可以声明新结构，exec 自动生成类型签名和 StructureInfo。v9 不预置任何结构 — Sigma 和 Prod 都通过 StructureCmd 定义。** Kernel 层（whnf、infer_type、defeq）无需任何修改即可处理新声明的结构。elab 的 Sigma 专属 surface 语法（`SSigma`/`SPair`/`SFst`/`SSnd`）仍然硬编码 — 这些语法只在 StructureCmd Sigma 执行后才可用。自定义结构的 surface 语法是后续版本的工作。

注意：`(t : A) ↦ t`（Ann 擦除）不再出现在计算规则中 — `Ann` 不是 CoreTerm 构造子。`Σ (x : A), B` 也不再是计算规则的基础 — 它是记号，elaboration 后变成 `App(App(Const Sigma, A), Bfun)`。

尚未加入：

```text
eta 规则
proof irrelevance
universe constraints / level metavariable
reducibility control（opaque / semireducible）
de Bruijn index / fvar
universe polymorphism
implicit arguments
anonymous constructor / surface syntax for custom structures (other than Sigma)
recursive structures（StructureCmd 不支持递归：字段类型不能引用正在声明的 typeName，因为 typeName 在 field elaboration 时尚未加入 S.Axioms）
constructor arguments（包括 `Nat.succ : Nat → Nat`）
recursive constructors 与 induction hypotheses
parametric inductive（如 `List A`）
indexed inductive（如 `Eq`）
`SMatch` / `match ... with ...` 表层语法
large elimination 限制
real Lean Expr
```

v11 的定位：

> v8 是"让 Proj 的类型推断一般化" — Sigma 和 Prod 由同一个 StructureInfo + Proj 机制处理；
> v9 是"让所有结构都由用户声明" — StructureCmd 自动生成 StructureInfo（包括 Sigma），kernel 规则自动适用；
> v10 是"让投影有名字、让 dot notation 工作" — ProjectionInfo + SProj + SDot。
> v11 是"从单构造子结构跨到多构造子归纳类型" — InductiveCmd + 自动 recursor + iota reduction。
>
> CoreTerm 和 SurfaceTerm 不变；
> State 新增 Inductives / Recursors；
> Command 新增 InductiveCmd；
> kernel 只有 whnf 新增由 RecursorInfo 驱动的 iota reduction；
> infer_type、check_type、defeq 和 elab 的通用规则不变。
