--------------------------------------------------------------------------------
-- |
-- Module      :  Data.Comp.Param
-- Copyright   :  (c) 2011 Tom Hvitved
-- License     :  BSD3
-- Maintainer  :  Tom Hvitved <hvitved@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- This module defines the infrastructure necessary to use compositional data
-- types for parametric recursive data types, i.e. higher-order abstract syntax
-- (HOAS). Examples of usage are provided below.
--
--------------------------------------------------------------------------------
module Data.Comp.Param (
  -- * Examples
  -- ** Pure Computations
  -- $ex1

  -- ** Monadic Computations
  -- $ex2

  -- ** Composing Term Homomorphisms and Algebras
  -- $ex3

  -- ** Lifting Term Homomorphisms to Products
  -- $ex4
    module Data.Comp.Param.Term
  , module Data.Comp.Param.Algebra
  , module Data.Comp.Param.Functor
  , module Data.Comp.Param.Sum
  , module Data.Comp.Param.Product
    ) where

import Data.Comp.Param.Term
import Data.Comp.Param.Algebra
import Data.Comp.Param.Functor
import Data.Comp.Param.Sum
import Data.Comp.Param.Product

{- $ex1
The example below illustrates how to use generalised compositional data types 
to implement a small expression language, with a sub language of values, and 
an evaluation function mapping expressions to values.

The following language extensions are
needed in order to run the example: @TemplateHaskell@, @TypeOperators@,
@MultiParamTypeClasses@, @FlexibleInstances@, @FlexibleContexts@,
@UndecidableInstances@, and @GADTs@. Moreover, in order to derive instances for
GADTs, version 7 of GHC is needed.

> import Data.Comp.Multi
> import Data.Comp.Multi.Show ()
> import Data.Comp.Derive
> 
> -- Signature for values and operators
> data Value e l where
>   Const  ::        Int -> Value e Int
>   Pair   :: e s -> e t -> Value e (s,t)
> data Op e l where
>   Add, Mult  :: e Int -> e Int   -> Op e Int
>   Fst        ::          e (s,t) -> Op e s
>   Snd        ::          e (s,t) -> Op e t
>
> -- Signature for the simple expression language
> type Sig = Op :+: Value
> 
> -- Derive boilerplate code using Template Haskell (GHC 7 needed)
> $(derive [instanceHFunctor, instanceHShowF, smartHConstructors] 
>          [''Value, ''Op])
> 
> -- Term evaluation algebra
> class Eval f v where
>   evalAlg :: Alg f (HTerm v)
> 
> instance (Eval f v, Eval g v) => Eval (f :+: g) v where
>   evalAlg (Inl x) = evalAlg x
>   evalAlg (Inr x) = evalAlg x
> 
> -- Lift the evaluation algebra to a catamorphism
> eval :: (HFunctor f, Eval f v) => Term f :-> Term v
> eval = cata evalAlg
> 
> instance (Value :<: v) => Eval Value v where
>   evalAlg = inject
> 
> instance (Value :<: v) => Eval Op v where
>   evalAlg (Add x y)  = iConst $ (projC x) + (projC y)
>   evalAlg (Mult x y) = iConst $ (projC x) * (projC y)
>   evalAlg (Fst x)    = fst $ projP x
>   evalAlg (Snd x)    = snd $ projP x
> 
> projC :: (Value :<: v) => Term v Int -> Int
> projC v = case project v of Just (Const n) -> n
> 
> projP :: (Value :<: v) => Term v (s,t) -> (Term v s, Term v t)
> projP v = case project v of Just (Pair x y) -> (x,y)
> 
> -- Example: evalEx = iConst 2
> evalEx :: Term Value Int
> evalEx = eval (iFst $ iPair (iConst 2) (iConst 1) :: Term Sig Int)
-}

