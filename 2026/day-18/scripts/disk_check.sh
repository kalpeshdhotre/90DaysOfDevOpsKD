#!/bin/bash

check_disk(){
    echo "============================="
    echo "Your system disk usage status"
    echo "============================="
    df -h /    
    echo ""
}

check_memory(){
    echo "============================="
    echo "Yous system memory status"
    echo "============================="
    free -h
}

check_disk
check_memory