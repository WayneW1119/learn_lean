# model v3

> 本文档在 v2 基础上扩展。
>
> **相对于 v2 的变化：**
>
> - §3 `Term`：新增 `Ann` 构造子（类型标注）
> - §9.6 `HasType`：新增 `Ann` 规则
> - §10 `FV`：新增 `Ann` 分支
> - §11 `subst`：新增 `Ann` 分支
> - §12 `infer_type`：新增 `Ann` 分支
> - §15 bidirectional typing：更新可推断列表
> - §16：新增 `Ann` 综合例子
> - §17：更新边界说明
>
> **重要说明：** `Ann` 是 **elaboration-level 构造**，用于模拟 Lean elaborator 中的 expected type。它不是 Lean kernel 的 `Expr` 中的底层节点。将来区分 SurfaceTerm / CoreTerm 后，`Ann` 应在 elaboration 后被消去。
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
## 3. `Term`                                                      【v3 修改】
定义数据类型 `Term`：
```text
Term = Const(name : GlobalName)                  # 写作 Const name
     | Sort(level : Level)                       # 写作 Sort level
     | Var(name : LocalName)                     # 写作 Var name
     | App(fn : Term, arg : Term)                # 写作 fn arg
     | Lam(x : LocalName, A : Term, body : Term) # 写作 fun (x : A) => body
     | Forall(x : LocalName, A : Term, B : Term) # 写作 Π (x : A), B
     | Sigma(x : LocalName, A : Term, B : Term)  # 写作 Σ (x : A), B
     | Pair(a : Term, b : Term)                   # 写作 ⟨a, b⟩
     | Fst(t : Term)                              # 写作 fst t
     | Snd(t : Term)                              # 写作 snd t
     | Ann(t : Term, A : Term)                    # 写作 (t : A)       【v3 新增】
```
其中：
```text
Sigma(x, A, B)   写作 Σ (x : A), B
Pair(a, b)       写作 ⟨a, b⟩
Fst(t)           写作 fst t
Snd(t)           写作 snd t
Ann(t, A)        写作 (t : A)
```
**评论：**
- 注意 `Pair` 和 `App` 的结构非常相似 — 都没有 binder，都是两个子 term 的组合。区别在于语义：`App` 是函数应用，`Pair` 是对子构造。这个区别在 typing 规则中才体现出来。
- `Ann(t, A)` 不是新的数学对象。它的作用是显式告诉类型推断器：请把 `t` 按照 `A` 来检查；如果检查成功，则 `Ann(t, A)` 可以推断出类型 `A`。它把"只能 check 的 term"变成"可以 infer 的 term"。
因此：
```text
若 x : LocalName, A : Term, B : Term，则 Σ (x : A), B : Term
若 a : Term, b : Term，则 ⟨a, b⟩ : Term
若 t : Term，则 fst t : Term
若 t : Term，则 snd t : Term
若 t : Term, A : Term，则 (t : A) : Term
```
### 3.1 例子

先假设：

```text
Nat, f : GlobalName
x, y  : LocalName
```

则：

```text
Const Nat
Sort (level 0)
Var x
(Const f) (Var x)
fun (x : Sort (level 0)) => Var x
Π (x : Sort (level 0)), Sort (level 0)
```

都 `: Term`。以及：

```text
Σ (x : Sort (level 0)), Sort (level 0)
⟨Const zero, Const zero⟩
fst ⟨Const zero, Const zero⟩       【v2 新增】
snd (Var x)                         【v2 新增】
```

也都 `: Term`。以及：

```text
(⟨Const zero, Const zero⟩ : Σ (x : Const Nat), Const Nat)   【v3 新增】
(Const zero : Const Nat)                                     【v3 新增】
```
---
## 4. `State`
定义状态类型 `State`：
```text
class State:
    Axioms : PartialMap[g : GlobalName, t : Term]                 # 写作 g : t
    Defs   : PartialMap[g : GlobalName, Pair[t1 : Term, t2 : Term]]  # 写作 g : (t1, t2)
```
若 `S : State`，则：
```text
S.Axioms
S.Defs
```
分别表示该状态中的两个字段。
其中：
- 若 `S.Axioms.get(n) = A`，则表示：
  在当前状态 `S` 中，全局名字 `n` 被声明为一个 `axiom`，其 type 是 `A`。
- 若 `S.Defs.get(n) = Pair(A, t)`，则表示：
  在当前状态 `S` 中，全局名字 `n` 被声明为一个 `def`，其 type 是 `A`，body 是 `t`。
---
## 5. 顶层命令 `Command`
定义数据类型 `Command`：
```text
Command = AxiomCmd(name : GlobalName, term : Term)             # 写作 AxiomCmd n : A
        | DefCmd(name : GlobalName, term1 : Term, term2 : Term) # 写作 DefCmd n A t
```
也就是说：
```text
AxiomCmd(n, A)     写作 AxiomCmd n : A
DefCmd(n, A, t)    写作 DefCmd n A t
```
---
## 6. 状态执行函数 `exec`
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
cmd = AxiomCmd(n, A)
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
    Axioms = S.Axioms.set(n, A),
    Defs   = S.Defs
)
```
### 6.3 规则 2：执行 `DefCmd`
若：
```text
cmd = DefCmd(n, A, t)
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
    Axioms = S.Axioms,
    Defs   = S.Defs.set(n, Pair(A, t))
)
```
### 6.4 `exec` 代码
```python
# 写作 exec(S, cmd)
def exec(S: State, cmd: Command) -> State:
    '''
    执行顶层命令并返回更新后的状态
    '''


    if isinstance(cmd, AxiomCmd):
        n, A = cmd.args        # cmd = AxiomCmd n : A
        if n not in S.Axioms and n not in S.Defs:
            return State(
                Axioms = S.Axioms.set(n, A),
                Defs   = S.Defs
            )
        raise Error


    elif isinstance(cmd, DefCmd):
        n, A, t = cmd.args     # cmd = DefCmd n A t
        if n in S.Axioms or n in S.Defs:
            raise Error
        if not check_type(S, ∅, t, A):
            raise Error
        return State(
            Axioms = S.Axioms,
            Defs   = S.Defs.set(n, Pair(A, t))
        )


    raise Error
```
---
## 7. `Context`
定义上下文类型 `Context`：
```text
class Context:
    Types : PartialMap[n : LocalName, t : Term]   # 写作 n : t
