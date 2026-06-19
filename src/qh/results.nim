## Result[T, E] - errors as values (design D6, open question 2).
##
## Homegrown pending Phase-1 ergonomics validation. Chosen over
## `questionable`/`resultty` to keep zero external deps and full control over
## integration with `{.raises.}` pragmas. If ergonomics prove poor in the
## spike, swap the backing impl without touching call sites.
##
## Implementation note: uses a flat object (both fields present) rather than a
## Nim `case` object, because variant objects with a generic param confined to
## one branch hit "cannot instantiate: 'E'" on this Nim (2.2.4). The space
## cost is one unused field per Result - acceptable; revisit in Phase 2.

type
  Result*[T, E] = object
    isOk*: bool
    val*: T     ## valid when isOk
    err*: E     ## valid when not isOk

proc ok*[T, E](v: T): Result[T, E] {.inline.} =
  Result[T, E](isOk: true, val: v)

proc err*[T, E](e: E): Result[T, E] {.inline.} =
  Result[T, E](isOk: false, err: e)

proc get*[T, E](r: Result[T, E]): T {.inline.} =
  if not r.isOk:
    raise newException(ValueError, "Result.get on an error result")
  r.val

proc error*[T, E](r: Result[T, E]): E {.inline.} =
  if r.isOk:
    raise newException(ValueError, "Result.error on a success result")
  r.err

proc map*[T, E, U](r: Result[T, E], f: proc(x: T): U): Result[U, E] {.inline.} =
  if r.isOk: ok[U, E](f(r.val)) else: err[U, E](r.err)

proc mapErr*[T, E, F](r: Result[T, E], f: proc(e: E): F): Result[T, F] {.inline.} =
  if r.isOk: ok[T, F](r.val) else: err[T, F](f(r.err))
