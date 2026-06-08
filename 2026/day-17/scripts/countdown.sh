#!/bin/bash

read -p "Enter Number from where count down to start: " START

while [[ $START -gt 0 ]];
do    
    echo $START
    START=$((START - 1))
done
