CC ?= cc
CFLAGS = -Wall -Wextra -Os -DSTANDALONE
TARGET = port-occupier

$(TARGET): port-occupier.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: clean
