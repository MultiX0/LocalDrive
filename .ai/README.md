# .ai

Support files for AI coding agents working in this repository.

Two things live here, and they are deliberately separate:

- [`project.json`](project.json) holds **facts a program can act on**: paths,
  commands, component boundaries, public contracts. No advice, no prose.
- [`skills/`](skills/) holds **playbooks for specific kinds of task**. Each one
  is the sequence a careful contributor would follow for that job, including
  the steps that are easy to skip and expensive to skip.

Human guidance is elsewhere and stays elsewhere. [`AGENTS.md`](../AGENTS.md) at
the repository root is how to work here, the `AGENTS.md` nearest the code holds
local rules, and [`VISION.md`](../VISION.md) is how to judge whether a change
belongs at all.

## Vendor neutrality

Nothing here names or requires a particular AI product, and nothing in the
build, the tests, the release or the contribution process depends on any of it.

Delete this entire directory and the project still builds, tests, releases and
accepts contributions exactly as before. That is the test, and it should stay
true.

Where a tool insists on its own filename, the project's answer is a one line
file that points at the neutral one rather than a second copy of the rules.
`landing/CLAUDE.md` is the existing example.

## Keeping it honest

`project.json` describes the repository as it is. A command listed there is one
that runs. When you move a package, rename a command or change a contract,
update it in the same change.

A map that is out of date is worse than no map, because it is trusted.
