# Customizing Models in OpenCode Zones

## Quick Reference

### Using `cz run` with Custom Models

The **easiest** way - specify model on command line:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."

# Use any OpenRouter model
cz run -m "google/gemini-2.5-flash" "Your prompt here"
cz run -m "anthropic/claude-3.5-sonnet" "Explain this code"
cz run -m "openai/gpt-4-turbo" "Write a function"
```

The `-m` flag automatically:
1. Creates/updates the OpenCode config
2. Adds the model
3. Sets it as default
4. Runs your prompt

### Permanent Model Configuration

For reusable zones, edit the config manually:

```bash
# Enter your zone
cz shell myapp

# Edit OpenCode config
vim /workspace/.opencode/opencode.json
```

## Config File Structure

Location: `/workspace/.opencode/opencode.json`

### Basic Structure

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "openrouter": {
      "options": {
        "apiKey": "{env:OPENROUTER_API_KEY}",
        "baseURL": "https://openrouter.ai/api/v1"
      },
      "models": {
        "model-key": {
          "name": "Display Name",
          "id": "provider/model-id-on-openrouter"
        }
      }
    }
  },
  "model": "openrouter/model-key",
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow"
  }
}
```

### Key Parts Explained

1. **Model Key** (e.g., `gemini-2.5-flash`):
   - Short name you'll reference
   - Can be anything (no special chars)
   - Used in: `"model": "openrouter/YOUR-KEY"`

2. **Model ID** (e.g., `google/gemini-2.5-flash`):
   - Actual model identifier on OpenRouter
   - Find at: https://openrouter.ai/models
   - Format: `provider/model-name`

3. **Default Model**:
   - Set in `"model"` field at root level
   - Format: `"provider-name/model-key"`
   - Example: `"openrouter/gemini-2.5-flash"`

## Examples

### Example 1: Google Gemini 2.5 Flash

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "openrouter": {
      "options": {
        "apiKey": "{env:OPENROUTER_API_KEY}",
        "baseURL": "https://openrouter.ai/api/v1"
      },
      "models": {
        "gemini-2.5-flash": {
          "name": "Gemini 2.5 Flash",
          "id": "google/gemini-2.5-flash"
        }
      }
    }
  },
  "model": "openrouter/gemini-2.5-flash",
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow"
  }
}
```

Usage:
```bash
cz prompt myapp "Your prompt"  # Uses gemini-2.5-flash
```

### Example 2: Multiple Models

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "openrouter": {
      "options": {
        "apiKey": "{env:OPENROUTER_API_KEY}",
        "baseURL": "https://openrouter.ai/api/v1"
      },
      "models": {
        "gemini-flash": {
          "name": "Gemini 2.5 Flash",
          "id": "google/gemini-2.5-flash"
        },
        "claude-sonnet": {
          "name": "Claude Sonnet 4",
          "id": "anthropic/claude-sonnet-4"
        },
        "gpt4": {
          "name": "GPT-4 Turbo",
          "id": "openai/gpt-4-turbo"
        },
        "deepseek": {
          "name": "DeepSeek R1",
          "id": "deepseek/deepseek-r1"
        }
      }
    }
  },
  "model": "openrouter/gemini-flash",
  "agent": {
    "build": {
      "model": "openrouter/claude-sonnet",
      "description": "For complex code modifications"
    },
    "plan": {
      "model": "openrouter/gpt4",
      "description": "For planning"
    }
  },
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow"
  }
}
```

Inside OpenCode TUI:
- Press `Ctrl+x` then `m` to switch models
- See all 4 models in the list
- Switch instantly without restarting

### Example 3: Free Models Only

