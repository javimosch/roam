# roam — build targets. Requires the `machin` compiler (github.com/javimosch/machin).
VERSION ?= 0.1.0

.PHONY: build release clean

# Dynamic build (links libsqlite3 + OpenSSL from the host).
build:
	machin encode roam.src > roam.mfl
	machin build roam.mfl -o roam

# Fully-static release binary: bundles the SQLite amalgamation, statically links
# OpenSSL, and embeds a CA root store — runs FROM scratch on any x86-64 Linux with
# no libsqlite3 / libssl / libc needed. This is the artifact attached to releases.
release:
	machin encode roam.src > roam.mfl
	machin build --static roam.mfl -o roam-x86_64-linux
	sha256sum roam-x86_64-linux > roam-x86_64-linux.sha256
	@echo "built roam-x86_64-linux ($$(du -h roam-x86_64-linux | cut -f1), static)"

clean:
	rm -f roam roam.mfl roam-x86_64-linux roam-x86_64-linux.sha256
