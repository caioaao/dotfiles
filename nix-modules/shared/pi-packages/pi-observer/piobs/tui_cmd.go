package main

import (
	"piobs/internal/store"
	"piobs/internal/tui"
)

func runTui(st *store.Store) error {
	return tui.Run(st)
}
