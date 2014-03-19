import inspect
import os

def a():
    b()

def b():
    c()

def c():
    for i in inspect.stack():
        print i
    print os.path.basename(inspect.stack()[-1][1])[:16]

a()