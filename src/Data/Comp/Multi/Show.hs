{-# LANGUAGE TypeOperators, GADTs, FlexibleContexts,
  ScopedTypeVariables, UndecidableInstances, FlexibleInstances,
  TemplateHaskell #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  Data.Comp.Multi.Show
-- Copyright   :  (c) 2011 Patrick Bahr
-- License     :  BSD3
-- Maintainer  :  Patrick Bahr <paba@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- This module defines showing of (higher-order) signatures, which lifts to
-- showing of (higher-order) terms and contexts. All definitions are
-- generalised versions of those in "Data.Comp.Show".
--
--------------------------------------------------------------------------------

module Data.Comp.Multi.Show
    ( ShowHF(..)
    ) where

import Data.Comp.Multi.Term
import Data.Comp.Multi.Annotation
import Data.Comp.Multi.Algebra
import Data.Comp.Multi.Functor
import Data.Comp.Multi.Derive

instance KShow (K String) where
    kshow = id

instance (ShowHF f, HFunctor f) => ShowHF (Cxt h f) where
    showHF (Hole s) = s
    showHF (Term t) = showHF $ hfmap showHF t

instance (ShowHF f, HFunctor f, KShow a) => KShow (Cxt h f a) where
    kshow = free showHF kshow

instance (KShow f) => Show (f i) where
    show = unK . kshow

instance (ShowHF f, Show p) => ShowHF (f :&: p) where
    showHF (v :&: p) =  K $ unK (showHF v) ++ " :&: " ++ show p

$(derive [liftSum] [''ShowHF])