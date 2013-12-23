# coding: utf-8

import time
import sys

def PrintDetail(func):
    print func.__name__
    print func.__doc__
    print sys.getrefcount(func)
    start = time.time()
    func()
    print time.time() - start
    return func

@PrintDetail
def func():
    '''print 2**10
    '''

    print 2**10
func()
func()