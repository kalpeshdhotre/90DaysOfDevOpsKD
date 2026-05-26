# Day04

### Process checks

1. `ps` - Display all running processes
   ![alt text](image.png)

2. `htop` - Interactive process viewer
   ![alt text](image-1.png)

3. `pgrep` - find process with and return pid
   ![alt text](image-3.png)

---

### Service checks

1. `systemctl` - check status of process `sshd`
   ![alt text](image-4.png)

2. `sytemctl --type=services --state=inactive` - list all inactive services
   ![alt text](image-5.png)

3. `systemstl -is-enabled sshd` - to check service is enabled to start on boot
   ![alt text](image-6.png)

---

### Log checks

1. `journalctl -u sshd -n 4` - view recent 4 ssh logs
   ![alt text](image-7.png)

2. `journalctl -n +10` - display oldest 10 logs if `+` removed then recent 10 logs
   ![alt text](image-8.png)

### Mini troubleshooting steps

`sudo tail -n 20 /var/log/secure` checked why user logon was failed in authentication log
![alt text](image-9.png)
