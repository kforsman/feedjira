module Feedjira
  class Feed
    USER_AGENT = 'feedjira http://feedjira.com'

    # Passes raw XML and callbacks to a parser.
    # === Parameters
    # [parser<Object>] The parser to pass arguments to - must respond to
    # `parse` and should return a Feed object.
    # [xml<String>] The XML that you would like parsed.
    # === Returns
    # An instance of the parser feed type.
    def self.parse_with(parser, xml, &block)
      parser.parse xml, &block
    end

    # Takes a raw XML feed and attempts to parse it. If no parser is available a Feedjira::NoParserAvailable exception is raised.
    # You can pass a block to be called when there's an error during the parsing.
    # === Parameters
    # [xml<String>] The XML that you would like parsed.
    # === Returns
    # An instance of the determined feed type. By default, one of these:
    # * Feedjira::Parser::RSSFeedBurner
    # * Feedjira::Parser::GoogleDocsAtom
    # * Feedjira::Parser::AtomFeedBurner
    # * Feedjira::Parser::Atom
    # * Feedjira::Parser::ITunesRSS
    # * Feedjira::Parser::RSS
    # === Raises
    # Feedjira::NoParserAvailable : If no valid parser classes could be found for the feed.
    def self.parse(xml, &block)
      if parser = determine_feed_parser_for_xml(xml)
        parse_with parser, xml, &block
      else
      raise NoParserAvailable.new("No valid parser for XML.")
      end
    end

    # Determines the correct parser class to use for parsing the feed.
    #
    # === Parameters
    # [xml<String>] The XML that you would like determine the parser for.
    # === Returns
    # The class name of the parser that can handle the XML.
    def self.determine_feed_parser_for_xml(xml)
      start_of_doc = xml.slice(0, 2000)
      feed_classes.detect {|klass| klass.able_to_parse?(start_of_doc)}
    end

    # Adds a new feed parsing class that will be used for parsing.
    #
    # === Parameters
    # [klass<Constant>] The class/constant that you want to register.
    # === Returns
    # A updated array of feed parser class names.
    def self.add_feed_class(klass)
      feed_classes.unshift klass
    end

    # Provides a list of registered feed parsing classes.
    #
    # === Returns
    # A array of class names.
    def self.feed_classes
      @feed_classes ||= [
        Feedjira::Parser::RSSFeedBurner,
        Feedjira::Parser::GoogleDocsAtom,
        Feedjira::Parser::AtomFeedBurner,
        Feedjira::Parser::Atom,
        Feedjira::Parser::ITunesRSS,
        Feedjira::Parser::RSS
      ]
    end

    # Makes all registered feeds types look for the passed in element to parse.
    # This is actually just a call to element (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>] The element tag
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_element(element_tag, options = {})
      feed_classes.each do |k|
        k.element element_tag, options
      end
    end

    # Makes all registered feeds types look for the passed in elements to parse.
    # This is actually just a call to elements (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>] The element tag
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_elements(element_tag, options = {})
      feed_classes.each do |k|
        k.elements element_tag, options
      end
    end

    # Makes all registered entry types look for the passed in element to parse.
    # This is actually just a call to element (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>]
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_entry_element(element_tag, options = {})
      call_on_each_feed_entry :element, element_tag, options
    end

    # Makes all registered entry types look for the passed in elements to parse.
    # This is actually just a call to element (a SAXMachine call) in the class.
    #
    # === Parameters
    # [element_tag<String>]
    # [options<Hash>] Valid keys are same as with SAXMachine
    def self.add_common_feed_entry_elements(element_tag, options = {})
      call_on_each_feed_entry :elements, element_tag, options
    end

    # Call a method on all feed entries classes.
    #
    # === Parameters
    # [method<Symbol>] The method name
    # [parameters<Array>] The method parameters
    def self.call_on_each_feed_entry(method, *parameters)
      feed_classes.each do |k|
        # iterate on the collections defined in the sax collection
        k.sax_config.collection_elements.each_value do |vl|
          # vl is a list of CollectionConfig mapped to an attribute name
          # we'll look for the one set as 'entries' and add the new element
          vl.find_all{|v| (v.accessor == 'entries') && (v.data_class.class == Class)}.each do |v|
              v.data_class.send(method, *parameters)
          end
        end
      end
    end

    # Setup request options.
    # Possible parameters:
    # * :user_agent          - overrides the default user agent.
    # * :language            - accept language value.
    # * :compress            - any value to enable compression
    # * :enable_cookies      - boolean
    # * :cookiefile          - file to read cookies
    # * :cookies             - contents of cookies header
    # * :max_redirects       - max number of redirections
    # * :timeout             - timeout
    def self.setup_options(options={})
      _options = {followlocation: true, headers: {'User-Agent'=> USER_AGENT}}
      if options.has_key?(:user_agent)
        _options[:headers]['User-Agent'] = options[:user_agent]
      end
      if options.has_key?(:if_modified_since)
        _options[:headers]['If-Modified-Since'] = options[:if_modified_since]
      end
      if options.has_key?(:if_none_match)
        _options[:headers]['If-None-Match'] = options[:if_none_match]
      end
      if options.has_key?(:compress)
        _options[:headers]['Accept-encoding'] = 'gzip, deflate'
      end
      _options
    end

    # Fetches and returns the raw XML for each URL provided.
    #
    # === Parameters
    # [urls<String> or <Array>] A single feed URL, or an array of feed URLs.
    # [options<Hash>] Valid keys for this argument as as followed:
    #                 :if_modified_since - Time object representing when the feed was last updated.
    #                 :if_none_match - String that's normally an etag for the request that was stored previously.
    #                 :on_success - Block that gets executed after a successful request.
    #                 :on_failure - Block that gets executed after a failed request.
    # === Returns
    # A String of XML if a single URL is passed.
    #
    # A Hash if multiple URL's are passed. The key will be the URL, and the value the XML.
    def self.fetch_raw(urls, options = {})
      url_queue = [*urls]
      responses = {}
      _options = setup_options(options)
      hydra = Typhoeus::Hydra.hydra

      url_queue.each do |url|
        request = Typhoeus::Request.new(url, _options)
        request.on_complete do |response|

          if response.success?
            responses[url] = decode_content(response)
          elsif response.timed_out?
            raise TimeoutError.new "Got a time out for #{url}"
          else
            raise HttpError.new "HTTP request failed for #{url}: " + response.code.to_s
          end
        end
        hydra.queue(request)
      end
      hydra.run
      urls.is_a?(String) ? responses.values.first : responses
    end

    # Fetches and returns the parsed XML for each URL provided.
    #
    # === Parameters
    # [urls<String> or <Array>] A single feed URL, or an array of feed URLs.
    # [options<Hash>] Valid keys for this argument as as followed:
    # * :user_agent - String that overrides the default user agent.
    # * :if_modified_since - Time object representing when the feed was last updated.
    # * :if_none_match - String, an etag for the request that was stored previously.
    # * :on_success - Block that gets executed after a successful request.
    # * :on_failure - Block that gets executed after a failed request.
    # === Returns
    # A Feed object if a single URL is passed.
    #
    # A Hash if multiple URL's are passed. The key will be the URL, and the value the Feed object.
    def self.fetch_and_parse(urls, options = {})
      url_queue = [*urls]
      responses = {}
      _options = setup_options(options)

      hydra = Typhoeus::Hydra.hydra

      url_queue.each do |url|
        request = Typhoeus::Request.new(url, _options)
        request.on_complete do |response|

          if response.success?
            xml = decode_content(response)
            klass = determine_feed_parser_for_xml(xml)

            if klass
             feed = parse_with klass, xml #, &on_parser_failure(url)
             feed.feed_url = url # TODO: actual url?
             feed.etag = response.headers_hash['ETag'] #TODO
             feed.last_modified = last_modified_from_header(response.headers_hash['Last-Modified'])
             responses[url] = feed
            else
             raise NoParserAvailable.new "Can't determine a parser for #{url}"
            end
          elsif response.timed_out?
            raise TimeoutError.new "Got a time out for #{url}"
          else
            raise HttpError.new "HTTP request failed for #{url}: " + response.code.to_s
          end

        end
        hydra.queue request
      end

      # this is a blocking call that returns once all requests are complete
      hydra.run

      return urls.is_a?(String) ? responses.values.first : responses
    end

    # Decodes the XML document if it was compressed.
    #
    # === Parameters
    # [response<Typhoeus::Response>] The Typhoeus::Response object.
    # === Returns
    # A decoded string of XML.
    def self.decode_content(response)
      encoding = response.headers_hash['Content-Type'] if response.headers_hash

      if encoding && encoding.match(/gzip/i) # TODO: check regex
        begin
          gz =  Zlib::GzipReader.new(StringIO.new(response.body))
          xml = gz.read
          gz.close
        rescue Zlib::GzipFile::Error
          # Maybe this is not gzipped?
          xml = response.body
        end
      elsif encoding && encoding.match(/deflate/i)  # TODO: check regex
        xml = Zlib::Inflate.inflate(response.body)
      else
        xml = response.body
      end
      xml
    end

    # Updates each feed for each Feed object provided.
    #
    # === Parameters
    # [feeds<Feed> or <Array>] A single feed object, or an array of feed objects.
    # [options<Hash>] Valid keys for this argument as as followed:
    #                 * :on_success - Block that gets executed after a successful request.
    #                 * :on_failure - Block that gets executed after a failed request.
    # === Returns
    # A updated Feed object if a single URL is passed.
    #
    # A Hash if multiple Feeds are passed. The key will be the URL, and the value the updated Feed object.
    def self.update(feeds, options = {})
      feed_queue = [*feeds]
      hydra = Typhoeus::Hydra.hydra
      responses = {}
      _options = setup_options(options)

      feed_queue.each do |f|
        next unless f
        request = Typhoeus::Request.new(f.feed_url, _options)
        request.on_complete do |response|

          if response.success?
            updated_feed = Feed.parse response.body #, &on_parser_failure(feed.feed_url)
            updated_feed.feed_url = f.feed_url # TODO: actual url?
            updated_feed.etag = response.headers_hash['ETag'] #TODO
            updated_feed.last_modified = last_modified_from_header(response.headers_hash['Last-Modified'])
            f.update_from_feed(updated_feed)
            responses[f.feed_url] = f
          elsif response.timed_out?
            raise TimeoutError.new "Got a time out for #{f.feed_url}"
          else
            raise HttpError.new "HTTP request failed for #{f.feed_url}: " + response.code.to_s
          end
        end
        hydra.queue request
      end

      hydra.run

      feeds.is_a?(Array) ? responses : responses.values.first
    end

    # Determines the etag from the request headers.
    #
    # === Parameters
    # [header<String>] Raw request header returned from the request
    # === Returns
    # A string of the etag or nil if it cannot be found in the headers.
    def self.etag_from_header(header)
      header =~ /.*ETag:\s(.*)\r/
      $1
    end

    # Determines the last modified date from the request headers.
    #
    # === Parameters
    # [header<String>] Raw request header returned from the request
    # === Returns
    # A Time object of the last modified date or nil if it cannot be found in the headers.
    def self.last_modified_from_header(header)
      header =~ /.*Last-Modified:\s(.*)\r/
      Time.parse_safely($1) if $1
    end
  end
end
