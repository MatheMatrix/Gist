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
import kombu.async
import amqp.exceptions
import multiprocessing

from buildbot import config
from buildbot.mq import base
from buildbot.util import datetime2epoch
from datetime import datetime
from kombu.transport.base import Message
from twisted.python import log


class KombuMQ(config.ReconfigurableServiceMixin, base.MQBase):

    def __init__(self, master, conn='librabbitmq://guest:guest@localhost//'):
        # connection is a string and its default value:
        base.MQBase.__init__(self, master)
        self.debug = False
        self.conn = kombu.Connection(conn)
        self.channel = self.conn.channel()
        self.setupExchange()
        self.queues = {}
        self.producer = kombu.Producer(
            self.channel, exchange=self.exchange, auto_declare=False)
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
        except:
            log.msg("ERR: Unexpected error")
            raise
        finally:
            log.msg("MSG: Exchange start successfully")

    def reconfigService(self, new_config):
        self.debug = new_config.mq.get('debug', True)
        return config.ReconfigurableServiceMixin.reconfigService(self,
                                                                 new_config)

    def registerQueue(self, key, name=None, durable=False):
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
                "ERR: Routing Key %s has been used, register queue failed" % key)
            # raise Exception("ERROR: Routing Key %s has been used" % key)
            # NOTE(damon) should raise an exception here?

    def _checkKey(self, key):
        # check whether key already in queues
        for queue in self.queues.values():
            if queue.routing_key == key:
                return False
        return True

    def produce(self, routingKey, data):
        self.debug = True
        if self.debug:
            log.msg("MSG: %s\n%s" % (routingKey, pprint.pformat(data)))
        key = self.formatKey(routingKey)
        data = self.formatData(data)
        message = Message(self.channel, body=data)
        try:
            self.producer.publish(message.body, routing_key=key)
        except:
            ensurePublish = self.conn.ensure(self.producer, 
                                        self.producer.publish, max_retries=3)
            ensurePublish(message.body, routing_key=key)

    def registerConsumer(self, queues_name, callback, name=None, durable=False):
        # queues_name can be a list of queues' names or one queue's name
        # (list of strings or one string)
        if name == None:
            name = queues_name

        if type(queues_name) == list:
            queues = self.getQueues(queues_name)
        else:
            queues = self.queues.get(queues_name)
        if not name in self.consumers:
            self.consumers[name] = kombu.Consumer(
                self.channel, queues, auto_declare=False)
            self.consumers[name].register_callback(callback)

    def getQueues(self, queues_name):
        queues = []
        for name in queues_name:
            queues.append(self.queues[name])
        return queues

    def startConsuming(self, callback, routingKey, persistent_name=None):
        key = self.formatKey(routingKey)

        try:
            queue = self.queues[key]
        except:
            try:
                self.registerQueue(key)
            except:
                ensureRegister = self.conn.ensure(None, 
                                                  self.registerQueue, 
                                                  max_retries=3)
                ensureRegister(key)
            try:
                queue = self.queues.get(key)
            except:
                raise

        if key in self.consumers.keys():
            log.msg(
                "WARNNING: Consumer's Routing Key %s has been used by, " % key +
                "register failed")
            if callback in self.consumers[key].callbacks:
                log.msg(
                    "WARNNING: Consumer %s has been register to callback %s "
                    % (key, callback))
            else:
                self.consumers[key].register_callback(callback)
        else:
            self.registerConsumer(key, callback)

        # self.consumers[key].addCallback = self.consumers[key].register_callback
        # self.consumers[key].addErrback = lambda x, y: log.msg("ERR: %s" % y)

        return DeferConsumer(self.consumers[key])

    def formatKey(self, key):
        # transform key from a tuple to a string with standard routing key's
        # format
        result = ""
        for item in key:
            if item == None:
                result += "*."
            else:
                result += item + "."

        return result[:-1]

    def formatData(self, data):
        if isinstance(data, dict):
            for key in data:
                if isinstance(data[key], datetime):
                    data[key] = datetime2epoch(data[key])
                elif type(data[key]) in (dict, list, tuple):
                    data[key] = self.formatData(data[key])
        elif type(data) in (list, tuple):
            for index in range(len(data)):
                if isinstance(data[index], datetime):
                    data[index] = datetime2epoch(data[index])
                elif type(data[index]) in (dict, list, tuple):
                    data[index] = self.formatData(data[index])

        return data


    def __exit__(self):
        self.message_hub.__exit__()
        for queue in self.queues:
            queue.delete(nowait=True)
        self.exchange.delete(nowait=True)
        self.conn.release()


class KombuHub(multiprocessing.Process):

    """Message hub to handle message asynchronously by start a another process"""

    def __init__(self, conn):
        multiprocessing.Process.__init__(self)
        self.conn = conn
        self.hub = kombu.async.Hub()
        self.lock = multiprocessing.Lock()

        self.conn.register_with_event_loop(self.hub)
        self.attempts = 5

    def run(self):
        if self.attempts == 0:
           raise "Attempts run kombu hub 5 times and all fail"
        try:
           self.hub.run_forever()
        except:
           self.attempts = self.attempts - 1
           self.run()

    def __exit__(self):
        self.hub.stop()

class DeferConsumer(object):

    "Use for simulating defer's addCallback"

    def __init__(self, consumer):
        self.consumer = consumer

    def addCallback(self, callback):
        self.consumer.register_callback(callback)

    def addErrback(self, callback, msg):
        self.consumer.register_callback(callback)
        log.msg(msg)

    def stopConsuming(self):
        pass
