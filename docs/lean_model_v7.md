# model v7

> 本文档在 v6 基础上扩展。
>
> **相对于 v6 的变化：**
>
> * §4：`CoreTerm` 去掉 `CSigma / CPairTyped / CFst / CSnd`，新增 `Proj(structName, index, target)`；构造子不再使用 `C` 前缀
> * §5：`State` 新增 `Structures` 字段，新增 `StructureInfo` 类型
> * §5a：预置状态 `SΣ`，将 `Sigma` 和 `Sigma.mk` 作为环境中的全局名字
> * §4a：新增辅助函数 `is_sigma_type`、`collect_app`、`mk_sigma_type`、`mk_sigma_mk`
> * §9：`HasType` 去掉 Sigma/Pair/Fst/Snd 规则，新增 `Proj` 规则
> * §10-11：`FV` 和 `subst` 大幅简化（只有 `Lam` 和 `Forall` 有 binder）
> * §12：`whnf` 去掉 `CFst/CSnd` 分支，新增 `Proj` 分支（由 `StructureInfo` 驱动）
> * §13：`defeq` 简化，新增 `Proj` 分支
> * §14：`infer_type` 去掉 Sigma/Pair/Fst/Snd 分支，新增 `Proj` 分支
> * §15a：`elab` 中 `SSigma` → `(Const Sigma) A (fun x => B)`，`SPair` → `Sigma.mk` 应用，`SFst/SSnd` → `Proj`
> * v7 不引入 `Sigma.fst / Sigma.snd` 全局名字，不引入 `ProjectionInfo`
> * v7 不引入完整的 `InductiveCmd / StructureCmd`
>
> **记号约定：** 本文档中有时使用"令 X = ..."或"简记 X 为 ..."。这是**文本层面的临时缩写**，不是模型中的操作。模型中没有"令"或"赋值"的概念 — State 的修改只能通过 `exec` 执行命令来完成。
>
> **命名约定（v7 修改）：** v7 有两种 term 类型：
> - `SurfaceTerm` 的构造子以 `S` 为前缀（`SConst`、`SApp`、`SAnn` 等）
> - `CoreTerm` 的构造子**不再使用** `C` 前缀（`Const`、`App`、`Proj` 等）
>
> v6 中 `CoreTerm` 构造子使用 `C` 前缀（`CConst`、`CApp` 等）。v7 去掉了这个前缀。原因：v7 的 `CoreTerm` 更接近 Lean 的核心表达式，不再需要前缀区分。
>
> 在不引起歧义时，"写作"格式省略前缀 — 例如 `Const Nat` 既可以表示 `SConst Nat` 也可以表示 CoreTerm 的 `Const Nat`，具体含义由上下文决定。
>
> **多参数应用缩写（v7 新增）：** 因为 `App` 是二元构造子，下面约定：
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
- v7 的 `CoreTerm` 有 7 个构造子：`Const`、`Sort`、`Var`、`App`、`Lam`、`Forall`、`Proj`。
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
## 3. `SurfaceTerm`                                              【同 v6】

`SurfaceTerm` 表示用户在表层语法中写的东西。v7 不改变 `SurfaceTerm` — 用户仍然写 `Σ (x : A), B`、`⟨a, b⟩`、`fst p`、`snd p`、`(t : A)`。但 elaboration 后它们变成不同的 CoreTerm。

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

**评论：** `SurfaceTerm` 保留了 `SSigma / SPair / SFst / SSnd / SAnn`。用户确实会写这些东西。但在 v7 中，elaboration 后它们分别变成：

```text
SSigma(x, A, B) → (Const Sigma) A (fun (x : A) => B)
SPair(a, b)     → (Const Sigma.mk) A (fun (x : A) => B) a b    (需 expected type)
SFst(t)         → Proj(Sigma, 0, t_core)
SSnd(t)         → Proj(Sigma, 1, t_core)
SAnn(t, A)      → t_core                                        (Ann 被消耗)
```

---
## 4. `CoreTerm`                                                     【v7 重大修改】

v7 中 `CoreTerm` 有 7 个构造子。相比 v6：

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
- v7 暂时**不引入** `Sigma.fst / Sigma.snd` 全局名字。因为 `Proj(Sigma, 0, p)` 已经编码了投影的全部信息。
- v7 暂时**不引入** `ProjectionInfo`。`StructureInfo` 只记录 `typeName`、`constructor`、`numParams`、`numFields`（见 §5a）。

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

