BUILDDIR ?= .
SRCDIR ?= .
WINDRES ?= windres
CFLAGS ?= -Wall
CXXFLAGS ?= -Wall
LDFLAGS = -Wl,--tsaware

all: $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/WhoUses.exe \
	$(BUILDDIR)/blocked-file-util.exe $(BUILDDIR)/proxy-lookup.exe \
	$(BUILDDIR)/git-askyesno.exe \
	$(BUILDDIR)/git-askpass.exe \
	$(BUILDDIR)/git-credential-helper-selector.exe

$(BUILDDIR)/create-shortcut.exe: $(BUILDDIR)/create-shortcut.o
	$(CC) $(CFLAGS) -o $@ $(LDFLAGS) $^ -luuid -lole32

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	$(CC) -c $(CFLAGS) $< -o $@

$(BUILDDIR)/%.res: $(SRCDIR)/%.rc
	$(WINDRES) --input $< --output $@ --output-format coff

$(BUILDDIR)/WhoUses.exe: $(BUILDDIR)/WhoUses.o $(BUILDDIR)/SystemInfo.o
	$(CXX) $(CXXFLAGS) -o $@ $(LDFLAGS) $^ -lmsvcrt-os

$(BUILDDIR)/WhoUses.o: $(SRCDIR)/WhoUses.cpp $(SRCDIR)/SystemInfo.h
$(BUILDDIR)/SystemInfo.o: $(SRCDIR)/SystemInfo.cpp $(SRCDIR)/SystemInfo.h

$(BUILDDIR)/%.o: $(SRCDIR)/%.cpp
	$(CXX) -c $(CXXFLAGS) $< -o $@

$(BUILDDIR)/blocked-file-util.exe: $(BUILDDIR)/blocked-file-util.o
	$(CC) $(CFLAGS) -o $@ $(LDFLAGS) $^

$(BUILDDIR)/proxy-lookup.o: CFLAGS += -DUNICODE

$(BUILDDIR)/proxy-lookup.exe: $(BUILDDIR)/proxy-lookup.o
	$(CC) -municode $(CFLAGS) -o $@ $(LDFLAGS) $^ -lshell32 -lwinhttp

$(BUILDDIR)/git-askyesno.o: CFLAGS += -DUNICODE

$(BUILDDIR)/git-askyesno.exe: $(BUILDDIR)/git-askyesno.o
	$(CC) -municode $(CFLAGS) -o $@ $(LDFLAGS) $^

$(BUILDDIR)/git-credential-helper-selector.o: CFLAGS += -DUNICODE

$(BUILDDIR)/git-credential-helper-selector.exe: \
	$(BUILDDIR)/git-credential-helper-selector.o \
	$(BUILDDIR)/git-credential-helper-selector.res
	$(CC) -municode $(CFLAGS) -o $@ $(LDFLAGS) $^ -lgdi32 -lcomctl32

$(BUILDDIR)/git-askpass.o: CFLAGS += -DUNICODE

$(BUILDDIR)/git-askpass.exe: \
	$(BUILDDIR)/git-askpass.o \
	$(BUILDDIR)/git-askpass.res
	$(CC) -municode $(CFLAGS) -o $@ $(LDFLAGS) $^
clean:
	$(RM) $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/create-shortcut.o
	$(RM) $(BUILDDIR)/WhoUses.exe $(BUILDDIR)/WhoUses.o \
		$(BUILDDIR)/SystemInfo.o
	$(RM) $(BUILDDIR)/blocked-file-util.exe $(BUILDDIR)/blocked-file-util.o
	$(RM) $(BUILDDIR)/proxy-lookup.exe $(BUILDDIR)/proxy-lookup.o
	$(RM) $(BUILDDIR)/git-credential-helper-selector.exe \
		$(BUILDDIR)/git-credential-helper-selector.o
