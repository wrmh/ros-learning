# day02 预习（写于 11-02 晚）· 2026-11-02 · Linux 文件系统与权限

> 注意：这是 **11-02 晚提前学** 的流水，正日子算 11-03（第 2 天），正式笔记在 `26_11_03/day02.md`。
> 环境：Ubuntu 22.04，当时工作目录 `~/ros_learning/26_11_02`（下划线；11-03 已并入仓库 `~/ros-learning/code/week01/26_11_02`）。


> 命令流水（本人按顺序敲的）。环境：Ubuntu 22.04，工作目录 `~/ros_learning/26_11_02`。
> 证据图在同级 `26_11_02/`：`644,755,600.png`、`rwx+ugo+umask.png`、`建目录树.png`、`重定向+管道.png`、`重定向执行结果.png`、`df+du.png`、`lsblk.png`

## 1. 权限：文件与目录

```bash
mkdir -p ~/ros_learning/26_11_02
touch file1.txt file2.txt file3.txt
ls -l file1.txt
chmod g+w file1.txt
ls -l file1.txt
mkdir test
chmod 750 test
ls -l test
touch test/notes.md
ls -l test/notes.md
chmod g-w test/notes.md
touch 644.txt 755.txt 600.txt
chmod 644 644.txt && chmod 755 755.txt && chmod 600 600.txt
stat -c '%a %n' 644.txt 755.txt 600.txt
ls -l 644.txt 755.txt 600.txt
umask
```

## 2. 目录树

```bash
mkdir -p ~/ros_learning/26_11_02/{src,doc,test}/v1
tree ~/ros_learning/26_11_02
```

## 3. 链接与重定向

```bash
echo "Hello Linux" > src/file.txt
ln src/file.txt hard_link.txt
ln -s src/file.txt soft_link.txt
ls -li src/file.txt hard_link.txt soft_link.txt
ls -li src/file.txt hard_link.txt soft_link.txt > my_list.txt
ls -li src/file.txt hard_link.txt soft_link.txt >> my_list.txt
```

## 4. 结论

- `644 / 755 / 600` 三项实测通过：`stat -c '%a %n'` 输出 `644 644.txt` / `755 755.txt` / `600 600.txt`，`ls -l` 对应 `-rw-r--r--` / `-rwxr-xr-x` / `-rw-------`。
- `chmod g+w` / `g-w` 是符号法：只动「属组」这一位，其余位不变；数字法 `chmod 750` 是一次改三位。
- 硬链与源文件**同 inode**（`ls -li` 第一列相同，链接计数 2），软链是**独立 inode**，`ls -l` 显示 `-> 目标`。
- `umask` = `0002`，所以新建文件默认 `664`、新建目录默认 `775`，不是常见的 `644/755`。

## 5. 本日踩到 / 复习时注意

- `chmod 644 a.txt && 755 b.txt` 会报 **`755: 未找到命令`**——`&&` 后面必须是完整命令，`chmod` 不能省。截图 `644,755,600.png` 里第一次就是这么报错的，第二次补全后通过；第 1 节已按正确写法记。
- `mkdir -p ~/ros_learnig/...` 少一个 `n`，会悄悄建出一个新目录而不是目标目录。这次是拼写失误，已修正为 `ros_learning`。
- `soft.link.txt`（点）与 `soft_link.txt`（下划线）是两个不同文件，`ls` 会报「没有那个文件或目录」；全文已统一为 `soft_link.txt`。

## 6. 与计划的对账

- 已完成：A 组建目录树、B 组改权限（644/755/600 + `doc` 类目录 750）、软硬链接（`week1_read.md` 自述疑问之一）、重定向 `>` `>>` 与管道。
- 未完成：`find`/通配符、D 组批量改名——按 `26_11_03\_adjust.md` 不记欠账，压到 11/08 弹性日。