### 4.2 `Proj` 的直觉                                                 【v7 新增】

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

// v7 的 Proj 表达同一件事
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

### 4.3 v6 → v7 的对应表                                            【v7 新增】

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

### 4.4 如果再加一个结构？                                           【v7 新增】

假设将来我们在 `S.Structures` 中注册一个 `Point` 结构：

```text
S.Structures.set(Point, StructureInfo(
  typeName    = Point,
  constructor = Point.mk,
  numParams   = 1,       -- 类型参数 X（坐标的类型）
  numFields   = 2        -- 字段 x 和 y
))
```

那么 `whnf` 的 Proj 规则**不需要任何修改**就能处理：

```text
whnf(S, Proj(Point, 0, (Const Point.mk) (Const Nat) a b))
= a

whnf(S, Proj(Point, 1, (Const Point.mk) (Const Nat) a b))
= b
```

因为 Proj 的 whnf 规则只看 `S.Structures.get(Point)`，查出 `constructor = Point.mk`、`numParams = 1`、`numFields = 2`，然后 `field_pos = 1 + 0 = 1`（第一个字段在参数列表的第 1 位，因为第 0 位是类型参数 X）。

这就是 Proj 的"一般性"在实践中的意义：**新增结构不需要修改 kernel 代码，只需要在 State 中注册信息。**

---
## 4a. 辅助函数                                                    【v7 新增】

v7 需要几个辅助函数来处理"Sigma 类型识别"和"构造子应用拆解"。

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

也就是说：

```text
is_sigma_type((Const Sigma) A Bfun) = Pair(A, Bfun)
```

其中 `Bfun` 通常是一个 lambda：

```text
Bfun = fun (x : A) => B_body
```

**评论：** 这个函数目前只识别 `Sigma`。将来一般化为 `is_structure_type(S, structName, t)` 时，可以通过 `S.Structures` 查任意结构。但 v7 先只处理 Sigma。

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
## 5. `State` 与 `StructureInfo`                                   【v7 修改】

### 5.1 `StructureInfo`

新增 record 类型：

```text
class StructureInfo:
    typeName    : GlobalName
    constructor : GlobalName
    numParams   : Nat
    numFields   : Nat
```

其中：
- `typeName` 是结构类型的全局名字；
- `constructor` 是该结构的构造子名字；
- `numParams` 表示构造子应用中有几个参数是类型参数/type family 参数（不是字段）；
- `numFields` 表示该结构有几个真正的字段。

对于 `Sigma`（见 §5a）：

```text
StructureInfo(
  typeName    = Sigma,
  constructor = Sigma.mk,
  numParams   = 2,
  numFields   = 2
)
```

含义是 `(Const Sigma.mk) A B a b` 中：`A` 和 `B` 是参数（第 0、1 位），`a` 和 `b` 是字段（第 2、3 位）。因此 `Proj(Sigma, 0, p)` 投影出第 `2 + 0 = 2` 个参数 `a`，`Proj(Sigma, 1, p)` 投影出第 `2 + 1 = 3` 个参数 `b`。

**评论：** v7 不引入 `ProjectionInfo`，不记录字段名字（如 `Sigma.fst`）。`Proj(structName, index, target)` 已经编码了投影的全部信息。将来如果要更接近 Lean 的 projection declaration 机制，再把 `Sigma.fst / Sigma.snd` 作为全局名字加入。

### 5.2 `State`

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

注意：`S.Structures.get(Sigma)` 不是天生存在的。它必须来自某个具体状态。v7 中通过预置状态 `SΣ` 给出（见 §5a）。

---
## 5a. 预置状态 `SΣ`                                               【v7 新增】

### 5a.1 全局名字

取两个全局名字：

```text
Sigma, Sigma.mk : GlobalName
```

并要求 `Sigma != Sigma.mk`。

v7 暂时**不引入** `Sigma.fst / Sigma.snd`。因为 `Proj(Sigma, 0, p)` 和 `Proj(Sigma, 1, p)` 已经表达了投影。

### 5a.2 单宇宙简化版 `Sigma` 的类型

