# C++ style

Naming, formatting, and file organization. Based on the [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html) with a few house exceptions (file extensions, line length, function-name casing rule).

## Naming

| Kind | Convention | Example |
|---|---|---|
| Types (class, struct, enum class, type alias) | `PascalCase` | `ConnectionPool`, `ParseError`, `NodePtr` |
| Functions and methods | `PascalCase` in new code; `snake_case` when matching surrounding ROS2-style code | `LoadConfig()`, `timer_callback()` |
| Variables (local, parameter) | `snake_case` | `retry_count`, `error_code` |
| Class data members (private/protected) | `snake_case_` (trailing underscore) | `timer_`, `publisher_` |
| Struct data members (public, plain data) | `snake_case` | `host`, `port` |
| Constants and `constexpr` values | `kCamelCase` | `kMaxRetries`, `kPublishPeriod` |
| Enumerators (`enum class`) | `kCamelCase` | `Severity::kError`, `Color::kRed` |
| Namespaces | `snake_case` | `acme`, `acme::storage` |
| Macros (avoid when possible) | `UPPER_SNAKE_CASE` | `ACME_LIKELY` |
| Header guards | `PROJECT_PATH_FILE_HPP_` | `EXAMPLE_ROS_NODE_EXAMPLE_PUBLISHER_HPP_` |

Hungarian-style prefixes (`m_`, `s_`, `c_`, `sp`, `p`, `tl_`, `g_`) are **not** used in this project. Same with `I` / `Base` / `_Test` suffixes for interfaces, base classes, or test classes — name them by what they are, not what they architecturally play (`IStorage` becomes `Storage`; `DispatcherBase` becomes either `Dispatcher` or `DispatcherInterface` depending on intent).

### Names communicate purpose

```cpp
// Good — name says what, type says how
int elapsed_days;
std::unique_ptr<Connection> conn;

// Bad — type encoded in name
int iElapsedDays;
std::unique_ptr<Connection> sp_conn;
```

Length guide:

- Loop indices: `i`, `j`, `it`.
- Locals: 1-2 words.
- Members: 2-3 words.
- Functions: verb + noun, as long as needed.
- Classes: noun phrase, as long as needed.

## Formatting

