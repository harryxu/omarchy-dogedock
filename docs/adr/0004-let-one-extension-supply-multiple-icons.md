# Let one extension supply multiple icons

A Dock extension keeps one instance shared across screens and can supply zero or more icons. Each icon has a stable identity within the extension so that interactions reach the intended icon when the list changes. Keeping one instance lets a folder extension manage several folders through one enable switch and one set of settings.

API v2 introduces multi-icon extensions and extension settings. DogeDock also loads API v1 extensions using their existing single-icon contract.
