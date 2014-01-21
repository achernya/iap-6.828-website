# Lecture 5: Multiprocessing

## Announcements

- Lab 4 has been released.

- We are still grading Lab 2.

## Concurrency

So far, we've worked in a single-process environment in JOS. However,
a full operating system is generally considered to be able to run
multiple processes at a time. This is called
*multitasking*. Specifically, we take advantage of this feature to
allow a single program to perform tasks simultaneously. To better
understand how this works, we need to first understand some
terminology.

* **Process**: A logical program. Also called a "thread group", a
    process consists of one of more threads.
* **Thread**: An exection unit in the program. Each thread has its own
    stack, but shares a heap with all other threads.

There are two types of threads: preemptable, also called "OS native",
threads; and green threads, sometimes called greenlets or fibers. Both
of these threads still have independent stacks, and share a heap with
the other threads in the process, but the mechanism by which they are
scheduled is very different.  Green threads have low overhead---only
the stack has to be preserved---and the context switches are handled
entirely in userspace without the kernel's intervention.
Unfortunately, it means that the kernel has no knowledge of the green
threads, and can't do any preemption. A context switch occurs if and
only if the threads *yield*, willingly give up control, to another
thread. This brings us to yet another name for green threads:
cooperative threading.

Preemptable threads are scheduled by the kernel, and have all of the
data structures associated with a full environment.  This has all of
the overhead of a full kernel-level environment structure, but affords
the benefit that the kernel can forcibly re-schedule the thread should
it stall, e.g., in a blocking syscall. There are two ways to implement
this type of threading, both of which are available to us in JOS if we
wanted to do so: we could leverage the fact that the exokernel
structure exposes the page tables and just create multiple processes
with the same physical pages, or we could modify the kernel to
explicitly support thread groups.

### Implementing Threading

To demonstrate threading, we've implemented a threading library for
linux that we'd like to go through. This library leverages Linux
syscalls `getcontext`, `makecontext`, and `setcontext` to save the
registers of the currently running thread and switch between
them. We've designed this API to mimic JOS as much as possible: we
have the fairly familiar functions `env_create`, `env_yield`, and the
userspace entry point is `umain`.

Unlike JOS, these are not system calls, but rather library calls
implemented by our library. All of the context switching is *entirely*
userspace. (Not entirely true: the `setcontext` call may perform
implementation-defined syscalls to deal with signals, which are an
unfortunate fact of life in UNIX.)

Let's start with the `yield.c` file. This program is a direct port,
almost verbatim, of the JOS `yield` program. Running `./yield` results in

```lang-html
Hello, I am environment 00000001.
Hello, I am environment 00000002.
Hello, I am environment 00000003.
Back in environment 00000001, iteration 0.
Back in environment 00000002, iteration 0.
Back in environment 00000003, iteration 0.
Back in environment 00000001, iteration 1.
Back in environment 00000002, iteration 1.
Back in environment 00000003, iteration 1.
Back in environment 00000001, iteration 2.
Back in environment 00000002, iteration 2.
Back in environment 00000003, iteration 2.
Back in environment 00000001, iteration 3.
Back in environment 00000002, iteration 3.
Back in environment 00000003, iteration 3.
Back in environment 00000001, iteration 4.
All done in environment 00000001.
Back in environment 00000002, iteration 4.
All done in environment 00000002.
Back in environment 00000003, iteration 4.
All done in environment 00000003.
```

We can see that there are three logical environments, each of which is
given an opportunity to run. The context switches happen at entirely
predictable locations: every call to `env_yield`.

`env_yield` is responsible for saving the state of the calling
environment and then running the scheduler. We've implemented a simple
round-robin scheduler similar to the one you'll be writing for Lab
4. The semantics of the scheduler are that it will try to find the
next `ENV_RUNNABLE` process beyond the current one, falling back to
the current one if there are none left. If even the current process is
not `ENV_RUNNABLE`, then the scheduler will terminate the program.

We also implement `env_exit`, which can be called to terminate a the
thread early. `env_destroy` lets any environment kill any other
environment.  Note that killing the current environment will result in
a deadlock; use `env_exit` instead. There's an `env_getid` that will
return the current environment's ID. `env_create` will create a new
environment that is ready for scheduling, given a function pointer
entry point, returning the environment ID to the caller. However,
since the environments are cooperative, the newly created environment
will not have an opportunity to run until a `env_yield` is
invoked. Even then, it may not run until all other environments
ordered before it have had an opportunity to run and call `env_yield`.

A priority-scheduler is still useful in the case of cooperative
threading, although it cannot provide the same guarantees as a
preemptive priority-scheduler would. That is, an environment can still
take a disproportionate amount of CPU time despite being low-priority.

### Threads on Linux 

On Linux, the OS native threading library is called `NPTL`, the Native
POSIX Threading Library. `NPTL` takes the latter approach, and
leverages explicit support in the Linux kernel to create
threads. `NPTL` replaced the older `LinuxThreads` library that took
the former approach, setting up processes and relying on the kernel
being blind to the fact that they shared heap space.

