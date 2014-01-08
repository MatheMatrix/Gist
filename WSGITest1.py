# from wsgiref.simple_server import make_server

# def simple_app(environ, start_response):
#     status = '200 OK'
#     response_headers = [('Content-type', 'text/plain')]
#     start_response(status, response_headers)
#     return [u"This is hello wsgi app".encode('utf8')]

# httpd = make_server('', 8000, simple_app)
# print "Serving on port 8000..."
# httpd.serve_forever()

from wsgiref.simple_server import make_server

class AppClass:

    def __call__(self,environ, start_response):
        status = '200 OK'
        response_headers = [('Content-type', 'text/plain')]
        start_response(status, response_headers)
        return ["hello world!"]

app = AppClass()
httpd = make_server('', 8001, app)
print "Serving on port 8001..."
httpd.serve_forever()