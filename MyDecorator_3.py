attr = {'name':'', 'gender':'', 'age':''}

def add_attr(clas):
    clas.attr = attr
    return clas

@add_attr
class Person(object):
    """docstring for Person"""
    
damon = Person()
print Person.attr