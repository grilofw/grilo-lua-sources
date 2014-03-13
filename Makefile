
GRILO_DIR=`pkg-config --variable datarootdir grilo-0.2`/grilo-plugins/grl-lua-factory/
QUVI_DIR=`pkg-config --variable scriptsdir libquvi-scripts-0.9`/0.9/media/

check-dirs:
	@pkg-config --variable datarootdir grilo-0.2 > /dev/null
	@pkg-config --variable scriptsdir libquvi-scripts-0.9 > /dev/null

install: check-dirs
	@for i in grilo/*.lua; do \
		install -D -m 0644 $$i $(GRILO_DIR)/`basename $$i` ; \
	done
	@for i in quvi/*lua; do \
		install -D -m 0644 $$i $(QUVI_DIR)/`basename $$i` ; \
	done
