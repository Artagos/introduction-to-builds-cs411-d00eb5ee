# Reflection — introduction-to-builds
## Analysis of Go Binary Size Differences
The size reduction observed when compiling with the flags `-ldflags='-s -w'` is caused by removing **debugging information** and **symbol tables**. 

By passing these flags, the compiler strips out non-essential metadata, resulting in a **~31.8% smaller binary** (~4.96 MB vs. ~7.28 MB) without changing how your code actually executes.

---

### Technical Breakdown of `-ldflags='-s -w'`

### 1. `-w` (Omit DWARF Debugging Information)
* **What it does:** This flag instructs the linker to omit DWARF debugging information from the binary.
* **Impact:** DWARF data allows tools like debuggers (`gdb` or `delve`) to step through your source code line-by-line or inspect variable states at runtime. Removing it saves a substantial amount of space.

### 2. `-s` (Omit Symbol Table & Build ID)
* **What it does:** This flag removes the program's symbol table and the Go build ID. 
* **Impact:** The symbol table maps raw machine instructions back to human-readable function names (e.g., `main.handler`). Stripping it makes reverse engineering significantly harder, as functions are reduced to generic memory addresses.

