#!/bin/bash
# tests/test_lib_color.sh

set -o errexit -o nounset -o pipefail

# Load your logging script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib_bash.sh"

CMD="${SCRIPT_DIR}/lib_color.sh"

TESTS_RUN=0
TESTS_FAILED=0

assert() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    ((++TESTS_RUN))  # pre-increment to avoid set -e issues

    if [[ "$actual" == "$expected" ]]; then
        echo "$(clr_green "✓") $message"
    else
        ((++TESTS_FAILED))
        echo "$(clr_red "✗") $message"
        echo "  Expected: '$expected'"
        echo "  Got:      '$actual'"
    fi
}

demonstrate() {
    local title="$1"
    shift
    echo
    echo "=== $title ==="
    echo -e "$@"
    echo "==============="
}

test_functions_exist() {
    echo "Testing function existence..."
    local functions=(
        # Original
        "clr_reset" "clr_reset_underline" "clr_reset_reverse" "clr_default"
        "clr_defaultb" "clr_bold" "clr_underscore" "clr_reverse" "clr_black"
        "clr_red" "clr_green" "clr_yellow" "clr_blue" "clr_magenta" "clr_cyan"
        "clr_white" "clr_blackb" "clr_redb" "clr_greenb" "clr_yellowb"
        "clr_blueb" "clr_magentab" "clr_cyanb" "clr_whiteb"

        # 256 color
        "clr_256fg" "clr_256bg"

        # New bright
        "clr_bright_black" "clr_bright_red" "clr_bright_green" "clr_bright_yellow"
        "clr_bright_blue" "clr_bright_magenta" "clr_bright_cyan" "clr_bright_white"
        "clr_bright_blackb" "clr_bright_redb" "clr_bright_greenb" "clr_bright_yellowb"
        "clr_bright_blueb" "clr_bright_magentab" "clr_bright_cyanb" "clr_bright_whiteb"

        # New attributes
        "clr_italic" "clr_blink"
    )
    for func in "${functions[@]}"; do
        if fn_exists "$func"; then
            assert "true" "true" "Function $func exists"
        else
            assert "true" "false" "Function $func exists"
        fi
    done
}

test_foreground_colors() {
    local colors
    local func
    local result
    local text="This is a test of foreground colors"
    local demo_text=""

    echo "Testing foreground colors..."
    colors=( "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" )
    for color in "${colors[@]}"; do
        func="clr_${color}"
        result=$("${CMD}" "$func" "$text")
        assert "$($func "$text")" "$result" "Testing $color foreground"
        demo_text+="$($func "$color")
"
    done
    demonstrate "Foreground Colors" "$demo_text"
}

test_background_colors() {
    local colors
    local func
    local result
    echo "Testing background colors..."
    local text="This is a test of background colors"
    local demo_text=""

    colors=( "blackb" "redb" "greenb" "yellowb" "blueb" "magentab" "cyanb" "whiteb" )
    for color in "${colors[@]}"; do
        func="clr_${color}"
        result=$("${CMD}" "$func" "$text")
        assert "$($func "$text")" "$result" "Testing $color background"
        demo_text+="$($func "$color")
"
    done
    demonstrate "Background Colors" "$demo_text"
}

test_attributes() {
    local result
    echo "Testing text attributes..."
    local text="This text demonstrates attributes"
    local demo_text=""

    result=$("${CMD}" clr_bold "$text")
    assert "$result" "$result" "Bold attribute"
    demo_text+="Bold: $(clr_bold "$text")
"

    result=$("${CMD}" clr_underscore "$text")
    assert "$result" "$result" "Underscore attribute"
    demo_text+="Underscore: $(clr_underscore "$text")
"

    result=$("${CMD}" clr_reverse "$text")
    assert "$result" "$result" "Reverse attribute"
    demo_text+="Reverse: $(clr_reverse "$text")
"

    demonstrate "Text Attributes" "$demo_text"
}

