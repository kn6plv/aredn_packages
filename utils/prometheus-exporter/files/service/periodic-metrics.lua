#!/usr/bin/lua
--[[

	Part of AREDN -- Used for creating Amateur Radio Emergency Data Networks
	Copyright (C) 2023 Tim Wilkinson
	See Contributors file for additional contributors

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation version 3 of the License.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

	Additional Terms:

	Additional use restrictions exist on the AREDN(TM) trademark and logo.
		See AREDNLicense.txt for more info.

	Attributions to the AREDN Project must be retained in the source code.
	If importing this code into a new or existing project attribution
	to the AREDN project must be added to the source code.

	You must not misrepresent the origin of the material contained within.

	Modified versions must be modified to attribute to the original source
	and be marked in reasonable ways as differentiate it from the original
	version

--]]

local info = require("aredn.info")

local metrics_conf = "/etc/metrics.conf"
local metrics_data = "/tmp/periodic-metrics"
local metrics_periodics = "/usr/local/bin/metrics/periodics"
local M = {}

function M.periodic_metrics()
	-- Only run if we have a configuration
	if not nixio.fs.stat(metrics_conf) then
		exit_app()
		return
	end

	local periodics = {}
	for name in nixio.fs.dir(metrics_periodics)
	do
		local task = name:match("^(.+)%.lua$")
		if task then
			periodics[#periodics + 1] = require("metrics.periodics." .. task)
		end
	end

	local metrics = {}

	-- Read the configuration
	local conf = {}
	for line in io.lines(metrics_conf)
	do
		local freq, name, arg = line:match("^%s*(%a*)%s+(%S+)%s+(%S+)%s*$")
		if freq then
			conf[#conf + 1] = { frequency = freq, name = name, arg = arg }
		end
	end

	-- Run once per hour, but signal each 24 hour period
	local count = 0
	while true
    do
		-- Call each periodic in turn
		local options = { is_daily = (count == 0) }
		for _, periodic in ipairs(periodics)
		do
			periodic(conf, metrics, options)
		end

		-- Update metrics data for async retrieval
		f = io.open(metrics_data, "w")
		if f then
			local keys = {}
			for k, _ in pairs(metrics)
			do
				keys[#keys + 1] = k
			end
			table.sort(keys)
			for _, k in ipairs(keys)
			do
				f:write(k .. " " .. metrics[k])
			end
			f:close()
		end

		count = (count + 1) % 24
        wait_for_ticks(60 * 60) -- 1 hour
    end
end

return M.periodic_metrics
