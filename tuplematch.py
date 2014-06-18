import itertools

def matchTuple(routingKey, filter):
    print len(filter), len(routingKey)
    if len(filter) != len(routingKey):
        return False
    for k, f in itertools.izip(routingKey, filter):
        print k, f
        if f is not None and f != k:
            return False
    return True

if __name__ == '__main__':
    print matchTuple(('buildrequest', '1', '1', '1', 'complete'), ('buildrequest', '1', None, None, 'complete'))