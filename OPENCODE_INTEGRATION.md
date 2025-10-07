# OpenCode Integration

## Overview

claudez now supports **OpenCode** as an alternative AI agent alongside Claude Code. Users can choose their preferred agent and provider when creating zones.

## Quick Start

```bash
# Default: Claude Code with Anthropic
cz myapp

# NEW: OpenCode with OpenRouter (free models available)
cz myapp --oc

# OpenCode with Anthropic
cz myapp --oc-anthropic

# OpenCode with custom provider
cz myapp --oc-custom
```

## Features

### 1. **Dual Agent Support**
- **Claude Code** (default): Anthropic's official coding agent
- **OpenCode**: Open-source, multi-provider agent with TUI

### 2. **Multiple Provider Support**
- **OpenRouter**: Access 75+ models (Gemini, Claude, GPT-4, DeepSeek, etc.) with one API key
- **Anthropic Direct**: Use your Anthropic API key with OpenCode
- **Custom Providers**: Configure any OpenAI-compatible API

### 3. **Interactive Setup**
When creating a zone with `--oc`, if no API key is found:
- Opens browser to get OpenRouter API key
- Prompts to paste key
- Offers to save for future zones
- Beautiful formatted output with available models

### 4. **Pre-configured Models**
OpenRouter zones come with 5 models ready to use:
- `gemini-flash-free` (FREE) - Default
- `gemini-pro`
- `claude-sonnet`
- `gpt4-turbo`
- `deepseek-chat`

Users can switch models instantly inside OpenCode with `Ctrl+x m`.

## Usage Examples

### Create Zone with OpenRouter

```bash
# Interactive (will prompt for key if needed)
cz demo --oc

# Non-interactive (requires env var)
export OPENROUTER_API_KEY="sk-or-v1-..."
cz demo --oc --no-interactive
```

### Use Inside Zone

```bash
cz enter demo

# Launch OpenCode
opencode

# Inside OpenCode:
# - Press Ctrl+x then m to switch models
# - Type "/models" to see available models
# - Start coding: "Add a login page"
```

### Custom Provider Example

```bash
# Interactive setup
cz myapp --oc-custom

# Will prompt for:
# - Provider name
# - API base URL
# - API key
```

## Configuration Files

### OpenCode Config Location
`/workspace/.opencode/opencode.json`

### Environment Variables
- `OPENROUTER_API_KEY`: For OpenRouter provider
- `ANTHROPIC_API_KEY`: For Anthropic (direct or via OpenCode)
- `CUSTOM_API_KEY`: For custom providers
- `CUSTOM_BASE_URL`: For custom providers

### Config Templates
Located in `templates/`:
- `opencode-config.openrouter.json.tmpl`
- `opencode-config.anthropic.json.tmpl`
- `opencode-config.custom.json.tmpl`

## API Keys Management

### Option 1: Environment Variables
```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Option 2: Config Files
```bash
echo "sk-or-v1-..." > ~/.config/claudez/openrouter_key
echo "sk-ant-..." > ~/.config/claudez/anthropic_key
```

### Option 3: Interactive Prompts
Just run `cz myapp --oc` and you'll be guided through setup.

## Command Reference

```bash
# Agent flags
--oc                  # OpenCode with OpenRouter
--oc-anthropic        # OpenCode with Anthropic
--oc-custom           # OpenCode with custom provider

# Long form
--agent=opencode      # Explicit agent selection
--provider=openrouter # Explicit provider selection

# Other flags
--no-interactive      # Skip prompts (for CI/automation)
--verify              # Verify Traefik routing
--large               # Use 5GB memory limit
```

## Architecture

### Docker Image
Both agents are installed in every container:
- `/usr/local/bin/claude` - Claude Code
- `/usr/local/bin/opencode` - OpenCode

### Config Generation
When `--oc` is used:
1. Validates/prompts for API key
2. Adds key to `/path/to/zone/.env`
3. Creates `/workspace/.opencode/opencode.json` with provider config
4. Sets appropriate permissions (user 10001)

### Success Message
OpenCode zones show a fancy box with:
- Zone URLs
- Agent info
- Available models
- Quick start commands

## Benefits

1. **Cost Flexibility**: Start with free Gemini, upgrade to Claude for complex tasks
2. **Provider Agnostic**: Not locked into Anthropic
3. **Model Switching**: Change models mid-session without recreating zone
4. **Future Proof**: As new models launch, just update the JSON config
5. **Developer Choice**: Use Claude Code OR OpenCode in any zone

## Implementation Files

### New Files
- `lib/interactive.sh` - Interactive prompts and UI helpers
- `templates/opencode-config.*.json.tmpl` - OpenCode config templates
- `OPENCODE_INTEGRATION.md` - This document

### Modified Files
- `templates/Dockerfile.tmpl` - Added `opencode-ai` to npm install
- `bin/claudez-create` - Added agent/provider flags and setup logic
- `conf/defaults.env` - Added `OPENROUTER_API_KEY_FILE`

## Testing

Verified working:
- ✅ OpenCode installation in container
- ✅ Config file generation with proper permissions
- ✅ Environment variable injection
- ✅ Both `claude` and `opencode` binaries available
- ✅ Help text shows new flags
- ✅ `--oc` shorthand works
- ✅ Non-interactive mode works

## Future Enhancements

Potential additions:
- Add more default models to templates
- Support for provider presets (e.g., `--groq`, `--fireworks`)
- Per-agent configurations in `~/.claudezrc`
- Model usage statistics
- Auto-update OpenCode config with new models