为避免 universe polymorphism，v7 先使用单宇宙版本：

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

### 5a.4 `SΣ` 的内容

预置状态 `SΣ`：

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

SΣ.Structures = {
  Sigma :
    StructureInfo(
      typeName    = Sigma,
      constructor = Sigma.mk,
      numParams   = 2,
      numFields   = 2
    )
}
```

**评论：** `Sigma` 不是模型宇宙里自动存在的魔法对象。它是预置状态 `SΣ` 中明确记录的全局信息 — 类型签名在 `Axioms` 中，结构信息在 `Structures` 中。这类似于 Lean 的 prelude 已经提供了 `Sigma`。

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

`elab` 在 §15a 定义。

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
## 9. `HasType` 的具体定义                                    【v7 重大修改】

`HasType` 是 `State × Context × CoreTerm × CoreTerm` 的最小子集，满足以下规则。

v7 的关键变化：**Sigma 类型的 formation、pair 的 introduction、fst/snd 的 elimination 不再需要专门的 HasType 规则。** 它们由基础的 `Const` 和 `App` 规则覆盖 — 因为 Sigma 现在是 `Const Sigma`，pair 是 `(Const Sigma.mk) A B a b`，它们的类型通过普通函数应用规则计算。

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

### 9.3 `Proj` 规则                                          【v7 新增】

- **Proj-fst 规则**（第一投影 elimination rule）

  若：

  ```text
  S ; Γ ⊢ p : App(App(Const Sigma, A), Bfun)
  ```

  则：

  ```text
  S ; Γ ⊢ Proj(Sigma, 0, p) : A
  ```

- **Proj-snd 规则**（第二投影 elimination rule）

  若：

  ```text
  S ; Γ ⊢ p : App(App(Const Sigma, A), Bfun)
  ```

  则：

  ```text
  S ; Γ ⊢ Proj(Sigma, 1, p) : App(Bfun, Proj(Sigma, 0, p))
  ```

**评论：**

- 这是 v7 中唯一专门处理 Sigma 的 HasType 规则。Sigma 类型的 formation、构造子的 introduction 由 `Const` 和 `App` 规则自动覆盖。
- `Proj-fst`：如果 `p : Sigma A Bfun`，则 `Proj(Sigma, 0, p) : A`。
- `Proj-snd`：如果 `p : Sigma A Bfun`，则 `Proj(Sigma, 1, p) : Bfun (Proj(Sigma, 0, p))`。第二字段类型依赖于第一投影。
- **暂时硬编码 Sigma。** 将来一般化时，`infer_type` 应通过 `S.Structures` 查结构信息，不直接匹配 `Sigma`。但当前 `StructureInfo` 不记录字段类型信息，所以 infer_type 暂时硬编码 Sigma 的字段类型计算。详见 §14。
- v6 中的 `CSigma` formation rule、`CPairTyped` introduction rule、`CFst/CSnd` elimination rule 在 v7 中全部消失 — 被更基础的 `Const/App/Proj` 规则取代。

### 9.4 `Ann` 规则

`Ann` 不再是 CoreTerm 的构造子（从 v6 开始）。类型标注在表层由 `SAnn` 处理，elaboration 时被消耗。详见 §15a.6。

### 9.5 `Conversion` 规则

- **Conversion 规则**（类型转换）

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
## 10. `FV`                                                          【v7 修改】

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
## 11. substitution                                                  【v7 修改】

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
## 12. 计算规则：`whnf`                                              【v7 修改】

`whnf`（weak head normal form）把 CoreTerm 化简到弱头部正规形式。v7 中 `whnf` 作用于 `CoreTerm` — 不再有 `Ann` 擦除分支（CoreTerm 中没有 `Ann`），不再有 `CFst`/`CSnd` 匹配 `CPairTyped` 的分支（这些构造子已不存在），取而代之的是 `Proj` 分支。

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

回到 `Proj`：现在知道 target 的 whnf 是一个应用链了。检查 `S.Structures.get(Sigma)` 找到结构信息 `StructureInfo(constructor=Sigma.mk, numParams=2, numFields=2)`。用 `collect_app` 拆分：head = `Const Sigma.mk`，args = `[A, Bfun, a, b]`。head 匹配构造子，index=0，field_pos = numParams + index = 2 + 0 = 2，取出 args[2] = a。

```
→ 返回 whnf(S, a)
```

如果 `a` 本身已经是最简形式（比如 `Const zero`），就停了。结果：`Const zero`。

整个过程就像**剥洋葱** — 从最外层开始，遇到能化简的就化简，化简不动就停。不会主动去化简 `a` 内部的子结构（比如如果 `a` 是一个 `App`，whnf 不会碰它，除非它出现在新的头部位置）。

v7 的 `Proj` 规则是**通用的** — 它不硬编码 Sigma，而是通过 `S.Structures` 查找结构信息。这意味着将来添加新的 structure（如 Prod、Subtype 等），`whnf` 不需要任何修改，只需要在 `S.Structures` 中注册即可。

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

### 12.3 Proj 的结构投影化简                                    【v7 新增】

如果被投影项 whnf 后是一个已知结构的构造子应用，则取出对应字段：

```text
whnf(S, Proj(structName, index, target))
  = whnf(S, args[numParams + index])
      当 whnf(S, target) 展开后 head = Const(constructor)
        且 S.Structures.get(structName) 提供了结构信息
        且 args 的数量 == numParams + numFields（构造子完整应用）
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

    if index >= info.numFields:
        raise Error

    head_args = collect_app(target0)
    head, args = head_args.args

    if isinstance(head, Const) and head.args == info.constructor:
        expected_arity = info.numParams + info.numFields
        if len(args) != expected_arity:
            return Proj(structName, index, target0)
        field_pos = info.numParams + index
        return whnf(S, args[field_pos])

    return Proj(structName, index, target0)
