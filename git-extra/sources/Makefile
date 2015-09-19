BUILDDIR ?= .
SRCDIR ?= .

all: $(BUILDDIR)/create-shortcut.exe

$(BUILDDIR)/create-shortcut.exe: $(BUILDDIR)/create-shortcut.o
	$(CC) $(CFLAGS) -o $@ $^ -luuid -lole32

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/create-shortcut.o
