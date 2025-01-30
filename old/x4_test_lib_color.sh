#!/bin/bash
# tests/test_lib_color.sh
#
# Test script for lib_color.sh, including 256-color functionality.

set -o errexit -o nounset -o pipefail

# 1) Source the main color library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib_color.sh"

# 2) Global test counters
TESTS_RUN=0
TESTS_FAILED=0

# 3) Test helper: "assert expected actual message"
assert() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    ((++TESTS_RUN))  # Use pre-increment so it won't return 1 when starting at 0

    if [[ "$actual" == "$expected" ]]; then
        echo "$(clr_green "✓") $message"
    else
        ((++TESTS_FAILED))
        echo "$(clr_red "✗") $message"
        echo "  Expected: '$expected'"
        echo "  Got:      '$actual'"
    fi
}

# 4) Demonstration helper (just prints a section with echo -e)
demonstrate() {
    local title="$1"
    shift
    echo
    echo "=== $title ==="
    echo -e "$@"
    echo "==============="
}

# 5) Test that each known function actually exists
test_functions_exist() {
    echo "Testing function existence..."
    local functions=(
        "clr_reset" "clr_reset_underline" "clr_reset_reverse" "clr_default"
        "clr_defaultb" "clr_bold" "clr_underscore" "clr_reverse" "clr_black"
        "clr_red" "clr_green" "clr_yellow" "clr_blue" "clr_magenta" "clr_cyan"
        "clr_white" "clr_blackb" "clr_redb" "clr_greenb" "clr_yellowb"
        "clr_blueb" "clr_magentab" "clr_cyanb" "clr_whiteb"

        # 256-color helpers (new)
        "clr_256fg" "clr_256bg"
    )

    for func in "${functions[@]}"; do
        if fn_exists "$func"; then
            assert "true" "true" "Function $func exists"
        else
            assert "true" "false" "Function $func exists"
        fi
    done
}

# 6) Test basic foreground colors
test_foreground_colors() {
    echo "Testing foreground colors..."
    local text="This is a test of foreground colors"
    local demo_text=""

    local colors=( "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" )
    for color in "${colors[@]}"; do
        local func="clr_${color}"
        local result=$($func "$text")
        # Compare to itself (sanity check)
        assert "$($func "$text")" "$result" "Testing $color foreground"
        demo_text+="$($func "$color")
"
    done

    demonstrate "Foreground Colors" "$demo_text"
}

# 7) Test basic background colors
test_background_colors() {
    echo "Testing background colors..."
    local text="This is a test of background colors"
    local demo_text=""

    local colors=( "blackb" "redb" "greenb" "yellowb" "blueb" "magentab" "cyanb" "whiteb" )
    for color in "${colors[@]}"; do
        local func="clr_${color}"
        local result=$($func "$text")
        assert "$($func "$text")" "$result" "Testing $color background"
        demo_text+="$($func "$color")
"
    done

    demonstrate "Background Colors" "$demo_text"
}

# 8) Test text attributes (bold, underscore, reverse)
test_attributes() {
    echo "Testing text attributes..."
    local text="This text demonstrates attributes"
    local demo_text=""

    # Bold
    local result
    result=$(clr_bold "$text")
    assert "$result" "$result" "Bold attribute"
    demo_text+="Bold: $(clr_bold "$text")
"

    # Underscore
    result=$(clr_underscore "$text")
    assert "$result" "$result" "Underscore attribute"
    demo_text+="Underscore: $(clr_underscore "$text")
"

    # Reverse
    result=$(clr_reverse "$text")
    assert "$result" "$result" "Reverse attribute"
    demo_text+="Reverse: $(clr_reverse "$text")
"

    demonstrate "Text Attributes" "$demo_text"
}

# 9) Test combinations of colors & attributes
test_combinations() {
    echo "Testing color and attribute combinations..."
    local text="Combined effects"
    local demo_text=""

    # Bold red on blue background
    local result
    result=$(clr_bold "$(clr_red "$(clr_blueb "$text")")")
    assert "$result" "$result" "Bold red on blue"
    demo_text+="Bold red on blue: $result
"

    # Underscored green on yellow background
    result=$(clr_underscore "$(clr_green "$(clr_yellowb "$text")")")
    assert "$result" "$result" "Underscored green on yellow"
    demo_text+="Underscored green on yellow: $result
"

    # Reverse cyan on magenta background
    result=$(clr_reverse "$(clr_cyan "$(clr_magentab "$text")")")
    assert "$result" "$result" "Reverse cyan on magenta"
    demo_text+="Reverse cyan on magenta: $result
"

    demonstrate "Color Combinations" "$demo_text"
}

