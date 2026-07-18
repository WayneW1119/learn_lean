# model v8

> **相对于 v7 的变化：**
>
> * §5：`StructureInfo` 扩展为 `params: List[ParamInfo]` + `fields: List[FieldInfo]`；新增 `ParamInfo` 和 `FieldInfo` 类型
> * §12a（新增章节）：`subst_many`、`match_structure_type`、`projection_type` — 依赖 §5/§11/§12 的概念，因此在 §12 之后定义
> * §5a：预置状态新增 `Prod` 结构（非依值乘积），预置状态更名为 `SΣΠ`
> * §14：`infer_type(Proj)` 不再硬编码 Sigma，改用 `match_structure_type` + `projection_type` 一般化
> * v8 不引入 `StructureCmd / InductiveCmd / Nat.rec`
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
- v8 的 `CoreTerm` 有 7 个构造子：`Const`、`Sort`、`Var`、`App`、`Lam`、`Forall`、`Proj`。
  - `Sigma` 不再是 core 构造子 — 它是环境中的全局名字 `Const Sigma`。
  - `Pair` 不再是 core 构造子 — 它是 `Const Sigma.mk` 的应用。
  - `fst/snd` 不再是 core 构造子 — 它们是 `Proj(Sigma, 0/1, target)`。
  - 所有 kernel 函数（`infer_type`、`check_type`、`whnf`、`defeq`、`FV`、`subst`）只作用于 `CoreTerm`。
  - `elab` 函数负责把 `SurfaceTerm` 转换为 `CoreTerm`。
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

`SurfaceTerm` 表示用户在表层语法中写的东西。自 v7 起 `SurfaceTerm` 不变 — 用户仍然写 `Σ (x : A), B`、`⟨a, b⟩`、`fst p`、`snd p`、`(t : A)`。但 elaboration 后它们变成不同的 CoreTerm。

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

**评论：** `SurfaceTerm` 保留了 `SSigma / SPair / SFst / SSnd / SAnn`。用户确实会写这些东西。但从 v7 起，elaboration 后它们分别变成：

```text
SSigma(x, A, B) → (Const Sigma) A (fun (x : A) => B)
SPair(a, b)     → (Const Sigma.mk) A (fun (x : A) => B) a b    (需 expected type)
SFst(t)         → Proj(Sigma, 0, t_core)
SSnd(t)         → Proj(Sigma, 1, t_core)
SAnn(t, A)      → t_core                                        (Ann 被消耗)
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
- v8 暂时**不引入** `ProjectionInfo`。`StructureInfo` 记录 `typeName`、`constructor`、`params`、`fields`（见 §5）。`numParams = len(params)`、`numFields = len(fields)` 不再单独存储。

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

`Proj` 用一个构造子解决了所有结构的字段提取。这就是"一般化"的具体收益。

### 4.3 v6 → v7 的对应表

v7 的每个核心变化都对应一个 v6 的构造子：

```text
v6                            v7
─────────────────────────────────────────────────────────────
CSigma(x, A, B)               App(App(Const Sigma, A), Lam(x, A, B))
                              （Sigma 类型的 formation → 全局常量的应用）

CPairTyped(x, A, B, a, b)    App(App(App(App(Const Sigma.mk, A), Bfun), a), b)
                              （pair 的 introduction → 构造子的应用）

CFst(t)                       Proj(Sigma, 0, t)
CSnd(t)                       Proj(Sigma, 1, t)
                              （fst/snd 的 elimination → 一般投影）

CConst / CSort / ...          Const / Sort / ...
                              （去掉 C 前缀）
```

直觉：

- **v6 的 `CSigma` 是"自带语法糖的构造子"** — 它知道自己是一个 Sigma 类型，有 `A` 和 `B` 两个子 term，自带 binder 语义。
- **v7 的 `App(App(Const Sigma, A), Bfun)` 是"打散后的版本"** — Sigma 不再是特殊构造子，它只是把一个叫 `Sigma` 的全局常量应用到两个参数上。`B` 被包装成了 `Lam(x, A, B)`（即 `Bfun`），因为依值类型需要一个函数来表达。

- **v6 的 `CPairTyped` 是"自带类型信息的特殊构造子"** — 5 个字段（x, A, B, a, b），其中类型信息被嵌入构造子中。
- **v7 的 `(Const Sigma.mk) A Bfun a b` 是"构造子的普通应用"** — 4 层嵌套 `App`，没有特殊构造子。类型信息在构造子 `Sigma.mk` 的类型签名中（存于 `S.Axioms`），不在 term 本身。

- **v6 的 `CFst(t)` / `CSnd(t)` 是"专门为 Sigma 设计的投影"** — 只能处理 Sigma。
- **v7 的 `Proj(Sigma, 0, t)` / `Proj(Sigma, 1, t)` 是"一般投影"** — 可以处理任何在 `S.Structures` 中注册的结构。

### 4.4 如果再加一个结构？

假设将来我们在 `S.Structures` 中注册一个 `Point` 结构：

```text
S.Structures.set(Point, StructureInfo(
  typeName    = Point,
  constructor = Point.mk,
  params = [
    ParamInfo(X, Sort(level 0))
  ],
  fields = [
    FieldInfo(x, Var X),
    FieldInfo(y, Var X)
  ]
))
```

那么 `whnf` 的 Proj 规则**不需要任何修改**就能处理：

```text
whnf(S, Proj(Point, 0, (Const Point.mk) (Const Nat) a b))
= a

