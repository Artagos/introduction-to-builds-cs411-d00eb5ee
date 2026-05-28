

## 1. Hypotheses

1. **The pipeline launches `./main` as a child of the SSH session (highest likelihood).**
   The process is spawned without detaching from the controlling terminal, so when the SSH session closes, SIGHUP is delivered to the process group and `./main` exits.

2. **The pipeline binds `./main` to the SSH agent's forwarded socket or a shell environment variable that becomes invalid on disconnect (lower likelihood).**
   The app may depend on an environment exported only within the SSH session (e.g. `SSH_AUTH_SOCK`), causing it to crash on the first I/O attempt after the session drops rather than on the signal itself.

---

## 2. Verification Steps

**Hypothesis 1** — confirm SIGHUP is the killer:

```bash
# On target, while the pipeline is running and ./main is up:
ps -eo pid,ppid,pgid,sid,comm | grep main
# If PGID == SID and both match the sshd child PID, the process is in the
# SSH session's process group and will be HUP'd on logout.
```

Alternatively, check the last signal received right after the session drops:

```bash
# Immediately after a failed pipeline run:
journalctl -xe | grep main
# or
dmesg | tail -20
# A "killed by signal 1" line confirms SIGHUP as the cause.
```

**Hypothesis 2** — confirm an env-variable dependency:

```bash
# On target, run the app with a clean environment and observe whether it
# survives a deliberate SSH disconnect:
env -i HOME=/root PATH=/usr/local/bin:/usr/bin:/bin ./main &
sleep 5 && curl localhost:4444
# If it survives with a clean env but not the normal one, a session variable
# is the culprit.
```

---

## 3. Fix

Add a `nohup` + output redirect to the pipeline's "Copy + run on target" shell step (no Docker, no restructuring required):

```bash
# In the Jenkins pipeline shell step that starts the app:
ssh user@target "nohup /path/to/main > /var/log/main.log 2>&1 & echo \$! > /var/run/main.pid"
```

`nohup` ignores SIGHUP and closes stdin, `&` backgrounds the process, and the explicit `> ... 2>&1` redirect detaches it from the terminal's file descriptors. The PID file lets subsequent runs kill the previous instance cleanly before restarting:

```bash
ssh user@target "[ -f /var/run/main.pid ] && kill \$(cat /var/run/main.pid) 2>/dev/null; \
  nohup /path/to/main > /var/log/main.log 2>&1 & echo \$! > /var/run/main.pid"
```

If `systemd` is available on `target`, a drop-in unit file is the more robust long-term alternative:

```ini
# /etc/systemd/system/main.service
[Unit]
Description=main API service

[Service]
ExecStart=/path/to/main
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload && systemctl enable --now main
# Pipeline deploy step then becomes simply:
# systemctl restart main
```

---

## 4. Underlying Lesson

"Process exists right now" only means the kernel has a PID entry for it at this instant; "process is supervised" means something (a init system, a process manager, or at minimum `nohup`/`disown`) guarantees the process is decoupled from any ephemeral session and will be restarted if it exits — two entirely different properties that green CI logs cannot distinguish between.
