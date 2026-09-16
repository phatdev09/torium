#!/bin/bash
# ==============================================================================
# ToriumBot Watchdog Daemon Installation Script
# Target: palera1n Rootful Jailbreak (iOS 15-16)
# ==============================================================================

set -e

echo "[+] Bắt đầu cài đặt ToriumBot Watchdog Daemon..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Lỗi: Vui lòng chạy script với quyền root (sudo)."
  exit 1
fi

# Compile daemon if source exists and clang is present
if [ -f "watchdog_daemon.c" ]; then
    echo "[+] Biên dịch watchdog_daemon.c..."
    clang -arch arm64 -isysroot / -framework Foundation -o watchdog_daemon watchdog_daemon.c || true
fi

# Copy daemon binary
if [ -f "watchdog_daemon" ]; then
    echo "[+] Copy binary vào /usr/local/bin/watchdog_daemon..."
    mkdir -p /usr/local/bin
    cp watchdog_daemon /usr/local/bin/watchdog_daemon
    chmod 755 /usr/local/bin/watchdog_daemon
    chown root:wheel /usr/local/bin/watchdog_daemon
else
    echo "[-] Cảnh báo: Chưa tìm thấy binary watchdog_daemon."
fi

# Copy LaunchDaemon plist
if [ -f "com.toriumbot.watchdog.plist" ]; then
    echo "[+] Cài đặt LaunchDaemon plist vào /Library/LaunchDaemons/..."
    cp com.toriumbot.watchdog.plist /Library/LaunchDaemons/com.toriumbot.watchdog.plist
    chmod 644 /Library/LaunchDaemons/com.toriumbot.watchdog.plist
    chown root:wheel /Library/LaunchDaemons/com.toriumbot.watchdog.plist

    # Unload previous instance if active
    launchctl unload /Library/LaunchDaemons/com.toriumbot.watchdog.plist 2>/dev/null || true

    # Load new LaunchDaemon
    echo "[+] Kích hoạt LaunchDaemon qua launchctl..."
    launchctl load -w /Library/LaunchDaemons/com.toriumbot.watchdog.plist
    echo "[✓] Watchdog Daemon đã được cài đặt và kích hoạt thành công!"
fi