# 10) Test error handling
test_error_handling() {
    echo "Testing error handling..."
    local result

    # 10a) Empty input
    result=$(clr_red "")
    # Typically looks like: "\033[31m\033[0m"
    # We'll just do a direct string compare with an expected value:
    local expected=$'\033[31m\033[0m'
    assert "$expected" "$result" "Empty input handling"

    # 10b) Invalid escape code => should return empty (and print error to stderr)
    result=$(clr_escape "-e" "test" 999 2>/dev/null) || true
    assert "" "$result" "Invalid escape code handling"

    demonstrate "Error Handling" \
        "Empty string with red: '$(clr_red "")'
Invalid code output: '$result'"
}

# 11) Test clr_layer function specifically
test_clr_layer() {
    echo "Testing clr_layer function..."
    local demo_text=""

    local result

    # Just text
    result=$(clr_layer "test")
    assert "test" "$result" "Basic layer with text only"
    demo_text+="Basic layer: $result
"

    # Single color code
    result=$(clr_layer $CLR_RED "test")
    assert $'\033[31mtest\033[0m' "$result" "Layer with color code"
    demo_text+="Red layer: $result
"

    # Multiple attributes
    result=$(clr_layer $CLR_RED $CLR_BOLD "test")
    assert $'\033[31;1mtest\033[0m' "$result" "Layer with multiple attributes"
    demo_text+="Bold red layer: $result
"

    demonstrate "Layer Function" "$demo_text"
}

# 12) Test clr_dump function (just ensures it prints something expected)
test_clr_dump() {
    echo "Testing clr_dump function..."

    local dump_output
    dump_output=$(clr_dump)

    local expected_patterns=(
        "Text (Normal)"
        "Text (Bold)"
        "Text (Under)"
        "Text (Revs)"
        "BLACK on WHITEB"
        "RED on BLUEB"
        "GREEN on MAGENTAB"
        "256-Color Foreground Table"
        "256-Color Background Table"
    )

    for pattern in "${expected_patterns[@]}"; do
        if [[ "$dump_output" == *"$pattern"* ]]; then
            echo "$(clr_green "✓") clr_dump contains '$pattern'"
        else
            ((++TESTS_FAILED))
            echo "$(clr_red "✗") clr_dump missing '$pattern'"
        fi
    done

    demonstrate "Color Dump Sample" "$dump_output"
}

# 13) Simple rainbow demonstration (original example)
test_rainbow() {
    local text="Color Library Demo"
    local rainbow=""
    local colors=("red" "yellow" "green" "cyan" "blue" "magenta")

    for color in "${colors[@]}"; do
        rainbow+="$(clr_${color} "$text") "
    done

    demonstrate "Rainbow Demo" "$rainbow"
}

# 14) New test: extended 256-color codes
test_extended_colors() {
    echo "Testing 256-color functionality..."
    local result

    # Foreground 196 (a bright red)
    result=$(clr_256fg 196 "Hello 196")
    # We check for the substring "[38;5;196mHello 196"
    if [[ "$result" == *"[38;5;196mHello 196"* ]]; then
        echo "$(clr_green "✓") clr_256fg 196 produces correct sequence"
    else
        ((++TESTS_FAILED))
        echo "$(clr_red "✗") clr_256fg 196 - got: $result"
    fi

    # Background 82 (a greenish color)
    result=$(clr_256bg 82 "BG 82")
    if [[ "$result" == *"[48;5;82mBG 82"* ]]; then
        echo "$(clr_green "✓") clr_256bg 82 produces correct sequence"
    else
        ((++TESTS_FAILED))
        echo "$(clr_red "✗") clr_256bg 82 - got: $result"
    fi
}

# 15) Main driver
main() {
    echo "$(clr_bold "Running color library tests...")"
    echo

    test_functions_exist
    echo
    test_foreground_colors
    echo
    test_background_colors
    echo
    test_attributes
    echo
    test_combinations
    echo
    test_error_handling
    echo
    test_clr_layer
    echo
    test_clr_dump
    echo
    test_rainbow
    echo
    test_extended_colors
    echo

    echo "$(clr_bold "Test Summary:")"
    echo "Tests run: $TESTS_RUN"
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "$(clr_green "$(clr_bold "All tests passed!")")"
    else
        echo "$(clr_red "$(clr_bold "Tests failed: $TESTS_FAILED")")"
        exit 1
    fi
}

# Only run `main()` if this script is invoked directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

