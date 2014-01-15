# Lecture 3: System calls and interrupts
[Slides](../../slides/lec-3.html)

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

If we run `gcc hello.c -o hello && strace ./hello`, we'll eventually
see the syscall

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

`puts` has to be translated into `write` because the userspace program
has no way to directly output data onto the screen. The kernel is
responsible for accepting all requests to use the hardware and
determine if they are acceptable before enacting them. Otherwise, each
program could attempt to perform direct operations on each IO
device. If there's only one program running, but in a multitasking
environment, this is going to cause complete mayhem. So we use the
kernel as an arbiter, and the syscalls are our way of communicating to
it our intentions.

Let's look at a more complicated example, in which we want to run
another program:

`run-system.c`:

```lang-c
int main(int argc, char* argv[]) {
    system("ls");
    return 0;
}
```

This program just runs `ls` normally; let's look at the interesting
lines from `strace -f`, which will tell `strace` to "follow forks":

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
       const char* args[] = {"sh", "-c", "ls", 0};
       execv("/bin/sh", args);
    }
    wait(&status);
    return 0;
}
```

Finally, let's look at an example that has to do with files. It's
pretty normal to want a temporary file whose name you don't care
about, so long as it's unique. The C standard library provides
`mkstemp`:

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

Each of these examples allowed a userspace program to perform a
privileged operation: write to the screen, run another program, create
and write to a file; all mediated by the kernel, preventing them from
crashing each other. In all cases, the only interface these programs
used to communicate with the kernel was the syscall. Now, all we have
to do is actually implement them.

## User environments

So far (up to and including `lab2`), all of the code in JOS has been
entirely in kernel space. Any function in any file could directly
modify any piece of hardware, as everything is running in ring 0. The
goal of `lab3` is two parts: setting up unprivileged user environments
(also called processes) and handling exceptions, and then using this
infrastructure to handle system calls.

The initial part of `lab3` is fairly similar to `lab2` in that you
have to implement some utility functions for managing in-kernel
tracking data structures. These time it will be `struct Env` rather
than `struct PageInfo`. After that, you'll be setting up the interrupt
handlers to perform a userspace to kernelspace transition, and perform
the appropriate action.

## Entering the Kernel

When an exception or an interrupt occurs, the processor looks up what
code to run in the *Interrupt Descriptor Table* (IDT). There are 256
entries, including values for page fault, general protection fault,
and double fault. We'll also use the IDT for enabling a syscall. JOS
uses `int $0x30`---Linux uses `int $0x80`.

`inc/mmu.h` defines the macro `SETGATE` for conveniently setting all
the fields in the IDT, which are then loaded into the CPU with
`lidt`. Each entry of the IDT contains many fields, but the ones we're
interested in are the selector and the privilege level. We'll be
setting the selector to `GD_KT` so that the interrupt runs in the
kernel's context. For syscalls, we'll want to set the privilege level
to ring 3 to allow user programs to invoke the interrupt. For all of
the exceptions, we want to set the privlege level to ring 0 so that
only the kernel or the processor itself can cause them.

Unfortunately, the IDT is not sufficient for describing everything
that to do on an interrupt. The processor needs to know which stack to
push data onto. To supply this, we have to turn to an x86 feature
called the Task State Segment (TSS). The TSS exists to enable hardware
multitasking---a feature we will otherwise not be using.

The GDT has a pointer to the TSS which we will fill in with exactly
two values: the kernel's stack and privilege level. JOS uses a single
kernel stack per CPU, so all interrupts (including syscalls) will be
processed there.

Once we've switched to the kernel's stack, the function provided in
the IDT will be run. This function will be defined in `trapentry.S`,
some specialized assembly that's part of Lab 3 that will save the
necessary information to restore back to userspace. This means
preserving all registers so that when the transition occurs execution
of the userspace program continues unimpeded. This data structure is
defined in `inc/trap.h` and is called `struct Trapframe`.

## Performing syscalls

Now that an interrupt has landed execution in the kernel, we need to
process the trap frame. We can't store arguments on the stack, so we
need a special calling convention for syscalls. We'll use `EAX` to
store the syscall number, and then `EDX`, `ECX`, `EBX`, `EDI`, `ESI`
(in that order) to hold the maximum of 5 arguments. We'll use `EAX` to
return values back into userspace, which we can do by just modifying
the value in our trap frame.

These 5 arguments seem like they're very limiting---they are. However,
since the kernel and the userspace share the same virtual memory
space, the arguments can be pointers to data in userspace. The kernel
has full privileges to read and edit this data, a feature we will take
advantage of in future labs. As an added benefit, we don't incur a TLB
flush every time we perform a syscall, so calling into the kernel is
fairly cheap, but still more expensive than a userspace function call.

## Heading back to Userspace

One the kernel is done processing the interrupt, heading back to
userspace is easy. The function `env_pop_tf` will restore the
userspace program by placing the contents in the trap frame back into
the appropriate registers, which will automatically resume exection at
the correct privilege level.

This same functionality will be used in Lab 4 for switching between
running processes.

## Some hints on Lab 3

- The macros `ROUNDUP` and `ROUNDDOWN` are very useful.

- You'll have to write code that can load ELF files. You may find the
  code in `boot/main.c` useful, as well as `inc/elf.h`.

- If you get a strange error when trying to run your first userspace
  environment, make sure your `env_init` sets up your environments
  such that the first `env_alloc` call uses `envs[0]`, as that's what
  the test code expects.