```
若 `Γ : Context`，则：
```text
Γ.Types
```
表示这个上下文中记录局部变量类型的那个映射。
其中：
- 若 `Γ.Types.get(x) = A`，则表示：
  在当前局部上下文 `Γ` 中，局部变量 `x` 的类型是 `A`。
### 7.1 上下文扩展
定义函数：
```python
# 写作 Γ, x : A
# 也写作 expand_context(Γ, x, A)
def expand_context(Γ : Context, x : LocalName, A : Term) -> Context:
    return Context(
        Types = Γ.Types[x -> A]
    )
```
因此：
```text
expand_context(Γ, x, A)   写作 Γ, x : A
```
---
## 8. typing judgment
定义一个四元判断 `HasType`：
```text
HasType ⊆ State × Context × Term × Term
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
- `t : Term`
- `A : Term`
它表示：
> 在状态 `S` 和局部上下文 `Γ` 下，term `t` 的类型是 `A`。
---
## 9. `HasType` 的具体定义
`HasType` 是 `State × Context × Term × Term` 的最小子集，满足以下规则。
### 9.1 基本 typing 规则
- Var 规则
  若：
```text
Γ.Types.get(x) = A
```
则：
```text
S ; Γ ⊢ Var x : A
```
- Const-axiom 规则
  若：
```text
S.Axioms.get(n) = A
```
则：
```text
S ; Γ ⊢ Const n : A
```
- Const-def 规则
  若：
```text
S.Defs.get(n) = Pair(A, t)
```
则：
```text
S ; Γ ⊢ Const n : A
```
### 9.2 `Sort / Π / fun / App` 规则
- Sort 规则
  若：
```text
v = succ_level(u)
```
则：
```text
S ; Γ ⊢ Sort u : Sort v
```
- Forall 规则
  若：
```text
S ; Γ ⊢ A : Sort u
S ; (Γ, x : A) ⊢ B : Sort v
```
则：
```text
S ; Γ ⊢ Π (x : A), B : Sort (max_level(u, v))
```
- Lam 规则
  若：
```text
S ; Γ ⊢ A : Sort u
S ; (Γ, x : A) ⊢ t : B
S ; (Γ, x : A) ⊢ B : Sort v
```
则：
```text
S ; Γ ⊢ fun (x : A) => t : Π (x : A), B
```
- App 规则
  若：
```text
S ; Γ ⊢ f : Π (x : A), B
S ; Γ ⊢ a : A
```
则：
```text
S ; Γ ⊢ f a : B[x := a]
```
其中：
```text
B[x := a]
```
表示：
```text
subst(B, x, a)
```
### 9.3 `Sigma` 规则
- Sigma 规则（formation rule）
  若：
```text
S ; Γ ⊢ A : Sort u
S ; (Γ, x : A) ⊢ B : Sort v
```
则：
```text
S ; Γ ⊢ Σ (x : A), B : Sort (max_level(u, v))
```
**评论：** 这条规则和 `Forall` 的 formation 规则完全平行。它说明了 `Σ(x:A), B` 本身是一个 type，居于 `Sort (max_level(u, v))`。
### 9.4 `Pair` 规则
- Pair 规则（introduction rule）
  若：
```text
S ; Γ ⊢ a : A
S ; Γ ⊢ b : B[x := a]
```
则：
```text
S ; Γ ⊢ ⟨a, b⟩ : Σ (x : A), B
```
**评论：**
- 这是 `Σ` 的 introduction rule — 它告诉我们**如何构造**一个 `Σ(x:A), B` 类型的元素。
- 注意第二个前提：`b` 的类型不是 `B`，而是 `B[x := a]`。因为 `B` 中可能含有对 `x` 的引用，而 `x` 的值现在是 `a`，所以必须把 `x` 替换成 `a`。这正是"依值"的含义。
- 这条规则在 `HasType` 层面是完整的，但它在 `infer_type` 和 `check_type` 中的处理方式不同 — 详见 §12 和 §15。

### 9.5 `Fst` / `Snd` 规则                                      【v2 新增】

- Fst 规则（elimination rule — 第一投影）
  若：

```text
S ; Γ ⊢ t : Σ (x : A), B
```

则：

```text
S ; Γ ⊢ fst t : A
```

- Snd 规则（elimination rule — 第二投影）
  若：

```text
S ; Γ ⊢ t : Σ (x : A), B
```

则：

```text
S ; Γ ⊢ snd t : B[x := fst t]
```

**评论：**

- 这两条是 `Σ` 的 **elimination rules** — 它们告诉我们**如何使用**一个 `Σ(x:A), B` 类型的元素。
- `fst` 的类型直接是 `A`，很直观。
- `snd` 的类型是 `B[x := fst t]`，不是 `B`。这是因为 `B` 中含有对 `x` 的引用，而 `x` 的值是 `t` 的第一分量 `fst t`，所以必须替换。
- 注意 `fst t` 出现在 `snd` 的类型的替换结果中 — 这形成了一种**自引用**：`snd t` 的类型依赖于 `fst t`。这正是依值对子的消除规则的核心特征。
- 在路线 A 中，我们**不加入 reduction 规则**（即 `fst ⟨a, b⟩` 不会化简为 `a`）。这意味着 `snd ⟨a, b⟩` 的类型是 `B[x := fst ⟨a, b⟩]`，而不是 `B[x := a]`。加入 reduction 后这两者才会等价。

### 9.6 `Ann` 规则                                                【v3 新增】

- Ann 规则（类型标注）
  若：

```text
S ; Γ ⊢ A : Sort u
S ; Γ ⊢ t : A
```

则：

```text
S ; Γ ⊢ (t : A) : A
```

**评论：**

- 这条规则的作用是：给 term `t` 显式附上类型 `A`。如果 `A` 确实是一个 type，且 `t` 确实可以被检查为类型 `A`，那么 `(t : A)` 作为一个整体拥有类型 `A`。
- `Ann` 不是新的数学对象构造方式。它解决的是 bidirectional typing 中的一个实际问题：**把只能 check 的 term 变成可以 infer 的 term**。例如 `⟨a, b⟩` 不能 infer，但 `(⟨a, b⟩ : Σ(x:A), B)` 可以 infer 出 `Σ(x:A), B`。
- `Ann` 是 **elaboration-level 构造**，不是 Lean kernel 的底层 term。在 Lean 的表面语法中，`(⟨0, h⟩ : Σ x, P x)` 中的类型标注帮助 elaborator 理解 expected type；经 elaboration 后，`Ann` 被消去，变成 `Sigma.mk` 等具体构造子应用。
---
## 10. `FV`                                                      【v3 修改】
定义函数：
```python
# 写作 FV(t)
def FV(t : Term) -> Set[LocalName]:
    if isinstance(t, Const):
        return ∅


    if isinstance(t, Sort):
        return ∅


    if isinstance(t, Var):
        x = t.args              # t = Var x
        return {x}


    if isinstance(t, App):
        f, a = t.args           # t = f a
        return FV(f) ∪ FV(a)


    if isinstance(t, Lam):
        x, A, body = t.args     # t = fun (x : A) => body
        return FV(A) ∪ (FV(body) \ {x})


    if isinstance(t, Forall):
        x, A, B = t.args        # t = Π (x : A), B
        return FV(A) ∪ (FV(B) \ {x})


    if isinstance(t, Sigma):
        x, A, B = t.args        # t = Σ (x : A), B
        return FV(A) ∪ (FV(B) \ {x})


    if isinstance(t, Pair):
        a, b = t.args            # t = ⟨a, b⟩
        return FV(a) ∪ FV(b)

    if isinstance(t, Fst):                          # ← v2 新增
        t1 = t.args               # t = fst t1
        return FV(t1)

    if isinstance(t, Snd):                          # ← v2 新增
        t1 = t.args               # t = snd t1
        return FV(t1)

    if isinstance(t, Ann):                          # ← v3 新增
        t1, A = t.args            # t = (t1 : A)
        return FV(t1) ∪ FV(A)
```
### 10.1 例子

