require File.dirname(__FILE__) + '/../spec_helper'

class Hell < StandardError; end

class FailParser
  def self.parse(_, &on_failure)
    on_failure.call 'this parser always fails.'
  end
end

describe Feedjira::Feed do

  describe "#add_common_feed_element" do
    before(:all) do
      Feedjira::Feed.add_common_feed_element("generator")
    end

    it "should parse the added element out of Atom feeds" do
      Feedjira::Feed.parse(sample_wfw_feed).generator.should == "TypePad"
    end

    it "should parse the added element out of Atom Feedburner feeds" do
      Feedjira::Parser::Atom.new.should respond_to(:generator)
    end

    it "should parse the added element out of RSS feeds" do
      Feedjira::Parser::RSS.new.should respond_to(:generator)
    end
  end

  describe "#add_common_feed_entry_element" do
    before(:all) do
      Feedjira::Feed.add_common_feed_entry_element("wfw:commentRss", :as => :comment_rss)
    end

    it "should parse the added element out of Atom feeds entries" do
      Feedjira::Feed.parse(sample_wfw_feed).entries.first.comment_rss.should == "this is the new val"
    end

    it "should parse the added element out of Atom Feedburner feeds entries" do
      Feedjira::Parser::AtomEntry.new.should respond_to(:comment_rss)
    end

    it "should parse the added element out of RSS feeds entries" do
      Feedjira::Parser::RSSEntry.new.should respond_to(:comment_rss)
    end
  end

  describe "#feed_classes" do
    it "should" do
      expect(Feedjira::Feed.feed_classes).to include(Feedjira::Parser::RSSFeedBurner)
      expect(Feedjira::Feed.feed_classes).to include(Feedjira::Parser::GoogleDocsAtom)
      expect(Feedjira::Feed.feed_classes).to include(Feedjira::Parser::AtomFeedBurner)
      expect(Feedjira::Feed.feed_classes).to include(Feedjira::Parser::Atom)
      expect(Feedjira::Feed.feed_classes).to include(Feedjira::Parser::ITunesRSS)
      expect(Feedjira::Feed.feed_classes).to include(Feedjira::Parser::RSS)
    end
  end

  describe '#parse_with' do
    let(:xml) { '<xml></xml>' }

    it 'invokes the parser and passes the xml' do
      parser = double 'Parser', parse: nil
      parser.should_receive(:parse).with xml
      Feedjira::Feed.parse_with parser, xml
    end

    context 'with a callback block' do
      it 'passes the callback to the parser' do
        callback = ->(*) { raise Hell }

        expect do
          Feedjira::Feed.parse_with FailParser, xml, &callback
        end.to raise_error Hell
      end
    end
  end

  describe "#parse" do # many of these tests are redundant with the specific feed type tests, but I put them here for completeness
    context "when there's an available parser" do
      it "should parse an rdf feed" do
        feed = Feedjira::Feed.parse(sample_rdf_feed)
        feed.title.should == "HREF Considered Harmful"
        feed.entries.first.published.should == Time.parse_safely("Tue Sep 02 19:50:07 UTC 2008")
        feed.entries.size.should == 10
      end

      it "should parse an rss feed" do
        feed = Feedjira::Feed.parse(sample_rss_feed)
        feed.title.should == "Tender Lovemaking"
        feed.entries.first.published.should == Time.parse_safely("Thu Dec 04 17:17:49 UTC 2008")
        feed.entries.size.should == 10
      end

      it "should parse an atom feed" do
        feed = Feedjira::Feed.parse(sample_atom_feed)
        feed.title.should == "Amazon Web Services Blog"
        feed.entries.first.published.should == Time.parse_safely("Fri Jan 16 18:21:00 UTC 2009")
        feed.entries.size.should == 10
      end

      it "should parse an feedburner atom feed" do
        feed = Feedjira::Feed.parse(sample_feedburner_atom_feed)
        feed.title.should == "Paul Dix Explains Nothing"
        feed.entries.first.published.should == Time.parse_safely("Thu Jan 22 15:50:22 UTC 2009")
        feed.entries.size.should == 5
      end

      it "should parse an itunes feed" do
        feed = Feedjira::Feed.parse(sample_itunes_feed)
        feed.title.should == "All About Everything"
        feed.entries.first.published.should == Time.parse_safely("Wed, 15 Jun 2005 19:00:00 GMT")
        feed.entries.size.should == 3
      end
    end

    context "when there's no available parser" do
      it "raises Feedjira::NoParserAvailable" do
        proc {
          Feedjira::Feed.parse("I'm an invalid feed")
        }.should raise_error(Feedjira::NoParserAvailable)
      end
    end

    it "should parse an feedburner rss feed" do
      feed = Feedjira::Feed.parse(sample_rss_feed_burner_feed)
      feed.title.should == "TechCrunch"
      feed.entries.first.published.should == Time.parse_safely("Wed Nov 02 17:25:27 UTC 2011")
      feed.entries.size.should == 20
    end
  end

  describe "#determine_feed_parser_for_xml" do
    it 'should return the Feedjira::Parser::GoogleDocsAtom calss for a Google Docs atom feed' do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_google_docs_list_feed).should == Feedjira::Parser::GoogleDocsAtom
    end

    it "should return the Feedjira::Parser::Atom class for an atom feed" do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_atom_feed).should == Feedjira::Parser::Atom
    end

    it "should return the Feedjira::Parser::AtomFeedBurner class for an atom feedburner feed" do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_feedburner_atom_feed).should == Feedjira::Parser::AtomFeedBurner
    end

    it "should return the Feedjira::Parser::RSS class for an rdf/rss 1.0 feed" do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_rdf_feed).should == Feedjira::Parser::RSS
    end

    it "should return the Feedjira::Parser::RSSFeedBurner class for an rss feedburner feed" do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_rss_feed_burner_feed).should == Feedjira::Parser::RSSFeedBurner
    end

    it "should return the Feedjira::Parser::RSS object for an rss 2.0 feed" do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_rss_feed).should == Feedjira::Parser::RSS
    end

    it "should return a Feedjira::Parser::RSS object for an itunes feed" do
      Feedjira::Feed.determine_feed_parser_for_xml(sample_itunes_feed).should == Feedjira::Parser::ITunesRSS
    end

  end

  describe "when adding feed types" do
    it "should prioritize added types over the built in ones" do
      feed_text = "Atom asdf"
      Feedjira::Parser::Atom.stub(:able_to_parse?).and_return(true)
      new_feed_type = Class.new do
        def self.able_to_parse?(val)
          true
        end
      end

      new_feed_type.should be_able_to_parse(feed_text)
      Feedjira::Feed.add_feed_class(new_feed_type)
      Feedjira::Feed.determine_feed_parser_for_xml(feed_text).should == new_feed_type

      # this is a hack so that this doesn't break the rest of the tests
      Feedjira::Feed.feed_classes.reject! {|o| o == new_feed_type }
    end
  end

  describe '#etag_from_header' do
    before(:each) do
      @header = "HTTP/1.0 200 OK\r\nDate: Thu, 29 Jan 2009 03:55:24 GMT\r\nServer: Apache\r\nX-FB-Host: chi-write6\r\nLast-Modified: Wed, 28 Jan 2009 04:10:32 GMT\r\nETag: ziEyTl4q9GH04BR4jgkImd0GvSE\r\nP3P: CP=\"ALL DSP COR NID CUR OUR NOR\"\r\nConnection: close\r\nContent-Type: text/xml;charset=utf-8\r\n\r\n"
    end

    it "should return the etag from the header if it exists" do
      Feedjira::Feed.etag_from_header(@header).should == "ziEyTl4q9GH04BR4jgkImd0GvSE"
    end

    it "should return nil if there is no etag in the header" do
      Feedjira::Feed.etag_from_header("foo").should be_nil
    end

  end

  describe '#last_modified_from_header' do
    before(:each) do
      @header = "HTTP/1.0 200 OK\r\nDate: Thu, 29 Jan 2009 03:55:24 GMT\r\nServer: Apache\r\nX-FB-Host: chi-write6\r\nLast-Modified: Wed, 28 Jan 2009 04:10:32 GMT\r\nETag: ziEyTl4q9GH04BR4jgkImd0GvSE\r\nP3P: CP=\"ALL DSP COR NID CUR OUR NOR\"\r\nConnection: close\r\nContent-Type: text/xml;charset=utf-8\r\n\r\n"
    end

    it "should return the last modified date from the header if it exists" do
      Feedjira::Feed.last_modified_from_header(@header).should == Time.parse_safely("Wed, 28 Jan 2009 04:10:32 GMT")
    end

    it "should return nil if there is no last modified date in the header" do
      Feedjira::Feed.last_modified_from_header("foo").should be_nil
    end
  end

  describe "fetching feeds" do
    before(:each) do
      @paul_feed = { :xml => load_sample("PaulDixExplainsNothing.xml"), :url => "http://feeds.feedburner.com/PaulDixExplainsNothing" }
      @trotter_feed = { :xml => load_sample("TrotterCashionHome.xml"), :url => "http://feeds2.feedburner.com/trottercashion" }
      @invalid_feed = { :xml => 'This feed is invalid', :url => "http://feeds.feedburner.com/InvalidFeed" }
      #stub_request(:get, @paul_feed[:url]).to_return(:body => @paul_feed[:xml], :status => 200)
      stub_request(:get, @paul_feed[:url]).to_return(File.new("spec/fixtures/response_mocks/paul_dix_eplains_nothing.response"))
      stub_request(:get, @trotter_feed[:url]).to_return(:body => @trotter_feed[:xml], :status => 200)
    end

    describe "#fetch_raw" do

      before(:each) do
        # stub_request(:get, @paul_feed[:url]).to_return(:body => @paul_feed[:xml], :status => 200)
        # stub_request(:get, @trotter_feed[:url]).to_return(:body => @trotter_feed[:xml], :status => 200)
      end

      it "should set user agent if it's passed as an option" do
        stub_request(:get, @paul_feed[:url]).to_return(:body => @paul_feed[:xml], :status => 200)
        Feedjira::Feed.fetch_raw(@paul_feed[:url], :user_agent => 'Custom Useragent')
        WebMock.should have_requested(:get, @paul_feed[:url]).with(:headers => {'User-Agent' => 'Custom Useragent'})
      end

      it "should set user agent to default if it's not passed as an option" do
        Feedjira::Feed.fetch_raw(@paul_feed[:url])
        WebMock.should have_requested(:get, @paul_feed[:url]).with(:headers => {'User-Agent' => Feedjira::Feed::USER_AGENT})
      end

      it "should set if modified since as an option if passed" do
        Feedjira::Feed.fetch_raw(@paul_feed[:url], :if_modified_since => Time.parse_safely("Wed, 28 Jan 2009 04:10:32 GMT"))
        WebMock.should have_requested(:get, @paul_feed[:url])
        .with(:headers => {'If-Modified-Since' => '2009-01-28 04:10:32 UTC', 'User-Agent' => Feedjira::Feed::USER_AGENT})
      end

      it "should set if none match as an option if passed" do
        Feedjira::Feed.fetch_raw(@paul_feed[:url], :if_none_match => 'ziEyTl4q9GH04BR4jgkImd0GvSE')
        WebMock.should have_requested(:get, @paul_feed[:url])
        .with(:headers => {'If-None-Match' => 'ziEyTl4q9GH04BR4jgkImd0GvSE', 'User-Agent' => Feedjira::Feed::USER_AGENT})
      end

      it 'should set userpwd for http basic authentication if :http_authentication is passed' do
        pending
        # @curl.should_receive(:userpwd=).with('username:password')
        # Feedjira::Feed.fetch_raw(@paul_feed[:url], :http_authentication => ['username', 'password'])
      end

      it 'should set accepted encodings' do
        Feedjira::Feed.fetch_raw(@paul_feed[:url], :compress => true)
        WebMock.should have_requested(:get, @paul_feed[:url])
        .with(:headers => {'Accept-encoding' => 'gzip, deflate', 'User-Agent' => Feedjira::Feed::USER_AGENT})
      end

      it "should return raw xml" do
        Feedjira::Feed.fetch_raw(@paul_feed[:url]).should =~ /^#{Regexp.escape('<?xml version="1.0" encoding="UTF-8"?>')}/
      end

      it "should take multiple feed urls and return a hash of urls and response xml" do
        results = Feedjira::Feed.fetch_raw([@paul_feed[:url], @trotter_feed[:url]])
        results.keys.should include(@paul_feed[:url])
        results.keys.should include(@trotter_feed[:url])
        results[@paul_feed[:url]].should =~ /Paul Dix/
        results[@trotter_feed[:url]].should =~ /Trotter Cashion/
      end

      it "should always return a hash when passed an array" do
        results = Feedjira::Feed.fetch_raw([@paul_feed[:url]])
        results.class.should == Hash
      end

      it "should handle non-success http statuses" do
        url = 'http://somesite.com'
        stub_request(:get, url).to_return(File.new("spec/fixtures/response_mocks/404.response"))
        expect{Feedjira::Feed.fetch_raw(url)}.to raise_error(/HTTP request failed for/)

      end

      it "should handle timeouts" do
        stub_request(:any, @paul_feed[:url]).to_timeout
        expect{
          Feedjira::Feed.fetch_raw(@paul_feed[:url])
        }.to raise_error(Feedjira::TimeoutError)
      end
    end

    describe "#fetch_and_parse" do
      before(:each) do

      end

      describe 'on success' do
        before(:each) do
          @feed = double('feed', :feed_url= => true, :etag= => true, :last_modified= => true)
          Feedjira::Feed.stub(:decode_content).and_return(@paul_feed[:xml])
          # Feedjira::Feed.stub(:determine_feed_parser_for_xml).and_return(Feedjira::Parser::AtomFeedBurner)
          # Feedjira::Parser::AtomFeedBurner.stub(:parse).and_return(@feed)
          # Feedjira::Feed.stub(:etag_from_header).and_return('ziEyTl4q9GH04BR4jgkImd0GvSE')
          # Feedjira::Feed.stub(:last_modified_from_header).and_return('Wed, 28 Jan 2009 04:10:32 GMT')
        end

        it 'should decode the response body' do
          Feedjira::Feed.should_receive(:decode_content).and_return(@paul_feed[:xml])
          Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
        end

        it 'should determine the xml parser class' do
          Feedjira::Feed.should_receive(:determine_feed_parser_for_xml).with(@paul_feed[:xml]).and_return(Feedjira::Parser::AtomFeedBurner)
          Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
        end

        it 'should parse the xml' do
          Feedjira::Parser::AtomFeedBurner.should_receive(:parse).
            with(@paul_feed[:xml]).and_return(@feed)
          Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
        end

        describe 'when a compatible xml parser class is found' do

          it 'should set the last effective url to the feed url' do
            feed = Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
            feed[@paul_feed[:url]].feed_url.should == @paul_feed[:url]
          end

          it 'should set the etags on the feed' do
            feed = Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
            feed.values.first.etag.should == 'fkkhayM81rgbWEltwTKzn08uElg'
          end

          it 'should set the last modified on the feed' do
            feed = Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
            feed.values.first.last_modified.to_s.should == "2009-01-22 15:50:22 UTC"
          end

          it 'should add the feed to the responses' do
            responses = Feedjira::Feed.fetch_and_parse([@paul_feed[:url]])
            responses.length.should == 1
            responses['http://feeds.feedburner.com/PaulDixExplainsNothing'].class.should == Feedjira::Parser::AtomFeedBurner
          end

          it 'should call proc if :on_success option is passed' do
            pending
            success = lambda { |url, feed| }
            success.should_receive(:call).with(@paul_feed[:url], @feed)
            Feedjira::Feed.add_url_to_multi(@multi, @paul_feed[:url], [], {}, { :on_success => success })
            @easy_curl.on_success.call(@easy_curl)
          end

          describe 'when the parser raises an exception' do
            it 'invokes the on_failure callback with that exception' do
              pending
              failure = double 'Failure callback', arity: 2
              failure.should_receive(:call).with(@easy_curl, an_instance_of(Hell))

              Feedjira::Parser::AtomFeedBurner.should_receive(:parse).and_raise Hell
              Feedjira::Feed.add_url_to_multi(@multi, @paul_feed[:url], [], {}, { on_failure: failure })

              @easy_curl.on_success.call(@easy_curl)
            end
          end

        end

        describe 'when no compatible xml parser class is found' do
          it 'invokes the on_failure callback' do
            pending
            failure = double 'Failure callback', arity: 2
            failure.should_receive(:call).with(@easy_curl, "Can't determine a parser")

            Feedjira::Feed.should_receive(:determine_feed_parser_for_xml).and_return nil
            Feedjira::Feed.add_url_to_multi(@multi, @paul_feed[:url], [], {}, { on_failure: failure })

            @easy_curl.on_success.call(@easy_curl)
          end
        end
      end

      describe 'on failure' do
        before(:each) do
          @headers = "HTTP/1.0 500 Something Bad\r\nDate: Thu, 29 Jan 2009 03:55:24 GMT\r\nServer: Apache\r\nX-FB-Host: chi-write6\r\nLast-Modified: Wed, 28 Jan 2009 04:10:32 GMT\r\n"
          @body = 'Sorry, something broke'

          @easy_curl.stub(:response_code).and_return(500)
          @easy_curl.stub(:header_str).and_return(@headers)
          @easy_curl.stub(:body_str).and_return(@body)
        end

        it "should handle non success http status" do
          url = 'http://somesite.com'
          stub_request(:get, url).to_return(File.new("spec/fixtures/response_mocks/404.response"))
          expect{Feedjira::Feed.fetch_and_parse(url)}.to raise_error(Feedjira::HttpError)

        end

        it "should handle timeouts" do
          stub_request(:any, @paul_feed[:url]).to_timeout
          expect{
            Feedjira::Feed.fetch_and_parse(@paul_feed[:url])
          }.to raise_error(Feedjira::TimeoutError)
        end

        it 'should return the http code in the responses' do
          pending
          responses = {}
          Feedjira::Feed.add_url_to_multi(@multi, @paul_feed[:url], [], responses, {})
          @easy_curl.on_failure.call(@easy_curl)

          responses.length.should == 1
          responses[@paul_feed[:url]].should == 500
        end
      end

    end

    describe "#update" do

      before(:each) do
        @url = "http://awesomefeedsite.com"
        stub_request(:get, @url).to_return(File.new("spec/fixtures/response_mocks/paul_dix_eplains_nothing.response"))
        @feed = Feedjira::Feed.fetch_and_parse(@url)
      end

      it "should update feed" do
        Feedjira::Feed.update(@feed)
      end

      it "should not blow up if feed to update is nil" do
        Feedjira::Feed.update([nil])
      end

      it "should handle non-success http statuses" do
        #url = 'http://somesite.com'
        stub_request(:get, @url).to_return(File.new("spec/fixtures/response_mocks/404.response"))
        expect{Feedjira::Feed.update(@feed)}.to raise_error(Feedjira::HttpError)
      end

      it "should handle timeouts" do
        stub_request(:any, @url).to_timeout
        expect{
          Feedjira::Feed.update(@feed)
        }.to raise_error(Feedjira::TimeoutError)
      end

    end

    describe "#decode_content" do
      before(:each) do
        @url = "http://gzipfeeds.com"
        stub_request(:get, @url).to_return(File.new("spec/fixtures/response_mocks/gzip.response"))
      end

      it "should decode gzipped body" do
        feed = Feedjira::Feed.fetch_raw(@url)
      end
    end

  end
end
