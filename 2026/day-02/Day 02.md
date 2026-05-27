# 💻 Day 02 of #90DaysOfDevOps

# Linux Architecture

A Linux system consists of multiple layers:

1. **Hardware**  
   Physical components like CPU, RAM, Disk, Keyboard, Network devices, etc.

2. **Kernel**  
   The core part of Linux that directly communicates with hardware and manages:
    - CPU
    - Memory
    - Devices
    - Processes
    - File systems
    - Networking

3. **Shell**  
   A command-line interface that allows users to interact with the kernel using simple commands.  
   Examples:
    - bash
    - zsh
    - fish

4. **Applications/User Space**  
   Software installed and used by users such as:
    - Browsers
    - Editors
    - Databases
    - Web servers
    - Monitoring tools

---

# Linux Basics

- Linux itself is technically the **Kernel**
- It is an **open-source operating system kernel**
- Different Linux distributions combine the Linux kernel with software packages and utilities

Examples of Linux distributions:

- Ubuntu
- Fedora
- Debian
- Arch Linux
- CentOS

---

# Important Linux Commands

## Check Kernel Version

```bash
uname -r
```

Displays the currently running Linux kernel version.

---

## Check OS Information

```bash
cat /etc/os-release
```

Displays Linux distribution details such as:

- Distribution name
- Version
- Release information

---

# Linux Directory Structure

Unlike Windows, Linux uses a single root directory represented by `/`.

Common directories:

| Directory | Purpose                                        |
| --------- | ---------------------------------------------- |
| `/bin`    | Essential binaries and commands                |
| `/home`   | User personal files and directories            |
| `/etc`    | System configuration files                     |
| `/var`    | Variable data such as logs, cache, spool files |
| `/tmp`    | Temporary files                                |

---

# Process States in Linux

## Running

Process is currently executing on CPU or ready to execute.

## Sleeping

Process is waiting for an event such as:

- Keyboard input
- File read
- Network response

## Stopped

Process execution is paused using a signal or user action.

## Zombie

Process has completed execution, but its process entry still exists until the parent process reads its exit status.

## Orphan

A process whose parent process has terminated.  
It gets adopted by the system process (`init/systemd`).

---

# Common Linux Commands

| Command    | Description                         |
| ---------- | ----------------------------------- |
| `pwd`      | Show present working directory      |
| `cd`       | Change directory                    |
| `htop`     | Interactive process monitoring tool |
| `cat`      | Display file contents               |
| `uname -r` | Display kernel version              |

---

# Core Components of Linux

## Kernel

Core component that directly interacts with hardware and manages system resources.

## User Space

Area where user applications run:

- Browser
- Shell
- Editors
- Services

Applications access hardware through the kernel.

## init/systemd

The first userspace process started by the kernel (PID 1).

Responsibilities:

- Starts services during boot
- Manages services/processes
- Handles orphan processes
- Cleans zombie processes

---

# How Processes Are Created and Managed

1. A parent process creates a child process using:

```c
fork()
```

2. The child process may load a new program using:

```c
exec()
```

3. The kernel manages:

- CPU scheduling
- Memory allocation
- Process priorities
- Process states

---

# What is systemd?

`systemd` is the modern Linux service and system manager.

## Responsibilities

- Starts services during system boot
- Manages background services
- Restarts failed services automatically
- Handles:
    - Logging
    - Timers
    - Networking
    - Service dependencies

Examples of services:

- SSH
- Nginx
- Apache
- Databases

---

# Why systemd Matters

- Faster boot process
- Better service management
- Automatic recovery of failed services
- Centralized service control using:

```bash
systemctl
```

Example:

```bash
systemctl status ssh
```
