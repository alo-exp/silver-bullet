# Contributing to Silver Bullet

Thank you for your interest in contributing! Silver Bullet is an AI-native process orchestrator for Claude Code, and contributions are welcome.

## Getting Started

1. Fork and clone the repo
2. Install prerequisites: Claude Code, jq, GSD (`npx get-shit-done-cc@^1.30.0`), Superpowers (`/plugin install obra/superpowers`)
3. Run `/using-silver-bullet` in the cloned repo to activate enforcement

## Project Structure

```
skills/           # Skill definitions (SKILL.md per skill)
hooks/            # Enforcement hook scripts + hooks.json
templates/        # CLAUDE.md, config, and workflow templates
site/             # GitHub Pages help site (static HTML)
  help/           # Help documentation pages
  index.html      # Landing page
scripts/          # Utility scripts (semantic compression, deploy gate)
tests/            # Hook and script tests
```

## Adding a Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`)
2. Write the skill instructions in markdown
3. If the skill should be tracked by enforcement, add it to `all_tracked` in `templates/silver-bullet.config.json.default`
4. Add a search.js entry and update the Reference help page if appropriate
5. Run CI locally: validate JSON, check hook references, lint shell scripts

## Adding a Hook

1. Create an executable shell script in `hooks/`
2. Add the trigger mapping to `hooks/hooks.json`
3. Ensure the hook reads config from `.silver-bullet.json` via `jq`
4. Test with `bash -n hooks/your-hook.sh` (syntax check) and `shellcheck hooks/your-hook.sh`

## Modifying Help Pages

Each help page under `site/help/` is a self-contained HTML file with inline CSS. When creating or modifying pages:

1. Copy the CSS block and template structure from an existing page
2. Add sidebar navigation entries
3. Add corresponding entries to `site/help/search.js`
4. Test locally by opening the HTML file in a browser

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear, conventional commit messages (`feat:`, `fix:`, `docs:`)
3. Ensure CI passes (JSON validation, hook checks, shell linting)
4. Open a PR with a description of what changed and why
5. PRs are reviewed for consistency with the existing workflow structure

## Code Style

- **Shell scripts**: POSIX-compatible, pass `shellcheck`, use `jq` for JSON
- **HTML**: Inline CSS (no external stylesheets), semantic HTML, responsive design
- **Markdown**: ATX-style headings, fenced code blocks, conventional commit references

## Reporting Issues

Use [GitHub Issues](https://github.com/alo-exp/silver-bullet/issues) with the provided templates for bug reports and feature requests.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
