PLUGIN_NAME := helm-fast-delete
REMOTE      := https://github.com/phantomnat/$(PLUGIN_NAME)

.PHONY: install
install:
	helm plugin install https://github.com/phantomnat/$(PLUGIN_NAME)

.PHONY: link
link:
	helm plugin install .

.PHONY: uninstall
uninstall:
	helm plugin remove fast-delete