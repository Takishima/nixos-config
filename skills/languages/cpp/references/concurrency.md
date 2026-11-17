# C++ concurrency & threading

For ROS2 concurrency (SingleThreadedExecutor vs MultiThreadedExecutor, callback groups, no wall clocks, no sleeps, action server return-immediately rule), use the `ros2` skill — none of that is repeated here. This file covers the language-level concurrency primitives.

## Core principle

Prefer **message-passing via queues** over shared mutable state. When shared state is unavoidable, use the narrowest synchronization primitive.

## Synchronization Primitives

| Primitive | Use When |
|-----------|----------|
| `std::atomic<T>` | Single variable, lock-free (counters, flags, state enums) |
| `std::lock_guard` | Simple critical section (single mutex) |
| `std::scoped_lock` (C++17) | **Locking multiple mutexes** -- deadlock-free |
| `std::unique_lock` | Need condition_variable or conditional locking |
| `thread_local` | Per-thread caches -- no sync needed |
| Task queues | Cross-thread dispatch -- preferred over shared state |

### Locks — RAII, minimal scope

```cpp
// Single mutex
{ std::lock_guard<std::mutex> lock(mutex_); map_.emplace(k, std::move(v)); }

// Multiple mutexes — std::scoped_lock avoids deadlocks automatically
{ std::scoped_lock lock(mutex_a_, mutex_b_); TransferData(); }
```

**Keep critical sections small.** No I/O, no allocation, no external calls under lock.

**Never lock multiple mutexes with separate `lock_guard` calls** — this is a classic deadlock source. Use `std::scoped_lock` instead.

### Atomics

```cpp
static std::atomic<uint64_t> g_counter{1};
static uint64_t GetNext() { return g_counter++; }

// CAS for conditional updates
while (current < value) {
  if (g_counter.compare_exchange_weak(current, value)) break;
}
```

### Thread-local storage

```cpp
static Cache& Instance() noexcept {
  static thread_local Cache instance;
  return instance;
}
```

## Task queue pattern

```cpp
template <typename T>
void RunOnWriteQueue(std::string_view name, T&& func) {
  auto item = std::make_unique<LambdaTask>(
      QueueId::kWrite, MakeItem(name, std::forward<T>(func)));
  AddToQueue(std::move(item));
}
```

**Always name queue items** for diagnostics.

## Lambda capture rules — CRITICAL

| Lambda lifetime | Capture style |
|---|---|
| Synchronous in same scope | `[&]` safe |
| Queued async / dispatched | **By-value or move-capture ONLY** |
| Stored as member | **By-value or move-capture ONLY** |
| Timer / delayed callback | **By-value capture** |

```cpp
// Good: by-value for cross-thread
[context = GetContext()]() { RestoreContext(context); };

// Good: move-capture transfers ownership
[data = std::move(pending_)]() mutable { Process(data); };

// Good: reference capture for synchronous lambdas
auto pred = [&state]() { return state.Ready(); };
WaitUntil(pred);  // executes immediately

// Bad: NEVER reference-capture in async lambdas
auto bad = [&local]() { Use(local); };
DispatchAsync(std::move(bad));  // local is gone!
```

## `std::jthread` (C++20) — RAII thread

`std::jthread` automatically joins on destruction and supports cooperative cancellation via `std::stop_token`. Prefer it over `std::thread`, which requires manual `join()` and calls `std::terminate` if destroyed while joinable.

```cpp
// Bad: std::thread requires manual join — easy to leak
std::thread worker([&] { Process(); });
// If exception thrown before join(), std::terminate!
worker.join();

// Good: std::jthread joins automatically on destruction (RAII)
std::jthread worker([](std::stop_token token) {
  while (!token.stop_requested()) {
    ProcessNextItem();
  }
});
// Destructor requests stop and joins — safe even on exception.
```

## Key rules

1. **Prefer queues over shared state.**
1. **Always RAII for locks.** Never manual lock/unlock.
1. **`std::scoped_lock` for multiple mutexes** — deadlock-free by design.
1. **`std::jthread` over `std::thread`** — RAII join and cooperative cancellation.
1. **Keep critical sections minimal.**
1. **Never capture by reference in async lambdas.**
1. **Use `thread_local` for per-thread caches.**
1. **Use `std::atomic` for counters and flags.**
1. **Name all queue items** for diagnostics.
1. **For ROS2 executor/callback-group/threading rules**, use the `ros2` skill.
