# day02 · 2026-11-03 · Linux 权限进阶 + 脚本骨架 + SSH 上传链路

> Phase1 第 2 天 / 第 1 周 ｜ 加速日（11-02 得 96 分）→ 上午闭卷小测、下午深化 + 项目化、傍晚装 SSH 工具链。
> 环境：Ubuntu 22.04，仓库 `~/ros-learning`（连字符），用户 `wrmh`，主机名 `wrmh-Lenovo-Legion-R7000P2020H`。
> 证据图（同目录）：`补三条命令+github上传1/2/3.png`、`setuid.png`、`setgid+sticky+umask.png`、`脚本骨架搭建1.png`、`SSH开发工具安装1/2/3.png`
> ⚠️ 命名更正：本篇是**第 2 天**的笔记。11-02 那篇「Linux 文件系统与权限」是 11-02 晚的提前学，已拆到 `26_11_02/day02_预习.md`，`26_11_02/day01.md` 只留装机。

## 1. 闭卷小测：80.5 / 100（压线过，超线 0.5）

10:25 起笔、10:58 停笔（配了 80 min，33 min 就交卷）。只许 `man` 和 `--help`，不翻笔记和之前的 day01。

| 题 | 考点 | 得分 | 情况 |
|---|---|---|---|
| 1 | FHS 八目录各放什么 | 13.5 / 16 | `/var` 答成「内存里」——错，`/var` 在**磁盘**上（`/var/log`、`/var/cache`），内存里的是 `/run`、`/proc`、`/sys`；`/bin` 答成「apt 之类的」——现代 Ubuntu 里 `/bin` 就是**软链到 `/usr/bin`** |
| 2 | 默写 644 / 755 / 600 / 777 | 12 / 12 | 全对 |
| 3 | `-rwxr--r--` → 数字 | 6 / 6 | 744，对 |
| 4 | `umask 0002` 反推默认权限 | 12 / 12 | 文件 664 / 目录 775；**但推导口径要改**：不是「666 − 002」，是 `666 & ~umask`（按位与补码），答案对是碰上了，遇上 `umask 0033` 就会算错 |
| 5 | `ls -l` 十位逐位拆解 | **0 / 6** | **全空** |
| 6 | 目录的 `x` 位与 `r` 位差别 | 10 / 10 | 对（`x`=能进/能穿，`r`=能列名） |
| 7 | 符号法 `chmod g+w` / `o-w` / `u+x,g-w` | **0 / 6** | **全空** |
| 8 | `chmod 755 a.txt && 755 b.txt` 为何报错、怎么改 | 3 / 6 | 原因对（`755` 不是命令）；改法错：写成 `chmod 755 (a.txt && b.txt)` —— 括号是**子 shell**，`&&` 在里面照样把 `755` 当命令。正确就是 **`chmod 755 a.txt b.txt`** |
| 9 | `/usr` 与 `/opt` 的区别 | 6 / 6 | 对 |
| 10 | 硬链与软链 | 18 / 20 | 同 inode / 独立 inode、`120000` 模式说对；软链断链后的行为没答全 |

**结论**：数值法（644/755/600/777）已经通了，塌的是两块——**`ls -l` 元信息的读法**（第 5 题）和**符号法**（第 7 题）。两道全空不是时间不够，是压根没会。11-07 小测① 必考。

## 2. 特殊位三件套（各一组前后对比）

```bash
mkdir -p ~/lab/day03/{setuid,setgid,sticky,umask}
cd ~/lab/day03
```

### 2.1 setuid —— 用 `passwd` 只读对照，不改系统文件

```bash
ls -l /usr/bin/passwd            # -rwsr-xr-x 1 root root  59976 2月 6 2024 /usr/bin/passwd
sudo cp /usr/bin/passwd ~/lab/day03/setuid/ld_root   # 先复制一份，绝不改 /usr/bin/passwd
sudo chown root:root ~/lab/day03/setuid/ld_root
sudo chmod 755 ~/lab/day03/setuid/ld_root            # -rwxr-xr-x
sudo chmod u+s ~/lab/day03/setuid/ld_root            # -rwsr-xr-x   ← 属主 x 位变 s
sudo chmod u-s ~/lab/day03/setuid/ld_root            # -rwxr-xr-x   ← 复原
```

