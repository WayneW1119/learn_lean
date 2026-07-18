# model v5

> 本文档在 v4 基础上扩展。
>
> **相对于 v4 的变化：**
>
> - §9.7：新增 Conversion 规则
> - §12：新增 whnf（弱头部正规化）
> - §13：新增 defeq（definitional equality）
> - §14：infer_type/check_type 改用 whnf 和 defeq
> - §19-20：新增 whnf 和 defeq 例子
> - §22：更新边界说明
>
> **记号约定：** 本文档中有时使用"令 X = ..."或"简记 X 为 ..."。这是**文本层面的临时缩写**，不是模型中的操作。模型中没有"令"或"赋值"的概念 — State 的修改只能通过 `exec` 执行命令来完成。
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
## 3. `Term`
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
     | Ann(t : Term, A : Term)                    # 写作 (t : A)
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
fst ⟨Const zero, Const zero⟩
snd (Var x)
```

也都 `: Term`。以及：

```text
(⟨Const zero, Const zero⟩ : Σ (x : Const Nat), Const Nat)
(Const zero : Const Nat)
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
- 这条规则在 `HasType` 层面是完整的，但它在 `infer_type` 和 `check_type` 中的处理方式不同 — 详见 §14 和 §17。

### 9.5 `Fst` / `Snd` 规则

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

### 9.6 `Ann` 规则

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

### 9.7 `Conversion` 规则                                            【v5 新增】

- Conversion 规则（类型转换）
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

**评论：**

- 这是 type theory 中的标准 **conversion rule**。它说的是：如果 `t` 有类型 `A`，而 `A` 和 `B` 是 definitionally equal 的类型，那么 `t` 也可以被看作有类型 `B`。
- 在实现层面，我们不直接用这条规则 — 而是通过修改 `check_type` 的默认分支，把 `==` 替换成 `defeq`（见 §14）。
- `defeq` 是 definitional equality 的缩写。它比结构相等更宽松：不仅允许 alpha-renaming，还允许通过 reduction（beta、delta、fst/snd 投影、Ann 擦除）产生的相等。

---
## 10. `FV`
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

    if isinstance(t, Fst):
        t1 = t.args               # t = fst t1
        return FV(t1)

    if isinstance(t, Snd):
        t1 = t.args               # t = snd t1
        return FV(t1)

    if isinstance(t, Ann):
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
FV(fst (Var x)) = {x}
FV(snd ⟨Var x, Var y⟩) = {x, y}
FV((⟨Var x, Var y⟩ : Σ (z : Const Nat), Const Nat)) = {x, y}
```

**评论：** `Fst` 和 `Snd` 的 FV 和输入 term 的 FV 相同 — 因为 `fst t` 和 `snd t` 只包含一个子 term，没有 binder。`Ann` 的 FV 是两个子 term 的 FV 的并集（和 `Pair`、`App` 平行），没有 binder 遮蔽。
---
## 11. substitution
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

    if isinstance(t, Fst):
        t1 = t.args               # t = fst t1
        return Fst(subst(t1, x, e))

    if isinstance(t, Snd):
        t1 = t.args               # t = snd t1
        return Snd(subst(t1, x, e))

    if isinstance(t, Ann):
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
subst(fst (Var x), x, Const zero) = fst (Const zero)
subst(snd ⟨Var x, Var y⟩, x, Const zero) = snd ⟨Const zero, Var y⟩
subst((⟨Var x, Var y⟩ : Σ (z : Const Nat), Const Nat), x, Const zero)
= ⟨Const zero, Var y⟩ : Σ (z : Const Nat), Const Nat
```
---
## 12. 计算规则：`whnf`

加入 `Ann` 和 `Σ` 之后，模型能推断 `snd p_ann : (Const Pred) (fst p_ann)`，但 `fst p_ann` 作为一个 term 不能被"计算"成 `Const zero`。这个 gap 影响两个方面：

1. **term 层面**：我们有 `fst ⟨a, b⟩` 和 `snd ⟨a, b⟩` 的 elimination 规则，但没有对应的计算规则 — 无法让 `fst ⟨a, b⟩` 实际"变成" `a`。
2. **类型层面**：`infer_type` 中有时需要判断推断出的类型是否是 `Sort`/`Forall`/`Sigma`。如果类型头部是一个全局定义（如 `def T := Π (x : Nat), Nat`），那 `infer_type` 会得到 `Const T`，直接 `isinstance(Const T, Forall)` 会失败。

`whnf`（weak head normal form）同时解决这两个问题：

```text
whnf(S, t) -> Term
```

