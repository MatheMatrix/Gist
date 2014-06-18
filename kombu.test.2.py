#! -*- coding:utf-8 -*-
import time
import datetime
import threading

from twisted.internet import protocol, reactor, defer
from kombu import Exchange, Queue, Consumer, Connection
from kombu.messaging import Producer
from kombu.transport.base import Message
from kombu.common import eventloop, drain_consumer
from kombu.async import Hub

connection = Connection('amqp://guest:guest@localhost//')
channel = connection.channel()

# 定义了一个exchange
task_exchange = Exchange('tasks', channel=channel, type='topic', durable=False)
task_exchange.declare()

# 在这里进行了exchange和queue的绑定，并且指定了这个queue的routing_key
task_queue = Queue('piap', task_exchange, channel=channel,
                   routing_key='suo_piao.#', durable=False)
task_queue.declare()

message = Message(channel, body=
    {'state_strings': [u'pending'], 'stepid': 1, 'complete_at': None, 
    'name': u'git', 'buildid': 1, 'results': None, 'number': 0, 'urls': [], 
    'complete': False})

# produce
producer = Producer(channel, exchange=task_exchange, auto_declare=False, serializer="json")
producer.publish(message.body, routing_key='abc.suo_piao')
producer.publish(message.body, routing_key='def.suo_piao')
producer.publish(message.body, routing_key='suo_piao.def')
producer.publish(message.body, routing_key='suo_piao.abc')
# producer.publish(message.body,routing_key='suo_piao')


def process_media(body, message):  # body是某种格式的数据，message是一个Message对象，这两个参数必须提供
    print body
    print message.delivery_info
    # message.ack()

def process_media2(body, message):  # body是某种格式的数据，message是一个Message对象，这两个参数必须提供
    print "test"
    message.ack()

def print_a():
    print 'zhe...'
# consume
consumer = Consumer(channel, task_queue, auto_declare=False)
consumer.register_callback(process_media)
consumer.register_callback(process_media2)
consumer.consume()

# while True:
#     print "a"
#     connection.drain_events()
print task_queue.routing_key
# consumer.receive(message.body, message)
# defer.succeed(connection.drain_events())
# print 'a'
# defer.succeed(connection.drain_events())
# print 'b'
# defer.succeed(connection.drain_events())
# producer.publish(message.body, routing_key='suo_piao.abc')
# connection.drain_events()
# it = eventloop(connection, timeout=1, ignore_timeouts=True)
# deferred = next(it)
# deferred.addCallbacks(print_a, print_a)
# print 'a'
# deferred = next(it)
# print 'b'
# deferred = next(it)
# producer.publish(message.body, routing_key='suo_piao.abc')
# next(it)
# next(it)
# next(it)

hub = Hub()
connection.register_with_event_loop(hub)
threadLock = threading.Lock()

class myThread (threading.Thread):
    def __init__(self):
        threading.Thread.__init__(self)
        # self.daemon = True
    def run(self):
        print "Starting " + self.name
       # 获得锁，成功获得锁定后返回True
       # 可选的timeout参数不填时将一直阻塞直到获得锁定
       # 否则超时后将返回False
        # threadLock.acquire()
        hub.run_forever()
        # 释放锁
        # threadLock.release()

    def __exit__(self):
        print "test"
        hub.stop()

thread = myThread()
thread.start()

print "a"
print "b"

print "c"

print "d"

print "e"

time.sleep(3)
thread.__exit__()

# task_queue.delete(nowait=True)
# task_exchange.delete(nowait=True)
# connection.release()