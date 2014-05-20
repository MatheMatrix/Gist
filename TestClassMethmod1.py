# !/usr/bin/env python
# -*- coding: utf-8 -*-

class TestClass():
    """docstring for TestClass"""

    def __init__(self, arg):
        self.arg = arg
        print arg

    @classmethod
    def func(cls):
        print "A"

def outer_func(cls):
    cls.func()

outer_func(TestClass)