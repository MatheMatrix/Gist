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

from buildbot import config
from buildbot.mq import base
from buildbot.util import tuplematch
from twisted.internet import defer
from twisted.python import log


class KombuMQ(config.ReconfigurableServiceMixin, base.MQBase):

    defaultRoutingKey = [
        "scheduler.$schedulerid.started", "scheduler.$schedulerid.stopped",
        "builder.$builderid.started", "builder.$builderid.stopped",
        "buildset.$bsid.new", "buildset.$bsid.complete",
        "buildrequest.$bsid.$builderid.$brid.new",
        "buildrequest.$bsid.$builderid.$brid.claimed",
        "buildrequest.$bsid.$builderid.$brid.unclaimed",
        "buildrequest.$bsid.$builderid.$brid.cancelled",
        "buildrequest.$bsid.$builderid.$brid.complete"]

    def __init__(self, master, conn):
        # connection is a string and its default value:
        # 'amqp://guest:guest@localhost//'
        base.MQBase.__init__(self, master)
        self.debug = False
        self.conn = kombu.Connection(connection)
        self.channel = conn.channel()
        self.exchange = kombu.Exchange(
            'buildbot', 'topic', channel=self.channel, durable=True)
        # NOTE(damon) if durable = false, durable queue will cant bind to this
        # exchange
        self.setupExchange()
        self.queues = {}
        self.producer = kombu.Producer(
            channel, exchange=self.exchange, auto_declare=False)
        # NOTE(damon) auto_declrae often cause redeclare

    def setupExchange(self):
        try:
            self.exchange.declare()
        except amqp.exceptions.PreconditionFailed, e:
            log.msg(
                "warnning: exchange buildbot already exist, " + 
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

    def setupQueues(self):
        for key in self.defaultRoutingKey:
            standardized_key = self.standardizeKey(key)
            if self._checkKey(key) == False:
                self.regeristyQueue(key)

    def standardizeKey(self, key):
        standardized_key = ""
        key = key.split(".")
        for part in key:
            if part[0] == "$":
                return standardized_key + ".#"
            else:
                standardized_key += part

    def regeristyQueue(self, name, key, durable=False):
        if self._checkKey(key) == True:
            # NOTE(damon) check for if called by other class
            self.queues[name] = kombu.Queue(
                name, self.exchange, channel=self.channel, routing_key=key,
                durable=durable)
            self.queues[name].declare()
        else:
            log.msg(
                "ERROR: Routing Key %d has been used by, regeristy queue failed" % key)
            raise Exception("ERROR: Routing Key %d has been used" % key)
            # NOTE(damon) should raise an exception here?

    def _checkKey(self, key):
        for queue in self.queues:
            if queue.routing_key == key:
                return False
        return True

    def produce(self, routingKey, on_ack):
        if self.debug:
            log.msg("MSG: %s\n%s" % (routingKey, pprint.pformat(data)))
        message = kombu.Message(self.channel, body=data)
        self.producer.publish(message.body, routing_key=routingKey)

    def regeristyConsumer(self, name, queues, key, durable=False):
        pass

    def startConsuming(self):
        pass
