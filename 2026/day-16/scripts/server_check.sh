#!/bin/bash

read -p "Enter service name to be checked: " SERVICE

read -p "Procced with the status check of $SERVICE? (y/n): " ANSWER

if [ $ANSWER == "y" ]; then
    STATUS=$(systemctl is-active $SERVICE)
    if [ "$STATUS" == "active" ]; then
        echo "Service is running."
    else
        echo "Service is not running. Status: $STATUS"
    fi
else
    echo "Service checking skipped"
fi
