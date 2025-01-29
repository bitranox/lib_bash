# lib_color.sh - Bash Terminal Color Library

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)  
![Part of lib_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

Part of the [lib_bash](https://github.com/bitranox/lib_bash) collection - A powerful Bash scripting utilities library.

### sourced : 
```bash
#!/bin/bash
source /usr/local/lib_color.sh
clr_bold clr_green "SUCCESS" clr_blue "Color output made easy"
```

### directly from the commandline :
```bash
/usr/local/lib_color.sh clr_green "SUCCESS" clr_blue "Color output made easy" 
```

## Features

- 8 foreground colors + 8 background colors
- Text styles (bold, underline, reverse)
- Chainable color/style combinations
- Color combination demo (`--dump`)
- Error/warning utilities
- Full ANSI code validation
- Cross-platform terminal support

## Installation

### As part of lib_bash
```bash
git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash
source /usr/local/lib_bash/lib_color.sh
```

### Standalone usage
```bash
curl -O https://raw.githubusercontent.com/bitranox/lib_bash/master/lib_color.sh
source lib_color.sh
```

## Quick Start

```bash
source /usr/local/lib_bash/lib_color.sh

# Basic formatted output
clr_red "Error message"
clr_greenb clr_white "Status update"

# Combined styles
clr_bold clr_underscore clr_cyan "Important notice"

# Utility functions
warn "Potential configuration issue"

# Show all color combinations
lib_color.sh --dump
```

## API Reference

### Text Formatting
| Function           | Description                    |
|--------------------|--------------------------------|
| `clr_bold`         | Bold text style                |
| `clr_underscore`   | Underlined text                |
| `clr_reverse`      | Reverse video effect           |

### Foreground Colors
```bash
clr_black "Text"    clr_red "Text"    clr_green "Text"
clr_yellow "Text"   clr_blue "Text"   clr_magenta "Text"  
clr_cyan "Text"     clr_white "Text"
```

### Background Colors
```bash
clr_blackb "Text"   clr_redb "Text"   clr_greenb "Text"
clr_yellowb "Text"  clr_blueb "Text"  clr_magentab "Text"
clr_cyanb "Text"    clr_whiteb "Text"
```

### Reset Functions
```bash
clr_reset           # Reset all attributes
clr_reset_underline # Remove underline
clr_default         # Default foreground
clr_defaultb        # Default background
```

## Advanced Usage

### Inline Formatting
```bash
echo "$(clr_bold "Bold") and $(clr_underline "underlined") text"
```

### Nested Styles
```bash
clr_redb "$(clr_bold "$(clr_white "White on red")")"
```

### Function Chaining
```bash
clr_bold "$(clr_underscore "$(clr_cyan "Styled text")")"
```

## Color Demo

Display all 896 possible color/style combinations:

```bash
/usr/local/lib_bash/lib_color.sh --dump
```

![Color Combination Demo](https://raw.githubusercontent.com/bitranox/lib_bash/master/docs/color_demo_screenshot.png)

## Requirements

- Bash 4.0+
- Terminal with ANSI color support

## License

GNU General Public License v3.0 - See [LICENSE](https://github.com/bitranox/lib_bash/blob/master/docs/LICENSE) file.

## lib_bash Ecosystem

Part of a comprehensive Bash utilities collection:
- **lib_color.sh** - Terminal color formatting
- **lib_bash.sh** - a bunch of small helpers and source the whole collection at once
- **lib_retry.sh** - the name is obviouse
- **self_update.sh** - make Your script self updating
- [View all modules...](https://github.com/bitranox/lib_bash)

## Contributing

Contributions welcome! Please follow lib_bash contribution guidelines:
1. Fork the repository
2. Create feature branch
3. Commit changes
4. Submit Pull Request

See [CONTRIBUTING.md](https://github.com/bitranox/lib_bash/blob/master/CONTRIBUTING.md) for details.

---

*Tested on: Linux  
*Part of the [lib_bash](https://github.com/bitranox/lib_bash) professional scripting toolkit*