它只在 term 的**头部**进行必要的化简 — 不递归进入 body、参数等子结构。"weak" 指不深入内部，"head" 指只处理最外层的 redex。

**评论：** 为什么不直接加入完整的 normalization 或 definitional equality？因为 definitional equality 依赖 whnf — `defeq(S, Γ, A, B)` 的标准实现是把 A 和 B 都 whnf 后比较头部，再递归比较子项。所以 whnf 是 conversion 的基础构件，先加它是最自然的顺序。

### whnf 的核心直觉

一句话：**从外往里，一层一层剥**。

```
whnf(S, fst (⟨a, b⟩ : Σ (x : A), B))
```

第一步看到 `fst`，需要先知道它的参数是什么：

```
→ 先算 whnf(S, (⟨a, b⟩ : Σ (x : A), B))
```

第二步看到 `Ann`，计算时没意义，剥掉：

```
→ 变成 whnf(S, ⟨a, b⟩)
```

第三步看到 `Pair`，不是头部 redex，停了：

```
→ 返回 ⟨a, b⟩
```

回到 `fst`：现在知道参数是 `⟨a, b⟩` 了，取出第一分量：

```
→ 返回 whnf(S, a)
```

如果 `a` 本身已经是最简形式（比如 `Const zero`），就停了。结果：`Const zero`。

整个过程就像**剥洋葱** — 从最外层开始，遇到能化简的就化简，化简不动就停。不会主动去化简 `a` 内部的子结构（比如如果 `a` 是一个 `App`，whnf 不会碰它，除非它出现在新的头部位置）。

### 12.1 Ann 擦除

`Ann` 是 elaboration-level 的标注，不是计算内容。化简时直接丢弃：

```text
whnf(S, (t : A)) = whnf(S, t)
```

```python
if isinstance(t, Ann):
    body, A = t.args
    return whnf(S, body)
```

**评论：** `Ann` 在类型检查时有意义（提供 expected type），但在计算时没有意义 — 它不影响 term 的值。所以 whnf 直接剥掉它。

### 12.2 Const 的 delta reduction

如果 `n` 是一个定义名（即 `n ∈ S.Defs`），则展开它的 body：

```text
whnf(S, Const n) = whnf(S, body)     当 S.Defs.get(n) = (A, body)
whnf(S, Const n) = Const n            当 n ∉ S.Defs（即 n 是 axiom）
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

### 12.3 App 的 beta reduction

如果函数部分 whnf 后是 lambda，则发生 beta reduction：

```text
whnf(S, f a) = whnf(S, body[x := a])    当 whnf(S, f) = fun (x : A) => body
whnf(S, f a) = App(whnf(S, f), a)       当 whnf(S, f) 不是 Lam
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

- Beta reduction 是 `(fun (x : A) => body) a ↦ body[x := a]`。注意这里不先化简参数 `a` — 这是 **weak head** reduction 的特点：只化简头部到足够暴露结构，不化简参数或 body 内部。
- 如果 `f` whnf 后不是 Lam（比如是一个 axiom，或另一个 App），则无法继续化简，返回 `App(f0, a)`。

### 12.4 Fst 的 pair 投影化简

如果被投影项 whnf 后是 pair，则取出第一分量：

```text
whnf(S, fst p) = whnf(S, a)             当 whnf(S, p) = ⟨a, b⟩
whnf(S, fst p) = Fst(whnf(S, p))        当 whnf(S, p) 不是 Pair
```

```python
if isinstance(t, Fst):
    p = t.args
    p0 = whnf(S, p)

    if isinstance(p0, Pair):
        a, b = p0.args
        return whnf(S, a)

    return Fst(p0)
```

### 12.5 Snd 的 pair 投影化简

如果被投影项 whnf 后是 pair，则取出第二分量：

```text
whnf(S, snd p) = whnf(S, b)             当 whnf(S, p) = ⟨a, b⟩
whnf(S, snd p) = Snd(whnf(S, p))        当 whnf(S, p) 不是 Pair
```

```python
if isinstance(t, Snd):
    p = t.args
    p0 = whnf(S, p)

    if isinstance(p0, Pair):
        a, b = p0.args
        return whnf(S, b)

    return Snd(p0)
```

### 12.6 其他情况

其他 term 已经是 whnf，不做进一步化简：

```python
return t
```

因此 `whnf` 不递归进入：

```text
Lam 的 body
Forall 的 A 和 B
Sigma 的 A 和 B
Pair 的两个分量
Sort
Var
```

除非这些 term 出现在需要被化简的头部位置（如 `App` 的函数部分、`Fst`/`Snd` 的被投影项）。

