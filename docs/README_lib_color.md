Below is the **updated** `README.md` that includes a **screenshot of the color dump**. The screenshot link is a placeholder—replace it with your actual image file/location as needed (for example, in your GitHub repo’s `docs/` folder).

```markdown
# lib_color.sh - Bash Terminal Color Library

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)  
![Part of lib_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

Part of the [lib_bash](https://github.com/bitranox/lib_bash) collection - A powerful Bash scripting utilities library.

---

## Quick Example

You can **source** the library or run it directly for one-off commands:

```bash
#!/bin/bash
source /usr/local/lib_color.sh

clr_bold clr_green "SUCCESS" clr_blue "Color output made easy"
```

Or from the command line:

```bash
/usr/local/lib_color.sh clr_green "SUCCESS" clr_blue "Color output made easy"
```

---

## Features

- **8 basic foreground** + **8 basic background** colors
- **Bright colors** (90..97 FG, 100..107 BG)
- **256-color mode** (via `clr_256fg CODE` and `clr_256bg CODE`)
- **Text styles**: bold, underline, reverse, **italic**, **blink**
- **Chainable** color/style combinations
- **Color combination demo** (`--dump`) — includes **256-color** FG/BG tables
- **Full ANSI code validation** (rejects invalid codes)
- **Cross-platform** terminal support (Linux, macOS, etc.)

> **Note**: Some terminals **ignore** italic or blink for accessibility reasons, so you may not see them visually.

---

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

---

## Quick Start

```bash
source /usr/local/lib_bash/lib_color.sh

# Basic formatted output
clr_red "Error message"
clr_greenb clr_white "Status update"

# Combined styles
clr_bold clr_underscore clr_cyan "Important notice"

# Extended styles
clr_italic "This might appear slanted"
clr_blink  "This might blink, depending on your terminal"

# Bright colors
clr_bright_red "Bright Red Text"
clr_bright_yellowb "Bright Yellow Background"

# 256-color usage
clr_256fg 196 "Foreground color #196"
clr_256bg 82  "Background color #82"

# Show all color combinations (including 256-colors)
lib_color.sh --dump
```

---

## Usage and API Reference

### Text Attributes

| Function         | Effect                       | Notes                                            |
|------------------|------------------------------|--------------------------------------------------|
| `clr_bold`       | Bold text                   |                                                  |
| `clr_underscore` | Underlined text             |                                                  |
| `clr_reverse`    | Reverse video               |                                                  |
| `clr_italic`     | Italic text (SGR 3)         | May not be shown by all terminals               |
| `clr_blink`      | Blinking text (SGR 5)       | Often disabled in modern terminals by default   |

### Foreground Colors (Basic 8)
```
clr_black     clr_red     clr_green    clr_yellow
clr_blue      clr_magenta clr_cyan     clr_white
```

### Background Colors (Basic 8)
```
clr_blackb    clr_redb    clr_greenb   clr_yellowb
clr_blueb     clr_magentab clr_cyanb   clr_whiteb
```

### Bright Foreground Colors (90..97)
```
clr_bright_black  clr_bright_red   clr_bright_green
clr_bright_yellow clr_bright_blue  clr_bright_magenta
clr_bright_cyan   clr_bright_white
```

### Bright Background Colors (100..107)
```
clr_bright_blackb  clr_bright_redb   clr_bright_greenb
clr_bright_yellowb clr_bright_blueb  clr_bright_magentab
clr_bright_cyanb   clr_bright_whiteb
```

### 256-Color Mode
Use `clr_256fg N` for a **foreground** or `clr_256bg N` for a **background**, where **N** ranges `0..255`:

```bash
clr_256fg 196 "Hello #196"
clr_256bg 82  "Text on #82 background"
```

### Reset Functions

```bash
clr_reset            # Reset all attributes
clr_reset_underline  # Remove underline
clr_reset_reverse    # Remove reverse
clr_default          # Default foreground color
clr_defaultb         # Default background color
```

---

## Advanced Usage

### Chaining Functions

All color/attribute functions can be chained. For example:
```bash
clr_bold "$(clr_underscore "$(clr_cyan "Styled text")")"
```
or
```bash
clr_blink clr_bold clr_red "Blinking, bold, red text (if your terminal supports blink...)"
```

### Inline Formatting in Echo
```bash
echo "$(clr_bold "Bold") and $(clr_italic "italic") text"
```

### Nested Styles
```bash
clr_redb "$(clr_bold "$(clr_white "White on red")")"
```

---

## Color Demo

Use:
```bash
/usr/local/lib_bash/lib_color.sh --dump
```
to display **all** standard and bright combos, plus a **256-color** FG/BG matrix, including italic and blink columns.

![Color Dump Demo1](https://raw.githubusercontent.com/bitranox/lib_bash/master/docs/lib_color_Screenshot1.png "Sample color dump screenshot")

![Color Dump Demo2](https://raw.githubusercontent.com/bitranox/lib_bash/master/docs/lib_color_Screenshot2.png "Sample color dump screenshot")

![Color Dump Demo3](https://raw.githubusercontent.com/bitranox/lib_bash/master/docs/lib_color_Screenshot3.png "Sample color dump screenshot")

![Color Dump Demo4](https://raw.githubusercontent.com/bitranox/lib_bash/master/docs/lib_color_Screenshot4.png "Sample color dump screenshot")


---

## Testing

A complete test script (`test_lib_color.sh`) covers:

- Basic color output
- 256-color usage
- Attributes (bold, underline, reverse, italic, blink)
- Bright colors
- Error handling for invalid codes
- Full coverage of chaining logic

Run:
```bash
chmod +x test_lib_color.sh
./test_lib_color.sh
```
You should see a summary of “✓” (pass) or “✗” (fail) lines, ending with “All tests passed!” if everything’s good.

---

## Requirements

- Bash 4.0+  
- Terminal with ANSI color support (most modern terminals)  
- **Italic** and **blink** may not visibly render in all terminals

---

## License

GNU General Public License v3.0 – See [LICENSE](https://github.com/bitranox/lib_bash/blob/master/docs/LICENSE) for details.

---

## lib_bash Ecosystem

This script is part of a comprehensive Bash utilities collection:

- **lib_color.sh** – Terminal color formatting (this library)  
- **lib_bash.sh** – A bunch of small helpers and environment setups  
- **lib_retry.sh** – Retry logic for commands that might fail intermittently  
- **self_update.sh** – Make your script self-updating  
- [View all modules...](https://github.com/bitranox/lib_bash)

---

## Contributing

Contributions welcome! Please follow the standard procedure:

1. Fork the repository  
2. Create a feature branch  
3. Commit your changes  
4. Submit a Pull Request  

See [CONTRIBUTING.md](https://github.com/bitranox/lib_bash/blob/master/docs/CONTRIBUTING.md) for more details.

---

*Tested on: Linux, macOS.  
*Part of the [lib_bash](https://github.com/bitranox/lib_bash) professional scripting toolkit.*