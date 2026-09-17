#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>
#include <spawn.h>
#include <syslog.h>

#define CHECK_INTERVAL_SECONDS 60
#define HEARTBEAT_FILE "/tmp/toriumbot.heartbeat"
#define HEARTBEAT_TIMEOUT_SECONDS 120
#define TORIUM_BUNDLE_ID "com.toriumbot.app"
#define LOG_TAG "ToriumWatchdog"

#include <dlfcn.h>
#include <sys/wait.h>

extern char **environ;

static int run_cmd(const char *cmd) {
    if (!cmd || strlen(cmd) == 0) return -1;
    typedef int (*sys_fn)(const char *);
    sys_fn sys = (sys_fn)dlsym(RTLD_DEFAULT, "system");
    if (sys) {
        return sys(cmd);
    }
    pid_t pid;
    const char *argv[] = {"sh", "-c", cmd, NULL};
    if (posix_spawn(&pid, "/bin/sh", NULL, NULL, (char* const*)argv, environ) == 0) {
        int status;
        waitpid(pid, &status, 0);
        return WEXITSTATUS(status);
    }
    return -1;
}

// Checks if ToriumBot process is running via pgrep or heartbeat file
int is_toriumbot_alive() {
    // 1. Check process table via pgrep
    int ret = run_cmd("pgrep -x ToriumBot > /dev/null 2>&1");
    if (ret == 0) {
        // Process exists, now verify heartbeat staleness
        struct stat st;
        if (stat(HEARTBEAT_FILE, &st) == 0) {
            time_t now = time(NULL);
            if (now - st.st_mtime > HEARTBEAT_TIMEOUT_SECONDS) {
                syslog(LOG_WARNING, "ToriumBot heartbeat is stale (%ld seconds old).", now - st.st_mtime);
                return 0; // Frozen/stuck
            }
        }
        return 1; // Process is healthy
    }
    return 0; // Process not running
}

// Launches or respawns ToriumBot app via SpringBoard open command
void respawn_toriumbot() {
    syslog(LOG_NOTICE, "Respawning ToriumBot (%s)...", TORIUM_BUNDLE_ID);
    
    // Attempt 1: Using uiopen / open command on jailbroken device
    int res = run_cmd("uiopen --bundle com.toriumbot.app > /dev/null 2>&1");
    if (res != 0) {
        // Attempt 2: Using openURL fallback
        run_cmd("open com.toriumbot.app > /dev/null 2>&1");
    }
}

int main(int argc, char *argv[]) {
    // Daemonize process
    openlog(LOG_TAG, LOG_PID | LOG_CONS, LOG_DAEMON);
    syslog(LOG_NOTICE, "ToriumBot Watchdog Daemon started 24/7 monitor.");

    while (1) {
        if (!is_toriumbot_alive()) {
            syslog(LOG_ERR, "ToriumBot is NOT running or responsive. Triggering auto-restart...");
            respawn_toriumbot();
        }
        sleep(CHECK_INTERVAL_SECONDS);
    }

    closelog();
    return 0;
}
