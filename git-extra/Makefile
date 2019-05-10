BUILDDIR ?= .
SRCDIR ?= .
WINDRES ?= windres
CFLAGS ?= -Wall
CXXFLAGS ?= -Wall

all: $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/WhoUses.exe \
	$(BUILDDIR)/blocked-file-util.exe $(BUILDDIR)/proxy-lookup.exe \
	$(BUILDDIR)/git-askyesno.exe \
	$(BUILDDIR)/git-credential-helper-selector.exe

$(BUILDDIR)/create-shortcut.exe: $(BUILDDIR)/create-shortcut.o
	$(CC) $(CFLAGS) -o $@ $^ -luuid -lole32

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	$(CC) -c $(CFLAGS) $< -o $@

$(BUILDDIR)/%.res: $(SRCDIR)/%.rc
	$(WINDRES) --input $< --output $@ --output-format coff

$(BUILDDIR)/WhoUses.exe: $(BUILDDIR)/WhoUses.o $(BUILDDIR)/SystemInfo.o
	$(CXX) $(CXXFLAGS) -o $@ $^

$(BUILDDIR)/WhoUses.o: $(SRCDIR)/WhoUses.cpp $(SRCDIR)/SystemInfo.h
$(BUILDDIR)/SystemInfo.o: $(SRCDIR)/SystemInfo.cpp $(SRCDIR)/SystemInfo.h

$(BUILDDIR)/%.o: $(SRCDIR)/%.cpp
	$(CXX) -c $(CXXFLAGS) $< -o $@

$(BUILDDIR)/blocked-file-util.exe: $(BUILDDIR)/blocked-file-util.o
	$(CC) $(CFLAGS) -o $@ $^

$(BUILDDIR)/proxy-lookup.exe: $(BUILDDIR)/proxy-lookup.o
	$(CC) $(CFLAGS) -o $@ $^ -lshell32 -lwinhttp

$(BUILDDIR)/git-askyesno.o: CFLAGS += -DUNICODE

$(BUILDDIR)/git-askyesno.exe: $(BUILDDIR)/git-askyesno.o
	$(CC) -municode $(CFLAGS) -o $@ $^

$(BUILDDIR)/git-credential-helper-selector.o: CFLAGS += -DUNICODE

$(BUILDDIR)/git-credential-helper-selector.exe: \
	$(BUILDDIR)/git-credential-helper-selector.o \
	$(BUILDDIR)/git-credential-helper-selector.res
	$(CC) -municode $(CFLAGS) -o $@ $^ -lgdi32 -lcomctl32
clean:
	$(RM) $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/create-shortcut.o
	$(RM) $(BUILDDIR)/WhoUses.exe $(BUILDDIR)/WhoUses.o \
		$(BUILDDIR)/SystemInfo.o
	$(RM) $(BUILDDIR)/blocked-file-util.exe $(BUILDDIR)/blocked-file-util.o
	$(RM) $(BUILDDIR)/proxy-lookup.exe $(BUILDDIR)/proxy-lookup.o
	$(RM) $(BUILDDIR)/git-credential-helper-selector.exe \
		$(BUILDDIR)/git-credential-helper-selector.o
