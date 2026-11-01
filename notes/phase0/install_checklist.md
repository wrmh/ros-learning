做什么 / 怎么验 / 卡住怎么办

1. **备份确认** — `F:\backup\2026-10-31_pre_install\` 里 Desktop / Documents / Downloads 三份都在（22.43 GiB）→ 验：能打开 3 个文件
   ↳ 卡住：目录打不开或提示无权限 → 右键属性→安全→给自己「完全控制」；数字对不上 → 重跑一遍镜像复制，别靠「看着像全了」

2. **腾空间**（在 Windows 里做）— `diskmgmt.msc` → C: 右键「压缩卷」→ 压出 ≥ 80 GB → 验：磁盘管理里出现一块黑色「未分配」
   ↳ 卡住：压缩卷压不出 80 GB（可用压缩量远小于剩余空间）→ 先关休眠（管理员 `powercfg /h off`）再关系统保护/还原点，然后重开磁盘管理

3. **U 盘启动**（不进 BIOS）— 双击 `Notes\Phase0\从U盘启动.cmd` → 使用设备 → `UEFI: HIKSEMI` → GRUB 选 `Install Ubuntu` → 验：进到安装器首屏；Secure Boot 保持 Enabled
   ↳ 卡住：设备列表里没有 `UEFI: HIKSEMI` → 换一个 USB 口（优先机身后置/直连，不经扩展坞）再重来一次；出现两个同名项 → 选带 `UEFI:` 前缀那个

4. **安装** — 安装类型选「其它选项」→ 用那块 80 GB 未分配做 `/` 与 swap → 引导器装到内置盘已有 EFI 分区（**不新建第二个 EFI**）→ 时区 Shanghai、用户名全小写、勾「安装第三方驱动」→ 验：重启出现 GRUB 且能进桌面
   ↳ 卡住：分区界面看不到「未分配」→ 确认是从 `UEFI:` 项进来的、且 Windows 侧确实压出了未分配空间；提示「没有 EFI 分区」→ 退回上一步重新选引导器位置，别自己新建

5. **换源** — 备份后改 `/etc/apt/sources.list` 为清华或阿里云 jammy main/restricted/universe/multiverse → 验：`sudo apt update` 结尾无 `Err:`
   ↳ 卡住：改了源还是 `Err:` → 先 `ping -c 2 mirrors.tuna.tsinghua.edu.cn` 分清是网络还是写错行；`Err:` 里出现 `NO_PUBKEY` → 补 `sudo apt-key adv` 或改用 `signed-by` 写法

6. **NVIDIA 驱动** — `ubuntu-drivers devices` 看推荐版本 → `sudo ubuntu-drivers autoinstall` → 重启 → 验：`nvidia-smi` 出表、能读到 `Driver Version`
   ↳ 卡住：`nvidia-smi` 报「couldn't communicate with the driver」→ 重启一次再看；仍不行 → `Ctrl+Alt+F3` 进 TTY，`sudo apt purge 'nvidia*'` 后改装 `nvidia-driver-535`（装机总耗时超 4 h 还没桌面 → 按计划书预案切 WSL2）

7. **输入法 + 双系统验收** — fcitx5（`fcitx5` + `fcitx5-chinese-addons`）或 ibus → 验：终端里能打「机器人」；重启能在 GRUB 里选回 `Windows Boot Manager`
   ↳ 卡住：装了输入法但终端打不出中文 → 检查 `im-config` 选的是不是 fcitx5，注销重进；GRUB 里没有 `Windows Boot Manager` → 进 Linux 跑 `sudo update-grub` 再重启

**回滚预案**：①Windows `diskmgmt.msc` 删 Ubuntu 分区；②`bootrec /rebuildbcd` 或 Windows U 盘修引导；③连 Windows 都进不去 → 高级启动「启动修复」。