```text
FV(Const Nat) = ∅
FV(Var x) = {x}
FV((Var x) (Var y)) = {x, y}
FV(fun (x : Sort (level 0)) => Var x) = ∅
FV(Π (x : Sort (level 0)), Var x) = ∅
FV(Σ (x : Const Nat), (Var f) (Var x)) = {f}
FV(⟨Var x, Var y⟩) = {x, y}
FV(fst (Var x)) = {x}                【v2 新增】
FV(snd ⟨Var x, Var y⟩) = {x, y}      【v2 新增】
FV((⟨Var x, Var y⟩ : Σ (z : Const Nat), Const Nat)) = {x, y}  【v3 新增】
```

**评论：** `Fst` 和 `Snd` 的 FV 和输入 term 的 FV 相同 — 因为 `fst t` 和 `snd t` 只包含一个子 term，没有 binder。`Ann` 的 FV 是两个子 term 的 FV 的并集（和 `Pair`、`App` 平行），没有 binder 遮蔽。
---
## 11. substitution                                              【v3 修改】
定义函数：
```python
# 写作 subst(t, x, e)
# 也写作 t[x := e]
def subst(t: Term, x: LocalName, e: Term) -> Term:
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
        f, a = t.args           # t = f a
        return App(
            subst(f, x, e),
            subst(a, x, e)
        )


    if isinstance(t, Lam):
        y, A, body = t.args     # t = fun (y : A) => body


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
        y, A, B = t.args        # t = Π (y : A), B


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


    if isinstance(t, Sigma):
        y, A, B = t.args        # t = Σ (y : A), B


        A1 = subst(A, x, e)


        if y == x:
            return Sigma(y, A1, B)


        if y not in FV(e):
            return Sigma(
                y,
                A1,
                subst(B, x, e)
            )


        z = fresh_local_name(FV(B) ∪ FV(e) ∪ {x, y})
        B1 = alpha_rename_binder(B, y, z)
        return Sigma(
            z,
            A1,
            subst(B1, x, e)
        )


    if isinstance(t, Pair):
        a, b = t.args            # t = ⟨a, b⟩
        return Pair(
            subst(a, x, e),
            subst(b, x, e)
        )

    if isinstance(t, Fst):                          # ← v2 新增
        t1 = t.args               # t = fst t1
        return Fst(subst(t1, x, e))

    if isinstance(t, Snd):                          # ← v2 新增
        t1 = t.args               # t = snd t1
        return Snd(subst(t1, x, e))

    if isinstance(t, Ann):                          # ← v3 新增
        t1, A = t.args            # t = (t1 : A)
        return Ann(
            subst(t1, x, e),
            subst(A, x, e)
        )
```
**评论：** `Pair` 的 subst 和 `App` 完全平行 — 递归地对两个子 term 做替换即可。因为 `Pair` 没有 binder，所以不存在变量捕获的问题。`Ann` 的 subst 也是如此 — 递归替换两个子 term，没有 binder。
这里用了两个辅助函数：
```python
# 写作 fresh_local_name(used)
def fresh_local_name(used : Set[LocalName]) -> LocalName:
    '''
    返回一个不在 used 中的新局部变量名
    '''


# 写作 alpha_rename_binder(t, old, new)
def alpha_rename_binder(t : Term, old : LocalName, new : LocalName) -> Term:
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
subst((Var x) (Var y), x, Const Nat) = (Const Nat) (Var y)
subst(fun (x : Sort (level 0)) => Var x, x, Const Nat)
= fun (x : Sort (level 0)) => Var x
subst(fun (y : Sort (level 0)) => Var x, x, Const Nat)
= fun (y : Sort (level 0)) => Const Nat
```

并且：

```text
subst(fun (y : Sort (level 0)) => Var x, x, Var y)
```

不能直接得到：

```text
fun (y : Sort (level 0)) => Var y
```

因为这会发生变量捕获。
应先把 binder `y` 改名为一个新名字 `z`，再替换，得到：

```text
fun (z : Sort (level 0)) => Var y
```

`Sigma`、`Pair`、`Fst`、`Snd` 的 subst 与已有的构造子完全平行（`Sigma` 同 `Forall`，`Pair` 同 `App`，`Fst`/`Snd` 递归替换子 term）：

```text
subst(Σ (y : Const Nat), Var x, x, Const zero) = Σ (y : Const Nat), Const zero
subst(⟨Var x, Var y⟩, x, Const zero) = ⟨Const zero, Var y⟩
subst(fst (Var x), x, Const zero) = fst (Const zero)           【v2 新增】
subst(snd ⟨Var x, Var y⟩, x, Const zero) = snd ⟨Const zero, Var y⟩  【v2 新增】
subst((⟨Var x, Var y⟩ : Σ (z : Const Nat), Const Nat), x, Const zero)
= ⟨Const zero, Var y⟩ : Σ (z : Const Nat), Const Nat            【v3 新增】
```
---
## 12. `infer_type` 与 `check_type`                              【v3 修改】
### 12.0 背景：为什么需要两个函数？

如果所有 term 都能从自身推断类型，那么 `check_type` 只需要是 `infer_type` 的简单包装：

```text
check_type(S, Γ, t, A) = (infer_type(S, Γ, t) == A)
```

这对 `Var`、`Const`、`Sort`、`App`、`Lam`、`Forall`、`Sigma` 都够用 — 它们自身携带了足够的信息来确定类型。