{- $ex2
The example below illustrates how to use generalised compositional data types to
implement a small expression language, with a sub language of values, and a 
monadic evaluation function mapping expressions to values.

The following language
extensions are needed in order to run the example: @TemplateHaskell@,
@TypeOperators@, @MultiParamTypeClasses@, @FlexibleInstances@,
@FlexibleContexts@, @UndecidableInstances@, and @GADTs@.  Moreover, in order to
derive instances for GADTs, version 7 of GHC is needed.

> import Data.Comp.Multi
> import Data.Comp.Multi.Show ()
> import Data.Comp.Derive
> import Control.Monad (liftM)
> 
> -- Signature for values and operators
> data Value e l where
>   Const  ::        Int -> Value e Int
>   Pair   :: e s -> e t -> Value e (s,t)
> data Op e l where
>   Add, Mult  :: e Int -> e Int   -> Op e Int
>   Fst        ::          e (s,t) -> Op e s
>   Snd        ::          e (s,t) -> Op e t
> 
> -- Signature for the simple expression language
> type Sig = Op :+: Value
> 
> -- Derive boilerplate code using Template Haskell (GHC 7 needed)
> $(derive [instanceHFunctor, instanceHTraversable, instanceHFoldable,
>           instanceHEqF, instanceHShowF, smartHConstructors]
>          [''Value, ''Op])
> 
> -- Monadic term evaluation algebra
> class EvalM f v where
>   evalAlgM :: AlgM Maybe f (Term v)
> 
> instance (EvalM f v, EvalM g v) => EvalM (f :+: g) v where
>   evalAlgM (Inl x) = evalAlgM x
>   evalAlgM (Inr x) = evalAlgM x
> 
> evalM :: (HTraversable f, EvalM f v) => Term f l
>                                      -> Maybe (Term v l)
> evalM = cataM evalAlgM
> 
> instance (Value :<: v) => EvalM Value v where
>   evalAlgM = return . inject
> 
> instance (Value :<: v) => EvalM Op v where
>   evalAlgM (Add x y)  = do n1 <- projC x
>                            n2 <- projC y
>                            return $ iConst $ n1 + n2
>   evalAlgM (Mult x y) = do n1 <- projC x
>                            n2 <- projC y
>                            return $ iConst $ n1 * n2
>   evalAlgM (Fst v)    = liftM fst $ projP v
>   evalAlgM (Snd v)    = liftM snd $ projP v
> 
> projC :: (Value :<: v) => Term v Int -> Maybe Int
> projC v = case project v of
>             Just (Const n) -> return n; _ -> Nothing
> 
> projP :: (Value :<: v) => Term v (a,b) -> Maybe (Term v a, Term v b)
> projP v = case project v of
>             Just (Pair x y) -> return (x,y); _ -> Nothing
> 
> -- Example: evalMEx = Just (iConst 5)
> evalMEx :: Maybe (Term Value Int)
> evalMEx = evalM ((iConst 1) `iAdd`
>                  (iConst 2 `iMult` iConst 2) :: Term Sig Int)
-}

