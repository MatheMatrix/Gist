# !/bin/usr/env python
# -*- coding: utf-8 -*-

import sys
import os
import webob
import routes
import webob.dec
import routes.middleware
from webob import Request
from webob import Response
from paste.deploy import loadapp
from wsgiref.simple_server import make_server


class AuthFilter(object):

    '''filter1,auth
       1.factory read args and print,return self instance
       2.call method return app
       3.AuthFilter(app)
    '''

    def __init__(self, app):
        self.app = app

    def __call__(self, environ, start_response):
        print 'this is Auth call filter1'
        return self.app(environ, start_response)

    @classmethod
    def factory(cls, global_conf, **kwargs):
        '''global_conf and kwargs are dict'''
        print '######AuthFilter##########'
        print 'global_conf type:', type(global_conf)
        print '[DEFAULT]', global_conf
        print 'kwargs type:', type(kwargs)
        print 'Auth Info', kwargs
        return AuthFilter


class LogFilter(object):

    '''
    filter2,Log
    '''

    def __init__(self, app):
        self.app = app

    def __call__(self, environ, start_response):
        print 'This is call LogFilter filter2'
        return self.app(environ, start_response)

    @classmethod
    def factory(cls, global_conf, **kwargs):
        print '######LogFilter###########'
        print '[DEFAULT]', global_conf
        print 'Log Info', kwargs
        return LogFilter


class ShowStuDetail(object):

    '''
    app
    '''

    def __init__(self, name, age):
        self.name = name
        self.age = age

    def __call__(self, environ, start_response):
        print 'this is call ShowStuDetail'
        start_response("200 OK", [("Content-type", "text/plain")])
        content = []
        content.append("name: %s age:%s\n" % (self.name, self.age))
        # content.append("**********WSGI INFO***********\n")
        # for k,v in environ.iteritems():
        #     content.append('%s:%s \n' % (k,v))
        return ['\n'.join(content)]  # return a list

    @classmethod
    def factory(cls, global_conf, **kwargs):
        return ShowStuDetail(kwargs['name'], kwargs['age'])


class ShowVersion(object):

    '''
    app
    '''

    def __init__(self, version):
        self.version = version

    def __call__(self, environ, start_response):
        print '*' * 20 + '\n' + 'this is call ShowVersion'
        req = Request(environ)
        res = Response()
        res.status = '200 OK'
        res.content_type = "text/plain"
        content = []
        content.append("%s\n" % self.version)
        # content.append("*********WSGI INFO*********")
        # for k,v in environ.iteritems():
        #     content.append('%s:%s\n' % (k,v))
        res.body = '\n'.join(content)
        return res(environ, start_response)

    @classmethod
    def factory(cls, global_conf, **kwargs):
        return ShowVersion(kwargs['version'])

class MyRouter(object):

    """docstring for MyRouter"""

    def __init__(self, **local_config):
        mapper = routes.Mapper()
        self._router = routes.middleware.RoutesMiddleware(self._dispatch,
                                                          mapper)

        versions_resource = create_resource()
        mapper.connect("/",controller=versions_resource, # 建立对应关系
                        action="index")

    @classmethod
    def factory(cls, global_conf, **kwargs):
        return cls()

    # @webob.dec.wsgify
    def __call__(self, environ, start_response):
        return self._router

    @staticmethod
    # @webob.dec.wsgify
    def _dispatch(req):
        match = req.environ['wsgiorg.routing_args'][1]
        if not match:
            language = req.best_match_language()
            msg = _('The resource could not be found.')
            msg = gettextutils.translate(msg, language)
            return webob.exc.HTTPNotFound(explanation=msg)
        app = match['controller']
        return app

class Controller(object):
    def __init__(self):
        # TODO
        self.version = "0.1"

    def index(self,req):
        response = Response(request=req,
                                  status=httplib.MULTIPLE_CHOICES,
                                  content_type='application/json')
        response.body = json.dumps(dict(versions=self.version))
        return response
            
    @webob.dec.wsgify
    def __call__(self, req):
        # TODO
        return self.index(req)

def create_resource():
    return Controller()


if __name__ == '__main__':
    config = 'paste.ini'
    appname = "common"
    print("config:%s" % os.path.abspath(config), appname)
    wsgi_app = loadapp("config:%s" % os.path.abspath(config), appname)
    server = make_server('localhost', 7072, wsgi_app)
    server.serve_forever()
    pass