但 `Pair` 打破了这个假设。`⟨a, b⟩` 自身不携带足够的信息来确定类型 — 同样的 `⟨zero, zero⟩`，在不同的目标 `Σ(x:A), B` 下可能合法也可能不合法。因此需要引入 **bidirectional typing**：
- **infer 模式**（synthesis）：`infer_type(S, Γ, t)` — 给定 term，推断出类型。
- **check 模式**：`check_type(S, Γ, t, A)` — 给定 term 和目标类型，检查是否合法。
两者的关系是：
```text
check_type 可以调用 infer_type（"先推断，再比较"）
check_type 也可以调用 check_type（递归检查子项）
infer_type 可以调用 check_type（如 App 中检查参数类型）
```
这和 **Lean 的真实实现**是一致的：
- Lean 的 elaborator 中，anonymous constructor `⟨a, b⟩` 必须知道 expected type 才能处理。
- Lean 的 kernel 中，构造子的类型签名存储在环境中，所以 kernel 可以 infer。但这依赖 inductive type 声明机制，我们当前模型还没有引入。
### 12.1 `infer_type` 的定义
```text
infer_type(S : State, Γ : Context, t : Term) -> Term
```
写作：
```text
infer_type(S, Γ, t)
```
它的含义是：
- 输入状态 `S`
- 输入上下文 `Γ`
- 输入一个 term `t`
- 若 `t` 在 `S` 和 `Γ` 下可推断类型，则返回它的类型
- 若不可推断，则 `infer_type(S, Γ, t)` 不定义（代码中写作 `raise Error`）
### 12.2 `check_type` 的定义
```text
check_type(S : State, Γ : Context, t : Term, A : Term) -> bool
```
写作：
```text
check_type(S, Γ, t, A)
```
它的含义是：
- 输入状态 `S`
- 输入上下文 `Γ`
- 输入一个 term `t`
- 输入一个目标类型 `A`
- 若 `t` 在 `S` 和 `Γ` 下可以拥有类型 `A`，则返回 `True`
- 否则返回 `False`
当前阶段不加 conversion 规则，所以不会把 definitionally equal 但不完全相同的两个 type 视为相等。
### 12.3 代码
```python
# 写作 infer_type(S, Γ, t)
def infer_type(S: State, Γ: Context, t: Term) -> Term:
    '''
    在 S 和 Γ 下推断 t 的类型（infer 模式）
    若无法推断，则 raise Error
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
        x, A, B = t.args           # t = Π (x : A), B


        TA = infer_type(S, Γ, A)
        if not isinstance(TA, Sort):
            raise Error
        u = TA.args                # TA = Sort u


        Γ1 = expand_context(Γ, x, A)
        TB = infer_type(S, Γ1, B)
        if not isinstance(TB, Sort):
            raise Error
        v = TB.args                # TB = Sort v


        return Sort(max_level(u, v))


    elif isinstance(t, Lam):
        x, A, body = t.args        # t = fun (x : A) => body


        TA = infer_type(S, Γ, A)
        if not isinstance(TA, Sort):
            raise Error


        Γ1 = expand_context(Γ, x, A)
        B = infer_type(S, Γ1, body)


        TB = infer_type(S, Γ1, B)
        if not isinstance(TB, Sort):
            raise Error


        return Forall(x, A, B)


    elif isinstance(t, App):
        f, a = t.args              # t = f a


        Tf = infer_type(S, Γ, f)
        if not isinstance(Tf, Forall):
            raise Error
        x, A, B = Tf.args          # Tf = Π (x : A), B


        if not check_type(S, Γ, a, A):
            raise Error


        return subst(B, x, a)


    elif isinstance(t, Sigma):
        x, A, B = t.args          # t = Σ (x : A), B


        TA = infer_type(S, Γ, A)
        if not isinstance(TA, Sort):
            raise Error
        u = TA.args                # TA = Sort u


        Γ1 = expand_context(Γ, x, A)
        TB = infer_type(S, Γ1, B)
        if not isinstance(TB, Sort):
            raise Error
        v = TB.args                # TB = Sort v


        return Sort(max_level(u, v))


    elif isinstance(t, Pair):
        # ⟨a, b⟩ 没有目标类型，无法推断
        raise Error


    elif isinstance(t, Fst):                       # ← v2 新增
        t1 = t.args                # t = fst t1
        Tt1 = infer_type(S, Γ, t1)
        if not isinstance(Tt1, Sigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = Σ (x : A), B
        return A

    elif isinstance(t, Snd):                       # ← v2 新增
        t1 = t.args                # t = snd t1
        Tt1 = infer_type(S, Γ, t1)
        if not isinstance(Tt1, Sigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = Σ (x : A), B
        return subst(B, x, Fst(t1))

    elif isinstance(t, Ann):                       # ← v3 新增
        t1, A = t.args             # t = (t1 : A)
        TA = infer_type(S, Γ, A)
        if not isinstance(TA, Sort):
            raise Error
        if not check_type(S, Γ, t1, A):
            raise Error
        return A

    raise Error



# 写作 check_type(S, Γ, t, A)
def check_type(S: State, Γ: Context, t: Term, A: Term) -> bool:
    '''
    在 S 和 Γ 下检查 t : A（check 模式）
    '''
    try:
        if isinstance(t, Pair):
            # Pair 只能在已知目标类型时检查
            if not isinstance(A, Sigma):
                return False
            a, b = t.args       # t = ⟨a, b⟩
            x, A1, B = A.args   # A = Σ (x : A1), B
            return (
                check_type(S, Γ, a, A1)
                and
                check_type(S, Γ, b, subst(B, x, a))
            )


        # 其他情况：先推断类型，再与目标类型比较
        return infer_type(S, Γ, t) == A


    except:
        return False
```
**评论：**
- `check_type` 从一个一行包装器变成了一个独立的推导机制。这是加入 `Pair` 带来的最关键的概念升级。
- 注意 `check_type` 内部**递归调用自己**：`check_type(S, Γ, a, A1)` 和 `check_type(S, Γ, b, subst(B, x, a))`。这意味着 `a` 或 `b` 本身也可以是 `Pair`，递归地需要 check 模式。
- `try/except` 包住整个函数体，确保内部任何 `raise Error`（来自 `infer_type` 或 `subst`）都被捕获并返回 `False`。
- 在 `App` 规则中，`infer_type` 已经调用了 `check_type` 来检查参数类型。所以 `infer` 和 `check` 是互相调用的，不是单方向的。
- `Fst` 和 `Snd` 在 `infer_type` 中直接处理 — 它们**可以推断类型**。因为给定 `t : Σ(x:A), B`，`fst t` 的类型一定是 `A`，`snd t` 的类型一定是 `B[x := fst t]`，不存在歧义。这与 `Pair` 不同。
- 注意 `snd` 的类型中出现了 `Fst(t1)` — 这是一个**未经化简的项**。在当前阶段没有 reduction，所以它就保持这个形式。
- `Ann` 的 infer 规则是：先检查 `A` 是 type（`infer_type(S, Γ, A)` 是 Sort），再检查 `t1` 可以拥有类型 `A`（`check_type(S, Γ, t1, A)`），如果都成功则返回 `A`。这正好实现了"把只能 check 的 term 变成可以 infer 的 term"。
- `Ann` 在 `check_type` 中不需要特殊处理 — 它能 infer，所以走默认的 `infer_type == A` 即可。
---
## 13. 一些有意义的例子（`Π / fun / App`）
下面给出一组彼此衔接的例子。
这些例子一方面帮助理解 `Π / fun / App`，另一方面也帮助理解 `State` 和 `Context` 的区别。
### 13.1 先加入一些全局名字
取空状态 `S0 : State`，满足：
```text
S0.Axioms = {}
S0.Defs   = {}
```
先执行：
```text
S1 = exec(S0, AxiomCmd Nat : Sort (level 0))
```
则有：
```text
S1.Axioms = {
  Nat : Sort (level 0)
}
S1.Defs = {}
```
再执行：
```text
S2 = exec(S1, AxiomCmd zero : Const Nat)
```
则有：
```text
S2.Axioms = {
  Nat  : Sort (level 0),
  zero : Const Nat
}
S2.Defs = {}
```
再执行：
```text
S3 = exec(S2, AxiomCmd Pred : Π (x : Const Nat), Sort (level 0))
```
则有：
```text
S3.Axioms = {
  Nat  : Sort (level 0),
  zero : Const Nat,
  Pred : Π (x : Const Nat), Sort (level 0)
}
S3.Defs = {}
```
再执行：
```text
S4 = exec(S3, AxiomCmd choosePred : Π (x : Const Nat), (Const Pred) (Var x))
```
则有：
```text
S4.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
}
S4.Defs = {}
```
这里：
- `Nat` 是一个全局 type；
- `zero` 是一个全局常量，类型是 `Nat`；
- `Pred` 是一个依值 type family：对每个 `x : Nat`，`Pred x` 都是一个 type；
- `choosePred` 是一个依值函数：对每个 `x : Nat`，它给出一个 `Pred x` 的元素。
### 13.2 全局常量的类型来自 `State`
在任意上下文 `Γ : Context` 下，都有：
```text
S4 ; Γ ⊢ Const Nat : Sort (level 0)
S4 ; Γ ⊢ Const zero : Const Nat
```
因为：
```text
S4.Axioms.get(Nat)  = Sort (level 0)
S4.Axioms.get(zero) = Const Nat
```
这说明：
- `Const Nat`
- `Const zero`
这些全局名字的类型，都由 `State` 决定，而不由 `Context` 决定。
### 13.3 局部变量的类型来自 `Context`
取一个上下文 `Γ1 : Context`：
```text
Γ1.Types = {
  x : Const Nat
}
```
则有：
```text
S4 ; Γ1 ⊢ Var x : Const Nat
```
因为：
```text
Γ1.Types.get(x) = Const Nat
```
但在空上下文 `∅` 中，没有：
```text
∅.Types.get(x) = Const Nat
```
因此：
```text
S4 ; ∅ ⊬ Var x : Const Nat
```
这说明：
- `Var x` 这样的局部变量，其类型来自 `Context`；
- 不在 `Context` 里的局部变量，当前不能直接使用。
### 13.4 一个最基本的非依值函数
考虑 term：
```text
fun (x : Const Nat) => Var x
```
我们说明：
```text
S4 ; Γ ⊢ fun (x : Const Nat) => Var x : Π (x : Const Nat), Const Nat
```
理由如下。
首先：
```text
S4 ; Γ ⊢ Const Nat : Sort (level 0)
```
再令：
```text
Γ2 = Γ, x : Const Nat
```
则有：
```text
S4 ; Γ2 ⊢ Var x : Const Nat
S4 ; Γ2 ⊢ Const Nat : Sort (level 0)
```
因此由 `Lam` 规则可得：
```text
S4 ; Γ ⊢ fun (x : Const Nat) => Var x : Π (x : Const Nat), Const Nat
```
### 13.5 把上面的函数加入 `State` 作为顶层定义
执行：
```text
S5 = exec(
  S4,
  DefCmd idNat
    (Π (x : Const Nat), Const Nat)
    (fun (x : Const Nat) => Var x)
)
```
则有：
```text
S5.Defs.get(idNat)
=
(
  Π (x : Const Nat), Const Nat,
  fun (x : Const Nat) => Var x
)
```
因此，在任意上下文 `Γ : Context` 下，都有：
```text
S5 ; Γ ⊢ Const idNat : Π (x : Const Nat), Const Nat
```
这说明：
- 在检查 `fun (x : Const Nat) => Var x` 时，需要临时把 `x : Nat` 放进 `Context`；
- 但检查完成后，整个函数作为一个闭项进入 `State`。
也就是说：
- `Context` 是局部、临时的；
- `State` 是顶层、长期的。
### 13.6 应用一个非依值函数
现在考虑：
```text
(Const idNat) (Const zero)
```
先有：
```text
S5 ; Γ ⊢ Const idNat : Π (x : Const Nat), Const Nat
S5 ; Γ ⊢ Const zero  : Const Nat
```
因此由 `App` 规则：
```text
S5 ; Γ ⊢ (Const idNat) (Const zero) : (Const Nat)[x := Const zero]
```
而 `Const Nat` 中并没有自由出现的 `x`，所以：
```text
(Const Nat)[x := Const zero] = Const Nat
```
故：
```text
S5 ; Γ ⊢ (Const idNat) (Const zero) : Const Nat
```
这说明：
- 非依值函数只是依值函数的特例；
- 在非依值情形下，`B[x := a]` 这一步替换可能什么都不改变。
### 13.7 一个真正依值的 type family
由前面的 `State S4`，我们已经有：
```text
S4 ; Γ ⊢ Const Pred : Π (x : Const Nat), Sort (level 0)
```
因此可得：
```text
S4 ; Γ ⊢ (Const Pred) (Const zero) : Sort (level 0)
```
也就是说：
```text
(Const Pred) (Const zero)
```
本身是一个 type。
### 13.8 一个真正依值的函数应用
由 `S4` 中的声明，有：
```text
S4 ; Γ ⊢ Const choosePred : Π (x : Const Nat), (Const Pred) (Var x)
S4 ; Γ ⊢ Const zero : Const Nat
```
因此由 `App` 规则：
```text
S4 ; Γ ⊢ (Const choosePred) (Const zero) : ((Const Pred) (Var x))[x := Const zero]
```
而替换后得到：
```text
((Const Pred) (Var x))[x := Const zero] = (Const Pred) (Const zero)
```
所以：
```text
S4 ; Γ ⊢ (Const choosePred) (Const zero) : (Const Pred) (Const zero)
```
这个例子体现了依值函数的核心：
- `choosePred` 的返回类型不是固定的；
- 当输入从 `x` 变成 `zero` 时，返回类型也随之变成 `Pred zero`。
### 13.9 一个依值的 lambda
考虑 term：
```text
fun (x : Const Nat) => (Const choosePred) (Var x)
```
我们说明：
```text
S4 ; Γ ⊢ fun (x : Const Nat) => (Const choosePred) (Var x)
      : Π (x : Const Nat), (Const Pred) (Var x)
```
理由如下。
先有：
```text
S4 ; Γ ⊢ Const Nat : Sort (level 0)
```
令：
```text
Γ3 = Γ, x : Const Nat
```
则：
```text
S4 ; Γ3 ⊢ Const choosePred : Π (x : Const Nat), (Const Pred) (Var x)
S4 ; Γ3 ⊢ Var x : Const Nat
```
因此由 `App` 规则：
```text
S4 ; Γ3 ⊢ (Const choosePred) (Var x) : (Const Pred) (Var x)
```
并且：
```text
S4 ; Γ3 ⊢ (Const Pred) (Var x) : Sort (level 0)
```
因此由 `Lam` 规则：
```text
S4 ; Γ ⊢ fun (x : Const Nat) => (Const choosePred) (Var x)
      : Π (x : Const Nat), (Const Pred) (Var x)
```
---
## 14. 小结：`State` 与 `Context`
从上面的例子可以看出：
- `State` 记录的是全局名字的信息，例如：
  - `Nat`
  - `zero`
  - `Pred`
  - `choosePred`
  - `idNat`
