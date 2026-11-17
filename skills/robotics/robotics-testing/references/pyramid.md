# The Robotics Testing Pyramid

```
                    ╱╲
                   ╱  ╲        Field Tests
                  ╱    ╲       (Real robot, real environment)
                 ╱──────╲
                ╱        ╲     Hardware-in-the-Loop (HIL)
               ╱          ╲    (Real hardware, controlled environment)
              ╱────────────╲
             ╱              ╲   Simulation Tests
            ╱                ╲  (Full sim, realistic physics)
           ╱──────────────────╲
          ╱                    ╲  Integration Tests
         ╱                      ╲ (Multi-node, message passing)
        ╱────────────────────────╲
       ╱                          ╲ Unit Tests
      ╱____________________________╲ (Single function/class, fast, deterministic)

MORE tests at the bottom, FEWER at the top.
Bottom = fast, cheap, deterministic. Top = slow, expensive, realistic.
```
