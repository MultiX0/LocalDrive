# Skills

A playbook for each kind of task that has a right order and a set of steps that
are cheap to skip and expensive to have skipped.

These are not a second copy of [`AGENTS.md`](../../AGENTS.md). That file is how
to work here in general. A skill is the specific sequence for one job, and it
exists only where the sequence is not obvious from reading the code.

| Skill | Use it when |
| --- | --- |
| [bug-fix](bug-fix.md) | Something behaves wrongly and needs to stop |
| [server-endpoint](server-endpoint.md) | Adding or changing an HTTP endpoint |
| [database-change](database-change.md) | The schema has to change |
| [client-feature](client-feature.md) | Building or changing something in the Flutter app |
| [security-review](security-review.md) | Reviewing a change that touches auth, paths, uploads or sharing |
| [release](release.md) | Cutting a version |
| [verify-with-testsprite](verify-with-testsprite.md) | A change is done and needs proving against a running deployment |

Every skill assumes the root `AGENTS.md` has been read, and the `AGENTS.md`
nearest the code being changed.

If a task does not match a skill, that is normal. Follow the loop in
`AGENTS.md` and use judgement.
