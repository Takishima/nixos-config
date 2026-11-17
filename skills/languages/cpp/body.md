> Adapted from [PetrGuan/Cpp-Agent-Skill](https://github.com/PetrGuan/Cpp-Agent-Skill) (MIT).

# C++ skill index

Pick the topic and read its reference before writing or reviewing C++. Aligned with the [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html); the house exceptions to it are in `references/style.md`.

For ROS2-specific concerns (executors, callback groups, QoS, intra-process, threading), use the `ros2` skill.

| Topic | When to read | Reference |
|---|---|---|
| Naming & formatting | Google naming (snake_case vars, PascalCase types/funcs, kCamelCase constants), 100-col, `.cpp`/`.hpp`, header guards, include order | `references/style.md` |
| Memory & ownership | `unique_ptr`/`shared_ptr`, raw non-owning pointers, RAII, Rule of Zero/Five, move semantics, `std::span` | `references/memory.md` |
| Concurrency | `std::thread`/`jthread`, mutexes, `scoped_lock`, atomics, async lambda capture rules | `references/concurrency.md` |
| Error handling | exceptions vs `std::expected`, `noexcept`, `assert()` for invariants, flat error paths | `references/error-handling.md` |
| Performance | data-oriented design, allocation discipline, container selection, cache awareness, zero-overhead | `references/performance.md` |
| Patterns & idioms | modern C++17/20/23 idioms, `enum class`, `[[nodiscard]]`, `explicit`, `constexpr`, Concepts, variant/visit | `references/patterns.md` |
| API design | strong types, minimal surface, header-vs-source rule (only trivial defs in headers), ownership in signatures | `references/api-design.md` |
| Testing | GoogleTest, Arrange-Act-Assert, fixtures, mocks, test data builders | `references/testing.md` |
| Simplicity & taste | readability, "remove > reuse > simple > clever", flat control flow, naming is design | `references/simplicity.md` |

After reading the reference, follow its guidance for the task.
