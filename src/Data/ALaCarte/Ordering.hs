{-# LANGUAGE TypeOperators, GADTs, TemplateHaskell #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  Data.ALaCarte.Ordering
-- Copyright   :  3gERP, 2010
-- License     :  AllRightsReserved
-- Maintainer  :  Tom Hvitved, Patrick Bahr, and Morten Ib Nielsen
-- Stability   :  unknown
-- Portability :  unknown
--
-- The ordering algebra (orderings on terms).
--
--------------------------------------------------------------------------------
module Data.ALaCarte.Ordering
    ( compList,
      deriveFunctorOrds,
      deriveFunctorOrd
    ) where

import Data.ALaCarte.Equality
import Data.ALaCarte
import Data.ALaCarte.Derive


import Data.Maybe
import Data.List
import Control.Monad
import Language.Haskell.TH hiding (Cxt)

{-|
  Functor type class that provides an 'Eq' instance for the corresponding
  term type class.
-}
class FunctorEq f => FunctorOrd f where
    compAlg :: Ord a => f a -> f a -> Ordering

instance (FunctorOrd f, Ord a)  => Ord (Cxt h f a) where
    compare = compAlg

{-|
  From an 'FunctorOrd' functor an 'Ord' instance of the corresponding
  term type can be derived.
-}
instance (FunctorOrd f) => FunctorOrd (Cxt h f) where
    compAlg (Term e1) (Term e2) = compAlg e1 e2
    compAlg (Hole h1) (Hole h2) = compare h1 h2
    compAlg Term{} Hole{} = LT
    compAlg Hole{} Term{} = GT

{-|
  'FunctorOrd' is propagated through sums.
-}

instance (FunctorOrd f, FunctorOrd g) => FunctorOrd (f :+: g) where
    compAlg (Inl _) (Inr _) = LT
    compAlg (Inr _) (Inl _) = GT
    compAlg (Inl x) (Inl y) = compAlg x y
    compAlg (Inr x) (Inr y) = compAlg x y
    
compList :: [Ordering] -> Ordering
compList = fromMaybe EQ . find (/= EQ)

deriveFunctorOrds :: [Name] -> Q [Dec]
deriveFunctorOrds = liftM concat . mapM deriveFunctorOrd

{-| This function generates an instance declaration of class
'FunctorEq' for a type constructor of any first-order kind taking at
least one argument. -}

deriveFunctorOrd :: Name -> Q [Dec]
deriveFunctorOrd fname = do
  TyConI (DataD _cxt name args constrs _deriving) <- abstractNewtypeQ $ reify fname
  let complType = foldl AppT (ConT name) (map (VarT . tyVarBndrName) (tail args))
      classType = AppT (ConT ''FunctorOrd) complType
  eqAlgDecl <- funD 'compAlg  (compAlgClauses constrs)
  return $ [InstanceD [] classType [eqAlgDecl]]
      where compAlgClauses [] = []
            compAlgClauses constrs = 
                let constrs' = map abstractConType constrs `zip` [1..]
                    constPairs = [(x,y)| x<-constrs', y <- constrs']
                in map genClause constPairs
            genClause ((c,n),(d,m))
                | n == m = genEqClause c
                | n < m = genLtClause c d
                | otherwise = genGtClause c d
            genEqClause (constr, n) = do 
              varNs <- newNames n "x"
              varNs' <- newNames n "y"
              let pat = ConP constr $ map VarP varNs
                  pat' = ConP constr $ map VarP varNs'
                  vars = map VarE varNs
                  vars' = map VarE varNs'
                  mkEq x y = let (x',y') = (return x,return y)
                             in [| compare $x' $y'|]
                  eqs = listE $ zipWith mkEq vars vars'
              body <- [|compList $eqs|]
              return $ Clause [pat, pat'] (NormalB body) []
            genLtClause (c, _) (d, _) = clause [recP c [], recP d []] (normalB [| LT |]) []
            genGtClause (c, _) (d, _) = clause [recP c [], recP d []] (normalB [| GT |]) []