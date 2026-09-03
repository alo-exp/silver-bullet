# Method — rung 4 GLM 5.3 Max

1. `scripts/agent-opencode/invoke.sh` — **missing** on this checkout. Skill would also pin `mimo-v2.5`. Per brief: native `opencode run` with GLM 5.3 **Max**.
2. Sandbox `HOME` hides `opencode-go/*`. Launch with `HOME=/Users/shafqat`.
3. Model: `-m opencode-go/glm-5.3 --variant max --auto`
4. OpenCode 1.17.16: message as last argv; attach plan via `--file`.
5. No Fast. No Grok. No commit. Stay on main.
