require_relative "../spec_helper"

begin
  require 'mail'
rescue LoadError
  warn "mail not installed, skipping mail_processor plugin test"  
else
Mail.defaults do
  retriever_method :test
end

describe "mail_processor plugin" do 
  def new_mail
    m = Mail.new(:to=>'a@example.com', :from=>'b@example.com', :cc=>'c@example.com', :bcc=>'d@example.com', :subject=>'Sub', :body=>'Bod')
    yield m if block_given?
    m
  end

  def check
    @processed.clear
    yield
    @processed
  end

  it "supports processing Mail instances via the routing tree using case insensitive address matchers" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.to('a@example.com') do
        r.handle_from(/@example.com/) do
          processed << :to_a1
        end
        r.handle_from(/\A(.+)@example(\d).com\z/i) do |pre, id|
          processed << :to_a2 << pre << id
        end
        r.handle_cc(['d@example.com', 'c@example.com']) do |ad|
          processed << :to_a3 << ad
        end
        r.handle do
          processed << :to_a4
        end
      end
      r.handle_to('e@example.com') do
        processed << :to_e
      end
      r.handle_rcpt('f@example.com') do
        processed << :to_f
      end
    end

    check{app.process_mail(new_mail)}.must_equal [:to_a1]
    check{app.process_mail(new_mail{|m| m.from 'b2@example2.com'})}.must_equal [:to_a2, "b2", "2"]
    check{app.process_mail(new_mail{|m| m.from 'b2@example12.com'})}.must_equal [:to_a3, 'c@example.com']
    check{app.process_mail(new_mail{|m| m.from 'b2@f.com'; m.cc []})}.must_equal [:to_a4]
    check{app.process_mail(new_mail{|m| m.to 'e@example.com'})}.must_equal [:to_e]
    check{app.process_mail(new_mail{|m| m.to 'f@example.com'})}.must_equal [:to_f]
    check{app.process_mail(new_mail{|m| m.to 'foo@example.com'; m.cc 'f@example.com'})}.must_equal [:to_f]

    app.freeze

    check{app.process_mail(new_mail{|m| m.to 'A@example.com'})}.must_equal [:to_a1]
    check{app.process_mail(new_mail{|m| m.from 'b2@Example2.com'})}.must_equal [:to_a2, "b2", "2"]
    check{app.process_mail(new_mail{|m| m.from 'b2@EXAMPLE12.com'})}.must_equal [:to_a3, 'c@example.com']
    check{app.process_mail(new_mail{|m| m.from 'b2@f.COM'; m.cc []})}.must_equal [:to_a4]
    check{app.process_mail(new_mail{|m| m.to 'E@EXAmple.com'})}.must_equal [:to_e]
    check{app.process_mail(new_mail{|m| m.to 'f@exAMPLe.com'})}.must_equal [:to_f]
    check{app.process_mail(new_mail{|m| m.to 'FOo@eXAMPle.com'; m.cc 'f@eXAMPle.com'})}.must_equal [:to_f]
  end

  it "supports processing Mail instances via the routing tree using body and subject matchers" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_subject('Sub') do
        r.handle_body(/XID: (\d+)/) do |xid|
          processed << :sb << xid
        end
        processed << :s1
      end
      r.handle_subject(['Su', 'Si']) do |sub|
        processed << :s2 << sub
      end
      r.subject(/S([ao])/) do |sub|
        r.handle do
          processed << :s3 <<  sub
        end
      end
    end

    check{app.process_mail(new_mail)}.must_equal [:s1]
    check{app.process_mail(new_mail{|m| m.subject 'Si'})}.must_equal [:s2, 'Si']
    check{app.process_mail(new_mail{|m| m.subject 'Sa'})}.must_equal [:s3, 'a']
    check{app.process_mail(new_mail{|m| m.body 'XID: 1234'})}.must_equal [:sb, '1234']
  end

  it "supports processing Mail instances via the routing tree using header matchers" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_header('X-Test') do |v|
        processed << :x1 << v
      end
      r.handle_header('X-Test2', 'Foo') do
        processed << :x2
      end
      r.handle_header('X-Test2', ['Foo', 'Bar']) do |val|
        processed << :x3 << val
      end
      r.header('X-Test2', /(\d+)/) do |i|
        r.handle do
          processed << :x4 << i
        end
      end
      r.handle do
        processed << :f
      end
    end

    check{app.process_mail(new_mail)}.must_equal [:f]
    check{app.process_mail(new_mail{|m| m.header['X-Test'] = 'Foo'})}.must_equal [:x1, 'Foo']
    check{app.process_mail(new_mail{|m| m.header['X-Test2'] = 'Foo'})}.must_equal [:x2]
    check{app.process_mail(new_mail{|m| m.header['X-Test2'] = 'Bar'})}.must_equal [:x3, 'Bar']
    check{app.process_mail(new_mail{|m| m.header['X-Test2'] = 'foo 3'})}.must_equal [:x4, '3']
  end

  it "calls unhandled_mail block for email not handled by a routing block" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.to('a@example.com') do
        processed << :on_to
      end
      processed << :miss
    end
    app.unhandled_mail do
      processed << :uh << mail.to.first
    end
    check{app.process_mail(new_mail)}.must_equal [:on_to, :uh, 'a@example.com']
    check{app.process_mail(new_mail{|m| m.to 'b@example.com'})}.must_equal [:miss, :uh, 'b@example.com']
  end

  it "calls handled_mail block for email handled by a routing block" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_to('a@example.com') do
        processed << :to
      end
    end
    app.handled_mail do
      processed << :h << mail.to.first
    end
    check{app.process_mail(new_mail)}.must_equal [:to, :h, 'a@example.com']
  end

  it "raises by default for unhandled email" do
    @processed = processed = []
    app(:mail_processor) do |r|
      processed << :miss
    end
    proc{app.process_mail(new_mail)}.must_raise Roda::RodaPlugins::MailProcessor::UnhandledMail
    processed.must_equal [:miss]
  end

  it "allows calling unhandled_mail directly, and not calling either implicitly if called directly" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_to('a@example.com') do
        r.handle_from('b@example.com') do
          processed << :quux
        end
        unhandled_mail "bar"
        processed << :foo
      end
      r.to('d@example.com') do
        r.handle do
          processed << :bar
          unhandled_mail "foo"
        end
      end
      r.handle do
        processed << :baz
      end
    end
    app.unhandled_mail do
      processed << :uh
    end
    app.handled_mail do
      processed << :h
    end
    app.after_mail do
      processed << :a
    end
    check{app.process_mail(new_mail)}.must_equal [:quux, :h, :a]
    check{app.process_mail(new_mail{|m| m.from 'c@example.com'})}.must_equal [:uh, :a]
    check{app.process_mail(new_mail{|m| m.to 'd@example.com'})}.must_equal [ :bar, :uh, :a]
    check{app.process_mail(new_mail{|m| m.to 'e@example.com'})}.must_equal [ :baz, :h, :a]
  end

  it "always calls after_mail after processing an email, even if the mail is not handled" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_to('a@example.com') do
        processed << :t
      end
      r.handle_to('b@example.com') do
        raise
      end
    end
    app.unhandled_mail do
      processed << :uh
    end
    app.after_mail do
      processed << :a
    end
    check{app.process_mail(new_mail)}.must_equal [:t, :a]
    check{app.process_mail(new_mail{|m| m.to 'd@example.com'})}.must_equal [:uh, :a]
    check{proc{app.process_mail(new_mail{|m| m.to 'b@example.com'})}.must_raise RuntimeError}.must_equal [:a]
  end

  it "always calls after_mail after processing an email, even if handled_mail or unhandled_mail hooks raise an exception" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_to('a@example.com') do
        processed << :t
      end
    end
    app.handled_mail do
      processed << :h
      raise "foo"
    end
    app.unhandled_mail do
      processed << :uh
      raise "foo"
    end
    app.after_mail do
      processed << :a
    end
    check{proc{app.process_mail(new_mail)}.must_raise RuntimeError}.must_equal [:t, :h, :a]
    check{proc{app.process_mail(new_mail{|m| m.to 'd@example.com'})}.must_raise RuntimeError}.must_equal [:uh, :a]
  end

  it "should raise RodaError for unsupported address and content matchers" do
    app(:mail_processor) do |r|
      r.subject('Sub') do
        r.subject(Object.new) do
        end
      end
      r.subject('Si') do
        r.from(Object.new) do
        end
      end
    end

    proc{app.process_mail(new_mail)}.must_raise Roda::RodaError
    proc{app.process_mail(new_mail{|m| m.subject 'Si'})}.must_raise Roda::RodaError
  end

  it "supports processing retrieved mail from a mailbox via the routing tree" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_to('a@example.com') do
        processed << :to_a
      end
      r.handle_to('c@example.com') do
        processed.concat(mail.to)
      end
    end
    Mail::TestRetriever.emails = [new_mail]
    check{app.process_mailbox}.must_equal [:to_a]
    Mail::TestRetriever.emails = [new_mail{|m| m.to 'c@example.com'}]
    check{app.process_mailbox}.must_equal ['c@example.com']
    Mail::TestRetriever.emails = [new_mail] * 10
    check{app.process_mailbox}.must_equal([:to_a]*10)
    Mail::TestRetriever.emails = Array.new(10){new_mail}
    check{app.process_mailbox(:count=>2)}.must_equal([:to_a]*2)
    check{app.process_mailbox}.must_equal([:to_a]*8)
  end

  it "supports processing retrieved mail from a mailbox with a custom :retreiver" do
    @processed = processed = []
    emails = []
    retriever = Class.new(Mail::Retriever) do
      define_method(:find) do |opts={}, &block|
        es = emails.dup
        emails.clear
        es.each(&block) if block
        es
      end
    end.new
    app(:mail_processor) do |r|
      r.handle_to('a@example.com') do
        processed << :to_a
      end
    end
    emails << new_mail
    check{app.process_mailbox}.must_equal []
    emails.wont_be_empty
    check{app.process_mailbox(:retriever=>retriever)}.must_equal [:to_a]
    emails.must_be_empty
    check{app.process_mailbox(:retriever=>retriever)}.must_equal []
  end

  it "supports rcpt class method to delegate to blocks by recipient address, falling back to main routing block" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle do
        processed << :f
      end
    end
    app.rcpt('a@example.com') do |r|
      r.handle do
        processed << :a
      end
    end
    app.rcpt(/(.*[bcd])@example.com/, /(.*[bcd]2)@example.com/) do |r, x|
      r.handle do
        processed << :bcd << x
      end
    end
    app.rcpt(/([cde])@example.com(.*)/i) do |r, x, y|
      r.handle do
        processed << :cde << x << y
      end
    end
    app.rcpt('B@EXAMPLE.com', 'c@example.com') do |r|
      r.handle do
        processed << :bc
      end
    end
    app.rcpt('x@example.com') do |r|
      processed << :x
    end
    proc{app.rcpt(Object.new){}}.must_raise Roda::RodaError

    check{app.process_mail(new_mail)}.must_equal [:a]

    app.freeze

    check{app.process_mail(new_mail{|m| m.to 'b@example.com'})}.must_equal [:bc]
    check{app.process_mail(new_mail{|m| m.to 'C@example.com'; m.cc 'a@example.com'})}.must_equal [:bc]
    check{app.process_mail(new_mail{|m| m.to 'd@example.com'; m.cc 'a@example.com'})}.must_equal [:a]
    check{app.process_mail(new_mail{|m| m.to 'd@example.com'; m.cc []})}.must_equal [:bcd, 'd']
    check{app.process_mail(new_mail{|m| m.to '123d@example.com123'; m.cc []})}.must_equal [:bcd, '123d']
    check{app.process_mail(new_mail{|m| m.to 'd2@example.com'; m.cc []})}.must_equal [:bcd, 'd2']
    check{app.process_mail(new_mail{|m| m.to '123d2@example.com123'; m.cc []})}.must_equal [:bcd, '123d2']
    check{app.process_mail(new_mail{|m| m.to 'e@example.com'; m.cc []})}.must_equal [:cde, 'e', '']
    check{app.process_mail(new_mail{|m| m.to '123e@example.com123'; m.cc []})}.must_equal [:cde, 'e', '123']
    check{proc{app.process_mail(new_mail{|m| m.to 'x@example.com'})}.must_raise Roda::RodaPlugins::MailProcessor::UnhandledMail}.must_equal [:x]
  end

  it "supports mail_recipients class method to set recipients of mail, respected by rcpt methods" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_rcpt('a@example.com') do
        processed << :a
      end
      r.handle do
        processed << :f
      end
    end
    app.rcpt('b@example.com') do |r|
      r.handle do
        processed << :b
      end
    end
    check{app.process_mail(new_mail)}.must_equal [:a]
    check{app.process_mail(new_mail{|m| m.to 'b@example.com'})}.must_equal [:b]
    check{app.process_mail(new_mail{|m| m.to 'e@example.com'})}.must_equal [:f]

    app.mail_recipients do
      if smtp_rcpt = header['X-SMTP-To']
        smtp_rcpt = smtp_rcpt.decoded
      end
      Array(smtp_rcpt)
    end
    check{app.process_mail(new_mail)}.must_equal [:f]
    check{app.process_mail(new_mail{|m| m.header['X-SMTP-To'] = 'a@example.com'})}.must_equal [:a]
    check{app.process_mail(new_mail{|m| m.header['X-SMTP-To'] = 'b@example.com'})}.must_equal [:b]
  end

  it "supports #mail_text, .mail_text, and r.text for allowing the ability to extract text from mails" do
    @processed = processed = []
    app(:mail_processor) do |r|
      r.handle_text(/Found (foo|bar)/) do |x|
        processed << :f << x
      end
      r.text(/Found (baz|quux)/) do |x|
        r.handle do
          processed << :f2 << x << mail_text
        end
      end
      r.handle do
        processed << :nf << mail_text
      end
    end
    check{app.process_mail(new_mail)}.must_equal [:nf, 'Bod']
    check{app.process_mail(new_mail{|m| m.body "Found bar\n--\nFound foo"})}.must_equal [:f, 'bar']
    check{app.process_mail(new_mail{|m| m.body "> Found baz\nFound quux"})}.must_equal [:f2, 'baz', "> Found baz\nFound quux"]
    @app.mail_text do
      text = mail.body.decoded.gsub(/^>[^\r\n]*\r?\n/m, '')
      text.split(/\r?\n--\r?\n/).last
    end
    check{app.process_mail(new_mail)}.must_equal [:nf, 'Bod']
    check{app.process_mail(new_mail{|m| m.body "Found bar\n--\nFound foo"})}.must_equal [:f, 'foo']
    check{app.process_mail(new_mail{|m| m.body "> Found baz\nFound quux"})}.must_equal [:f2, 'quux', "Found quux"]
  end

  it "works with route_block_args plugin" do
    @processed = processed = []
    app(:bare) do
      plugin :mail_processor
      plugin :route_block_args do
        [to, from]
      end
      route do |t, f|
        request.handle do
          processed << t << f
        end
      end
      handled_mail do
#      processed << :h << mail.to.first
      end
    end
    check{app.process_mail(new_mail)}.must_equal [["a@example.com"], ["b@example.com"]]
  end

  it "works with hooks plugin, calling after hook before *_mail hooks" do
    @processed = processed = []
    app(:bare) do
      plugin :mail_processor
      plugin :hooks
      before do 
        processed << 1
      end
      after do |_|
        processed << 2
      end
      route do |r|
        processed << 3
        r.handle_to('a@example.com') do
        end
      end
      handled_mail do
        processed << 4
      end
      unhandled_mail do
        processed << 5
      end
      after_mail do
        processed << 6
      end
    end
    check{app.process_mail(new_mail)}.must_equal [1, 3, 2, 4, 6]
    check{app.process_mail(new_mail{|m| m.to 'x@example.com'})}.must_equal [1, 3, 2, 5, 6]
  end
end
end
