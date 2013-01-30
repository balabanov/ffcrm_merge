require 'spec_helper'

describe 'when merging accounts' do
  before :each do
    @master = FactoryGirl.create(:account, :name => "Master account",
      :email => "master@example.com", :background_info => "Master Background Info", :tag_list => 'tag1, tag2, tag3')
    @duplicate = FactoryGirl.create(:account, :name => "Duplicate account",
      :email => "duplicate@example.com", :background_info => "Duplicate Background Info", :tag_list => 'tag3, tag4')
    FactoryGirl.create(:email, :mediator => @master)
    FactoryGirl.create(:comment, :commentable => @master)
    FactoryGirl.create(:email, :mediator => @duplicate)
    FactoryGirl.create(:comment, :commentable => @duplicate)
    FactoryGirl.create(:address, :addressable => @master, :address_type => 'Billing')
    FactoryGirl.create(:address, :addressable => @duplicate, :address_type => 'Billing')
    FactoryGirl.create(:address, :addressable => @master, :address_type => 'Shipping')
    FactoryGirl.create(:address, :addressable => @duplicate, :address_type => 'Shipping')
    @master.tasks << FactoryGirl.create(:task)
    @duplicate.tasks << FactoryGirl.create(:task)
    @master.opportunities << FactoryGirl.create(:opportunity)
    @duplicate.opportunities << FactoryGirl.create(:opportunity)
    @master.contacts << FactoryGirl.create(:contact)
    @duplicate.contacts << FactoryGirl.create(:contact)
  end
  
    
  it "should always ignore certain attributes" do
    expect(@master.merge_attributes.keys).to_not include(@master.ignored_merge_attributes)
  end
  
  it "should not merge into itself" do
    expect(@master.merge_with(@master)).to be_false
  end
  
  it "should return true" do
    expect(@duplicate.merge_with(@master)).to be_true
  end
  
  it "should delete the duplicate" do
    expect(Account.where(:id => @duplicate.id).first).to eql(@duplicate)
    @duplicate.merge_with(@master)
    expect(Account.where(:id => @duplicate.id).first).to be_nil
  end
  
  it "should call merge hook" do
    @master.should_receive(:merge_hook).with(@duplicate)
    @duplicate.merge_with(@master)
  end

  it "should include associations" do
    @duplicate.merge_with(@master)
    @master.reload
    
    emails = @duplicate.emails.dup
    comments = @duplicate.comments.dup
    opportunities = @duplicate.opportunities.dup
    contacts = @duplicate.contacts.dup
    tasks = @duplicate.tasks.dup
    addresses = @duplicate.addresses.dup
    tags = @duplicate.tags.dup
    
    expect(@master.user).to eq(@duplicate.user)

    expect(@master.emails.size).to eq(2)
    expect(@master.emails).to include(*emails)
    expect(@master.comments.size).to eq(2)
    expect(@master.comments).to include(*comments)
    expect(@master.opportunities.size).to eq(2)
    expect(@master.opportunities).to include(*opportunities)
    expect(@master.contacts.size).to eq(2) # master + duplicate
    expect(@master.contacts).to include(*contacts)
    expect(@master.tasks.size).to eq(2)
    expect(@master.tasks).to include(*tasks)
    expect(@master.addresses.size).to eq(2)
    expect(@master.addresses).to include(*addresses)
    expect(@master.tags.size).to eq(4)
    expect(@master.tags).to include(*tags)
  end
  
  it "should copy all duplicate attributes" do
    duplicate_merge_attributes = @duplicate.merge_attributes
    @duplicate.merge_with(@master)
    expect(@master.merge_attributes).to eq(duplicate_merge_attributes)
  end
  
  it "should be able to ignore some of the duplicate attributes when merging" do
    ignored_attributes = %w(name background_info phone fax)
    duplicate_attributes = @duplicate.merge_attributes.dup
    master_attributes = @master.merge_attributes.dup
    @duplicate.merge_with(@master, ignored_attributes)

    # Check that the merge has ignored some duplicate attributes
    expect(@master.name).to eql(master_attributes['name'])
    expect(@master.background_info).to eql(master_attributes['background_info'])
    expect(@master.phone).to eql(master_attributes['phone'])
    expect(@master.fax).to eql(master_attributes['fax'])

    # Check that the merge has included some duplicate attributes
    expect(@master.category).to eql(duplicate_attributes['category'])
    expect(@master.toll_free_phone).to eql(duplicate_attributes['toll_free_phone'])
    expect(@master.access).to eql(duplicate_attributes['access'])
    expect(@master.rating).to eql(duplicate_attributes['rating'])

  end

  describe "account alias" do
  
    it "should be created" do
      @duplicate.merge_with(@master)
      ca = AccountAlias.where(:destroyed_account_id => @duplicate.id).first
      expect(ca.account).to eq(@master)
    end

    it "should update existing aliases pointing to the duplicate record" do
      @ca1 = AccountAlias.create(:account => @duplicate, :destroyed_account_id => 12345)
      @ca2 = AccountAlias.create(:account => @duplicate, :destroyed_account_id => 23456)
      @duplicate.merge_with(@master)
      expect(AccountAlias.where(:destroyed_account_id => 12345).first.account_id).to eql(@master.id)
      expect(AccountAlias.where(:destroyed_account_id => 23456).first.account_id).to eql(@master.id)
    end
    
  end
  
  describe "merge failure" do

    it "validation error should return false" do
      @master.should_receive('save!').and_return(false)
      expect(@duplicate.merge_with(@master)).to be_false
    end

    pending "should rollback the transaction" do
      duplicate_attributes = @duplicate.merge_attributes.dup
      master_attributes = @master.merge_attributes.dup

      #~ @master.should_receive(:tag_list=).and_return(lambda { raise "tag_list error" })
      AccountAlias.should_receive(:create).and_return(lambda { raise "active_record error" })
      expect(@duplicate.merge_with(@master)).to raise_error

      @master.reload
      # check master attributes are rolled back
      expect(@master.name).to eql(master_attributes['name'])
      expect(@master.website).to eql(master_attributes['website'])
      expect(@master.rating).to eql(master_attributes['rating'])
      expect(@master.phone).to eql(master_attributes['phone'])
      
      # check duplicate name is rolled back
      expect(@duplicate.name).to eq(duplicate_attributes['name'])

      # check master association assigments are rolled back
      expect(@master.user).to eq(master_attributes['user'])
      expect(@master.contacts).to eq(master_attributes['contacts'])
      expect(@master.tasks).to eq(master_attributes['tasks'])
      expect(@master.opportunities).to eq(master_attributes['opportunities'])
      
      # check duplicate association assigments are rolled back
      expect(@duplicate.user).to eq(master_attributes['user'])
      expect(@duplicate.contacts).to eq(master_attributes['contacts'])
      expect(@duplicate.tasks).to eq(master_attributes['tasks'])
      expect(@duplicate.opportunities).to eq(master_attributes['opportunities'])
      
    end
  
  end

end
