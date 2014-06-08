from kombu import Connection, Exchange, Queue

media_exchange = Exchange('media', 'direct', durable=True)
video_queue = Queue('video', exchange=media_exchange, routing_key='video')


def process_media(body, message):
    print '*'*10
    print body
    print '*'*10
    message.ack()

# Connection
conn = Connection('amqp://guest@localhost//')

# produce
producer = conn.Producer(serializer='json')
producer.publish('name',
    exchange = media_exchange, routing_key='video',
    declare=[video_queue])

    # # consume
    # with conn.Consumer(video_queue, callbacks=[process_media]) as consumer:
    #     while True:
    #         print "I'm HERE"
    #         conn.drain_events()

# Consume from several queues on the same channel:
video_queue = Queue('video', exchange=media_exchange, key='video')
image_queue = Queue('image', exchange=media_exchange, key='image')

with Connection('amqp://guest@localhost//') as conn:
    with conn.Consumer([video_queue, image_queue],
                            callbacks=[process_media]) as consumer:
        conn.drain_events()

print "I'm here!!"

producer.publish('woca',
    exchange = media_exchange, routing_key='video',
    declare=[video_queue])

with Connection('amqp://guest@localhost//') as conn:
    with conn.Consumer([video_queue, image_queue],
                            callbacks=[process_media]) as consumer:
        conn.drain_events()

with Connection('amqp://guest@localhost//') as conn:
    with conn.Consumer([video_queue, image_queue],
                            callbacks=[process_media]) as consumer:
        conn.drain_events()

with Connection('amqp://guest@localhost//') as conn:
    with conn.Consumer([video_queue, image_queue],
                            callbacks=[process_media]) as consumer:
        conn.drain_events()

with Connection('amqp://guest@localhost//') as conn:
    with conn.Consumer([video_queue, image_queue],
                            callbacks=[process_media]) as consumer:
        conn.drain_events()

with Connection('amqp://guest@localhost//') as conn:
    with conn.Consumer([video_queue, image_queue],
                            callbacks=[process_media]) as consumer:
        conn.drain_events()
