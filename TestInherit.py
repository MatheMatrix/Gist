class A(object):
	def func_in_a(self):
		print("func_in_a")
		self.func_in_b()

class B(object):
	def func_in_b(self):
		print("func_in_b")

class C(A, B):
	def func_in_c(self):
		self.func_in_a()

c = C()
c.func_in_c()
print A.__bases__
a = A()
a.func_in_a()