```

**评论：**

- 这个规则是**通用的** — 它通过 `S.Structures` 查找结构信息，不硬编码任何特定结构。对于 Sigma：`numParams=2`（A 和 Bfun），`numFields=2`（a 和 b）。所以 `Proj(Sigma, 0, Sigma.mk A Bfun a b) → a`，`Proj(Sigma, 1, Sigma.mk A Bfun a b) → b`。
- 检查 `index >= info.numFields` 防止越界访问。
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

        if index >= info.numFields:
            raise Error

        head_args = collect_app(target0)
        head, args = head_args.args

        if isinstance(head, Const) and head.args == info.constructor:
            expected_arity = info.numParams + info.numFields
            if len(args) != expected_arity:
                return Proj(structName, index, target0)
            field_pos = info.numParams + index
            return whnf(S, args[field_pos])

        return Proj(structName, index, target0)

    return t
```

**评论：** v7 的 `whnf` 只有三个计算分支（Const delta、App beta、Proj 结构投影），其余四个构造子（Sort, Var, Lam, Forall）是值。v6 有五个计算分支（CConst delta、CApp beta、CFst 投影、CSnd 投影，以及潜在的 CPairTyped 归约），加三个额外构造子（CSigma, CPairTyped）作为值。v7 的简化来源于两个因素：(1) 构造子数量从 10 减少到 7；(2) Proj 的通用规则取代了 CFst/CSnd 的硬编码规则。

---
## 13. 类型等价：`defeq`                                              【v7 修改】

v7 的 `whnf` 让 term 可以计算了。例如：

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
## 14. `infer_type` 与 `check_type`                                 【v7 重大修改】

### 14.0 背景：为什么需要两个函数？

如果所有 CoreTerm 都能从自身推断类型，那么 `check_type` 只需要是 `infer_type` 的简单包装：

```text
check_type(S, Γ, t, A) = defeq(S, Γ, infer_type(S, Γ, t), A)
```

这对 `Var`、`Const`、`Sort`、`App`、`Lam`、`Forall` 都完全成立。`Proj` 也可以 infer，但 **当前 `infer_type` 的 Proj 分支临时硬编码了 Sigma** — 它只能正确推断 `Proj(Sigma, i, target)` 的类型，不能处理一般结构。原因是 `StructureInfo` 只记录了字段数量，没有记录字段类型信息。将来一般化需要扩展 `StructureInfo` 以存储每个字段的类型。

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

v7 的关键变化：**Sigma 类型的 formation、pair 的 introduction、fst/snd 的 elimination 不再需要 `infer_type` 中的专门分支。** 它们由基础规则覆盖：

