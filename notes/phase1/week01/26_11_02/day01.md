# day01 · 2026-11-02 · 装机与验收

> Phase1 第 1 天 / 第 1 周 ｜ 主线：把 Windows 单系统变成 Ubuntu 22.04 双系统，并确认「能用」。
> 证据图（同目录）：`nvidia-smi.jpg`、`sudo-apt-update.jpg`、`终端测试打出机器人.jpg`、`lsblk命令.jpg`、`GRUB菜单选择UBUNTU启动.jpg`、`GRUB菜单选择WINDOWS启动.jpg`、`安装时遗漏的照片.png`（安装当时的「其它选项」页）、`blkid+efibootmgr.png`、`df+du.png`、`rwx+ugo+umask.png`、`建目录树.png`、`重定向+管道.png`、`重定向执行结果.png`、`lsblk.png`

## 1. 磁盘实况（`lsblk -f` + `lsblk -d`）

| 设备 | 容量 / 型号 | 文件系统 | 挂载点 / 用途 |
|---|---|---|---|
| `nvme0n1` | 476.9G · `SKHynix_HFS512GD9TNI-L2A0B`（Windows 系统盘） | — | — |
| 　`nvme0n1p1` | 221.2M（`df` 报 256M） | `vfat` FAT32，label `SYSTEM_DRV`，UUID `9634-B307`，PARTLABEL `EFI system partition`，PARTUUID `2afcdf5-4540-43bc-b682-f6fbb67f1190` | **`/boot/efi`**（全机唯一 ESP） |
| 　`nvme0n1p2` | — | 无（`blkid` 报 `PARTLABEL="Microsoft reserved partition"`） | MSR 保留分区，未动 |
| 　`nvme0n1p3` | — | `ntfs`，label `Windows-SSD`，UUID `DAEC3536EC350DEF` | Windows C: |
| 　`nvme0n1p4` | — | `ntfs`，label `WINRE_DRV`，UUID `F60835ED8835AD0D` | Windows 恢复分区 |
| `nvme1n1` | 1.9T · `KINGBANK_KP260`（数据盘，Windows 下是 F:） | — | — |
| 　`nvme1n1p1` | — | **无文件系统**，`blkid` 报 `PARTLABEL="Microsoft reserved partition"`，PARTUUID `82f1f9a1-b196-4c39-b769-fc5094332cfd` | **MSR 保留分区**（已定性，见 §7-2） |
| 　`nvme1n1p2` | — | `ntfs`，label `Data`，UUID `0C6714A06713634` | Windows F: |
| 　`nvme1n1p3` | **147 G 总 / 14 G 已用 / 126 G 可用** | `ext4`，UUID `6ed96882-eaae-4a06-8eba-ff6cbff282c5`，BLOCK_SIZE 4096 | **`/`**（`df -h /`） |
| `loop0`–`loop10` | 4K ~ 505M | `squashfs` | snap 镜像，不是真分区 |

结论（对应验收 V2、T4 判据）：

1. **全机只有 1 个 ESP**＝`nvme0n1p1`（`SYSTEM_DRV`），没有在数据盘上新建第二个 EFI。`efibootmgr -v` 显示 ubuntu 与 Windows Boot Manager **都指向这同一个 ESP**，形态正确。
2. `/` 独占 `nvme1n1p3`，Ubuntu 落在**数据盘**（KINGBANK）上，不在 Windows 那块 SK Hynix 上——这是压缩 F 盘而不是 C 盘带来的直接结果。
3. **没有任何 swap 分区**，取舍见 §3。
4. `loop0`–`loop10` 是 snap 的只读镜像，别当成分区去数。
5. 两块盘上的 `p1/p2` 里各有一个 `Microsoft reserved partition`（MSR），这是 Windows 正常结构，**没有文件系统是它的正常状态**，不是坏分区。

## 2. 三个数字：压缩 150 GB、安装器 163 GB、根分区 147 GiB

| 口径 | 数值 | 来源 |
|---|---|---|
| 压缩前 F: 可用 | 1.86 TB | Windows 资源管理器 |
| 压缩后 F: 可用 | 1.71 TB（差 0.15 TB ≈ 150 GB） | Windows 资源管理器 |
| 安装器「未分配空间」 | 163 GB（十进制） | 安装器「其它选项」页 |
| ext4 根分区实际 | **147 G 总 / 14 G 已用 / 126 G 可用** | `df -h /`（`df+du.png`） |
| 十进制换算 | 147 GiB × 1.0737 ≈ **158 GB** | 换算 |

**已收口（11-02 晚）**：

- **150 → 163 的 13 GB** 是显示口径差：Windows 用 GiB 却标成 "GB"，150 GiB ≈ 161 GB；安装器按十进制 GB 显示，且把盘上原有的零星未分配（`nvme1n1p1` 前那 1 MB 级空隙）一起并进来，于是显示 163 GB。
- **163 → 147 GiB** 的差 ≈ 4.8 GiB，是 ext4 的元数据/日志 + 默认 5% 保留块（root 专属，普通用户看不到）。
- **结论：容量没有丢，不需要重装。** 若日后要让 `df` 显示的数字更大，可 `sudo tune2fs -m 1 /dev/nvme1n1p3` 把保留块从 5% 降到 1%（约多出 5.7 GiB）。

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
| `umask` | **`0002`**（所以新文件默认 `664`、新目录 `775`，不是常见的 `644/755`） |