- `Context` 记录的是当前局部变量的信息，例如：
  - `x : Const Nat`
因此：
- `Const n` 的类型来自 `State`
- `Var x` 的类型来自 `Context`
也就是说：
- `State` 是顶层世界
- `Context` 是当前 binder 打开的局部世界
---
## 15. 关于 bidirectional typing                                  【v3 修改】
加入 `Pair` 之后，我们的模型引入了一个重要的概念区分：**infer 模式** 与 **check 模式**。
### 15.1 哪些 term 可以 infer？
以下 term 可以在 `infer_type` 中成功推断类型：
```text
Var x          → 从 Context 中查到
Const n        → 从 State 中查到
Sort u         → 总是 Sort (succ_level(u))
App f a        → 从 f 的类型中算出
Lam x A body   → 自带类型注解 A，可以算出 Π(x:A), B
Forall x A B   → 可以算出 Sort(max(u, v))
Sigma x A B    → 可以算出 Sort(max(u, v))
Fst t          → 从 t 的类型 Σ(x:A), B 中取出 A
Snd t          → 从 t 的类型 Σ(x:A), B 中取出 B[x := fst t]
Ann(t, A)      → 显式标注类型 A，前提是 check_type(t, A) 成功  【v3 新增】
```
它们的共同特点是：**自身携带了足够的信息来确定类型**。
### 15.2 哪些 term 只能 check？
当前阶段：
```text
Pair a b       → 只能在已知目标类型 Σ(x:A), B 时检查
```
原因是：同样的 `⟨a, b⟩`，在不同的目标 `Σ(x:A), B` 下可能有不同的合法性。`Pair` 自身不携带 `B` 的信息。

