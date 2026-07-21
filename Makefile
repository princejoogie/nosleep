PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin

.PHONY: install uninstall

install:
	install -d "$(BINDIR)"
	ln -sf "$(CURDIR)/nosleep" "$(BINDIR)/nosleep"
	@echo "Installed: $(BINDIR)/nosleep -> $(CURDIR)/nosleep"

uninstall:
	rm -f "$(BINDIR)/nosleep"
	@echo "Removed: $(BINDIR)/nosleep"
