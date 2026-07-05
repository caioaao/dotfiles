package main

import (
	"fmt"

	"piobs/internal/store"
)

// Placeholders until the distiller (slice 4) and TUI (slice 5) land.

func runTui(_ *store.Store) error {
	return fmt.Errorf("tui: not implemented yet")
}

func distillCmd(_ *store.Store, _ store.SessionInfo, _ bool) error {
	return fmt.Errorf("distill: not implemented yet")
}