### 12.7 `whnf` 完整代码

```python
# 写作 whnf(S, t)
def whnf(S : State, t : Term) -> Term:
    '''
    把 t 化简到 weak head normal form。
    处理：Ann 擦除、delta 展开、beta reduction、fst/snd 投影化简。
    '''

    if isinstance(t, Ann):
        body, A = t.args
        return whnf(S, body)

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

    if isinstance(t, Fst):
        p = t.args
        p0 = whnf(S, p)

        if isinstance(p0, Pair):
            a, b = p0.args
            return whnf(S, a)

        return Fst(p0)

    if isinstance(t, Snd):
        p = t.args
        p0 = whnf(S, p)

        if isinstance(p0, Pair):
            a, b = p0.args
            return whnf(S, b)

        return Snd(p0)

    return t
```

---
## 13. 类型等价：`defeq`                                              【v5 新增】

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
defeq(S : State, Γ : Context, t1 : Term, t2 : Term) -> bool
```

写作 `defeq(S, Γ, t1, t2)`。含义是：在状态 `S` 和上下文 `Γ` 下，判断两个 term 是否 definitionally equal。

当前阶段，`defeq` 做三件事：

1. **先对两边做 `whnf`** — 暴露头部结构
2. **头部结构匹配则递归比较子项** — 比如 `App` 就递归比函数和参数
3. **binder 用 alpha-renaming** — `Π (x : Nat), x` 和 `Π (y : Nat), y` 应该相等

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

**Pair：** 递归比较两个分量。

```python
if isinstance(t1, Pair) and isinstance(t2, Pair):
    a1, b1 = t1.args
    a2, b2 = t2.args
    return defeq(S, Γ, a1, a2) and defeq(S, Γ, b1, b2)
```

**Fst / Snd：** 递归比较被投影项。

```python
if isinstance(t1, Fst) and isinstance(t2, Fst):
    return defeq(S, Γ, t1.args, t2.args)

if isinstance(t1, Snd) and isinstance(t2, Snd):
    return defeq(S, Γ, t1.args, t2.args)
