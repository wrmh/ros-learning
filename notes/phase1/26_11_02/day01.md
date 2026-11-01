# day01 · 2026-11-02 · 装机与验收

> Phase1 第 1 天 / 第 1 周 ｜ 主线：把 Windows 单系统变成 Ubuntu 22.04 双系统，并确认「能用」。
> 证据图（同目录）：`nvidia-smi.jpg`、`sudo-apt-update.jpg`、`终端测试打出机器人.jpg`、`lsblk命令.jpg`、`GRUB菜单选择UBUNTU启动.jpg`、`GRUB菜单选择WINDOWS启动.jpg`

## 1. 磁盘实况（`lsblk -f` + `lsblk -d`）

| 设备 | 容量 / 型号 | 文件系统 | 挂载点 / 用途 |
|---|---|---|---|
| `nvme0n1` | 476.9G · `SKHynix_HFS512GD9TNI-L2A0B`（Windows 系统盘） | — | — |
| 　`nvme0n1p1` | 221.2M | `vfat` FAT32，label `SYSTEM_DRV`，UUID `9634-B307` | **`/boot/efi`**（全机唯一 ESP） |
| 　`nvme0n1p2` | — | 无（`lsblk` 空） | 推测为 MSR 保留分区，未动 |
| 　`nvme0n1p3` | — | `ntfs`，label `Windows-SSD`，UUID `DAEC3536EC350DEF` | Windows C: |
| 　`nvme0n1p4` | — | `ntfs`，label `WINRE_DRV`，UUID `F60835ED8835AD0D` | Windows 恢复分区 |
| `nvme1n1` | 1.9T · `KINGBANK_KP260`（数据盘，Windows 下是 F:） | — | — |
| 　`nvme1n1p1` | 待核（`lsblk -f` 不显示大小） | **空**（无文件系统标识） | 未挂载，来历待核，见 §7-2 |
| 　`nvme1n1p2` | — | `ntfs`，label `Data`，UUID `0C6714A06713634` | Windows F: |
| 　`nvme1n1p3` | — | `ext4` 1.0，UUID `6ed96882-eaae-4a06-8eba-ff6cbff282c5` | **`/`**，`FSAVAIL 127.2G`、`FSUSE 8%` |
| `loop0`–`loop7` | 4K ~ 505M | `squash` 4.0 | snap 镜像，不是真分区 |

结论（对应验收 V2、T4 判据）：

1. **全机只有 1 个 ESP**＝`nvme0n1p1`（221.2M，Windows 自带的 `SYSTEM_DRV`），没有在数据盘上新建第二个 EFI。
2. `/` 独占 `nvme1n1p3`，Ubuntu 落在**数据盘**（KINGBANK）上，不在 Windows 那块 SK Hynix 上——这是压缩 F 盘而不是 C 盘带来的直接结果。
3. **没有任何 swap 分区**，取舍见 §3。
4. `loop0`–`loop7` 是 snap 的只读镜像，别当成分区去数。

## 2. 两个数字：压缩 150 GB，安装器却说 163 GB

| 口径 | 数值 | 来源 |
|---|---|---|
| 压缩前 F: 可用 | 1.86 TB | Windows 资源管理器 |
| 压缩后 F: 可用 | 1.71 TB | Windows 资源管理器（差 0.15 TB ≈ 150 GB） |
| 安装器「未分配空间」 | 163 GB | Ubuntu 安装器「其它选项」页 |
| 实际根分区 | 约 138 GiB（`FSAVAIL 127.2G` ÷ 0.92） | `lsblk -f` |

差额没算平。两个候选解释，谁对还没定：

- **GiB / GB 口径差**：Windows 磁盘管理用 GiB 但标成 "GB"，安装器按十进制 GB 显示，同一块空间两边读出来能差 7%。
- **盘上原本就有未分配空间**：若压缩前 `nvme1n1` 上已有一小块未分配（或那块无文件系统的 `nvme1n1p1`），安装器会把「连续未分配」合起来显示，于是比 150 GB 大。

定案命令（下次开机 5 分钟）：

```bash
sudo lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME
sudo blkid /dev/nvme1n1p1
```

## 3. 取舍：为什么不建 swap

安装时把整块未分配空间全给了一个 ext4 根分区，**没有 swap 分区**。当时的判断：

- 不做休眠（hibernate），swap 的最大刚需用不上；
- 不用 swap 换来的是根分区不被迫切小、少一个要维护的分区；
- 代价：内存吃紧时没有缓冲，OOM killer 直接杀进程；某些编译/仿真负载会因此失败而不是变慢。

**以后想补，不用重装**：`sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`，再写进 `/etc/fstab`。

## 4. 驱动与工具链（对应 V1、V3、V4）

