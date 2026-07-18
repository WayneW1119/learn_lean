# model v0（整理版）

> 本文档是对当前版本模型的整理。
> 
> - 只保留**当前最新**的定义与记号。
> - 主要目标是统一格式、统一记号、增强可读性。
> - 在不改变核心内容的前提下，尽量多使用“写作”的格式。

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
- 后面的 `b`、`c` 是“写作”时使用的占位符。

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

- 对于各种类型、构造子应用、函数，都尽量给出“写作”的格式。

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
```

因此：

```text
可以取 wwr : GlobalName，则 Const wwr : Term
若 u : Level，则 Sort u : Term
若 x : LocalName，则 Var x : Term
```

以及：

```text
若 f, a : Term，则 f a : Term
若 x : LocalName, A : Term, t : Term，则 fun (x : A) => t : Term
若 x : LocalName, A : Term, B : Term，则 Π (x : A), B : Term
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

都 `: Term`。

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
```

### 10.1 例子

```text
FV(Const Nat) = ∅
FV(Sort (level 0)) = ∅
FV(Var x) = {x}
FV((Var x) (Var y)) = {x, y}
FV(fun (x : Sort (level 0)) => Var x) = ∅
FV(fun (x : Sort (level 0)) => (Var x) (Var y)) = {y}
FV(Π (x : Sort (level 0)), Var x) = ∅
```

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
```

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
应先把 binder `y` 改名为一个新名字 `z``，再替换，得到：

```text
fun (z : Sort (level 0)) => Var y
```

---

## 12. `infer_type` 与 `check_type`

当前阶段，为了更方便处理：

- `Π (x : A), B`
- `fun (x : A) => t`
- `f a`

我们先定义一个部分函数：

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
- 若 `t` 在 `S` 和 `Γ` 下可定型，则返回它的类型
- 若不可定型，则 `infer_type(S, Γ, t)` 不定义（代码中写作 `raise Error`）

然后定义：

```text
check_type(S, Γ, t, A)
```

其含义是：

- 先计算 `infer_type(S, Γ, t)`
- 再检查返回值是否与 `A` 结构相等

因此，在当前阶段：

```text
check_type(S, Γ, t, A) = True
```

当且仅当：

```text
infer_type(S, Γ, t) = A
```

这里的 `=` 指结构相等。  
当前阶段还不加入 conversion 规则，所以不会把 definitionally equal 但不完全相同的两个 type 视为相等。

### 12.1 代码

```python
# 写作 infer_type(S, Γ, t)
def infer_type(S: State, Γ: Context, t: Term) -> Term:
    '''
    在 S 和 Γ 下推导 t 的类型
    若无法推导，则 raise Error
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

    raise Error


# 写作 check_type(S, Γ, t, A)
def check_type(S: State, Γ: Context, t: Term, A: Term) -> bool:
    '''
    在 S 和 Γ 下检查 t : A
    当前阶段不加 conversion，
    因此这里只做结构相等比较
    '''
    try:
        return infer_type(S, Γ, t) == A
    except:
        return False
```

---

## 13. 一些有意义的例子

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

## 15. 当前阶段的边界

当前阶段，我们已经有：

- `Sort`
- `Π`
- `fun`
- `App`
- `FV`
- `subst`
- `infer_type`
- `check_type`

但当前阶段还**没有**加入：

```text
Sigma
Pair
fst
snd
conversion
definitional equality
reduction
```

因此当前模型还主要是一个最基础的、围绕依值函数构建的 kernel 雏形。

