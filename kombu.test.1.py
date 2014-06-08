from kombu import Connection, Exchange, Queue

media_exchange = Exchange('media', 'direct', durable=True)
video_queue = Queue('video', exchange=media_exchange, routing_key='video')


def process_media(body, message):
    print '*'*10
    print body
    print '*'*10
    message.ack()

# Connection
with Connection('amqp://guest@localhost//') as conn:

    # produce
    producer = conn.Producer(serializer='json')
    producer.publish({'name': '/tmp/locat1.avi', 'size': 1301013},
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
        while True:
            print "I'm here"
            conn.drain_events()