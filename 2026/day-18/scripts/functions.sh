#!/bin/bash

greet(){
    echo "Hello, $1!"
}

add(){
    local RESULT=$(( $1 + $2 ))
    echo "Sum of $1 and $2 = $RESULT"
}

greet "Kalpesh"
add 10 25