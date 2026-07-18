# model v4

> 本文档在 v3 基础上扩展。
>
> **相对于 v3 的变化：**
>
> - §18：新增 `whnf` 动机说明
> - §19：新增 `whnf` 函数定义（Ann 擦除、delta、beta、fst/snd 投影化简）
> - §20：新增 `whnf` 完整代码
> - §12 `infer_type`：在类型头部检查前加入 `whnf` 展开
> - §21：说明 `check_type` 仍使用结构相等
> - §22-25：新增 `whnf` 综合例子
> - §26：更新边界说明
>
> **重要说明：** v4 只加入 `whnf`（reduction），暂不加入 definitional equality / conversion。v4 中 `check_type` 的类型比较仍然使用结构相等（`==`）。v5 再加入 `defeq` 并替换 `check_type` 中的 `==`。
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
- 这条规则在 `HasType` 层面是完整的，但它在 `infer_type` 和 `check_type` 中的处理方式不同 — 详见 §12 和 §15。

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
## 12. `infer_type` 与 `check_type`                              
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


        TA = whnf(S, infer_type(S, Γ, A))                  # 【v4 修改】
        if not isinstance(TA, Sort):
            raise Error
        u = TA.args                # TA = Sort u


        Γ1 = expand_context(Γ, x, A)
        TB = whnf(S, infer_type(S, Γ1, B))                 # 【v4 修改】
        if not isinstance(TB, Sort):
            raise Error
        v = TB.args                # TB = Sort v


        return Sort(max_level(u, v))


    elif isinstance(t, Lam):
        x, A, body = t.args        # t = fun (x : A) => body


        TA = whnf(S, infer_type(S, Γ, A))                  # 【v4 修改】
        if not isinstance(TA, Sort):
            raise Error


        Γ1 = expand_context(Γ, x, A)
        B = infer_type(S, Γ1, body)


        TB = whnf(S, infer_type(S, Γ1, B))                 # 【v4 修改】
        if not isinstance(TB, Sort):
            raise Error


        return Forall(x, A, B)


    elif isinstance(t, App):
        f, a = t.args              # t = f a


        Tf = whnf(S, infer_type(S, Γ, f))                  # 【v4 修改】
        if not isinstance(Tf, Forall):
            raise Error
        x, A, B = Tf.args          # Tf = Π (x : A), B


        if not check_type(S, Γ, a, A):
            raise Error


        return subst(B, x, a)


    elif isinstance(t, Sigma):
        x, A, B = t.args          # t = Σ (x : A), B


        TA = whnf(S, infer_type(S, Γ, A))                  # 【v4 修改】
        if not isinstance(TA, Sort):
            raise Error
        u = TA.args                # TA = Sort u


        Γ1 = expand_context(Γ, x, A)
        TB = whnf(S, infer_type(S, Γ1, B))                 # 【v4 修改】
        if not isinstance(TB, Sort):
            raise Error
        v = TB.args                # TB = Sort v


        return Sort(max_level(u, v))


    elif isinstance(t, Pair):
        # ⟨a, b⟩ 没有目标类型，无法推断
        raise Error


    elif isinstance(t, Fst):
        t1 = t.args                # t = fst t1
        Tt1 = whnf(S, infer_type(S, Γ, t1))                # 【v4 修改】
        if not isinstance(Tt1, Sigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = Σ (x : A), B
        return A

    elif isinstance(t, Snd):
        t1 = t.args                # t = snd t1
        Tt1 = whnf(S, infer_type(S, Γ, t1))                # 【v4 修改】
        if not isinstance(Tt1, Sigma):
            raise Error
        x, A, B = Tt1.args         # Tt1 = Σ (x : A), B
        return subst(B, x, Fst(t1))

    elif isinstance(t, Ann):
        t1, A = t.args             # t = (t1 : A)
        TA = whnf(S, infer_type(S, Γ, A))                  # 【v4 修改】
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
            A_whnf = whnf(S, A)                            # 【v4 修改】
            if not isinstance(A_whnf, Sigma):
                return False
            a, b = t.args       # t = ⟨a, b⟩
            x, A1, B = A_whnf.args  # A = Σ (x : A1), B
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
- **【v4 新增】** v4 在 `infer_type` 的所有类型头部检查处加入了 `whnf` 展开。具体来说：`Forall`/`Sigma`/`Lam`/`Ann` 分支中检查 `TA : Sort` 和 `TB : Sort` 时、`App` 分支中检查 `Tf : Forall` 时、`Fst`/`Snd` 分支中检查 `Tt1 : Sigma` 时，都先用 `whnf` 展开推断出的类型。这确保了如果类型头部是一个全局定义（如 `def T := Π (x : Nat), Nat`），展开后能正确匹配到 `Forall` 等构造子。同样，`check_type` 的 `Pair` 分支中对目标类型也做了 `whnf` 展开。
- **【v4 新增】** 注意 `check_type` 的默认分支（`return infer_type(S, Γ, t) == A`）**没有**加 `whnf` 或 `defeq`。这意味着 `check_type` 仍然要求推断类型和目标类型结构相同。完整的类型比较（definitional equality）留到 v5。
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
## 15. 关于 bidirectional typing                                  
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
Ann(t, A)      → 显式标注类型 A，前提是 check_type(t, A) 成功  
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
---
## 16. `Σ / Pair / fst / snd / Ann` 综合例子                    

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

### 16.3 Ann：让裸 pair 可以被 infer                                

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

### 16.6 对比：Ann vs DefCmd                                       

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

## 17. 当前阶段的边界

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
whnf
```

以及：

```text
bidirectional typing（infer 模式 / check 模式）
whnf（弱头部正规化）
```

当前模型**新增了**计算规则：

```text
fst ⟨a, b⟩      ↦ a
snd ⟨a, b⟩      ↦ b
(fun x => t) a   ↦ t[x := a]
Const defName    ↦ body           （delta 展开）
(t : A)          ↦ t              （Ann 擦除）
```

并且 `infer_type` 在检查类型头部结构前会先做 `whnf` 展开。

但当前阶段还**没有**加入：

```text
definitional equality（defeq）
conversion（类型转换）
```

也就是说，`check_type` 的类型比较仍然使用结构相等（`==`）。虽然 `whnf(S, fst p_ann) = Const zero`，但 `check_type` 不会自动把 `(Const Pred) (fst p_ann)` 和 `(Const Pred) (Const zero)` 视为相同类型。这一步留到 v5 的 `defeq`。

---

## 18. 为什么先加 `whnf`                                                  【v4 新增】

v3 已经能推断 `snd p_ann : (Const Pred) (fst p_ann)`，但 `fst p_ann` 作为一个 term 不能被"计算"成 `Const zero`。这个 gap 影响两个方面：

1. **term 层面**：我们有 `fst ⟨a, b⟩` 和 `snd ⟨a, b⟩` 的 elimination 规则，但没有对应的计算规则 — 无法让 `fst ⟨a, b⟩` 实际"变成" `a`。
2. **类型层面**：`infer_type` 中有时需要判断推断出的类型是否是 `Sort`/`Forall`/`Sigma`。如果类型头部是一个全局定义（如 `def T := Π (x : Nat), Nat`），那 `infer_type` 会得到 `Const T`，直接 `isinstance(Const T, Forall)` 会失败。

`whnf`（weak head normal form）同时解决这两个问题：

```text
whnf(S, t) -> Term
```

它只在 term 的**头部**进行必要的化简 — 不递归进入 body、参数等子结构。"weak" 指不深入内部，"head" 指只处理最外层的 redex。

**评论：** 为什么不直接加入完整的 normalization 或 definitional equality？因为 definitional equality 依赖 whnf — `defeq(S, Γ, A, B)` 的标准实现是把 A 和 B 都 whnf 后比较头部，再递归比较子项。所以 whnf 是 conversion 的基础构件，先加它是最自然的顺序。

---

## 18.5 从 v3 到 v4：一个直觉性的过渡                                    【v4 新增】

### v3 留下的问题

回顾 v3 的 §16.5。我们有：

```text
snd p_ann : (Const Pred) (fst p_ann)
```

这个结论是正确的。但仔细看类型中的 `fst p_ann` — 我们**知道** `p_ann` 的第一分量是 `Const zero`（因为 `p_ann` 就是用 `Const zero` 构造的），类型系统却不知道。

问题出在哪里？`infer_type` 对 `snd` 的处理是机械的：

1. 推断 `p_ann` 的类型 → `Σ (x : Const Nat), (Const Pred) (Var x)`
2. 取出 `B = (Const Pred) (Var x)`
3. 做替换 `B[x := fst p_ann]` → `(Const Pred) (fst p_ann)`

第 3 步产生了 `fst p_ann`，然后就没有然后了。类型系统不知道 `fst p_ann` 可以"算出" `Const zero`，因为它没有计算规则。

### 缺的是什么？

缺的是一个直觉上很简单的想法：**有些 term 可以被"算"一下**。

具体来说，以下等式在数学上显然成立：

```text
fst ⟨a, b⟩ = a                    -- 取第一分量
snd ⟨a, b⟩ = b                    -- 取第二分量
(fun (x : A) => body) arg = body[x := arg]   -- 函数应用
Const defName = body               -- 展开定义（当 defName 有定义时）
(t : A) = t                        -- 去掉标注
```

v3 的模型认识 `fst`、`snd`、`App`、`Const`、`Ann` 这些构造子，也知道它们的**类型规则**（typing rules），但不知道它们的**计算规则**（computation rules）。

v4 要做的事就是：加入计算规则。

### 为什么是 whnf 而不是完整的 normalization？

"算一下"有不同程度的"算"：

- **最轻量**：只看最外层，化简到无法继续为止 — 这就是 **whnf**（weak head normal form）。
- **中量级**：递归化简所有子项 — 这是 **normalization**（nf），得到一个完全化简的 term。
- **重量级**：不仅化简，还在类型比较时使用化简结果 — 这是 **conversion** / **definitional equality**。

为什么 v4 只做最轻量的 whnf？

1. whnf 是后两者的基础。normalization = 对每个子项递归做 whnf。defeq = 把两边都 whnf 后比较。所以先实现 whnf，后面的自然就能搭上去。
2. whnf 保证了**终止性** — 它只处理头部 redex，不会无限展开（因为每次化简都在缩短 term 的头部结构）。
3. Lean 的 kernel 实际上也用 whnf 作为核心操作，不是用完整的 normalization。

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

### whnf 带来了什么，还没带来什么

**带来了：**

- `fst ⟨a, b⟩` 现在可以算出 `a`。
- `snd ⟨a, b⟩` 现在可以算出 `b`。
- `(fun x => t) arg` 现在可以算出 `t[x := arg]`。
- `Const defName` 现在可以展开成它的定义体。
- `infer_type` 在检查类型头部时，会先用 whnf 展开，确保不会被定义别名挡住。

**还没带来：**

- 类型比较仍然是结构相等。也就是说，`infer_type` 推出 `(Const Pred) (fst p_ann)`，目标是 `(Const Pred) (Const zero)`，即使 `whnf` 知道 `fst p_ann = Const zero`，`check_type` 也不会自动把两者视为相等。
- 要做到这一步，需要在类型比较中用 `defeq` 替换 `==`。这是 v5 的事。

**一句话总结 v4 的定位：项可以开始计算了，但类型比较还没有真正变成 Lean kernel 风格。**

---

## 19. `whnf` 的定义                                                      【v4 新增】

```text
whnf(S : State, t : Term) -> Term
```

写作 `whnf(S, t)`。它的作用是把 `t` 化简到 weak head normal form。

当前阶段处理 5 种头部 redex：

### 19.1 Ann 擦除

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

### 19.2 Const 的 delta reduction

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

- 当前模型认为所有 `def` 都是透明的（transparent），可以展开。将来如果要更接近 Lean，需要加入 reducibility 属性（`reducible` / `semireducible` / `irreducible` / `opaque`），控制哪些定义可以被展开。v4 暂不处理。
- 注意 axiom 不能展开 — 它没有 body。`Const Nat`、`Const zero` 等已经是 whnf。

### 19.3 App 的 beta reduction

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

### 19.4 Fst 的 pair 投影化简

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

### 19.5 Snd 的 pair 投影化简

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

### 19.6 其他情况

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

---

## 20. `whnf` 完整代码                                                    【v4 新增】

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

## 21. `check_type` 仍然使用结构相等                                      【v4 新增】

v4 加入 `whnf` 后，`check_type` 的默认分支仍然是：

```python
return infer_type(S, Γ, t) == A
```

也就是说，v4 **没有**把类型比较改成：

```python
defeq(S, Γ, infer_type(S, Γ, t), A)
```

这意味着：虽然 `whnf(S, fst p_ann) = Const zero`，但 `check_type` 不会自动把 `(Const Pred) (fst p_ann)` 和 `(Const Pred) (Const zero)` 视为相同类型。

在 v4 中，要让 `check_type` 成功，`infer_type` 的结果和目标类型必须**结构相同**。

这一步留到 v5 的 definitional equality / conversion。

---

## 22. 例子一：beta reduction                                             【v4 新增】

### 前置状态

沿用 v3 的状态 `S`：

```text
S.Axioms = {
  Nat        : Sort (level 0),
  zero       : Const Nat,
  Pred       : Π (x : Const Nat), Sort (level 0),
  choosePred : Π (x : Const Nat), (Const Pred) (Var x)
}
S.Defs = {}
```

### 计算 `whnf`

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

`Lam` 不是任何 whnf 规则的头部 redex，直接返回 (§19.6)。

3. `f0 = Lam(x, Const Nat, Var x)`，是 `Lam`，触发 beta reduction (§19.3)：

```text
whnf(S, subst(Var x, x, Const zero))
= whnf(S, Const zero)
```

4. `Const zero`：`zero` 不在 `S.Defs` 中（是 axiom），所以 (§19.2)：

```text
whnf(S, Const zero) = Const zero
```

**结论：**

```text
whnf(S, (fun (x : Const Nat) => Var x) (Const zero)) = Const zero
```

---

## 23. 例子二：`fst` 作用在 Ann 包装的 pair 上                           【v4 新增】

### 前置状态

同 §22，状态 `S`。

### 计算 `whnf`

简记 `p_ann = (⟨Const zero, (Const choosePred) (Const zero)⟩ : Σ (x : Const Nat), (Const Pred) (Var x))`。

考虑 term：

```text
fst p_ann
```

计算：

```text
whnf(S, fst p_ann)
```

**推导过程：**

1. `t = Fst(p_ann)`，匹配 `Fst` 分支 (§19.4)。
2. 先化简被投影项 `p_ann`：

```text
whnf(S, p_ann)
```

`p_ann = Ann(Pair(...), Sigma(...))`，匹配 `Ann` 分支 (§19.1)：

```text
whnf(S, p_ann) = whnf(S, ⟨Const zero, (Const choosePred) (Const zero)⟩)
```

`Pair` 不是任何 whnf 规则的头部 redex，直接返回 (§19.6)：

```text
whnf(S, p_ann) = ⟨Const zero, (Const choosePred) (Const zero)⟩
```

3. `p0 = Pair(Const zero, (Const choosePred) (Const zero))`，是 `Pair`，触发 fst 投影化简 (§19.4)：

```text
whnf(S, Const zero)
```

4. `Const zero`：`zero` 是 axiom，不在 `S.Defs` 中：

```text
whnf(S, Const zero) = Const zero
```

**结论：**

```text
whnf(S, fst p_ann) = Const zero
```

**评论：** 这就是 v3 中无法做到的事 — `fst ⟨a, b⟩` 现在可以化简为 `a`。Ann 先被擦除，然后 `fst` 看到 `Pair`，取出第一分量。

---

## 24. 例子三：`snd` 作用在 Ann 包装的 pair 上                           【v4 新增】

### 前置状态

同 §22，状态 `S`。

### 计算 `whnf`

考虑 term：

```text
snd p_ann
```

计算：

```text
whnf(S, snd p_ann)
```

**推导过程：**

1. `t = Snd(p_ann)`，匹配 `Snd` 分支 (§19.5)。
2. 先化简被投影项 `p_ann`（同 §23 第 2 步）：

```text
whnf(S, p_ann) = ⟨Const zero, (Const choosePred) (Const zero)⟩
```

3. `p0 = Pair(Const zero, (Const choosePred) (Const zero))`，是 `Pair`，触发 snd 投影化简 (§19.5)：

```text
whnf(S, (Const choosePred) (Const zero))
```

4. `(Const choosePred) (Const zero)` 是 `App`，先化简函数部分：

```text
whnf(S, Const choosePred) = Const choosePred
```

`choosePred` 是 axiom（不在 `S.Defs` 中），不能展开为 Lam。所以 `f0 = Const choosePred`，不是 `Lam`，beta reduction 不触发 (§19.3)。

**结论：**

```text
whnf(S, snd p_ann) = (Const choosePred) (Const zero)
```

**评论：** `snd p_ann` 成功化简为 `(Const choosePred) (Const zero)`。但注意这是 `snd` 的**值**，不是 `snd` 的**类型**。`snd p_ann` 的类型仍然是 `infer_type` 推出的 `(Const Pred) (fst p_ann)` — 要让类型也化简，需要 v5 的 conversion。

---

## 25. 例子四：`fst` / `snd` 作用在全局定义上                              【v4 新增】

### 前置状态

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

1. `t = Fst(Const pair0)`，匹配 `Fst` 分支 (§19.4)。
2. 先化简 `Const pair0`：

`pair0 ∈ S'.Defs`，触发 delta reduction (§19.2)：

```text
whnf(S', Const pair0) = whnf(S', ⟨Const zero, (Const choosePred) (Const zero)⟩)
```

`Pair` 直接返回 (§19.6)：

```text
whnf(S', Const pair0) = ⟨Const zero, (Const choosePred) (Const zero)⟩
```

3. `p0 = Pair(...)`，是 `Pair`，触发 fst 投影化简 (§19.4)：

```text
whnf(S', Const zero) = Const zero
```

**结论：**

```text
whnf(S', fst (Const pair0)) = Const zero
```

### 计算 `whnf(S', snd (Const pair0))`

同理，delta 展开 `pair0` 后得到 `Pair`，snd 取出第二分量：

```text
whnf(S', snd (Const pair0)) = whnf(S', (Const choosePred) (Const zero))
                             = (Const choosePred) (Const zero)
```

（最后一步和 §24 相同 — `choosePred` 是 axiom，不能继续展开。）

### 类型推导 vs 值计算

注意以下对比：

```text
-- 值（whnf 计算）
whnf(S', fst (Const pair0)) = Const zero
whnf(S', snd (Const pair0)) = (Const choosePred) (Const zero)

-- 类型（infer_type 推导）
infer_type(S', ∅, fst (Const pair0)) = Const Nat
infer_type(S', ∅, snd (Const pair0)) = (Const Pred) (fst (Const pair0))
```

`snd (Const pair0)` 的**值**已经化简到 `(Const choosePred) (Const zero)`，但它的**类型**仍然是 `(Const Pred) (fst (Const pair0))` — 包含未化简的 `fst (Const pair0)`。

要让类型也化简，需要 v5 在 `check_type` 中用 `defeq` 替换 `==`。
