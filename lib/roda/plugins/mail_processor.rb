# frozen-string-literal: true

require 'mail'

class Roda
  module RodaPlugins
    # The mail_processor plugin allows your Roda application to process mail
    # using a routing tree. Quick example:
    #
    #   class MailProcessor < Roda
    #     plugin :mail_processor
    #
    #     route do |r|
    #       # Match based on the To header, extracting the ticket_id
    #       r.to /ticket\+(\d+)@example.com/ do |ticket_id|
    #         if ticket = Ticket[ticket_id.to_i]
    #           # Mark the mail as handled if there is a valid ticket associated
    #           r.handle do
    #             ticket.add_note(text: mail_text, from: from)
    #           end
    #         end
    #       end
    #
    #       # Match based on the To or CC header
    #       r.rcpt "post@example.com" do
    #         # Match based on the body, capturing the post id and tag
    #         r.body(/^Post: (\d+)-(\w+)/) do |post_id, tag|
    #           unhandled_mail("no matching post") unless post = Post[post_id.to_i]
    #           unhandled_mail("tag doesn't match for post") unless post.tag == tag
    #
    #           # Match based on APPROVE somewhere in the mail text,
    #           # marking the mail as handled
    #           r.handle_text /\bAPPROVE\b/i do
    #             post.approve!(from)
    #           end
    #
    #           # Match based on DENY somewhere in the mail text,
    #           # marking the mail as handled
    #           r.handle_text /\bDENY\b/i do
    #             post.deny!(from)
    #           end
    #         end
    #       end
    #     end
    #   end
    #
    # = Processing Mail
    #
    # To submit a mail for processing via the mail_processor routing tree, call the +process_mail+
    # method with a +Mail+ instance:
    #
    #   MailProcessor.process_mail(Mail.new do
    #     # ...
    #   end)
    #
    # You can use this to process mail messages from the filesystem:
    #
    #   MailProcessor.process_mail(Mail.read('/path/to/message.eml'))
    #
    # If you have a service that delivers mail via an HTTP POST request (for realtime
    # processing), you can have your web routes convert the web request into a +Mail+ instance
    # and then call +process_mail+:
    #
    #   r.post "email" do
    #     # check request is submitted by trusted sender
    #
    #     # If request body is the raw mail body
    #     r.body.rewind
    #     MailProcessor.process_mail(Mail.new(r.body.read))
    #
    #     # If request body is in a parameter named content
    #     MailProcessor.process_mail(Mail.new(r.params['content']))
    #
    #     # If the HTTP request requires a specific response status code (such as 204)
    #     response.status = 204
    #
    #     nil
    #   end
    #
    # Note that when receiving messages via HTTP, you need to make sure you check that the
    # request is trusted.  How to do this depends on the delivery service, but could involve
    # using HTTP basic authentication, checking for valid API tokens, or checking that a message
    # includes a signature/hash that matches the expected value.
    #
    # If you have setup a default retriever_method for +Mail+, you can call +process_mailbox+,
    # which will process all mail in the given mailbox (using +Mail.find_and_delete+):
    #
    #   MailProcessor.process_mailbox
    #
    # You can also use a +:retreiver+ option to provide a specific retriever:
    #
    #   MailProcessor.process_mailbox(retreiver: Mail::POP3.new)
    #
    # = Routing Mail
    #
    # The mail_processor plugin handles routing similar to Roda's default routing for
    # web requests, but because mail processing may not return a result, the mail_processor
    # plugin uses a more explicit approach to consider whether the message has been handled.
    # If the +r.handle+ method is called during routing, the mail is considered handled,
    # otherwise the mail is considered not handled.  The +unhandled_mail+ method can be
    # called at any point to stop routing and consider the mail as not handled (even if
    # inside an +r.handle+ block).
    #
    # Here are the mail routing methods and what they use for matching:
    #
    # from :: match on the mail From address
    # to :: match on the mail To address
    # cc :: match on the mail CC address
    # rcpt :: match on the mail recipients (To and CC addresses by default)
    # subject :: match on the mail subject
    # body :: match on the mail body
    # text :: match on text extracted from the message (same as mail body by default)
    # header :: match on a mail header
    #
    # All of these routing methods accept a single argument, except for +r.header+, which
    # can take two arguments.
    #
    # Each of these routing methods also has a +r.handle_*+ method
    # (e.g. +r.handle_from+), which will call +r.handle+ implicitly to mark the
    # mail as handled if the routing method matches and control is passed to the block.
    #
    # The address matchers (from, to, cc, rcpt) perform a case-insensitive match if
    # given a string or array of strings, and a regular regexp match if given a regexp.
    #
    # The content matchers (subject, body, text) perform a case-sensitive substring search
    # if given a string or array of strings, and a regular regexp match if given a regexp.
    #
    # The header matcher should be called with a key and an optional value.  If the matcher is
    # called with a key and not a value, it matches if a header matching the key is present
    # in the message, yielding the header value.  If the matcher is called with a key and a
    # value, it matches if a header matching the key is present and the header value matches
    # the value given, using the same criteria as the content matchers.
    #
    # In all cases for matchers, if a string is given and matches, the match block is called without
    # arguments.  If an array of strings is given, and one of the strings matches,
    # the match block is called with the matching string argument.  If a regexp is given,
    # the match block is called with the regexp captures.  This is the same behavior for Roda's
    # general string, array, and regexp matchers.
    # 
    # = Recipient-Specific Routing
    #
    # To allow splitting up the mail processor routing tree based on recipients, you can use
    # the +rcpt+ class method, which takes any number of string or regexps arguments for recipient
    # addresses, and a block to handle the routing for those addresses instead of using the
    # default routing.
    #
    #   MailProcessor.rcpt('a@example.com') do |r|
    #     r.text /Post: (\d+)-(\h+)/ do |post_id, hmac|
    #       next unless Post[post_id.to_i]
    #       unhandled_mail("no matching Post") unless post = Post[post_id.to_i]
    #       unhandled_mail("HMAC for doesn't match for post") unless hmac == post.hmac_for_address(from.first)
    #
    #       r.handle_text 'APPROVE' do
    #         post.approved_by(from)
    #       end
    #
    #       r.handle_text 'DENY' do
    #         post.denied_by(from)
    #       end
    #     end
    #   end
    #
    # The +rcpt+ class method does not mark the messages as handled, because in most cases you will
    # need to do additional matching to extract the information necessary to handle
    # the mail.  You will need to call +r.handle+ or similar method inside the block
    # to mark the mail as handled.
    #
    # Matching on strings provided to the +rcpt+ class method is an O(1) operation as
    # the strings are stored lowercase in a hash.  Matching on regexps provided to the
    # +rcpt+ class method is an O(n) operation on the number of regexps.
    #
    # If you would like to break up the routing tree using something other than the
    # recipient address, you can use the multi_route plugin.
    #
    # = Hooks
    #
    # The mail_processor plugin offers hooks for processing mail.
    #
    # For mail that is handled successfully, you can use the handled_mail hook:
    #
    #   MailProcessor.handled_mail do
    #     # nothing by default
    #   end
    #
    # For mail that is not handled successfully, either because +r.handle+ was not called
    # during routing or because the +unhandled_mail+ method was called explicitly,
    # you can use the unhandled_mail hook.
    #
    # The default is to reraise the UnhandledMail exception that was raised during routing,
    # so that calling code will not be able to ignore errors when processing mail.  However,
    # you may want to save such mails to a special location or forward them as attachments
    # for manual review, and the unhandled_mail hook allows you to do that:
    #
    #   MailProcessor.unhandled_mail do
    #     # raise by default
    #
    #     # Forward the mail as an attachment to an admin
    #     m = Mail.new
    #     m.to 'admin@example.com'
    #     m.subject '[APP] Unhandled Received Email'
    #     m.add_file(filename: 'message.eml', :content=>mail.encoded)
    #     m.deliver
    #   end
    #   
    # Finally, for all processed mail, regardless of whether it was handled or not,
    # there is an after_mail hook, which can be used to archive all processed mail:
    #
    #   MailProcessor.after_mail do
    #     # nothing by default
    #
    #     # Add it to a received_mail table using Sequel
    #     DB[:received_mail].insert(:message=>mail.encoded)
    #   end
    #
    # The after_mail hook is called after the handled_mail or unhandled_mail hook
    # is called, even if routing, the handled_mail hook, or the unhandled_mail hook
    # raises an exception.  The handled_mail and unhandled_mail hooks are not called
    # if an exception is raised during routing (other than for UnhandledMail exceptions).
    #
    # = Extracting Text from Mail
    #
    # The most common use of the mail_processor plugin is to handle replies to mails sent
    # out by the application, so that recipients can reply to mail to make changes without
    # having to access the application directly.  When handling replies, it is common to want
    # to extract only the text of the reply, and ignore the text of the message that was
    # replied to.  Because there is no consistent way to format replies in mail, there have
    # evolved various approaches to do this, with some gems devoted to extracting the reply
    # text from a message.
    #
    # The mail_processor plugin does not choose any particular approach for extracting text from mail,
    # but it includes the ability to configure how to do that via the +mail_text+ class method.
    # This method affects the +r.text+ match method, as well as +mail_text+ instance method.
    # By default, the decoded body of the mail is used as the mail text.
    # 
    #   MailProcessor.mail_text do
    #     # mail.body.decoded by default
    #
    #     # https://github.com/github/email_reply_parser
    #     EmailReplyParser.parse_reply(mail.body.decoded)
    #
    #     # https://github.com/fiedl/extended_email_reply_parser
    #     mail.parse
    #   end
    #
    # = Security
    #
    # Note that due to the way mail delivery works via SMTP, the actual sender and recipient of
    # the mail (the SMTP envelope MAIL FROM and RCPT TO addresses) may not match the sender and
    # receiver embedded in the message.  Because mail_processor routing relies on parsing the mail, 
    # it does not have access to the actual sender and recipient used at the SMTP level, unless
    # a mail server adds that information as a header to the mail (and clears any existing header
    # to prevent spoofing).  Keep that in mind when you are setting up your mail routes.  If you
    # have setup your mail server to add the SMTP RCPT TO information to a header, you may want
    # to only consider that header when looking for the recipients of the message, instead of
    # looking at the To and CC headers.  You can override the default behavior for determining
    # the recipients (this will affect the +rcpt+ class method, +r.rcpt+ match method, and
    # +mail_recipients+ instance method):
    #
    #   MailProcessor.mail_recipients do
    #     # Assuming the information is in the X-SMTP-To header
    #     Array(header['X-SMTP-To'].decoded)
    #   end
    #
    # Also note that unlike when handling web requests where you can rely on storing authentication
    # information in the session, when processing mail, you should manually authenticate each message,
    # as email is trivially forged.  One way to do this is assigning and storing a unique identifier when
    # sending each message, and checking for a matching identifier when receiving a response. Another
    # option is including a computable authentication code (e.g. HMAC) in the message, and then
    # when receiving a response, recomputing the authentication code and seeing if it matches the
    # authentication code in the message.  The unique identifier approach requires storing a large
    # number of identifiers, but allows you to remove the identifier after a reply is received
    # (to ensure only one response is handled).  The authentication code approach does not
    # require additional storage, but does not allow you to ensure only a single response is handled.
    #
    # = Avoiding Mail Loops
    #
    # If processing the mail results in sending out additional mail, be careful not to send a
    # response to the sender of the email, otherwise if the sender of the email has an
    # auto-responder, you can end up with a mail loop, where every mail you send results in
    # a response, which you then process and send out a response to.
    module MailProcessor
      # Exception class raised when a mail processed is not handled during routing,
      # either implicitly because the +r.handle+ method was not called, or via an explicit
      # call to +unhandled_mail+.
      class UnhandledMail < StandardError; end

      module ClassMethods
        # Freeze the rcpt routes if they are present.
        def freeze
          if string_routes = opts[:mail_processor_string_routes].freeze
            string_routes.freeze
            opts[:mail_processor_regexp_routes].freeze
          end
          super
        end

        # Process the given Mail instance, calling the appropriate hooks depending on
        # whether the mail was handled during processing.
        def process_mail(mail)
          scope = new("PATH_INFO"=>'', 'SCRIPT_NAME'=>'', "REQUEST_METHOD"=>"PROCESSMAIL", 'rack.input'=>StringIO.new, 'roda.mail'=>mail)

          begin
            begin
              scope.process_mail
            rescue UnhandledMail
              scope.unhandled_mail_hook
            else
              scope.handled_mail_hook
            end
          ensure
            scope.after_mail_hook
          end
        end
        
        # Process all mail in the given mailbox.  If the +:retriever+ option is
        # given, should be an object supporting the Mail retriever API, otherwise
        # uses the default Mail retriever_method.  This deletes retrieved mail from the
        # mailbox after processing, so that when called multiple times it does
        # not reprocess the same mail.  If mail should be archived and not deleted,
        # the +after_mail+ method should be used to perform the archiving of the mail.
        def process_mailbox(opts=OPTS)
          (opts[:retriever] || Mail).find_and_delete(opts.dup){|m| process_mail(m)}
          nil
        end

        # Setup a routing tree for the given recipient addresses, which can be strings or regexps.
        # Any messages matching the given recipient address will use these routing trees instead
        # of the normal routing tree.
        def rcpt(*addresses, &block)
          opts[:mail_processor_string_routes] ||= {}
          opts[:mail_processor_regexp_routes] ||= {}
          string_meth = nil
          regexp_meth = nil
          addresses.each do |address|
            case address
            when String
              unless string_meth
                string_meth = define_roda_method("mail_processor_string_route_#{address}", 1, &convert_route_block(block))
              end
              opts[:mail_processor_string_routes][address] = string_meth 
            when Regexp
              unless regexp_meth
                regexp_meth = define_roda_method("mail_processor_regexp_route_#{address}", :any, &convert_route_block(block))
              end
              opts[:mail_processor_regexp_routes][address] = regexp_meth
            else
              raise RodaError, "invalid address format passed to rcpt, should be Array or String"
            end
          end
          nil
        end

        %w'after_mail handled_mail unhandled_mail'.each do |meth|
          class_eval(<<-END, __FILE__, __LINE__+1)
            def #{meth}(&block)
              define_method(:#{meth}_hook, &block)
              nil
            end
          END
        end

        %w'mail_recipients mail_text'.each do |meth|
          class_eval(<<-END, __FILE__, __LINE__+1)
            def #{meth}(&block)
              define_method(:#{meth}, &block)
              nil
            end
          END
        end
      end

      module InstanceMethods
        [:to, :from, :cc, :body, :subject, :header].each do |field|
          class_eval(<<-END, __FILE__, __LINE__+1)
            def #{field}
              mail.#{field}
            end
          END
        end

        # Perform the processing of mail for this request, first considering
        # routes defined via the class-level +rcpt+ method, and then the
        # normal routing tree passed in as the block.
        def process_mail(&block)
          if string_routes = opts[:mail_processor_string_routes]
            addresses = mail_recipients

            addresses.each do |address|
              if meth = string_routes[address.to_s.downcase]
                _roda_handle_route{send(meth, @_request)}
                return
              end
            end

            opts[:mail_processor_regexp_routes].each do |regexp, meth|
              addresses.each do |address|
                if md = regexp.match(address)
                  _roda_handle_route{send(meth, @_request, *md.captures)}
                  return 
                end
              end
            end
          end

          _roda_handle_main_route

          nil
        end

        # Hook called after processing any mail, whether the mail was
        # handled or not.  Does nothing by default.
        def after_mail_hook
          nil
        end

        # Hook called after processing a mail, when the mail was handled.
        # Does nothing by default.
        def handled_mail_hook
          nil
        end

        # Hook called after processing a mail, when the mail was not handled.
        # Reraises the UnhandledMail exception raised during mail processing
        # by default.
        def unhandled_mail_hook
          raise
        end

        # The mail instance being processed.
        def mail
          env['roda.mail']
        end

        # The text of the mail instance being processed, uses the
        # decoded body of the mail by default.
        def mail_text
          mail.body.decoded
        end

        # The recipients of the mail instance being processed, uses the To and CC
        # headers by default.
        def mail_recipients
          Array(to) + Array(cc)
        end

        # Raise an UnhandledMail exception with the given reason, used to mark the
        # mail as not handled.  A reason why the mail was not handled must be
        # provided, which will be used as the exception message.
        def unhandled_mail(reason)
          raise UnhandledMail, reason
        end
      end

      module RequestMethods
        [:to, :from, :cc, :body, :subject, :rcpt, :text].each do |field|
          class_eval(<<-END, __FILE__, __LINE__+1)
            def handle_#{field}(val)
              #{field}(val) do |*args|
                handle do
                  yield(*args)
                end
              end
            end

            def #{field}(address, &block)
              on(:#{field}=>address, &block)
            end
          END

          case field
          when :rcpt, :text, :body, :subject
            next
          end

          class_eval(<<-END, __FILE__, __LINE__+1)
            private

            def match_#{field}(address)
              _match_address(:#{field}, address, Array(mail.#{field}))
            end
          END
        end

        # Same as +header+, but also mark the message as being handled.
        def handle_header(key, value=nil)
          header(key, value) do |*args|
            handle do
              yield(*args)
            end
          end
        end

        # Match based on a mail header value.
        def header(key, value=nil, &block)
          on(:header=>[key, value], &block)
        end

        # Mark the mail as having been handled, so routing will not call
        # unhandled_mail implicitly.
        def handle(&block)
          env['roda.mail_handled'] = true
          always(&block)
        end

        private

        if RUBY_VERSION >= '2.4.0'
          # Whether the addresses are the same (case insensitive match).
          def address_match?(a1, a2)
            a1.casecmp?(a2)
          end
        else
          # simplecov:disable
          def address_match?(a1, a2)
            a1.downcase == a2.downcase
          end
          # simplecov:enable
        end

        # Match if any of the given addresses match the given val, which
        # can be a string (case insensitive match of the string), array of
        # strings (case insensitive match of any string), or regexp
        # (normal regexp match).
        def _match_address(field, val, addresses)
          case val
          when String
            addresses.any?{|a| address_match?(a, val)}
          when Array
            overlap = []
            addresses.each do |a|
              val.each do |v|
                if address_match?(a, v)
                  overlap << a 
                end
              end
            end

            unless overlap.empty?
              @captures.concat(overlap)
            end
          when Regexp
            matched = false
            addresses.each do |v|
              if md = val.match(v)
                matched = true
                @captures.concat(md.captures)
              end
            end
            matched
          else
            unsupported_matcher(:field=>val)
          end
        end

        # Match if the content matches the given val, which
        # can be a string (case sensitive substring match), array of
        # strings (case sensitive substring match of any string), or regexp
        # (normal regexp match).
        def _match_content(field, val, content)
          case val
          when String
            content.include?(val)
          when Array
            val.each do |v|
              if content.include?(v)
                return @captures << v
              end
            end
            false
          when Regexp
            if md = val.match(content)
              @captures.concat(md.captures)
            end
          else
            unsupported_matcher(field=>val)
          end
        end

        # Match the value against the full mail body.
        def match_body(val)
          _match_content(:body, val, mail.body.decoded)
        end

        # Match the value against the mail subject.
        def match_subject(val)
          _match_content(:subject, val, mail.subject)
        end

        # Match the given address against all recipients in the mail.
        def match_rcpt(address)
          _match_address(:rcpt, address, scope.mail_recipients)
        end

        # Match the value against the extracted mail text.
        def match_text(val)
          _match_content(:text, val, scope.mail_text)
        end

        # Match against a header specified by key with the given
        # value (which may be nil).
        def match_header((key, value))
          return unless content = mail.header[key]

          if value.nil?
            @captures << content.decoded
          else
            _match_content(:header, value, content.decoded)
          end
        end

        # The mail instance being processed.
        def mail
          env['roda.mail']
        end

        # If the routing did not explicitly mark the mail as handled
        # mark it as unhandled.
        def block_result_body(_)
          unless env['roda.mail_handled']
            scope.unhandled_mail('mail was not handled during mail_processor routing')
          end
        end
      end
    end

    register_plugin(:mail_processor, MailProcessor)
  end
end

