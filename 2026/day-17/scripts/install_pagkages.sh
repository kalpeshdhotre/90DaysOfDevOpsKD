#!/bin/bash

PACKAGES="nginx curl wget tree" 

for PACKAGE in $PACKAGES; do
    if rpm -q "$PACKAGE" >/dev/null; then
        echo "Package is already installed"
    else
        echo "Installing package..."
        sudo dnf install -y $PACKAGE
        echo "$PACKAGE installed successfully!"
    fi
done
