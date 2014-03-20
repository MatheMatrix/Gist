#!/usr/bin/env python
#coding:utf-8
import os
import random
import math


class Center(object):
   
    def __init__(self, vector):
        self.vector = vector
        self.objects = []

class Vector(object):
    
    def __init__(self, label):
        self.words = {}
        self.label = label
    
    def loadFromFile(self, file_name, word_dict):
        with open(file_name,'r') as f:
	    _words = [i.split() for i in f.readlines()]
	    words = [ (i[3],i[4],i[5]) for  i  in  _words]
         #  words = f.read().split()
            for word in words:
                if word not in word_dict:
                    word_dict[word] = len(word_dict)
                word_id = word_dict[word]
                self.words[word_id] = word
            f.close()
    
    def addToNearestCenter(self, centers):
        nearest = centers[0]
        d = self.distance(centers[0].vector)
        for center in centers[1:]:
            new_d = self.distance(center.vector)
            if new_d < d:
                d = new_d
                nearest = center
        nearest.objects.append(self)
    
    def distance(self, vector):
        square_sum = 0.0
        for word in vector.words:
            if word not in self.words:
                a = vector.words[word]
                square_sum += math.pow(a, 2)
            if word in self.words:
                a,b = vector.words[word],self.words[word]
                square_sum += math.pow((a-b), 2)
        for word in self.words:
            if word not in vector.words:
                a = self.words[word]
                square_sum += math.pow(a, 2)
        result = math.sqrt(square_sum)
        return result

class KMeans(object):
    
     def __init__(self, dir_name):
        self.word_dict = {}
        self.vectors = []
        self.dir_name = dir_name
        # {'file_name':{word:3,word:4}}
        self.centers = []
        self.last_cost = 0.0
        
	for file_name in os.listdir(dir_name):
            v = Vector(file_name)
            v.loadFromFile(dir_name+'/'+file_name, self.word_dict)
            self.vectors.append(v)
     def start(self, class_num):
        for vector in random.sample(self.vectors, class_num):
            c = Center(vector)
            self.centers.append(c)
        print 'init center points'
        self.split()
        self.locateCenter()
        self.last_cost = self.costFunction()
        print 'start optimization'
        i = 0
        while True:
            i += 1
            self.split()
            self.locateCenter()
            current_cost = self.costFunction()
            print 'Ëʧ½µµÍÉһ´Î- µ±ǰ)£º',self.last_cost,' - ',current_cost,' = ',(self.last_cost - current_cost)
            if self.last_cost - current_cost  <= 1:
                break
            else:
                self.last_cost = current_cost
        count = 0
        for center in self.centers:
            count += 1
            for s in ['business','it','sports','yule','auto']:
                s_count = 0
                for vector in center.objects:
                    if vector.label.find(s) > 0:
                        s_count += 1
                print s,' = ',s_count
            print '---------------------------------------'

     def split(self):
        
        for center in self.centers:
            center.objects = []
        for vector in self.vectors:
            vector.addToNearestCenter(self.centers)
     
     def locateCenter(self):
        count = 0
        for center in self.centers:
            count += 1
            files_count = float(len(center.objects))
            new_center = {}
            for vector in center.objects:
                for word in vector.words:
                    if word not in new_center:
                        new_center[word] = 1
                    else:
                      new_center[word] += 1
            for word in new_center:
                new_center[word] = new_center[word]/files_count
            center.vector = Vector('center')
            center.vector.words = new_center


     """ ��ʧ���� """
     def costFunction(self):
        
        total_cost = 0.0
        count = 0
        for center in self.centers:
            count += 1
            for vector in center.objects:
        	 total_cost += math.pow(vector.distance(center.vector),2)
        return total_cost

if __name__ == '__main__':
    km = KMeans('/opt/workloadSuite/logkmean')
    km.start(10)
          



