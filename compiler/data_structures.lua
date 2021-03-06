--[[--------------------------------------------------------------------

  Gazelle: a system for building fast, reusable parsers

  data_structures.lua

  Implementations of useful data structures that we use often.
  Most of these are just useful interfaces around Lua's tables.

  Copyright (c) 2007-2008 Joshua Haberman.  See LICENSE for details.

--------------------------------------------------------------------]]--

require "misc"

-- Queue
define_class("Queue")
  function Queue:initialize(init)
    -- The elements themselves, indexed by numbers.
    -- The index self.first is the oldest member of the queue, self.last is
    -- the newest.
    self.elements = {}
    self.first = 0
    self.last  = -1

    if init then
      self:enqueue(init)
    end
  end

  function Queue:enqueue(val)
    self.last = self.last + 1
    self.elements[self.last] = val
  end

  function Queue:dequeue()
    if self:isempty() then error("Tried to dequeue an empty queue") end
    local val = self.elements[self.first]
    self.elements[self.first] = nil
    self.first = self.first + 1
    return val
  end

  function Queue:isempty()
    return self.first > self.last
  end
-- class Queue


-- Stack
define_class("Stack")
  function Stack:initialize(init)
    -- The elements on the stack, indexed by number.  Index '1' is the bottom
    -- of the stack (the first element that was pushed).
    self.stack = {}
  end

  function Stack:push(val)
    table.insert(self.stack, val)
  end

  function Stack:pop()
    return table.remove(self.stack)
  end

  function Stack:top()
    return self.stack[#self.stack]
  end

  function Stack:get(i)
    return self.stack[i]
  end

  function Stack:isempty()
    return #self.stack == 0
  end

  function Stack:count()
    return #self.stack
  end

  function Stack:dup()
    local new_stack = Stack:new_empty()
    new_stack.stack = table_shallow_copy(self.stack)
    return new_stack
  end

  function Stack:contains(elem)
    for e in each(self.stack) do
      if elem == e then
        return true
      end
    end
    return false
  end

  function Stack:each()
    return each(self.stack)
  end

  function Stack:to_array()
    local arr = {}
    for i, val in ipairs(self.stack) do
      table.insert(arr, val)
    end
    return arr
  end

  function Stack:tostring(indent)
    indent = indent or "  "
    local string = indent .. string.format("{Stack, %d elements:\n", self:count())
    local first = true
    local sub_indent = indent .. "  "
    for element in self:each() do
      if first then
        first = false
      else
        string = string .. ",\n"
      end
      string = string .. sub_indent .. serialize(element, 3, sub_indent)
    end
    string = string .. indent .. "}"
    return string
  end
-- class Stack


-- Set
define_class("Set")
  function Set:initialize(init)
    -- The elements of the set are the keys of self.elements.
    self.elements = {}

    if init then
      self:add_collection(init)
    end
  end

  function Set:sample()
    for element in self:each() do
      return element
    end
    return nil
  end

  function Set:contains(x)
    return self.elements[x] ~= nil
  end

  function Set:add(x)
    self.elements[x] = true
  end

  function Set:remove(x)
    self.elements[x] = nil
  end

  function Set:intersection(x)
    local new_set = Set:new()
    for element in each(x) do
      if self:contains(element) then
        new_set:add(element)
      end
    end
    return new_set
  end

  function Set:add_collection(arr)
    for elem in each(arr) do
      self:add(elem)
    end
  end

  function Set:each()
    return pairs(self.elements)
  end

  function Set:to_array()
    local arr = {}
    for elem in self:each() do
      table.insert(arr, elem)
    end
    return arr
  end

  function Set:isempty()
    return self:count() == 0
  end

  function Set:dup()
    local new_set = Set:new_empty()
    new_set.elements = table_shallow_copy(self.elements)
    return new_set
  end

  function Set:count()
    local i = 0
    for elem in self:each() do
      i = i + 1
    end
    return i
  end

  function Set:hash_key()
    local arr = self:to_array()
    for i=1,#arr do
      if isobject(arr[i]) and has_method(arr[i], "signature") then
        arr[i] = tostring(arr[i]:signature(true))
      else
        arr[i] = tostring(arr[i])
      end
    end

    table.sort(arr)

    local str = ""
    for elem in each(arr) do str = str .. elem end
    return str
  end

  function Set:tostring(indent)
    indent = indent or ""
    local string = indent .. string.format("{Set, %d elements: ", self:count())
    local first = true
    local sub_indent = indent .. "  "
    for element in self:each() do
      if first then
        string = string .. "\n"
        first = false
      else
        string = string .. ",\n"
      end
      string = string .. indent .. serialize(element, 3, sub_indent)
    end
    if not first then
      string = string .. indent
    end
    string = string .. "}"
    return string
  end
-- class Set

-- OrderedSet
define_class("OrderedSet")
  function OrderedSet:initialize(init)
    -- An ordered array of the set's elements.  This allows O(1) lookup of a
    -- given offset.
    self.elements = {}

    -- A map of {set element -> offset}.  This allows O(1) lookup of an offset
    -- by element.
    self.element_offsets = {}

    if init then
      for element in each(init) do
        self:add(element)
      end
    end
  end

  function OrderedSet:add(elem)
    if not self.element_offsets[elem] then
      table.insert(self.elements, elem)
      self.element_offsets[elem] = #self.elements
    end
  end

  function OrderedSet:count()
    return #self.elements
  end

  -- though this is against Lua convention, this method returns 0-based offsets,
  -- since this function is primarily used to generate the output byte-code
  -- file (which is based on 0-offsets).
  function OrderedSet:offset_of(elem)
    return self.element_offsets[elem] - 1
  end

  function OrderedSet:element_at(pos)
    return self.elements[pos]
  end

  function OrderedSet:sort(sort_func)
    table.sort(self.elements, sort_func)
    self.element_offsets = {}
    for i, element in ipairs(self.elements) do
      self.element_offsets[element] = i
    end
  end

  function OrderedSet:each()
    local i = 0
    return function ()
      i = i + 1
      if self.elements[i] then
        return self.elements[i]
      else
        return nil
      end
    end
  end

-- OrderedMap
-- NOTE: the map currently does not support deletion or replacement, only adding.
define_class("OrderedMap")
  function OrderedMap:initialize()
    -- An ordered array of {key, value} pairs that are the members of the set.
    -- This allows O(1) lookup of any element given its offset.
    self.elements = {}

    -- A map of {key -> element offset}.  This allows O(1) lookup of any
    -- element given its key.
    self.key_offsets = {}
  end

  function OrderedMap:add(key, value)
    if self.key_offsets[key] then
      error(string.format("Attempted to insert duplicate key '%s'", key))
    end
    table.insert(self.elements, {key, value})
    self.key_offsets[key] = #self.elements
  end

  function OrderedMap:get_or_insert_new(key, creator)
    if not self:contains(key) then
      self:add(key, creator())
    end
    return self:get(key)
  end

  function OrderedMap:insert_front(key, value)
    local new_key_offsets = {}
    for k, o in pairs(self.key_offsets) do
      new_key_offsets[k] = o + 1
    end
    self.key_offsets = new_key_offsets
    self.key_offsets[key] = 1
    table.insert(self.elements, 1, {key, value})
  end

  function OrderedMap:subset(predicate)
    local new_map = OrderedMap:new()
    for key, value in self:each() do
      if predicate(key, value) then
        new_map:add(key, value)
      end
    end
    return new_map
  end

  function OrderedMap:get(key)
    return self.elements[self.key_offsets[key]][2]
  end

  function OrderedMap:get_key_at_offset(offset)
    assert(offset <= self:count())
    return self.elements[offset][1]
  end

  -- though this is against Lua convention, this method returns 0-based offsets,
  -- since this function is primarily used to generate the output byte-code
  -- file (which is based on 0-offsets).
  function OrderedMap:offset_of_key(elem)
    return self.key_offsets[elem] - 1
  end

  function OrderedMap:contains(elem)
    return self.key_offsets[elem] ~= nil
  end

  function OrderedMap:count()
    return #self.elements
  end

  function OrderedMap:each()
    local i = 0
    return function ()
      i = i + 1
      if self.elements[i] then
        return unpack(self.elements[i])
      else
        return nil
      end
    end
  end

-- Range
-- The Range is *inclusive* at both ends.
define_class("Range")
  function Range:initialize(low, high)
    assert(low <= high)
    self.low = low
    self.high = high
  end

  function Range.union(a, b)
    if math.max(a.low, b.low) <= (math.min(a.high, b.high)+1) then
      return Range:new(math.min(a.low, b.low), math.max(a.high, b.high))
    else
      return nil
    end
  end

  function Range:contains(int)
    return (self.low <= int) and (self.high >= int)
  end

  function Range:tostring(display_val_func)
    if self.low == self.high then
      return display_val_func(self.low)
    else
      return display_val_func(self.low) .. "-" .. display_val_func(self.high)
    end
  end
-- class Range


-- IntSet
-- None of the ranges may overlap.
define_class("IntSet")
  function IntSet:initialize()
    self.list = {}
    self.negated = false
  end

  function IntSet:add(new_range)
    local newlist = {}
    for range in each(self.list) do
      local union = new_range:union(range)
      if union then
        new_range = union
      else
        table.insert(newlist, range)
      end
    end

    table.insert(newlist, new_range)
    self.list = newlist
  end

  function IntSet:get_non_negated()
    if self.negated then
      return self:invert()
    else
      return self
    end
  end

  -- This is O(n^2) right now, and can probably
  -- be made O(n lg n) with a little thought, but n's
  -- are so small right now that I won't worry.
  function IntSet:add_intset(intset)
    for range in each(intset.list) do
      self:add(range)
    end
  end

  function IntSet:contains(int)
    local obj = self:get_non_negated()
    for range in each(obj.list) do
      if range:contains(int) then return true end
    end
    return false
  end

  function IntSet:sampleint()
    local obj = self:get_non_negated()

    if #obj.list == 0 then
      return nil
    else
      return obj.list[1].low
    end
  end

  function IntSet:invert()
    local new_intset = IntSet:new()
    new_intset.negated = not self.negated

    table.sort(self.list, function (a, b) return a.low < b.low end)
    local offset = 0

    for range in each(self.list) do
      if offset <= range.low-1 then
        new_intset:add(Range:new(offset, range.low-1))
      end
      offset = range.high+1
    end

    if offset ~= math.huge then
      new_intset:add(Range:new(offset, math.huge))
    end

    return new_intset
  end

  function IntSet:each_range()
    return each(self:get_non_negated().list)
  end

  function IntSet:isunbounded()
    for range in each(self.list) do
      if range.high == math.huge then
        return true
      end
    end
    return false
  end

  function IntSet:tostring(display_val_func)
    local str = ""
    if self.negated then str = "^" end

    table.sort(self.list, function (a, b) return a.low < b.low end)
    local first = true
    for range in each(self.list) do
      if first then
        first = false
      else
        str = str .. ","
      end

      str = str .. range:tostring(display_val_func)
    end

    return str
  end

  function IntSet:toasciistring()
    local function convert_func(x)
      if x == math.huge then
        return "del"
      elseif x < 33 then
        return string.format("\\%03o", x)
      else
        return string.char(x)
      end
    end
    return self:tostring(convert_func)
  end

  function IntSet:tointstring()
    return self:tostring(function (x) return tostring(x) end)
  end
-- class IntSet

-- vim:et:sts=2:sw=2
