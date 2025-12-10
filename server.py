from http.server import HTTPServer, SimpleHTTPRequestHandler

class StaticHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

if __name__ == '__main__':
    port = 5000
    server = HTTPServer(('0.0.0.0', port), StaticHandler)
    print(f'Static server running on http://0.0.0.0:{port}')
    server.serve_forever()