- 属主 `x` 位上的 `s` = setuid：**执行时以文件属主身份跑**。`passwd` 要写 `/etc/shadow`（只有 root 能写），靠的就是它。
- 若属主**没有** `x` 位，`s` 会显示成大写 `S` —— 这是陷阱，`S` 意味着 setuid 位设了但**不生效**。
- 数字法：`chmod 4755`（第一位 4 = setuid）。

### 2.2 setgid —— 目录上「新建文件继承属组」

```bash
mkdir -p ~/lab/day03/setgid/shared && cd ~/lab/day03/setgid/shared
touch before && ls -l ~/lab/day03/setgid/shared
# -rw-r--r-- 1 wrmh wrmh ... before        ← 属组 wrmh

sudo chgrp nogroup ~/lab/day03/setgid/shared
chmod 2755 ~/lab/day03/setgid/shared
touch after && ls -l ~/lab/day03/setgid/shared
# -rw-r--r-- 1 wrmh nogroup ... after      ← 属组变成 nogroup

sudo usermod -aG nogroup $USER
newgrp nogroup                                # 换一把带新属组的 shell
rm -f after && touch after && ls -l after
# -rw-r--r-- 1 wrmh nogroup ... after      ← 这一步才真正确认继承
```

- 数字法：`chmod 2755`（第一位 2 = setgid）；`ls -ld` 里属组 `x` 位显示 `s`。
- **卡点记录（本日最大卡点，约 20 min）**：`chmod 2755` 之后 `touch` 出来的文件属组还是 `wrmh`，一度以为 setgid 没生效。真正原因是——**内核新建文件时只能把属组设成「当前进程所属的组」，而我的进程属组列表里还没有 `nogroup`**，所以位设对了却无法继承。必须 `usermod -aG` 把组加进账号、再 `newgrp` 让**当前 shell** 拿到这个组（`groups` 能看到 `nogroup`），继承才会发生。
- 顺带结论：**setgid 是「继承」不是「强制」**，它改的是新文件的默认属组，不改已有文件的属组。

### 2.3 sticky —— 目录里「只能删自己的」

```bash
mkdir -p ~/lab/day03/sticky/shared
chmod 777 ~/lab/day03/sticky/shared
ls -ld ~/lab/day03/sticky/shared      # drwxrwxrwx
chmod +t ~/lab/day03/sticky/shared
ls -ld ~/lab/day03/sticky/shared      # drwxrwxrwt   ← t 出现在「其他」的 x 位上
touch ~/lab/day03/sticky/shared/mine
```

- 典型例子：`/tmp` 就是 `drwxrwxrwt`。大家都能写，但**只能删自己建的文件**。
- 数字法：`chmod 1777`（第一位 1 = sticky）。

## 3. `umask` 反推 3 组 × 2 类（自己写 `for` 循环，一次跑对 6/6）

```bash
cd ~/lab/day03/umask
for u in 0022 0002 0077; do
  ( umask "$u"; touch "file_$u"; mkdir "dir_$u";
    printf 'umask=%s\n' "$u"; stat -c '%a %n' "file_$u" "dir_$u" )
done
```

| umask | 新文件 | 新目录 | 推导 |
|---|---|---|---|
| `0022` | **644** | **755** | 文件 666 & ~022、目录 777 & ~022 |
| `0002` | **664** | **775** | 文件 666 & ~002、目录 777 & ~002 |
| `0077` | **600** | **700** | 文件 666 & ~077、目录 777 & ~077 |

- 我机器默认 `umask = 0002`（所以平时新建是 664/775，不是 644/755）。
- **口径纠正**：推导是 `基准 & ~umask`（按位与上掩码的反），不是「基准 − umask」。减法在 `0022` 这种「位不重叠」的场合碰巧对，`umask 0033` 就会错。
- 括号 `( ... )` 是子 shell：`umask` 只在里面改，出了括号回到原值，所以 3 组之间互不污染。

## 4. 项目化：`scripts/` 三个脚本（755 + `bash -n` + git mode `100755`）

