# !/bin/usr/env python
# -*- coding: utf-8 -*-

import httplib
import json
import webob.dec

from webob import Response

class Controller(object):
    def __init__(self):
        # TODO
        self.version = "0.1"

    def index(self,req):
        print "I'm in index"
        response = Response(request=req,
                                  status=httplib.MULTIPLE_CHOICES,
                                  content_type='application/json')
        response.body = json.dumps(dict(versions=self.version))
        return response

    @webob.dec.wsgify
    def __call__(self, request):
        # TODO
        print "I'm in __call__"
        print "*"*20
        print request.environ
        print "*"*20
        print request
        print "*"*20
        print request.environ["wsgiorg.routing_args"]
        # return self.index(request)

def create_resource():
    return Controller()