# This file is part of Buildbot.  Buildbot is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Copyright Buildbot Team Members

import pprint
import kombu
import amqp.exceptions
import threading

from buildbot import config
from buildbot.mq import base
from twisted.python import log


class KombuMQ(config.ReconfigurableServiceMixin, base.MQBase):

    def __init__(self, master, conn='amqp://guest:guest@localhost//'):
        # connection is a string and its default value:
        base.MQBase.__init__(self, master)
        self.debug = False
        self.conn = kombu.Connection(conn)
        self.channel = conn.channel()
        self.setupExchange()
        self.queues = {}
        self.producer = kombu.Producer(
            channel, exchange=self.exchange, auto_declare=False)
        # NOTE(damon) auto_declrae often cause redeclare and will cause error
        self.consumers = {}
        self.message_hub = KombuHub(self.conn)
        self.message_hub.start()

    def setupExchange(self):
        self.exchange = kombu.Exchange(
            'buildbot', 'topic', channel=self.channel, durable=True)
        # NOTE(damon) if durable = false, durable queue will cant bind to this
        # exchange
        try:
            self.exchange.declare()
        except amqp.exceptions.PreconditionFailed, e:
            log.msg(
                "WARNNING: exchange buildbot already exist, " +
                "this maybe casued by anomaly exit last time")
            # NOTE(damon) should we raise Exception here?
        else:
            raise
        finally:
            log.msg("MSG: Exchange start successfully")

    def reconfigService(self, new_config):
        self.debug = new_config.mq.get('debug', False)
        return config.ReconfigurableServiceMixin.reconfigService(self,
                                                                 new_config)

    def regeristyQueue(self, key, name=None, durable=False):
        if name == None:
            name = key
        if self._checkKey(key) == True:
            # NOTE(damon) check for if called by other class
            self.queues[name] = kombu.Queue(
                name, self.exchange, channel=self.channel, routing_key=key,
                durable=durable)
            self.queues[name].declare()
        else:
            log.msg(
                "ERROR: Routing Key %s has been used by, regeristy queue failed" % key)
            raise Exception("ERROR: Routing Key %s has been used" % key)
            # NOTE(damon) should raise an exception here?

    def _checkKey(self, key):
        # check whether key already in queues
        for queue in self.queues:
            if queue.routing_key == key:
                return False
        return True

    def produce(self, routingKey, data):
        if self.debug:
            log.msg("MSG: %s\n%s" % (routingKey, pprint.pformat(data)))
        key = self.formatKey(routingKey)
        message = kombu.Message(self.channel, body=data)
        self.producer.publish(message.body, routing_key=key)
        # TODO(damon) default serializer is JSON, it doesn't support python's datetime

    def regeristyConsumer(self, queues_name, callback, name=None, durable=False):
        # queues_name can be a list of queues' names or one queue's name
        # (list of strings or one string)
        if name == None:
            name = queues_name

        if type(queues) == list:
            queues = self.getQueues(queues_name)
        else:
            queues = self.queues[queues_name]
        if not name in self.conmusers:
            self.consumers[name] = kombu.Consumer(
                self.channel, queues, auto_declare=False)
            self.consumers[name].register_callback(callback)

    def getQueues(self, queues_name):
        queues = []
        for name in queues_name:
            queues.append(self.queues[name])
        return queues

    def startConsuming(self, callback, routingKey, persistent_name=None):
        key = formatKey(routingKey)

        try:
            queue = self.queues[key]
        except:
            self.regeristyQueue(key)
            queue = self.queues[key]

        if key in self.consumer.keys():
            log.msg(
                "WARNNING: Consumer's Routing Key %s has been used by, " % key + 
                "regeristy failed")
            if callback in self.consumer[key].callbacks:
                log.msg(
                    "WARNNING: Consumer %s has been regeristy to callback %s "
                     % (key, callback))
            else:
                self.consumer[key].register_callback(callback)
        else:
            self.regeristyConsumer(key, callback)

    def formatKey(self, key):
        # transform key from a tuple to a string with standard routing key's format
        result = ""
        for item in key:
            if item == None:
                result += "*."
            else:
                result += item + "."

        return result[:-1]

    def __exit__(self):
        self.message_hub.__exit__()
        for queue in self.queues:
            queue.delete(nowait=True)
        self.exchange.delete(nowait=True)
        self.conn.release()

class KombuHub(threading.Thread):
    """Message hub to handle message asynchronously by start a another thread"""

    def __init__(self, conn):
        threading.Thread.__init__(self)
        self.conn = conn
        self.hub = kombu.async.Hub()

        self.conn.register_with_event_loop(self.hub)

    def run(self):
        self.hub.run_forever()

    def __exit__(self):
        self.hub.stop()