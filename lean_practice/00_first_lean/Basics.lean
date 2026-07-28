-- 两个减号是注释。`/- ... -/` 是多行注释。

-- #check 看类型，#eval 计算值
#check 42
#eval 1 + 2

-- def 定义一个东西
def x : Nat := 5
#eval x + 3

-- 定义一个函数
def double (n : Nat) : Nat := n + n
#eval double 3

-- theorem 声明一个命题，rfl 是最简单的证明（两边一样）
theorem one_plus_one : 1 + 1 = 2 := rfl