但通过 `Ann`，可以把裸 `Pair` 包装成可推断的 term：

```text
Ann(⟨a, b⟩, Σ(x:A), B)  →  可以 infer 出 Σ(x:A), B
```

前提是 `check_type(S, Γ, ⟨a, b⟩, Σ(x:A), B) = True`。
### 15.3 infer 和 check 的互相调用
两个函数不是单方向的，而是互相调用：
```text
infer_type 调用 check_type：
  - App 规则中，检查参数 a : A 时用 check_type


check_type 调用 infer_type：
  - 非 Pair 的 term，先 infer 再比较


check_type 调用 check_type：
  - Pair 规则中，递归检查子项
```
### 15.4 和 Lean 的关系
这个设计在 Lean 的真实实现中有直接的对应：
| 我们的模型                              | Lean 中的对应                                              |
| ---------------------------------- | ------------------------------------------------------ |
| `infer_type` 遇到 `Pair` raise Error | Lean elaborator 中 `⟨a, b⟩` 需要 expected type            |
| `check_type` 处理 `Pair`             | Lean elaborator 用 expected type 来 elaboration `⟨a, b⟩` |
| 构造子存储在环境中（尚未引入）                    | Lean kernel 中 `Sigma.mk` 的类型可从环境查到                     |
当前模型更接近 **Lean elaborator** 的行为。将来加入 inductive type 声明机制后，`Pair` 可能会变成全局可查的构造子，那时 `infer_type` 也能处理它。

### 15.5 一个实际缺口：裸 `Pair` 无法被 `fst`/`snd` 使用           【v3 新增】

§15.2 说了 `Pair` 只能 check 不能 infer。这导致一个具体的困难：

```text
snd ⟨a, b⟩
```

会失败。因为 `snd` 的 `infer_type` 需要先推断出 `⟨a, b⟩` 的类型（才能知道它是 `Σ(x:A), B`），但 `⟨a, b⟩` 不能推断 — 它不知道自己的 `A` 和 `B` 是什么。

v2 解决这个问题的办法是用 `DefCmd`：先把 pair 注册为全局定义（这样 `Const pair0` 可以 infer），再对 `Const pair0` 做 `fst`/`snd`。但这有点绕 — 明明已经有一个 pair 值在手里了，为什么非得给它取个名字才能用？

v3 加入 `Ann(t, A)` 就是为了填这个缺口。直觉很简单：

```text
⟨a, b⟩ 不能 infer        ← 缺信息
(⟨a, b⟩ : Σ(x:A), B) 可以 infer  ← 补上信息
```

`Ann` 就像一个标签：它不改变 term 的值，只是显式告诉类型系统"这个 term 的类型是 `A`"。有了这个标签，`snd (⟨a, b⟩ : Σ(x:A), B)` 就能工作了 — `snd` 先从 `Ann` 推断出 `Σ(x:A), B`，然后正常执行 elimination。

这和 Lean 表面语法中的 `(⟨0, h⟩ : Σ x, P x)` 完全对应 — 写 Lean 代码时你也经常需要加这个标注。

