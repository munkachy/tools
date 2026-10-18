# Transcript Grabber

Get a YouTube video's transcript as plain text, grouped into 5-minute blocks, ready to paste into Claude or another AI for a summary.

**Web page:** https://munkachy.github.io/tools/yt-transcript/

## Ways to use it

0. **iPhone** (`GetTranscript.js`, for the free Scriptable app). Share a YouTube video to it and the transcript lands on your clipboard. Setup steps are on the web page.
1. **Bookmark button** (on the web page). Drag it to your bookmarks bar, open a YouTube video, and click it. A box shows the transcript with a *Copy for AI* button. Works in desktop browsers.
2. **Paste and clean** (on the web page). Copy the text from YouTube's *Show transcript* panel, paste it in, and get clean 5-minute blocks. This always works, because nothing has to be downloaded.
3. **Python scripts** (on your own computer):

   | Script | Library | Notes |
   |---|---|---|
   | `yt_transcript.py` | `yt-dlp` | The one that worked in testing. Tries six YouTube clients in turn, because YouTube often blocks one but not another. |
   | `backup_transcript_api.py` | `youtube-transcript-api` | A separate method. Works well from home internet; usually blocked from cloud servers. |

   ```bash
   pip install -U yt-dlp youtube-transcript-api
   python yt_transcript.py "https://www.youtube.com/watch?v=VIDEO_ID"
   python backup_transcript_api.py "https://www.youtube.com/watch?v=VIDEO_ID"
   ```

   Add `--plain` to leave out timestamps. `yt_transcript.py` also takes `-o file.txt` to save the output.

## If something stops working

YouTube changes things often. First update the libraries with `pip install -U yt-dlp youtube-transcript-api`. If that doesn't help, use *Paste and clean*, which doesn't depend on YouTube's internals.
