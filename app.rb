system("clear") 
@countries = [
  { code: "NLD", name: "Netherlands" },
  { code: "ALB", name: "Albania" },
  { code: "AND", name: "Andorra" },
  { code: "BEL", name: "Belgium" },
  { code: "GER", name: "Germany" },                 # No match
  { code: "BIH", name: "Bosnia and Herzegovina" }
]

@cities = [
  { country_code: "ALB", name: "Tirana" },
  { country_code: "AND", name: "Andorra la Vella" },
  { country_code: "BEL", name: "Schaerbeek" },
  { country_code: "BEL", name: "Brugge" },
  { country_code: "BIH", name: "Zenica" },
  { country_code: "BIH", name: "Banja Luka" },
  { country_code: "BIH", name: "Sarajevo" },
  { country_code: "NLD", name: "Alkmaar" },
  { country_code: "NLD", name: "Ede" },
  { country_code: "POL", name: "Krakow" }            # No match
]

#+ ([ { country_code: "XXX", name: "Ede" } ] * 10)

@cities_code_index = @cities.inject({}) do |memo, city|
  memo[city[:country_code]] ||= []
  memo[city[:country_code]] << @cities.index(city)
  memo
end

@cities_name_index = @cities.inject({}) do |memo, city|
  memo[city[:name]] ||= []
  memo[city[:name]] << @cities.index(city)
  memo
end

# SELECT country.code from country inner join city on country.code = city.countrycode where country.code in ('NLD', 'ALB', 'GER', 'AND', 'BEL', 'BIH');

# Nested loop

# * has no upstart cost, makes it super efficent for few rows
# * can get very expensive quickly (number iterations is product of both tables)
# * first place to look in explain analyze is estimated rows vs actual rows

results = []
i = 0

@countries.each do |country|
  @cities.each do |city|
    i = i + 1
    results << country if city[:country_code] == country[:code]
  end
end

puts "Nested loop (#{i} iterations):"
puts results.map {|country| country[:code]}.inspect
puts "============"

#  For each row r in R do
#     For each row s in S do
#        If r and s satisfy the join condition
#           Then output the row <r,s>


# Hash join

# * requires building a hash structure in advance (time and memory)
# * the less columns to join on the better
# * will always use smaller table to build a hash
# * order of joins doesn't matter
# * supports only == operator

results = []
i = 0

temp_hash = @cities.inject(Hash.new([])) do |memo, city|
  memo[city[:country_code]] = memo[city[:country_code]] + [city]
  memo
end

@countries.each do |country|
  temp_hash[country[:code]].each do
    i = i + 1
    results << country
  end
end

temp_hash = nil

puts "Hash join (#{i} iterations):"
puts results.map {|country| country[:code]}.inspect
puts "============"

# for each row R1 in the build table
#     begin
#         calculate hash value on R1 join key(s)
#         insert R1 into the appropriate hash bucket
#     end
# for each row R2 in the probe table
#     begin
#         calculate hash value on R2 join key(s)
#         for each row R1 in the corresponding hash bucket
#             if R1 joins with R2
#                 return (R1, R2)
#     end


# Merge join

# * at most sum of rows in both inputs
# * show by adding some XXX cities
# * has to be sorted, but can use indexes if available
# * does not support != operator

results = []
i = 0

sorted_countries = @countries.sort_by {|country| country[:code]}
sorted_cities    = @cities.sort_by {|city| city[:country_code]}

x = 0
y = 0

loop do
  i = i + 1
  country = sorted_countries[x]
  city    = sorted_cities[y]

  if country[:code] == city[:country_code]
    results << country
    y = y + 1
  elsif country[:code] < city[:country_code]
    x = x + 1
  elsif country[:code] > city[:country_code]
    y = y + 1
  end

  break if (sorted_countries[x].nil? || sorted_cities[y].nil?)
end

puts "Merge join (#{i} iterations):"
puts results.map {|country| country[:code]}.inspect
puts "============"

# get first row R1 from input 1
# get first row R2 from input 2
# while not at the end of either input
#     begin
#         if R1 joins with R2
#             begin
#                 return (R1, R2)
#                 get next row R2 from input 2
#             end
#         else if R1 < R2
#             get next row R1 from input 1
#         else
#             get next row R2 from input 2
#     end


# AGGREGATES
# SELECT count(*), countrycode from city group by countrycode;

# * require sorted input by all columns (order doesn't matter)

