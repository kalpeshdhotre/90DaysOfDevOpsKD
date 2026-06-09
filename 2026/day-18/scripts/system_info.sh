#!/bin/bash
set -euo pipefail

# function to print hostname and OS info
osinfo(){
    echo "Your Hostname and OS is :$(uname -on)" 
}

showUptime(){
    echo "Your system is $(uptime -p)"
}

diskUsage(){
    echo "Your system disk usage "
    # Below command exits becaue of -euo pipefail, so we need to handle it with || true or 
    # we can use head -5 < <(du -h ~ | sort -rh) to avoid the error and get the top 5 results
    # du -h ~/Shell-Scripting-For-DevOps-KD | sort -rh | head -5
    head -5 < <(du -h ~ | sort -rh)
}

memoryUsage(){
    echo "Your system memory status"
    free -h
}

cpuUsage(){
    echo "Your CPU usage report:"
    ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -6
}

main(){
    echo "Your system information report"
    osinfo
    echo "====="
    showUptime
    echo "====="
    diskUsage
    echo "====="
    memoryUsage
    echo "====="
    cpuUsage
    echo "====="
    echo "report end"
}

main