# Mission

dotfiles exists so that the owner's Macs and the agents the owner runs on them work from the smallest set of configuration files and rules that makes the owner's real work better, kept secure and simple to follow.

Only the owner decides the mission and the goals. An agent proposes a change, and it takes effect when the owner merges it.

## Goals

The states the owner most wants true now. They are priorities, not the whole of the work: fixing what broke and upkeep need no goal.

1. A change merged to `main` reaches each Mac the owner uses through one `chezmoi apply`, with no repair by hand afterwards.
2. Tool versions are managed securely and without the owner's hands: every tool the owner runs is pinned in this repository, and an update arrives as a checked change the owner did not have to start.
3. The owner does not repeat an instruction to agents: one the owner has given twice takes effect in later sessions without being given again, and the shared rules do not grow to carry it.
