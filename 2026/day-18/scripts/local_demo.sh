#!/bin/bash

localFunc(){
    local NAME="I am local variable"
    echo "from inside function - $NAME"
}

globalFunc(){
    GLOBAL="I am global variable"
    echo "from inside function - $GLOBAL"
}

localFunc
globalFunc
echo "Whats inside function, localFunc? '$NAME'"
echo "Whats inside function, globalFunc? '$GLOBAL'"