```bash
cd ~/ros-learning && mkdir -p scripts && cd scripts
```

| 脚本 | 干什么 | 关键写法 |
|---|---|---|
| `sysinfo.sh` | 系统信息一屏 | `uname -a`、`df -h`、`free -h` |
| `hello_ros.sh` | ROS 环境快照 | `lsb_release -d`、`cat /etc/os-release \| grep PRETTY_NAME \| cut -f2`、`[ -d /opt/ros ]` 判有无；无则 `echo "ROS: Not Installed"` |
| `backup.sh` | 备份笔记 | `tar -czf "$DST" "$SRC"`，`DST="$HOME/backup/$(date +%F).tar.gz"` |

```bash
chmod 755 *.sh
bash -n sysinfo.sh && bash -n hello_ros.sh && bash -n backup.sh   # 语法检查，全部无输出即过
git config core.fileMode          # true —— 必须为 true，否则权限位进不了 git
git add scripts/
git ls-files -s scripts/          # 三行都是 100755
./sysinfo.sh && ./hello_ros.sh && ./backup.sh
```

实测输出：

- `./hello_ros.sh` → `== ROS Env Summary ==` / `Ubuntu 22.04.5 LTS` / `6.8.0-138-generic` / **`ROS: Not Installed`**（还没装 ROS，正确）；
- `./sysinfo.sh` → 内核行 + `df -h`（`/dev/nvme0n1p3 147G 16G 124G 12% /`）+ `free -h`（15Gi 总 / 3.2Gi 已用）；
- `./backup.sh` → `Backup saved to /home/wrmh/backup/2026-11-03.tar.gz`（`tar` 顺带警告「从成员名中删除开头的/」，无害）。

踩到的两个小坑：

1. `bash -n hello_ros.s` —— 少打一个 `h`，报「没有那个文件或目录」。**敲之前先 `ls` 一眼**。
2. `./sysinfo.sh` 在 `~/ros-learning` 下敲，报「没有那个文件或目录」—— 不是权限也不是 shebang，是 **`cwd` 不对**（脚本在 `scripts/` 里）。`./` 表示当前目录，当前目录不是脚本所在目录，就找不到。

## 5. SSH 上传链路（今天最有价值的一段）

### 5.1 首次 `commit` 失败：git 身份没配

```bash
git commit -m "code(week01): 26_11_02 权限/目录树/软硬链接/重定向练习"
# *** 请告诉我您是谁。 作者身份未知
# fatal: 无法自动检测邮件地址（得到 'wrmh@...（none）'）

git config --global user.name "wrmh"
git config --global user.email "a2165426113@163.com"
git config --global --list        # 复核两个键都在
```

`git remote -v` 配好 ≠ 能提交：**remote 管「推到哪」，`user.name`/`user.email` 管「谁提交的」**，两件事。

### 5.2 从 HTTPS 换成 SSH

```bash
ssh-keygen -t ed25519 -C "a2165426113@163.com"   # 回车三次（默认路径、空口令）
cat ~/.ssh/id_ed25519.pub                        # 复制整行，粘到 GitHub → Settings → SSH keys
ssh -T git@github.com
# The authenticity of host 'github.com (20.205.243.166)' can't be established.
# ... 继续连接 (yes/no/[fingerprint])? yes
# Hi wrmh! You've successfully authenticated, but GitHub does not provide shell access.

git remote set-url origin git@github.com:wrmh/ros-learning.git
git remote -v                                    # 两行都要是 git@github.com:...
```

- 那句 `Hi wrmh!` 就是成功标志；后半句「不提供 shell」是正常的，GitHub 只给 git 协议。
- 第一次连会问指纹：输入 `yes` 后才写进 `~/.ssh/known_hosts`，之后不再问。
- 踩过的弯路：昨天 `push` 一直 `Recv failure: Connection was reset`（HTTPS 被 socks 代理拖着），换 SSH 之后一次过。

### 5.3 三处目录合并 + 提交推送

```bash
cd ~/ros-learning
mkdir -p code/week01 && mv ~/ros_learning/26_11_02 code/week01/ && rmdir ~/ros_learning
git add code/week01
git commit -m "code(week01): 26_11_02 权限/目录树/软硬链接/重定向练习"
git push origin main          # 00af052..f2f1d74  main -> main
```

