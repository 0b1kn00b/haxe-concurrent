/*
 * Copyright (c) 2017 Vegard IT GmbH, http://vegardit.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package hx.concurrent;

import hx.concurrent.internal.Dates;
import hx.concurrent.ConcurrentException;

/**
 * A re-entrant lock that can only be released by the same thread that acquired it.
 *
 * https://stackoverflow.com/questions/2332765/lock-mutex-semaphore-whats-the-difference
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
class RLock {

    /**
     * Indicates if this class will have any effect on the current target.
     * Currently: CPP, CS, Flash, Java, Neko, Python.
     */
    public static var isSupported(default, never) = #if (cpp||cs||flash||java||neko||python) true #else false #end;

    #if cpp
        var _rlock = new cpp.vm.Mutex();
    #elseif cs
        // nothing to do
    #elseif flash
        // flash.concurrent.Mutex requries swf-version >= 11.4
        // flash.concurrent.Condition requries swf-version >= 11.5
        var cond = new flash.concurrent.Condition(new flash.concurrent.Mutex());
    #elseif java
        var _rlock = new java.util.concurrent.locks.ReentrantLock();
    #elseif neko
        var _rlock = new neko.vm.Mutex();
    #elseif python
        var _rlock = new python.lib.threading.RLock();
    #end


    inline
    public function new() {
    }


    /**
     * Executes the given function while the lock is acquired.
     */
    public function execute<T>(func:Void->T, swallowExceptions:Bool = false):T {
        var ex:ConcurrentException = null;
        var result:T = null;

        acquire();
        try {
            result = func();
        } catch (e:Dynamic) {
            ex = ConcurrentException.capture(e);
        }
        release();

        if (!swallowExceptions && ex != null)
            ex.rethrow();
        return result;
    }


    /**
     * Blocks until lock can be acquired.
     */
    inline
    public function acquire():Void {
        #if cs
            cs.system.threading.Monitor.Enter(this);
        #elseif (cpp||neko||python)
            _rlock.acquire();
        #elseif java
            _rlock.lock();
        #elseif flash
            cond.mutex.lock();
        #else
            // no concurrency support
        #end
    }


    /**
     * By default this call is non-blocking, meaning if the lock cannot be acquired `false` is returned immediately.
     *
     * If <code>timeoutMS</code> is set to value > 0, results in blocking for the given time to aqcuire the lock.
     * If <code>timeoutMS</code> is set to `-1`, results in indefinitely blocking to acquire the lock.
     * If <code>timeoutMS</code> is set to value lower than -1, results in an exception.
     *
     * @return `false` if lock could not be acquired
     */
    public function tryAcquire(timeoutMS:Int = 0):Bool {

        if (timeoutMS < -1) throw "[timeoutMS] must be >= -1";

        if (timeoutMS == -1) {
            acquire();
            return true;
        }

        #if cs
            return cs.system.threading.Monitor.TryEnter(this, timeoutMS);
        #elseif (cpp||neko)
            return Threads.wait(function() return _rlock.tryAcquire(), timeoutMS);
        #elseif java
            return _rlock.tryLock(timeoutMS, java.util.concurrent.TimeUnit.MILLISECONDS);
        #elseif python
            return Threads.wait(function() return _rlock.acquire(false), timeoutMS);
        #elseif flash
            var startAt = Dates.now();
            while (true) {
                if (cond.mutex.tryLock())
                    return true;

                var elapsedMS = Dates.now() - startAt;
                if (elapsedMS >= timeoutMS)
                    return false;

                cond.wait(timeoutMS - elapsedMS);
            }
        #else
            // no concurrency support
            return true;
        #end
    }


    /**
     * Releases the lock.
     *
     * @throws an exception if the lock was not acquired by the current thread
     */
    inline
    public function release():Void {
        #if cs
            cs.system.threading.Monitor.Exit(this);
        #elseif (cpp||neko||python)
            _rlock.release();
        #elseif java
            _rlock.unlock();
        #elseif flash
            cond.notify();
            cond.mutex.unlock();
        #else
            // no concurrency support
        #end
    }
}
