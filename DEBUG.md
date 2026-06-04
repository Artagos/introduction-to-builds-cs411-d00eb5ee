# DEBUG.md

## Hypotheses (ranked by likelihood)

1. **Security Group missing inbound rule for port 4444** — The EC2 Security Group has no rule permitting TCP 4444 from `0.0.0.0/0`, so AWS silently drops the packet before it reaches the instance, producing an indefinite hang rather than a refused connection.

2. **Application bound to loopback (127.0.0.1) only** — The app is listening exclusively on the loopback interface; traffic arriving on the public NIC finds no socket to hand off to, and the connection stalls without an RST.

---

## Verification Steps

1. **Security Group** — Check inbound rules via CLI:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <sg-id> \
     --query 'SecurityGroups[].IpPermissions'
   ```
   Or in the Console: EC2 → Security Groups → Inbound rules. A missing TCP/4444 entry confirms hypothesis 1.

2. **Listen address** — SSH into the instance and run:
   ```bash
   ss -tlnp | grep 4444
   ```
   If the output shows `127.0.0.1:4444` instead of `0.0.0.0:4444` or `*:4444`, hypothesis 2 is confirmed.

---

## Fix

**Hypothesis 1 (most likely fix):** Add an inbound SG rule — no Terraform rewrite needed:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 4444 \
  --cidr 0.0.0.0/0
```

**Hypothesis 2 fix:** Change the app's bind address from `127.0.0.1` to `0.0.0.0` in its config or start command (e.g. `--host 0.0.0.0`), then restart the process.

---

## Underlying Lesson

A **dropped** packet (SG/firewall silently discards it) leaves the sender with no reply, so the connection hangs until timeout; a packet that **reaches a closed port** gets an immediate TCP RST from the OS, which the client surfaces as "connection refused" — the failure mode reveals exactly where in the stack the packet died.