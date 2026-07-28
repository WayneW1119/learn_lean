#eval 1 + 2

#check 1 + 2

def x : Nat := 5

#check x

#eval x

def double (n:Nat) : Nat := n + n

#eval double x

#check double

#check double x

#check fun n : Nat => n + n

def double2 := fun x : Nat => x + x

#check double2

#check (x : Nat) → Nat

#check (x : Nat) → x = x

#check Nat

#check Prop

#check (1 : Nat)

axiom n : A

axiom myNat : Type
axiom myZero : myNat
axiom myPred : myNat → Type

#check myPred myZero

axiom myChoosePred : (x : myNat) → myPred x

#check myChoosePred

#check myChoosePred myZero

#check fun (x : myNat) => x

#check fun (x : myNat) => myChoosePred x

def myId : myNat → myNat := fun x => x

#check myId

#check Sigma

#check Σ (x : myNat), myPred x

#check (⟨myZero, myChoosePred myZero⟩ : Σ (x : myNat), myPred x)

#check Sigma.fst (⟨myZero, myChoosePred myZero⟩ : Σ (x : myNat), myPred x)

#check Sigma.snd (⟨myZero, myChoosePred myZero⟩ : Σ (x : myNat), myPred x)

structure Point (X : Type) where
  x : X
  y : X

#check Point

#check Point.mk

noncomputable def p : Point myNat := Point.mk (X := myNat) myZero myZero

#check p.x

#check Point.x p