---
## 16. `Σ / Pair / fst / snd / Ann` 综合例子                    【v3 重写】

下面给出一组衔接的例子，覆盖 `Σ` 的 formation、`Pair` 的 introduction、`fst/snd` 的 elimination。每一步推导都标注使用的规则。

### 16.0 构建前置状态

取空状态 `S0`，依次执行：

```text
S1 = exec(S0, AxiomCmd Nat : Sort (level 0))
S2 = exec(S1, AxiomCmd zero : Const Nat)
S3 = exec(S2, AxiomCmd Pred : Π (x : Const Nat), Sort (level 0))
S  = exec(S3, AxiomCmd choosePred : Π (x : Const Nat), (Const Pred) (Var x))
```

因此 `S` 满足：

```text
S.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
}
S.Defs = {}
```

以下推导在空上下文 `∅` 下进行。

### 16.1 Formation：构造 `Σ` 类型

**目标：** 证明

```text
S ; ∅ ⊢ Σ (x : Const Nat), (Const Pred) (Var x) : Sort (level 0)
```

**推导过程：**

第一步，由 `Const-axiom` 规则（`S.Axioms.get(Nat) = Sort (level 0)`）：

```text
S ; ∅ ⊢ Const Nat : Sort (level 0)                           (Const-axiom)
```

因此 `u = level 0`。

第二步，在扩展上下文 `∅, x : Const Nat` 下。先由 `Const-axiom` 规则（`S.Axioms.get(Pred) = Π (x : Const Nat), Sort (level 0)`）：

```text
S ; ∅, x : Const Nat ⊢ Const Pred : Π (x : Const Nat), Sort (level 0)  (Const-axiom)
```

再由 `Var` 规则（`(∅, x : Const Nat).Types.get(x) = Const Nat`）：

```text
S ; ∅, x : Const Nat ⊢ Var x : Const Nat                     (Var)
```

由 `App` 规则，`B = Sort (level 0)`，`B[x := Var x] = Sort (level 0)`：

```text
S ; ∅, x : Const Nat ⊢ (Const Pred) (Var x) : Sort (level 0) (App)
```

因此 `v = level 0`。

第三步，由 `Sigma` 规则（formation rule），`max_level(level 0, level 0) = level 0`：

```text
S ; ∅ ⊢ Const Nat : Sort (level 0)                           (已证)
S ; ∅, x : Const Nat ⊢ (Const Pred) (Var x) : Sort (level 0) (已证)
──────────────────────────────────────────────────────────────────────
S ; ∅ ⊢ Σ (x : Const Nat), (Const Pred) (Var x) : Sort (level 0)  (Sigma)
```

**评论：** `Π` 和 `Σ` 的 formation 规则前提完全相同，区别只在结论的构造子。

### 16.2 Introduction：构造 pair

**目标：** 证明

```text
check_type(S, ∅, ⟨Const zero, (Const choosePred) (Const zero)⟩,
           Σ (x : Const Nat), (Const Pred) (Var x)) = True
```

**推导过程：**

目标类型为 `Σ (x : Const Nat), (Const Pred) (Var x)`，其中 `A = Const Nat`，`B = (Const Pred) (Var x)`。`check_type` 对 `Pair` 的处理需要检查两个子项。

**第一个子项** `a = Const zero`，目标类型 `A = Const Nat`：

由 `Const-axiom` 规则（`S.Axioms.get(zero) = Const Nat`）：

```text
S ; ∅ ⊢ Const zero : Const Nat                               (Const-axiom)
```

`infer_type(S, ∅, Const zero) = Const Nat`，与目标 `Const Nat` 结构相等 ✓

**第二个子项** `b = (Const choosePred) (Const zero)`，目标类型为 `B[x := a]`。

先计算替换：

```text
B[x := Const zero] = (Const Pred) (Var x)[x := Const zero] = (Const Pred) (Const zero)
```

然后推导 `b` 的类型。由 `Const-axiom` 规则：

```text
S ; ∅ ⊢ Const choosePred : Π (x : Const Nat), (Const Pred) (Var x)  (Const-axiom)
```

再由 `Const-axiom` 规则：

```text
S ; ∅ ⊢ Const zero : Const Nat                               (Const-axiom)
```

由 `App` 规则，`B = (Const Pred) (Var x)`，`B[x := Const zero] = (Const Pred) (Const zero)`：

```text
──────────────────────────────────────────────────────────────────────
S ; ∅ ⊢ (Const choosePred) (Const zero) : (Const Pred) (Const zero)  (App)
```

`infer_type(S, ∅, (Const choosePred) (Const zero)) = (Const Pred) (Const zero)`，与目标 `(Const Pred) (Const zero)` 结构相等 ✓

**结论：** 由 `Pair` 规则（introduction rule）：

```text
S ; ∅ ⊢ Const zero : Const Nat                               (Const-axiom)
S ; ∅ ⊢ (Const choosePred) (Const zero) : (Const Pred) (Const zero)  (App)
──────────────────────────────────────────────────────────────────────
S ; ∅ ⊢ ⟨Const zero, (Const choosePred) (Const zero)⟩
      : Σ (x : Const Nat), (Const Pred) (Var x)              (Pair)
```

**评论：** `Pair` 只能在已知目标类型时检查（check 模式）。`check_type` 递归调用自己来检查两个子项。

### 16.3 Ann：让裸 pair 可以被 infer                                【v3 新增】

**目标：** 证明

```text
infer_type(S, ∅, (⟨Const zero, (Const choosePred) (Const zero)⟩
                   : Σ (x : Const Nat), (Const Pred) (Var x)))
= Σ (x : Const Nat), (Const Pred) (Var x)
```

**推导过程：**

`infer_type` 对 `Ann` 的处理步骤：

1. 检查 `A = Σ (x : Const Nat), (Const Pred) (Var x)` 是否为 type：

```text
infer_type(S, ∅, Σ (x : Const Nat), (Const Pred) (Var x)) = Sort (level 0)
```

已在 §16.1 中证明 ✓

2. 检查 `check_type(S, ∅, ⟨Const zero, (Const choosePred) (Const zero)⟩, Σ (x : Const Nat), (Const Pred) (Var x)) = True`：

已在 §16.2 中证明 ✓

3. 返回 `A`：

```text
infer_type(S, ∅, (⟨Const zero, (Const choosePred) (Const zero)⟩
                   : Σ (x : Const Nat), (Const Pred) (Var x)))
= Σ (x : Const Nat), (Const Pred) (Var x)
```

用 HasType 规则表达：