whnf(S, Proj(Point, 1, (Const Point.mk) (Const Nat) a b))
= b
```

因为 Proj 的 whnf 规则只看 `S.Structures.get(Point)`，查出 `constructor = Point.mk`、`len(info.params) = 1`、`len(info.fields) = 2`，然后 `field_pos = 1 + 0 = 1`（第一个字段在参数列表的第 1 位，因为第 0 位是类型参数 X）。

这就是 Proj 的"一般性"在实践中的意义：**新增结构不需要修改 kernel 代码，只需要在 State 中注册信息。**

---
## 4a. 辅助函数（CoreTerm 层面）

本节定义几个只依赖 CoreTerm 的辅助函数。v8 新增的辅助函数（`subst_many`、`match_structure_type`、`projection_type`）依赖 `subst`（§11）、`whnf`（§12）、`State`（§5）等后定义的概念，因此放在 §12a（在 `whnf` 之后定义）。

### 4a.1 `is_sigma_type`

```python
# 写作 is_sigma_type(t)
def is_sigma_type(t : CoreTerm) -> Optional[Pair[CoreTerm, CoreTerm]]:
    '''
    如果 t = App(App(Const Sigma, A), Bfun)，返回 Pair(A, Bfun)
    否则返回 None
    此函数只做模式匹配，不调用 whnf（调用者需要预先 whnf 输入）。
    v8 中此函数仍用于 elab 的 Sigma 专属分支。
    一般化的类型识别应使用 match_structure_type（§12a.2）。
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

其中 `Bfun` 通常是一个 lambda：

```text
Bfun = fun (x : A) => B_body
```

**评论：** `is_sigma_type` 与 `match_structure_type(S, Sigma, T)`（§12a.2）的**结果**在大多数情况下相同，但机制不同：(1) `is_sigma_type` 不接受 `State` 参数，也不验证 `S.Structures` 中是否注册了 Sigma；(2) `is_sigma_type` 不内部调用 `whnf`，需要调用者预先化简输入（elab 中就是这样使用的）；(3) `is_sigma_type` 返回 `Pair(A, Bfun)`（两个值），而 `match_structure_type` 返回参数值列表。保留 `is_sigma_type` 是为了 elab 中 Sigma 专属分支的兼容。

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

例如：

```text
collect_app((Const Sigma.mk) A B a b)
=
Pair(Const Sigma.mk, [A, B, a, b])
```

**评论：** 这个函数在 `whnf` 的 `Proj` 分支中用于识别构造子应用。因为 constructor application 在 CoreTerm 里就是嵌套 `App`，没有特殊构造子。

### 4a.3 元语言辅助函数

为了写例子方便，定义两个**元语言**辅助函数（不是 CoreTerm 构造子）：

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

这些只是元语言函数，不是新的 CoreTerm 构造子。

---
## 5. `State` 与 `StructureInfo`                                   【v8 修改】

### 5.1 `ParamInfo` 与 `FieldInfo`                               【v8 新增】

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

### 5.2 `StructureInfo`                                          【v8 修改】

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
- `numParams = len(params)`、`numFields = len(fields)`。v8 不再单独存储这两个字段，改用 `len()`。whnf 中的引用也相应更新。

对于 `Sigma`（见 §5a）：

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

**评论：** v8 不引入 `ProjectionInfo`，不记录字段名字的全局投影名（如 `Sigma.fst`）。`Proj(structName, index, target)` 已经编码了投影的全部信息。将来如果要更接近 Lean 的 projection declaration 机制，再把 `Sigma.fst / Sigma.snd` 作为全局名字加入。

### 5.2a `StructureInfo` well-formedness invariant           【v8 新增】

`S.Structures` 中的每个 `StructureInfo` 必须满足以下条件：

1. **类型名和构造子名已注册：** `info.typeName` 和 `info.constructor` 必须存在于 `S.Axioms` 或 `S.Defs` 中。
2. **参数名互不相同：** `info.params` 中所有 `ParamInfo.name` 互不相等。
3. **字段名互不相同：** `info.fields` 中所有 `FieldInfo.name` 互不相等。
4. **参数名和字段名互不相同：** 任何 `ParamInfo.name` 不等于任何 `FieldInfo.name`。
5. **ParamInfo.type 只引用前序 params：** `info.params[i].type` 中的 `Var` 只能引用 `info.params[0..i-1].name`，不能引用后续参数名或字段名。
6. **FieldInfo.type 只引用 params 和前序 fields：** `info.fields[j].type` 中的 `Var` 只能引用 `info.params` 的名字和 `info.fields[0..j-1].name`，不能引用后续字段名。
7. **构造子参数顺序：** `info.constructor` 的类型签名中的参数顺序必须是先 `params` 后 `fields`。
8. **构造子返回类型：** `info.constructor` 的类型签名的返回类型必须是 `(Const info.typeName)` 应用到所有 `params` 的类型上。

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

**评论：** 当前模型中，`SΣΠ` 预置状态的 Sigma 和 Prod 都满足这些条件。将来通过 `StructureCmd` 用户声明自定义结构时，`exec` 必须验证这些条件。v8 不引入 `StructureCmd`，所以这些条件目前作为 **invariant** 陈述 — 假设 `S.Structures` 中的信息始终满足上述 8 条。

### 5.3 `State`

```text
class State:
    Axioms     : PartialMap[g : GlobalName, t : CoreTerm]                 # 写作 g : t
    Defs       : PartialMap[g : GlobalName, Pair[t1 : CoreTerm, t2 : CoreTerm]]  # 写作 g : (t1, t2)
    Structures : PartialMap[g : GlobalName, info : StructureInfo]          # 写作 g ↦ info
```

若 `S : State`，则：

```text
S.Axioms
S.Defs
S.Structures
```

分别表示该状态中的三个字段。

其中：
- 若 `S.Axioms.get(n) = A`，则表示：全局名字 `n` 被声明为 axiom，类型是 `A`。
- 若 `S.Defs.get(n) = Pair(A, t)`，则表示：全局名字 `n` 被声明为 def，类型是 `A`，body 是 `t`。
- 若 `S.Structures.get(n) = info`，则表示：`n` 是一个已登记的结构类型，结构信息是 `info`。

注意：`S.Structures.get(Sigma)` 不是天生存在的。它必须来自某个具体状态。v8 中通过预置状态 `SΣΠ` 给出（见 §5a）。

---
## 5a. 预置状态 `SΣΠ`                                              【v8 修改】

### 5a.1 全局名字

取四个全局名字：

```text
Sigma, Sigma.mk, Prod, Prod.mk : GlobalName
```

并要求所有名字互不相同。

v8 暂时**不引入** `Sigma.fst / Sigma.snd / Prod.fst / Prod.snd`。因为 `Proj(Sigma, 0, p)` 和 `Proj(Sigma, 1, p)` 已经表达了投影。

### 5a.2 单宇宙简化版 `Sigma` 的类型

为避免 universe polymorphism，v8 先使用单宇宙版本：

```text
Sigma :
  Π (A : Sort (level 0)),
  Π (B : Π (x : Var A), Sort (level 0)),
  Sort (level 0)
```

即：

```text
Const Sigma
:
Π (A : Sort (level 0)),
Π (B : Π (x : Var A), Sort (level 0)),
Sort (level 0)
```

含义：给定 `A : Sort 0` 和 `B : Π (x : A), Sort 0`，得到 `Sigma A B : Sort 0`。

### 5a.3 `Sigma.mk` 的类型

```text
Sigma.mk :
  Π (A : Sort (level 0)),
  Π (B : Π (x : Var A), Sort (level 0)),
  Π (a : Var A),
  Π (b : (Var B) (Var a)),
  (Const Sigma) (Var A) (Var B)
```

即：

```text
Const Sigma.mk
:
Π (A : Sort (level 0)),
Π (B : Π (x : Var A), Sort (level 0)),
Π (a : Var A),
Π (b : (Var B) (Var a)),
(Const Sigma) (Var A) (Var B)
```

含义：给定 `A`、`B`、`a : A`、`b : B a`，得到 `Sigma.mk A B a b : Sigma A B`。

**评论：** 这里 `A`、`B`、`a`、`b` 是 binder 使用的 `LocalName`，不是元语言变量。完整 Lean 版本的 `Sigma` 是 universe-polymorphic，还有 implicit arguments。当前模型没有 universe parameter 和 implicit argument 机制，所以用单宇宙显式版本。

### 5a.4 `Prod` 的类型                                            【v8 新增】

```text
Prod :
  Π (A : Sort (level 0)),
  Π (B : Sort (level 0)),
  Sort (level 0)
```

即：

```text
Const Prod
:
Π (A : Sort (level 0)),
Π (B : Sort (level 0)),
Sort (level 0)
```

含义：给定 `A : Sort 0` 和 `B : Sort 0`，得到 `Prod A B : Sort 0`。注意 `B` 不依赖 `A` — 这是**非依值**乘积（与 Sigma 的依值乘积不同）。

### 5a.5 `Prod.mk` 的类型                                         【v8 新增】

```text
Prod.mk :
  Π (A : Sort (level 0)),
  Π (B : Sort (level 0)),
  Π (a : Var A),
  Π (b : Var B),
  (Const Prod) (Var A) (Var B)
```

即：

```text
Const Prod.mk
:
Π (A : Sort (level 0)),
Π (B : Sort (level 0)),
Π (a : Var A),
Π (b : Var B),
(Const Prod) (Var A) (Var B)
```

含义：给定 `A`、`B`、`a : A`、`b : B`，得到 `Prod.mk A B a b : Prod A B`。注意 `b : Var B` 而非 `b : (Var B) (Var a)` — 第二字段不依赖第一字段。

### 5a.6 `SΣΠ` 的内容                                              【v8 修改】

预置状态 `SΣΠ`：

```text
SΣΠ.Axioms = {
  Sigma :
    Π (A : Sort (level 0)),
    Π (B : Π (x : Var A), Sort (level 0)),
    Sort (level 0),

  Sigma.mk :
    Π (A : Sort (level 0)),
    Π (B : Π (x : Var A), Sort (level 0)),
    Π (a : Var A),
    Π (b : (Var B) (Var a)),
    (Const Sigma) (Var A) (Var B),

  Prod :
    Π (A : Sort (level 0)),
    Π (B : Sort (level 0)),
    Sort (level 0),

  Prod.mk :
    Π (A : Sort (level 0)),
    Π (B : Sort (level 0)),
    Π (a : Var A),
    Π (b : Var B),
    (Const Prod) (Var A) (Var B)
}

SΣΠ.Defs = {}

SΣΠ.Structures = {
  Sigma : StructureInfo(Sigma, Sigma.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Π (x : Var A), Sort(level 0))
  ], [
    FieldInfo(a, Var A),
    FieldInfo(b, App(Var B, Var a))
  ]),
  Prod : StructureInfo(Prod, Prod.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Sort(level 0))
  ], [
    FieldInfo(a, Var A),
    FieldInfo(b, Var B)
  ])
}
```

**评论：** Prod 与 Sigma 的关键区别在于：Prod 的第二字段类型是 `Var B`（不是 `App(Var B, Var a)`），因为 Prod 是非依值乘积 — B 不依赖 a。Sigma 的第二字段类型是 `App(Var B, Var a)`，因为 B 可以依赖 a。`projection_type` 会根据 `FieldInfo.type` 模板自动处理这两种情况。

**评论：** `Sigma` 和 `Prod` 不是模型宇宙里自动存在的魔法对象。它们是预置状态 `SΣΠ` 中明确记录的全局信息 — 类型签名在 `Axioms` 中，结构信息在 `Structures` 中。这类似于 Lean 的 prelude 已经提供了 `Sigma` 和 `Prod`。

---
## 6. 顶层命令 `Command`

定义数据类型 `Command`：

```text
Command = AxiomCmd(name : GlobalName, term : SurfaceTerm)             # 写作 AxiomCmd n : A
        | DefCmd(name : GlobalName, term1 : SurfaceTerm, term2 : SurfaceTerm) # 写作 DefCmd n A t
```

用户写 `SurfaceTerm`；`exec` 会先通过 `elab` 转换为 `CoreTerm` 再存储。

---
## 7. 状态执行函数 `exec`

定义一个部分函数：

```text
exec(S : State, cmd : Command) -> State
```

### 7.1 状态转移记号

约定：

```text
S --cmd--> S'
```

作为 `exec(S, cmd) = S'` 的简写。

### 7.2 规则 1：执行 `AxiomCmd`

若：

```text
cmd = AxiomCmd(n, A_surf)
A_core = elab(S, ∅, A_surf, None)
infer_type(S, ∅, A_core) : Sort u                    （声明的类型本身必须是 type）
not S.Axioms.contains(n)
not S.Defs.contains(n)
not S.Structures.contains(n)
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
    Structures = S.Structures
)
```

**评论：** `infer_type(S, ∅, A_core) : Sort u` 确保声明的类型本身是一个 type。否则用户可以错误地声明 `AxiomCmd bad : Const zero` — `Const zero : Const Nat` 不是 type。此外，v7 新增了 `S.Structures`，新名字也不应与已有结构名冲突。

### 7.3 规则 2：执行 `DefCmd`

若：

```text
cmd = DefCmd(n, A_surf, t_surf)
A_core = elab(S, ∅, A_surf, None)
infer_type(S, ∅, A_core) : Sort u                    （声明的类型本身必须是 type）
t_core = elab(S, ∅, t_surf, A_core)
not S.Axioms.contains(n)
not S.Defs.contains(n)
not S.Structures.contains(n)
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
    Structures = S.Structures
)
```

### 7.4 `exec` 代码

```python
# 写作 exec(S, cmd)
def exec(S: State, cmd: Command) -> State:
    '''
    执行顶层命令并返回更新后的状态。
    Command 中的 term 是 SurfaceTerm，需要先通过 elab 转换为 CoreTerm。
    v7：State 新增 Structures 字段，exec 不修改 Structures。
    '''

    if isinstance(cmd, AxiomCmd):
        n, A_surf = cmd.args
        A_core = elab(S, ∅, A_surf, None)
        TA = whnf(S, infer_type(S, ∅, A_core))
        if not isinstance(TA, Sort):
            raise Error
        if n not in S.Axioms and n not in S.Defs and n not in S.Structures:
            return State(
                Axioms = S.Axioms.set(n, A_core),
                Defs   = S.Defs,
                Structures = S.Structures
            )
        raise Error

    elif isinstance(cmd, DefCmd):
        n, A_surf, t_surf = cmd.args
        A_core = elab(S, ∅, A_surf, None)
        TA = whnf(S, infer_type(S, ∅, A_core))
        if not isinstance(TA, Sort):
            raise Error
        t_core = elab(S, ∅, t_surf, A_core)
        if n in S.Axioms or n in S.Defs or n in S.Structures:
            raise Error
        if not check_type(S, ∅, t_core, A_core):
            raise Error
        return State(
            Axioms = S.Axioms,
            Defs = S.Defs.set(n, Pair(A_core, t_core)),
            Structures = S.Structures
        )

    raise Error
```

`elab` 在 §15a 定义。这是一个不可避免的前向引用：`exec` 处理用户输入（SurfaceTerm），必须调用 `elab` 来转换；而 `elab` 又调用 `infer_type`/`check_type`（§14）来验证类型。概念上，`exec` → `elab` → `infer_type/check_type` → `whnf/defeq`。文档按照依赖关系的反向顺序排列：先定义底层（`whnf`、`defeq`、`infer_type`），再定义上层（`elab`、`exec`）。

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
## 9. `HasType` 的具体定义

`HasType` 是 `State × Context × CoreTerm × CoreTerm` 的最小子集，满足以下规则。

核心设计：**Sigma 类型的 formation、pair 的 introduction、fst/snd 的 elimination 不再需要专门的 HasType 规则。** 它们由基础的 `Const` 和 `App` 规则覆盖 — 因为 Sigma 现在是 `Const Sigma`，pair 是 `(Const Sigma.mk) A B a b`，它们的类型通过普通函数应用规则计算。

唯一新增的规则是 `Proj` 的 elimination rule。

### 9.1 基本 typing 规则

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

### 9.2 `Sort / Π / fun / App` 规则

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

### 9.3 `Proj` 规则                                                  【v8 修改】

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

- v8 的 HasType 规则与 `infer_type` 实现一致 — 都使用 `match_structure_type` + `projection_type`，不硬编码任何特定结构。
- 一般规则的三个前提条件：(1) `S.Structures` 中注册了该结构；(2) target 的类型能匹配该结构的参数；(3) index 在合法范围内。这三条对应 `infer_type` 中 `Proj` 分支的三个检查。
- v6 中的 `CSigma` formation rule、`CPairTyped` introduction rule、`CFst/CSnd` elimination rule 已全部消失 — 被更基础的 `Const/App/Proj` 规则取代。

### 9.4 `Ann` 规则

`Ann` 不再是 CoreTerm 的构造子（从 v6 开始）。类型标注在表层由 `SAnn` 处理，elaboration 时被消耗。详见 §15a.6。

### 9.5 `Conversion` 规则

- **Conversion 规则**（类型转换）

  注意：`defeq` 在 §13 定义。此处是前向引用 — HasType 规则的形式化表述需要 `defeq`，但 `defeq` 的定义在后面。这是不可避免的：`defeq` 依赖 `whnf`（§12），而 HasType 规则需要在 `whnf` 之前给出（因为 §9 是 typing 规则的基础）。

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
## 10. `FV`

定义函数：

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

### 10.1 例子

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
## 11. substitution

定义函数：

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

### 11.1 例子

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

---
## 12. 计算规则：`whnf`

`whnf`（weak head normal form）把 CoreTerm 化简到弱头部正规形式。自 v7 起 `whnf` 作用于 `CoreTerm` — 不再有 `Ann` 擦除分支（CoreTerm 中没有 `Ann`），不再有 `CFst`/`CSnd` 匹配 `CPairTyped` 的分支（这些构造子已不存在），取而代之的是 `Proj` 分支。

```text
whnf(S, t) -> CoreTerm
```

它只在 term 的**头部**进行必要的化简 — 不递归进入 body、参数等子结构。"weak" 指不深入内部，"head" 指只处理最外层的 redex。

**评论：** 为什么不直接加入完整的 normalization 或 definitional equality？因为 definitional equality 依赖 whnf — `defeq(S, Γ, A, B)` 的标准实现是把 A 和 B 都 whnf 后比较头部，再递归比较子项。所以 whnf 是 conversion 的基础构件，先加它是最自然的顺序。

### whnf 的核心直觉

一句话：**从外往里，一层一层剥**。

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
whnf(S, App(f, a)) = App(whnf(S, f), a)        当 whnf(S, f) 不是 Lam
```

```python
if isinstance(t, App):
    f, a = t.args
    f0 = whnf(S, f)

    if isinstance(f0, Lam):
        x, A, body = f0.args
        return whnf(S, subst(body, x, a))

    return App(f0, a)
```

**评论：**

- Beta reduction 是 `Lam(x, A, body) a ↦ body[x := a]`。注意这里不先化简参数 `a` — 这是 **weak head** reduction 的特点：只化简头部到足够暴露结构，不化简参数或 body 内部。
- 如果 `f` whnf 后不是 `Lam`（比如是一个 axiom，或另一个 `App`），则无法继续化简，返回 `App(f0, a)`。

### 12.3 Proj 的结构投影化简

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

### 12.4 其他情况

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

### 12.5 `whnf` 完整代码

```python
# 写作 whnf(S, t)
def whnf(S : State, t : CoreTerm) -> CoreTerm:
    '''
    把 t 化简到 weak head normal form。
    处理：delta 展开（Const）、beta reduction（App）、Proj 结构投影化简。
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

        return App(f0, a)

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

