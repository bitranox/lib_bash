#!/bin/bash

source ../lib_lxc_helpers.sh



function test {
    local container_name
    container_name="dd-clean"
	# assert_equal "lxc_wait_until_internet_connected ${container_name}" ""
}

test
