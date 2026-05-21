# Debugging GLIBC Version Mismatch

## Hypotheses

1. **Hypothesis 1 (Most Likely): Glibc backward-incompatibility.**
   * **Reason:** The Jenkins build machine is running a modern Linux distribution featuring a newer version of `glibc` (specifically version 2.34 or higher), whereas the customer's older Ubuntu 18.04 VM only supplies `glibc` up to version 2.27. Because `glibc` guarantees forward-compatibility but explicitly lacks backward-compatibility for newer symbols, the binary fails to execute on the older system.
2. **Hypothesis 2 (Less Likely): Rogue CGO dependency.**
   * **Reason:** Even if the Go code itself doesn't explicitly import `"C"`, a native Go package in the dependency tree (such as `net` or `os/user`) might have automatically triggered CGO to fall back on host system libraries during the standard `go build` execution.

---

## Verification Steps

### Verification for Hypothesis 1
Run the following command on the **customer's Ubuntu 18.04 VM** to check the native version of `glibc` available on their system:
```bash
ldd --version
```

* What the output tells me: If the output prints a version string lower than 2.34 (e.g., `ldd (Ubuntu GLIBC 2.27-3ubuntu1) 2.27`), it conclusively proves that the customer's platform cannot satisfy the runtime dependency of the compiled binary.

### Verification for Hypothesis 2
Run the following command on the Jenkins build machine (or on the binary itself) to check what specific shared library versions the executable is hunting for:
```bash
objdump -p ./main | grep GLIBC_
```

* What the output tells me: This will spit out an explicit list of versioned symbols required by the binary. If I see a line explicitly naming `GLIBC_2.34`, it confirms the binary was linked against the newer host system runtime during compilation.

---

## The Fix
To fix this minimally without introducing Docker or altering code, compile the binary on the Jenkins machine by forcing CGO to be disabled:
```bash
CGO_ENABLED=0 go build -o main main.go
```

### Why this fixes it
By default, the Go toolchain dynamically links to the host machine's `glibc` providers for tasks like DNS resolution or user lookup. By explicitly prefixing the compilation with `CGO_ENABLED=0`, we instruct the compiler to switch to Go's native, pure-Go network and OS implementations. The linker transitions from generating a dynamically linked binary that relies on an external `/lib64/ld-linux-x86-64.so.2` interpreter to spitting out a fully self-contained, statically linked binary. It completely eliminates runtime dependencies on any version of `glibc`, allowing the executable to run flawlessly on Ubuntu 18.04 or any other Linux kernel.

---

## Underlying Lesson
Go binaries dynamically link to glibc by default, and glibc is forward- but not backward-compatible across versions. 