{- $ex3
The example below illustrates how to compose a term homomorphism and an algebra,
exemplified via a desugaring term homomorphism and an evaluation algebra.

The following language extensions are needed in order to run the example:
@TemplateHaskell@, @TypeOperators@, @MultiParamTypeClasses@,
@FlexibleInstances@, @FlexibleContexts@, @UndecidableInstances@, and @GADTs@. 
Moreover, in order to derive instances for GADTs, version 7 of GHC is needed.

> import Data.Comp.Multi
> import Data.Comp.Multi.Show ()
> import Data.Comp.Derive
> 
> -- Signature for values, operators, and syntactic sugar
> data Value e l where
>   Const  ::        Int -> Value e Int
>   Pair   :: e s -> e t -> Value e (s,t)
> data Op e l where
>   Add, Mult  :: e Int -> e Int   -> Op e Int
>   Fst        ::          e (s,t) -> Op e s
>   Snd        ::          e (s,t) -> Op e t
> data Sugar e l where
>   Neg   :: e Int   -> Sugar e Int
>   Swap  :: e (s,t) -> Sugar e (t,s)
>
> -- Source position information (line number, column number)
> data Pos = Pos Int Int
>            deriving Show
> 
> -- Signature for the simple expression language
> type Sig = Op :+: Value
> type SigP = Op :&: Pos :+: Value :&: Pos
>
> -- Signature for the simple expression language, extended with syntactic sugar
> type Sig' = Sugar :+: Op :+: Value
> type SigP' = Sugar :&: Pos :+: Op :&: Pos :+: Value :&: Pos
> 
> -- Derive boilerplate code using Template Haskell (GHC 7 needed)
> $(derive [instanceHFunctor, instanceHTraversable, instanceHFoldable,
>           instanceHEqF, instanceHShowF, smartHConstructors]
>          [''Value, ''Op, ''Sugar])
> 
> -- Term homomorphism for desugaring of terms
> class (HFunctor f, HFunctor g) => Desugar f g where
>   desugHom :: TermHom f g
>   desugHom = desugHom' . hfmap Hole
>   desugHom' :: Alg f (Context g a)
>   desugHom' x = appCxt (desugHom x)
> 
> instance (Desugar f h, Desugar g h) => Desugar (f :+: g) h where
>   desugHom (Inl x) = desugHom x
>   desugHom (Inr x) = desugHom x
>   desugHom' (Inl x) = desugHom' x
>   desugHom' (Inr x) = desugHom' x
> 
> instance (Value :<: v, HFunctor v) => Desugar Value v where
>   desugHom = simpCxt . inj
> 
> instance (Op :<: v, HFunctor v) => Desugar Op v where
>   desugHom = simpCxt . inj
> 
> instance (Op :<: v, Value :<: v, HFunctor v) => Desugar Sugar v where
>   desugHom' (Neg x)  = iConst (-1) `iMult` x
>   desugHom' (Swap x) = iSnd x `iPair` iFst x
>
> -- Term evaluation algebra
> class Eval f v where
>   evalAlg :: Alg f (Term v)
> 
> instance (Eval f v, Eval g v) => Eval (f :+: g) v where
>   evalAlg (Inl x) = evalAlg x
>   evalAlg (Inr x) = evalAlg x
> 
> instance (Value :<: v) => Eval Value v where
>   evalAlg = inject
> 
> instance (Value :<: v) => Eval Op v where
>   evalAlg (Add x y)  = iConst $ (projC x) + (projC y)
>   evalAlg (Mult x y) = iConst $ (projC x) * (projC y)
>   evalAlg (Fst x)    = fst $ projP x
>   evalAlg (Snd x)    = snd $ projP x
>
> projC :: (Value :<: v) => Term v Int -> Int
> projC v = case project v of Just (Const n) -> n
>
> projP :: (Value :<: v) => HTerm v (s,t) -> (HTerm v s, HTerm v t)
> projP v = case project v of Just (Pair x y) -> (x,y)
>
> -- Compose the evaluation algebra and the desugaring homomorphism to an
> -- algebra
> eval :: Term Sig' :-> Term Value
> eval = cata (evalAlg `compAlg` (desugHom :: TermHom Sig' Sig))
> 
> -- Example: evalEx = iPair (iConst 2) (iConst 1)
> evalEx :: Term Value (Int,Int)
> evalEx = eval $ iSwap $ iPair (iConst 1) (iConst 2)
-}

{- $ex4
The example below illustrates how to lift a term homomorphism to products,
exemplified via a desugaring term homomorphism lifted to terms annotated with
source position information.

The following language extensions are needed in order to run the example:
@TemplateHaskell@, @TypeOperators@, @MultiParamTypeClasses@,
@FlexibleInstances@, @FlexibleContexts@, @UndecidableInstances@, and @GADTs@.
 Moreover, in order to derive instances for GADTs, version 7 of GHC is needed.

> import Data.Comp.Multi
> import Data.Comp.Multi.Show ()
> import Data.Comp.Derive
> 
> -- Signature for values, operators, and syntactic sugar
> data Value e l where
>   Const  ::        Int -> Value e Int
>   Pair   :: e s -> e t -> Value e (s,t)
> data Op e l where
>   Add, Mult  :: e Int -> e Int   -> Op e Int
>   Fst        ::          e (s,t) -> Op e s
>   Snd        ::          e (s,t) -> Op e t
> data Sugar e l where
>   Neg   :: e Int   -> Sugar e Int
>   Swap  :: e (s,t) -> Sugar e (t,s)
>
> -- Source position information (line number, column number)
> data Pos = Pos Int Int
>            deriving Show
> 
> -- Signature for the simple expression language
> type Sig = Op :+: Value
> type SigP = Op :&: Pos :+: Value :&: Pos
>
> -- Signature for the simple expression language, extended with syntactic sugar
> type Sig' = Sugar :+: Op :+: Value
> type SigP' = Sugar :&: Pos :+: Op :&: Pos :+: Value :&: Pos
> 
> -- Derive boilerplate code using Template Haskell (GHC 7 needed)
> $(derive [instanceHFunctor, instanceHTraversable, instanceHFoldable,
>           instanceHEqF, instanceHShowF, smartHConstructors]
>          [''Value, ''Op, ''Sugar])
> 
> -- Term homomorphism for desugaring of terms
> class (HFunctor f, HFunctor g) => Desugar f g where
>   desugHom :: TermHom f g
>   desugHom = desugHom' . hfmap Hole
>   desugHom' :: Alg f (Context g a)
>   desugHom' x = appCxt (desugHom x)
> 
> instance (Desugar f h, Desugar g h) => Desugar (f :+: g) h where
>   desugHom (Inl x) = desugHom x
>   desugHom (Inr x) = desugHom x
>   desugHom' (Inl x) = desugHom' x
>   desugHom' (Inr x) = desugHom' x
> 
> instance (Value :<: v, HFunctor v) => Desugar Value v where
>   desugHom = simpCxt . inj
> 
> instance (Op :<: v, HFunctor v) => Desugar Op v where
>   desugHom = simpCxt . inj
> 
> instance (Op :<: v, Value :<: v, HFunctor v) => Desugar Sugar v where
>   desugHom' (Neg x)  = iConst (-1) `iMult` x
>   desugHom' (Swap x) = iSnd x `iPair` iFst x
>
> -- Lift the desugaring term homomorphism to a catamorphism
> desug :: Term Sig' :-> Term Sig
> desug = appTermHom desugHom
>
> -- Example: desugEx = iPair (iConst 2) (iConst 1)
> desugEx :: Term Sig (Int,Int)
> desugEx = desug $ iSwap $ iPair (iConst 1) (iConst 2)
>
> -- Lift desugaring to terms annotated with source positions
> desugP :: Term SigP' :-> Term SigP
> desugP = appTermHom (productTermHom desugHom)
>
> iSwapP :: (DistProd f p f', Sugar :<: f) => p -> Term f' (a,b) -> Term f' (b,a)
> iSwapP p x = Term (injectP p $ inj $ Swap x)
>
> iConstP :: (DistProd f p f', Value :<: f) => p -> Int -> Term f' Int
> iConstP p x = Term (injectP p $ inj $ Const x)
>
> iPairP :: (DistProd f p f', Value :<: f) => p -> Term f' a -> Term f' b -> Term f' (a,b)
> iPairP p x y = Term (injectP p $ inj $ Pair x y)
>
> iFstP :: (DistProd f p f', Op :<: f) => p -> Term f' (a,b) -> Term f' a
> iFstP p x = Term (injectP p $ inj $ Fst x)
>
> iSndP :: (DistProd f p f', Op :<: f) => p -> Term f' (a,b) -> Term f' b
> iSndP p x = Term (injectP p $ inj $ Snd x)
>
> -- Example: desugPEx = iPairP (Pos 1 0)
> --                            (iSndP (Pos 1 0) (iPairP (Pos 1 1)
> --                                                     (iConstP (Pos 1 2) 1)
> --                                                     (iConstP (Pos 1 3) 2)))
> --                            (iFstP (Pos 1 0) (iPairP (Pos 1 1)
> --                                                     (iConstP (Pos 1 2) 1)
> --                                                     (iConstP (Pos 1 3) 2)))
> desugPEx :: Term SigP (Int,Int)
> desugPEx = desugP $ iSwapP (Pos 1 0) (iPairP (Pos 1 1) (iConstP (Pos 1 2) 1)
>                                                        (iConstP (Pos 1 3) 2))
-}

{- $ex5
The example below illustrates how to use Higher-Order Abstract Syntax (HOAS)
with generalised compositional data types.

The following language extensions are needed in order to run the example:
@TemplateHaskell@, @TypeOperators@, @MultiParamTypeClasses@,
@FlexibleInstances@, @FlexibleContexts@, @UndecidableInstances@, and @GADTs@.
Moreover, in order to derive instances for GADTs, version 7 of GHC is needed.

> import Data.Comp.Multi
> import Data.Comp.Derive
> 
> data Value e l where
>   Const  ::        Int -> Value e Int
>   Pair   :: e s -> e t -> Value e (s,t)
> data Op e l where
>   Add, Mult  :: e Int -> e Int   -> Op e Int
>   Fst        ::          e (s,t) -> Op e s
>   Snd        ::          e (s,t) -> Op e t
> data Lam e l where
>   Lam :: (e l1 -> e l2) -> Lam e (l1 -> l2)
> data App e l where
>   App :: e (l1 -> l2) -> e l1 -> App e l2
>
> -- Signature for values
> type Val = Lam :++: Value
>
> -- Signature for expressions
> type Sig = App :++: Op :++: Val
> 
> -- Derive boilerplate code using Template Haskell (GHC 7 needed)
> $(derive [instanceHExpFunctor, smartHConstructors] 
>          [''Value, ''Op, ''Lam, ''App])
> 
> -- Term evaluation algebra
> class Eval f v where
>   evalAlg :: HAlg f (HTerm v)
> 
> instance (Eval f v, Eval g v) => Eval (f :++: g) v where
>   evalAlg (HInl x) = evalAlg x
>   evalAlg (HInr x) = evalAlg x
> 
> -- Lift the evaluation algebra to a catamorphism
> evalE :: (HExpFunctor f, Eval f v) => HTerm f :-> HTerm v
> evalE = hcataE evalAlg
> 
> instance (Value :<<: v) => Eval Value v where
>   evalAlg = hinject
> 
> instance (Value :<<: v) => Eval Op v where
>   evalAlg (Add x y)  = iConst $ (projC x) + (projC y)
>   evalAlg (Mult x y) = iConst $ (projC x) * (projC y)
>   evalAlg (Fst x)    = fst $ projP x
>   evalAlg (Snd x)    = snd $ projP x
>
> instance (Lam :<<: v) => Eval Lam v where
>   evalAlg = hinject
>
> instance (Lam :<<: v) => Eval App v where
>   evalAlg (App x y) = (projL x) y
>
> projC :: (Value :<<: v) => HTerm v Int -> Int
> projC v = case hproject v of Just (Const n) -> n
> 
> projP :: (Value :<<: v) => HTerm v (s,t) -> (HTerm v s, HTerm v t)
> projP v = case hproject v of Just (Pair x y) -> (x,y)
>
> projL :: (Lam :<<: v) => HTerm v (l1 -> l2) -> HTerm v l1 -> HTerm v l2
> projL v = case hproject v of Just (Lam f) -> f
> 
> -- Example: evalEEx = iConst 3
> evalEEx :: HTerm Val Int
> evalEEx = evalE (((iLam $ \x -> x) `iApp`
>                   (iConst 1 `iAdd` iConst 2)) :: HTerm Sig Int)
-}