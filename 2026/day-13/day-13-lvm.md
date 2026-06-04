# Day 13 – Linux Volume Management (LVM)

## What is LVM?

LVM (Logical Volume Manager) adds a flexible abstraction layer between physical disks and the filesystem. Instead of partitioning disks directly, you stack three layers:

```
Physical Volumes (PV) → Volume Group (VG) → Logical Volumes (LV)
```

This lets you resize, extend, and manage storage without touching partitions or reformatting.

---

## Environment Setup

No spare disk available — created a virtual disk using a loop device:

```bash
dd if=/dev/zero of=/tmp/disk1.img bs=1M count=1024
losetup -fP /tmp/disk1.img
losetup -a
# Output: /dev/loop0: []: (/tmp/disk1.img)
```

---

## Task 1: Check Current Storage

```bash
lsblk
pvs
vgs
lvs
df -h
```

`lsblk` showed existing block devices and the new `/dev/loop0`.  
`pvs`, `vgs`, `lvs` all returned empty — clean slate, nothing configured yet.

## ![alt text](<Screenshot From 2026-06-04 19-53-16.png>)

## Task 2: Create Physical Volume

```bash
pvcreate /dev/loop0
pvs
```

**Output:**

```
Physical volume "/dev/loop0" successfully created.

  PV          VG  Fmt  Attr PSize    PFree
  /dev/loop0      lvm2 ---  1020.00m 1020.00m
```

`pvcreate` registers the device with LVM. The PV is now visible to the LVM layer but not yet assigned to any group.

---

## Task 3: Create Volume Group

```bash
vgcreate devops-vg /dev/loop0
vgs
```

**Output:**

```
Volume group "devops-vg" successfully created

  VG        #PV #LV #SN Attr   VSize    VFree
  devops-vg   1   0   0 wz--n- 1016.00m 1016.00m
```

The VG pools one or more PVs into a single storage unit. LVs are carved out of this pool.

---

## Task 4: Create Logical Volume

```bash
lvcreate -L 500M -n app-data devops-vg
lvs
```

**Output:**

```
Logical volume "app-data" created.

  LV       VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  app-data devops-vg -wi-a----- 500.00m
```

`-L 500M` sets the size, `-n app-data` names the LV. It now lives at `/dev/devops-vg/app-data`.

## ![alt text](<Screenshot From 2026-06-04 19-55-10.png>)

## Task 5: Format and Mount

```bash
mkfs.ext4 /dev/devops-vg/app-data
mkdir -p /mnt/app-data
mount /dev/devops-vg/app-data /mnt/app-data
df -h /mnt/app-data
```

**Output:**

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/mapper/devops--vg-app--data  477M   24K  445M   1% /mnt/app-data
```

Formatted with ext4 and mounted. The volume is now usable as a regular directory.

---

## Task 6: Extend the Volume

```bash
lvextend -L +200M /dev/devops-vg/app-data
resize2fs /dev/devops-vg/app-data
df -h /mnt/app-data
```

**Output:**

```
Size of logical volume devops-vg/app-data changed from 500.00 MiB to 700.00 MiB.
Logical volume devops-vg/app-data successfully resized.

Filesystem      Size  Used Avail Use% Mounted on
/dev/mapper/devops--vg-app--data  669M   24K  630M   1% /mnt/app-data
```

`lvextend` grows the LV block device. `resize2fs` then stretches the filesystem to fill it — **both steps are required**. The volume was extended live without unmounting.

## ![alt text](<Screenshot From 2026-06-04 19-56-25.png>)

## Self-Check

**Q1. What's the difference between a PV, VG, and LV?**

- **PV (Physical Volume)** — a raw disk or partition registered with LVM (`pvcreate`)
- **VG (Volume Group)** — a pool that combines one or more PVs into a single storage unit (`vgcreate`)
- **LV (Logical Volume)** — a slice carved out of a VG, used like a regular partition (`lvcreate`)

The stack is: disk → PV → VG → LV → filesystem → mount point.

---

**Q2. Why do you need `resize2fs` after `lvextend`?**

`lvextend` only grows the block device at the LVM layer. The ext4 filesystem sitting on top of it still thinks it's the old size. `resize2fs` tells the filesystem to expand and use the newly available space. Skipping it means the extra space exists but is inaccessible.

---

**Q3. How is this better than traditional partitioning?**

With traditional partitions, resizing requires unmounting, repartitioning, and reformatting — risky and often requires downtime. LVM lets you extend a live, mounted volume in seconds. You can also add a second disk to the same VG and the LV spans both transparently.

---

## Key Commands Reference

| Command                        | What it does                          |
| ------------------------------ | ------------------------------------- |
| `pvcreate /dev/sdX`            | Register a disk as a Physical Volume  |
| `pvs`                          | List all Physical Volumes             |
| `vgcreate name /dev/sdX`       | Create a Volume Group from PV(s)      |
| `vgs`                          | List all Volume Groups                |
| `lvcreate -L size -n name vg`  | Create a Logical Volume               |
| `lvs`                          | List all Logical Volumes              |
| `mkfs.ext4 /dev/vg/lv`         | Format LV with ext4                   |
| `mount /dev/vg/lv /mnt/path`   | Mount the LV                          |
| `lvextend -L +size /dev/vg/lv` | Extend the LV                         |
| `resize2fs /dev/vg/lv`         | Resize filesystem to fill extended LV |

---

## 3 Things Learned

1. **LVM separates storage from hardware** — you manage logical volumes, not physical disks. Adding or swapping disks doesn't disrupt the filesystem structure above.

2. **Live extension is a two-step process** — `lvextend` and `resize2fs` are separate operations. The filesystem is unaware of the LVM layer, so both must be run.

3. **Loop devices make LVM practice accessible** — `dd` + `losetup` lets you simulate real disk operations entirely in `/tmp` without any hardware. Same commands, same behavior.

---

_Day 13 of #90DaysOfDevOps — TrainWithShubham_
