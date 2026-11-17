# Let extensions render their icons

Extensions can supply an `iconComponent` whose visual receives the current icon data. This revises the host-rendered icon boundary in [ADR 0001](0001-load-trusted-qml-extensions.md): extensions own custom rendering so new visual behavior does not require new host fields or drawing logic. DogeDock creates and destroys one visual per icon per screen, controls its size and input, and retains the existing image renderer as a fallback; the nonvisual extension instance and its state remain shared.
