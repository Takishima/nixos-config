# Why Robotics Software Is Different

Robotics code operates under constraints that most software never faces:

1. **Physical consequences** — A bug doesn't just crash a process, it crashes a robot into a wall
1. **Real-time deadlines** — Missing a 1ms control loop deadline can cause oscillation or damage
1. **Sensor uncertainty** — All inputs are noisy, delayed, and occasionally wrong
1. **Hardware diversity** — Same algorithm must work on 10 different grippers from 5 vendors
1. **Sim-to-real gap** — Code must run identically in simulation and on real hardware
1. **Long-running operation** — Robots run for hours/days; memory leaks and drift matter
1. **Safety criticality** — Some failures must NEVER happen, regardless of software state

These constraints demand disciplined design. Below are principles that account for them.

______________________________________________________________________
