BUILDDIR ?= .
SRCDIR ?= .

all: $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/WhoUses.exe

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

clean:
	rm $(BUILDDIR)/create-shortcut.exe $(BUILDDIR)/create-shortcut.o
	rm $(BUILDDIR)/WhoUses.exe $(BUILDDIR)/WhoUses.o \
		$(BUILDDIR)/SystemInfo.o
