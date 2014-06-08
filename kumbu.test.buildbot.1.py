import kombu
import pprint

from twisted.application import service

class KombuMQBase(service.Service):

    def __init__(self, master):
        self.master = master
        self.setName('komubumq')
        self.setServiceParent(self)

class KombuSimpleMQ(KombuMQBase):

    def __init__(self, master, connection):
        # connection's default value: 'amqp://guest:guest@localhost//'
        super(KombuSimpleMQ, self, master)
        self.debug = False

        self.exchanges = {"default":
                          kombu.Exchange('default', 'fanout', durable=True)}
        # defalut exchange
        # other exchange (most will be 'topic') should be set separately
        self.queues = {"default":
                       kombu.Queue("default", exchange=self.exchanges["default"], key="all")}
        # same as exchange
        self.conn = kombu.Connection(connection)
        self.producer = self.conn.Producer(serializer='json')

    def produce(self, exchange, routingKey, data):
        # exchange, routingKey should be string
        if self.debug:
            log.msg("MSG: %s\n%s" % (routingKey, pprint.pformat(data)))
        self.producer.publish(
            data, exchange=self.exchanges[exchange], routing_key="routingKey")

    def consumeOnce(self, queues, callback):
        # queues shoud be a list of strings
        queues = [self.queues[queue] for queue in queues]
        self.conn.Consumer(queues, callbacks=[callback])
        self.conn.drain_events(timeout=1)

    def __exit__(self):
        self.conn.release()