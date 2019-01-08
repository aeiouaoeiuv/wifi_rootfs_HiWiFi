-- Copyright (c) 2013 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local luci_util = require "luci.util"
local tonumber = tonumber

module "hiwifi.traffic_stats"
local traffic = luci_util.get_traffic_total()

function read_stats()	-- 单位 b
  if traffic['up'] then
	  return {
	    rx_bps = tonumber(traffic['down'])*1024,
	    tx_bps = tonumber(traffic['up'])*1024
	  }
  end
  return 
  {
    rx_bps = 0,
    tx_bps = 0
  }
end