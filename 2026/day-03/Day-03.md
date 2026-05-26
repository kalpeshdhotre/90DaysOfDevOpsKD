# Day 03 - Linux Commands

CLI is one of the fastest and most secure ways to manage Linux systems.

Today I explored commonly used Linux commands related to:

- Process Management
- File System Operations
- Networking Troubleshooting

I also learned that many Linux commands are acronyms or short forms, which makes them easier to remember once we understand their meaning.

---

# Process Management Commands

1. `top` - display processes currently managed by Linux kernel
2. `htop` - interactive version of `top` with scrolling support
3. `ps` - process status snapshot
4. `kill` - terminate process using PID
5. `pkill` - terminate process using process name

---

# File System Commands

6. `ls` - list files and directories
7. `mkdir <name>` - create new directory
8. `cd <dirname>` - change directory
9. `pwd` - print working directory
10. `cp` - copy files
11. `mv` - move or rename files
12. `rm` - remove files
13. `touch` - create empty file
14. `du` - check folder size
15. `df` - check disk usage

---

# Networking Troubleshooting Commands

16. `ping` - check network connectivity using ICMP
17. `ip addr` - show IP addresses and interfaces
18. `dig` - query DNS records
19. `curl` - test HTTP/HTTPS requests
20. `wget` - download files from internet
21. `ssh` - securely connect to remote server

---

# Long Command Practice

The following command:

- Creates a directory named `KD`
- Changes into that directory
- Saves output of `ps aux` into `proc.txt`
- Displays file content using `cat`

Also learned:

- `&&` joins multiple commands
- `>` redirects output into a file

```bash
mkdir KD && cd KD && ps aux > proc.txt && cat proc.txt
```
