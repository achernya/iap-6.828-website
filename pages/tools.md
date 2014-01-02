---
title: 'Tools'
position: 5
---
Tools Used in 6.828
===================

If you use the MIT Athena machines that run Linux, then all the software
tools you will need for this course are located in the 6.828 locker:
just type 'add -f 6.828' to get access to them. If you would like to
compile and run the tools on your own machine, however, here is the
information you need. We cannot guarantee that these tools will run on
your computer, but they should run on recent versions of Linux.

It should be possible to get this development environment running under
windows with the help of [Cygwin](http://www.cygwin.com). Install
cygwin, and be sure to install the flex and bison packages (they are
under the development header).

For an overview of useful commands in the tools used in 6.828, see the
[lab tools guide](../labguide).

Compiler Toolchain
------------------

Most modern Linuxes and BSDs have an ELF toolchain compatible with the
6.828 labs. That is, the system-standard `gcc`, `as`, `ld` and `objdump`
should just work. The 6.828 lab makefile should automatically detect
this. However, if your machine is in this camp and the makefile fails to
detect this, you can override it by adding the following line to
`conf/env.mk`:

    GCCPREFIX=

If you are using something other than standard x86 Linux or BSD, you
will need the GNU C compiler toolchain, configured and built as a
cross-compiler for the target 'i386-jos-elf', as well as the GNU
debugger, configured for the i386-jos-elf toolchain. You can download
the specific versions we used via these links, although any recent
versions of gcc, binutils, and GDB should work:

-   [http://ftpmirror.gnu.org/binutils/binutils-2.21.1.tar.bz2](http://ftpmirror.gnu.org/binutils/binutils-2.21.1.tar.bz2)
-   [http://ftpmirror.gnu.org/gcc/gcc-4.5.1/gcc-core-4.5.1.tar.bz2](http://ftpmirror.gnu.org/gcc/gcc-4.5.1/gcc-core-4.5.1.tar.bz2)
-   [http://ftpmirror.gnu.org/gdb/gdb-6.8a.tar.gz](http://ftpmirror.gnu.org/gdb/gdb-6.8a.tar.gz)

Once you've unpacked these archives, run the following commands as root:

```lang-sh
$ cd binutils-2.21.1
$ ./configure --target=i386-jos-elf --disable-nls
$ make
$ make install
$ cd ../gcc-4.5.1
$ ./configure --target=i386-jos-elf --disable-nls --without-headers \
              --with-newlib --disable-threads --disable-shared \
              --disable-libmudflap --disable-libssp
$ make
$ make install
$ cd ../gdb-6.8
$ ./configure --target=i386-jos-elf --program-prefix=i386-jos-elf- \
              --disable-werror
$ make
$ make install
```

Then you'll have in /usr/local/bin a bunch of binaries with names like
i386-jos-elf-gcc. The lab makefile should detect this toolchain and use
it in preference to your machine's default toolchain. If this doesn't
work, there are instructions on how to override the toolchain inside the
GNUmakefile in the labs.

QEMU Emulator
-------------

[QEMU](http://www.nongnu.org/qemu/) is a modern and fast PC emulator.
QEMU version 0.15 is set up on Athena for x86 machines in the 6.828
locker.

Unfortunately, QEMU's debugging facilities, while powerful, are somewhat
immature, so we highly recommend you use our patched version of QEMU
instead of the stock version that may come with your distribution. The
version installed on Athena is already patched. To build your own
patched version of QEMU:

1.  Clone the 6.828 QEMU git repository
     `git clone http://pdos.csail.mit.edu/6.828/qemu.git -b 6.828-0.15`
2.  On Linux, you may need to install the SDL development libraries to
    get a graphical VGA window. On Debian/Ubuntu, this is the
    libsdl1.2-dev package.
3.  Configure the source code\
     Linux:
    `./configure --disable-kvm [--prefix=PFX] [--target-list="i386-softmmu x86_64-softmmu"]`
     OS X:
    `./configure --disable-kvm --disable-sdl [--prefix=PFX] [--target-list="i386-softmmu x86_64-softmmu"]`
     The `prefix` argument specifies where to install QEMU; without it
    QEMU will install to `/usr/local` by default. The `target-list`
    argument simply slims down the architectures QEMU will build support
    for.
4.  Run `make && make install`