- **Line length: 100 columns** (overrides Google's 80).
- **Indentation: 2 spaces**, no tabs.
- **Braces: each on its own line for namespaces, classes, and functions**; same-line for `if`/`for`/`while` is fine.
- **One declaration per line**: `int x = 0;` then `int y = 1;`, not `int x = 0, y = 1;`.

## Headers

### Guards

Use `#ifndef` guards with a path-derived name. Prefer them over `#pragma once`.

```cpp
#ifndef EXAMPLE_ROS_NODE_EXAMPLE_PUBLISHER_HPP_
#define EXAMPLE_ROS_NODE_EXAMPLE_PUBLISHER_HPP_

// ... declarations ...

#endif  // EXAMPLE_ROS_NODE_EXAMPLE_PUBLISHER_HPP_
```

### Include order

Per Google, separated by blank lines:

1. The matching header (only in a `.cpp`, `#include "foo.hpp"` first)
1. C system headers (`<sys/types.h>`)
1. C++ standard library (`<chrono>`, `<memory>`)
1. Other libraries (`<rclcpp/rclcpp.hpp>`, `<boost/...>`)
1. This project's headers (`"acme/log.hpp"`)

```cpp
// example_publisher.cpp
#include "example_ros_node/example_publisher.hpp"  // matching header first

#include <chrono>                                   // C++ standard
#include <memory>

#include "rclcpp/rclcpp.hpp"                        // other libraries
#include "std_msgs/msg/string.hpp"
```

Use forward declarations only when including the header would force a transitive dependency on callers. Within the same compilation unit, full includes are clearer.

### Include what you use (Google IWYU)

Every translation unit must directly include the header that declares each symbol it names. **Do not** rely on transitive inclusions — neither from the matching `.hpp` nor from third-party headers. From Google §Include What You Use: *"If a source or header file refers to a symbol defined elsewhere, the file should directly include a header file which … provides a declaration or definition of that symbol. It should not include header files for any other reason."*

```cpp
// foo.hpp
#include <shared_mutex>           // foo.hpp uses std::shared_mutex in its declarations

// foo.cpp
#include "foo.hpp"                // matching header first

#include <mutex>                  // foo.cpp uses std::unique_lock — include it.
#include <shared_mutex>           // foo.cpp uses std::shared_mutex directly — include it,
                                  // even though foo.hpp already pulls it in.
```

The "matching header first" rule still buys you something concrete: if `foo.hpp` ever drops `<chrono>`, `foo.cpp` keeps compiling only when it includes `<chrono>` itself. That's the whole point of IWYU — refactors of one header don't silently break consumers.

What this rule does *not* require: re-listing headers for types you only pass through the `.hpp`'s public API. If `foo.hpp` returns a `std::vector<int>` and `foo.cpp` only forwards that value, `foo.cpp` doesn't need `<vector>`. The moment it constructs, indexes, or iterates one, it does.

### Header content rule

Only **trivial** non-template definitions in `.hpp`:

- Single-statement getter (`return member_;`)
- Single-statement setter (`member_ = value;`)

Everything else — multi-statement bodies, anything that pulls additional includes — goes in `.cpp`. Templates and `constexpr` functions are the only routine exception.

## Comments

Comments explain **why**, not **what** — naming carries the "what".

```cpp
// Bad — narrates the code
count_++;  // increment count

// Good — explains a constraint the code can't express
// Retry up to 3 times because the auth service returns 503 during deployments
// (see incident #4521).
constexpr int kMaxRetries = 3;
```

- `//` for inline and block comments. Reserve `/* */` for `clang-format` off/on and rare multi-line license headers. The Google C++ Style Guide notes `//` is "much more common" than `/* */`; use `//` exclusively. **Do not** switch to Doxygen `///` or `/** @brief */` for member docs.
- No comments that restate the function signature ("returns true if authenticated").
- No comments referencing tickets, branches, or other agents' work that will rot — link via commit message or PR instead.

### Multi-line `//` blocks next to existing members

When adding a wider `//` rationale next to an existing data-member section, **don't reuse a former section-header line as your lead-in**. A short header that used to apply to several members underneath gets read by the next reader as the headline of your new prose, and the actual rationale gets ignored.

```cpp
// Bad — the "Data buffers" header was a section title for the two
// members underneath; the mutex rationale inherits it by accident.
private:
  // Data buffers. map_ is written by the elevation-map subscription
  // callback and read by nav2's updateBounds/updateCosts on a separate
  // thread. grid_map::GridMap is not thread-safe...
  mutable std::shared_mutex map_mutex_;
  grid_map::GridMap map_;
```

```cpp
// Good — header dropped; rationale lives in two short paragraphs
// separated by a blank // line, in the order "what / why / how it's used".
private:
  // map_ is written by the /elevation_map subscription callback and read
  // by nav2's updateBounds/updateCosts on a separate thread. grid_map::GridMap
  // is not thread-safe — GridMapRosConverter::fromMessage reallocates the
  // Eigen-backed storage in place.
  //
  // Writer takes a unique_lock on map_mutex_; readers take a shared_lock.
  mutable std::shared_mutex map_mutex_;
  grid_map::GridMap map_;
```

If the section header is still useful for the members below the new mutex, move it to where it still applies, or delete it.

## Other Google rules in force

Topics where Google's guide is the rule and there's no house override. Mentioned here so reviewers don't need to bounce out to google.com mid-review.

### C++ casts (§Casting)

Use `static_cast`, `dynamic_cast`, `const_cast`, `reinterpret_cast`, and (C++20) `std::bit_cast`. **Never** C-style casts.

```cpp
// Good
auto count = static_cast<int>(items.size());
auto* derived = dynamic_cast<Derived*>(base);

// Bad
auto count = (int)items.size();          // C-style cast
auto* derived = (Derived*)base;          // C-style cast, also unsafe vs dynamic_cast
```

### RTTI (§Run-Time Type Information)

Avoid `typeid` and `dynamic_cast` for runtime dispatch in production code. Prefer `std::variant` + `std::visit` (see `patterns.md`) for closed type sets, or virtual functions for open hierarchies. RTTI is fine in test code.

```cpp
// Good — closed set, exhaustive at compile time
std::visit([](const auto& s) { return s.Area(); }, shape);

// Bad — open-ended RTTI dispatch in production
if (typeid(*shape) == typeid(Circle)) { /* ... */ }
```

### Class-member declaration order (§Declaration Order)

Inside a class: `public:` → `protected:` → `private:`. Within each access section, in order:

1. Types and type aliases (`using`, nested classes)
1. Static constants (`static constexpr`)
1. Factory functions
1. Constructors and assignment operators
1. Destructor
1. All other methods (grouped logically)
1. Data members

One block per access label — don't interleave methods and data, and don't repeat `public:` / `private:` twice.

### Fixed-width integer types (§Integer Types)

Prefer plain `int` for small values that fit comfortably in 16 bits and where the exact width doesn't matter. For wider or specific-width values, use `<cstdint>`: `int32_t`, `int64_t`, `uint32_t`, `uint64_t`. **Never** `long long`. Avoid bare `unsigned` except for documented quantities like `uint16_t port`.

```cpp
// Good
int retry_count = 0;
int64_t bytes_transferred = 0;
uint16_t port = 8080;

// Bad
unsigned int retry_count = 0;            // bare unsigned for arithmetic
long long bytes_transferred = 0;         // use int64_t instead
```

### `friend` declarations

Allowed but rare. Reasonable use: paired classes in the same `.hpp` (e.g. a builder/`friend`s its product), or a test fixture in the same header. Don't reach for `friend` to paper over a missing accessor.

### Streams

Don't use `<iostream>` for logging — use the project's logging library. `std::ostringstream` is fine for one-off string formatting; prefer `std::format` (C++20) where available.

```cpp
// Good
LOG_INFO("connected to {}", endpoint);                      // logging library
auto msg = std::format("rate={:.2f} hz", current_rate_);    // C++20

// Bad
std::cout << "connected to " << endpoint << "\n";           // never log via iostream
```
