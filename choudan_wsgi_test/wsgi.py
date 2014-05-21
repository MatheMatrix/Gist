# !/bin/usr/env python
# -*- coding: utf-8 -*-

import logging
import routes.middleware
import webob.dec
import webob.exc


class Router(object): # 作为WSGI APP的基类，能够完成url到resource的映射

    def __init__(self, mapper=None):
        self.map =  mapper # 建立了resource的map
        self._router = routes.middleware.RoutesMiddleware(self._dispatch,
                                                         self.map) # 注册关于url的回调函数
    @classmethod
    def factory(cls, global_conf, **local_conf): # 实际的入口
        return cls() # 构造该app

    @webob.dec.wsgify # 能够将request和response封装成WSGI 风格的
    def __call__(self,req): # callable对象
        return self._router

    @staticmethod
    @webob.dec.wsgify
    def _dispatch(req):
        # TODO
        match = req.environ['wsgiorg.routing_args'][1]
        if not match:
            return webob.exc.HTTPNotFound()
        app = match['controller']
        return app