
GRILO_DIR=`pkg-config --variable datarootdir grilo-0.3`/grilo-plugins/grl-lua-factory/
QUVI_DIR=`pkg-config --variable scriptsdir libquvi-scripts-0.9`/0.9/media/

all: check-dirs resources

check-dirs:
	@pkg-config --variable datarootdir grilo-0.3 > /dev/null
	@pkg-config --variable scriptsdir libquvi-scripts-0.9 > /dev/null

resources: template-resource.xml
	@for i in grilo/*.lua; do							\
		ICON_BASE=`basename $$i | sed 's/.lua//' | sed 's/grl-//'` ;		\
		if [ -f grilo/$$ICON_BASE.png ] ; then ICON_NAME=grilo/$$ICON_BASE.png ; fi ;	\
		if [ -f grilo/$$ICON_BASE.svg ] ; then ICON_NAME=grilo/$$ICON_BASE.svg ; fi ;	\
		if [ x$$ICON_NAME != "x" ] ; then						\
			cat template-resource.xml | sed "s,@ICON_NAME@,$$ICON_NAME," | sed "s,@ICON_BASE@,$$ICON_BASE," > grilo/grl-$$ICON_BASE.gresource.xml ; \
			glib-compile-resources grilo/grl-$$ICON_BASE.gresource.xml ;	\
		fi ;									\
		ICON_BASE='' ;							\
		ICON_NAME='' ;							\
	done

install: check-dirs
	@for i in grilo/*.lua grilo/*gresource; do \
		install -D -m 0644 $$i $(GRILO_DIR)/`basename $$i` ; \
	done
	@for i in quvi/*lua; do \
		install -D -m 0644 $$i $(QUVI_DIR)/`basename $$i` ; \
	done
