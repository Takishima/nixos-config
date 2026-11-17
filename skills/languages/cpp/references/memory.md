# C++ memory management & ownership

The examples below follow the naming scheme of [`style.md`](style.md) (`snake_case_` for class members, no `sp`/`p` Hungarian prefixes).

## The ownership rule

Every heap-allocated object must have **exactly one clear owner** at all times. Ownership is expressed through types, not comments.

## Smart pointer selection

| Pointer type | Ownership | Use when |
|---|---|---|
| `std::unique_ptr<T>` | Exclusive | Default choice. Single owner; transfer via `std::move` |
| `std::shared_ptr<T>` | Shared | Multiple owners with shared lifetime. Use sparingly. |
| Raw pointer (`T*`) | **Non-owning** | Observer/borrowed reference; never manages lifetime |

### `std::unique_ptr` — default choice

```cpp
auto task = std::make_unique<LoadTask>(type, handle);
queue.Push(std::move(task));  // transfer ownership
```

### Raw pointers — non-owning only

```cpp
void OnChanged(Host* host, const Node* node) const;  // borrowed

class Reactor {
  DataStore* store_;  // non-owning — lifetime managed externally
};
```

## RAII — everything

### Scope guards

```cpp
auto guard = GetScopeGuard([]() { Cleanup(); });

BasicScopeGuard SetContextForScope(const Data& data) noexcept {
  Data old = GetContext();
  SetContext(data);
  return BasicScopeGuard([old]() { SetContext(old); });
}
```

### Locks — always RAII

```cpp
// Good: RAII
{ std::lock_guard<std::mutex> lock(mutex_); map_.emplace(k, std::move(v)); }

// Bad: NEVER manual lock/unlock
mutex_.lock(); DoWork(); mutex_.unlock();
```

## Rule of Zero / Rule of Five

### Rule of Zero (preferred)

If your class only contains RAII members (smart pointers, standard containers, value types), **declare no special members**. Let the compiler generate them correctly.

```cpp
// Good: Rule of Zero — compiler generates correct copy/move/destructor
class UserSession {
  std::string name_;
  std::unique_ptr<Connection> conn_;
  std::vector<Token> tokens_;
};
```

### Rule of Five

If you must define **any** of the five special members (destructor, copy constructor, copy assignment, move constructor, move assignment), you must define **all five** — or explicitly `= delete` the ones you don't want.

```cpp
class Buffer {
 public:
  ~Buffer() noexcept;
  Buffer(const Buffer& other);                 // deep copy
  Buffer& operator=(const Buffer& other);      // copy-assign
  Buffer(Buffer&& other) noexcept;             // move
  Buffer& operator=(Buffer&& other) noexcept;  // move-assign

 private:
  void* data_;
  size_t size_;
};
```

**Always prefer Rule of Zero.** If you find yourself writing a destructor, ask whether wrapping the resource in a RAII type (e.g., `unique_ptr` with custom deleter) would eliminate the need.

## Move semantics

```cpp
queue.Push(std::move(task));                      // transfer ownership
[data = std::move(pending_)]() mutable { ... };   // move into capture

template <typename T>
void Dispatch(std::string_view name, T&& func) {
  auto item = MakeItem(name, std::forward<T>(func));  // perfect forward
  AddToQueue(std::move(item));
}
```

**Critical**: Mark move constructors and move assignment `noexcept`. Without `noexcept`, `std::vector` will **copy** instead of move during reallocation — a silent performance regression.

```cpp
// Good: noexcept move enables vector optimization
MyType(MyType&& other) noexcept;
MyType& operator=(MyType&& other) noexcept;
```

## Non-owning views

### `std::span<T>` (C++20) — contiguous range view

`std::span` replaces `(T* ptr, size_t len)` parameter pairs with a safe, non-owning view over contiguous memory.

```cpp
// Bad: raw pointer + size — easy to mismatch
void Process(const float* data, size_t count);

// Good: span is safe, accepts vector, array, C-array
void Process(std::span<const float> data);

std::vector<float> v = {1.0f, 2.0f, 3.0f};
Process(v);                         // works
std::array<float, 3> a = {1, 2, 3};
Process(a);                         // works
```

## Key rules

1. **Default to `unique_ptr`** — only `shared_ptr` when sharing is required.
1. **Raw pointers are non-owning** — they borrow, never manage lifetime.
1. **RAII for everything** — locks, handles, state restoration, cleanup.
1. **Rule of Zero** — prefer compiler-generated special members. Rule of Five if you must.
1. **Mark move operations `noexcept`** — required for `std::vector` optimization.
1. **Use `std::span`** for non-owning views over contiguous ranges.
1. **Transfer with `std::move`** — never copy a `unique_ptr`.
1. **Scope guards for paired operations** — set/restore, open/close, push/pop.