```

### 13.3 Binder 情况（Lam / Forall / Sigma）

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

**评论：** 为什么需要 alpha-renaming？因为 `Π (x : Nat), x` 和 `Π (y : Nat), y` 只是 binder 名字不同，应该相等。做法是：取一个新名字 `z`，把两个 body 的 binder 都改成 `z`，然后在扩展上下文 `Γ, z : A` 下递归比较。这样 `x` 和 `y` 都变成了 `z`，body 就能正确比较了。

`Lam` 和 `Sigma` 的处理与 `Forall` 完全平行。

### 13.4 其他情况

如果两边 whnf 后的头部构造子不同（比如一边是 `App`，另一边是 `Sort`），返回 `False`。

**评论：** `Ann` 不需要特殊分支。因为 `defeq` 一开始就对两边做 `whnf`，而 `whnf` 会把头部的 `Ann` 剥掉。嵌套的 `Ann`（如 `App(Ann(f, T), x)`）在递归比较子项时也会被 `whnf` 处理。

### 13.5 `defeq` 完整代码

```python
# 写作 defeq(S, Γ, t1, t2)
def defeq(S : State, Γ : Context, t1 : Term, t2 : Term) -> bool:
    '''
    判断 t1 和 t2 是否 definitionally equal。
    处理：whnf + alpha-equivalence + 递归结构比较。
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

    if isinstance(t1, Sigma) and isinstance(t2, Sigma):
        x1, A1, B1 = t1.args
        x2, A2, B2 = t2.args
        if not defeq(S, Γ, A1, A2):
            return False
        z = fresh_local_name(FV(B1) ∪ FV(B2) ∪ FV(A1) ∪ FV(A2) ∪ {x1, x2})
        B1z = alpha_rename_binder(B1, x1, z)
        B2z = alpha_rename_binder(B2, x2, z)
        Γ1 = expand_context(Γ, z, A1)
        return defeq(S, Γ1, B1z, B2z)

    if isinstance(t1, Pair) and isinstance(t2, Pair):
        a1, b1 = t1.args
        a2, b2 = t2.args
        return defeq(S, Γ, a1, a2) and defeq(S, Γ, b1, b2)

    if isinstance(t1, Fst) and isinstance(t2, Fst):
        return defeq(S, Γ, t1.args, t2.args)

    if isinstance(t1, Snd) and isinstance(t2, Snd):
        return defeq(S, Γ, t1.args, t2.args)

    return False
```

---
## 14. `infer_type` 与 `check_type`
### 14.0 背景：为什么需要两个函数？

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
### 14.1 `infer_type` 的定义
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
### 14.2 `check_type` 的定义
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
### 14.3 代码
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
        x, A, body = t.args        # t = fun (x : A) => body


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
        f, a = t.args              # t = f a


        Tf = whnf(S, infer_type(S, Γ, f))
        if not isinstance(Tf, Forall):
            raise Error
        x, A, B = Tf.args          # Tf = Π (x : A), B


        if not check_type(S, Γ, a, A):
            raise Error


        return subst(B, x, a)


    elif isinstance(t, Sigma):
        x, A, B = t.args          # t = Σ (x : A), B


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


    elif isinstance(t, Pair):
        # ⟨a, b⟩ 没有目标类型，无法推断
        raise Error


    elif isinstance(t, Fst):
        t1 = t.args                # t = fst t1
        Tt1 = whnf(S, infer_type(S, Γ, t1))
        if not isinstance(Tt1, Sigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = Σ (x : A), B
        return A

    elif isinstance(t, Snd):
        t1 = t.args                # t = snd t1
        Tt1 = whnf(S, infer_type(S, Γ, t1))
        if not isinstance(Tt1, Sigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = Σ (x : A), B
        return subst(B, x, Fst(t1))

    elif isinstance(t, Ann):
        t1, A = t.args             # t = (t1 : A)
        TA = whnf(S, infer_type(S, Γ, A))
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
            A_whnf = whnf(S, A)
            if not isinstance(A_whnf, Sigma):
                return False
            a, b = t.args       # t = ⟨a, b⟩
            x, A1, B = A_whnf.args  # A = Σ (x : A1), B
            return (
                check_type(S, Γ, a, A1)
                and
                check_type(S, Γ, b, subst(B, x, a))
            )


        # 其他情况：先推断类型，再用 defeq 与目标类型比较          【v5 修改：v4 用 == 比较，v5 改为 defeq】
        return defeq(S, Γ, infer_type(S, Γ, t), A)


    except:
        return False
```
**评论：**
- `check_type` 从一个一行包装器变成了一个独立的推导机制。这是加入 `Pair` 带来的最关键的概念升级。
- 注意 `check_type` 内部**递归调用自己**：`check_type(S, Γ, a, A1)` 和 `check_type(S, Γ, b, subst(B, x, a))`。这意味着 `a` 或 `b` 本身也可以是 `Pair`，递归地需要 check 模式。
- `try/except` 包住整个函数体，确保内部任何 `raise Error`（来自 `infer_type` 或 `subst`）都被捕获并返回 `False`。
- 在 `App` 规则中，`infer_type` 已经调用了 `check_type` 来检查参数类型。所以 `infer` 和 `check` 是互相调用的，不是单方向的。
- `Fst` 和 `Snd` 在 `infer_type` 中直接处理 — 它们**可以推断类型**。因为给定 `t : Σ(x:A), B`，`fst t` 的类型一定是 `A`，`snd t` 的类型一定是 `B[x := fst t]`，不存在歧义。这与 `Pair` 不同。
- 注意 `snd` 的类型中出现了 `Fst(t1)` — 这是一个**未经化简的项**。`whnf` 可以化简它（如果 `t1` 是 pair 或 Ann 包装的 pair），但 `infer_type` 本身不做化简，它返回的类型中可能包含 `Fst(...)` 形式。`check_type` 通过 `defeq` 在比较时自动调用 `whnf` 来处理这种情况。
- `Ann` 的 infer 规则是：先检查 `A` 是 type（`infer_type(S, Γ, A)` 是 Sort），再检查 `t1` 可以拥有类型 `A`（`check_type(S, Γ, t1, A)`），如果都成功则返回 `A`。这正好实现了"把只能 check 的 term 变成可以 infer 的 term"。
- `Ann` 在 `check_type` 中不需要特殊处理 — 它能 infer，所以走默认的 `defeq(infer_type(...), A)` 即可。
- `infer_type` 在所有类型头部检查处使用了 `whnf` 展开。具体来说：`Forall`/`Sigma`/`Lam`/`Ann` 分支中检查 `TA : Sort` 和 `TB : Sort` 时、`App` 分支中检查 `Tf : Forall` 时、`Fst`/`Snd` 分支中检查 `Tt1 : Sigma` 时，都先用 `whnf` 展开推断出的类型。这确保了如果类型头部是一个全局定义（如 `def T := Π (x : Nat), Nat`），展开后能正确匹配到 `Forall` 等构造子。同样，`check_type` 的 `Pair` 分支中对目标类型也做了 `whnf` 展开。
- `check_type` 默认分支使用 `defeq` 而不是 `==`，即 `defeq(S, Γ, infer_type(S, Γ, t), A)`。这意味着推断出的类型和目标类型不再需要结构相同 — 只要经过 reduction、alpha-renaming 和递归比较后 definitionally equal，`check_type` 就通过。
---
## 15. 构建前置状态 `S`

为了后续展示 `whnf` / `defeq` 的例子，先构建一个共同的前置状态 `S`。

从空状态 `S0` 开始，依次执行：

```text
S1 = exec(S0, AxiomCmd Nat : Sort (level 0))
S2 = exec(S1, AxiomCmd zero : Const Nat)
S3 = exec(S2, AxiomCmd Pred : Π (x : Const Nat), Sort (level 0))
S  = exec(S3, AxiomCmd choosePred : Π (x : Const Nat), (Const Pred) (Var x))
```

最终得到的状态 `S`：

```text
S.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
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
S ; Γ ⊢ Const Nat        : Sort (level 0)
S ; Γ ⊢ Const zero       : Const Nat
S ; Γ ⊢ Const Pred       : Π (x : Const Nat), Sort (level 0)
S ; Γ ⊢ Const choosePred : Π (x : Const Nat), (Const Pred) (Var x)
S ; Γ ⊢ (Const Pred) (Const zero) : Sort (level 0)
S ; Γ ⊢ (Const choosePred) (Const zero) : (Const Pred) (Const zero)
```

**评论：** 后续 §18-§20 的所有例子都基于这个状态 `S`。需要时会在用到的地方临时扩展状态（如 §19.4 加入 `pair0`）。

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
## 17. 关于 bidirectional typing

加入 `Pair` 之后，我们的模型引入了一个重要的概念区分：**infer 模式** 与 **check 模式**。

### 17.1 哪些 term 可以 infer？

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
Ann(t, A)      → 显式标注类型 A，前提是 check_type(t, A) 成功
```

它们的共同特点是：**自身携带了足够的信息来确定类型**。

### 17.2 哪些 term 只能 check？

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

### 17.3 infer 和 check 的互相调用

两个函数不是单方向的，而是互相调用：

```text
infer_type 调用 check_type：
  - App 规则中，检查参数 a : A 时用 check_type

check_type 调用 infer_type：
  - 非 Pair 的 term，先 infer 再比较

check_type 调用 check_type：
  - Pair 规则中，递归检查子项
```

### 17.4 和 Lean 的关系

这个设计在 Lean 的真实实现中有直接的对应：

| 我们的模型                              | Lean 中的对应                                              |
| ---------------------------------- | ------------------------------------------------------ |
| `infer_type` 遇到 `Pair` raise Error | Lean elaborator 中 `⟨a, b⟩` 需要 expected type            |
| `check_type` 处理 `Pair`             | Lean elaborator 用 expected type 来 elaboration `⟨a, b⟩` |
| 构造子存储在环境中（尚未引入）                    | Lean kernel 中 `Sigma.mk` 的类型可从环境查到                     |

当前模型更接近 **Lean elaborator** 的行为。将来加入 inductive type 声明机制后，`Pair` 可能会变成全局可查的构造子，那时 `infer_type` 也能处理它。

### 17.5 `Ann` 填补的 gap

裸 `Pair` 不能 infer，但有三种方式绕过：

1. **通过 `Ann`**：`(⟨a, b⟩ : Σ(x:A), B)` 可以 infer 出 `Σ(x:A), B`。
2. **通过 `DefCmd`**：先把 pair 注册为全局定义 `p`，然后 `Const p` 可以 infer 出类型。
3. **将来通过 inductive type 声明**：`Sigma.mk` 的类型存储在环境中，kernel 可以 infer。

当前阶段，`Ann` 是最轻量的方式 — 不需要修改 `State`，不需要全局名字。

---
## 18. 关键 term：`p_ann`

本节目的：构建后续 §19、§20 中要用到的关键 term `p_ann`，并验证它推断出的类型。这是 `Σ / Pair / fst / snd / Ann` 的综合应用。

### 18.1 `p_ann` 的定义（文本缩写）

**文本缩写（非模型操作）：** 以下简记 `p_ann` 为：

```text
(⟨Const zero, (Const choosePred) (Const zero)⟩
  : Σ (x : Const Nat), (Const Pred) (Var x))
```

注意：`p_ann` 不是 `Term` 构造子，也不是 State 中的全局名字，只是本文档中的临时缩写。

### 18.2 `p_ann` 可以 infer 出类型

由 §9 的规则可推出（细节省略，关键步骤用注释标出）：

```text
-- Σ 类型的 formation（由 Sigma 规则）
S ; ∅ ⊢ Σ (x : Const Nat), (Const Pred) (Var x) : Sort (level 0)

-- Pair 的 introduction（由 Pair 规则；两个子项分别 check）
S ; ∅ ⊢ Const zero : Const Nat                                    (Const-axiom)
S ; ∅ ⊢ (Const choosePred) (Const zero) : (Const Pred) (Const zero)  (App)
S ; ∅ ⊢ ⟨Const zero, (Const choosePred) (Const zero)⟩
      : Σ (x : Const Nat), (Const Pred) (Var x)                    (Pair)

-- Ann 包装后可以 infer
infer_type(S, ∅, p_ann) = Σ (x : Const Nat), (Const Pred) (Var x)
```

**评论：** `Ann` 的核心作用 — 把只能 check 的裸 `Pair` 包装成可以 infer 的 term。

### 18.3 `fst p_ann` 与 `snd p_ann` 的类型

由 `Fst` 和 `Snd` 规则：

```text
infer_type(S, ∅, fst p_ann) = Const Nat
infer_type(S, ∅, snd p_ann) = (Const Pred) (fst p_ann)
```

**评论（重要）：** 注意 `snd p_ann` 的类型是 `(Const Pred) (fst p_ann)`，**不是** `(Const Pred) (Const zero)` — 类型中包含未化简的 `fst p_ann`。在 v5 之前，这导致 `check_type(S, ∅, snd p_ann, (Const Pred) (Const zero))` 失败；v5 的 `defeq` 通过 `whnf` 把 `fst p_ann` 化简为 `Const zero`，从而让这个 check 通过（详见 §20）。

---

## 19. `whnf` 例子

### 19.1 beta reduction

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）：

```text
S.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
}
S.Defs = {}
```

**计算 `whnf`**

考虑 term：

```text
(fun (x : Const Nat) => Var x) (Const zero)
```

计算：

```text
whnf(S, (fun (x : Const Nat) => Var x) (Const zero))
```

**推导过程：**

1. `t = App(Lam(x, Const Nat, Var x), Const zero)`，匹配 `App` 分支。
2. 先化简函数部分：

```text
whnf(S, fun (x : Const Nat) => Var x) = fun (x : Const Nat) => Var x
```

`Lam` 不是任何 whnf 规则的头部 redex，直接返回 (§12.6)。

3. `f0 = Lam(x, Const Nat, Var x)`，是 `Lam`，触发 beta reduction (§12.3)：

```text
whnf(S, subst(Var x, x, Const zero))
= whnf(S, Const zero)
```

4. `Const zero`：`zero` 不在 `S.Defs` 中（是 axiom），所以 (§12.2)：

```text
whnf(S, Const zero) = Const zero
```

**结论：**

```text
whnf(S, (fun (x : Const Nat) => Var x) (Const zero)) = Const zero
```

### 19.2 `fst` 作用在 Ann 包装的 pair 上

**前置状态**

同 §19.1，状态 `S`。

**计算 `whnf`**

文本缩写（非模型操作）：令 `p_ann` 表示 `(⟨Const zero, (Const choosePred) (Const zero)⟩ : Σ (x : Const Nat), (Const Pred) (Var x))`。

考虑 term：

```text
fst p_ann
```

计算：

```text
whnf(S, fst p_ann)
```

**推导过程：**

1. `t = Fst(p_ann)`，匹配 `Fst` 分支 (§12.4)。
2. 先化简被投影项 `p_ann`：

`p_ann` 的头部是 `Ann`，匹配 `Ann` 分支 (§12.1)：

```text
whnf(S, p_ann) = whnf(S, ⟨Const zero, (Const choosePred) (Const zero)⟩)
```

`Pair` 不是任何 whnf 规则的头部 redex，直接返回 (§12.6)：

```text
whnf(S, p_ann) = ⟨Const zero, (Const choosePred) (Const zero)⟩
```

3. `p0 = Pair(Const zero, (Const choosePred) (Const zero))`，是 `Pair`，触发 fst 投影化简 (§12.4)：

```text
whnf(S, Const zero) = Const zero
```

**结论：**

```text
whnf(S, fst p_ann) = Const zero
```

### 19.3 `snd` 作用在 Ann 包装的 pair 上

**前置状态**

同 §19.1，状态 `S`。

**计算 `whnf`**

考虑 term：

```text
snd p_ann
```

**推导过程：**

1. `t = Snd(p_ann)`，匹配 `Snd` 分支 (§12.5)。
2. 先化简被投影项 `p_ann`（同 §19.2 第 2 步）：

```text
whnf(S, p_ann) = ⟨Const zero, (Const choosePred) (Const zero)⟩
```

3. `p0 = Pair(...)`，是 `Pair`，触发 snd 投影化简 (§12.5)：

```text
whnf(S, (Const choosePred) (Const zero))
```

4. `(Const choosePred) (Const zero)` 是 `App`，先化简函数部分：

```text
whnf(S, Const choosePred) = Const choosePred
```

`choosePred` 是 axiom（不在 `S.Defs` 中），不能展开为 Lam。beta reduction 不触发 (§12.3)。

**结论：**

```text
whnf(S, snd p_ann) = (Const choosePred) (Const zero)
```

### 19.4 `fst` / `snd` 作用在全局定义上

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
  (Σ (x : Const Nat), (Const Pred) (Var x))
  ⟨Const zero, (Const choosePred) (Const zero)⟩)
```

执行后：

```text
S'.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
}
S'.Defs = {
  pair0 : (Σ (x : Const Nat), (Const Pred) (Var x),
           ⟨Const zero, (Const choosePred) (Const zero)⟩)
}
```

### 计算 `whnf(S', fst (Const pair0))`

**推导过程：**

1. `t = Fst(Const pair0)`，匹配 `Fst` 分支 (§12.4)。
2. `pair0 ∈ S'.Defs`，触发 delta reduction (§12.2)：

```text
whnf(S', Const pair0) = whnf(S', ⟨Const zero, (Const choosePred) (Const zero)⟩)
                       = ⟨Const zero, (Const choosePred) (Const zero)⟩
```

3. `p0 = Pair(...)`，触发 fst 投影化简 (§12.4)：

```text
whnf(S', Const zero) = Const zero
```

**结论：** `whnf(S', fst (Const pair0)) = Const zero`

同理 `whnf(S', snd (Const pair0)) = (Const choosePred) (Const zero)`

---

## 20. `defeq` 例子                                                  【v5 新增】

### 20.1 `snd p_ann` 现在可以通过 `check_type`

**前置状态**

沿用之前的状态 `S`（文本缩写，非模型操作）：

```text
S.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
}
S.Defs = {}
```

文本缩写（非模型操作）：令 `p_ann` 表示 `(⟨Const zero, (Const choosePred) (Const zero)⟩ : Σ (x : Const Nat), (Const Pred) (Var x))`。

**只用结构相等的情形**

由 `Snd` 规则：

```text
infer_type(S, ∅, snd p_ann) = (Const Pred) (fst p_ann)
```

如果尝试：

```text
check_type(S, ∅, snd p_ann, (Const Pred) (Const zero))
```

比较的是：

```text
(Const Pred) (fst p_ann) == (Const Pred) (Const zero)
```

结构不同 ✗

**使用 `defeq` 的情形**

需要证明：

```text
defeq(S, ∅, (Const Pred) (fst p_ann), (Const Pred) (Const zero)) = True
```

**推导过程：**

1. 两边先 `whnf`。`(Const Pred) (fst p_ann)` — `Pred` 是 axiom，whnf 后不变。`(Const Pred) (Const zero)` — 同理不变。

2. 两边都是 `App`（§13.2），递归比较函数部分和参数部分。

3. 函数部分：`defeq(S, ∅, Const Pred, Const Pred)`

   两边 whnf 后都是 `Const Pred`，比较名字 `Pred == Pred` ✓

4. 参数部分：`defeq(S, ∅, fst p_ann, Const zero)`

   先 whnf 左边：`whnf(S, fst p_ann) = Const zero`（§19.2 已证）

   两边 whnf 后都是 `Const zero`，`t1 == t2` ✓

5. 函数部分 ✓ 且参数部分 ✓，因此 `App` 整体 ✓。

**结论：**

```text
defeq(S, ∅, (Const Pred) (fst p_ann), (Const Pred) (Const zero)) = True
```

因此：

```text
check_type(S, ∅, snd p_ann, (Const Pred) (Const zero)) = True
```

**评论：** 类型比较开始承认计算结果 — `defeq` 通过 `whnf` 发现 `fst p_ann = Const zero`，从而让两个结构不同但语义相同的类型通过检查。

### 20.2 alpha-renaming

**证明**

```text
defeq(S, ∅,
  Π (x : Const Nat), (Const Pred) (Var x),
  Π (y : Const Nat), (Const Pred) (Var y)) = True
```

**推导过程：**

1. 两边先 `whnf`。`Forall` 不是头部 redex，不变。

2. 两边都是 `Forall`（§13.3），处理 binder：

   - 先比较 domain 类型：`defeq(S, ∅, Const Nat, Const Nat) = True` ✓
   - 取新名字 `z`（不在 `FV(B1) ∪ FV(B2) ∪ ...` 中）
   - 左边 body `(Const Pred) (Var x)` 改名为 `(Const Pred) (Var z)`
   - 右边 body `(Const Pred) (Var y)` 改名为 `(Const Pred) (Var z)`
   - 在扩展上下文 `∅, z : Const Nat` 下递归比较

3. 递归比较 `(Const Pred) (Var z)` 和 `(Const Pred) (Var z)`：

   两边都是 `App`。函数部分 `Const Pred` vs `Const Pred` ✓。参数部分 `Var z` vs `Var z` ✓。

**结论：** `defeq` 返回 `True`。

**评论：** 如果只看结构相等，`Π (x : Nat), ...` 和 `Π (y : Nat), ...` 不同 — binder 名字不同。`defeq` 通过 alpha-renaming 把两边统一成 `z`，使比较正确进行。

### 20.3 `fst` / `snd` 作用在全局定义上的 `defeq`

**前置状态**

沿用 §19.4 的状态 `S'`（`pair0` 已注册为全局定义，文本缩写，非模型操作）。

**证明**

```text
check_type(S', ∅, snd (Const pair0), (Const Pred) (Const zero)) = True
```

**推导过程：**

1. 先推断类型：

```text
infer_type(S', ∅, snd (Const pair0)) = (Const Pred) (fst (Const pair0))
```

2. `check_type` 调用：

```text
defeq(S', ∅, (Const Pred) (fst (Const pair0)), (Const Pred) (Const zero))
```

3. 两边都是 `App`，递归比较：

   - 函数部分：`Const Pred` vs `Const Pred` ✓
   - 参数部分：`defeq(S', ∅, fst (Const pair0), Const zero)`

4. 参数部分的比较：

   先 whnf 左边：`whnf(S', fst (Const pair0)) = Const zero`（§19.4 已证：delta 展开 `pair0` → `Pair` → fst 取第一分量 → `Const zero`）

   两边 whnf 后都是 `Const zero` ✓

**结论：**

```text
check_type(S', ∅, snd (Const pair0), (Const Pred) (Const zero)) = True
```

**评论：** 注意这里 `defeq` 做了什么 — 它在比较参数部分时调用了 `whnf`，而 `whnf` 做了 delta 展开（`Const pair0` → body → `Pair`）和 fst 投影化简（`fst Pair(a, b)` → `a`）。

---

## 21. `defeq` 的关键限制                                          【v5 新增】

`defeq` 不处理以下情况：

**eta 规则：** `fun (x : A) => f x` 和 `f`（当 `x ∉ FV(f)` 时）在 Lean 中是 definitionally equal，但当前 `defeq` 不承认这一点。要支持 eta，需要在 `Lam` 分支中加入额外的检查。

**Proof irrelevance：** 两个不同的 proof of the same proposition 在 Lean 中是 equal 的，但当前模型不区分 `Prop` 和 `Type`。

**Universe constraints：** Lean 中 `Sort u` 和 `Sort v` 可能因为 universe polymorphism 而相等，但当前模型的 `Level` 只是自然数，不支持 universe metavariable。

**Reducibility control：** 当前模型认为所有 `def` 都是透明的。Lean 中有 `reducible` / `semireducible` / `irreducible` / `opaque` 的区分。

这些留到后续版本。

---

## 22. 当前阶段的边界

当前阶段，模型包含：

```text
Term 构造子：Sort, Var, Const, App, Lam, Forall, Sigma, Pair, Fst, Snd, Ann

函数：FV, subst, exec, infer_type, check_type, whnf, defeq
```

类型系统特性：

```text
bidirectional typing（infer / check）
whnf（弱头部正规化）
definitional equality（alpha-renaming + reduction + 递归比较）
conversion-based checking（check_type 用 defeq 而非 ==）
```

计算规则：

```text
fst ⟨a, b⟩ ↦ a
snd ⟨a, b⟩ ↦ b
(fun x => t) a ↦ t[x := a]
Const defName ↦ body（delta 展开）
(t : A) ↦ t（Ann 擦除）
```

尚未加入：

```text
eta 规则
proof irrelevance
universe constraints / level metavariable
reducibility control（opaque / semireducible）
SurfaceTerm / CoreTerm 区分
de Bruijn index / fvar
inductive type 声明机制
```
