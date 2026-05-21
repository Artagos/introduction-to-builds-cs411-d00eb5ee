# 1. Reflection — introduction-to-builds
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


# 2. Reflection — introduction-to-builds

## What did I do?

I started by writing the provided source code into `main.go` inside `~/app`.
Before I could do anything with it, I hit my first snag: I tried to run the
file directly and got a "command not found" style error because Go wasn't
installed on the machine yet. Once I installed it, the rest of the loop was
straightforward. I ran `go build -o main main.go` inside `~/app`, which
produced a single executable binary with no extra files alongside it. I then
started the server with `./main`, saw "Server started on port 4444" printed
to the terminal, and confirmed it was working by running `curl localhost:4444`
from a second terminal tab. The response came back as a JSON object with
`Name`, `Description`, and `Url` fields, exactly as the handler defined.
I also did the strip stretch task, rebuilding with
`go build -ldflags='-s -w' -o main-stripped main.go` to produce a smaller
binary for comparison.

## What was most surprising?

The most surprising part was discovering how much of the compiled binary is
taken up by metadata that has nothing to do with actually running the program.
Running `du -b ./main ./main-stripped` after building with `-ldflags='-s -w'`
made the size difference concrete and visible. I hadn't thought about the fact
that by default Go embeds symbol tables and DWARF debugging information into
the binary — data that is only useful if you're attaching a debugger or
reading a stack trace. Stripping it out with those flags produces a smaller
artifact that behaves identically at runtime. It reframes what a "compiled
binary" actually is: not just machine code, but machine code plus a layer of
observability tooling baked in by default, which you can consciously trade
away when you don't need it.

## What's still unclear?

What I don't fully understand yet is what DWARF debugging information actually
contains and how a debugger consumes it at a technical level. I know that
stripping it reduces binary size and that it's used for debugging, but I'm
unclear on what the format looks like internally — whether it maps machine
instructions back to source lines, stores variable names and types, or
something else entirely. I also don't know at what point in the build pipeline
it gets generated, or whether there are cases where keeping it in a production
binary would be a deliberate choice rather than an oversight. This feels
important to understand properly before I start building CI/CD pipelines where
binary size and observability are both concerns.