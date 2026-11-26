import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from urllib.parse import unquote, urlsplit


def extract_urls(text):
    """Recognize tmux's URL forms, most recently mentioned first."""
    matches = [
        (match.start(), match.group())
        for match in re.finditer(
            r"(?:https?|ftp|file):/?//[-A-Za-z0-9+&@#/%?=~_|!:,.;]*[-A-Za-z0-9+&@#/%=~_|]",
            text,
        )
    ]
    for pattern, prefix in (
        (r"\bwww\.[a-zA-Z](?:-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}(?:/[^\s'\"`<>]*)?", "http://"),
        (r"\b\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?(?:/[^\s'\"`<>]*)?", "http://"),
    ):
        matches.extend((match.start(), prefix + match.group())
                       for match in re.finditer(pattern, text))
    matches.extend(
        (match.start(), "https://" + match[1] + "/" + match[2])
        for match in re.finditer(r"(?:ssh://)?git@([^\s:'\"`<>/]+)[:/]([^\s'\"`<>]+)", text)
    )
    matches.extend(
        (match.start(), "https://github.com/" + match[1])
        for match in re.finditer(r"['\"]([_A-Za-z0-9-]+/[_.A-Za-z0-9-]+)['\"]", text)
    )
    urls = {}
    for _, url in sorted(matches):
        urls.pop(url, None)
        urls[url] = None
    return list(reversed(urls))


def extract_files(text):
    """Return existing file paths, most recently mentioned first."""
    files = {}
    for match in re.finditer(r"""[^\s`'"<>()\[\]{}]+""", text):
        candidate = match.group().rstrip(".,;:")
        if candidate.startswith("file://"):
            try:
                uri = urlsplit(candidate)
            except ValueError:
                continue
            if uri.netloc not in ("", "localhost"):
                continue
            candidate = unquote(uri.path)
        elif ":" in candidate or not any(char in candidate for char in "/."):
            continue
        if not candidate or not candidate.isprintable():
            continue
        path = Path(candidate).expanduser() if candidate.startswith("~/") else Path(candidate)
        if path.is_file():
            absolute = os.path.abspath(path)
            files.pop(absolute, None)
            files[absolute] = str(path)
    return list(reversed(files.values()))


def main():
    choose_file = sys.argv[2:] == ["--file"]
    # Preserve the active server's matching CLI and inherited REX_* context.
    capture = subprocess.run(
        ["rex", "capture", "--block", sys.argv[1], "--unwrap"],
        check=True, text=True, stdout=subprocess.PIPE,
    )
    items = extract_files(capture.stdout) if choose_file else extract_urls(capture.stdout)
    kind = "file" if choose_file else "URL"
    if not items:
        print(f"No {kind}s found. Press Enter to close.", flush=True)
        input()
        return
    command = ["fzf", "--exit-0", "--no-preview", "--no-sort",
               "--layout=reverse-list", f"--prompt=Open {kind}> "]
    if not choose_file:
        command.append("--multi")
    selected = subprocess.run(
        command, input="\n".join(items), text=True, stdout=subprocess.PIPE,
    )
    if selected.returncode in (1, 130):
        return
    selected.check_returncode()
    if not selected.stdout:
        return
    if choose_file:
        editor = shlex.split(os.environ.get("EDITOR", ""))
        if not editor:
            raise ValueError("set $EDITOR on the Rex server")
        subprocess.run(editor + [os.path.abspath(selected.stdout.rstrip("\n"))], check=True)
        return
    for url in selected.stdout.splitlines():
        opener = ["/usr/bin/open"] if sys.platform == "darwin" else ["xdg-open"]
        subprocess.run(opener + [url], check=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Rex picker: {error}", file=sys.stderr, flush=True)
        input("Press Enter to close.")
        sys.exit(1)
