"""Serve generated QA files on loopback with ranges and a throttled path."""

from argparse import ArgumentParser
from hashlib import sha256
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import time
from urllib.parse import urlparse


def catalog_fixtures(origin):
    return {
        "/catalog-subscription.json": (
            "application/json",
            json.dumps({
                "schemaVersion": 1,
                "sources": [
                    {"id": "qa-json", "name": "QA JSON", "format": "json",
                     "endpoint": f"{origin}/catalog.json"},
                    {"id": "qa-rss", "name": "QA RSS", "format": "rss",
                     "endpoint": f"{origin}/catalog.rss"},
                    {"id": "qa-web", "name": "QA Web", "format": "web",
                     "endpoint": f"{origin}/catalog.html"},
                ],
            }),
        ),
        "/catalog.json": (
            "application/json",
            json.dumps({
                "schemaVersion": 1,
                "resources": [
                    {"id": "hls", "title": "QA HLS", "bangumiSubjectId": 400602,
                     "bangumiEpisodeId": 8766, "url": "/test.m3u8"},
                    {"id": "wrong", "title": "QA episode 2", "bangumiSubjectId": 400602,
                     "bangumiEpisodeId": 8767, "url": "/AniView-QA.mp4"},
                ],
            }),
        ),
        "/catalog.rss": (
            "application/rss+xml",
            '<rss version="2.0" xmlns:av="urn:aniview:catalog:v1"><channel>'
            '<item><guid>qa</guid><title>QA RSS</title>'
            '<av:subjectId>400602</av:subjectId><av:episodeId>8766</av:episodeId>'
            '<enclosure url="/AniView-QA.mp4" type="video/mp4"/></item></channel></rss>',
        ),
        "/catalog.html": (
            "text/html",
            '<!doctype html><video data-aniview-id="qa" data-title="QA Web" '
            'data-bangumi-subject="400602" data-bangumi-episode="8766">'
            '<source src="/AniView-QA.mp4" type="video/mp4"></video>',
        ),
    }


def animeko_fixtures(origin):
    web_config = {
        "searchUrl": f"{origin}/web-search.html?q={{keyword}}",
        "subjectFormatId": "a",
        "selectorSubjectFormatA": {"selectLists": "a.result"},
        "channelFormatId": "no-channel",
        "selectorChannelFormatNoChannel": {"selectEpisodes": "a.episode"},
    }
    json_config = {
        "baseUrl": origin,
        "requestInterval": 0,
        "autoMatch": {"enabled": True},
        "search": {
            "request": {
                "url": "/animeko/search",
                "method": "POST",
                "body": ('{"search_term":"{keyword}","page_number":{page},'
                         '"items_per_page":{pageSize}}'),
            },
            "pageSize": 10,
            "selectItems": "$[*]",
            "selectName": "$.title",
            "selectId": "$.id",
        },
        "subject": {
            "request": {
                "url": "/animeko/subject",
                "method": "POST",
                "body": '{"p_id":{id}}',
            },
            "channelFormatId": "grouped",
            "channelFormatGrouped": {
                "selectChannels": "$.sources[*]",
                "selectChannelName": "$.name",
            },
            "episodes": {
                "selectEpisodes": "$.episodes[*]",
                "selectName": "$.title",
                "selectId": "$.id",
                "selectSort": "$.episode_number",
                "selectType": "$.kind",
                "typeMapping": "main=MainStory\nsp=SP",
            },
        },
        "play": {
            "request": {
                "url": "/animeko/play",
                "method": "POST",
                "body": '{"episode_id":{id}}',
            },
            "selectCandidates": "$.candidates[*]",
            "selectCandidateChannel": "$.source_name",
            "selectVideoUrl": "$.url",
            "fallbackToFirstCandidate": False,
        },
    }
    return {
        "/animeko-subscription.json": (
            "application/json",
            json.dumps({
                "schemaVersion": 2,
                "mediaSources": [
                    {"id": "web_fixture", "factoryId": "web-selector", "version": 2,
                     "arguments": {"name": "QA Animeko Web", "searchConfig": web_config}},
                    {"id": "json_fixture", "factoryId": "json-api", "version": 1,
                     "arguments": {"name": "QA Animeko JSON", "searchConfig": json_config}},
                ],
            }),
        ),
        "/web-search.html": (
            "text/html",
            "<a class='result' href='/web-subject.html'>Integration QA</a>",
        ),
        "/web-subject.html": (
            "text/html",
            "<a class='episode' href='/web-play.html' "
            "data-bangumi-subject='400602' data-bangumi-episode='8766'>第1集</a>"
            "<a class='episode' href='/web-play-2.html' "
            "data-bangumi-subject='400602' data-bangumi-episode='8767'>第2集</a>",
        ),
        "/web-play.html": ("text/html", "<video src='/missing.mp4'></video>"),
        "/web-play-2.html": ("text/html", "<video src='/AniView-QA.mp4'></video>"),
    }


