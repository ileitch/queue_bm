require 'rubygems'
require 'atomic'
require 'benchmark'
require 'thread'
$:.unshift('./disruptor/lib')
require 'disruptor'
require './atomic_linked_queue'

$thread_count = 6
$iterations = 1_000

Thread.abort_on_exception = true

# this one tells all the threads when to start
$go = false

def setup(queue)
  tg = ThreadGroup.new

  $thread_count.times do
    t = Thread.new do
      # wait until the bm starts to do the work. This should
      # minimize variance.
      nil until $go
      $iterations.times do
        queue.push(:item)
      end

      $iterations.times do
        queue.pop
      end
    end

    tg.add(t)
  end

  tg
end

def exercise(tg)
  $go = true
  tg.list.each(&:join)
  $go = false
end

Benchmark.bm(50) do |bm|
  queue = Queue.new
  tg = setup(queue)
  bm.report("Queue (stdlib)") { exercise(tg) }

  atomic = AtomicLinkedQueue.new
  tg = setup(atomic)
  bm.report("AtomicLinkedQueue") { exercise(tg) }

  disruptor_spinning = Disruptor::Queue.new(10_000, Disruptor::BusySpinWaitStrategy.new)
  tg = setup(disruptor_spinning)
  bm.report("Disruptor::Queue - BusySpinWaitStrategy") { exercise(tg) }

  disruptor_blocking = Disruptor::Queue.new(10_000, Disruptor::BlockingWaitStrategy.new)
  tg = setup(disruptor_blocking)
  bm.report("Disruptor::Queue - BlockingWaitStrategy") { exercise(tg) }
end
