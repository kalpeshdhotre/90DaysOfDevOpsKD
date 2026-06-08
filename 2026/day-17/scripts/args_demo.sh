#!/bin/bash

if [[ $1 ]] then
    echo "File name is $0, Total No of agrs are $#"
    echo "Arguments are $@"
else
    echo "No argument passed"    
fi

