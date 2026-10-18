#!/usr/bin/env python3
"""Backup method: the youtube-transcript-api library (no yt-dlp needed).

Works well from a home internet connection; usually blocked from cloud servers.

Setup:   pip install -U youtube-transcript-api
Usage:   python backup_transcript_api.py URL [--plain]
"""
import re, sys
from youtube_transcript_api import YouTubeTranscriptApi


def video_id(url):
    m = re.search(r'(?:v=|youtu\.be/|shorts/|embed/|live/)([\w-]{11})', url)
    return m.group(1) if m else url


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    plain = '--plain' in sys.argv
    snippets = YouTubeTranscriptApi().fetch(video_id(sys.argv[1]), languages=['en', 'en-US', 'en-GB'])
    if plain:
        print(' '.join(s.text.replace('\n', ' ') for s in snippets))
        return
    blocks = {}
    for s in snippets:
        blocks.setdefault(int(s.start // 300), []).append(s.text.replace('\n', ' '))
    for k in sorted(blocks):
        sec = k * 300
        print(f'[{sec // 3600}:{sec % 3600 // 60:02d}:00]\n' + ' '.join(blocks[k]) + '\n')


if __name__ == '__main__':
    main()
