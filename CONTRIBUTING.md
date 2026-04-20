# Contributing to portman

Thanks for wanting to contribute. This document covers how to report bugs, suggest features, and submit code.

---

## Reporting Bugs

Before opening an issue, check if it already exists in [Issues](https://github.com/chaitanyaodd1/portman/issues).

When filing a bug, please include:

- Your OS and version (`uname -a`)
- Bash version (`bash --version`)
- Python version (`python3 --version`)
- The exact command you ran
- The full output (including any error messages)
- Contents of `~/.portman/forwards.json` if relevant
- The log file output (`portman log <n>`) if the forward crashed

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).

---

## Suggesting Features

Open a [feature request](.github/ISSUE_TEMPLATE/feature_request.md) issue and describe:

- The problem you're trying to solve
- What you'd want the command or behavior to look like
- Whether you'd be willing to implement it

---

## Submitting Code

### Setup

portman is a single bash script. No build step, no dependencies to install beyond what's listed in the README.

```bash
git clone https://github.com/chaitanyaodd1/portman.git
cd portman
```

### Code style

- Use `local` for all variables inside functions
- Prefer `[[ ]]` over `[ ]` for conditionals
- All user-facing messages go through `_ok`, `_warn`, `_info`, or `_die` helpers
- Prefix internal/private functions with `_`
- Test with `bash -n portman` (syntax check) before submitting

### Lint check

Install [shellcheck](https://www.shellcheck.net/) and run it before submitting:

```bash
shellcheck portman
```

All shellcheck warnings should be resolved or explicitly suppressed with a comment explaining why.

### Pull request checklist

- [ ] `bash -n portman` passes (no syntax errors)
- [ ] `shellcheck portman` passes (or suppressions are justified)
- [ ] New commands have a `--help` path or are documented in `cmd_help`
- [ ] `CHANGELOG.md` has an entry under `[Unreleased]`
- [ ] The PR description explains *what* changed and *why*

---

## Versioning

portman follows [Semantic Versioning](https://semver.org/).

- Bug fixes → PATCH bump (1.0.0 → 1.0.1)
- New commands or backwards-compatible features → MINOR bump (1.0.0 → 1.1.0)
- Breaking changes to existing command syntax → MAJOR bump (1.0.0 → 2.0.0)

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