```text
S ; ∅ ⊢ Σ (x : Const Nat), (Const Pred) (Var x) : Sort (level 0)  (Sigma)
S ; ∅ ⊢ ⟨Const zero, (Const choosePred) (Const zero)⟩
      : Σ (x : Const Nat), (Const Pred) (Var x)                    (Pair)
──────────────────────────────────────────────────────────────────────
S ; ∅ ⊢ (⟨Const zero, (Const choosePred) (Const zero)⟩
         : Σ (x : Const Nat), (Const Pred) (Var x))
      : Σ (x : Const Nat), (Const Pred) (Var x)                    (Ann)
```

**评论：** `Ann` 的效果 — 把只能 check 的 `⟨a, b⟩` 变成可以 infer 的 `(⟨a, b⟩ : Σ(x:A), B)`。不再需要先通过 DefCmd 注册为全局定义（v2 的做法）。

### 16.4 Elimination：`fst` 取第一分量（via Ann）

以下简记 `p_ann = (⟨Const zero, (Const choosePred) (Const zero)⟩ : Σ (x : Const Nat), (Const Pred) (Var x))`。

**目标：** 计算 `infer_type(S, ∅, fst p_ann)`。

**推导过程：**

`infer_type` 对 `Fst` 的处理步骤：

1. 递归推断 `t1 = p_ann` 的类型：

```text
infer_type(S, ∅, p_ann) = Σ (x : Const Nat), (Const Pred) (Var x)  (Ann，§16.3 已证)
```

2. 匹配 `Sigma`，提取 `A = Const Nat`。
3. 返回 `A`：

```text
infer_type(S, ∅, fst p_ann) = Const Nat
```

用 HasType 规则表达：

```text
S ; ∅ ⊢ p_ann : Σ (x : Const Nat), (Const Pred) (Var x)         (Ann)
──────────────────────────────────────────────────────────────────────
S ; ∅ ⊢ fst p_ann : Const Nat                                    (Fst)
```

### 16.5 Elimination：`snd` 取第二分量（via Ann）

**目标：** 计算 `infer_type(S, ∅, snd p_ann)`。

**推导过程：**

`infer_type` 对 `Snd` 的处理步骤：

1. 递归推断 `t1 = p_ann` 的类型：

```text
infer_type(S, ∅, p_ann) = Σ (x : Const Nat), (Const Pred) (Var x)
```

2. 匹配 `Sigma`，提取 `B = (Const Pred) (Var x)`。
3. 计算替换 `subst(B, x, Fst(t1))` = `subst((Const Pred) (Var x), x, fst p_ann)`：

```text
(Const Pred) (Var x)[x := fst p_ann] = (Const Pred) (fst p_ann)
```

4. 返回替换结果：

```text
infer_type(S, ∅, snd p_ann) = (Const Pred) (fst p_ann)
```

用 HasType 规则表达：

```text
S ; ∅ ⊢ p_ann : Σ (x : Const Nat), (Const Pred) (Var x)         (Ann)
──────────────────────────────────────────────────────────────────────
S ; ∅ ⊢ snd p_ann : (Const Pred) (fst p_ann)                     (Snd)
```

**评论：**
- `snd p_ann` 的类型是 `(Const Pred) (fst p_ann)`，不是 `(Const Pred) (Const zero)`。
- `Ann` 解决的是"裸 Pair 不能 infer"的问题。但 `snd` 的类型中仍然包含未化简的 `fst p_ann`。
- 要让 `fst p_ann` 化简为 `Const zero`，需要加入 reduction 规则。这是后续版本的任务。

### 16.6 对比：Ann vs DefCmd                                       【v3 新增】

v2 通过 DefCmd 解决 "Pair 不能 infer" 的问题（§16.3-16.5），v3 通过 Ann 解决同样的问题：

```text
-- v2 的做法：先把 pair 注册为全局定义
S' = exec(S, DefCmd myPair (Σ (x : Const Nat), (Const Pred) (Var x)) ⟨...⟩)
infer_type(S', ∅, snd (Const myPair))                           -- 通过 Const-def 推断

-- v3 的做法：直接用 Ann 标注类型
infer_type(S, ∅, snd (⟨...⟩ : Σ (x : Const Nat), (Const Pred) (Var x)))  -- 通过 Ann 推断
```

两种方法对比：

- **DefCmd**：需要修改 State，引入全局名字，但 pair 可以反复使用
- **Ann**：不需要修改 State，不需要全局名字，但每次使用都要写标注

**评论：** `Ann` 更接近 Lean 的表面语法 — 写 `(⟨0, h⟩ : Σ x, P x)` 比 `def p := ⟨0, h⟩` 更轻量。在 Lean 底层，`Ann` 会在 elaboration 后被消去，变成 `Sigma.mk` 等具体构造子应用。

### 16.7 `fst`/`snd` vs `Pair` vs `Ann`：infer 与 check

```text
infer_type(S, ∅, fst p_ann) = Const Nat                           ✓ fst 可以推断
infer_type(S, ∅, snd p_ann) = (Const Pred) (fst p_ann)            ✓ snd 可以推断
infer_type(S, ∅, p_ann) = Σ (x : Const Nat), (Const Pred) (Var x) ✓ Ann 可以推断
infer_type(S, ∅, ⟨Const zero, (Const choosePred) (Const zero)⟩)    ✗ Pair 不能推断
```

- `Ann` 把只能 check 的 term 包装成可以 infer 的 term。
- `fst`/`snd` 可以作用于任何能 infer 出 `Σ` 类型的 term（包括 `Ann` 包装的 pair）。
- 裸 `Pair` 仍然不能 infer — 但现在可以通过 `Ann` 来解决。

---

## 17. 当前阶段的边界                                            【v3 修改】

当前阶段，我们已经有：

```text
Sort
Var
Const
Π
fun
App
Σ
Pair
fst
snd
Ann
```

以及：

```text
bidirectional typing（infer 模式 / check 模式）
```

当前模型可以处理：

```text
裸 Pair 不能 infer
Pair 可以在 Σ 目标类型下 check
Ann(Pair, Σ-type) 可以 infer 出 Σ-type
fst / snd 可以作用在 Ann(Pair, Σ-type) 上
```

但当前阶段还**没有**加入：

```text
reduction
definitional equality
conversion
```

因此还没有计算规则：

```text
fst ⟨a, b⟩ ↦ a
snd ⟨a, b⟩ ↦ b
(fun (x : A) => t) a ↦ t[x := a]
```

下一步可以加入 reduction（最小计算规则），但要注意：一旦加入 reduction，`check_type` 的类型比较就不能继续只用结构相等，后续会自然走向 definitional equality / conversion。
