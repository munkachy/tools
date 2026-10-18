#!/usr/bin/env python3
"""Download a YouTube transcript as clean text, ready to paste into an AI.

This is the method that worked: yt-dlp, trying several YouTube "clients"
in turn, because YouTube often blocks one and lets another through.

Setup:   pip install -U yt-dlp
Usage:   python yt_transcript.py URL            # 5-minute blocks with timestamps
         python yt_transcript.py URL --plain    # one continuous block of text
         python yt_transcript.py URL -o out.txt # also save to a file
"""
import argparse, glob, os, re, subprocess, sys, tempfile, time

CLIENTS = ['default', 'android', 'tv', 'web_safari', 'mweb', 'ios']
LANGS = 'en,en-US,en-GB,en-orig'


def fetch_vtt(url):
    d = tempfile.mkdtemp()
    for client in CLIENTS:
        cmd = ['yt-dlp', '--skip-download', '--write-subs', '--write-auto-subs',
               '--sub-langs', LANGS, '--sub-format', 'vtt', '-q', '--no-warnings',
               '-o', os.path.join(d, 'v'), url]
        if client != 'default':
            cmd[1:1] = ['--extractor-args', f'youtube:player_client={client}']
        print(f'Trying {client} ...', file=sys.stderr)
        subprocess.run(cmd)
        files = sorted(glob.glob(os.path.join(d, '*.vtt')))
        if files:
            # prefer the original-language auto track, then plain English
            files.sort(key=lambda f: ('en-orig' not in f, f))
            return files[0]
        time.sleep(2)
    return None


def parse_vtt(path):
    """Return [(start_seconds, text)], with auto-caption repeats removed."""
    out, last, start = [], '', None
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        m = re.match(r'(\d+):(\d+):(\d+\.\d+) -->', line)
        if m:
            h, mi, s = m.groups()
            start = int(h) * 3600 + int(mi) * 60 + float(s)
            continue
        if not line or start is None:
            continue
        text = re.sub(r'<[^>]+>', '', line).replace('&gt;', '>').replace('&amp;', '&').strip()
        if text and text != last:
            out.append((start, text))
            last = text
    return out


def stamp(sec):
    sec = int(sec)
    return f'{sec // 3600}:{sec % 3600 // 60:02d}:{sec % 60:02d}'


def format_text(lines, plain, block=300):
    if plain:
        return ' '.join(t for _, t in lines)
    blocks = {}
    for s, t in lines:
        blocks.setdefault(int(s // block), []).append(t)
    return '\n\n'.join(f'[{stamp(k * block)}]\n' + ' '.join(v) for k, v in sorted(blocks.items()))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('url')
    p.add_argument('--plain', action='store_true', help='no timestamps')
    p.add_argument('-o', '--output', help='also save to this file')
    a = p.parse_args()

    vtt = fetch_vtt(a.url)
    if not vtt:
        sys.exit('Could not get captions. Try again in a few minutes, '
                 'update yt-dlp (pip install -U yt-dlp), or use a backup method.')
    text = format_text(parse_vtt(vtt), a.plain)
    if a.output:
        open(a.output, 'w', encoding='utf-8').write(text + '\n')
        print(f'Saved {a.output}', file=sys.stderr)
    print(text)


if __name__ == '__main__':
    main()