## 5. 踩坑 3 条

### ① 分区界面差点把引导器装到数据盘那块 EFI 上

- **现象**：安装器「安装启动引导器的设备」下拉里同时出现两块盘的 `p1`，两个都在列表里挨着；数据盘那块 p1 看着也像 EFI（装完后 GRUB 生成的 Windows 条目就写着 `on /dev/nvme1n1p1`）。
- **怎么定位的**：用「引导器必须装在 Windows 所在那块盘」这条原则筛——带 `Windows-SSD` 和 `WINRE_DRV` 的那块才是 Windows 盘，于是选它。
- **结果**：`/boot/efi` 现在挂在 `nvme0n1p1`（`SYSTEM_DRV`），装完 GRUB 三项都能进，引导链通。**安装当时的照片 `安装时遗漏的照片.png` 是这条的硬证据**：下拉框选的是 `/dev/nvme1n1  SKHynix_HFS512GD9TNI-L2A0B (512.1 GB)`，弹窗「以下设备的分区表已改变：/dev/nvme0n1」「以下分区将被格式化：/dev/nvme0n1 设备上的第 3 分区将设为 ext4」——即引导器写 SK Hynix、新分区建在 KINGBANK，两件事分得清清楚楚。

### ② Ubuntu 装完首次启动，Perform MOK manager 键盘失效

- **现象**：勾了「安装第三方驱动」，首次启动进 MOK 管理界面（给 DKMS 模块签名/登记）时键盘完全无响应，卡在界面里出不来。
- **怎么定位的**：界面本身没报错、键盘灯也没灭，判断是虚拟控制台在这一阶段的输入设备偶发不识别，不是系统装坏了。
- **结果**：直接重启，问题消失，驱动正常装上（`nvidia-smi` 出表就证明 MOK 没挡住驱动）。要再犯：换 USB 口外接键盘，或 `Ctrl+Alt+F3` 切 TTY。

### ③ 压缩 150 GB，安装器显示 163 GB，差额没算平 → **当晚收口**

- **现象**：F: 可用从 1.86 TB 掉到 1.71 TB（少了 150 GB），但安装器那一步显示未分配 163 GB；`lsblk` 推算根分区只有约 138 GiB。
- **怎么定位的**：`df -h /` 拿到硬数字（147 G 总 / 14 G 已用 / 126 G 可用）后，把「GiB 与 GB 的口径差」和「ext4 保留块」两项加起来正好对上。
- **结果**：**已收口，容量没丢**，推导见 §2。教训：**别用 `lsblk` 的 `FSAVAIL ÷ (1 - FSUSE%)` 去反推总容量**，那个估法本身有 5~8% 误差，直接 `df -h /` 一行就完事。

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

## 7. 三条待核命令的结果（11-02 晚已全部办结）

1. `sudo lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME` —— 已跑，分区实际大小进 §1 表；`/` 147 G、ESP 256M。
2. `sudo blkid /dev/nvme1n1p1` —— 输出 `PARTLABEL="Microsoft reserved partition" PARTUUID="82f1f9a1-b196-4c39-b769-fc5094332cfd"`，**无文件系统，是 MSR 保留分区**，不是旧 EFI。
   **「GRUB 写着 `on /dev/nvme1n1p1`」与「这块没有文件系统」不矛盾**：那句括号里的设备名是**装系统那一刻的编号**。`安装时遗漏的照片.png` 证明当时 SK Hynix（Windows 盘）是 `nvme1n1`、KINGBANK（数据盘）是 `nvme0n1`；装完重启后内核枚举顺序对调 → 现在 SK Hynix 变成 `nvme0n1`、KINGBANK 变成 `nvme1n1`。GRUB 真正靠 PARTUUID 找盘，不靠设备名，所以照常能进 Windows。**结论：不需要动任何分区，之前那条「动 p1 前先备份」的警告可以撤销。**
3. `sudo efibootmgr -v` —— `BootCurrent: 0003`（当前从 Ubuntu 启）；`Boot0003* ubuntu` 与 `Boot0004* Windows Boot Manager` 的路径都是 `HD(1,GPT,2afcdf5-4540-43bc-b682-f6fbb67f1190,0x800,0x82000)/File(\EFI\…)`，即**两个系统共用同一个 ESP**（`nvme0n1p1`）。这是正确形态。

**新增待办（非阻塞）**：Ubuntu 侧的笔记与截图还散在 `~/ros_learning/26_11_02/`、`~/day01/`、`~/lab/day02/` 三处，而仓库在 `~/ros-learning`（连字符）。11/03 统一到仓库内的 `code/week01/` 与 `notes/` 下，见 §8。

## 8. 明日第一步

11/03「Linux 文件系统与权限」：§7 的三条命令已办结，明天**直接进正题**——先把散在三处的练习目录合并到 `~/lab/day02`（或仓库内 `code/week01/`），再补 B 组缺的 `chmod 755` / `chmod 600` 两个目标值（`rwx+ugo+umask.png` 里只做了 644、`g+w`、`g-w`、`750` 目录与 `umask`），最后写 `notes/week01/day02.md` 并提交。