`NPTL` provides the `pthreads` API; see `man pthreads(7)` for mroe
information. You can check which version of `pthreads` your system is
using by running

```lang-sh
$ getconf GNU_LIBPTHREAD_VERSION
NPTL 2.13
```

## Locking

### Spin locks

Spin locks are the simplest locks. We define the lock to be an
integer: `0` is unlocked, `1` is locked. Each processor will attempt
to atomically exchange the contents of the lock variable with a `1` to
get the lock. The exchange "succeeds" if the exchange operation
results in a `1`.

In assembly, this roughly looks like (where `EBX` is holding the
lock's address)

```lang-asm
movl $0x1,%eax
lock xchgl %eax,(%ebx)
test %eax,%eax                  ; fancy way of saying "is EAX zero"
jne TRY_AGAIN
jmp GOT_THE_LOCK
```

The trickry bit is the `test` instruction, which is really just a
fancy way to check for if `EAX` is zero, setting the appropriate bits
in `EFLAGS` that will then let us `jne` (jump not equal) to try again,
or fall through to `jmp` to continue running our code.

Spin locks have the benefit of being the lowest-latency locks. Since
the CPU is always trying to acquire the lock, it will notice
as-soon-as-possible that it succeeds in acquring the
lock. Unfortunately, it will consume all of the CPU, and performs
poorly on mobile devices.

### Ticket-based spin locks

Naive spin locks rely on the inherent race between processors to get
the lock. This means that spin locks are unfair, and can result in
starvation. We can improve upon the design of the spin lock by making
there be two integers: a queue and a dequeue. Upon trying to take the
lock, a thread reads-and-increments the queue. It then atomically
compares its ticket with the dequeue value. Once they match, it holds
the lock. It is then that thread's responsibility to increment the
dequeue when it is done.

### Semaphores

Semaphores rely on a counter. Every time a process wishes to acquire
the semaphore, it calls `wait()`, which decrements the counter. If
this operation causes the counter to become negative, the process is
blocked and execution yields. When the semaphore is released,
`signal()` increments the counter, and unblocks a waiting process. To
avoid starvation, the counter is usually paired with a FIFO queue of
the blocked processes.

### Mutex

A mutex (short for "mutual exclusion") is a binary semaphore with the
added concept of an owner. This provides the additional guarantee that
a process cannot be killed while still holding a lock.

## Priority Inversion

Suppose you have two processes, *P* running at priority 12 that is
producing data, and *C* running at priority 4, consuming the
data. These two processes use a lock to synchronize editing the data
queue. Now, suppose we introduce some process *M* running at priority
8. Now, *M* gets scheduler twice as often as *C*. However, since *C*
and *P* share a finite queue, *P* eventually gets blocked because it
has nowhere to put the data. This causes *P* to starve.

Mutexes can guard against this because the notion of ownership allows
for a process to be temporarily promoted in priority to relinquish the
lock so that the higher-priority process can perform work.

## Bringing up multiple CPUs

One of the new features Lab 4 introduces to JOS is the ability to use
more than one processor. All of that talk about locking finally sound
useful? The x86 standard for bringing up multiple CPUs is actually
really touchy, and doing it wrong results in the CPU not coming up. In
fact, the Lab 4 JOS will not boot on real hardware, but will work fine
in QEMU. If you're interested in getting your JOS to work on real
hardware, talk to us at the end of the course---we just spent the
better part of the weekend making sure this is possible.

The CPUs on the system are divided into two categories---the BSP, boot
processor, and the APs, application processors. The BSP is the only
processor running JOS until you bring up the APs. However, since the
processors are halted, we can't just ask them to start. Fortunately,
each processor has a LAPIC (local advanced programmable interrupt
controller) that we *can* talk to. There's a "universal startup
algorithm" that goes as follows:

1. Find the neighbor's APIC ID
2. Send a INIT message from your APIC to the target APIC
3. Wait 10 milliseconds
4. Send a STARTUP message
5. Wait 200 microseconds
6. Send another STARTUP message
7. Wait 200 microseconds, again.

The LAPIC is the first use of memory-mapped IO in JOS. You'll have
your code in `pmap.c` to support the MMIO region. The address of the
APIC is determined by reading the BIOS configuration area as specified
by the Multiprocessing 1.4 standard (MP1.4). Make sure that you mark
this page as reserved.

## New system calls

One of the new system calls you'll get to implement is `sys_exofork`,
which creates a new environment with the same trap frame as the
currently running environment, except that the return value of the
syscall will be 0. This is useful for implementing `fork`, which is
part of the lab. There's a subtlety here in that userspace
`sys_exofork` **must** be inline, unlike other syscalls. This is
mostly out of convenient to you to implement fork---if we had used the
not-inlined version that routed via `syscall`, there would be
additional stack frames present which are unwanted for where we want
the child's `ESP` to be. With it being inline, those new stack frames
are never created.
