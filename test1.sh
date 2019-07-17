#!/bin/bash

echo "parameter 0 is : $0"
echo "parameter 1 is : $1"

echo "BASH_SOURCE is : ${BASH_SOURCE[0]}"  # this gives the right name when sourced AND when runned

echo "sleeping 1"
sleep 1
echo "now we source ourself and exit (after update)"
    source "${BASH_SOURCE[0]}"
    exit

echo "after we source ourself in main sleeping 1"

