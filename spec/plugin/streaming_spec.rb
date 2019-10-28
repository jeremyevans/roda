require_relative "../spec_helper"

describe "streaming plugin" do 
  it "adds stream method for streaming responses" do
    app(:streaming) do |r|
      stream do |out|
        %w'a b c'.each do |v|
          (out << v).must_equal out
          out.write(v).must_equal 1
        end
      end
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    b.to_a.must_equal %w'a a b b c c'
  end

  it "works with IO.copy_stream" do
    app(:streaming) do |r|
      stream do |out|
        %w'a b c'.each{|v| IO.copy_stream(StringIO.new(v), out) }
      end
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    # dup as copy_stream reuses the buffer
    b.map(&:dup).must_equal %w'a b c'
  end

  it "should handle errors when streaming, and run callbacks" do
    a = []
    app(:streaming) do |r|
      stream(:callback=>proc{a << 'e'}) do |out|
        %w'a b'.each{|v| out << v}
        raise Roda::RodaError, 'foo'
        out << 'c'
      end
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    proc{b.each{|v| a << v}}.must_raise(Roda::RodaError)
    a.must_equal %w'a b e'
  end

  it "should handle :loop option to loop" do
    a = []
    app(:streaming) do |r|
      b = %w'a b c'
      stream(:loop=>true, :callback=>proc{a << 'e'}) do |out|
        out << b.shift
        raise Roda::RodaError, 'foo' if b.length == 1
      end
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    proc{b.each{|v| a << v}}.must_raise(Roda::RodaError)
    a.must_equal %w'a b e'
  end

  it "uses handle_stream_error for handling errors when streaming" do
    a = []
    app(:streaming) do |r|
      b = %w'a b c'
      stream(:loop=>true, :callback=>proc{a << 'e'}) do |out|
        out << b.shift
        raise Roda::RodaError, 'foo' if b.length == 1
      end
    end

    app.send(:define_method, :handle_stream_error) do |error, out|
      out << '1'
      raise error
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    proc{b.each{|v| a << v}}.must_raise(Roda::RodaError)
    a.must_equal %w'a b 1 e'
  end

  it "should allow closing the stream when handling an error" do
    a = []
    app(:streaming) do |r|
      b = %w'a b c'
      stream(:loop=>true, :callback=>proc{a << 'e'}) do |out|
        out << b.shift
        raise Roda::RodaError, 'foo' if b.length == 1
      end
    end

    app.send(:define_method, :handle_stream_error) do |error, out|
      out.close
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    b.each{|v| a << v}
    a.must_equal %w'a b e'
  end

  it "should allow ignoring errors when streaming" do
    a = []
    b2 = %w'a b c'

    app(:streaming) do |r|
      stream(:loop=>true, :callback=>proc{a << 'e'}) do |out|
        out << b2.shift
        raise Roda::RodaError
      end
    end

    app.send(:define_method, :handle_stream_error) do |error, out|
      out << '1'
      out.close if b2.empty?
    end

    s, h, b = req
    s.must_equal 200
    h.must_equal('Content-Type'=>'text/html')
    b.each{|v| a << v}
    a.must_equal %w'a 1 b 1 c 1 e'
  end

  describe "with :async" do
    it "should stream in a thread" do
      main_thread = Thread.current
      minitest = self
      app(:streaming) do |r|
        stream(:async=>true) do |out|
          minitest.refute_equal Thread.current, main_thread
          %w'a b c'.each do |v|
            out << v
          end
        end
      end

      s, h, b = req
      s.must_equal 200
      h.must_equal('Content-Type'=>'text/html')
      b.to_a.must_equal %w'a b c'
    end

    it "should propagate exceptions" do
      app(:streaming) do |r|
        stream(:async=>true) do |out|
          Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
          %w'a b'.each{|v| out << v}
          raise Roda::RodaError, 'foo'
          out << 'c'
        end
      end

      s, h, b = req
      s.must_equal 200
      h.must_equal('Content-Type'=>'text/html')
      a = []
      proc{b.each{|v| a << v}}.must_raise(Roda::RodaError)
      a.must_equal %w'a b'
    end

    it "should terminate the thread on close" do
      q = Queue.new
      app(:streaming) do |r|
        stream(:async=>true) do |out|
          %w'a b c d e f g h i j'.each{|v| out << v}
          q.deq
          out << 'k'
        end
      end

      *, b = req
      e = b.enum_for(:each)
      10.times{e.next}
      b.close
      q.enq 'x'
      proc{e.next}.must_raise(StopIteration)
    end

    it "should still run callbacks on close" do
      callback = false
      app(:streaming) do |r|
        stream(:async=>true, :callback=>proc{callback = true}) do |out|
          %w'a b c'.each{|v| out << v}
        end
      end

      *, b = req
      b.close
      callback.must_equal true
    end

    it "should apply backpressure by default" do
      q = Queue.new
      a = []
      app(:streaming) do |r|
        stream(:async=>true) do |out|
          %w'a b c d e f g h i j'.each do |v|
            out << v
            a << v
          end

          q.enq 'x'

          out << 'k'
          a << 'k'
        end
      end

      *, b = req
      q.deq
      a.must_equal %w'a b c d e f g h i j'
      b.to_a # drain the queue
    end

    it "should handle :queue option to override queue" do
      q = Queue.new
      a = []
      app(:streaming) do |r|
        stream(:async=>true, queue: SizedQueue.new(5)) do |out|
          %w'a b c d e'.each do |v|
            out << v
            a << v
          end

          q.enq 'x'

          out << 'f'
          a << 'f'
        end
      end

      *, b = req
      q.deq
      a.must_equal %w'a b c d e'
      b.to_a # drain the queue
    end
  end
end
