import re
import subprocess
import sys


def extract(text):
    """Recognize the five URL forms offered by the tmux picker."""
    urls = set(re.findall(
        r"(?:https?|ftp|file):/?//[-A-Za-z0-9+&@#/%?=~_|!:,.;]*[-A-Za-z0-9+&@#/%=~_|]",
        text,
    ))
    for pattern, prefix in (
        (r"\bwww\.[a-zA-Z](?:-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}(?:/[^\s'\"`<>]*)?", "http://"),
        (r"\b\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?(?:/[^\s'\"`<>]*)?", "http://"),
    ):
        urls.update(prefix + match for match in re.findall(pattern, text))
    for host, path in re.findall(r"(?:ssh://)?git@([^\s:'\"`<>/]+)[:/]([^\s'\"`<>]+)", text):
        urls.add("https://" + host + "/" + path)
    urls.update("https://github.com/" + path for path in re.findall(
        r"['\"]([_A-Za-z0-9-]+/[_.A-Za-z0-9-]+)['\"]", text,
    ))
    return sorted(urls)


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
        ["fzf", "--multi", "--exit-0", "--no-preview", "--prompt=Open URL> "],
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
