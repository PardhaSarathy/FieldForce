"""Static server for the Flutter web preview, with caching turned off.

`python -m http.server` sends no cache headers, so Chrome holds on to
`main.dart.js` indefinitely: the server hands over a fresh bundle and the page
renders the previous build. Clearing the service-worker cache does not help —
that is a different cache. This sends `no-store` on everything, so a plain
reload always shows the build that is on disk.
"""
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, *args):
        pass  # the preview pane shows the requests; this just adds noise

    def send_head(self):
        # The app uses path URLs, so a deep link like /home is a real request
        # for a file that does not exist. Serve the shell and let the router
        # resolve it, the way any SPA host does.
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "." not in os.path.basename(path):
            self.path = "/index.html"
        return super().send_head()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    directory = sys.argv[2] if len(sys.argv) > 2 else "build/web"
    NoCacheHandler.directory = directory
    ThreadingHTTPServer(
        ("127.0.0.1", port),
        lambda *a: NoCacheHandler(*a, directory=directory),
    ).serve_forever()
