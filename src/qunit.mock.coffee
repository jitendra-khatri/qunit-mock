# Copyright (c) 2010 Bitzesty
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

mocking = null
stack = []

class Expectation
  
  constructor : (args)->
    for i, arg of args
      @[i] = arg
    
    @calledWith = []

  isCallback : () ->
    @object == undefined

  with : (args...)->
    @expectedArgs = args
    @

  calls : (calls)->
    @expectedCalls = calls
    @

  undo : ()->
    if @object?
      @object[@method] = @originalMethod


expectCall = (object, method, calls) ->
  calls ?= 1

  expectation = new Expectation({
    expectedCalls: calls
    callCount: 0
  })

  mock = (args...) ->
    if expectation.originalMethod
      expectation.originalMethod.apply(object, args)
    expectation.callCount += 1
    expectation.calledWith.push(args)

  mocking.expectations.push(expectation)
  
  if method != undefined
    expectation.originalMethod = object[method]
    expectation.object =  object
    expectation.method = method
    object[method] = mock
    return expectation
  else
    expectation.calls(object||1)

  mock

stub = (object, method, fn) ->
  if typeof fn != 'function'
    retur = fn;
    fn = () -> retur
    

  stb = {
    object: object,
    method: method,
    original: object[method]
  }
  
  object[method] = fn
  
  mocking.stubs.push stb
  stb

mock = (test) ->
  mk = {
    expectations: []
    stubs: []
  }
  
  mocking = mk
  stack.push(mk)
  
  test.call(this)
  
  unless QUnit.config.blocking
    finishMock()
  else
    QUnit.config.queue.unshift finishMock

mocked = (fn) ->
  -> mock.call(this, fn)

finishMock = () ->
  testExpectations()

  stack.pop()
  mocking = if stack.length > 0 then stack[stack.length - 1] else null

testExpectations = ->
  while mocking.expectations.length > 0
    expectation = mocking.expectations.pop()

    if expectation.isCallback()
      equal(expectation.callCount, expectation.expectedCalls, "callback should have been called #{expectation.expectedCalls} times")
    else
      equal(expectation.callCount, expectation.expectedCalls, "method #{expectation.method} should be called #{expectation.expectedCalls} times")
      expectation.undo();

    if expectation.expectedArgs
      for i, el of expectation.calledWith
        deepEqual(expectation.expectedArgs, el, "expected to be called with #{expectation.expectedArgs}, called with #{el}")
      

  while mocking.stubs.length > 0
    stb = mocking.stubs.pop()
    stb.object[stb.method] = stb.original

window.expectCall = expectCall
window.stub = stub
window.mock = mock
window.QUnitMock = {
  mocking: mocking,
  stack: stack
}

window.test = (args...) ->
  for arg, i in args
    args[i] = mocked(arg) if typeof arg == 'function'
  
  QUnit.test.apply(this, args)
  
window.asyncTest = (testName, expected, callback) ->
  if arguments.length == 2
    callback = expected
    expected = 0
  
  QUnit.test(testName, expected, mocked(callback), true)
