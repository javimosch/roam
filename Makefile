# roam — build targets. Requires the `machin` compiler (github.com/javimosch/machin).
VERSION ?= 0.4.0

.PHONY: build release clean version-check

# Dynamic build (links libsqlite3 + OpenSSL from the host).
build:
	machin encode roam.src telemetry.src > roam.mfl
	machin build roam.mfl -o roam

# Fully-static release binary: bundles the SQLite amalgamation, statically links
# OpenSSL, and embeds a CA root store — runs FROM scratch on any x86-64 Linux with
# no libsqlite3 / libssl / libc needed. This is the artifact attached to releases.
# The version the BINARY reports lives in telemetry.src; the Makefile carries it
# too. They drifted a whole release apart once, and nothing noticed because
# there was no way to ask a built binary what it was. Now the release refuses.
version-check:
	@grep -q 'tstr = "$(VERSION)"' telemetry.src || { \
	  echo "version mismatch: Makefile says $(VERSION), telemetry.src says $$(grep -oE 'func roam_version.*tstr = \"[^\"]+\"' telemetry.src | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"; \
	  exit 1; }

release: version-check
	machin encode roam.src telemetry.src > roam.mfl
	machin build --static roam.mfl -o roam-x86_64-linux
	sha256sum roam-x86_64-linux > roam-x86_64-linux.sha256
	@echo "built roam-x86_64-linux ($$(du -h roam-x86_64-linux | cut -f1), static)"

clean:
	rm -f roam roam.mfl roam-x86_64-linux roam-x86_64-linux.sha256
