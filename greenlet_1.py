# coding:utf-8

from time import sleep

# Event Manager

event_listeners = {}

def fire_event(name):
    print "I'm in fire_event"
    event_listeners[name]()
    print '4' + str(event_listeners)

def use_event(func):
    print "I'm in use_event"
    def call(*args, **kwargs):
        print "I'm in call"
        generator = func(*args, **kwargs)
        # 执行到挂起
        event_name = next(generator)
        # 将“唤醒挂起的协程”注册到事件管理器中
        def resume():
            print "I'm in resume"
            try:
                next(generator)
            except StopIteration:
                pass
        event_listeners[event_name] = resume
        print '2' + str(event_listeners)
    return call

# Test

@use_event
def test_work():
    print "I'm in test_work"
    print("=" * 50)
    print("waiting click")
    yield "click"  # 挂起当前协程, 等待事件
    print("clicked !!")

if __name__ == "__main__":
    print '1' + str(event_listeners)
    test_work()
    print '3' + str(event_listeners)
    sleep(3)  # 做了很多其他事情
    fire_event("click")  # 触发了 click 事件
    print '5' + str(event_listeners)