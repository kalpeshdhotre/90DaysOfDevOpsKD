# Day 15 – Networking Concepts: DNS, IP, Subnets & Ports

---

## Task 1: DNS – How Names Become IPs

### How DNS works
DNS (Domain Name System) is Linux's domain name resolution system. It converts a human-readable website address (like `google.com`) into the IP address of the server hosting it — because computers communicate using IP addresses, not names.

**Resolution flow:**
1. Browser checks its own cache first. If visited recently, the IP is already stored.
2. If not cached, the OS asks a DNS resolver (usually your router or ISP's DNS server).
3. The resolver queries a root DNS server → directed to the `.com` TLD server → directed to the authoritative DNS server for that domain.
4. The authoritative server returns the A record (IP address). The browser connects to that IP.

### DNS Record Types

| Record | Purpose |
|--------|---------|
| `A` | Maps a domain to an IPv4 address |
| `AAAA` | Maps a domain to an IPv6 address |
| `CNAME` | Alias — maps one domain name to another domain name |
| `MX` | Mail exchange — specifies which server handles email for the domain |
| `NS` | Nameserver — identifies which server is authoritative for the domain |

### dig output — A record and TTL

```bash
dig google.com
dig trainwithshubham.com
```

📸 *Screenshot: dig-output.png*

**Observation:** The ANSWER SECTION shows the A record in the format:
```
google.com.    300    IN    A    142.250.x.x
               ↑                ↑
              TTL              resolved IP
```

**TTL (Time To Live)** — controls how long a DNS response is cached before it expires and a fresh DNS lookup is needed. A TTL of 300 means the result is cached for 300 seconds (5 minutes). After that, the DNS query is made again. Lower TTL = more frequent lookups but fresher results.

---

## Task 2: IP Addressing

### IPv4 structure
An IPv4 address is a 32-bit address written as 4 numbers (octets) separated by dots. Each octet ranges from 0 to 255.

Example: `192.168.1.10`

### Public vs Private IPs

| Type | Description | Example |
|------|-------------|---------|
| Public | Globally unique, routable on the internet. Assigned by ISP or cloud provider. | `13.234.56.78` (EC2 instance from Day 08) |
| Private | Only valid within a local or internal network. Not routable on the internet. | `192.168.x.x` (RHEL VM on VMware) |

### Private IP ranges
```
10.0.0.0     – 10.255.255.255
172.16.0.0   – 172.31.255.255
192.168.0.0  – 192.168.255.255
```

### ip addr show

```bash
ip addr show
```

📸 *Screenshot: ip-addr-show.png*

**Observation:** The IP shown on the RHEL VM falls within the private IP range (`192.168.x.x`). This is a locally assigned address from VMware's NAT — it is not reachable from the internet directly.

---

## Task 3: CIDR & Subnetting

### What does /24 mean?
The number after the `/` in CIDR notation indicates how many bits are used for the **network** portion of the address. The remaining bits are available for **hosts**.

`192.168.1.0/24` = first 24 bits are the network (`192.168.1`), last 8 bits are for hosts (`.0 – .255`)

### Why do we subnet?
Selecting a specific range of IP addresses is essential when creating a VPC (Virtual Private Cloud) on AWS or any cloud provider. CIDR notation (`/24`, `/16`, `/28`) is used instead of the traditional subnet mask format — it is more compact and easier to work with when defining network boundaries. Subnetting also helps isolate services, improve security, and manage IP allocation across teams or availability zones.

### CIDR Table

| CIDR | Subnet Mask | Total IPs | Usable Hosts |
|------|-------------|-----------|--------------|
| /24 | 255.255.255.0 | 256 | 254 |
| /16 | 255.255.0.0 | 65,536 | 65,534 |
| /28 | 255.255.255.240 | 16 | 14 |

**Formula:** Total IPs = 2^(32 - prefix). Usable = Total - 2 (network address + broadcast address are reserved).

---

## Task 4: Ports – The Doors to Services

### What is a port?
A port is a 16-bit number (0–65535) that identifies which specific service on a machine should receive incoming traffic. If an IP address is the building address, the port is the flat number inside — it tells traffic exactly which service to reach.

### Common Ports

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH — secure remote login | TCP |
| 80 | HTTP — unencrypted web traffic | TCP |
| 443 | HTTPS — encrypted web traffic (TLS) | TCP |
| 53 | DNS — domain name resolution | UDP/TCP |
| 3306 | MySQL — relational database | TCP |
| 6379 | Redis — in-memory cache/database | TCP |
| 27017 | MongoDB — NoSQL document database | TCP |

### ss -tulpn output

```bash
ss -tulpn
```

📸 *Screenshot: ss-tulpn.png*

**Observation:** Ports that are displayed in the output of `ss -tulpn` are the ones that are currently open and listening on the machine. On the RHEL VM, ports visible included 22 (SSH), 631 (CUPS), 5353 (mDNS), and 323 (chronyd) — same as observed in Day 14.

---

## Task 5: Putting It Together

### Scenario 1: `curl http://myapp.com:8080`

DNS resolves `myapp.com` to an IP address via an A record lookup (Application layer). A TCP connection is then established to that IP on port `8080` (Transport layer). The HTTP request is sent over that connection (Application layer). Port 8080 is a non-standard/custom port — not the default 80 — so it must be explicitly stated in the URL and the firewall or security group must have port 8080 open for the request to succeed.

### Scenario 2: App can't reach database at `10.0.1.50:3306`

`10.0.1.50` is a private IP — so this is internal network traffic within the same VPC or local network. First checks:

```bash
ping 10.0.1.50                    # confirm IP is reachable at all
systemctl status mysql            # is the database service running?
ss -tulpn | grep 3306             # is port 3306 actually listening?
```

If ping fails → network or routing issue. If ping succeeds but port is unreachable → service is down or firewall is blocking port 3306.

---

## Commands Used

| Command | Purpose |
|---------|---------|
| `dig google.com` | DNS lookup — shows A record and TTL |
| `nslookup google.com` | Alternative DNS lookup |
| `ip addr show` | Show IP addresses and network interfaces |
| `ss -tulpn` | List all listening ports and services |

---

## Key Learnings

- DNS converts human-readable domain names to IP addresses through a hierarchical lookup chain — browser cache → OS resolver → root → TLD → authoritative server. TTL controls how long each step caches the result before querying again.
- CIDR notation (`/24`, `/16`, `/28`) is the standard way to define IP ranges in cloud networking — especially when creating VPCs and subnets on AWS. It is more compact than traditional subnet masks and directly tells you how many IPs are in the range.
- Ports displayed in `ss -tulpn` are open and listening — those are the services accepting connections on that machine. Knowing the port-to-service mapping is essential for both troubleshooting connectivity and configuring firewall rules correctly.

---

*Day 15 of #90DaysOfDevOps — TrainWithShubham*
