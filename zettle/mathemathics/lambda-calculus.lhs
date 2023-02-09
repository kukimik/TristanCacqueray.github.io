# Lambda Calculus

> This document is a literate haskell file.

```haskell
{-# LANGUAGE LambdaCase #-}
module MyLambdaCalculus where
import Text.Parsec (char, eof, many1, runParser, satisfy, sepBy1, (<|>))

type Name = String
```

Lambda calculus consists of three terms:

```haskell
data Term =
    Var Name
  | Lam Name Term
  | App Term Term
  deriving (Show)
```

- `Var` (Variable) is a character or string representing a parameter or mathematical/logical value.
- `Lam` (Abstraction) is a function definition.
- `App` (Application) applying a function to an argument.

Instead of writting the term manually, we can parse the standard syntax:

```haskell
parse :: String -> Term
parse s = let Right term = runParser (termParser <* eof) () "lambda" s in term
  where
    termParser = reorderApp <$> (parensParser <|> lamParser <|> varParser) `sepBy1` char ' '
    parensParser = char '(' *> termParser <* char ')'
    lamParser = Lam <$> (char 'λ' *> varParser <* char '.' >>= \(Var name) -> pure name) <*> termParser
    varParser = Var <$> many1 (satisfy (not . flip elem "()λ. "))
    reorderApp (term : terms) = case terms of
      (x : xs) -> foldl App (App term x) xs
      [] -> term
```

## Church encoding

Boolean:

```haskell
true  = parse "λx.λy.x"
false = parse "λx.λy.y"

and'  = parse "λp.λq.p q p"
or'   = parse "λp.λq.p p q"
not'  = parse "λp.λa.λb.p b a"
```

Omega term can't be beta-reduced:

```haskell
omega = parse "(λx.x x) (λx.x x)"
```

