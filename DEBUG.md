# DEBUG.md

## The error
`exec /app/main: exec format error` — the container starts and dies immediately.
This means the binary inside the image was compiled for a different CPU architecture
than the host trying to run it.

---

## 1. Two ranked hypotheses

**Hypothesis 1 (most likely) — The image was built for ARM and pushed as a single-arch manifest**
You built on Apple Silicon (ARM64) with a plain `docker build`, which produces an ARM64
binary by default. The `docker` VM is x86_64 and cannot execute an ARM64 binary.

**Hypothesis 2 (less likely) — The Go binary was cross-compiled with the wrong GOARCH**
`GOOS=linux` was set but `GOARCH` was left unset or explicitly set to `arm64`, so even
if the image manifest looks multi-arch, the binary inside targets the wrong architecture.

---

## 2. Verification steps

**For Hypothesis 1** — inspect the manifest architecture on the docker VM:
```bash
docker inspect ttl.sh/artagos:2h --format='{{.Architecture}}'
# Returns "arm64" → confirms you pushed an ARM-only image
```

**For Hypothesis 2** — check what the binary itself declares:
```bash
docker run --rm --entrypoint="" ttl.sh/artagos:2h file /app/app
# Returns "ELF 64-bit LSB executable, ARM aarch64" → wrong arch binary
# Should say "x86-64" for the docker VM to run it
```

---

## 3. The fix

Build a multi-arch image with `buildx` and push both ARM64 and AMD64 variants in a
single manifest. The x86_64 VM will then automatically pull the right one:

```bash
# One-time setup: create a buildx builder that supports multi-arch
docker buildx create --use --name multi-arch-builder

# Build and push both architectures in one command
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ttl.sh/artagos:2h \
  --push \
  .
```

Your Dockerfile already has `CGO_ENABLED=0 GOOS=linux` in the build stage — that's
enough. `buildx` handles setting `GOARCH` correctly for each platform automatically
via the build environment. No Dockerfile changes needed.

---

## 4. The underlying lesson

"The image is built" only promises that the layers were assembled successfully on the
build host — it says nothing about whether the binary inside is executable on the
runtime host's CPU architecture.