def animeko_api(path, values):
    if path == "/animeko/search" and values.get("search_term") == "Integration QA":
        return [{"id": 101, "title": "Integration QA", "bangumi_id": 400602}]
    if path == "/animeko/subject" and values.get("p_id") == 101:
        return {
            "sources": [{
                "name": "QA",
                "episodes": [
                    {"id": 118, "title": "Episode 3", "episode_number": 3,
                     "kind": "main", "bangumi_episode_id": 8768},
                    {"id": 116, "title": "Episode 1", "episode_number": 1,
                     "kind": "main", "bangumi_episode_id": 8766},
                ],
            }],
        }
    if path == "/animeko/play":
        video = {116: "/test.m3u8", 118: "/AniView-QA.mp4"}.get(values.get("episode_id"))
        if video:
            return {"candidates": [{"source_name": "QA", "url": video}]}
    return None


def handler(directory):
    class MediaHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            self._send_file(include_body=True)

        def do_HEAD(self):
            self._send_file(include_body=False)

        def do_POST(self):
            path = urlparse(self.path).path
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 4096:
                    raise ValueError
                values = json.loads(self.rfile.read(length))
                if not isinstance(values, dict):
                    raise ValueError
                reply = animeko_api(path, values)
            except (ValueError, TypeError):
                self.send_error(400)
                return
            if reply is None:
                self.send_error(404)
                return
            self._send_fixture("application/json", json.dumps(reply), include_body=True)

        def _send_fixture(self, mime, text, include_body):
            body = text.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", f"{mime}; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if include_body:
                self.wfile.write(body)

        def _send_file(self, include_body):
            target = urlparse(self.path)
            path = target.path
            origin = f"http://127.0.0.1:{self.server.server_port}"
            fixture = (
                catalog_fixtures(origin).get(path) or animeko_fixtures(origin).get(path)
            )
            if fixture is not None:
                self._send_fixture(*fixture, include_body)
                return
            throttled = path.startswith("/slow/")
            interrupted = path.startswith("/interrupted/")
            name = path.removeprefix("/slow/").removeprefix("/interrupted/").lstrip("/")
            if not re.fullmatch(r"AniView-QA\.mp4|test\.m3u8|segment-\d{3}\.ts", name):
                self.send_error(404)
                return
            file = directory / name
            if not file.is_file():
                self.send_error(404)
                return
            size = file.stat().st_size
            validator = '"' + sha256(file.read_bytes()).hexdigest() + '"'
            start, end = 0, size - 1
            value = self.headers.get("Range")
            conditional = self.headers.get("If-Range")
            partial = bool(value and conditional in [None, validator])
            if partial:
                match = re.fullmatch(r"bytes=(\d+)-(\d*)", value)
                if match is None or int(match[1]) >= size:
                    self.send_response(416)
                    self.send_header("Content-Range", f"bytes */{size}")
                    self.end_headers()
                    return
                start = int(match[1])
                end = min(size - 1, int(match[2])) if match[2] else size - 1
            mime = {".m3u8": "application/vnd.apple.mpegurl", ".ts": "video/mp2t", ".mp4": "video/mp4"}
            self.send_response(206 if partial else 200)
            self.send_header("Content-Type", mime[file.suffix])
            self.send_header("Content-Length", str(end - start + 1))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("ETag", validator)
            if partial:
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
            self.end_headers()
            if not include_body:
                return
            step = 8192 if throttled else 65536
            try:
                with file.open("rb") as media:
                    media.seek(start)
                    remaining = end - start + 1
                    while remaining > 0:
                        chunk = media.read(min(step, remaining))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        remaining -= len(chunk)
                        if interrupted and not partial:
                            self.close_connection = True
                            return
                        if interrupted and partial:
                            time.sleep(0.04)
                        if throttled:
                            time.sleep(0.2)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass

    return MediaHandler


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--directory", type=Path, default=Path(".tooling/test-media"))
    parser.add_argument("--port", type=int, default=8172)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler(args.directory.resolve())) as server:
        server.serve_forever()
