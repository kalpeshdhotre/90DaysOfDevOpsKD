#!/bin/bash
read -p "Enter file name to be check: " FILE

if [ -f "$FILE" ]; then
    echo "File exists"
else
    echo "Entered file do not exists"
fi
