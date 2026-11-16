# Let one extension supply multiple icons

A Dock extension keeps one instance shared across screens and can supply zero or more icons. Each icon has a stable identity within the extension so that interactions reach the intended icon when the list changes. Keeping one instance lets a folder extension manage several folders through one enable switch and one set of settings.

The QML entry point publishes an `icons` array even for a single icon. The manifest can independently declare `settings`, so extensions can use either capability by itself or both together. DogeDock adapts existing single-icon entry points by their QML shape and accepts manifests without a version field.
