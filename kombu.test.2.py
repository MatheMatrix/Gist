#! -*- coding:utf-8 -*-

from kombu import Exchange, Queue, Consumer, Connection
from kombu.messaging import Producer  
from kombu.transport.base import Message  

#定义了一个exchange
task_exchange = Exchange('tasks', type='direct')

#在这里进行了exchange和queue的绑定，并且指定了这个queue的routing_key
task_queue = Queue('piap', task_exchange, routing_key='suo_piao')
  
connection = Connection('amqp://guest:guest@localhost')  
channel = connection.channel()  
  
message=Message(channel,body='Hello Kombu')  
  
# produce  
producer = Producer(channel,exchange=task_exchange)  
producer.publish(message.body,routing_key='suo_piao')  

def process_media(body, message):#body是某种格式的数据，message是一个Message对象，这两个参数必须提供  
    print body  
    message.ack()  
  
# consume  
consumer = Consumer(channel, task_queue)  
consumer.register_callback(process_media)  
consumer.consume()  
  
while True:  
    connection.drain_events()