// piobs - observe active pi sessions.
//
//	piobs                       TUI: session list + distilled feed
//	piobs list                  print sessions to stdout
//	piobs distill <id-prefix>   one-shot catch-up distill (prints new lines)
//	piobs redistill <id-prefix> rebuild a session's feed from scratch
package main

import (
	"fmt"
	"os"
	"strings"

	"piobs/internal/store"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string) error {
	cmd := ""
	if len(args) > 0 {
		cmd = args[0]
	}

	st, err := store.New()
	if err != nil {
		return err
	}

	switch cmd {
	case "", "tui":
		return runTui(st)
	case "list":
		st.GC(14)
		return list(st)
	case "distill":
		s, err := findSession(st, args[1:])
		if err != nil {
			return err
		}
		return distillCmd(st, s, false)
	case "redistill":
		s, err := findSession(st, args[1:])
		if err != nil {
			return err
		}
		return distillCmd(st, s, true)
	default:
		return fmt.Errorf("unknown command: %s\nusage: piobs [tui|list|distill <id>|redistill <id>]", cmd)
	}
}

func findSession(st *store.Store, args []string) (store.SessionInfo, error) {
	if len(args) == 0 || args[0] == "" {
		return store.SessionInfo{}, fmt.Errorf("usage: piobs <command> <session-id-prefix>")
	}
	prefix := args[0]
	var matches []store.SessionInfo
	for _, s := range st.ListSessions() {
		if strings.HasPrefix(s.SessionID, prefix) {
			matches = append(matches, s)
		}
	}
	switch len(matches) {
	case 0:
		return store.SessionInfo{}, fmt.Errorf("no session matches '%s'", prefix)
	case 1:
		return matches[0], nil
	default:
		ids := make([]string, len(matches))
		for i, m := range matches {
			ids[i] = m.SessionID
		}
		return store.SessionInfo{}, fmt.Errorf("ambiguous: %s", strings.Join(ids, ", "))
	}
}

func list(st *store.Store) error {
	for _, s := range st.ListSessions() {
		title := s.SessionName
		if title == "" {
			title = s.LastPrompt
		}
		fmt.Printf("%-7s  %s  %-40s  %-30s  %s\n",
			s.EffectiveState,
			s.SessionID[:min(8, len(s.SessionID))],
			tildify(s.Cwd),
			s.Model,
			firstN(title, 60),
		)
	}
	return nil
}

// tildify replaces the home-dir prefix with ~.
func tildify(path string) string {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return path
	}
	if path == home {
		return "~"
	}
	if strings.HasPrefix(path, home+"/") {
		return "~" + path[len(home):]
	}
	return path
}

func firstN(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}
