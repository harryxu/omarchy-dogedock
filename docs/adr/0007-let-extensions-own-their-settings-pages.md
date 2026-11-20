# Let extensions own their settings pages

Manifest fields work for standard controls, and some extensions need interactions spanning several values and a system action. An extension can declare a settings page and supply its component from the running instance so the view and background behavior share state. DogeDock owns navigation and mounting, while the extension owns the page and its persistence.
