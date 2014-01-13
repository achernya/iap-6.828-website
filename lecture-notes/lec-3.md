# Lecture 3: System calls and interrupts
[Slides](TODO/LINK/TO/THE/MEMES)

## Announcements

- Comments and grades for lab 1 are available on the course
  submissions website.

- We strongly encourage students taking this class as "listener" to
  still work on and hand in the labs. In the full-length 6.828, the
  lectures contain a lot more content, including theory discussion,
  paper readings, and examples from xv6. This IAP version is heavily
  condensed, with lectures primarily containing the minimal
  information needed to be able to write JOS. The majority of the
  learning experience comes from working through the labs.

- Read **all** the comments in a JOS labs. They are there to help
  you. They frequently include hints.

- While grading lab 1, we noticed there was some confusion about
  pointer arithmetic. You can perform arithmetic on pointers without
  casting them to `int` first. The increment value will be the same as
  `sizeof(type)`; i.e., `int* a = 0x4; a++` results in `a = 0x8`.

## The Shell & System Calls

The first exercise, [the shell](../../lab/shell/), serves two
purposes: familiarity with the C programming language, and exposure to
system calls. What system calls does a completed `sh.c` use?

- `brk`
- `close`
- `dup2`
- `execve`
- `fork`
- `ioctl`
- `open`
- `pipe`
- `read`
- `wait`
- `write`

Some of these system calls you used directly (like `dup2` and `pipe`)
but others (like `ioctl`) aren't even in the source code! Library
functions (from `libc`) frequently do work for you that involves
calling into the kernel. The most obvious functions are those that are
thin wrappers around the syscall interface---like `write`. The less
obvious ones, like `fwrite` still end up calling into the thin
wrappers. You can get the man pages for these syscalls by running `man
2 SYSCALL`, like `man 2 write`, on `athena.dialup.mit.edu`.

Before we continue, there's a useful tool that's installed on Athena
called `strace`. As per its man page, it allows you to "trace system
calls and signals". Running `strace PROGRAM` will show you the
syscalls it is calling---live. This makes `strace` an incredibly
useful debugging tool. We're going to use `strace` to identify the
syscalls in some example programs.

`hello.c`:

```lang-c
#include <stdio.h>
int main(int argc, char* argv[]) {
    puts("Hello, world!");
    return 0;
}
```

If we run `gcc hello.c -o hello && strace ./hello`, we'll eventually see the syscall

```lang-html
write(1, "Hello, world!\n", 14)         = 14
```

We can conclude that `puts` is a library function that ends up
calling `write`. That means we could re-write the program to use
`write` directly, and then confirm with `strace`.

`hello-write.c`:

```lang-c
int main(int argc, char* argv[]) {
    const char hello[] = "Hello, world!\n";
    write(1, hello, sizeof(hello) - 1);
    return 0;
}
```

Let's look at a more complicated example:

`run-system.c`:

```lang-c
int main(int argc, char* argv[]) {
    system("ls");
    return 0;
}
```

This program just runs `ls` normally; let's look at the interesting lines from `strace -f`:

```lang-html
clone(child_stack=0, flags=CLONE_PARENT_SETTID|SIGCHLD,
      parent_tidptr=0x7fffe5422818) = 32680
[pid 28702] execve("/bin/sh", ["sh", "-c", "ls"], [/* 60 vars */]) = 0
wait4(32680, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 32680
```

On Linux, `fork` is implemented in terms of the more general `clone`
system call, which is what we see here.

`run-fork.c`:

```lang-c
int main(int argc, char* argv[]) {
    int status;
    if (fork() == 0) {
       const char* args[] = {"sh", "-c", "ls"};
       execv("/bin/sh", args);
    }
    wait(&status);
    return 0;
}
```

Finally, let's look at an example that has to do with files:

`mkstemp-test.c`:

```lang-c
int main(int argc, char* argv[]) {
    char template[] = "/tmp/jos-XXXXXX";
    int fd = mkstemp(template);
    const char msg[] = "6.828 is amazing.\n";
    write(fd, msg, sizeof(msg) - 1);
    close(fd);
    return 0;
}
```

`mkstemp` takes a template string that it modifies, replacing the
string of `XXXXXX` with random ASCII characters. If a file with the
same name already exists, it tries again, until a new file is
created. We can see the `strace` output:

```lang-html
open("/tmp/jos-Fl9E8n", O_RDWR|O_CREAT|O_EXCL, 0600) = 3
write(3, "6.828 is amazing.\n", 18)     = 18
close(3)                                = 0
```

We can translate this into a moral equivalent (without the random name
choice and retry; that's an exercise for the reader):

`mkstemp-alike.c`:

```lang-c
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int main(int argc, char* argv[]) {
    int fd = open("/tmp/jos-Fl9E8n", O_RDWR | O_CREAT | O_EXCL, 0600);
    const char msg[] = "6.828 is amazing.\n";
    write(fd, msg, sizeof(msg) - 1);
    close(fd);
    return 0;
}
```