results = []
i = 0

sorted_cities     = @cities.sort_by {|city| city[:country_code]}
current_aggregate = {}

sorted_cities.each do |row|
  i = i + 1

  if (current_aggregate[:country_code] != row[:country_code]) # Input row does not match current group
    unless current_aggregate[:count].nil?                      # Initial aggregate is empty so we skip it
      results << current_aggregate                             # Output current aggregate to the results
    end
    current_aggregate = {}                                     # Clear current aggregate (start new one)
  end

  # Update current aggregate
  current_aggregate[:country_code] = row[:country_code]
  current_aggregate[:count]        = current_aggregate[:count].to_i + 1
end

results << current_aggregate # Output final aggregate to results (the loop has skipped it)
                             # Don't increase iterations, it's part of the very final one


puts "Aggregates (#{i} iterations):"
puts results.inspect
puts "============"

# clear the current aggregate results
# clear the current group by columns
# for each input row
#   begin
#     if the input row does not match the current group by columns
#       begin
#         output the aggregate results
#         clear the current aggregate results
#         set the current group by columns to the input row
#       end
#     update the aggregate results with the input row
#   end


# ACCESS PATTERNS
# SELECT * from city where country_code = 'BEL'

# Sequential scan

results = []
i = 0

@cities.each do |city|
  i = i + 1

  results << city if city[:country_code] == 'BEL'
end

puts "Sequential scan (#{i} iterations):"
puts results.inspect
puts "============"


# Index scan

# * index will be read sequentially, is much smaller than table
# * table will be accessed randomly (slow)
# * table will be accessed as the index is traversed (can read same page few times - should be in cache, but could as well be wiped already)

results = []
i = 0

@cities_code_index['BEL'].each do |row_position|
  i = i + 1

  results << @cities[row_position]
end

puts "Index scan (#{i} iterations):"
puts results.inspect
puts "============"


# Bitmap scan

# SELECT * from city where country_code = 'BEL' or name = 'Tirana' or name = 'Brugge';

# * requires building a bitmap
# * sorts bitmap to optimize access, any data ordering is lost
# * can merge multiple bitmaps
# * table page is accessed at most once
# * bitmap does lossy or exact scan, depending on the estimation. Lossy requires extra filtering because
#   it contains addresses to pages rather than rows
# * with multiple indexes used we lose information what index contained the information so statistics
#   for each index are increased
# * if there was order by in the query it will require separate sort (extra cost)

results = []
i = 0

# Prepare the bitmaps
name_bitmap_tirana = @cities_name_index['Tirana']
name_bitmap_brugge = @cities_name_index['Brugge']
code_bitmap_bel    = @cities_code_index['BEL']

# Merge the bitmaps (this is OR so we can union it
merged_bitmap = name_bitmap_tirana | name_bitmap_brugge | code_bitmap_bel

# Sort it to optimize disk access
sorted_bitmap = merged_bitmap.sort

# Read the table rows
sorted_bitmap.each do |row_position|
  i = i + 1
  results << @cities[row_position]
end

puts "Bitmap index scan (#{i} iterations):"
puts results.inspect
puts "============"


### HINTS FOR QUERY PLANNER (CHEATS)

# Since Query Planners relies on statistics to choose the right algorithm and since statistics are based
# on random sample of our data sometimes it can be inaccurate.


## Prevent using an index

# world=# explain analyze select * from city where countrycode = 'POL';
#                                                           QUERY PLAN                                                           
# -------------------------------------------------------------------------------------------------------------------------------
#  Index Scan using idx_city_countrycode on city  (cost=0.28..22.87 rows=44 width=31) (actual time=0.031..0.044 rows=44 loops=1)
#    Index Cond: (countrycode = 'POL'::bpchar)
#  Total runtime: 0.075 ms
# (3 rows)


# world=# explain analyze select * from city where countrycode = concat('POL');
#                                                            QUERY PLAN                                                           
# ---------------------------------------------------------------------------------------------------
#  Seq Scan on city  (cost=0.00..135.38 rows=20 width=31) (actual time=6.926..9.500 rows=44 loops=1)
#    Filter: ((countrycode)::text = concat('POL'))
#    Rows Removed by Filter: 4035
#  Total runtime: 9.546 ms
# (4 rows)

# QP have no statistics about expressions (unless we have an expression index), so it guesses default estimations.



## Giving a hint on number of rows expected