| 项 | 实测值 |
|---|---|
| GPU | `NVIDIA GeForce RTX 2060`，显存 6144MiB，空闲 50C、8W/80W |
| `Driver Version` | `580.178.04` |
| `CUDA Version` | `13.0`（`nvidia-smi` 报的是驱动支持的最高 CUDA 版本，不等于已装 CUDA Toolkit） |
| apt 源 | `https://repo.huaweicloud.com/ubuntu`，四条：`jammy` / `jammy-updates` / `jammy-backports` / `jammy-security` |
| `apt update` 结果 | 4 条全 `命中:`，无 `Err:`、无 `W:`，末行「所有软件包均为最新」 |
| 中文输入 | `fcitx5`，终端内可打出「机器人」 |

## 5. 踩坑 3 条

### ① 分区界面差点把引导器装到数据盘那块 EFI 上

- **现象**：安装器「安装启动引导器的设备」下拉里同时出现 `nvme0n1p1` 和 `nvme1n1p1`，两个都在列表里挨着；数据盘那块 p1 看着也像 EFI（装完后 GRUB 生成的 Windows 条目就写着 `on /dev/nvme1n1p1`）。
- **怎么定位的**：用「引导器必须装在 Windows 所在那块盘」这条原则筛——`nvme0n1` 上才有 `Windows-SSD` 和 `WINRE_DRV`，`nvme1n1` 上只有 `Data`，于是选 `nvme0n1p1`。
- **结果**：`/boot/efi` 现在挂在 `nvme0n1p1`（`SYSTEM_DRV`，221.2M），装完 GRUB 三项都能进，引导链通。**遗留疑点见 §7-2**。

### ② Ubuntu 装完首次启动，Perform MOK manager 键盘失效

- **现象**：勾了「安装第三方驱动」，首次启动进 MOK 管理界面（给 DKMS 模块签名/登记）时键盘完全无响应，卡在界面里出不来。
- **怎么定位的**：界面本身没报错、键盘灯也没灭，判断是虚拟控制台在这一阶段的输入设备偶发不识别，不是系统装坏了。
- **结果**：直接重启，问题消失，驱动正常装上（`nvidia-smi` 出表就证明 MOK 没挡住驱动）。要再犯：换 USB 口外接键盘，或 `Ctrl+Alt+F3` 切 TTY。

### ③ 压缩 150 GB，安装器显示 163 GB，差额没算平

- **现象**：F: 可用从 1.86 TB 掉到 1.71 TB（少了 150 GB），但安装器那一步显示未分配 163 GB；装完实际根分区只有约 138 GiB。
- **怎么定位的**：把三处数字并排放（Windows 可用空间差 / 安装器显示 / `lsblk -f` 的 `FSAVAIL` + `FSUSE%`），先排除「压缩没成功」这个可能（可用空间确实少了 150 GB），剩下就是口径差或盘上原有未分配。
- **结果**：**还没收口**。用 §2 末尾两条命令定案。这件事不影响今天的验收，但下次分盘前必须搞清楚，否则「以为给了 150 GB、实际只用了 138 GiB、还有几十 GB 不知道在哪」会变成长期隐患。

## 6. 双系统切换记录（对应 V2、M6）

GRUB 菜单三项（来源 `GRUB菜单选择UBUNTU启动.jpg` / `GRUB菜单选择WINDOWS启动.jpg`）：

```
Ubuntu
Advanced options for Ubuntu
Windows Boot Manager (on /dev/nvme1n1p1)
```

- Ubuntu → 重启 → GRUB 选 `Windows Boot Manager` → 进 Win11：**成功**
- Windows → 重启 → GRUB 选 `Ubuntu` → 进桌面，并在终端跑 `lsblk` / `nvidia-smi` 拿到结果后再重启回 Windows：**成功**
- 计数：**双向各 ≥1 次**（M6 达标）

## 7. 遗留待核（下次开机 5 分钟）

1. `sudo lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME` —— 拿到每个分区的**实际大小**和 GPT 类型名，才能把 §2 的差额算平。
2. `nvme1n1p1` 到底是什么：`sudo blkid /dev/nvme1n1p1`。`lsblk -f` 说它没有文件系统，可 GRUB 的 Windows 条目却写着 `on /dev/nvme1n1p1`，两者矛盾；若它真是旧 Windows 留下的 ESP，动它之前先备份，别顺手格式化。
3. `sudo efibootmgr -v` —— 确认 `ubuntu` 与 `Windows Boot Manager` 两个启动项都在 NVRAM 里、顺序合理。

## 8. 明日第一步

11/03「Linux 文件系统与权限」：先把 §7 的三条命令跑完（10 分钟），再按计划做「建目录树 / 改权限 / 建软链接 / 批量改名」四组练习。练习目录：`~/lab/day02`。
