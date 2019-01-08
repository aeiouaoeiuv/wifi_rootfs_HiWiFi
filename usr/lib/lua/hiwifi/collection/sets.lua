-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local pairs, table = pairs, table

module "hiwifi.collection.sets"

function add(set, value)
  set[value] = true
end

function remove(set, value)
  set[value] = nil
end

function contains(set, value)
  return set[value] or false
end

function to_list(set)
  local list = {}
  for k, _ in pairs(set) do
    table.insert(list, k)
  end
  return list
end

function from_list(list)
  local set = {}
  for _, value in pairs(list) do
    set[value] = true
  end
  return set
end
