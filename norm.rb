#NORM: Norm Object Relational Mapper
require 'rubygems'
require 'mysql'

class Object
  def i?
    respond_to? :to_i
  end
end

class NilClass
  def simplify
    nil
  end
end

class Module
  def self.const_defined?(foo)
    puts foo
  end
end

class String
  def i?
    self =~ /^[0-9]+$/
  end
  
  def f?
    self =~ /^[0-9.]+$/
  end
  
  def strip(char = /\s/)
    gsub(/^(#{char})+/,'').gsub(/(#{char})+$/,'')
  end
  
  def underscore
    gsub(/(.)([A-Z])/){"#{$1}_#{$2.downcase}"}.downcase.gsub(/[^a-z_]/, '_').squeeze('_').strip("_")
  end
end

class Array
  def simplify
    case length
    when 0 then nil
    when 1 then first
    else self
    end
  end
end

class Mysql::Result
  include Enumerable
  alias_method :each, :each_hash
end

module Norm
  def self.const_missing(something)
    eval "class Norm::#{something}; include Norm; end"
  end
  
  def self.included(klass)
    klass.send :include, InstanceMethods
    klass.extend ClassMethods
    Norm.models[klass.table_name] = klass
    klass.ensure_table
  end
  
  def self.settings
    @@settings ||= {
      :host => "localhost",
      :username => "root",
      :password => "password",
      :database => "norm"
    }
  end
  
  self.settings.keys.each do |k|
    self.class.send(:define_method, :"#{k}="){|val| settings[k] = val}
    self.class.send(:define_method, k){settings[k]}
  end
  
  def self.connection
    @@connection ||= Mysql.real_connect(
      settings[:host], settings[:username], settings[:password], settings[:database]
    )
  end
  
  def self.drop(table_name)
    Norm["drop table `#{table_name}`"]
  end
  
  def self.log
    @@log ||= []
  end
  
  def self.tables
    self["show tables"].map{|r| r.values.first };
  end
  
  def self.escape(string)
    connection.escape_string string.to_s
  end
  
  def self.query(query)
    log << query
    if r = connection.query(query)
      arr = r.inject([]){|a,r|a<<r.to_hash}
    else
      []
    end
  end
  class << self; alias_method :[], :query; end
  
  def self.models
    @@models ||= {}
  end
  
  def self.model(model_name)
    models[model_name.to_s]
  end
  
  module InstanceMethods
    def initialize(id = nil)
      if id.nil?
        Norm["insert into `#{self.class.table_name}` set id = NULL"]
        @id = Norm["select last_insert_id() as id"].first['id'].to_i
      elsif id.is_a? Hash
        initialize
        id.each{|k,v| send :"#{k}=", v unless k == 'id'}
      else
        @id = id
      end
    end
    
    def method_missing(method, *args)
      if method.to_s =~ /(.+)=$/
        set $1, args.first
      else
        get method
      end
    end
    
    def ==(other)
      other.is_a?(Norm) && self.class.table_name == other.class.table_name && id == other.id
    end
    
    def attributes
      self.class * "where id = #{id}"
    end
    
    def delete
      Norm["delete from `#{self.class.table_name}` where id = #{id}"]
    end
    
    def id() @id end
    
    def id=(anything)
      raise 'id cannot be set'
    end
    
    def set(column, arg)
      self.class.ensure_column column
      raise "can't put a #{arg.class.table_name} into a #{column} column" if Norm.model(column) && arg.is_a?(Norm) && arg.class.table_name != column
      Norm["update `#{self.class.table_name}` set `#{column}` = '#{Norm.escape arg}' where id = #{id}"]
    end
    
    def get(column)
      if self.class.column_exists?(column)
        values = Norm["select `#{column}` from `#{self.class.table_name}` where id = #{id}"].map{|r| r[column.to_s]}
        if Norm.model column
          [Norm.model(column)[values]]
        else
          values
        end.simplify
      elsif Norm.model(column) && Norm.model(column).column_exists?(self.class.table_name)
        Norm.model(column)["where `#{self.class.table_name}` = #{id}"]
      end
    end
    
    def to_s
      id.to_s
    end
    
    def inspect
      "#{self.class.name}#{attributes.inspect}"
    end
  end

  module ClassMethods
    def columns
      Norm["show columns from `#{table_name}`"].map{|c| c["Field"].to_sym}
    end
    
    def last
      self[self * "order by id desc limit 1"]
    end
    
    def first
      self[self * "order by id asc limit 1"]
    end
    
    def all
      self[self * '']
    end
    
    def *(conditions)
      Norm["select * from `#{table_name}` #{conditions}"].simplify
    end
    
    def drop
      Norm.drop table_name
    end
    
    def [](request)
      if request.is_a? Array
        request.map{|i| self[i]}.simplify
      elsif request.is_a?(Hash) && request['id']
        self[request['id']]
      elsif request.is_a? Norm
        request
      elsif request.i?
        object = self.new request.to_i
        object.attributes ? object : nil
      else
        self[self * request]
      end
    end
    
    def column_exists?(column)
      columns.include?(column.to_sym)
    end
    
    def ensure_column(column)
      self + column unless column_exists?(column)
    end
    
    def +(column)
      Norm["alter table `#{table_name}` add column `#{column}` varchar(255)"]
      self
    end
    
    def -(column)
      Norm["alter table `#{table_name}` drop column `#{column}`"]
      self
    end
    
    def ensure_table
      create_table unless Norm.tables.include? table_name
    end
    
    def create_table
      Norm["create table `#{table_name}` (id int(11) NOT NULL AUTO_INCREMENT, PRIMARY KEY (id))"]
    end
    
    def table_name
      name.gsub(/^.+::/, '').underscore
    end
  end
end

N = Norm