Sum types, see [The visitor pattern is essentially the same thing as Church encoding](https://www.haskellforall.com/2021/01/the-visitor-pattern-is-essentially-same.html):

```haskell
circle    = parse "λradi.λc.λr.c radi"
rectangle = parse "λw.λh.λc.λr.r w h"
area = parse "λs.s (λradi.mul pi (sqrt radi)) (λw.λh.mul h w)"

example_circle = App circle (Var "10")
```

## Evaluation strategy

References:

- [Programming Language Foundations](http://homepage.cs.uiowa.edu/%7Eslonnegr/plf/Book/Chapter5.pdf)
- [Wikipedia](https://en.wikipedia.org/wiki/Evaluation_strategy)
- [Write You a Haskell (Stephen Diehl)](http://dev.stephendiehl.com/fun/005_evaluation.html#call-by-need)

### Applicative order

The argument to a function is evaluated before the function is applied:

- `(λx.λy.x y) ((λx.x) y) ((λx.x) x)`
- `(λx.λy.x y) y x`
- `y x`

Can also be refered to as `call by value`.

### Normal order

The argument to a function are substituted into the body before the function evaluation:

- `(λx.λy.x y) ((λx.x) y) ((λx.x) x)`
- `((λx.x) y) ((λx.x) x)`
- `y x`

`call by name` means the argument is left un-touched, and it may be evaluated multiple times if it is used more than once in the function body.
`call by need` means the argument is passed as a thunk, and it may evaluate once when used.

### Differences

- Applicative order is the most common, it can be refered to as `strict`. Though it prevents the implementation of custom control flow, e.g. `if` function needs a special case to by-pass then/else clause evaluation.
  Diverging argument like omega can't be used.
- Normal order does not need special case for control flow which can be implemented in the language. `call by value` can be refered to as `lazy`.

## Normal order example:

### Alpha conversion

Lambda term's variables may need to be renamed to avoid collision.
Multiple strategies exist, see [bound](https://www.schoolofhaskell.com/user/edwardk/bound),
and here is a naive implementation:

```haskell
-- | Convert conflicting variable name (based on code by Renzo Carbonara)
sub :: Name -> Term -> Term -> Term
sub name term = \case
  Var varName -> if name == varName then term else Var varName
  App t1 t2 -> App (convert t1) (convert t2)
  Lam varName body
    | -- varName shadows name
      name == varName ->
      Lam varName body
    | -- varName conflicts
      isFree varName term ->
      let newName = freshName "x" term
          newBody = sub varName (Var newName) body
       in Lam newName (convert newBody)
    | otherwise ->
      Lam varName (convert body)
  where
    convert = sub name term
    isFree n e = n `elem` freeVars e
    freeVars = \case
      Var n -> [n]
      App f x -> freeVars f <> freeVars x
      Lam n b -> filter (/= n) (freeVars b)
    freshName s e
      | isFree s e = freshName ('x' : s) e
      | otherwise = s
```

### Beta reduction

Lambda term's variables can be replaced on application:

```haskell
betaReduce :: Term -> Term
betaReduce = \case
  App t1 t2 -> case betaReduce t1 of
    Lam name body -> betaReduce (sub name t2 body)
    _ -> App t1 t2
  Lam name body -> Lam name (betaReduce body)
  term -> term

main = do
  putStrLn "True and !True are equivalent:"
  print $ betaReduce true
  print $ betaReduce (App not' false)
  putStrLn ""
  putStrLn "Area of a circle of radius 10:"
  print $ betaReduce (App area (App circle (Var "10")))
  putStrLn "Area of a rectangle of size 5x10:"
  print $ betaReduce (App area (App (App rectangle (Var "5")) (Var "10")))
```

> To evaluate the file:
> nix-shell -p ghcid -p "haskellPackages.ghcWithPackages (p: [p.markdown-unlit p.parsec])" --command 'ghcid --test=:main --command "ghci -pgmL markdown-unlit" lambda-calculus.lhs'

## hello world

Here is a demo in javascript:

```javascript
// "hello world" using pure lambda

// * Church numeral
// We encode number using the church numeral representation:
let zero  = f => x => x
let one   = f => x => f(x)
let two   = f => x => f(f(x))
let three = f => x => f(f(f(x)))

// Basic algebra:
let incr = x => f => s => f(x(f)(s))
let add = x => y => x(incr)(y)
let mul = x => y => f => x(y(f))
let exp = x => y => y(x)

// Numbers definition:
let four = incr(three)
let five = add(two)(three)
let seven = incr(mul(three)(two))
let eight = exp(two)(three)
let nine = exp(three)(two)
let eleven = incr(incr(nine))
let hundred = mul(exp(two)(two))(exp(five)(two))

// ASCII letters:
let H = mul(nine)(eight)
let e = incr(hundred)
let l = mul(four)(exp(three)(three))
let o = mul(three)(incr(mul(four)(nine)))
let spc = exp(two)(five)
let M = mul(seven)(eleven)
let C = incr(mul(two)(mul(three)(eleven)))

// * Sum type encoding (see: https://www.haskellforall.com/2021/01/the-visitor-pattern-is-essentially-same.html)
// A list is defined as either Nil, or Cons(a, List)
let nil = c => n => n
let cons = a => l => c => n => c(a)(l)

// * Text buffer
let mem = cons(H)(cons(e)(cons(l)(cons(l)(cons(o)(cons(spc)(cons(M)(cons(C)(cons(H)(nil)))))))))

// * Y-combinator
let Y = f => (x => f(z => x(x)(z))) (x => f(z => x(x)(z)))
// Let bindings are not recursive, thus we use a combinator to enable self reference
let map_rec = map => f => l => l(x => xs => cons(f(x))(map(f)(xs)))(nil)
let map = Y(map_rec)

// The entry point:
let main = decode_list => decode_value => decode_list(map(decode_value)(mem))
// The main function is defined in pure lambda calculus, using only:
// - `x`: Variable
// - `λx.x`: Abstraction
// - `x x`: Application
// In particular, the function doesn't uses any number or operator.
//
// Helpers to decode our lambda program:
let decode_list = acc => l => l(x => xs => decode_list(acc.concat([x]))(xs))(acc)
let decode_number = n => n(x => x + 1)(0)
console.log(String.fromCharCode(...main(decode_list([]))(decode_number)))
```

And using this script:

```python
# Make the final demo by applying let transformation
lines = open("lambda.js").readlines()
lets = [(e.split()[1], e.strip().split(" = ")[1]) for e in filter(lambda s: s.startswith("let "), lines)]

def desugar(xs):
    (k, v) = xs[0]
    if k == "main":
        return v
    return "(" + k + " => " + desugar(xs[1:]) + ")(" + v + ")"


print("let main = " + desugar(lets))
body = False
for line in lines:
    if body and line != "\n":
        print(line, end="")
    if line.startswith("let main"):
        body = True
```

We can craft this demo:

```javascript
let main = (zero => (one => (two => (three => (incr => (add => (mul => (exp => (four => (five => (seven =>
           (eight => (nine => (eleven => (hundred => (H => (e => (l => (o => (spc => (M => (C => (nil =>
           (cons => (mem => (Y => (map_rec => (map => decode_list => decode_value => decode_list(map(decode_value)(mem)))
           (Y(map_rec)))(map => f => l => l(x => xs => cons(f(x))(map(f)(xs)))(nil)))
           (f => (x => f(z => x(x)(z))) (x => f(z => x(x)(z)))))
           (cons(H)(cons(e)(cons(l)(cons(l)(cons(o)(cons(spc)(cons(M)(cons(C)(cons(H)(nil)))))))))))
           (a => l => c => n => c(a)(l)))(c => n => n))(incr(mul(two)(mul(three)(eleven)))))(mul(seven)(eleven)))
           (exp(two)(five)))(mul(three)(incr(mul(four)(nine)))))(mul(four)(exp(three)(three))))(incr(hundred)))
           (mul(nine)(eight)))(mul(exp(two)(two))(exp(five)(two))))(incr(incr(nine))))(exp(three)(two)))
           (exp(two)(three)))(incr(mul(three)(two))))(add(two)(three)))(incr(three)))(x => y => y(x)))
           (x => y => f => x(y(f))))(x => y => x(incr)(y)))(x => f => s => f(x(f)(s))))(f => x => f(f(f(x)))))
           (f => x => f(f(x))))(f => x => f(x)))(f => x => x)
// The main function is defined in pure lambda calculus, using only:
// - `x`: Variable
// - `λx.x`: Abstraction
// - `x x`: Application
// In particular, the function doesn't uses any number or operator.
//
// Helpers to decode our lambda program:
let decode_list = acc => l => l(x => xs => decode_list(acc.concat([x]))(xs))(acc)
let decode_number = n => n(x => x + 1)(0)
console.log(String.fromCharCode(...main(decode_list([]))(decode_number)))
```

See the [[mockingbird|mockingbird book]]#
