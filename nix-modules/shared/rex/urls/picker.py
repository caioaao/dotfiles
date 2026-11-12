import re
import subprocess
import sys


def extract(text):
    """Recognize tmux's URL forms, ordered by their last terminal occurrence."""
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
    return list(urls)


def main():
    # Preserve the active server's matching CLI and inherited REX_* context.
    capture = subprocess.run(
        ["rex", "capture", "--block", sys.argv[1], "--unwrap"],
        check=True, text=True, stdout=subprocess.PIPE,
    )
    urls = extract(capture.stdout)
    if not urls:
        print("No URLs found. Press Enter to close.", flush=True)
        input()
        return
    selected = subprocess.run(
        ["fzf", "--multi", "--exit-0", "--no-preview", "--no-sort",
         "--layout=reverse-list", "--prompt=Open URL> "],
        input="\n".join(urls), text=True, stdout=subprocess.PIPE,
    )
    if selected.returncode in (1, 130):
        return
    selected.check_returncode()
    for url in selected.stdout.splitlines():
        opener = ["/usr/bin/open"] if sys.platform == "darwin" else ["xdg-open"]
        subprocess.run(opener + [url], check=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"URL picker: {error}", file=sys.stderr, flush=True)
        input("Press Enter to close.")
        sys.exit(1)
