require "#{File.dirname(__FILE__)}/helper"
 
Scrooge::Test.prepare!
 
class ScroogeTest < ActiveSupport::TestCase
  
  teardown do
    MysqlUser.scrooge_flush_callsites!
  end

  test "should not attempt to optimize models without a defined primary key" do
    MysqlUser.stubs(:primary_key).returns('undefined')
    MysqlUser.expects(:find_by_sql_with_scrooge).never
    MysqlUser.find(:first)  
  end  
    
  test "should not optimize any SQL other than result retrieval" do
    MysqlUser.expects(:find_by_sql_with_scrooge).never 
    MysqlUser.find_by_sql("SHOW fields from mysql.user")
  end  
  
  test "should not optimize inner joins" do
    MysqlUser.expects(:find_by_sql_with_scrooge).never 
    MysqlUser.find_by_sql("SELECT * FROM columns_priv INNER JOIN user ON columns_priv.User = user.User")
  end
    
  test "should be able to flag applicable records as being scrooged" do
    assert MysqlUser.find(:first).scrooged?
    assert MysqlUser.find_by_sql( "SELECT * FROM mysql.user WHERE User = 'root'" ).first.scrooged?
  end
  
  test "should be able to track callsites" do
    assert_difference 'MysqlUser.scrooge_callsites.size' do
      MysqlUser.find(:first)
    end
  end
  
  test "should be able to retrieve a callsite form a given signature" do
    assert MysqlUser.find(:first).scrooged?
    assert_instance_of Set, MysqlUser.scrooge_callsite_set( first_callsite )
  end
  
  test "should be able to populate the callsite for a given signature" do
    MysqlUser.scrooge_callsite_set!(123456, Set[1,2,3])
    assert_equal MysqlUser.scrooge_callsite_set(123456), Set[1,2,3]
  end
  
  test "should be able to augment an existing callsite with attributes" do
    MysqlUser.find(:first)
    MysqlUser.augment_scrooge_callsite!( first_callsite, 'Password' )
    assert MysqlUser.scrooge_callsite_set( first_callsite ).include?( 'Password' )
  end
  
  test "should be able to generate a SQL select snippet from a given set" do
    assert_equal MysqlUser.scrooge_sql( Set['Password','User','Host'] ), "`user`.User,`user`.Password,`user`.Host"
  end
 
  test "should be able to augment an existing callsite when attributes is referenced that we haven't seen yet" do
    user = MysqlUser.find(:first)
    MysqlUser.expects(:augment_scrooge_callsite!).times(36)
    user.attributes['Password']
    user.attributes['Host']
  end
  
  def first_callsite
    MysqlUser.scrooge_callsites.to_a.flatten.first
  end
  
end