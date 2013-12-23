# coding:utf-8

from time import sleep

# Event Manager

event_listeners = {}

def fire_event(name):
    event_listeners[name]()

def use_event(func):
    print "I'm here"
    def call(*args, **kwargs):
        generator = func(*args, **kwargs)
        # 执行到挂起
        event_name = next(generator)
        # 将“唤醒挂起的协程”注册到事件管理器中
        def resume():
            try:
                next(generator)
            except StopIteration:
                pass
        event_listeners[event_name] = resume
    return call

# Test

@use_event
def test_work():
    print("=" * 50)
    print("waiting click")
    yield "click"  # 挂起当前协程, 等待事件
    print("clicked !!")

if __name__ == "__main__":
    test_work()
    sleep(3)  # 做了很多其他事情
    fire_event("click")  # 触发了 click 事件