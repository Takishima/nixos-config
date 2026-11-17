# Quick Reference: Principle Checklist

Use this during code reviews:

| # | Principle | Check |
|---|-----------|-------|
| 1 | Single Responsibility | Can you describe the module without "and"? |
| 2 | Dependency Inversion | Does high-level code import hardware drivers? |
| 3 | Open-Closed | Does adding a new sensor require modifying existing code? |
| 4 | Interface Segregation | Are implementations forced to stub out unused methods? |
| 5 | Liskov Substitution | Can you swap sim/real without changing caller code? |
| 6 | Separation of Rates | Does perception block the control loop? |
| 7 | Fail-Safe Defaults | What happens on communication loss? |
| 8 | Configuration Over Code | Are there magic numbers in the source? |
| 9 | Idempotent Operations | Is it safe to send every command twice? |
| 10 | Observe Everything | Can you diagnose a 2 AM failure from logs alone? |
| 11 | Composability | Can you build new tasks from existing skills? |
| 12 | Graceful Degradation | What's the robot's behavior when a sensor fails? |
