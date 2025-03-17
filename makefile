#! make -f
#
# makefile - start
#


# directory
#

# source file directory
SRCDIR			=	sources

# include file directory
INCDIR			=	sources

# object file directory
OBJDIR			=	objects

# binary file directory
BINDIR			=	bin

# output file directory
OUTDIR			=	disk

# output file directory
RESDIR			=	resources

# tool directory
TOOLDIR			=	tools

# vpath search directories
VPATH			=	$(SRCDIR):$(INCDIR):$(OBJDIR):$(BINDIR)

# assembler
#

# assembler command
AS				=	z88dk-z80asm

# assembler flags
ASFLAGS			=	-mz80 -I$(SRCDIR) -I$(INCDIR) -I.

# c compiler
#

# c compiler command
CC				=	zcc

# c compiler flags
CFLAGS			=	+x1 -mz80 -lm -I$(SRCDIR) -I$(INCDIR) -I.

# linker
#

# linker command
# LD			=	zcc
LD				=	z88dk-z80asm

# linker flags
# LDFLAGS		=	+x1
LDFLAGS			=	-b -mz80 -split-bin

# suffix rules
#
.SUFFIXES:			.asm .c .o

# assembler source suffix
.asm.o:
	$(AS) $(ASFLAGS) -o=$(OBJDIR)/$@ $<

# c source suffix
.c.o:
	$(CC) $(CFLAGS) -o $(OBJDIR)/$@ -c $<

# project files
#

# target name
TARGET			=	templete
TARGET_ID		=	temp

# assembler source files
ASSRCS			=	crt0.asm xcs.asm \
					app.asm

# c source files
CSRCS			=	

# object files
OBJS			=	$(ASSRCS:.asm=.o) $(CSRCS:.c=.o)

# resource files
RESS			=	$(RESDIR)/images/image.gvr \
					$(RESDIR)/pcgs/bg.pcg \
					$(RESDIR)/tilesets/sprite.ts \
					$(RESDIR)/sounds/song.snd

# build project disk
#
$(TARGET).d88:		$(OBJS)
	$(LD) $(LDFLAGS) -o=$(BINDIR)/$(TARGET_ID).bin -m $(foreach file,$(OBJS),$(OBJDIR)/$(file))
	@mv $(BINDIR)/$(TARGET_ID)_boot.bin $(BINDIR)/$(TARGET_ID)_boot.Sys
	$(TOOLDIR)/hu2d -d88 -o $(OUTDIR)/$(TARGET).d88 $(BINDIR)/$(TARGET_ID)_boot.Sys $(BINDIR)/$(TARGET_ID)_app.bin $(RESS)
	$(TOOLDIR)/hu2d -2d  -o $(OUTDIR)/$(TARGET).2d  $(BINDIR)/$(TARGET_ID)_boot.Sys $(BINDIR)/$(TARGET_ID)_app.bin $(RESS)

# clean project
#
clean:
	@rm -f $(OBJDIR)/*
	@rm -f $(BINDIR)/*
##	@rm -f makefile.depend

# build depend file
#
##	depend:
##	ifneq ($(strip $(CSRCS)),)
##		$(CC) $(CFLAGS) -MM $(foreach file,$(CSRCS),$(SRCDIR)/$(file)) > makefile.depend
##	endif

# build tools
#
tool:
	@g++ -o $(TOOLDIR)/hu2d $(TOOLDIR)/hu2d.cpp
	@g++ -o $(TOOLDIR)/fmstxt $(TOOLDIR)/fmstxt.cpp

# phony targets
#
##	.PHONY:				clean depend
.PHONY:				clean

# include depend file
#
-include makefile.depend


# makefile - end