# world=# explain analyze select * from city where countrycode = concat('POL');
#                                             QUERY PLAN                                             
# ---------------------------------------------------------------------------------------------------
#  Seq Scan on city  (cost=0.00..135.38 rows=20 width=31) (actual time=7.154..8.968 rows=44 loops=1)
#    Filter: ((countrycode)::text = concat('POL'))
#    Rows Removed by Filter: 4035
#  Total runtime: 9.011 ms
# (4 rows)


# world=# explain analyze select * from city where countrycode = concat('POL') limit 1;
#                                                QUERY PLAN                                               
# --------------------------------------------------------------------------------------------------------
#  Limit  (cost=0.00..6.77 rows=1 width=31) (actual time=7.254..7.255 rows=1 loops=1)
#    ->  Seq Scan on city  (cost=0.00..135.38 rows=20 width=31) (actual time=7.252..7.252 rows=1 loops=1)
#          Filter: ((countrycode)::text = concat('POL'))
#          Rows Removed by Filter: 2994
#  Total runtime: 7.297 ms
# (5 rows)

# We know there is only one row matching the condition so we give a hint to fetch only one row and stop
# processing once it's found. Without the limit postgres would fetch all rows (see how many were removed by filter).




# CREATE INDEX idx_countrylanguage_language ON countrylanguage (language text_pattern_ops);
# ANALYZE;


# CREATE OR REPLACE FUNCTION parse_explain(IN query text, 
# -- http://stackoverflow.com/questions/7682102/putting-explain-results-into-a-table
# OUT startup numeric,
# OUT totalcost numeric, 
# OUT planrows numeric, 
# OUT planwidth numeric,
# OUT type text)
# AS
# $BODY$
# DECLARE
#     query_explain  text;
#     explanation       xml;
#     nsarray text[][];
# BEGIN
# nsarray := ARRAY[ARRAY['x', 'http://www.postgresql.org/2009/explain']];
# query_explain :=e'EXPLAIN(FORMAT XML) ' || query;
# EXECUTE query_explain INTO explanation;
# startup := (xpath('/x:explain/x:Query/x:Plan/x:Startup-Cost/text()', explanation, nsarray))[1];
# totalcost := (xpath('/x:explain/x:Query/x:Plan/x:Total-Cost/text()', explanation, nsarray))[1];
# planrows := (xpath('/x:explain/x:Query/x:Plan/x:Plan-Rows/text()', explanation, nsarray))[1];
# planwidth := (xpath('/x:explain/x:Query/x:Plan/x:Plan-Width/text()', explanation, nsarray))[1];
# type      := (xpath('/x:explain/x:Query/x:Plan/x:Node-Type/text()', explanation, nsarray))[1];
# RETURN;
# END;
# $BODY$
# LANGUAGE plpgsql;



# with langs as (
#   select count(*), language from countrylanguage group by 2 order by 1 desc
# ),
# queries as (
#   select sub.planrows as plan_count, sub.type, sub.totalcost, langs.language, count as real_count
#   from langs
#   inner join lateral ( select totalcost, langs.language, planrows, type
#                        from parse_explain(concat(E'select * from countrylanguage where language = \'', langs.language, E'\'')) ) sub
#   on langs.language = sub.language
# )
# select language, real_count, plan_count, totalcost, type from queries;
#
#
#          language          | real_count | plan_count | totalcost |       type       
# ---------------------------+------------+------------+-----------+------------------
#  English                   |         60 |         60 |     11.49 | Bitmap Heap Scan
#  Arabic                    |         33 |         33 |     10.94 | Bitmap Heap Scan
#  Spanish                   |         28 |         28 |     10.84 | Bitmap Heap Scan
#  French                    |         25 |         25 |     10.78 | Bitmap Heap Scan
#     -- snap --                  -- snap --                  -- snap --
#  Wolof                     |          3 |          3 |      9.97 | Bitmap Heap Scan
#  Shona                     |          3 |          3 |      9.97 | Bitmap Heap Scan
#  Gurma                     |          3 |          3 |      9.97 | Bitmap Heap Scan
#  Hebrew                    |          2 |          1 |      8.29 | Index Scan
#  Arawakan                  |          2 |          1 |      8.29 | Index Scan
#  Teke                      |          2 |          1 |      8.29 | Index Scan
#  Papuan Languages          |          2 |          1 |      8.29 | Index Scan
#
#
#
#
# (984 records in total)
#
