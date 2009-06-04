require 'norm'
def assert(assertion) raise unless assertion end

Norm.database = 'norm'
assert N == Norm

N.tables.each{|m| N.drop m}
assert N.tables.empty? #Empty hat, no rabbit

module Norm
  assert !const_defined?(:Table)
  table = Table.new :material => "wood"
  assert Table.last == table
  assert Table.first == table
  assert Table.all == table
  
  assert Table.last.material == "wood"
  assert Table[table.id].material == "wood"
  assert Table["where id = #{table.id}"].material == "wood"
  assert Table["where material = 'wood'"] == table
  assert Table["where material = 'squid'"].nil?
  
  assert !const_defined?(:Chair)
  chair = Chair.new :variety => "stool", :table => table
  assert chair.table == table
  assert table.chair == chair
  
  second_chair = Chair.new :variety => 'lounge', :table => table
  assert table.chair.include?(second_chair) && table.chair.include?(chair)
  assert Chair.all == table.chair
  assert chair.table == second_chair.table
  
  assert chair.table
  Chair - 'table' #remove the column
  assert chair.table.nil?
  assert !chair.attributes.keys.include?('table')
  assert chair.attributes.keys.include?('variety')
  assert ["id", "variety"] == Chair.columns.map{|c| c.to_s}.sort
  Chair + 'table' + 'material' - 'variety'#add the column back, add a new column (material), and remove variety
  assert ["id", "material", "table"] == Chair.columns.map{|c| c.to_s}.sort
end