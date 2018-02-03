/*
 * Copyright (c) 2016-2017 Vegard IT GmbH, http://vegardit.com
 * SPDX-License-Identifier: Apache-2.0
 */
package hx.concurrent;

import hx.concurrent.Service.ServiceState;
import hx.concurrent.atomic.AtomicBool;
import hx.concurrent.atomic.AtomicInt;
import hx.concurrent.collection.Queue;
import hx.concurrent.event.AsyncEventDispatcher;
import hx.concurrent.event.EventDispatcherWithHistory;
import hx.concurrent.event.SyncEventDispatcher;
import hx.concurrent.executor.Executor;
import hx.concurrent.executor.Schedule;
import hx.concurrent.internal.Dates;
import hx.concurrent.lock.RLock;
import hx.concurrent.lock.Semaphore;
import hx.concurrent.thread.ThreadPool;
import hx.concurrent.thread.Threads;

/**
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
@:build(hx.doctest.DocTestGenerator.generateDocTests("src", ".*\\.hx"))
class TestRunner extends hx.doctest.DocTestRunner {

    #if threads
    @:keep
    static var __static_init = {
        /*
         * synchronize trace calls
         */
        var sync = new RLock();
        var old = haxe.Log.trace;
        haxe.Log.trace = function(v:Dynamic, ?pos: haxe.PosInfos ):Void {
            sync.execute(function() old(v, pos));
        }
    }
    #end


    public static function main() {
        var runner = new TestRunner();
        runner.runAndExit();
    }

    function testAtomicInt() {
        var val:Int = -1;

        var atomic = new AtomicInt(1);
        val = atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 1);

        atomic = new AtomicInt(1);
        val = atomic++;
        assertEquals(atomic.value, 2);
        assertEquals(val, 1);

        atomic = new AtomicInt(1);
        val = ++atomic;
        assertEquals(atomic.value, 2);
        assertEquals(val, 2);

        atomic = new AtomicInt(1);
        val = atomic--;
        assertEquals(atomic.value, 0);
        assertEquals(val, 1);

        atomic = new AtomicInt(1);
        val = --atomic;
        assertEquals(atomic.value, 0);
        assertEquals(val, 0);

        atomic = new AtomicInt(1);
        val = -atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, -1);

        atomic = new AtomicInt(1);
        val = atomic + 1;
        assertEquals(atomic.value, 1);
        assertEquals(val, 2);

        atomic = new AtomicInt(1);
        val = atomic + atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 2);

        atomic = new AtomicInt(1);
        val = 1 + atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 2);

        atomic = new AtomicInt(1);
        val = 1;
        val += atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 2);

        atomic = new AtomicInt(1);
        val = atomic - 1;
        assertEquals(atomic.value, 1);
        assertEquals(val, 0);

        atomic = new AtomicInt(1);
        val = atomic - atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 0);

        atomic = new AtomicInt(1);
        val = 1 - atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 0);

        atomic = new AtomicInt(1);
        val = 1;
        val -= atomic;
        assertEquals(atomic.value, 1);
        assertEquals(val, 0);

        atomic = new AtomicInt(0);
        assertEquals(atomic++, 0);
        assertEquals(++atomic, 2);
        atomic += 10;
        assertEquals(atomic.value, 12);
        atomic -= 10;
        assertEquals(atomic.value, 2);
        assertEquals(atomic--, 2);
        assertEquals(--atomic, 0);
    }


    function testConstantFuture() {
        var future = new Future.ConstantFuture(10);
        switch(future.result) {
            case SUCCESS(10, _):
            default: fail();
        }
        var flag = false;
        future.onResult = function(result:Future.FutureResult<Int>) flag = true;
        assertEquals(flag, true);
    }


    function testQueue() {
        var q = new Queue<Int>();
        assertEquals(null, q.pop());
        q.push(1);
        q.push(2);
        q.pushHead(3);
        assertEquals(3, q.pop());
        assertEquals(1, q.pop());
        assertEquals(2, q.pop());

        #if threads
        var q = new Queue<Int>();
        Threads.spawn(function() {
            Threads.sleep(1000);
            q.push(123);
            Threads.sleep(1000);
            q.push(456);
        });
        Threads.sleep(100);
        assertEquals(null, q.pop());
        assertEquals(null, q.pop(100));
        assertEquals(123,  q.pop(1500));
        assertEquals(null, q.pop());
        assertEquals(456,  q.pop(-1));
        assertEquals(null, q.pop());
        #end
    }


    function testScheduleTools() {
        var now = Dates.now();
        var in2sDate = Date.fromTime(now + 2000);
        var runInMS = ScheduleTools.firstRunAt(HOURLY(in2sDate.getMinutes(), in2sDate.getSeconds())) - now;
        assertTrue(runInMS > 1000);
        assertTrue(runInMS < 3000);
        var runInMS = ScheduleTools.firstRunAt(DAILY(in2sDate.getHours(), in2sDate.getMinutes(), in2sDate.getSeconds())) - now;
        assertTrue(runInMS > 1000);
        assertTrue(runInMS < 3000);
        var runInMS = ScheduleTools.firstRunAt(WEEKLY(in2sDate.getDay(), in2sDate.getHours(), in2sDate.getMinutes(), in2sDate.getSeconds())) - now;
        assertTrue(runInMS > 1000);
        assertTrue(runInMS < 3000);
    }


    function testRLock() {
        var lock = new RLock();

        #if threads
        Threads.spawn(function() {
            lock.acquire();
            Threads.sleep(2000);
            lock.release();
        });
        Threads.sleep(100);
        assertEquals(false, lock.tryAcquire(100));
        assertEquals(true,  lock.tryAcquire(3000));
        #end

        var flag = new AtomicBool(false);
        lock.acquire();
        // test lock re-entrance
        assertTrue(lock.execute(function():Bool { flag.value = true; return true; } ));
        assertTrue(flag.value);
        lock.release();

    }

    function testSemaphore() {
        var sem = new Semaphore(2);

        assertEquals(2, sem.availablePermits);

        assertEquals(true, sem.tryAcquire());
        assertEquals(true, sem.tryAcquire());
        assertEquals(0, sem.availablePermits);
        assertEquals(false, sem.tryAcquire());
        sem.release();
        assertEquals(true, sem.tryAcquire());
        sem.release();
        sem.release();
        sem.release();
        assertEquals(3, sem.availablePermits);
    }

    #if threads
    function testThreads() {
        var i = new AtomicInt(0);
        for (j in 0...10)
            Threads.spawn(function() i.increment());
        assertTrue(Threads.wait(function() { return i.value == 10; }, 200));
    }

    function testThreadPool() {
        var pool = new ThreadPool(2);
        var ids = [-1, -1];
        for (j in 0...2)
            pool.submit(function(ctx:ThreadContext) {
                Threads.sleep(50);
                ids[j] = ctx.id;
            });
        assertTrue(Threads.wait(function() { return ids[0] != -1 && ids[1] != -1; }, 200));
        pool.stop();
        assertNotEquals(ids[0], ids[1]);
    }
    #end


    function testEventDispatcher_Async() {
        var executor = Executor.create(2);
        var disp = new AsyncEventDispatcher(executor);

        var listener1Count = new AtomicInt();
        var listener1 = function(event:String) {
            listener1Count.incrementAndGet();
        }

        assertTrue(disp.subscribe(listener1));
        #if !(hl)
        assertFalse(disp.subscribe(listener1));
        #end

        var fut1 = disp.fire("123");
        var fut2 = disp.fire("1234567890");

        _later(100, function() {
            executor.stop();
            assertEquals(2, listener1Count.value);
            switch(fut1.result) {
                case SUCCESS(v,_): assertEquals(1, v);
                default: fail();
            }
            switch(fut2.result) {
                case SUCCESS(v,_): assertEquals(1, v);
                default: fail();
            }
        });

    }


    function testEventDispatcher_WithHistory() {
        var disp = new EventDispatcherWithHistory<String>(new SyncEventDispatcher<String>());

        switch(disp.fire("123").result) {
            case SUCCESS(v,_): assertEquals(0, v);
            default: fail();
        }
        switch(disp.fire("1234567890").result) {
            case SUCCESS(v,_): assertEquals(0, v);
            default: fail();
        }

        var listener1Count = new AtomicInt();
        var listener1 = function(event:String) {
            listener1Count.incrementAndGet();
        }
        assertTrue(disp.subscribeAndReplayHistory(listener1));
        #if !(hl)
        assertFalse(disp.subscribeAndReplayHistory(listener1));
        assertEquals(2, listener1Count.value);
        #end
    }


    function testEventDispatcher_Sync() {
        var disp = new SyncEventDispatcher<String>();

        var listener1Count = new AtomicInt();
        var listener1 = function(event:String) {
            listener1Count.incrementAndGet();
        }

        assertTrue(disp.subscribe(listener1));
        #if !(hl)
        assertFalse(disp.subscribe(listener1));
        #end

        switch(disp.fire("123").result) {
            case SUCCESS(v,_): assertEquals(1, v);
            default: fail();
        }
        assertEquals(1, listener1Count.value);
    }


    function testTaskExecutor_shutdown() {
        var executor = Executor.create(2);
        assertEquals(executor.state, ServiceState.RUNNING);
        executor.stop();
        _later(200, function() {
            assertEquals(executor.state, ServiceState.STOPPED);
        });
    }


    function testTaskExecutor_shutdown_with_running_tasks() {
        var executor = Executor.create(3);
        var counter = new AtomicInt(0);
        var future = executor.submit(function() counter++, FIXED_RATE(20));
        var startAt = Dates.now();
        _later(200, function() {
            var v = counter.value;
            assertFalse(future.isStopped);
            assertTrue(v >= 10 * 0.4);
            assertTrue(v <= 10 * 1.4);
        });
        _later(220, function() {
            executor.stop();
        });
        _later(400, function() {
            assertTrue(future.isStopped);
            assertEquals(executor.state, ServiceState.STOPPED);
        });
    }


    function testTaskExecutor_schedule_ONCE() {
        var executor = Executor.create(3);

        var flag1 = new AtomicBool(false);
        var flag2 = new AtomicBool(false);
        var flag3 = new AtomicBool(false);
        var startAt = Dates.now();
        var future1 = executor.submit(function():Void flag1.negate(), ONCE(0));
        var future2 = executor.submit(function():Void flag2.negate(), ONCE(100));
        var future3 = executor.submit(function():Void flag3.negate(), ONCE(100));
        _later(40, function() {
            assertTrue(flag1.value);
            assertTrue(future1.isStopped);

            assertFalse(flag2.value);
            assertFalse(future2.isStopped);

            assertFalse(flag3.value);
            assertFalse(future3.isStopped);
            future3.cancel();
            assertFalse(flag3.value);
            assertTrue(future3.isStopped);
        });
        _later(120, function() {
            assertTrue(flag2.value);
            assertTrue(future2.isStopped);

            assertFalse(flag3.value);
            assertTrue(future3.isStopped);

            executor.stop();
        });
    }

    function testTaskExecutor_schedule_RATE_DELAY() {
        var executor = Executor.create(2);

        var intervalMS = 20;
        var threadMS = 10;

        var fixedRateCounter  = new AtomicInt(0);
        var future1 = executor.submit(function() {
            fixedRateCounter.increment();
            #if threads
            Threads.sleep(threadMS);
            #end
        }, FIXED_RATE(intervalMS));
        var v1 = new AtomicInt(0);

        #if threads
        var fixedDelayCounter = new AtomicInt(0);
        var future2 = executor.submit(function() {
            fixedDelayCounter.increment();
            Threads.sleep(threadMS);
        }, FIXED_DELAY(intervalMS));
        var v2 = new AtomicInt(0);
        #end

        var waitMS = intervalMS * 10;
        _later(waitMS, function() {
            future1.cancel();
            v1.value = fixedRateCounter.value;
            assertTrue(v1.value <= (waitMS / intervalMS) * 1.6);
            assertTrue(v1.value >= (waitMS / intervalMS) * 0.4);

            #if threads
            future2.cancel();
            v2.value = fixedDelayCounter.value;
            assertTrue(v2.value <= (waitMS / (intervalMS + threadMS)) * 1.6);
            assertTrue(v2.value >= (waitMS / (intervalMS + threadMS)) * 0.4);
            assertTrue(v1 > v2);
            #end
        });
        _later(waitMS + 2 * intervalMS, function() {
            assertEquals(v1.value, fixedRateCounter.value);
            #if threads
            assertEquals(v2.value, fixedDelayCounter.value);
            #end

            executor.stop();
        });
    }


    function testTaskExecutor_schedule_HOURLY_DAILY_WEEKLY() {
        var executor = Executor.create(3);

        var hourlyCounter  = new AtomicInt(0);
        var dailyCounter  = new AtomicInt(0);
        var weeklyCounter  = new AtomicInt(0);
        var d = Date.fromTime(Dates.now() + 2000);
        var future1 = executor.submit(function() hourlyCounter.increment(), HOURLY(d.getMinutes(), d.getSeconds()));
        var future2 = executor.submit(function() dailyCounter.increment(),  DAILY(d.getHours(), d.getMinutes(), d.getSeconds()));
        var future3 = executor.submit(function() weeklyCounter.increment(), WEEKLY(d.getDay(), d.getHours(), d.getMinutes(), d.getSeconds()));
        assertEquals(hourlyCounter.value, 0);
        assertEquals(dailyCounter.value, 0);
        assertEquals(weeklyCounter.value, 0);
        _later(2500, function() {
            assertEquals(hourlyCounter.value, 1);
            assertEquals(dailyCounter.value, 1);
            assertEquals(weeklyCounter.value, 1);
            assertFalse(future1.isStopped);
            assertFalse(future2.isStopped);
            assertFalse(future3.isStopped);

            executor.stop();
        });

        _later(2600, function() {
            assertTrue(future1.isStopped);
            assertTrue(future2.isStopped);
            assertTrue(future3.isStopped);
        });
    }


    var _asyncExecutor = Executor.create(10);
    var _asyncTests = new AtomicInt(0);
    function _later(delayMS:Int, fn:Void->Void) {
        _asyncTests++;
        var future:TaskFuture<Dynamic> = _asyncExecutor.submit(function() {
            fn();
            _asyncTests--;
        }, ONCE(delayMS));
    }

    override
    function runAndExit(expectedMinNumberOfTests = 0):Void {
        results = new ThreadSafeDocTestResults();
        var startTime = Dates.now();
        run(expectedMinNumberOfTests, false);

        var t = new haxe.Timer(100);
        t.run = function() {
            if(_asyncTests.value == 0) {
                t.stop();
                var timeSpent = Std.int((Dates.now() - startTime) / 1000);

                if (results.getSuccessCount() + results.getFailureCount() == 0) {
                    // no tests defined, DocTestRunner will display warning
                } else if (results.getFailureCount() == 0) {
                    hx.doctest.internal.Logger.log(INFO, '**********************************************************');
                    hx.doctest.internal.Logger.log(INFO, 'All ${results.getSuccessCount()} test(s) were SUCCESSFUL within $timeSpent seconds.');
                    hx.doctest.internal.Logger.log(INFO, '**********************************************************');
                } else {
                    hx.doctest.internal.Logger.log(ERROR, '**********************************************************');
                    hx.doctest.internal.Logger.log(ERROR, '${results.getFailureCount()} of ${results.getSuccessCount() + results.getFailureCount()} test(s) FAILED:');
                    results.logFailures();
                }

                var exitCode = results.getFailureCount() == 0 ? 0 : 1;
                #if travix
                    travix.Logger.exit(exitCode);
                #else
                    #if sys
                        Sys.exit(exitCode);
                    #elseif js
                        var isPhantomJS = untyped __js__("(typeof phantom !== 'undefined')");
                        if(isPhantomJS) {
                            untyped __js__("phantom.exit(exitCode)");
                        } else {
                            untyped __js__("process.exit(exitCode)");
                        }
                    #elseif flash
                        flash.system.System.exit(exitCode);
                    #end
                #end
            }
        };
    }
}

private class ThreadSafeDocTestResults extends hx.doctest.DocTestRunner.DefaultDocTestResults {

    var _sync = new RLock();

    function super_add(success:Bool, msg:String, loc:hx.doctest.internal.Logger.SourceLocation, pos:haxe.PosInfos) {
        super.add(success, msg, loc, pos);
    }
    function super_logFailures() {
        super.logFailures();
    }

    override
    public function add(success:Bool, msg:String, loc:hx.doctest.internal.Logger.SourceLocation, pos:haxe.PosInfos) {
        _sync.execute(function() super_add(success, msg, loc, pos));
    }

    override
    public function getSuccessCount():Int {
        return _sync.execute(function() return _testsOK);
    }

    override
    public function getFailureCount():Int {
        return _sync.execute(function() return _testsFailed.length);
    }

    override
    public function logFailures():Void {
        return _sync.execute(function() super_logFailures());
    }
}
