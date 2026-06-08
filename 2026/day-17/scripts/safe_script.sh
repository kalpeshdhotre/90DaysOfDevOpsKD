#!/bin/bash
set -e

mkdir /tmp/devops-test || echo "Directory already exists.."
cd /tmp/devops-test || { echo "Cannot navigate into the directory. Exiting"; exit 1; }
touch deployement.log || { echo "Cannot create file. Exiting."; exit 1; }

echo "All steps completed. Files in /tmp/devops-test:"
ls -lh /tmp/devops-test
