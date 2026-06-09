#!/bin/bash

set -euo pipefail

echo "Testing strict mode"

#This will cause script to exit immediately 
#because UNDEFINED_VAR was never set (set -u)
#echo "Value: $UNDEFINED_VAR"

# This will exis because /kdkd does not exist
#ls /kdkd

# this will exit because file is not exist
#cat nonexisted.txt | grep "nothing"

echo "This line will not be executed"