远端实际收录 11 个文件（`git ls-tree -r origin/main` 可查）：

```
code/week01/26_11_02/600.txt  644.txt  755.txt  file1.txt  file2.txt  file3.txt
code/week01/26_11_02/hard_link.txt  my_list.txt  soft_link.txt  src/file.txt  test/notes.md
```

其中 `soft_link.txt` 的模式是 **`120000`**（不是 100644）—— git 记录的软链就是「一个指向目标的符号链」，`120000` 是它在 git 里的标准 mode，clone 下来会还原成真软链。硬链则相反：**普通文件 mode，链接计数看不出**（git 不存 inode），clone 后是两个独立文件。

## 6. 提前学：`sshd` + `tmux`（11/05 的安装环节提前做完）

```bash
sudo apt update
sudo apt install openssh-server -y     # 4 个包；自动生成 RSA/ECDSA/ED25519 三套 host key
sudo systemctl status ssh
# ● ssh.service - OpenBSD Secure Shell server
#    Active: active (running) since 2026-11-03 19:46:21 CST
#     Main PID: 8298 (sshd)
sudo apt install tmux -y
tmux -V                                # tmux 3.2a
```

- 关键证据：`sshd` 监听 **0.0.0.0:22** 与 `:22`，且 `enabled`（开机自启）；不是只「装上了」而是**真在跑**。
- 还没做的两件（留给 11/05）：Windows 端 VS Code Remote-SSH 实际连上来；`tmux` 三窗格实操（`tmux new -s work` → `Ctrl-b %` 竖分 / `Ctrl-b "` 横分 / `Ctrl-b d` 脱离 / `tmux attach -t work` 回来）。

## 7. 本日踩坑汇总

| # | 现象 | 根因 | 结论 |
|---|---|---|---|
| 1 | `chmod 2755` 后新文件属组不变 | 当前进程属组列表里没有 `nogroup`，内核无法继承一个自己不属于的组 | `usermod -aG nogroup $USER` + `newgrp nogroup`，`groups` 里看到才算生效 |
| 2 | `git commit` 报「作者身份未知」 | 只配了 remote，没配 `user.name`/`user.email` | 两件事分开配，`git config --global --list` 复核 |
| 3 | `./sysinfo.sh` 报「没有那个文件或目录」 | `cwd` 在 `~/ros-learning`，脚本在 `scripts/` | 先 `cd scripts`，或敲 `./scripts/sysinfo.sh` |
| 4 | `bash -n hello_ros.s` 报错 | 少打一个 `h` | 敲之前 `ls` 看一眼 |
| 5 | `ssh -T` 卡在指纹确认 | 首次连接未写 `known_hosts` | 输入 `yes`（或先 `ssh-keyscan github.com >> ~/.ssh/known_hosts`） |

## 8. 与计划的对账

- **完成**：小测 80.5（V2 过）；特殊位 3/3（V3 过）；`umask` 6/6（V4 过）；三脚本 755 + git mode `100755`（V5 过）；`f2f1d74` 已推（V6 过）。
- **没完成**：T0 两条悬案复述（0/2，V1 未过 —— EFI 在哪、163 GB→147 GiB 仍讲不出）；`scripts/` 只 `git add` 没 `commit`（**当前只存在于这台 Ubuntu 本机，不进远端就等于没备份**）。
- 欠账见 `DailyPlan\_progress.md` 欠账清单。

## 9. 明日第一步

**把 11-02 忘掉的命令重新敲一遍并背下来**：`sudo lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME`、`sudo blkid`、`sudo efibootmgr -v`、`df -h /`、`du -sh /* 2>/dev/null | sort -rh | head` —— 敲完能脱稿讲「EFI 分区在哪、共几个、根分区用了多少」。

紧接着 20 min 重做小测第 5、7 题（各造 3 个实例），再做 11/04 正题：`grep`/`sed`/`find` + `ps`/`top`/`kill`（`>`/`>>` 与 `du|sort|head` 已会，只复述 10 min）。
