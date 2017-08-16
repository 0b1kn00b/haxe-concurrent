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
package hx.concurrent.atomic;

/**
 * Value holder with thread-safe accessors.
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
class AtomicValue<T> {

    var _lock:RLock;

    /**
     * <pre><code>
     * >>> new AtomicValue(null).value   == null
     * >>> new AtomicValue(true).value   == true
     * >>> new AtomicValue("cat").value  == "cat"
     * </code></pre>
     */
    public var value(get, never):T;
    var _value:T;
    function get_value():T {
        _lock.acquire();
        var result = _value;
        _lock.release();
        return result;
    }


    public function new(initialValue:T) {
        _lock = new RLock();
        this._value = initialValue;
    }


    /**
     * <pre><code>
     * >>> new AtomicValue("cat").getAndSet("dog") == "cat"
     * </code></pre>
     */
    public function getAndSet(value:T):T {
        _lock.acquire();
        var old = _value;
        _value = value;
        _lock.release();
        return old;
    }


    public function set(value:T):Void {
        _lock.acquire();
        this._value = value;
        _lock.release();
    }


    /**
     * <pre><code>
     * >>> new AtomicValue(true).toString()  == "true"
     * >>> new AtomicValue(false).toString() == "false"
     * </code></pre>
     */
    inline
    public function toString() {
        return Std.string(value);
    }
}
