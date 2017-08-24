BUILDDIR ?= .
SRCDIR ?= .

all: $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/WhoUses.exe \
	$(BUILDDIR)/blocked-file-util.exe $(BUILDDIR)/proxy-lookup.exe

$(BUILDDIR)/create-shortcut.exe: $(BUILDDIR)/create-shortcut.o
	$(CC) $(CFLAGS) -o $@ $^ -luuid -lole32

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	$(CC) -c $(CFLAGS) $< -o $@

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

clean:
	rm $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/create-shortcut.o
	rm $(BUILDDIR)/WhoUses.exe $(BUILDDIR)/WhoUses.o \
		$(BUILDDIR)/SystemInfo.o
	rm $(BUILDDIR)/blocked-file-util.exe $(BUILDDIR)/blocked-file-util.o
	rm $(BUILDDIR)/proxy-lookup.exe $(BUILDDIR)/proxy-lookup.o
