#!/usr/bin/python
#encoding:utf8

import cgi
import cgitb
import sys
import os

#Make the environ argument
environ = {}
environ['REQUEST_METHOD'] = os.environ['REQUEST_METHOD']
environ['SCRIPT_NAME'] = os.environ['SCRIPT_NAME']
environ['PATH_INFO'] = os.environ['PATH_INFO']
environ['QUERY_STRING'] = os.environ['QUERY_STRING']
environ['CONTENT_TYPE'] = os.environ['CONTENT_TYPE']
environ['CONTENT_LENGTH'] = os.environ['CONTENT_LENGTH']
environ['SERVER_NAME'] = os.environ['SERVER_NAME']
environ['SERVER_PORT'] = os.environ['SERVER_PORT']
environ['SERVER_PROTOCOL'] = os.environ['SERVER_PROTOCOL']
environ['wsgi.version'] = (1, 0)
environ['wsgi.url_scheme'] = 'http'
environ['wsgi.input']        = sys.stdin
environ['wsgi.errors']       = sys.stderr
environ['wsgi.multithread']  = False
environ['wsgi.multiprocess'] = True
environ['wsgi.run_once']     = True


#make the start_response argument
#注意，WSGI协议规定，如果没有body内容，是不能返回http response头信息的。
sent_header = False
res_status = None
res_headers = None

def write(body):
    global sent_header
    if sent_header:
        sys.stdout.write(body)
    else:
        print res_status
        for k, v in res_headers:
            print k + ': ' + v
        print 
        sys.stdout.write(body)
        sent_header = True

def start_response(status, response_headers):
    global res_status
    global res_headers
    res_status = status
    res_headers = response_headers
    return write

#here is the application
def application(environ, start_response):
    status = '200 OK'
    output = 'World!'
    response_headers = [('Content-type', 'text/plain'),
                        ('Content-Length', str(12)]
    write = start_response(status, response_headers)
    write('Hello ')
    return [output]

#here run the application
result = application(environ, start_response)
for value in result: 
    write(value)