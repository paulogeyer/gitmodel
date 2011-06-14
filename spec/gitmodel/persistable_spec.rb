require 'spec_helper'

class TestEntity
  include GitModel::Persistable
end

class ValidateTestEntity
  include GitModel::Persistable
  validates_presence_of :name
  attribute :name
end

class LintTest < ActiveModel::TestCase
  include ActiveModel::Lint::Tests
 
  def setup
    @model = TestEntity.new
  end
end

describe GitModel::Persistable do

  it 'passes ActiveModel lint tests' do

    o = LintTest.new("ActiveModel lint test")
    o.setup

    # TODO get this list of methods dynamically
    o.test_to_key
    o.test_to_param
    o.test_valid?
    o.test_persisted?
    o.test_model_naming
    o.test_errors_aref
    o.test_errors_full_messages
  end

  describe '#save' do
    
    it 'raises an exception if the id is not set' do
      o = TestEntity.new
      lambda {o.save}.should raise_error(GitModel::NullId)
    end

    it 'stores an instance in a Git repository in a subdir of db_root named with the id' do
      id = 'foo'
      TestEntity.create!(:id => id)
      
      repo = Grit::Repo.new(GitModel.db_root)
      (repo.commits.first.tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).data.should_not be_nil
    end

    it 'stores attributes in a JSON file' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      TestEntity.create!(:id => id, :attributes => attrs)

      repo = Grit::Repo.new(GitModel.db_root)
      attrs = (repo.commits.first.tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).data
      r = JSON.parse(attrs)
      r.size.should == 2
      r['one'].should == 1
      r['two'].should == 2
    end

    it 'stores blobs in files' do
      id = 'foo'
      blobs = {'blob1.txt' => 'This is blob 1'}
      TestEntity.create!(:id => id, :blobs => blobs)

      repo = Grit::Repo.new(GitModel.db_root)
      (repo.commits.first.tree / File.join(TestEntity.db_subdir, id, 'blob1.txt')).data.should == 'This is blob 1'
    end

    it 'can store attributes and blobs' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1'}
      TestEntity.create!(:id => id, :attributes => attrs, :blobs => blobs)

      r = TestEntity.find('foo')
      r.attributes['one'].should == 1
      r.attributes['two'].should == 2
      r.blobs['blob1.txt'].should == 'This is blob 1'
    end

    it 'returns false if the validations failed' do
      testObj = ValidateTestEntity.new(:id => 'test')
      res = testObj.save
      res.should == false
    end
      

    it 'returns the SHA of the commit if the save was successful' do
      testObj = TestEntity.new
      testObj.id = 'foo'
      testObj.attributes = {:one => 1, :two => 2}
      testObj.blobs = {'blob1.txt' => 'This is blob 1'}
      res = testObj.save
      res.class.should == String
      res.size == 40
    end

    it 'deletes blobs that have been removed'
  end

  describe '#save!' do

    it "calls save and returns the non-false and non-nil result" do
      testObj = TestEntity.new
      testObj.id = 'foo'
      testObj.attributes = {:one => 1, :two => 2}
      testObj.blobs = {'blob1.txt' => 'This is blob 1'}
      res = testObj.save
      res.should_not == nil
      res.should_not == false
    end

    it "calls save and raises an exception if the result is nil" do
      testObj = TestEntity.new
      begin
        res = testObj.save
      rescue
        res.should == nil
      end
      lambda {res = testObj.save}.should raise_error
    end
    
    it "calls save and raises an exception if the result is false" do
      testObj = TestEntity.new
      begin
        res = testObj.save
      rescue
        res.should == false
      end
      lambda {res = testObj.save}.should raise_error
    end

  end

  describe '#new' do
    it 'creates a new unsaved instance' do
      TestEntity.new.new_record?.should be_true
    end

    it 'takes an optional hash to set id, attributes and blobs' do
      o = TestEntity.new(:id => 'foo', :attributes => {:one => 1}, :blobs => {'blob1.txt' => 'This is blob 1'})
      o.id.should == 'foo'
      o.attributes['one'].should == 1
      o.blobs['blob1.txt'].should == 'This is blob 1'
    end
  end

  describe '.create' do
    
    it 'creates a new instance with the given parameters and calls #save on it' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1'}

      new_mock = mock("new_mock")
      TestEntity.should_receive(:new).with(:id => id, :attributes => attrs, :blobs => blobs).and_return(new_mock)
      new_mock.should_receive(:save)

      TestEntity.create(:id => id, :attributes => attrs, :blobs => blobs) 
    end

    it 'returns an instance of the record created' do
      o = TestEntity.create(:id => 'lemur')
      o.should be_a(TestEntity)
      o.id.should == 'lemur'
    end

    describe 'with a single array as a parameter' do

      it 'creates a new instance with each element of the array as parameters and calls #save on it' do
        args = [
          {:id => 'foo', :attributes => {:one => 1}, :blobs => {'blob1.txt' => 'This is blob 1'}},
          {:id => 'bar', :attributes => {:two => 2}, :blobs => {'blob2.txt' => 'This is blob 2'}}
        ]

        new_mock1 = mock("new_mock1")
        new_mock2 = mock("new_mock2")
        TestEntity.should_receive(:new).with(args[0]).once.and_return(new_mock1)
        TestEntity.should_receive(:new).with(args[1]).once.and_return(new_mock2)
        new_mock1.should_receive(:save)
        new_mock2.should_receive(:save)

        TestEntity.create(args) 
      end

    end

  end

  describe '.create!' do

    it 'creates a new instance with the given parameters and calls #save! on it' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1'}

      new_mock = mock("new_mock")
      TestEntity.should_receive(:new).with(:id => id, :attributes => attrs, :blobs => blobs).and_return(new_mock)
      new_mock.should_receive(:save!)

      TestEntity.create!(:id => id, :attributes => attrs, :blobs => blobs) 
    end

    it 'returns an instance of the record created' do
      o = TestEntity.create!(:id => 'lemur')
      o.should be_a(TestEntity)
      o.id.should == 'lemur'
    end

    describe 'with a single array as a parameter' do
      it 'creates a new instance with each element of the array as parameters and calls #save! on it' do
        args = [
          {:id => 'foo', :attributes => {:one => 1}, :blobs => {'blob1.txt' => 'This is blob 1'}},
          {:id => 'bar', :attributes => {:two => 2}, :blobs => {'blob2.txt' => 'This is blob 2'}}
        ]

        new_mock1 = mock("new_mock1")
        new_mock2 = mock("new_mock2")
        TestEntity.should_receive(:new).with(args[0]).once.and_return(new_mock1)
        TestEntity.should_receive(:new).with(args[1]).once.and_return(new_mock2)
        new_mock1.should_receive(:save!)
        new_mock2.should_receive(:save!)

        TestEntity.create!(args) 
      end
    end

  end

  describe '.delete' do

    it 'deletes the object with the given id from the database' do
      TestEntity.create!(:id => 'monkey')
      TestEntity.delete('monkey')

      TestEntity.exists?('monkey').should be_false
    end

    it 'also deletes blobs associated with the given object' do
      id = 'Lemuridae'
      TestEntity.create!(:id => id, :blobs => {:crowned => "Eulemur coronatus", :brown => "Eulemur fulvus"})
      (GitModel.current_tree / File.join(TestEntity.db_subdir, id, 'crowned')).data.should_not be_nil
      (GitModel.current_tree / File.join(TestEntity.db_subdir, id, 'brown')).data.should_not be_nil
      TestEntity.delete(id)

      (GitModel.current_tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).should be_nil
      (GitModel.current_tree / File.join(TestEntity.db_subdir, id, 'attributes.json')).should be_nil

      (GitModel.current_tree / File.join(TestEntity.db_subdir, id, 'crowned')).should be_nil
      (GitModel.current_tree / File.join(TestEntity.db_subdir, id, 'brown')).should be_nil
    end


  end

  describe '.delete_all' do

    it 'deletes all objects of the same type from the database' do
      TestEntity.create!(:id => 'monkey')
      TestEntity.create!(:id => 'ape')

      TestEntity.delete_all
      TestEntity.find_all.should be_empty
    end

  end

  describe '#delete' do

    it 'deletes the object from the database' do
      o = TestEntity.create!(:id => 'monkey')
      o.delete

      TestEntity.exists?('monkey').should be_false
    end

    it 'freezes the object' do
      o = TestEntity.create!(:id => 'monkey')
      o.delete

      o.frozen?.should be_true
    end

  end

  describe '#find' do

    #it 'can load an object from an empty subdir of db_root' do
    #  id = "foo"
    #  dir = File.join(GitModel.db_root, TestEntity.db_subdir, id)
    #  FileUtils.mkdir_p dir

    #  o = TestEntity.find(id)
    #  o.id.should == id
    #  o.attributes.should be_empty
    #  o.blobs.should be_empty
    #end
    
    describe 'with no commits in the repo' do

      it 'raises GitModel::RecordNotFound if a record with the given id doesn\'t exist' do
        lambda{TestEntity.find('missing')}.should raise_error(GitModel::RecordNotFound)
      end

    end
    
    it 'raises GitModel::RecordNotFound if a record with the given id doesn\'t exist' do
      TestEntity.create!(:id => 'something')
      lambda{TestEntity.find('missing')}.should raise_error(GitModel::RecordNotFound)
    end

    it 'can load an object with attributes and no blobs' do
      id = "foo"
      attrs = {:one => 1, :two => 2}
      TestEntity.create!(:id => id, :attributes => attrs)

      o = TestEntity.find(id)
      o.id.should == id
      o.attributes.size.should == 2
      o.attributes['one'].should == 1
      o.attributes['two'].should == 2
      o.blobs.should be_empty
    end

    it 'can load an object with blobs and no attributes' do
      id = 'foo'
      blobs = {'blob1.txt' => 'This is blob 1', 'blob2' => 'This is blob 2'}
      TestEntity.create!(:id => id, :blobs => blobs)

      o = TestEntity.find(id)
      o.id.should == id
      o.attributes.should be_empty
      o.blobs.size.should == 2
      o.blobs["blob1.txt"].should == 'This is blob 1'
      o.blobs["blob2"].should == 'This is blob 2'
    end

    it 'can load an object with both attributes and blobs' do
      id = 'foo'
      attrs = {:one => 1, :two => 2}
      blobs = {'blob1.txt' => 'This is blob 1', 'blob2' => 'This is blob 2'}
      TestEntity.create!(:id => id, :attributes => attrs, :blobs => blobs)

      o = TestEntity.find(id)
      o.id.should == id
      o.attributes.size.should == 2
      o.attributes['one'].should == 1
      o.attributes['two'].should == 2
      o.blobs.size.should == 2
      o.blobs["blob1.txt"].should == 'This is blob 1'
      o.blobs["blob2"].should == 'This is blob 2'
    end

  end

  describe '#find_all' do

    it 'returns an array of all objects' do
      TestEntity.create!(:id => 'one')
      TestEntity.create!(:id => 'two')
      TestEntity.create!(:id => 'three')

      r = TestEntity.find_all
      r.size.should == 3
    end

    it 'returns an empty array if there are no objects of the current type' do
      r = TestEntity.find_all
      r.should == []
    end

  end

  describe '#exists?' do

    it 'returns true if the record exists' do
      TestEntity.create!(:id => 'one')
      TestEntity.exists?('one').should be_true
    end

    it "returns false if the record doesn't exist" do
      TestEntity.exists?('missing').should be_false
    end

  end

  describe '#attributes' do
    it 'accepts symbols or strings interchangeably as strings' do
      o = TestEntity.new(:id => 'lol', :attributes => {"one" => 1, :two => 2})
      o.save!
      o.attributes["one"].should == 1
      o.attributes[:one].should == 1
      o.attributes["two"].should == 2
      o.attributes[:two].should == 2

      # Should also be true after reloading
      o = TestEntity.find 'lol'
      o.attributes["one"].should == 1
      o.attributes[:one].should == 1
      o.attributes["two"].should == 2
      o.attributes[:two].should == 2
    end
  end

  describe '#blobs' do
    it 'accepts symbols or strings interchangeably as strings' do
      o = TestEntity.new(:id => 'lol', :blobs => {"one" => 'this is blob 1', :two => 'this is blob 2'})
      o.save!
      o.blobs["one"].should == 'this is blob 1'
      o.blobs[:one].should == 'this is blob 1'
      o.blobs["two"].should == 'this is blob 2'
      o.blobs[:two].should == 'this is blob 2'

      # Should also be true after reloading
      o = TestEntity.find 'lol'
      o.blobs["one"].should == 'this is blob 1'
      o.blobs[:one].should == 'this is blob 1'
      o.blobs["two"].should == 'this is blob 2'
      o.blobs[:two].should == 'this is blob 2'
    end
  end

  describe 'attribute description in the class definition' do

    it 'creates convenient accessor methods for accessing the attributes hash' do
      o = TestEntity.new
      class << o 
        attribute :colour
      end

      o.colour.should == nil
      o.colour = "red"
      o.colour.should == "red"
      o.attributes[:colour].should == "red"
    end

    it 'can set default values for attributes, with any ruby value for the default' do
      o = TestEntity.new

      # Change the singleton class for object o, this doesn't change the
      # TestEntity class
      class << o 
        attribute :size, :default => "medium"
        attribute :shape, :default => 2 
        attribute :style, :default => nil 
        attribute :teeth, :default => {"molars" => 4, "canines" => 2}
      end

      o.size.should == "medium"
      o.shape.should == 2
      o.style.should == nil
      o.teeth.should == {"molars" => 4, "canines" => 2}

      o.size = "large"
      o.size.should == "large"
    end

  end

  describe 'blob description in the class definition' do

    it 'creates convenient accessor methods for accessing the blobs hash' do
      o = TestEntity.new
      class << o 
        blob :avatar
      end

      o.avatar.should == nil

      o.avatar = "image_data_here"
      o.avatar.should == "image_data_here"
      o.blobs[:avatar].should == "image_data_here"
    end

  end

end

