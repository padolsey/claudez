# One-Shot Prompts with OpenCode

## Overview

You can now send **one-shot prompts** to OpenCode zones without entering the TUI, perfect for quick queries, automation, and scripting.

## Usage

```bash
# Simple prompt
cz prompt <zone> "your prompt here"

# Or use the short alias 'p'
cz p <zone> "your prompt"
```

## Examples

### Quick Questions
```bash
cz p myapp "What is 2+2?"
# Output: 2 + 2 equals 4.
```

### Code Analysis
```bash
cz p myapp "Explain what the code in app/page.tsx does"
```

### File Listing
```bash
cz p myapp "List all files in this project with brief descriptions"
```

### TODO Hunting
```bash
cz p myapp "Find all TODO comments in the codebase"
```

### Quick Fixes
```bash
cz p myapp "Add a TypeScript interface for a User with name, email, and age"
```

## Model Configuration

The prompt uses the **default model** configured in the zone's OpenCode settings.

### Check Current Model
```bash
cz shell myapp
cat /workspace/.opencode/opencode.json | grep '"model"'
```

### Change Model
```bash
# Enter the zone
cz shell myapp

# Edit config
vim /workspace/.opencode/opencode.json

# Change this line:
"model": "openrouter/gemini-flash-free",  # ← Change to your preferred model
```

### Available Models (OpenRouter zones)

Default zones created with `--oc` include these models:

- `openrouter/gemini-flash-free` - **FREE** (default)
- `openrouter/gemini-pro` - Gemini Pro 1.5
- `openrouter/claude-sonnet` - Claude Sonnet 4
- `openrouter/gpt4-turbo` - GPT-4 Turbo
- `openrouter/deepseek-chat` - DeepSeek Chat

### Adding Custom Models

Edit `/workspace/.opencode/opencode.json`:

```json
{
  "provider": {
    "openrouter": {
      "models": {
        "gemini-2.5-flash": {
          "name": "Gemini 2.5 Flash",
          "id": "google/gemini-2.5-flash"
        }
      }
    }
  },
  "model": "openrouter/gemini-2.5-flash"
}
```

The format is:
- **Key**: Short name you'll use (e.g., `gemini-2.5-flash`)
- **ID**: Full model identifier on OpenRouter (e.g., `google/gemini-2.5-flash`)
- **model**: Set to `openrouter/<key>` for default

## Full Workflow Example

```bash
# 1. Create OpenCode zone with your API key
export OPENROUTER_API_KEY="sk-or-v1-..."
cz myapp --oc

# 2. Send one-shot prompts
cz p myapp "What is the capital of France?"
cz p myapp "Create a React component for a login form"
cz p myapp "Explain the difference between let and const"

# 3. Change model if needed
cz shell myapp
vim /workspace/.opencode/opencode.json
# Update "model" field

# 4. Continue with new model
cz p myapp "Write a Python function to sort a list"
```

## Automation & Scripting

Perfect for CI/CD or automated workflows:

```bash
#!/bin/bash
# analyze.sh - Automated code review

ZONE="review-bot"
FILES=$(git diff --name-only HEAD~1)

for file in $FILES; do
  echo "Analyzing $file..."
  cz p $ZONE "Review this file for potential issues: $file"
done
```

## Tips

1. **Use quotes** for multi-word prompts
2. **Escape special characters** in shell if needed
3. **Zone must be running** - it will auto-start if stopped
4. **OpenCode only** - won't work with Claude Code zones
5. **Output is formatted** - includes tool calls and final response

## Limitations

- Model selection via CLI flag doesn't work reliably (use config instead)
- Requires zone created with `--oc` flag
- No streaming output (waits for complete response)
- Uses OpenCode's `run` command under the hood

## Help

```bash
cz prompt --help
```

## See Also

- `OPENCODE_INTEGRATION.md` - Full OpenCode integration guide
- `README.md` - claudez main documentation
