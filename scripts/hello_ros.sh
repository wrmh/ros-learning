#!/bin/bash
echo "=== ROS Env Summary ==="
lsb_release -d 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME
uname -r
if [ -d "/opt/ros" ]; then
    echo "ROS: Installed"
else
    echo "ROS: Not Installed"
fi
