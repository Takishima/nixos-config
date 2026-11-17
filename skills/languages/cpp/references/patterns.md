# C++ design patterns & modern idioms

## Architectural patterns

### Command (actor) pattern

```cpp
void AddAttachment::Execute(Host* host, const Header* draft, const Args* args) {
  if (!draft->IsDraft()) throw PreconditionViolated{...};
  auto id = AddAttachment(...);
  host->OnResultsAvailable(std::make_unique<Results>(id));
}
```

### Observer / reactor pattern

```cpp
class AccountReactor final : public Reactor {
  void OnObjectChanged(Host* host, const Node* node) const override;
  void OnObjectDeleted(Host* host, const Node* node) const override;
};
```

Reactors execute sequentially, not recursively.

### Factory pattern

```cpp
std::unique_ptr<Task> CreateTask(TaskType type, Args&& args);
std::shared_ptr<Storage> CreateStorage(bool snapshot = true);
```

## Modern C++ features

### `constexpr` — compute at compile time

```cpp
constexpr uint16_t kVersion = 2;
static constexpr std::array kUrls = {"a.com"sv, "b.com"sv};  // CTAD
static constexpr bool kWantsResults = !std::is_same_v<TResults, void>;
constexpr TypedID() noexcept = default;
```

### `if constexpr` — compile-time branching

```cpp
if constexpr (!std::is_same_v<TResult, void>) {
  result_ = std::static_pointer_cast<TResult>(std::move(value));
} else {
  (void)value;
}
```

### `std::optional`

```cpp
bool IsAuth(const Account* a, const std::optional<AuthType>& t = std::nullopt);
```

### String Handling

- Parameters: `string_view` (non-owning)
- Return: `std::string` / `std::wstring` (owning)
- Storage: owned strings

### C++20 Concepts (Preferred for Template Constraints)

```cpp
// C++20: Concepts -- clear, readable, better error messages
template <std::integral T>
T Saturate(T value, T min, T max);

// Custom concept
template <typename T>
concept Serializable = requires(T t, Writer& w) {
    { t.Serialize(w) } -> std::same_as<void>;
};

template <Serializable T>
void Save(const T& obj, Writer& writer);
```

### SFINAE / enable_if (C++17 Fallback)

```cpp
// C++17: SFINAE -- use only when Concepts are unavailable
template <typename T>
struct Conv<T, std::enable_if_t<std::is_enum_v<T>>> {
    static auto Convert(T v) { return static_cast<std::underlying_type_t<T>>(v); }
};
```

**Prefer Concepts (C++20) > `if constexpr` > SFINAE.** Concepts produce better error messages and are the intended replacement.

### std::variant / std::visit -- Type-Safe Unions

```cpp
// Type-safe alternative to unions and runtime polymorphism for closed type sets
using Shape = std::variant<Circle, Rectangle, Triangle>;

// Exhaustive dispatch -- compile error if a type is unhandled
double Area(const Shape& shape) {
    return std::visit([](const auto& s) { return s.Area(); }, shape);
}

// Overloaded lambda pattern for heterogeneous handling
template <class... Ts> struct Overloaded : Ts... { using Ts::operator()...; };
std::visit(Overloaded{
    [](const Circle& c)    { /* ... */ },
    [](const Rectangle& r) { /* ... */ },
    [](const Triangle& t)  { /* ... */ },
}, shape);
```

### C++20 Designated Initializers

```cpp
struct ConnectionConfig {
    std::string_view host;
    uint16_t port = 443;
    Security security = Security::TLS;
    Timeout timeout{30s};
};

// Clear, self-documenting initialization -- no positional ambiguity
auto config = ConnectionConfig{
    .host = "example.com",
    .port = 8080,
    .timeout = Timeout{60s},
};
```

### Iteration and algorithms

```cpp
for (const auto& [key, value] : map_) { ... }

// C++20: prefer std::ranges over explicit begin/end
auto it = std::ranges::find_if(items, [id](auto& x) { return x.id == id; });

// Ranges with projections — cleaner than lambdas for member access
std::ranges::sort(employees, {}, &Employee::last_name);

// Safe erase in loops
auto it = c.begin();
while (it != c.end()) {
  if (Remove(*it)) it = c.erase(it); else ++it;
}

// C++20: std::erase_if for containers
std::erase_if(items, [](const auto& item) { return item.IsExpired(); });
```

### `auto` usage

- Use for: iterators, factory returns, lambdas, scope guards.
- Avoid when: explicit type adds clarity (`int count`, `bool valid`, `ObjectID target`).

## Key rules

1. **C++20 Concepts over SFINAE** for template constraints. `if constexpr` for body branching.
1. **`constexpr` for all compile-time values.**
1. **`std::variant` + `std::visit`** for type-safe closed-set dispatch.
1. **Pass strings by `string_view`**, return by owned string.
1. **`enum class` exclusively** — never plain `enum`.
1. **Prefer `std::ranges` algorithms** over raw loops and explicit begin/end.
1. **Designated initializers** for readable aggregate construction.
1. **`auto` when obvious**, explicit types when clarifying.
1. **Factories return smart pointers.**
