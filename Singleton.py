#!/usr/bin/python3
#-*- coding:utf-8 -*-

# class Singleton2(type):  
#     def __init__(cls, name, bases, dict):
#     	    print '*'*10
#     	    print cls, name, bases, dict
#     	    super(Singleton2, cls).__init__(name, bases, dict)
#     	    cls._instance = None  
#     def __call__(cls, *args, **kw):
#     		print '*'*10
#     		print cls, args, kw
# 		if cls._instance is None:
# 			cls._instance = super(Singleton2, cls).__call__(*args, **kw)
# 		return cls._instance  
 
# class MyClass3(object):  
#      __metaclass__ = Singleton2
 
# one = MyClass3()  
# two = MyClass3() 

def singleton(cls, *args, **kw):
	print '*' * 10
	instances = {}
	print cls, args, kw
	def _singleton():
		print '*' * 10
		print instances
		print cls
		if cls not in instances:  
			instances[cls] = cls(*args, **kw)
		return instances[cls]  
	return _singleton  
 
@singleton
class MyClass4(object):  
	a = 1  
	def __init__(self, x=0):  
		self.x = x

one = MyClass4()
two = MyClass4()