- **Sigma formation**：`Const Sigma` 由 Const 规则处理（从 `S.Axioms` 查找类型），然后 `App(App(Const Sigma, A), Bfun)` 由 App 规则链式处理。
- **Pair introduction**：`App(App(App(App(Const Sigma.mk, A), Bfun), a), b)` 由 App 规则链式处理 — 每次应用推断类型，最终得到 `App(App(Const Sigma, A), Bfun)` 即 Sigma 类型。
- **Elimination**：`Proj(Sigma, i, p)` 需要专门的分支来计算字段类型 — 这是唯一硬编码 Sigma 的地方。

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
    v7：移除 CSigma, CPairTyped, CFst, CSnd 分支。
    新增 Proj 分支（暂时硬编码 Sigma）。
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

        Ttarget = whnf(S, infer_type(S, Γ, target))

        # 暂时硬编码 Sigma
        if structName == Sigma:
            AB = is_sigma_type(Ttarget)
            if AB is None:
                raise Error
            A, Bfun = AB.args
            if index == 0:
                return A
            if index == 1:
                return App(Bfun, Proj(Sigma, 0, target))
            raise Error

        raise Error

    raise Error


# 写作 check_type(S, Γ, t, A)
def check_type(S: State, Γ: Context, t: CoreTerm, A: CoreTerm) -> bool:
    '''
    在 S 和 Γ 下检查 t : A（check 模式）
    v7：与 v6 一样，check_type 是 infer_type 的简单包装。
    Proj 可以 infer（硬编码 Sigma），不需要 check-only 分支。
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

- **Proj 的类型推断** 暂时硬编码 Sigma。`is_sigma_type(Ttarget)`（定义在 §4a）检查目标类型是否为 `App(App(Const Sigma, A), Bfun)` 形式。如果是，`index=0` 返回 `A`，`index=1` 返回 `App(Bfun, Proj(Sigma, 0, target))`（第二字段类型依赖于第一投影）。

- **关于硬编码的说明：** 这是一个**暂时的教学版本**。`infer_type` 中的 Proj 分支硬编码了 `Sigma`，因为当前 `StructureInfo` 只记录 `numParams` 和 `numFields`，不记录字段类型信息。要将 Proj 的类型推断一般化，需要扩展 `StructureInfo` 加入每个字段的类型公式。而 `whnf` 中的 Proj 规则已经是**完全通用**的 — 它只需要 `numParams` 和 `numFields` 就能做投影化简。这种不对称是故意的：`whnf` 先一般化（因为它只需要计数），`infer_type` 以后再一般化（因为它需要类型公式）。

- 注意 `Proj` 的 `index=1` 分支返回的类型中出现了 `Proj(Sigma, 0, target)` — 这是一个**未经化简的项**。`whnf` 可以化简它（如果 target 是构造子应用），但 `infer_type` 本身不做化简，它返回的类型中可能包含 `Proj(...)` 形式。`check_type` 通过 `defeq` 在比较时自动调用 `whnf` 来处理这种情况。

- 在 `App` 规则中，`infer_type` 已经调用了 `check_type` 来检查参数类型。所以 `infer` 和 `check` 是互相调用的，不是单方向的。

- `infer_type` 在所有类型头部检查处使用了 `whnf` 展开。具体来说：`Forall`/`Lam` 分支中检查 `TA : Sort` 和 `TB : Sort` 时、`App` 分支中检查 `Tf : Forall` 时、`Proj` 分支中检查 `Ttarget` 是否为 Sigma 类型时，都先用 `whnf` 展开推断出的类型。

---
## 15. 构建前置状态 `S`                                         【v7 修改】

为了后续展示 `elab` / `whnf` / `defeq` 的例子，先构建一个共同的前置状态 `S`。

v7 不再从完全空的状态开始。取预置状态 `SΣ`（§5a 中定义），在其基础上依次添加 `Nat`、`zero`、`Pred`、`choosePred`。

```text
S0 = SΣ  (pre-set state with Sigma and Sigma.mk)

S1 = exec(S0, AxiomCmd Nat : SSort (level 0))
S2 = exec(S1, AxiomCmd zero : SConst Nat)
S3 = exec(S2, AxiomCmd Pred : SForall (x, SConst Nat, SSort (level 0)))
S  = exec(S3, AxiomCmd choosePred : SForall (x, SConst Nat, SApp (SConst Pred, SVar x)))
```

最终得到的状态 `S`：

```text
S.Axioms = SΣ.Axioms ∪ {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Forall (x, Const Nat, Sort (level 0)),
  choosePred : Forall (x, Const Nat, App (Const Pred, Var x))
}
S.Defs = {}
S.Structures = SΣ.Structures = {
  Sigma : StructureInfo(Sigma, Sigma.mk, 2, 2)
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

**评论：** 后续 §18-§21 的所有例子都基于这个状态 `S`。需要时会在用到的地方临时扩展状态（如 §19.4 加入 `pair0`）。State `S` 现在包含了 `SΣ` 的内容 — `Sigma` 和 `Sigma.mk` 在 `Axioms` 中，`Sigma` 在 `Structures` 中。这些不是 v7 文档新加的，而是从预置状态继承来的。

---

## 15a. `elab`：从 SurfaceTerm 到 CoreTerm                    【v7 重大修改】

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

不需要 expected type。注意 v7 的 CoreTerm 构造子没有 `C` 前缀。

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

### 15a.5 Sigma（**v7 关键变化**）

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

### 15a.7 Pair（**v7 关键变化**）

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

### 15a.8 Fst（**v7 关键变化**）

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

### 15a.9 Snd（**v7 关键变化**）

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
    v7：Sigma/Pair/Fst/Snd 不再产生特殊 core 构造子，
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

---

## 16. `State` 与 `Context` 的角色                           【v7 修改】

简短回顾两者的分工：

- **State**：记录全局名字（axiom 和 def）的类型，以及结构信息。`Const n` 的类型由 `S.Axioms` 或 `S.Defs` 决定。`S.Structures` 记录哪些全局名字是结构类型、它们的构造子是谁、有多少参数和字段。
- **Context**：记录当前 binder 打开的局部变量类型。`Var x` 的类型由 `Γ.Types` 决定。

例如：

```text
S ; Γ ⊢ Const Nat : Sort (level 0)           -- 类型来自 S.Axioms
S ; (Γ, x : Const Nat) ⊢ Var x : Const Nat   -- 类型来自 Γ.Types
```

v7 相对于 v6 的新增：`S.Structures` 字段。它使得 `whnf` 的 `Proj` 分支可以查找结构信息，不依赖硬编码。

State 是顶层、长期的（贯穿整个文件的推导）；Context 是局部、临时的（只在打开 binder 时存在）。

---

## 17. 关于 bidirectional typing                              【v7 修改】

v7 将 bidirectional typing 分为两层：
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
Proj Sigma 0 p     → A（从 is_sigma_type of p 的类型中取出）
Proj Sigma 1 p     → App(Bfun, Proj(Sigma, 0, p))
```

**评论：** 注意 Sigma type 的 formation 和 Sigma.mk 的应用类型可以完全通过 `Const` + `App` 的推断规则链得到 — 不需要特殊的 `CSigma` 和 `CPairTyped` 分支。`Proj` 仍然需要一个专门的 `infer_type` 分支（§14），但这个分支是一般的 projection 机制，不是专门的 `Fst/Snd` 构造子。

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

v7 的函数调用链：

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

### 17.5 v7 的架构变化

v6 中：

```text
Surface → Core (CPairTyped, CFst, CSnd 仍然是特殊构造子)
```

v7 中：

```text
Surface → Core (只有 Const, App, Lam, Forall, Proj — Sigma/Pair/Fst/Snd 变成了环境层面的东西)
```

> Sigma / Pair / fst / snd 不再是 core 语法的特殊情况；
> 它们变成了环境中的结构名、构造子和投影。

---

## 18. 关键 term：`p_ann`                                      【v7 修改】

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

### 18.2 Core 形式（elaboration 后 — v7 关键变化）

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
- core 形式中没有 `CPairTyped` — 它不再存在于 v7 的 `CoreTerm` 中。
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

## 19. `whnf` 例子                                            【v7 修改】

### 19.1 beta reduction

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）：

```text
S.Axioms = SΣ.Axioms ∪ {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Forall (x, Const Nat, Sort (level 0)),
  choosePred : Forall (x, Const Nat, App (Const Pred, Var x))
}
S.Defs = {}
S.Structures = { Sigma : StructureInfo(Sigma, Sigma.mk, 2, 2) }
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
  numParams = 2,
  numFields = 2
)
```

结构信息存在，且 `index = 0 < numFields = 2` ✓

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
field_pos = numParams + index = 2 + 0 = 2
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

3. 查结构信息：同 §19.2 第 3 步。结构信息存在，且 `index = 1 < numFields = 2` ✓

4. 拆开应用（同 §19.2 第 4 步）：

```text
collect_app(p_core) = Pair(Const Sigma.mk, [Const Nat, Bfun, Const zero, App(Const choosePred, Const zero)])
```

5. `head = Const Sigma.mk`，与 constructor 一致 ✓

6. 当前投影 index 是 `1`，所以字段位置是：

```text
field_pos = numParams + index = 2 + 1 = 3
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

---

## 20. `defeq` 例子                                            【v7 修改】

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
- `is_sigma_type` 识别出 `Pair(Const Nat, Bfun)`
- `index = 1`，所以返回 `App(Bfun, Proj(Sigma, 0, Const pair0))`

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

---

## 21. `elab` 例子                                            【v7 修改】

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

这由预置状态 `SΣ` 中 `Sigma` 的类型签名以及连续两次 `App` 规则推出 ✓

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

---

## 22. 当前阶段的边界                                         【v7 修改】

当前阶段，模型包含：

```text
SurfaceTerm 构造子：SConst, SSort, SVar, SApp, SLam, SForall, SSigma, SPair, SFst, SSnd, SAnn

CoreTerm 构造子：Const, Sort, Var, App, Lam, Forall, Proj

State 字段：Axioms, Defs, Structures

函数：FV(CoreTerm), subst(CoreTerm), exec, infer_type, check_type, whnf, defeq, elab, elab_raw
```

类型系统特性：

```text
Surface/Core 分层
elaboration（SurfaceTerm → CoreTerm，携带 expected type）
bidirectional typing（infer / check）on CoreTerm
whnf（弱头部正规化）on CoreTerm
definitional equality（alpha-renaming + reduction + 递归比较）on CoreTerm
conversion-based checking（check_type 用 defeq）on CoreTerm
StructureInfo + Proj（结构信息 + 一般投影）
```

计算规则：

```text
Proj(Sigma, 0, (Const Sigma.mk) A B a b) → a
Proj(Sigma, 1, (Const Sigma.mk) A B a b) → b
App(Lam(x, A, body), a) → body[x := a]
Const defName → body（delta 展开）
```

**评论：** v6 的 `CFst`/`CSnd`/`CPairTyped` 计算规则被一般的 `Proj` 规则替代。`Proj` 的 whnf 规则由 `StructureInfo` 中的 `constructor`、`numParams`、`numFields` 驱动 — 不需要对 Sigma 硬编码投影化简。将来添加新结构（如 `Point`、`Color`）时，只要在 `Structures` 中注册，`Proj` 的 whnf 规则自动适用。

**重要不对称：** whnf 的 Proj 规则已经完全一般化（由 `StructureInfo` 驱动），但 `infer_type` 的 Proj 分支仍然硬编码 Sigma — 它直接构造 `App(Bfun, Proj(Sigma, 0, p))` 而不是通过结构信息查询字段类型。一般化 `infer_type` 的 Proj 需要在 `StructureInfo` 中存储每个字段的类型信息（而不仅是字段数量），这是后续版本的工作。

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
general StructureInfo with field type info（so Proj infer_type doesn't hardcode Sigma）
Sigma.fst / Sigma.snd as global projection names
real Lean Expr
```

v7 的定位：

> Sigma / Pair / fst / snd 不再是特殊语法（special-cased core syntax）；
> 它们变成了环境中的结构 / 构造子 / 投影的一个具体例子。
> `Proj` 的 whnf 规则是一般的（由 `StructureInfo` 驱动）；
> 只有 `Proj` 的 `infer_type` 仍然对 Sigma 做特判（待后续一般化）。
> 
> v6 是"分 Surface / Core"；
> v7 是"把 Sigma pair 从特例改成环境里的构造子和投影"。
> 
> 这一步做完后，模型更接近 Lean 里 structure / inductive 的底层视角。
