# C++ testing patterns

GoogleTest is the unit-test framework. For ROS2 launch-driven integration tests, use the `robotics-testing` skill.

## Test structure

### Naming: `Method_Condition_ExpectedOutcome`

```cpp
TEST(Connection, Connect_WithInvalidHost_ReturnsError);
TEST(ScopeGuard, RunsCleanup_OnException);
```

### Arrange-Act-Assert

```cpp
TEST(RefCounted, MakeRefPtr_ReturnsObjectWithSoleOwnership) {
  // Arrange
  // Act
  auto p = std::make_shared<Base>();
  // Assert
  EXPECT_EQ(1, p.use_count()) << "sole ownership";
}
```

## Test data patterns

### Builder / modifier / inspector triple

```cpp
ObjectID id;
{ StoreBuilder s; s.AddObject(&id).SetState(State::kError); }     // build
{ StoreModifier s; s.GetObject(id).SetState(State::kNormal); }    // modify
{ StoreInspector s; EXPECT_TRUE(s.GetObject(id).IsNormal()); }    // inspect
```

### Test data builders with defaults

```cpp
static Args MakeArgs(
    std::string_view name = "Test",
    std::optional<std::string_view> email = "t@t.com",
    std::optional<GroupID> group = std::nullopt);
```

### Mock objects

```cpp
class MockTask : public Task {
 public:
  TaskQueueId GetQueueId() const override { return category_; }
  TaskId GetTaskId() const override { return TaskId::kMock; }

 private:
  TaskQueueId category_;
};
```

### Scope-based overrides

```cpp
auto scope = EnableFeatureForScope(FeatureId::kNewBehavior);
auto scope2 = OverrideConfigForScope(FeatureId::kMaxRetries, 5);
```

## Test code standards

| Allowed in tests | Don't over-engineer |
|---|---|
| Simpler error handling | No RAII wrappers for test helpers |
| Magic numbers for test values | No configurable test utilities |
| Less defensive coding | No abstraction layers in tests |
| Direct member access via fixtures | No gold-plating infrastructure |

## Key rules

1. **One act per test.** Separate AAA clearly.
1. **Descriptive names**: `Method_Condition_Outcome`.
1. **Builder / modifier / inspector** for stateful tests.
1. **Scope-based feature overrides** — never mutate global state permanently.
1. **Descriptive assertion messages.**
1. **Don't over-engineer test code.**
