PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin

.PHONY: install uninstall

install:
	install -d "$(BINDIR)"
	install -m 755 "$(CURDIR)/nosleep-brightness" "$(BINDIR)/nosleep-brightness"
	ln -sf "$(CURDIR)/nosleep" "$(BINDIR)/nosleep"
	@echo "Installed: $(BINDIR)/nosleep -> $(CURDIR)/nosleep"
	@echo "Installed: $(BINDIR)/nosleep-brightness"

uninstall:
	rm -f "$(BINDIR)/nosleep" "$(BINDIR)/nosleep-brightness"
	@echo "Removed: $(BINDIR)/nosleep $(BINDIR)/nosleep-brightness"
