#! -*- coding:utf-8 -*-
import time

from kombu import Exchange, Queue, Consumer, Connection
from kombu.messaging import Producer  
from kombu.transport.base import Message  
  
connection = Connection('amqp://guest:guest@localhost//')  
channel = connection.channel()

#定义了一个exchange
task_exchange = Exchange('tasks', channel=channel, type='topic', durable=False)
task_exchange.declare()

#在这里进行了exchange和queue的绑定，并且指定了这个queue的routing_key
task_queue = Queue('piap', task_exchange, channel=channel, routing_key='suo_piao.#', durable=False)
task_queue.declare()

message=Message(channel,body='Hello Kombu')

# produce  
producer = Producer(channel, exchange=task_exchange, auto_declare=False)  
producer.publish(message.body,routing_key='suo_piao.abc')
# producer.publish(message.body,routing_key='suo_piao')

def process_media(body, message):#body是某种格式的数据，message是一个Message对象，这两个参数必须提供  
    print body  
    print message.delivery_info
    message.ack()  
  
# consume  
consumer = Consumer(channel, task_queue, auto_declare=False)
consumer.register_callback(process_media)  
consumer.consume()  

# while True:  
#     print "a"
#     connection.drain_events()
print task_queue.routing_key
connection.drain_events()

time.sleep(5)

task_queue.delete(nowait=True)
task_exchange.delete(nowait=True)