CC ?= cc
CFLAGS = -Wall -Wextra -Os -DSTANDALONE
TARGET = port-protector

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
LOGDIR = $(PREFIX)/var/log
PLIST_NAME = com.local.port-protector.plist
PLIST_DIR = /Library/LaunchDaemons

$(TARGET): port-protector.c
	$(CC) $(CFLAGS) -o $@ $<

install: $(TARGET)
	install -d $(BINDIR)
	install -m 755 $(TARGET) $(BINDIR)/$(TARGET)
	install -d $(LOGDIR)
	install -m 644 $(PLIST_NAME) $(PLIST_DIR)/$(PLIST_NAME)
	launchctl bootstrap system $(PLIST_DIR)/$(PLIST_NAME)

uninstall:
	launchctl bootout system/$(PLIST_NAME:.plist=) || true
	rm -f $(PLIST_DIR)/$(PLIST_NAME)
	rm -f $(BINDIR)/$(TARGET)
	rm -f $(LOGDIR)/port-protector.log

clean:
	rm -f $(TARGET)

.PHONY: clean install uninstall
