# Lecture 1b: PC Hardware and x86
[Slides](../../slides/lec-1b.html)

## What is a computer?

We use computers every day, and expect them to function? But what
makes a computer? Is it the form factor? Or perhaps the functions they
can perform? Let's go through some different electronic devices and
figure out what's the same and different, and decide whether they are
computers. First off, we have a laptop. This one happens to be a
retina Macbook Pro. It has an Intel Core i7 processor, a screen,
keyboard, mouse, 16GB RAM, and an SSD.

But then we have this desktop from IBM. It has a classic IBM Model M
keyboard, a CRT monitor, and two 5.25" floppy drives. (You know,
actual floppy-floppies). This is about as far as you can get from the
Apple laptop; is this a computer? Finally, we have a Dell R720XD
server. It has 16 2.5" SAS hard drives, and two Intel Xeon processors,
and something on the order of 128GB of RAM. It has no screen.

What do all of these electronic devices have in common? Well, it's the
Intel x86 platform. They're all definitely computers, because they
have a general-purpose programmable CPU. But they're quite different,
and we expect our programs to still work correctly on them.  We have
to make all of this useful, which is the primary job of the operating
systems.

## Computer Architecture

In order to write an operating system, we first have to understand the
computer architecture. How many people here have taken 6.004? Can
anyone tell me what are the basic properties of a computer? It has a
logic unit, memory, and can perform input/output. We now have two
choices: we can either mark programs as "special", and separate them
from data, or we can decide that programs are just data. The Von
Neumann architecture goes the second route---programs are just data.
The nice thing about this is that you can actually think of the
processor as just an interpretter for a specific type of data, the
assembly program.

This assembly program is written in the processors particular
language, which we call an instruction set. The x86 instruction set
architecture ("ISA") has 6 general purpose, a base pointer, and a
stack pointer. These should be familiar from 6.004. Notice has this is
a lot fewer registers than the Beta you built. Like the Beta, the
registers are all 32 bits wide. AMD extended x86 to be 64 bit in 2003,
and all computers you buy these days are 64-bit, but still run most
often in 32-bit mode. The JOS you will be writing in lab will be
32-bit.

There's a special register called EIP that is the instruction pointer,
which is the address in memory that the processor is currently
executing. Unlike the Beta, it doesn't increment by +4, because x86
instructions are of variable length. This make x86 much more complex,
but EIP will always be incremented by the right amount. There are some
instructions that directly modify EIP: CALL, which you use to call a
function; RET, which you use to return from one, and JMP, which lets
you go to a specific address. JMP also comes in conditional
flavors--that's how you can make conditional statements and loops.

As Geoff said earlier today, x86 has to be compatible with all of the
nearly 30 years of its history. That means that the processor in your
laptop today has to start running in 16-bit mode, and support all of
the 16-bit instruction. But since the x86 was designed to be
compatible with the 8-bit processors that predated it, there are also
names for the 8-bit registers. The first general-purpose register is
EAX---extended AX. AX consists of "A high" (AH) and "A low" (AL),
which as you can see in this diagram refer to the upper 8 and lower 8
bits, respectively.

Similarly, there are 8-bit and 16-bit names for EBC through EDX. EBP,
ESI, EDI, and ESP only have a 16-bit register in them.

There's a special register called EFLAGS --- extended FLAGS. Various
instructions change the single-bit fields in EFLAGS depending on what
happened. For example, if you do an addition that overflows, you'll
get a 1 bit in the overflow flag. 

Now, let's go over some of the instructions in x86. We'll first start
with instructions that let you move data around. This is called the
MOV instruction. Just a note---in x86 instructions are always in
"families", an operation coupled with a suffix that indicates the size
of the data that's being operated on. In this case, the suffix is "l",
for long. Be careful with these suffixes, they're not exactly what you
expect if you've worked with 64-bit C or C++ before. b is for "byte",
8-bits. w is "word", 16-bit. l is for "long", 32 bit, and q is for
"quadword", 64-bit.

Let's go through these examples. First, you can use MOV to move data
between registers. You can also encode an constant value (called an
"immediate"), and set the register to that. You could also load from a
specific memory address, dereference a register, or even add an
offset before dereferencing. These all load from RAM into registers.

Next up, we have some instructions that modify the stack. The stack is
a region of RAM that is treated specially to help with building
programs. It works like a traditional stack data structure, but you
have to know exactly how much data you are pushing and popping down to
the number of bytes. The four instructions that implicitly modify the
stack as push, pop, call, and ret. The code on the right is an
equivalent translation for demonstration purposes.

Accessing memory is difficult on x86, sometimes; there's an additional
detail of x86 called segmentation registers. Back in the original
16-bit design, Intel wanted to use a 20-bit data bus. So they added
these 4-bit registers to "select" which chunk of memory is currently
active. We'll not be using them in JOS, but you do need to be aware
that they exist. Thankfully, they're disabled in 64-bit x86.

16-bit mode, also called "real mode", is what your processor starts
in. The JOS bootloader switches to 32-bit mode, called "protected
mode". 64-bit mode is called "long mode". 32-bit mode requires/enabled
Virtual Memory, which will be the topic of Thursday's lecture.

Now that we've talked about the CPU itself and a bit about memory,
let's talk about IO.  There are two ways to do IO on x86. The first is
to use the IN and OUT instructions, which you use when talking to
e.g., the printer. The code on the screen is for writing to the
parallel port to talk to a printer.

The other wawy of doing IO is called "memory mapped IO". A device is
accessible as if it were RAM, but reading/writing there causes the
device to do something---like draw on the screen.

This diagram described how physical memory is laid out on x86. You'll
become extremely familiar with it as you write JOS, it's included in
the memory header.

## Programming for x86

Calling conventions were mentioned briefly by Geoff. We're going to
use the following calling convention: first, all of the arguments will
be pushed in reverse order (so they can be popped off in-order). The
CALL instruction will save EIP onto the stack. Every function is going
to have a prologue and epilogue that will save the base pointer and
then move the current stack pointer into the base pointer. These base
pointers, while not strictly necessary, form a chain, and can be used
to make a stack trace. This is great for debugging, and is part of lab 1.

Part of this convention is which registers are used. EAX will hold
return values; ECX and EDX may be destroyed. The caller is responsible
for saving them if needed. EBP, EBX, ESI and EDI are all saved by the
callee.

The compiler knows about this calling convention. The way that your C
program is converted to binary is that gcc will produce assembly; gas
will produce an object; and ld will then combine objects into a single
binary. This single binary is then loaded by the kernel and started.

## Developing Operating Systems

Once again, we're going to be using QEMU to develop JOS. You can think
of QEMU as a virtual computer, emulating the various devices such as
the CPU, RAM, keyboard, mouse, etc. It runs on linux, and unlike real
hardware, will let you attach a debugger.

You can think of the registers as an array of integers. The same is
true of the physical memory. In this example we use the "char" type
because you're allowed to access any byte of memory in x86 without
worrying about alignment.

You can think of the CPU as an infinite loop that fetches an
instruction, decodes it, and then does the right bit of logic, finally
incrementing the instruction pointer.

Other devices are done similarly; files for disks, drawing onto the
screen, and passing through the keyboard.
