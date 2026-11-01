做什么 / 怎么验 / 卡住怎么办
  1. **备份确认** — `F:\backup\2026-10-31_pre_install\` 里 Desktop / Documents / Downloads 三份都在（22.43 GiB）→ 验：能打开 3 个文件
  2. **腾空间**（在 Windows 里做）— `diskmgmt.msc` → C: 右键「压缩卷」→ 压出 ≥ 80 GB → 验：磁盘管理里出现一块黑色「未分配」
  3. **U 盘启动**（不进 BIOS）— 双击 `Notes\Phase0\从U盘启动.cmd` → 使用设备 → `UEFI: HIKSEMI` → GRUB 选 `Install Ubuntu` → 验：进到安装器首屏；Secure Boot 保持 Enabled
  4. **安装** — 安装类型选「其它选项」→ 用那块 80 GB 未分配做 `/` 与 swap → 引导器装到内置盘已有 EFI 分区（**不新建第二个 EFI**）→ 时区 Shanghai、用户名全小写、勾「安装第三方驱动」→ 验：重启出现 GRUB 且能进桌面
  5. **换源** — 备份后改 `/etc/apt/sources.list` 为清华或阿里云 jammy main/restricted/universe/multiverse → 验：`sudo apt update` 结尾无 `Err:`
  6. **NVIDIA 驱动** — `ubuntu-drivers devices` 看推荐版本 → `sudo ubuntu-drivers autoinstall` → 重启 → 验：`nvidia-smi` 出表、能读到 `Driver Version`
  7. **输入法 + 双系统验收** — fcitx5（`fcitx5` + `fcitx5-chinese-addons`）或 ibus → 验：终端里能打「机器人」；重启能在 GRUB 里选回 `Windows Boot Manager`

  **回滚预案**：①Windows `diskmgmt.msc` 删 Ubuntu 分区；②`bootrec /rebuildbcd` 或 Windows U 盘修引导；③连 Windows 都进不去 → 高级启动「启动修复」。