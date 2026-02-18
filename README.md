# ai-reviewer

AI-powered dev workflow CLI. Extracts and standardizes the dev workflow (push, PR, commit-lint, AI review, AI lint) into a standalone Bash tool.

## Requirements

- **Bash 4+** (macOS: `brew install bash`)
- **git**
- **curl**

### Optional dependencies

| Tool | Purpose |
|------|---------|
| `gh` | GitHub CLI for PR creation |
| `jq` | JSON processing |
| `fzf` | Interactive selection |
| `lefthook` | Git hooks manager |
| `yq` | YAML processing (faster config parsing) |
| `shellcheck` | Shell script linting |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/jeanlondero/ai-reviewer/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/jeanlondero/ai-reviewer.git ~/.ai-reviewer
ln -sf ~/.ai-reviewer/bin/ai-reviewer /usr/local/bin/ai-reviewer
ln -sf ~/.ai-reviewer/bin/ai-reviewer /usr/local/bin/air
```

## Usage

```bash
ai-reviewer <command> [options]
air <command> [options]
```

### Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize ai-reviewer in the current project |
| `push` | Validate and push workflow |
| `pr` | Create pull request with AI-generated content |
| `commit-lint` | Validate conventional commit messages |
| `ai-review` | AI-powered code review |
| `ai-lint` | AI lint via git hooks |
| `config` | Manage global configuration |
| `doctor` | Health check: OS, bash, deps, config |
| `update` | Self-update ai-reviewer |
| `help` | Show help message |
| `version` | Print version |

### Options

```
--help, -h     Show help
--version, -v  Print version
--no-color     Disable colored output
```

### Examples

```bash
ai-reviewer doctor       # Check your setup
ai-reviewer ai-review    # Run AI code review
air push                 # Validate and push
air pr                   # Create a pull request
```

## Quick start

```bash
air config init    # Interactive setup wizard
air doctor         # Verify your setup
```

## Configuration

### Global config (`air config`)

Global settings are stored in `${AIR_CONFIG_DIR:-~/.config/ai-reviewer}/`:

| File | Purpose | Permissions |
|------|---------|-------------|
| `config` | Shareable settings (provider, model) | 644 |
| `credentials` | Secrets (API keys) | 600 |

```bash
air config init                    # Interactive setup wizard
air config set provider claude     # Set a value
air config get provider            # Get resolved value (shows source)
air config list                    # List all values (secrets masked)
air config unset provider          # Remove a key
air config path                    # Print config directory
air config edit                    # Open in $EDITOR
```

### Cascade priority

Values are resolved in this order (highest wins):

1. **Environment variables** (`AI_REVIEW_PROVIDER`, etc.)
2. **Project config** (`.ai-reviewer.yml`)
3. **Global config** (`~/.config/ai-reviewer/config`)
4. **Default**

### Project config (`.ai-reviewer.yml`)

Create `.ai-reviewer.yml` in your project root:

```yaml
# AI provider settings
provider: claude
model: claude-sonnet-4-20250514

# Review settings
review:
  strict: false
  skills_dir: docs/skills

# Commit lint
commit_lint:
  max_line_length: 110
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `AI_REVIEW_PROVIDER` | AI provider (claude, openai, gemini) |
| `AI_REVIEW_API_KEY` | API key for the provider |
| `AI_REVIEW_MODEL` | Model override |
| `AI_REVIEW_STRICT` | Block push on critical issues |
| `NO_COLOR` | Disable colored output |
| `AI_REVIEWER_HOME` | Custom install directory (default: `~/.ai-reviewer`) |

Environment variables can also be set via `.env` and `.env.development` files in your project root.

## Development

### Running tests

```bash
# Setup bats (first time)
git submodule update --init --recursive

# Run all tests
./test/bats/bin/bats test/core/

# Run specific test file
./test/bats/bin/bats test/core/colors.bats
```

### Running without install

```bash
export AIR_ROOT=/path/to/ai-reviewer
./bin/ai-reviewer --version
./bin/ai-reviewer help
./bin/ai-reviewer doctor
```

### ShellCheck

```bash
shellcheck lib/core/*.sh lib/commands/*.sh bin/ai-reviewer install.sh
```

## License

MIT
