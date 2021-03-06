module Common where

data Num a => Bundle a = B !a !a

instance (Num a, Show a) => Show (Bundle a) where
    show (B x x') = "(B " ++ (show x) ++ " " ++ (show x') ++ ")"

{-# INLINE lift #-}
lift :: Num a => a -> Bundle a
lift x = B x 0

instance (Num a) => Num (Bundle a) where
    fromInteger z       = lift (fromInteger z)
    (B x x') + (B y y') = B (x + y) (x' + y')
    (B x x') - (B y y') = B (x - y) (x' - y')
    (B x x') * (B y y') = B (x * y) (x * y' + x' * y)
    negate (B x x')     = B (negate x) (negate x')
    abs    (B x x')     = let s = signum x in B (s * x) (s * x')
    signum (B x _)      = lift (signum x)

instance Fractional a => Fractional (Bundle a) where
    recip (B x x') = let r = recip x in B r (- x' * r * r)
    fromRational z = lift (fromRational z)

instance (Num a, Eq a) => Eq (Bundle a) where
    (B x _) == (B y _) = (x == y)

instance (Num a, Ord a) => Ord (Bundle a) where
    (B x _) `compare` (B y _) = x `compare` y

instance Floating a => Floating (Bundle a) where
    pi             = lift pi
    exp   (B x x') = B (exp x)   (x' * exp x)
    log   (B x x') = B (log x)   (x' / x)
    sqrt  (B x x') = let y = sqrt x in B y (x' / (2 * y))
    sin   (B x x') = B (sin x)   (x' * (cos x))
    cos   (B x x') = B (cos x)   (x' * (- sin x))
    sinh  (B x x') = B (sinh x)  (x' * cosh x)
    cosh  (B x x') = B (cosh x)  (x' * sinh x)
    asin  (B x x') = B (asin x)  (x' / sqrt (1 - sqr x))
    acos  (B x x') = B (acos x)  (negate x' / sqrt (1 - sqr x))
    atan  (B x x') = B (atan x)  (x' / (1 + sqr x))
    asinh (B x x') = B (asinh x) (x' / sqrt (1 + sqr x))
    acosh (B x x') = B (acosh x) (negate x' / sqrt (sqr x - 1))
    atanh (B x x') = B (atanh x) (x' / (1 - sqr x))

instance (Num a, Enum a) => Enum (Bundle a) where
    toEnum i         = lift (toEnum i)
    fromEnum (B i _) = fromEnum i
    succ             = (+ 1)
    pred             = (subtract 1)

instance (Num a, Ord a, Real a) => Real (Bundle a) where
    toRational (B x _) = toRational x

derivative :: Num a => (Bundle a -> Bundle a) -> a -> a
{-# SPECIALIZE derivative :: (Bundle Double -> Bundle Double) -> Double -> Double #-}
{-# SPECIALIZE derivative :: (Bundle (Bundle Double) -> Bundle (Bundle Double))
                          -> (Bundle Double) -> (Bundle Double) #-}
derivative f x = let (B _ y') = f (B x 1) in y'

sqr x = x * x

vplus :: Num a => [a] -> [a] -> [a]
vplus = zipWith (+)

vminus :: Num a => [a] -> [a] -> [a]
vminus = zipWith (-)

ktimesv :: Num a => a -> [a] -> [a]
ktimesv k = map (k *)

magnitude_squared :: Num a => [a] -> a
magnitude_squared x = sum (map sqr x)

magnitude :: Floating a => [a] -> a
magnitude = sqrt . magnitude_squared

distance_squared :: Num a => [a] -> [a] -> a
distance_squared u v = magnitude_squared (vminus u v)

distance :: Floating a => [a] -> [a] -> a
distance u v = sqrt (distance_squared u v)

replace_ith :: [a] -> Int -> a -> [a]
replace_ith (x : xs) 0 xi = (xi : xs)
replace_ith (x : xs) i xi = (x : (replace_ith xs (i-1) xi))

gradient :: Num a => ([Bundle a] -> Bundle a) -> [a] -> [a]
{-# SPECIALIZE gradient :: ([Bundle Double] -> Bundle Double) -> [Double] -> [Double] #-}
{-# SPECIALIZE gradient :: ([Bundle (Bundle Double)] -> Bundle (Bundle Double))
                        -> [Bundle Double] -> [Bundle Double] #-}
gradient f x =
    map (\ i -> derivative
                (\ xi -> f (replace_ith (map lift x) i xi)) (x !! i))
        [0 .. (length x) - 1]


lower_fs :: Num a => ([Bundle a] -> Bundle a) -> [a] -> a
{-# SPECIALIZE lower_fs :: ([Bundle Double] -> Bundle Double) -> [Double] -> Double #-}
{-# SPECIALIZE lower_fs :: ([Bundle (Bundle Double)] -> Bundle (Bundle Double))
                        -> [Bundle Double] -> (Bundle Double) #-}
lower_fs f xs = let (B y _) = f (map lift xs) in y

multivariate_argmin :: (Floating a, Ord a) =>
                       ([Bundle a] -> Bundle a) -> [a] -> [a]
{-# SPECIALIZE multivariate_argmin :: ([Bundle Double] -> Bundle Double) -> [Double] -> [Double] #-}
{-# SPECIALIZE multivariate_argmin :: ([Bundle (Bundle Double)] -> Bundle (Bundle Double))
                                   -> [Bundle Double] -> [Bundle Double] #-}
multivariate_argmin f x =
    let g = gradient f
        ff = lower_fs f
        loop x fx gx eta i =
            if (magnitude gx) <= 1e-5
            then x
            else if i == 10
                 then loop x fx gx (2 * eta) 0
                 else let x_prime = vminus x (ktimesv eta gx)
                      in if (distance x x_prime) <= 1e-5
                         then x
                         else let fx_prime = ff x_prime
                              in if fx_prime < fx
                                 then
                                 loop
                                 x_prime fx_prime (g x_prime) eta       (i + 1)
                                 else
                                 loop
                                 x       fx       gx          (eta / 2) 0
    in loop x (ff x) (g x) 1e-5 0

multivariate_argmax :: (Floating a, Ord a) =>
                       ([Bundle a] -> Bundle a) -> [a] -> [a]
{-# SPECIALIZE multivariate_argmax :: ([Bundle Double] -> Bundle Double) -> [Double] -> [Double] #-}
{-# SPECIALIZE multivariate_argmax :: ([Bundle (Bundle Double)] -> Bundle (Bundle Double))
                                   -> [Bundle Double] -> [Bundle Double] #-}
multivariate_argmax f x = multivariate_argmin (negate . f) x

multivariate_max :: (Floating a, Ord a) =>
                    ([Bundle a] -> Bundle a) -> [a] -> a
{-# SPECIALIZE multivariate_max :: ([Bundle Double] -> Bundle Double) -> [Double] -> Double #-}
{-# SPECIALiZE multivariate_max :: ([Bundle (Bundle Double)] -> Bundle (Bundle Double))
                                -> [Bundle Double] -> Bundle Double #-}
multivariate_max f x = (lower_fs f) (multivariate_argmax f x)
