#1/bin/bash

read -p "Enter number to be checked: " Number

if [ $Number -gt 0 ]; then
    echo "Number is positive"
elif [ $Number -lt 0 ]; then
    echo "Number is negative"
else
    echo "The Number is zero"
fi