**评论：** v8 的 `whnf` 只有三个计算分支（Const delta、App beta、Proj 结构投影），其余四个构造子（Sort, Var, Lam, Forall）是值。v7 用 `info.numParams`/`info.numFields`；v8 改为 `len(info.params)`/`len(info.fields)`，因为 `StructureInfo` 已经存储了完整的 params/fields 列表。

---

## 12a. 辅助函数（结构投影层面）                                  【v8 新增】

本节定义 v8 新增的辅助函数，它们依赖 `subst`（§11）、`whnf`（§12）、`State`（§5）、`StructureInfo`（§5）等后定义的概念。因此放在 §12 之后，而不是 §4a 中（§4a 的函数只依赖 CoreTerm）。

### 12a.1 `subst_many`

```python
# 写作 subst_many(t, [(x1,e1), ..., (xn,en)])
def subst_many(t : CoreTerm, substitutions : List[Pair[LocalName, CoreTerm]]) -> CoreTerm:
    '''
    在 t 中逐个替换多个自由变量。
    substitutions 是 [(x1, e1), ..., (xn, en)] 列表。
    实现方式：对 substitutions 列表中的每个 (name, replacement)，
    依次调用 subst(t, name, replacement)。
    本文中 subst_many 只用于替换 structure schema variables（§5.2a）。
    我们假设这些 schema variables 经过 freshening 处理，
    与对象层 Γ 中的 LocalName 不冲突（隐含的 freshening invariant），
    因此逐个替换可以模拟 simultaneous substitution。
    '''
    for name, replacement in substitutions:
        t = subst(t, name, replacement)
    return t
```

**评论：** 实现是逐个替换，不是同时替换。`projection_type` 中的替换对象是 structure schema 的变量名（如 `A`、`B`、`a`、`b`），这些名字与对象层 `Γ` 中的 `LocalName` 经过 freshening 处理后不相交（见 §5.2a 的 invariant 条件 2-4：参数名和字段名互不相同，且与用户变量不冲突）。因此逐个替换等价于同时替换。严格实现中，应使用 simultaneous substitution 或单独的 `SchemaName` 类型。本文为简化，用 `LocalName` 表示 schema names，并隐含 freshening invariant。

### 12a.2 `match_structure_type`

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

**评论：** 此函数是 `is_sigma_type`（§4a.1）的一般化。`match_structure_type(S, Sigma, T)` 的结果与 `is_sigma_type(T)` 类似 — 但它能处理任何结构。两者有三个重要区别：(1) `match_structure_type` 内部调用 `whnf`，而 `is_sigma_type` 不调用（需要调用者预先 whnf）；(2) `match_structure_type` 返回所有参数值的列表 `[A_val, Bfun_val]`，而 `is_sigma_type` 返回 `Pair(A_val, Bfun_val)`；(3) `match_structure_type` 检查 `S.Structures` 中是否注册了该结构，而 `is_sigma_type` 不检查。严格相等 `len(args) != len(info.params)` 确保部分应用的结构类型不会被匹配。

### 12a.3 `projection_type`

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

    # Build substitution: param names → param values, then prior field names → Proj
    # 注意顺序：先替换参数名，再替换前序字段名。因为字段模板可能引用参数名（如 App(Var B, Var a) 中的 B）。
    substitutions = []
    for i, param in enumerate(info.params):
        substitutions.append(Pair(param.name, params[i]))
    for j in range(index):
        substitutions.append(Pair(info.fields[j].name, Proj(info.typeName, j, target)))

    return subst_many(fieldType, substitutions)
