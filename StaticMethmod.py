class a():

    @staticmethod
    def staticm():
        print 'static'

    def normalm(self):
        print 'nomarl',self

    @classmethod
    def classm(cls):
        print 'class',cls

a1 = a()
a1.normalm()
a1.staticm()
a.classm()
a1.classm()
print type(a)
print type(a1)
print type(type(a))
