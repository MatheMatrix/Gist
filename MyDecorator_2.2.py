# coding: utf-8

import time
import sys
from functools import wraps

def PrintDetail(func):
    @wraps(func)
    def _PrintDetail(*args):
        print func.__name__
        print func.__doc__
        print sys.getrefcount(func)
        start = time.time()
        print func(*args)
        print time.time() - start
    return _PrintDetail

@PrintDetail
def my_power(base, exponent):
    '''return base**exponent
    '''

    return base**exponent

@PrintDetail
def my_sum(*args):
    '''return sum of vars
    '''

    return sum(args)

my_power(2, 10)
my_sum(1,2,3,4,5,6)
my_power(2, 15)