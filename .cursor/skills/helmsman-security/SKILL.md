---
name: helmsman-security
description: >-
  Helmsman security. Record each security finding and how to fix it.
  Write .helmsman/reports/<UTC>/security.md when the write gate allows it.
  File GitHub issues only when the setup file allows it.
  Does not edit product code. Runs on command and on the night run.
  Explicit invoke only.
user-invocable: true
disable-model-invocation: true
---

# helmsman-security

[Helmsman](../../../README.md) is a set of rules and checks for agent-written code. This skill records each security finding and how to fix it. [helmsman-slop](../helmsman-slop/SKILL.md) scores unnecessary code. [helmsman-readiness](../helmsman-readiness/SKILL.md) asks whether a gate fails the pull request. [helmsman-fix-forward](../helmsman-fix-forward/SKILL.md) edits one finding.

Do not edit product code. Do not commit the report unless asked. Filing an issue is allowed only when `.helmsman/setup.md` says `File issues: yes`.

This skill records the finding and how to fix it. It does not edit the code.

## Where the checks come from

Four sources were compared. Two are used. Two are not the checklist.

| Source | Use it for |
| --- | --- |
| [OWASP Top 10:2025](https://owasp.org/Top10/2025/) | The ten risk names, in order. OWASP calls this an awareness document and the bare minimum. |
| [OWASP ASVS 5.0.0](https://asvs.dev/v5.0.0/) (May 2025) | What a pass looks like. About 345 requirements, 17 chapters, levels 1–3. Cite `v5.0.0-<id>`. |
| [NIST SSDF](https://csrc.nist.gov/pubs/sp/800/218/final), [SLSA](https://slsa.dev/) | Not this skill. SSDF is an organization's process. SLSA is build provenance. |

OWASP [says](https://owasp.org/Top10/2025/0x03_2025-Establishing_a_Modern_Application_Security_Program/) a tool cannot claim full Top 10 coverage, and names A06 Insecure Design as beyond most testing. Do not write "OWASP covered" or a score out of 10.

This skill takes every Level 1 requirement an agent can evidence from the tree, plus four Level 2 misses that show up constantly in agent-written code: secrets in source (`v5.0.0-13.3.1`), unsafe deserialization (`v5.0.0-1.5.2`), logs and errors (`v5.0.0-16.2.5`, `v5.0.0-16.3.1`, `v5.0.0-16.5.1`, `v5.0.0-16.5.3`), and server-side fetches of a request URL (`v5.0.0-1.3.6`). It does not paste the other Level 2 and Level 3 requirements.

ASVS 5.0.0 covers applications and APIs. It does not cover mobile clients or cloud infrastructure as their own standard. When the repo is only infrastructure, say so, run the tool checks that apply, and mark the application checks not applicable.

## Limits

- Do not write a payload, a proof of concept, a bypass, or steps that would make a leak succeed. Impact is one sentence. How to fix it is the smallest change that closes the finding.
- Redact secrets. Record the path and line. Never paste the secret value.
- Do not install a scanner, and do not add one to the repo.
- **Unknown** is not a pass. **Not applicable** is neither tight nor a leak.
- Do not mark a check as a pass because the files you opened happened to look fine. Search, then decide.

## Scope

Default: commits on the current branch versus the default branch, plus uncommitted work. Read the whole tree only when the user asks for a full security. The night run uses this same scope.

## Tools

Look for the tool. Do not install it. If it is missing, that line of the report is **unknown**, and name the command you looked for.

| Tool | When | Command |
| --- | --- | --- |
| Gitleaks | `gitleaks` is on `PATH`, or the repo already runs it | `gitleaks detect --no-banner` from the repo root |
| Semgrep | `semgrep` is on `PATH`, or the repo already has a config | The repo's config. With no config, `semgrep scan --config p/owasp-top-ten` is a read-only scan of this repo. Do not write a rule. |
| Trivy | `trivy` is on `PATH` | `trivy fs --scanners vuln,misconfig,secret .` |
| Dependency audit | The repo already has a command (`npm audit`, `pnpm audit`, `yarn npm audit`, `cargo audit`, `osv-scanner`, `pip-audit`) | That command. A high or critical production advisory is a leak. |
| Bandit | The repo is Python and `bandit` is already how it scans | The repo's command |

One leak found by a tool and by a hand check is one finding. Name both. Quote the tool. Do not treat a clean tool run as a pass the tool cannot see. A06 stays unknown even when Semgrep is clean.

## Already gated

If a readiness gate already fails the pull request for a class, record the gate. Still record a leak the gate missed, and name the gate you checked. A sentence in a README is not a gate.

## Seams

Each bullet is one check. The result is **tight**, **leak**, **unknown**, or **not applicable**.

A whole group is **not applicable** when the repo has none of that surface. Say why in one line. Do not record a leak per bullet.

### A01:2025 Broken Access Control

When the app has no request that should differ by caller, this group is not applicable.

- `v5.0.0-8.2.1` — function-level access is decided on the server from an explicit permission.
- `v5.0.0-8.2.2` — a data object is loaded only when this caller may see that object. An id from the request is not permission.
- `v5.0.0-8.3.1` — the rule lives in a trusted service layer. A check that exists only in browser code is a leak.
- `v5.0.0-3.4.2` — CORS allow-origin is a fixed origin or an exact allowlist. A wildcard together with credentials is a leak. No browser surface: not applicable.
- In STAR, each agent function has its own service identity. A function that reuses a person's token is a leak. A function linked to a resource its domain does not own is a leak.
- In STAR, SurrealMCP or embedded MCP in `apps/agent` or any production toolset is a leak. Production agents reach data only through domain MCP tools.
- `v5.0.0-15.3.1` — a response returns the fields this caller may see. A stored object that also holds a secret or another caller's fields is a leak when the handler returns it whole.

### A02:2025 Security Misconfiguration

- `v5.0.0-6.3.2` — no shipped default account (`root`, `admin`, `sa`) with a known password, when the app has accounts.
- `v5.0.0-3.3.1` — session cookies set `Secure`, and the name uses the `__Host-` or `__Secure-` prefix. No browser cookies: not applicable.
- `v5.0.0-3.4.1` — HTTPS responses include HSTS with a max-age of at least one year. No HTTPS app: not applicable.
- `v5.0.0-12.1.1`, `v5.0.0-12.2.1` — external HTTP uses TLS 1.2 or 1.3 and does not fall back to cleartext. Config you cannot see is unknown.
- `v5.0.0-13.4.1` — `.git` and `.svn` are not in the deployed tree and are not served. If you cannot see the deploy, unknown. A container or static host that copies those folders is a leak.
- `v5.0.0-13.3.1` (Level 2) — secrets are not in source or build artifacts. Committed `.env` files that are not examples, private keys, and cloud credential files count. Redact the value.

### A03:2025 Software Supply Chain Failures

- A lockfile exists for each package manager the repo uses. A missing lockfile is a leak.
- `v5.0.0-15.2.1` — production dependencies are inside a remediation window the repo has written down. No written window: a high or critical production advisory from the audit tool is a leak. No tool and no window: unknown.
- CI actions and container base images are pinned to a digest or a commit when those files exist. A floating tag is a leak.
- A build step that pipes a remote script into a shell from an unpinned URL is a leak.

### A04:2025 Cryptographic Failures

- `v5.0.0-11.4.1` — MD5 and SHA-1 are not used for passwords, signatures, or token integrity. A checksum the code marks as non-security is not applicable.
- `v5.0.0-11.3.1` — ECB and PKCS#1 v1.5 are not used.
- `v5.0.0-11.3.2` — encryption uses an approved cipher and mode, such as AES-GCM or the platform's current default. A library default you did not open is unknown.
- `v5.0.0-9.1.1`, `v5.0.0-9.1.2`, `v5.0.0-9.1.3` — a self-contained token is checked by signature or MAC before use, the algorithm is on an allowlist (reject `none`), and the key comes from the configured issuer, not from the token. No such tokens: not applicable.
- `v5.0.0-14.2.1` — API keys and session tokens are not placed in a URL or a query string.

### A05:2025 Injection

An injection path with no sink is not applicable.

- `v5.0.0-1.2.4` — queries are parameterized or go through the ORM. A query built by concatenating request data is a leak.
- `v5.0.0-1.2.5` — an operating-system call does not concatenate request data into a shell command.
- `v5.0.0-1.3.2` — `eval` and expression languages are not fed request data.
- `v5.0.0-1.2.1`, `v5.0.0-1.2.2`, `v5.0.0-1.2.3` — HTML, URLs, and JavaScript built from request data are encoded for that context. A `javascript:` or `data:` URL taken from request data is a leak.
- `v5.0.0-1.5.1` — an XML parser does not resolve external entities, when the app parses XML.
- `v5.0.0-5.3.2` — a file path is not taken raw from the request.
- `v5.0.0-1.3.6` (Level 2) — a URL supplied by the request is checked against an allowlist of protocol, host, and port before the server fetches it. No such fetch: not applicable.

### A06:2025 Insecure Design

One check. OWASP says this risk is beyond most testing.

- `v5.0.0-2.3.1` — business steps run on the server in order, and a caller cannot skip a step by calling a later route. If you cannot see that flow, mark **unknown**. Do not invent a threat model to fill the gap.

### A07:2025 Authentication Failures

Not applicable when the app has no accounts.

- `v5.0.0-6.2.1` — a user-set password may be at least 8 characters. A shorter maximum is a leak.
- `v5.0.0-6.2.8` — the password is checked as received, with no truncation and no case folding.
- `v5.0.0-6.4.2` — no password hints and no knowledge questions.
- `v5.0.0-7.2.1` — the session is checked on the server.
- `v5.0.0-7.2.4` — login issues a new session and drops the previous one.
- `v5.0.0-7.4.1` — logout or expiry makes that session unusable on the server.

### A08:2025 Software or Data Integrity Failures

- `v5.0.0-1.5.2` (Level 2) — untrusted input is not passed to a deserializer the platform documents as unsafe, such as Python `pickle`, YAML loading of arbitrary objects, PHP `unserialize`, or Java native deserialization. No such call: not applicable.
- `v5.0.0-10.4.1` — an authorization server in this repo checks redirect URIs against a client allowlist with exact string comparison. This repo is not an authorization server: not applicable.
- `v5.0.0-10.4.4` — that authorization server does not enable the implicit grant or the password grant.
- A workflow that runs pull-request code from a fork in a job that also holds secrets is a leak. Read the workflow. Do not describe how to use that job.

### A09:2025 Security Logging and Alerting Failures

Whether anyone is alerted in production is **unknown** from a clone. Say so. Do not call the group tight because a log line exists.

- `v5.0.0-16.3.1` (Level 2) — authentication success and failure are logged, when accounts exist.
- `v5.0.0-16.2.5` (Level 2) — logs do not contain passwords, session tokens, or payment data.
- `v5.0.0-16.5.1` (Level 2) — an unexpected error returns a generic message. A stack trace, a query, or a secret in the client response is a leak.

### A10:2025 Mishandling of Exceptional Conditions

- `v5.0.0-16.5.3` (Level 2) — a failed check stops the action. An empty catch that still completes a privileged or state-changing action is a leak.
- `v5.0.0-2.2.2` — input is validated on the server. Validation that exists only in the client is a leak for that field.

## Priority

Same scale as the slop, P0–P4. There is no P5. P4 is unused unless the defect has no security effect.

- **P0** — a secret in the tree, a query or shell or `eval` fed by request data, or authorization that fails open on a privileged action.
- **P1** — object access with no server-side check, unsafe deserialization, CORS credentials with a wildcard, an unpinned image or action that ships the app.
- **P2** — a weak hash used for security, missing HSTS on an HTTPS app, a stack trace returned to the client, a high or critical production advisory.
- **P3** — a missing authentication log, a session cookie without `Secure`, an advisory below high.
- **P4** — no security effect.

## Report

Show the report in the reply. Write `.helmsman/reports/<UTC>/security.md` only when `.helmsman/tools/checks/report-write.sh security.md` exits 0. Use the same `HELMSMAN_REPORT_STAMP` as the rest of the nightly. Exit 10 means chat only. A write needs the path gitignored and one of `HELMSMAN_WRITE_REPORTS=1`, `CURSOR_AGENT=1`, `GITHUB_ACTIONS=true`, or `CI=true`. One section per finding, P0 first. Do not invent a finding. A group that is not applicable is one line in the table. Every finding includes how to fix it. In this report, a tight control is `pass` and a leak is `finding`. Write the report in those words.

```markdown
# Security findings

**Date:** YYYY-MM-DD
**Scope:** branch vs default branch | full tree
**Coverage claim:** none. Risk names are OWASP Top 10:2025. A passing control is an ASVS 5.0.0 requirement. This is not full Top 10 coverage.

| Result | Count |
| --- | --- |
| Pass | n |
| Finding | n |
| Unknown | n |
| Not applicable | n |

## Tools

| Tool | Present | Result |
| --- | --- | --- |
| Gitleaks | yes / no | one line, or unknown |
| Semgrep | yes / no | one line, or unknown |
| Trivy | yes / no | one line, or unknown |
| Dependency audit | command, or none | one line, or unknown |

## Controls

| Risk | Requirement | Result | Evidence |
| --- | --- | --- | --- |
| A01:2025 | v5.0.0-8.2.1 | pass / finding / unknown / not applicable | `path:line` or why it does not apply |

## Findings

### P# — Short title

- **Priority:** P0 | P1 | P2 | P3 | P4
- **Risk:** A0N:2025 name
- **Requirement:** v5.0.0-x.y.z
- **Location:** `path/to/file.ext:line`
- **Impact:** One sentence on what is exposed if this stays.
- **Evidence:** The line, with any secret redacted. Name the tool if a tool found it.
- **Gate checked:** The check that should have failed the pull request, and why it did not. Or "no gate".
- **How to fix:** The smallest change that closes the finding. No patch and no reproduction.
- **Acceptance:** The control passes, and the named gate or command fails a regression of this finding.
- **Out of scope:** What the fix must not widen into.
```

## Issues

If `File issues` is not `yes`, stop after the report and say issues were not filed. The default is `no`. If it is `yes` and `Issues` is `github`, file one GitHub issue per finding that is not already open. Search open issues for the same path and title before creating one. Label them `helmsman`. The issue title is the heading without the hashes. The body is the finding section, including how to fix it, Acceptance, and Out of scope. That shape is [docs/issue-body.md](../../../docs/issue-body.md). If `Issues` is not `github`, say so and do not invent another tracker client.

A missing setup file means issues are not filed.

When you finish, tell the user the finding count and the unknown count. Point them at `/helmsman-fix-forward` for one finding. Do not start the fix unless they ask, or this is the night run and `Fix` is `yes`. An empty report does not raise the score.