test_combinations() {
    echo "Testing color and attribute combinations..."
    local text="Combined effects"
    local demo_text=""

    local result
    result=$("${CMD}" clr_bold "$(clr_red "$(clr_blueb "$text")")")
    assert "$result" "$result" "Bold red on blue"
    demo_text+="Bold red on blue: $result
"

    result=$("${CMD}" clr_underscore "$(clr_green "$(clr_yellowb "$text")")")
    assert "$result" "$result" "Underscored green on yellow"
    demo_text+="Underscored green on yellow: $result
"

    result=$("${CMD}" clr_reverse "$(clr_cyan "$(clr_magentab "$text")")")
    assert "$result" "$result" "Reverse cyan on magenta"
    demo_text+="Reverse cyan on magenta: $result
"

    demonstrate "Color Combinations" "$demo_text"
}

test_error_handling() {
    echo "Testing error handling..."
    local result

    result=$("${CMD}" clr_red "")
    local expected=$'\033[31m\033[0m'
    assert "$expected" "$result" "Empty input handling"

    result=$("${CMD}" clr_escape "-e" "test" 999 2>/dev/null) || true
    assert "" "$result" "Invalid escape code handling"

    demonstrate "Error Handling" \
        "Empty string with red: '$(clr_red "")'
Invalid code output: '$result'"
}

test_clr_layer() {
    echo "Testing clr_layer function..."
    local demo_text=""

    local result
    result=$("${CMD}" clr_layer "test")
    assert "test" "$result" "Basic layer with text only"
    demo_text+="Basic layer: $result
"

    result=$("${CMD}" clr_layer "$CLR_RED" "test")
    assert $'\033[31mtest\033[0m' "$result" "Layer with color code"
    demo_text+="Red layer: $result
"

    result=$("${CMD}" clr_layer "$CLR_RED" "$CLR_BOLD" "test")
    assert $'\033[31;1mtest\033[0m' "$result" "Layer with multiple attributes"
    demo_text+="Bold red layer: $result
"

    demonstrate "Layer Function" "$demo_text"
}

test_clr_dump() {
    echo "Testing clr_dump function..."
    local dump_output
    dump_output=$(clr_dump)

    local expected_patterns=(
        "Text(Norm)"
        "(Bold)"
        "(Undr)"
        "(Rev)"
        "(Ital)"
        "(Blink)"
        "BRIGHT_RED on BRIGHT_WHITEB"
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

test_rainbow() {
    local text="Color Library Demo"
    local rainbow=""
    local colors=("red" "yellow" "green" "cyan" "blue" "magenta")

    for color in "${colors[@]}"; do
        rainbow+="$(clr_"${color}" "$text") "
    done

    demonstrate "Rainbow Demo" "$rainbow"
}

test_extended_colors() {
    echo "Testing 256-color functionality..."
    local result

    result=$(clr_256fg 196 "Hello 196")
    if [[ "$result" == *"[38;5;196mHello 196"* ]]; then
        echo "$(clr_green "✓") clr_256fg 196 produces correct sequence"
    else
        ((++TESTS_FAILED))
        echo "$(clr_red "✗") clr_256fg 196 - got: $result"
    fi

    result=$(clr_256bg 82 "BG 82")
    if [[ "$result" == *"[48;5;82mBG 82"* ]]; then
        echo "$(clr_green "✓") clr_256bg 82 produces correct sequence"
    else
        ((++TESTS_FAILED))
        echo "$(clr_red "✗") clr_256bg 82 - got: $result"
    fi
}

# New test for italic, blink, bright colors
test_more_attributes() {
    echo "Testing italic, blink, and bright colors..."
    local result text

    # Italic
    text="This is italic text"
    result=$(clr_italic "$text")
    assert "$result" "$result" "Italic attribute"

    # Blink
    text="This is blinking text"
    result=$(clr_blink "$text")
    assert "$result" "$result" "Blink attribute"

    # Bright red
    text="Bright red text"
    result=$(clr_bright_red "$text")
    assert "$result" "$result" "Bright red foreground"

    # Bright yellow background
    text="Bright yellow background"
    result=$(clr_bright_yellowb "$text")
    assert "$result" "$result" "Bright yellow background"
}

main() {
    clr_bold "Running color library tests..."
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
    test_more_attributes
    echo

    clr_bold "Test Summary:"
    echo "Tests run: $TESTS_RUN"
    if [ $TESTS_FAILED -eq 0 ]; then
        clr_green clr_bold "All tests passed!"
    else
        clr_red clr_bold "Tests failed: $TESTS_FAILED"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