```json
{
  "provider": {
    "openrouter": {
      "options": {
        "apiKey": "{env:OPENROUTER_API_KEY}",
        "baseURL": "https://openrouter.ai/api/v1"
      },
      "models": {
        "gemini-free": {
          "name": "Gemini 2.0 Flash (FREE)",
          "id": "google/gemini-2.0-flash-exp:free"
        },
        "llama-free": {
          "name": "Llama 3.3 70B (FREE)",
          "id": "meta-llama/llama-3.3-70b-instruct:free"
        }
      }
    }
  },
  "model": "openrouter/gemini-free"
}
```

## Finding Model IDs

### OpenRouter Model Directory

Visit: https://openrouter.ai/models

Each model shows:
- **Model ID**: Copy this for the `"id"` field
- **Pricing**: Check if it's free or paid
- **Context**: How much text it can handle

### Popular Models

| Display Name | Model ID | Cost |
|--------------|----------|------|
| Gemini 2.5 Flash | `google/gemini-2.5-flash` | Paid |
| Gemini 2.0 Flash Free | `google/gemini-2.0-flash-exp:free` | FREE |
| Claude Sonnet 4 | `anthropic/claude-sonnet-4` | Paid |
| Claude Sonnet 3.5 | `anthropic/claude-3.5-sonnet` | Paid |
| GPT-4 Turbo | `openai/gpt-4-turbo` | Paid |
| GPT-4o | `openai/gpt-4o` | Paid |
| DeepSeek R1 | `deepseek/deepseek-r1` | Paid |
| Llama 3.3 70B Free | `meta-llama/llama-3.3-70b-instruct:free` | FREE |

## Workflows

### Workflow 1: Test Different Models

```bash
# Create zone
cz demo --oc

# Try different models
cz run -z demo -m "google/gemini-2.5-flash" "Explain async/await"
cz run -z demo -m "anthropic/claude-3.5-sonnet" "Explain async/await"
cz run -z demo -m "openai/gpt-4-turbo" "Explain async/await"

# Compare answers, pick your favorite
```

### Workflow 2: Set and Forget

```bash
# Create zone
cz myproject --oc

# Set preferred model once
cz shell myproject
vim /workspace/.opencode/opencode.json
# Set "model": "openrouter/your-preferred-model"

# Use forever
cz prompt myproject "Any prompt"
cz prompt myproject "Another prompt"
```

### Workflow 3: Project-Specific Models

```bash
# Backend project: use DeepSeek (good at code)
cz api --oc
cz shell api
# Configure: "model": "openrouter/deepseek"

# Documentation: use GPT-4 (good at writing)
cz docs --oc
cz shell docs
# Configure: "model": "openrouter/gpt4"

# Quick tasks: use free Gemini
cz scratch --oc
# Default config already has gemini-free
```

## Troubleshooting

### Error: Model Not Found

If you see `ProviderModelNotFoundError`:

1. **Check spelling** - Model IDs are case-sensitive
2. **Check OpenRouter** - Model might be unavailable
3. **Rebuild config** - Try deleting and recreating

### Check Current Model

```bash
cz shell myapp
cat /workspace/.opencode/opencode.json | grep '"model"'
```

### Reset to Default

```bash
cz shell myapp
rm /workspace/.opencode/opencode.json

# Recreate zone (or manually restore from template)
cz reset myapp --oc
```

## Advanced: Per-Agent Models

Different models for different tasks:

```json
{
  "model": "openrouter/gemini-flash",
  "agent": {
    "build": {
      "model": "openrouter/claude-sonnet",
      "description": "Use expensive Claude for complex builds"
    },
    "plan": {
      "model": "openrouter/gpt4",
      "description": "Use GPT-4 for planning"
    },
    "general": {
      "model": "openrouter/gemini-flash",
      "description": "Use cheap Gemini for everything else"
    }
  }
}
```

OpenCode will automatically pick the right model based on task type!

## Summary

**Easiest**: `cz run -m "google/gemini-2.5-flash" "prompt"`

**Most flexible**: Edit `/workspace/.opencode/opencode.json`

**Best practice**:
- Use cheap models for iteration
- Switch to expensive models for final output
- Configure multiple models in config for easy switching
