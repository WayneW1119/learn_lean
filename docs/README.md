# Version Documents

每个版本文档的阅读指南。版本号越大越新，v11 是当前最新版本。

## 阅读顺序

如果你是从头开始了解这个模型，推荐按版本顺序阅读：

1. **[v0](lean_model_v0.md)** — 起点：最小依赖类型核。定义了 `Term`、`State`、`Context`、`infer_type`、`check_type`。

2. **[v1](lean_model_v1.md)** — 引入 Sigma（依赖乘积）和 Pair。bidirectional typing 升级。

3. **[v2](lean_model_v2.md)** — 引入 Fst 和 Snd（投影消除规则）。Sigma 类型体系完整。

4. **[v3](lean_model_v3.md)** — 引入 `Ann`（类型标注）。为 Surface/Core 分层做准备。

5. **[v4](lean_model_v4.md)** — 引入 `whnf`（弱头部正规化）。Ann 擦除、delta 展开、beta 化简。

6. **[v5](lean_model_v5.md)** — 引入 `defeq`（定义相等）。`check_type` 改用 defeq 而非结构相等。

7. **[v6](lean_model_v6.md)** — Surface/Core 分层。引入 `elab` 函数。Kernel 函数只作用于 CoreTerm。

8. **[v7](lean_model_v7.md)** — CoreTerm 去特殊化。引入 `Proj` 通用投影。Sigma 不再是 core 构造子。

9. **[v8](lean_model_v8.md)** — `StructureInfo` 完善（`ParamInfo` + `FieldInfo`）。`Proj` 的 whnf/infer 一般化。

10. **[v9](lean_model_v9.md)** — `StructureCmd`——用户通过命令声明结构。不再预置任何结构。

11. **[v10](lean_model_v10.md)** — `ProjectionInfo` + `SProj` + `SDot`。投影名和 dot notation。

12. **[v11](lean_model_v11.md)** — `InductiveCmd` + `Bool.rec` + iota reduction。最简单的 inductive 类型（nullary constructors）。当前最新。

## 关于版本差异标记

每个版本文档在头部列出了"相对于上一版本的变化"摘要，正文中用 `【v10 新增】` / `【v10 修改】` 标记新内容。阅读原则：**只看当前版本与上一版本的差异**。

## 关于例子

- 非当前版本的例子（非 v10 例子）只保留简要结论，去掉逐步推导。
- 当前版本的新增例子（如 v10 的 `SProj`、`SDot`、`ProjectionInfo`）保留详细推导。

## 约定速览

- `SurfaceTerm` 构造子以 `S` 为前缀（`SConst`、`SApp` 等）
- `CoreTerm` 构造子无前缀（`Const`、`App`、`Proj` 等）
- `写作 ...` 表示 term 的写法格式
- `State` / `Context` 用 `class` 风格，字段用 `S.field` 访问
- 函数用 Python 风格伪代码
- `S --cmd--> S'` 是 `exec(S, cmd) = S'` 的简写
