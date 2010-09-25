require File.join(File.dirname(__FILE__), 'test_helper')

describe "WebCore" do
  it "#get with no options" do
    request = mock { expects(:request).with({}) }
    Commands::WebCore::Get.expects(:new).with('blah.com').returns(request)
    Commands::WebCore.get 'blah.com'
  end

  it "#post with no options" do
    Net::HTTP.expects(:post_form).with(anything, {}).returns(nil)
    Commands::WebCore.post 'blah.com'
  end

  it "#build_url with string params" do
    Commands::WebCore.build_url('ababd.com', :q=>'search').should == 'ababd.com?q=search'
  end

  it "#build_url with array params" do
    Commands::WebCore.build_url('ababd.com', :q=>%w{multi word search}).should == 'ababd.com?q=multi+word+search'
  end
end
