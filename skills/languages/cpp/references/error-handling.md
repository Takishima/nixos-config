# C++ error handling

Assertions use `assert()` from `<cassert>`. This file covers the rest: exception strategy, `noexcept` discipline, `std::expected`/`std::optional`, and error-path shape.

## Error strategy hierarchy

| Mechanism | When to use |
|---|---|
| `assert()` (`<cassert>`) | Pre/postconditions and invariants. Violations are bugs, not recoverable. |
| Exceptions | Recoverable failures at API/IO boundaries — file not found, network error, bad input |
| `std::expected<T, E>` (C++23) | Operation that can fail with diagnostic info; caller branches on the result |
| `std::optional<T>` | Values that may legitimately be absent (lookup miss, end-of-stream) |
| `[[nodiscard]]` returns | Functions whose return value must not be ignored |

## Assertions

Use `assert()` from `<cassert>` for pre/postconditions. The assertion is compiled out in release builds, so do not rely on side effects.

```cpp
#include <cassert>

void Pool::Acquire(Handle* out) {
  assert(out != nullptr);   // precondition
  assert(active_ < kCapacity);

  *out = AllocateSlot();

  assert(active_ <= kCapacity);  // postcondition
}

Pool::~Pool() noexcept {
  assert(active_ == 0);  // all slots returned
}
```

Don't `throw` on invariant violations — invariants are bugs. Reserve exceptions for runtime failures.

## Exception handling

### Catch-log-rethrow (boundary pattern)

```cpp
try {
  ProcessTask(std::move(data));
} catch (const std::bad_alloc&) {
  throw;  // always rethrow OOM
} catch (const std::exception& ex) {
  Log(ex.what());
  throw;
} catch (...) {
  Log("unknown");
  throw;
}
```

### Anti-patterns

```cpp
catch (...) { }                       // Bad: NEVER swallow silently
catch (std::exception ex) { }         // Bad: slices! use `const&`
try { return c.at(k); } catch { }     // Bad: don't use exceptions for control flow
```

## Exception safety guarantees

Every function provides one of three guarantees. Know which one you're providing:

| Guarantee | Promise | How to achieve |
|---|---|---|
| **Nothrow** | Never throws. Mark `noexcept`. | Destructors, move operations, swap, cleanup |
| **Strong** | If it throws, state is unchanged (commit-or-rollback). | Copy-then-swap idiom |
| **Basic** | If it throws, no leaks and invariants hold, but state may have changed. | RAII for all resources |

```cpp
// Nothrow: destructors, moves, swap
~Connection() noexcept;
Connection(Connection&& other) noexcept;
void swap(Connection& a, Connection& b) noexcept;

// Strong: copy-then-swap for commit-or-rollback
Widget& Widget::operator=(const Widget& other) {
  Widget temp(other);   // copy (may throw — but hasn't changed *this yet)
  swap(*this, temp);    // swap (noexcept — commits the change)
  return *this;         // temp's destructor cleans up old state
}
```

If you haven't thought about which guarantee, it's probably basic at best.

## `noexcept` guidance

Mark functions `noexcept` when they genuinely cannot throw:

- **Always**: destructors, move constructors, move assignment, swap.
- **Consider**: simple getters, comparison operators, hash functions.
- **Never**: functions that allocate, do I/O, or call unknown code.

**Critical performance implication**: `std::vector` will only move elements during reallocation if the move constructor is `noexcept`. Without it, vector silently falls back to copying for exception safety.

```cpp
// Without noexcept: vector copies during reallocation (slow)
MyType(MyType&& other);

// With noexcept: vector moves during reallocation (fast)
MyType(MyType&& other) noexcept;
```

## `std::expected<T, E>` (C++23)

For operations that can fail with diagnostic information, prefer `std::expected` over custom error types or out-parameters.

```cpp
[[nodiscard]] std::expected<Config, ParseError> ParseConfig(std::string_view input);

auto result = ParseConfig(text);
if (result) {
  UseConfig(*result);
} else {
  Log(result.error().message);
}
```

For C++17/20 codebases without `std::expected`, use a project-local `Expected<T, E>` or a library like `tl::expected`.

## Error-path design

Error paths should be **as clean as success paths**. Flat, not nested.

```cpp
// Bad — deeply nested
if (auto c = Connect()) {
  if (auto s = c->Open()) {
    if (auto d = s->Read()) { return Transform(d); }
  }
}

// Good — early returns, flat
auto c = Connect();   if (!c) return Error("connect");
auto s = c->Open();   if (!s) return Error("open");
auto d = s->Read();   if (!d) return Error("read");
return Transform(d);
```

## Key rules

1. **`assert()` for invariants**, exceptions for recoverable failures, `std::expected` for failures with info, `std::optional` for absence.
1. **Know your exception safety guarantee** — nothrow, strong, or basic. Every function has one.
1. **Mark `noexcept`** on destructors, move operations, and swap — required for correctness and performance.
1. **Catch by `const&`**, in order of specificity.
1. **Always rethrow after logging** at boundaries.
1. **Error paths should be flat** — early returns, not deep nesting.
1. **Don't guard impossible scenarios** — trust control flow guarantees.
1. **Destructors: `noexcept`** with `assert()` for cleanup invariants.
