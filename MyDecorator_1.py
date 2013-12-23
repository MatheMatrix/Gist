# coding: utf-8

import time
import sys

def PrintDetail(func):
    def _PrintDetail():
        print func.__name__
        print func.__doc__
        print sys.getrefcount(func)
        start = time.time()
        func()
        print time.time() - start
    return _PrintDetail

@PrintDetail
def calc():
    '''print 2**10
    '''

    print 2**10

calc()