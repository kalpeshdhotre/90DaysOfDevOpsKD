## Commands I have tried / practiced today

### Environment basics

1. `uname -a`
2. `lsb_release -a`
3. `cat /etc/os-release`

![alt text](<Screenshot From 2026-05-27 20-00-58-1.png>)

### Filesystem sanity

1. `mkdir /tmp/runbook-demo`
2. `cp /etc/hosts /tmp/runbook-demo && ls -l /tmp/runbook-demo/`

![alt text](<Screenshot From 2026-05-27 20-19-45.png>)

### CPU & memory

1. `pgrep ssh`
2. `ps -o pid,pcpu,pmem,comm -p 2289 2291`
3. `free -h`

![alt text](<Screenshot From 2026-05-27 20-45-18.png>)

### Disk & IO

1. `df -h`
2. `sudo du -sh /var/log`

![alt text](image.png)

### Network

1. `ss -tulpn`
2. `ping -c 3 google.com`

![alt text](image-1.png)

### LOGS

1. `journalctl -u NetworkManager -n 10`
2. `tail -n 10 /var/log/auth.log`

![alt text](image-2.png)