```

**评论：** 这是 v8 的核心变化。字段类型是模板，使用 `Var` 引用参数名和前序字段名。`projection_type` 把每个参数名替换为实际的参数值，把每个前序字段名替换为对应的投影。结果是一个合法的 CoreTerm，不再包含 schema 变量。

**评论（替换顺序）：** 替换列表先放参数名（如 A → A_val, B → Bfun_val），再放前序字段名（如 a → Proj(Sigma, 0, target)）。这个顺序不影响结果（因为 schema 变量互不依赖），但逻辑上更清晰 — 先处理"来自类型的参数"，再处理"来自前序字段的投影"。

---
## 13. 类型等价：`defeq`

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

### 为什么不能只比较 `whnf`

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

### 13.1 基本情况（无子项的构造子）

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

### 13.2 递归情况（有子项、无 binder 的构造子）

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

### 13.3 Binder 情况（Lam / Forall）

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

### 13.4 其他情况

如果两边 whnf 后的头部构造子不同（比如一边是 `App`，另一边是 `Sort`），返回 `False`。

### 13.5 `defeq` 完整代码

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
## 14. `infer_type` 与 `check_type`                                 【v8 修改】

### 14.0 背景：为什么需要两个函数？

如果所有 CoreTerm 都能从自身推断类型，那么 `check_type` 只需要是 `infer_type` 的简单包装：

```text
check_type(S, Γ, t, A) = defeq(S, Γ, infer_type(S, Γ, t), A)
```

这对 `Var`、`Const`、`Sort`、`App`、`Lam`、`Forall` 都完全成立。`Proj` 也可以 infer — **v8 的 Proj infer_type 已通过 `StructureInfo` 的 params/fields 信息一般化**，不再硬编码 Sigma。任何在 `S.Structures` 中注册且带有完整 `ParamInfo`/`FieldInfo` 的结构，`Proj` 都能推断类型。

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
- **Elimination**：`Proj(structName, i, p)` 需要专门的分支来计算字段类型 — v8 中这个分支通过 `match_structure_type` + `projection_type` 实现，对任何在 `S.Structures` 中注册的结构都适用。

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
    v8：Proj 分支不再硬编码 Sigma，改用 match_structure_type + projection_type。
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
    v8：自 v7 起沿用，check_type 是 infer_type 的简单包装。
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
  3. `infer_type(S, Γ, App(App(Const Sigma, A), Bfun))` → 继续 App 规则链，最终得到 `Sort(max_level(u, v))`。
  整个过程由 Const + App 规则自动处理，不需要专门的 CSigma 分支。

- **Pair introduction 的类型推断路径：**
  1. `infer_type(S, Γ, Const Sigma.mk)` → 从 `S.Axioms` 查到 `Sigma.mk` 的类型（一个嵌套 Π 类型）。
  2. 依次应用参数 `A`, `Bfun`, `a`, `b`，每次 App 规则推断类型。
  3. 最终得到 `App(App(Const Sigma, A), Bfun)` 即 Sigma 类型。
  整个过程由 Const + App 规则自动处理，不需要专门的 CPairTyped 分支。

- **Proj 的类型推断** 已一般化。`match_structure_type(S, structName, Ttarget)`（定义在 §12a.2）从目标类型中提取结构参数值，`projection_type(S, Γ, info, index, target, params)`（定义在 §12a.3）用 `FieldInfo.type` 模板计算字段类型。两者对任何在 `S.Structures` 中注册的结构都适用。

- **一般化机制对 Sigma 的工作方式：** 对于 `Proj(Sigma, 0, p)`：
  1. `match_structure_type(S, Sigma, Ttarget)` 从 `p` 的类型中提取 `[A_val, Bfun_val]`。
  2. `projection_type(S, Γ, info, 0, p, [A_val, Bfun_val])` — `fields[0].type = Var A`，替换 `A → A_val`，得到 `A_val`。
  对于 `Proj(Sigma, 1, p)`：
  1. 同上提取 `[A_val, Bfun_val]`。
  2. `projection_type` — `fields[1].type = App(Var B, Var a)`，替换 `A → A_val`、`B → Bfun_val`、`a → Proj(Sigma, 0, p)`，得到 `App(Bfun_val, Proj(Sigma, 0, p))`。

- **一般化机制对 Prod 的工作方式：** 对于 `Proj(Prod, 0, p)`：
  1. `match_structure_type(S, Prod, Ttarget)` 从 `p` 的类型中提取 `[A_val, B_val]`。
  2. `projection_type` — `fields[0].type = Var A`，替换 `A → A_val`，得到 `A_val`。
  对于 `Proj(Prod, 1, p)`：
  1. 同上提取 `[A_val, B_val]`。
  2. `projection_type` — `fields[1].type = Var B`（非依值！），替换 `A → A_val`、`B → B_val`，得到 `B_val`。
  注意 Prod 的第二字段类型是 `Var B` 而非 `App(Var B, Var a)` — 这个区别完全由 `FieldInfo.type` 模板表达。

- 注意 `projection_type` 返回的类型中可能包含 `Proj(...)` 形式（如 Sigma 的第二字段类型中的 `Proj(Sigma, 0, target)`）— 这是未经化简的项。`whnf` 可以化简它（如果 target 是构造子应用），但 `infer_type` 本身不做化简。`check_type` 通过 `defeq` 在比较时自动调用 `whnf` 来处理这种情况。

- 在 `App` 规则中，`infer_type` 已经调用了 `check_type` 来检查参数类型。所以 `infer` 和 `check` 是互相调用的，不是单方向的。

- `infer_type` 在所有类型头部检查处使用了 `whnf` 展开。具体来说：`Forall`/`Lam` 分支中检查 `TA : Sort` 和 `TB : Sort` 时、`App` 分支中检查 `Tf : Forall` 时、`Proj` 分支中通过 `match_structure_type` 检查 `Ttarget` 是否匹配结构类型时，都先用 `whnf` 展开推断出的类型。

---
## 15. 构建前置状态 `S`                                         【v8 修改】

为了后续展示 `elab` / `whnf` / `defeq` 的例子，先构建一个共同的前置状态 `S`。

v8 不再从完全空的状态开始。取预置状态 `SΣΠ`（§5a 中定义），在其基础上依次添加 `Nat`、`zero`、`Pred`、`choosePred`。

```text
S0 = SΣΠ  (pre-set state with Sigma, Sigma.mk, Prod, Prod.mk)

S1 = exec(S0, AxiomCmd Nat : SSort (level 0))
S2 = exec(S1, AxiomCmd zero : SConst Nat)
S3 = exec(S2, AxiomCmd Pred : SForall (x, SConst Nat, SSort (level 0)))
S  = exec(S3, AxiomCmd choosePred : SForall (x, SConst Nat, SApp (SConst Pred, SVar x)))
```

最终得到的状态 `S`：

```text
S.Axioms = SΣΠ.Axioms ∪ {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Forall (x, Const Nat, Sort (level 0)),
  choosePred : Forall (x, Const Nat, App (Const Pred, Var x))
}
S.Defs = {}
S.Structures = SΣΠ.Structures = {
  Sigma : StructureInfo(Sigma, Sigma.mk, params=[A, B], fields=[(a, Var A), (b, App(Var B, Var a))]),
  Prod  : StructureInfo(Prod, Prod.mk, params=[A, B], fields=[(a, Var A), (b, Var B)])
}
```

四个新 axiom 的角色：
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

**评论：** 后续 §18-§21 的所有例子都基于这个状态 `S`。需要时会在用到的地方临时扩展状态（如 §19.4 加入 `pair0`）。State `S` 现在包含了 `SΣΠ` 的内容 — `Sigma`、`Sigma.mk`、`Prod`、`Prod.mk` 在 `Axioms` 中，`Sigma` 和 `Prod` 在 `Structures` 中。这些不是 v8 文档新加的，而是从预置状态继承来的。

---

## 15a. `elab`：从 SurfaceTerm 到 CoreTerm                    【v8 修改】

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

**两层结构：** `elab` 实际由两个函数组成：

```text
elab(S, Γ, st, expected) = check(elab_raw(S, Γ, st, expected), expected)
```

- `elab_raw`：做结构转换（Surface → Core），用 `expected` 指导需要目标类型的分支（如 `SPair`、`SAnn`），但不验证最终结果是否满足 `expected`。
- `elab`（外层包装）：调用 `elab_raw` 得到 `core`，然后**统一检查** `check_type(S, Γ, core, expected)`（当 `expected` 非空时）。

**为什么需要两层？** 如果不分层，很多分支会忽略 `expected` — 比如 `SConst` 直接返回 `Const(name)`，不检查它是否真的有 expected type。拆分后，只要调用 `elab` 时传入了 `expected`，最终结果一定通过 `check_type` 验证。分支内部的 `check_type` 调用（如 `SPair` 中对分量的检查）仍然保留，用于指导 elaboration 过程和提前发现错误；外层的统一检查则作为兜底。

### 15a.1 基本项

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

### 15a.2 App

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

### 15a.3 Lam

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

### 15a.4 Forall

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

### 15a.5 Sigma

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

### 15a.6 Ann

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

### 15a.7 Pair

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

### 15a.8 Fst

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

### 15a.9 Snd

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

### 15a.10 `elab` 完整代码

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

    raise Error
```

**注意：** `elab_raw` 内部的递归调用使用 `elab`（外层包装）而非 `elab_raw`。这保证每层递归的 expected type 都被检查。例如 `SApp` 分支中 `a_c = elab(S, Γ, a_s, A)` 会检查 `a_c : A`，即使 `a_s` 是 `SConst` 这样的基本项。

**总结：** `elab` 把 SurfaceTerm 转换成 CoreTerm。v7 的重要变化：

- `SSigma(x, A, B)` 不再产生 `CSigma(x, A, B)`，而是产生 `(Const Sigma) A (fun (x : A) => B)` — 一个全局常量的应用。
- `SPair(a, b)` 不再产生 `CPairTyped(x, A, B, a, b)`，而是产生 `(Const Sigma.mk) A B a b` — 一个构造子的应用。
- `SFst(t)` 不再产生 `CFst(t_c)`，而是产生 `Proj(Sigma, 0, t_c)` — 一个一般的 projection。
- `SSnd(t)` 不再产生 `CSnd(t_c)`，而是产生 `Proj(Sigma, 1, t_c)` — 一个一般的 projection。
- `SAnn(t, A)` 仍然被消耗，不出现在输出中。

**v8 注意：** v8 的 `elab` 仍只处理 Sigma 相关的 surface 构造子（`SSigma`、`SPair`、`SFst`、`SSnd`）。要支持 Prod 等 structure 的 surface 语法，需要 v9 的 `StructureCmd`。

---

## 16. `State` 与 `Context` 的角色                           【v8 修改】

简短回顾两者的分工：

- **State**：记录全局名字（axiom 和 def）的类型，以及结构信息。`Const n` 的类型由 `S.Axioms` 或 `S.Defs` 决定。`S.Structures` 记录哪些全局名字是结构类型、它们的构造子是谁、参数和字段的名字与类型模板。
- **Context**：记录当前 binder 打开的局部变量类型。`Var x` 的类型由 `Γ.Types` 决定。

例如：

```text
S ; Γ ⊢ Const Nat : Sort (level 0)           -- 类型来自 S.Axioms
S ; (Γ, x : Const Nat) ⊢ Var x : Const Nat   -- 类型来自 Γ.Types
```

v8 相对于 v7 的新增：`StructureInfo` 现在记录 `params` 和 `fields` 的名字与类型模板。它使得 `whnf` 和 `infer_type` 的 `Proj` 分支都可以查找结构信息，不依赖硬编码。

State 是顶层、长期的（贯穿整个文件的推导）；Context 是局部、临时的（只在打开 binder 时存在）。

---

## 17. 关于 bidirectional typing                              【v8 修改】

v8 将 bidirectional typing 分为两层：
- **elaboration 层**：`elab` 处理 SurfaceTerm → CoreTerm 的转换。`SPair` 需要 expected type 才能 elaborate。
- **kernel 层**：`infer_type` / `check_type` 只作用于 CoreTerm。所有 CoreTerm 都可以 infer。

### 17.1 哪些 CoreTerm 可以 infer？

以下 CoreTerm 可以在 `infer_type` 中成功推断类型：

```text
Var x              → 从 Context 中查到
Const n            → 从 State 中查到（Axioms 或 Defs）
Sort u             → 总是 Sort (succ_level(u))
App f a            → 从函数类型 + substitution 中算出
Lam x A body       → 自带类型注解 A，可以算出 Forall(x, A, B)
Forall x A B       → 可以算出 Sort(max(u, v))
Proj structName i p → 第 i 个字段的类型（从 StructureInfo 的 fields 中取出，通过 projection_type）
```

**评论：** 注意 Sigma type 的 formation 和 Sigma.mk 的应用类型可以完全通过 `Const` + `App` 的推断规则链得到 — 不需要特殊的 `CSigma` 和 `CPairTyped` 分支。`Proj` 仍然需要一个专门的 `infer_type` 分支（§14），但 v8 中这个分支通过 `match_structure_type` + `projection_type` 实现，对 Sigma 和 Prod 都适用。

### 17.2 哪些 SurfaceTerm 需要 expected type 才能 elaborate？

```text
SPair a b  → 需要 expected type 是 Sigma 类型
```

原因是：同样的 `⟨a, b⟩`，在不同的目标 Sigma 类型下可能有不同的合法性。`SPair` 自身不携带 `B` 的信息。

