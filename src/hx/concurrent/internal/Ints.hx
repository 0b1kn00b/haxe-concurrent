/*
 * Copyright (c) 2016-2020 Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 */
package hx.concurrent.internal;

/**
 * <b>IMPORTANT:</b> This class it not part of the API. Direct usage is discouraged.
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
@:noDoc @:dox(hide)
class Ints {

   /**
    * Maximum value Int type can hold depending on target platform
    * <pre><code>
    * >>> Ints.MAX_VALUE > 0
    * </code></pre>
    */
   public static var MAX_VALUE(default, never):Int = {
      #if cs
         untyped __cs__("int.MaxValue");
      #elseif flash
         untyped __global__["int"].MAX_VALUE;
      #elseif java
         java.lang.Integer.MAX_VALUE;
      #elseif nodejs
         untyped __js__("Number.MAX_SAFE_INTEGER");
      #elseif php
         untyped __php__("PHP_INT_MAX");
      #elseif python
         python.Syntax.code("import sys");
         Std.int(python.Syntax.code("sys.maxsize"));
      #elseif eval
         2147483647;
      #else // neko, cpp, lua, js, etc.
         Std.int(Math.pow(2,31)-1);
      #end
   }


   /**
    * Maximum negative value Int type can hold depending on target platform
    * <pre><code>
    * >>> Ints.MIN_VALUE < 0
    * </code></pre>
    */
   public static var MIN_VALUE(default, never):Int = {
      #if cs
         untyped __cs__("int.MinValue");
      #elseif flash
         untyped __global__["int"].MIN_VALUE;
      #elseif java_src
         java.lang.Integer.MIN_VALUE;
      #elseif nodejs
         untyped __js__("Number.MIN_SAFE_INTEGER");
      #elseif php
         untyped __php__("PHP_INT_MIN");
      #elseif python
         python.Syntax.code("import sys");
         -Std.int(python.Syntax.code("sys.maxsize")) - 1;
      #elseif eval
         -2147483648;
      #else // neko, cpp, lua, js, etc.
         -Std.int(Math.pow(2,31));
      #end
   }
}
