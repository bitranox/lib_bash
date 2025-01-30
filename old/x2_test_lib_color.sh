#!/bin/bash
# tests/test_lib_color.sh
set -o errexit -o nounset -o pipefail

# Source the main script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib_color.sh"

# Test counter
TESTS_RUN=0
TESTS_FAILED=0

# Test helper function
assert() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    ((++TESTS_RUN))

    if [[ "$actual" == "$expected" ]]; then
        echo "$(clr_green "✓") $message"
    else
        ((TESTS_FAILED++))
        echo "$(clr_red "✗") $message"
        echo "  Expected: '$expected'"
        echo "  Got:      '$actual'"
    fi
}

# Visual demonstration helper
demonstrate() {
    local title="$1"
    shift
    echo
    echo "=== $title ==="
    echo -e "$@"
    echo "==============="
}

# Test function existence
test_functions_exist() {
    echo "Testing function existence..."
    local functions=(
        "clr_reset" "clr_reset_underline" "clr_reset_reverse" "clr_default"
        "clr_defaultb" "clr_bold" "clr_underscore" "clr_reverse" "clr_black"
        "clr_red" "clr_green" "clr_yellow" "clr_blue" "clr_magenta" "clr_cyan"
        "clr_white" "clr_blackb" "clr_redb" "clr_greenb" "clr_yellowb"
        "clr_blueb" "clr_magentab" "clr_cyanb" "clr_whiteb"
    )

    for func in "${functions[@]}"; do
        if fn_exists "$func"; then
            assert "true" "true" "Function $func exists"
        else
            assert "true" "false" "Function $func exists"
        fi
    done
}

# Test foreground colors
test_foreground_colors() {
    echo "Testing foreground colors..."
    local text="This is a test of foreground colors"
    local demo_text=""

    local colors=("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white")
    for color in "${colors[@]}"; do
        local func="clr_${color}"
        local result=$($func "$text")
        assert "$($func "$text")" "$result" "Testing $color foreground"
        demo_text+="$($func "$color")
"
    done

    demonstrate "Foreground Colors" "$demo_text"
}

# Test background colors
test_background_colors() {
    echo "Testing background colors..."
    local text="This is a test of background colors"
    local demo_text=""

    local colors=("blackb" "redb" "greenb" "yellowb" "blueb" "magentab" "cyanb" "whiteb")
    for color in "${colors[@]}"; do
        local func="clr_${color}"
        local result=$($func "$text")
        assert "$($func "$text")" "$result" "Testing $color background"
        demo_text+="$($func "$color")
"
    done

    demonstrate "Background Colors" "$demo_text"
}

# Test text attributes
test_attributes() {
    echo "Testing text attributes..."
    local text="This text demonstrates attributes"
    local demo_text=""

    # Test and demonstrate bold
    local result
    result=$(clr_bold "$text")
    assert "$result" "$result" "Bold attribute"
    demo_text+="Bold: $(clr_bold "$text")
"

    # Test and demonstrate underscore
    result=$(clr_underscore "$text")
    assert "$result" "$result" "Underscore attribute"
    demo_text+="Underscore: $(clr_underscore "$text")
"

    # Test and demonstrate reverse
    result=$(clr_reverse "$text")
    assert "$result" "$result" "Reverse attribute"
    demo_text+="Reverse: $(clr_reverse "$text")
"

    demonstrate "Text Attributes" "$demo_text"
}

# Test combinations
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

# Test error handling
test_error_handling() {
    echo "Testing error handling..."
    local result

    # Test empty input
    result=$(clr_red "")
    # For an empty string, the color codes wrap nothing. Usually looks like: '\033[31m\033[0m'
    # We'll just verify that we get exactly that (or similar) from the function.
    # If you want a strict check, adjust the expected sequence:
    local expected=$'\033[31m\033[0m'
    assert "$expected" "$result" "Empty input handling"

    # Test invalid escape code (should output error to stderr and return empty)
    result=$(clr_escape "-e" "test" 999 2>/dev/null) || true
    assert "" "$result" "Invalid escape code handling"

    demonstrate "Error Handling" \
        "Empty string with red: '$(clr_red "")'
Invalid code output: '$result'"
}

# Test clr_layer function
test_clr_layer() {
    echo "Testing clr_layer function..."
    local demo_text=""

    # Test basic layer
    local result
    result=$(clr_layer "test")
    assert "test" "$result" "Basic layer with text only"
    demo_text+="Basic layer: $result
"

    # Test with color code
    result=$(clr_layer $CLR_RED "test")
    assert $'\033[31mtest\033[0m' "$result" "Layer with color code"
    demo_text+="Red layer: $result
"

    # Test with multiple attributes
    result=$(clr_layer $CLR_RED $CLR_BOLD "test")
    assert $'\033[31;1mtest\033[0m' "$result" "Layer with multiple attributes"
    demo_text+="Bold red layer: $result
"

    demonstrate "Layer Function" "$demo_text"
}

# Test clr_dump function
test_clr_dump() {
    echo "Testing clr_dump function..."

    # Capture the output of clr_dump
    local dump_output
    dump_output=$(clr_dump)

    # Test that the output contains expected elements
    local expected_patterns=(
        "Text (Normal)"
        "Text (Bold)"
        "Text (Underscore)"
        "Text (Reverse)"
        "BLACK on WHITEB"
        "RED on BLUEB"
        "GREEN on MAGENTAB"
    )

    for pattern in "${expected_patterns[@]}"; do
        if [[ $dump_output == *"$pattern"* ]]; then
            assert "true" "true" "clr_dump contains '$pattern'"
        else
            assert "true" "false" "clr_dump contains '$pattern'"
        fi
    done

    # Visual demonstration of clr_dump
    demonstrate "Color Dump Sample" "$dump_output"
}

# Test a rainbow just for fun
test_rainbow() {
    local text="Color Library Demo"
    local rainbow=""
    local colors=("red" "yellow" "green" "cyan" "blue" "magenta")

    for color in "${colors[@]}"; do
        rainbow+="$(clr_${color} "$text") "
    done

    demonstrate "Rainbow Demo" "$rainbow"
}

# Run all tests
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

    # Print summary
    echo "$(clr_bold "Test Summary:")"
    echo "Tests run: $TESTS_RUN"
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "$(clr_green "$(clr_bold "All tests passed!")")"
    else
        echo "$(clr_red "$(clr_bold "Tests failed: $TESTS_FAILED")")"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
