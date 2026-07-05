package main

import (
	"context"
	"fmt"

	"piobs/internal/distill"
	"piobs/internal/store"
)

func distillCmd(st *store.Store, s store.SessionInfo, fromScratch bool) error {
	d, err := distill.New(st, distill.LoadConfig())
	if err != nil {
		return err
	}
	if fromScratch {
		if err := st.ClearFeed(s.SessionID); err != nil {
			return err
		}
	}
	n, err := d.Session(context.Background(), s, printEntry)
	if err != nil {
		return err
	}
	label := "new feed entries"
	if fromScratch {
		label = "feed entries"
	}
	fmt.Printf("\n%d %s\n", n, label)
	return nil
}

func printEntry(e store.FeedEntry) {
	detail := ""
	if e.Detail != "" {
		detail = "\n           " + e.Detail
	}
	t := e.T
	if len(t) >= 19 {
		t = t[11:19]
	}
	fmt.Printf("[%s] %-9s %s%s\n", t, e.Kind, e.Text, detail)
}