但通过 `SAnn`，可以把 `SPair` 包装起来，让 elab 有 expected type：

```text
SAnn(SPair(a, b), SSigma(x, A, B))  →  elab 得到 Sigma.mk A Bfun a_core b_core
```

### 17.3 调用链

v8 的函数调用链：

```text
elab 调用 infer_type / check_type：
  - SApp 规则中，推断函数类型
  - SPair 规则中，check 分量类型
  - SAnn 规则中，验证类型标注
  - SLam/SForall/SSigma 规则中，验证 domain 是 type
  - SFst/SSnd 规则中，验证参数类型是 Sigma 类型

elab 调用辅助函数：
  - SSigma 规则中，调用 mk_sigma_type 构造 Sigma 类型
  - SPair 规则中，调用 is_sigma_type 识别 Sigma 类型，调用 mk_sigma_mk 构造 Sigma.mk 应用

infer_type 调用辅助函数（v8 新增，§12a）：
  - Proj 规则中，调用 match_structure_type 匹配结构类型、提取参数值（§12a.2）
  - Proj 规则中，调用 projection_type 从 StructureInfo 的 fields 中计算字段类型（§12a.3）

infer_type 调用 check_type：
  - App 规则中，检查参数类型

check_type 调用 infer_type：
  - 默认分支：先 infer 再 defeq 比较
```

### 17.4 和 Lean 的对应

| 我们的模型 | Lean 中的对应 |
|---|---|
| `SSigma(x, A, B)` → `(Const Sigma) A Bfun` | `Σ (x : A), B` is notation for `Sigma A (fun x => B)` |
| `SPair(a, b)` → `(Const Sigma.mk) A Bfun a b` | `⟨a, b⟩` elaborates to `Sigma.mk` application |
| `SFst(t)` → `Proj(Sigma, 0, t_c)` | `fst p` becomes `Proj` |
| `SSnd(t)` → `Proj(Sigma, 1, t_c)` | `snd p` becomes `Proj` |
| `SAnn(t, A)` → consumed during elab | Type annotations help elaborator |

**v8 新增 Prod 对应：** Prod.mk 应用 ↔ Lean 的 `Prod.mk` 应用；`Proj(Prod, 0, ...)` ↔ Lean 的 `Prod.fst`；`Proj(Prod, 1, ...)` ↔ Lean 的 `Prod.snd`。

### 17.5 v8 的架构变化

v6 中：

```text
Surface → Core (CPairTyped, CFst, CSnd 仍然是特殊构造子)
```

v7 中：

```text
Surface → Core (只有 Const, App, Lam, Forall, Proj — Sigma/Pair/Fst/Snd 变成了环境层面的东西)
```

v8 中：

```text
Surface → Core（自 v7 沿用，但 Proj 的 infer_type 不再硬编码 Sigma，由 StructureInfo 的 params/fields 驱动）
```

> Sigma / Pair / fst / snd 不再是 core 语法的特殊情况；
> 它们变成了环境中的结构名、构造子和投影。
> v8 进一步将 Proj 的 infer_type 一般化 — Sigma 和 Prod 由同一个 StructureInfo + Proj 机制处理。

---

## 18. 关键 term：`p_ann`                                      【v8 修改】

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

**文本缩写（非模型操作）：** 以下简记 `p_core` 为：

```text
(Const Sigma.mk)
  (Const Nat)
  (fun (x : Const Nat) => App(Const Pred, Var x))
  (Const zero)
  (App(Const choosePred, Const zero))
```

使用完整的 `App` 展开：

```text
p_core =
App(
  App(
    App(
      App(Const(Sigma.mk), Const(Nat)),
      Lam(x, Const(Nat), App(Const(Pred), Var(x)))
    ),
    Const(zero)
  ),
  App(Const(choosePred), Const(zero))
)
```

**评论（重要）：**

- core 形式中没有 `Ann` — 它在 elaboration 时被消耗了。
- core 形式中没有 `CPairTyped` — 它自 v7 起不再存在于 `CoreTerm` 中。
- `p_core` 是一个 constructor application：`Const Sigma.mk` 应用到四个参数（`A`、`Bfun`、`a`、`b`）。整个项只是 4 层嵌套的 `App`。
- Sigma 类型信息被编码在 `Sigma.mk` 的参数中：前两个参数 `Const Nat` 和 `Lam(x, Const Nat, App(Const Pred, Var x))` 是类型参数 `A` 和 `Bfun`；后两个参数 `Const zero` 和 `App(Const choosePred, Const zero)` 是字段值 `a` 和 `b`。
- 这比 v6 的 `CPairTyped` 更接近 Lean 底层 — Lean 中 `Sigma.mk` 就是一个普通的 constructor。

### 18.3 `Proj` 在 `p_core` 上的类型

由 `Proj` 的 `infer_type` 规则 (§14)：

```text
infer_type(S, ∅, Proj(Sigma, 0, p_core)) = Const Nat
```

以及：

```text
infer_type(S, ∅, Proj(Sigma, 1, p_core)) = App(Bfun, Proj(Sigma, 0, p_core))
```

其中 `Bfun = Lam(x, Const Nat, App(Const Pred, Var x))`。

**评论（重要）：** 注意 `Proj(Sigma, 1, p_core)` 的类型是 `App(Bfun, Proj(Sigma, 0, p_core))`，**不是** `App(Const Pred, Const zero)` — 类型中包含未化简的 `Proj(Sigma, 0, p_core)`。

`App(Bfun, Proj(Sigma, 0, p_core))` beta-reduce 后变成 `App(Const Pred, Proj(Sigma, 0, p_core))`。

而 `Proj(Sigma, 0, p_core)` 可以通过 `whnf` 化简为 `Const zero`。

所以 `defeq` 可以把 `App(Bfun, Proj(Sigma, 0, p_core))` 和 `App(Const Pred, Const zero)` 视为 definitionally equal。详见 §20。

---

## 19. `whnf` 例子                                            【v8 修改】

### 19.1 beta reduction

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）：

```text
S.Axioms = SΣΠ.Axioms ∪ {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Forall (x, Const Nat, Sort (level 0)),
  choosePred : Forall (x, Const Nat, App (Const Pred, Var x))
}
S.Defs = {}
S.Structures = {
  Sigma : StructureInfo(Sigma, Sigma.mk, params=[A, B], fields=[(a, Var A), (b, App(Var B, Var a))]),
  Prod  : StructureInfo(Prod, Prod.mk, params=[A, B], fields=[(a, Var A), (b, Var B)])
}
```

**计算 `whnf`**

考虑 CoreTerm：

```text
App(Lam(x, Const Nat, Var x), Const zero)
```

计算：

```text
whnf(S, App(Lam(x, Const Nat, Var x), Const zero))
```

**推导过程：**

1. `t = App(Lam(x, Const Nat, Var x), Const zero)`，匹配 `App` 分支 (§12)。
2. 先化简函数部分：

```text
whnf(S, Lam(x, Const Nat, Var x)) = Lam(x, Const Nat, Var x)
```

`Lam` 不是任何 whnf 规则的头部 redex，直接返回。

3. `f0 = Lam(...)`，是 `Lam`，触发 beta reduction (§12)：

```text
whnf(S, subst(Var x, x, Const zero))
= whnf(S, Const zero)
```

4. `Const zero`：`zero` 不在 `S.Defs` 中（是 axiom），所以 (§12)：

```text
whnf(S, Const zero) = Const zero
```

**结论：**

```text
whnf(S, App(Lam(x, Const Nat, Var x), Const zero)) = Const zero
```

**评论：** 与 v6 完全相同，只是没有 C 前缀。

### 19.2 `Proj(Sigma, 0, p_core)` — 取代 v6 的 `CFst`

**前置状态**

同 §19.1，状态 `S`。

**计算 `whnf`**

文本缩写（非模型操作）：令 `p_core` 表示 §18.2 中定义的 `Sigma.mk` 应用。

考虑 CoreTerm：

```text
Proj(Sigma, 0, p_core)
```

计算：

```text
whnf(S, Proj(Sigma, 0, p_core))
```

**推导过程：**

1. `t = Proj(Sigma, 0, p_core)`，匹配 `Proj` 分支 (§12)。

2. 先化简 target：

```text
whnf(S, p_core) = p_core
```

`p_core` 是以 `Const Sigma.mk` 为头部的嵌套 `App`。`Sigma.mk` 是 axiom（不在 `S.Defs` 中），所以不能 delta 展开。这个 `App` 的 whnf 就是它自身 — 函数部分是 `Const Sigma.mk`，不是 `Lam`，不触发 beta reduction。所以 `whnf(S, p_core) = p_core`。

3. 查结构信息：

