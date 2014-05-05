#!/usr/bin/env python
#-*- coding:utf-8 -*-

import requests

ex_ip = requests.get("http://ifconfig.me/ip").content[:-1]

import json

post_data={
"login_email":"wangweinoo1@gmail.com",
"login_password":"wangwei",
"domain":"mytrix.me",
"format":"json"}

domain_resp = requests.post("https://dnsapi.cn/Domain.List", data=post_data)
domain_id = json.loads(domain_resp.content)["domains"][0]["id"]

post_data['domain_id']=domain_id

record_resp = requests.post("https://dnsapi.cn/Record.List", data = post_data)
record_test = filter(
    lambda x:x["name"]=="test",
    json.loads(record_resp.content)["records"])[0]
record_id = record_test["id"].encode("utf8")

post_data["record_id"]=record_id
post_data["record_type"]="A"
post_data["record_line"]="默认"
post_data["sub_domain"]="test"
post_data["value"]=ex_ip

print post_data

record_change = requests.post(
    "https://dnsapi.cn/Record.Modify",
    data = post_data)

print record_change.content