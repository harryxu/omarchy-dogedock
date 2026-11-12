# Load trusted QML extensions in Omarchy Shell

DogeDock loads explicitly enabled built-in and external extensions as trusted QML in the Omarchy Shell process. Both use the same interface to provide icon state and actions, and DogeDock renders the icon, tooltip, and menu and dispatches input. This lets the built-in Trash exercise the same interface that external authors use and gives both the same Dock interactions. External extensions execute with the Shell process's permissions, so users should enable only code they trust.

Each extension directory declares its ID, API version, and relative QML entry point in `manifest.json`. DogeDock checks the manifest before running the entry point. One instance serves every screen, so state and background work are shared across the Dock service.