```text
S.Structures.get(Sigma)
=
StructureInfo(
  typeName = Sigma,
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

结构信息存在，且 `index = 0 < len(info.fields) = 2` ✓

4. 拆开应用：

```text
collect_app(p_core)
=
Pair(
  Const Sigma.mk,
  [
    Const Nat,
    Lam(x, Const Nat, App(Const Pred, Var x)),
    Const zero,
    App(Const choosePred, Const zero)
  ]
)
```

`collect_app` 把嵌套的 `App(App(App(App(Const Sigma.mk, ...), ...), ...), ...)` 拆成头部 `Const Sigma.mk` 和参数列表 `[Const Nat, Bfun, Const zero, App(Const choosePred, Const zero)]`。

5. `head = Const Sigma.mk`，与结构信息中的 `constructor = Sigma.mk` 一致 ✓

6. 当前投影 index 是 `0`，所以字段位置是：

```text
field_pos = len(info.params) + index = 2 + 0 = 2
```

7. 参数列表第 `2` 个参数是：

```text
Const zero
```

8. 返回 `whnf(S, Const zero) = Const zero`（`zero` 是 axiom，不再展开）。

**结论：**

```text
whnf(S, Proj(Sigma, 0, p_core)) = Const zero
```

**评论：** v6 中这个过程是 `whnf(S, CFst(p_ann_core))`：先看 `CFst`，化简参数到 `CPairTyped`，取出第一分量 `CConst zero`。v7 中用通用的 `Proj` + `StructureInfo` 完成：先看 `Proj`，化简 target，查结构信息，拆开 constructor application，按字段位置取出对应参数。核心计算完全相同，但机制更一般。

### 19.3 `Proj(Sigma, 1, p_core)` — 取代 v6 的 `CSnd`

**前置状态**

同 §19.1，状态 `S`。

**计算 `whnf`**

考虑 CoreTerm：

```text
Proj(Sigma, 1, p_core)
```

**推导过程：**

1. `t = Proj(Sigma, 1, p_core)`，匹配 `Proj` 分支 (§12)。

2. 先化简 target（同 §19.2 第 2 步）：

```text
whnf(S, p_core) = p_core
```

3. 查结构信息：同 §19.2 第 3 步。结构信息存在，且 `index = 1 < len(info.fields) = 2` ✓

4. 拆开应用（同 §19.2 第 4 步）：

```text
collect_app(p_core) = Pair(Const Sigma.mk, [Const Nat, Bfun, Const zero, App(Const choosePred, Const zero)])
```

5. `head = Const Sigma.mk`，与 constructor 一致 ✓

6. 当前投影 index 是 `1`，所以字段位置是：

```text
field_pos = len(info.params) + index = 2 + 1 = 3
```

7. 参数列表第 `3` 个参数是：

```text
App(Const choosePred, Const zero)
```

8. 返回 `whnf(S, App(Const choosePred, Const zero))`。

   先化简函数部分：`whnf(S, Const choosePred) = Const choosePred`（axiom，不展开）。
   
   `Const choosePred` 不是 `Lam`，不触发 beta reduction。

   所以 `whnf(S, App(Const choosePred, Const zero)) = App(Const choosePred, Const zero)`。

**结论：**

```text
whnf(S, Proj(Sigma, 1, p_core)) = App(Const choosePred, Const zero)
```

### 19.4 `Proj` 作用在全局定义上

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

exec 内部会先 elab 类型注解得到 Sigma 类型，再 elab SPair 得到 `p_core`（Sigma.mk 应用）。所以：

```text
S'.Defs.get(pair0) = Pair(
  App(App(Const Sigma, Const Nat), Lam(x, Const Nat, App(Const Pred, Var x))),
  p_core
)
```

执行后：

```text
S'.Axioms = S.Axioms
S'.Defs = {
  pair0 : (App(App(Const Sigma, Const Nat), Lam(x, Const Nat, App(Const Pred, Var x))),
           p_core)
}
S'.Structures = S.Structures
```

### 计算 `whnf(S', Proj(Sigma, 0, Const pair0))`

**推导过程：**

1. `t = Proj(Sigma, 0, Const pair0)`，匹配 `Proj` 分支 (§12)。

2. 先化简 target：

```text
whnf(S', Const pair0)
```

`pair0 ∈ S'.Defs`，触发 delta reduction (§12)：

```text
whnf(S', Const pair0) = whnf(S', p_core)
```

`p_core` 是 `Const Sigma.mk` 的嵌套应用，`Sigma.mk` 是 axiom，不展开，所以：

```text
whnf(S', p_core) = p_core
```

3. 查结构信息：`S'.Structures.get(Sigma)` 存在 ✓

4. 拆开应用：

```text
collect_app(p_core) = Pair(Const Sigma.mk, [Const Nat, Bfun, Const zero, App(Const choosePred, Const zero)])
```

5. `head = Const Sigma.mk`，与 constructor 一致 ✓

6. 字段位置 `field_pos = 2 + 0 = 2`，参数列表第 `2` 个参数是 `Const zero`。

7. 返回 `whnf(S', Const zero) = Const zero`。

**结论：**

```text
whnf(S', Proj(Sigma, 0, Const pair0)) = Const zero
```

同理：

```text
whnf(S', Proj(Sigma, 1, Const pair0)) = App(Const choosePred, Const zero)
```

**评论：** 与 v6 §19.4 的核心逻辑相同 — delta 展开把 `Const pair0` 变成 body（`p_core`），然后 `Proj` 按字段位置取出对应分量。区别在于 v6 用 `CFst` 匹配 `CPairTyped`，v7 用 `Proj` + `collect_app` + `StructureInfo`。

### 19.5 Prod 的 whnf 例子                                    【v8 新增】

**前置状态**

沿用之前的状态 `S`（包含 `SΣΠ`，其中 `Prod` 和 `Prod.mk` 在 `Axioms` 中，`Prod` 在 `Structures` 中）。

令 `pair_prod` 表示：

```text
pair_prod = (Const Prod.mk) (Const Nat) (App(Const Pred, Const zero)) (Const zero) (App(Const choosePred, Const zero))
```

即：

```text
pair_prod = App(App(App(App(Const Prod.mk, Const Nat), App(Const Pred, Const zero)), Const zero), App(Const choosePred, Const zero))
```

注意第二类型参数 `B = App(Const Pred, Const zero)`（而非 `Const Nat`）。这样 `b : B = choosePred zero : Pred zero` 是类型正确的。如果取 `B = Const Nat`，则第二个分量必须是 `Nat` 的元素（如 `Const zero`），而 `choosePred zero : Pred zero` 不是 `Nat` — 这会导致类型错误。

**例子 1：** `whnf(S, Proj(Prod, 0, pair_prod))`

**推导过程：**

1. `t = Proj(Prod, 0, pair_prod)`，匹配 `Proj` 分支 (§12)。

2. 先化简 target：
   
   ```text
   whnf(S, pair_prod) = pair_prod
   ```
   
   `pair_prod` 是以 `Const Prod.mk` 为头部的嵌套 `App`。`Prod.mk` 是 axiom（不在 `S.Defs` 中），所以不能 delta 展开。函数部分是 `Const Prod.mk`，不是 `Lam`，不触发 beta reduction。所以 `whnf(S, pair_prod) = pair_prod`。

3. 查结构信息：
   
   ```text
   S.Structures.get(Prod)
   =
   StructureInfo(
     typeName = Prod,
     constructor = Prod.mk,
     params=[A, B],
     fields=[(a, Var A), (b, Var B)]
   )
   ```
   
   结构信息存在，且 `index = 0 < len(fields) = 2` ✓

4. 拆开应用：
   
   ```text
   collect_app(pair_prod)
   =
   Pair(
     Const Prod.mk,
     [Const Nat, App(Const Pred, Const zero), Const zero, App(Const choosePred, Const zero)]
   )
   ```

5. `head = Const Prod.mk`，与结构信息中的 `constructor = Prod.mk` 一致 ✓

6. `expected_arity = len(params) + len(fields) = 2 + 2 = 4 = len(args)` ✓

7. 当前投影 index 是 `0`，所以字段位置是：
   
   ```text
   field_pos = len(params) + 0 = 2 + 0 = 2
   ```
   
   参数列表第 `2` 个参数是 `Const zero`。

8. 返回 `whnf(S, Const zero) = Const zero`（`zero` 是 axiom，不再展开）。

**结论：**

```text
whnf(S, Proj(Prod, 0, pair_prod)) = Const zero
```

**例子 2：** `whnf(S, Proj(Prod, 1, pair_prod))`

**推导过程：**

1-6 同例子 1（结构信息相同，target 相同，拆开应用相同）。

7. 当前投影 index 是 `1`，所以字段位置是：
   
   ```text
   field_pos = len(params) + 1 = 2 + 1 = 3
   ```
   
   参数列表第 `3` 个参数是 `App(Const choosePred, Const zero)`。

8. 返回 `whnf(S, App(Const choosePred, Const zero)) = App(Const choosePred, Const zero)`（`choosePred` 是 axiom，不是 `Lam`，不触发 beta reduction）。

**结论：**

```text
whnf(S, Proj(Prod, 1, pair_prod)) = App(Const choosePred, Const zero)
```

**评论：** 注意 Prod 的第二字段类型是 `Pred zero`（而非 `Nat`）。`whnf` 只按位置取字段值，不关心字段类型 — 类型正确性由 `infer_type` 保证。

**评论：** 这表明同一个 `whnf` 机制无需任何代码更改即可处理 Sigma（依值）和 Prod（非依值）。唯一的区别在于参数数量和字段位置，而这些由 `StructureInfo` 的 `params` 和 `fields` 决定 — 机制本身完全一般。

---

## 20. `defeq` 例子                                            【v8 修改】

### 20.1 `Proj(Sigma, 1, p_core)` 可以通过 `check_type`

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）。

文本缩写（非模型操作）：令 `p_core` 表示 §18.2 中的 Sigma.mk 应用。

**推导过程**

由 `Proj` 的 `infer_type` 规则 (§14)：

```text
infer_type(S, ∅, Proj(Sigma, 1, p_core)) = App(Bfun, Proj(Sigma, 0, p_core))
```

其中 `Bfun = Lam(x, Const Nat, App(Const Pred, Var x))`。

**v8 的变化：** v7 用 `is_sigma_type` 硬编码提取 `A` 和 `Bfun`；v8 用 `match_structure_type(S, Sigma, Ttarget)` 提取 `[Const Nat, Bfun]`，再用 `projection_type(S, ∅, info, 1, p_core, [Const Nat, Bfun])` 计算 `subst_many(App(Var B, Var a), [(A, Const Nat), (B, Bfun), (a, Proj(Sigma, 0, p_core))])` = `App(Bfun, Proj(Sigma, 0, p_core))`。结果相同，但机制一般化了。

需要证明：

```text
defeq(S, ∅, App(Bfun, Proj(Sigma, 0, p_core)), App(Const Pred, Const zero)) = True
```

这样 `check_type(S, ∅, Proj(Sigma, 1, p_core), App(Const Pred, Const zero))` 就会通过。

**defeq 推导：**

1. 两边先 `whnf`。

   左边：`App(Bfun, Proj(Sigma, 0, p_core))`，其中 `Bfun = Lam(x, Const Nat, App(Const Pred, Var x))`。
   
   匹配 `App` 分支，先化简函数部分：`whnf(S, Bfun) = Lam(x, Const Nat, App(Const Pred, Var x))`（`Lam` 不化简）。
   
   `f0 = Lam(...)` 是 `Lam`，触发 beta reduction：
   
   ```text
   whnf(S, subst(App(Const Pred, Var x), x, Proj(Sigma, 0, p_core)))
   = whnf(S, App(Const Pred, Proj(Sigma, 0, p_core)))
   ```
   
   再化简这个 `App`：函数部分 `whnf(S, Const Pred) = Const Pred`（axiom），不是 `Lam`。所以：
   
   ```text
   whnf 左边 = App(Const Pred, Proj(Sigma, 0, p_core))
   ```

   右边：`App(Const Pred, Const zero)` — `Pred` 是 axiom，不化简。
   
   ```text
   whnf 右边 = App(Const Pred, Const zero)
   ```

2. 两边都是 `App`（§13），递归比较函数部分和参数部分。

3. 函数部分：`defeq(S, ∅, Const Pred, Const Pred)`
   
   两边 whnf 后都是 `Const Pred`，比较名字 `Pred == Pred` ✓

4. 参数部分：`defeq(S, ∅, Proj(Sigma, 0, p_core), Const zero)`
   
   先 whnf 左边：`whnf(S, Proj(Sigma, 0, p_core)) = Const zero`（§19.2 已证）
   
   两边 whnf 后都是 `Const zero`，`t1 == t2` ✓

5. 函数部分 ✓ 且参数部分 ✓，因此 `App` 整体 ✓。

**结论：**

```text
defeq(S, ∅, App(Bfun, Proj(Sigma, 0, p_core)), App(Const Pred, Const zero)) = True
```

因此：

```text
check_type(S, ∅, Proj(Sigma, 1, p_core), App(Const Pred, Const zero)) = True
```

**评论：** 类型比较承认计算结果 — `defeq` 通过 `whnf` 发现 `Proj(Sigma, 0, p_core) = Const zero`，以及 `App(Bfun, Proj(Sigma, 0, p_core))` beta-reduce 后等于 `App(Const Pred, Proj(Sigma, 0, p_core))`，从而让两个结构不同但语义相同的类型通过检查。这个例子展示了 `defeq` 中 beta reduction 和 projection 化简协同工作的能力。

### 20.2 alpha-renaming

**证明**

```text
defeq(S, ∅,
  Forall(x, Const Nat, App(Const Pred, Var x)),
  Forall(y, Const Nat, App(Const Pred, Var y))) = True
```

**推导过程：**

1. 两边先 `whnf`。`Forall` 不是头部 redex，不变。

2. 两边都是 `Forall`（§13），处理 binder：

   - 先比较 domain 类型：`defeq(S, ∅, Const Nat, Const Nat) = True` ✓
   - 取新名字 `z`（不在 `FV(B1) ∪ FV(B2) ∪ ...` 中）
   - 左边 body `App(Const Pred, Var x)` 改名为 `App(Const Pred, Var z)`
   - 右边 body `App(Const Pred, Var y)` 改名为 `App(Const Pred, Var z)`
   - 在扩展上下文 `∅, z : Const Nat` 下递归比较

3. 递归比较 `App(Const Pred, Var z)` 和 `App(Const Pred, Var z)`：

   两边都是 `App`。函数部分 `Const Pred` vs `Const Pred` ✓。参数部分 `Var z` vs `Var z` ✓。

**结论：** `defeq` 返回 `True`。

**评论：** binder 名字不同的 `Forall` 通过 alpha-renaming 被视为相等。与 v6 完全相同。

### 20.3 `Proj` 作用在全局定义上的 `defeq`

**前置状态**

沿用 §19.4 的状态 `S'`（`pair0` 已注册为全局定义，文本缩写，非模型操作）。

**证明**

```text
check_type(S', ∅, Proj(Sigma, 1, Const pair0), App(Const Pred, Const zero)) = True
```

**推导过程：**

1. 先推断类型：

```text
infer_type(S', ∅, Proj(Sigma, 1, Const pair0))
```

由 `Proj` 的 `infer_type` 规则：
- 先推断 target 类型：`infer_type(S', ∅, Const pair0)` = Sigma type 的 type（从 `S'.Defs` 查到）
- `match_structure_type(S', Sigma, Ttarget)` 识别出参数值 `[Const Nat, Bfun]`
- `projection_type(S', ∅, info, 1, Const pair0, [Const Nat, Bfun])` — `fields[1].type = App(Var B, Var a)`，替换 `B → Bfun`、`a → Proj(Sigma, 0, Const pair0)`，返回 `App(Bfun, Proj(Sigma, 0, Const pair0))`

```text
infer_type(S', ∅, Proj(Sigma, 1, Const pair0)) = App(Bfun, Proj(Sigma, 0, Const pair0))
```

2. `check_type` 调用：

```text
defeq(S', ∅, App(Bfun, Proj(Sigma, 0, Const pair0)), App(Const Pred, Const zero))
```

3. 两边先 whnf：

   左边 `App(Bfun, Proj(Sigma, 0, Const pair0))` beta-reduce：
   - `Bfun = Lam(x, ...)` 应用到 `Proj(Sigma, 0, Const pair0)` → `App(Const Pred, Proj(Sigma, 0, Const pair0))`
   
   右边 `App(Const Pred, Const zero)` 不变。

4. 两边都是 `App`，递归比较：

   - 函数部分：`Const Pred` vs `Const Pred` ✓
   - 参数部分：`defeq(S', ∅, Proj(Sigma, 0, Const pair0), Const zero)`

5. 参数部分的比较：

   先 whnf 左边：`whnf(S', Proj(Sigma, 0, Const pair0)) = Const zero`（§19.4 已证：delta 展开 `pair0` → `p_core` → `Proj` 取第 2 个参数 → `Const zero`）

   两边 whnf 后都是 `Const zero` ✓

**结论：**

```text
check_type(S', ∅, Proj(Sigma, 1, Const pair0), App(Const Pred, Const zero)) = True
```

**评论：** `defeq` 在比较参数部分时调用了 `whnf`，`whnf` 做了 delta 展开（`Const pair0` → body → `p_core`）和 Proj 投影化简（`Proj(Sigma, 0, p_core)` → `Const zero`）。

### 20.4 Prod 的 infer_type + defeq                                【v8 新增】

**前置状态**

沿用之前的状态 `S`（包含 `SΣΠ`，其中 `Prod` 和 `Prod.mk` 在 `Axioms` 中，`Prod` 在 `Structures` 中）。

令 `pair_prod` 表示 §19.5 中定义的 Prod.mk 应用：

```text
pair_prod = (Const Prod.mk) (Const Nat) (App(Const Pred, Const zero)) (Const zero) (App(Const choosePred, Const zero))
```

注意 `B = App(Const Pred, Const zero)`，所以 `b = choosePred zero : Pred zero = B`，类型正确。

**例子 1：** `infer_type(S, ∅, Proj(Prod, 0, pair_prod))`

1. `t = Proj(Prod, 0, pair_prod)`，匹配 `Proj` 分支 (§14)。

2. 查结构信息：

```text
info = S.Structures.get(Prod)
= StructureInfo(Prod, Prod.mk, [
    ParamInfo(A, Sort(level 0)),
    ParamInfo(B, Sort(level 0))
  ], [
    FieldInfo(a, Var A),
    FieldInfo(b, Var B)
  ])
```

`index = 0 < len(info.fields) = 2` ✓

3. 推断 target 类型：

```text
infer_type(S, ∅, pair_prod) = App(App(Const Prod, Const Nat), App(Const Pred, Const zero))
```

（`pair_prod` 是 `Prod.mk` 的四参数应用；`Prod.mk` 的类型是嵌套 Π，四参数依次应用后最终返回 `(Const Prod) (Var A) (Var B) = App(App(Const Prod, Const Nat), App(Const Pred, Const zero))`。）

4. 匹配结构类型：

```text
match_structure_type(S, Prod, App(App(Const Prod, Const Nat), App(Const Pred, Const zero)))
```

`whnf` 后 `head = Const Prod`，`args = [Const Nat, App(Const Pred, Const zero)]`。`len(args) = 2 = len(info.params)` ✓。返回 `[Const Nat, App(Const Pred, Const zero)]`。

5. 计算投影类型：

```text
projection_type(S, ∅, info, 0, pair_prod, [Const Nat, App(Const Pred, Const zero)])
```

`fields[0].type = Var A`

替换：`[(A, Const Nat), (B, App(Const Pred, Const zero))]`

`subst_many(Var A, [(A, Const Nat), (B, App(Const Pred, Const zero))]) = Const Nat`

6. 返回 `Const Nat`。

**结论：**

```text
infer_type(S, ∅, Proj(Prod, 0, pair_prod)) = Const Nat
```

**例子 2：** `infer_type(S, ∅, Proj(Prod, 1, pair_prod))`

1-4 同例子 1。

5. 计算投影类型：

```text
projection_type(S, ∅, info, 1, pair_prod, [Const Nat, App(Const Pred, Const zero)])
```

`fields[1].type = Var B`（**非依值** — 与 Sigma 的 `App(Var B, Var a)` 不同）

替换：`[(A, Const Nat), (B, App(Const Pred, Const zero))]`

`subst_many(Var B, [(A, Const Nat), (B, App(Const Pred, Const zero))]) = App(Const Pred, Const zero)`

6. 返回 `App(Const Pred, Const zero)`。

**结论：**

```text
infer_type(S, ∅, Proj(Prod, 1, pair_prod)) = App(Const Pred, Const zero)
```

**评论：** 对比 Sigma 的 `Proj(Sigma, 1, p_core)` 的类型推断结果 — `App(Bfun, Proj(Sigma, 0, p_core))`（依值：第二字段类型依赖第一投影）。而 Prod 的 `Proj(Prod, 1, pair_prod)` 的推断结果是 `App(Const Pred, Const zero)`（非依值：第二字段类型只是 `Var B`，替换后是第二个参数值 `App(Const Pred, Const zero)`，不依赖第一投影）。这个区别完全由 `FieldInfo.type` 模板决定 — Sigma 用 `App(Var B, Var a)`，Prod 用 `Var B`。`infer_type` 的代码不需要区分这两种情况。

---

## 21. `elab` 例子                                            【v8 修改】

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
- elab `SConst Nat` → `Const Nat` (§15a.1)。验证 `infer_type(S, ∅, Const Nat) = Sort(level 0)` ✓
- 在扩展上下文 `∅, x : Const Nat` 下，elab `SApp(SConst Pred, SVar x)`：
  - 匹配 `SApp` (§15a.2)。
  - elab `SConst Pred` → `Const Pred` (§15a.1)。
  - `infer_type(S, ∅, Const Pred) = Forall(x, Const Nat, Sort(level 0))`。
  - 参数 expected type 为 `Const Nat`。
  - elab `SVar x` → `Var x` (§15a.1)。
  - `check_type(S, (∅, x : Const Nat), Var x, Const Nat) = True` ✓
  - 返回 `App(Const Pred, Var x)`。
- `Bfun = Lam(x, Const Nat, App(Const Pred, Var x))`。
- 返回 `mk_sigma_type(Const Nat, Bfun)` = `App(App(Const Sigma, Const Nat), Bfun)`。

**步骤 3：** 验证类型注解是 type：

```text
infer_type(S, ∅, App(App(Const Sigma, Const Nat), Bfun)) = Sort(level 0)
```

这由预置状态 `SΣΠ` 中 `Sigma` 的类型签名以及连续两次 `App` 规则推出 ✓

**步骤 4：** 用 `App(App(Const Sigma, Const Nat), Bfun)` 作为 expected type，elab 内部项 `SPair(SConst zero, SApp(SConst choosePred, SConst zero))`。

- 匹配 `SPair` (§15a.7)。
- `expected = App(App(Const Sigma, Const Nat), Bfun)`，非空。
- `whnf(S, expected) = App(App(Const Sigma, Const Nat), Bfun)`（以 `Const Sigma` 为头部的应用，不能化简）。
- `is_sigma_type(expected_whnf)` 识别出：`Pair(Const Nat, Bfun)` ✓
- 提取 `A = Const Nat, Bfun = Lam(x, Const Nat, App(Const Pred, Var x))`。

- **第一个分量**：expected type = `Const Nat`。
  - elab `SConst zero` → `Const zero` (§15a.1)。
  - `check_type(S, ∅, Const zero, Const Nat) = True` ✓

- **第二个分量**：expected type = `App(Bfun, Const zero)`。
  - `B_at_a = App(Bfun, Const zero) = App(Lam(x, Const Nat, App(Const Pred, Var x)), Const zero)`。
  - 这个 beta-reduce 后是 `App(Const Pred, Const zero)`。但 `elab` 不做这个化简 — 它直接用 `App(Bfun, Const zero)` 作为 expected type 传下去。`check_type` 内部的 `defeq` 会处理这个。
  - elab `SApp(SConst choosePred, SConst zero)`：
    - 匹配 `SApp` (§15a.2)。
    - elab `SConst choosePred` → `Const choosePred` (§15a.1)。
    - `infer_type(S, ∅, Const choosePred) = Forall(x, Const Nat, App(Const Pred, Var x))`。
    - 参数 expected type = `Const Nat`。
    - elab `SConst zero` → `Const zero` (§15a.1)。
    - `check_type(S, ∅, Const zero, Const Nat) = True` ✓
    - 返回 `App(Const choosePred, Const zero)`。
  - `check_type(S, ∅, App(Const choosePred, Const zero), App(Bfun, Const zero))`：
    - `infer_type(S, ∅, App(Const choosePred, Const zero)) = App(Const Pred, Const zero)`（由 App 规则 + substitution）
    - `defeq(S, ∅, App(Const Pred, Const zero), App(Bfun, Const zero))`：
      - whnf 左边 = `App(Const Pred, Const zero)`
      - whnf 右边 = `App(Const Pred, Const zero)`（beta reduction: `App(Lam(x, ...), Const zero)` → `App(Const Pred, Const zero)`）
      - 两边相同 ✓
    - 所以 `check_type = True` ✓

- 返回 `mk_sigma_mk(Const Nat, Bfun, Const zero, App(Const choosePred, Const zero))`。
  
  即：
  ```text
  App(App(App(App(Const Sigma.mk, Const Nat), Bfun), Const zero), App(Const choosePred, Const zero))
  ```
  
  这就是 `p_core`。

**步骤 5：** `SAnn` 被消耗 — 返回步骤 4 的结果（不带 Ann 包装）。

**最终结果：**

```text
elab(S, ∅, p_ann_surf, None)
=
p_core
=
(Const Sigma.mk)
  (Const Nat)
  (fun (x : Const Nat) => App(Const Pred, Var x))
  (Const zero)
  (App(Const choosePred, Const zero))
```

**评论：** 整个 elaboration 过程中，`SAnn` 被消耗了。`SSigma` 变成了 `(Const Sigma)` 的应用。`SPair` 变成了 `(Const Sigma.mk)` 的应用。输出的 CoreTerm 中没有 `Ann`、没有 `CSigma`、没有 `CPairTyped` — 只有 `Const`、`App`、`Lam` 和 `Var`。

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
   - elab `p_ann_surf` = `SAnn(SPair(...), SSigma(...))` → `p_core` (§21.1 已证)。
   - `infer_type(S, ∅, p_core)`：
     - `p_core` 是 `App(App(App(App(Const Sigma.mk, ...), ...), ...), ...)`。
     - 连续使用 `App` 规则，从 `Sigma.mk` 的类型签名推得：`App(App(Const Sigma, Const Nat), Bfun)`。
   - `is_sigma_type(App(App(Const Sigma, Const Nat), Bfun)) = Pair(Const Nat, Bfun)` ✓
   - 返回 `Proj(Sigma, 1, p_core)`。

3. 回到 `SFst`：
   - `t_c = Proj(Sigma, 1, p_core)`。
   - `infer_type(S, ∅, Proj(Sigma, 1, p_core)) = App(Bfun, Proj(Sigma, 0, p_core))`。
   - `whnf(S, App(Bfun, Proj(Sigma, 0, p_core)))` beta-reduce 后 = `App(Const Pred, Proj(Sigma, 0, p_core))`。
   - 注意：`whnf` **不会**进一步化简参数位置的 `Proj(Sigma, 0, p_core)`（见 §13 的原则）。虽然 `defeq` 可以证明 `Proj(Sigma, 0, p_core)` 与 `Const zero` definitionally equal，但 `whnf` 只处理头部。
   - 因此该类型的 whnf 是 `App(Const Pred, Proj(Sigma, 0, p_core))`，不是 Sigma 类型（`is_sigma_type` 返回 None）。
   - **raise Error**。

**评论：** `SFst(SSnd(p_ann_surf))` 会 elaboration 失败 — 因为 `Proj(Sigma, 1, p_core)` 的类型是 `App(Const Pred, ...)`，不是 Sigma 类型。`SFst` 要求参数类型是 Sigma 类型。这个行为是正确的：`fst (snd pair)` 在这个例子中确实没有意义（`snd pair` 的类型不是 pair 类型）。无论 `defeq` 能否进一步证明该类型等于 `App(Const Pred, Const zero)`，它都不是 Sigma 类型，所以不影响结论。

### 21.4 Prod 在 elab 层的限制                                     【v8 新增】

v8 的 `elab` 只处理 Sigma 相关的 surface 构造子（`SSigma`、`SPair`、`SFst`、`SSnd`）。没有 `SProd`、`SProdPair`、`SProdFst`、`SProdSnd` 这样的 SurfaceTerm 构造子。

因此，一个 Prod pair 只能作为 **raw CoreTerm** 直接构造：

```text
pair_prod = (Const Prod.mk) (Const Nat) (App(Const Pred, Const zero)) (Const zero) (App(Const choosePred, Const zero))
```

这相当于"绕过 elab，直接写 kernel 层的 term"。在实际的 Lean 中，用户写 `⟨a, b⟩` 或 `(a, b)` 这样的语法，elaborator 会根据 expected type 决定是 `Sigma.mk` 还是 `Prod.mk` 的应用。v8 还没有这种 surface 语法支持 — 这需要 v9 的 `StructureCmd` 机制，让用户可以在 surface 层声明和引用自定义结构。

**评论：** v8 的这个限制是故意设计的 — 它展示了"kernel 一般化"和"surface 语法"之间的缝隙。Kernel 层（`whnf`、`infer_type`、`defeq`）已经完全一般化，任何在 `S.Structures` 中注册的结构都可以被 `Proj` 投影。但 surface 层（`elab`）仍然只处理 Sigma — 因为 v8 不引入新的 surface 语法构造子。这是 v9 的工作。

---

## 22. 当前阶段的边界                                         【v8 修改】

当前阶段，模型包含：

```text
SurfaceTerm 构造子：SConst, SSort, SVar, SApp, SLam, SForall, SSigma, SPair, SFst, SSnd, SAnn

CoreTerm 构造子：Const, Sort, Var, App, Lam, Forall, Proj

State 字段：Axioms, Defs, Structures

函数：FV(CoreTerm), subst(CoreTerm), subst_many, exec, infer_type, check_type, whnf, defeq, elab, elab_raw, is_sigma_type, collect_app, match_structure_type, projection_type
```

类型系统特性：

```text
Surface/Core 分层
elaboration（SurfaceTerm → CoreTerm，携带 expected type）
bidirectional typing（infer / check）on CoreTerm
whnf（弱头部正规化）on CoreTerm
definitional equality（alpha-renaming + reduction + 递归比较）on CoreTerm
conversion-based checking（check_type 用 defeq）on CoreTerm
StructureInfo + Proj（结构信息 + 一般投影，whnf 和 infer_type 都一般化）
```

计算规则：

```text
Proj(structName, index, (Const constructor) params... fields...) → fields[index]
App(Lam(x, A, body), a) → body[x := a]
Const defName → body（delta 展开）
```

**评论：** v6 的 `CFst`/`CSnd`/`CPairTyped` 计算规则被一般的 `Proj` 规则替代。`Proj` 的 whnf 规则由 `StructureInfo` 中的 `constructor`、`len(params)`、`len(fields)` 驱动 — 不需要对任何特定结构硬编码投影化简。将来添加新结构（如 `Point`、`Color`）时，只要在 `Structures` 中注册，`Proj` 的 whnf 规则自动适用。

**v8 的关键进展：** **whnf 和 infer_type 的 Proj 规则都已一般化。** whnf 由 `StructureInfo` 的 `params`/`fields` 长度驱动；infer_type 由 `match_structure_type` + `projection_type` 驱动，后者使用 `FieldInfo.type` 模板。两者不再硬编码 Sigma。唯一的 Sigma 专属逻辑留在 elab 中（`SSigma`/`SPair`/`SFst`/`SSnd` 是 Sigma 的 surface 语法），待 v9 的 `StructureCmd` 一般化。

注意：`(t : A) ↦ t`（Ann 擦除）不再出现在计算规则中 — `Ann` 不是 CoreTerm 构造子。`Σ (x : A), B` 也不再是计算规则的基础 — 它是记号，elaboration 后变成 `App(App(Const Sigma, A), Bfun)`。

尚未加入：

```text
eta 规则
proof irrelevance
universe constraints / level metavariable
reducibility control（opaque / semireducible）
de Bruijn index / fvar
complete InductiveCmd / StructureCmd
auto-generation of constructor / projection / recursor
universe polymorphism
implicit arguments
surface syntax for custom structures（currently elab only handles Sigma）
Sigma.fst / Sigma.snd / Prod.fst / Prod.snd as global projection names
real Lean Expr
```

v8 的定位：

> v7 是"把 Sigma pair 从特例改成环境里的构造子和投影"，但 infer_type 仍硬编码 Sigma；
> v8 是"让 Proj 的类型推断也一般化"。
> Sigma 和 Prod 由同一个 StructureInfo + Proj 机制处理。
>
> Kernel 层（whnf、infer_type、defeq）对任何 StructureInfo 注册的结构都适用 — 不需要代码修改。
> Surface 层（elab）仍只处理 Sigma — 这是 v9 StructureCmd 的工作。
