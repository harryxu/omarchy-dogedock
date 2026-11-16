# Render settings from extension declarations

The [current design](../extensions-design.md#enabling-extensions) gives the storage path for these values.

An extension can declare multiple named settings, each with a type, label, default, and single-value or list cardinality. DogeDock renders the controls below the enable switch for built-in and configured external extensions. This gives users a consistent settings panel and lets extension authors describe their fields without implementing a form.

The manifest declares the fields, so DogeDock can read them before starting the extension's QML. User values live in the `settings` object of the matching `dock.extensions` entry in `shell.json`, alongside the enable switch. Disabling the extension retains those values, and each confirmed edit updates the running extension when the save succeeds.
