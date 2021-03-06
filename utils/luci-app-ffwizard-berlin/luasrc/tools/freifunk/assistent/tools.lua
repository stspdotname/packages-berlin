local sys = require "luci.sys"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local sharenet = uci:get("ffwizard","settings","sharenet")

module("luci.tools.freifunk.assistent.tools", package.seeall)

-- Deletes all references of a wifi device
function wifi_delete_ifaces(device)
	local cursor = uci.cursor()
	cursor:delete_all("wireless", "wifi-iface", {device=device})
	cursor:save("wireless")
end


-- Creates a firewall zone
function firewall_create_zone(zone, input, output, forward, masq)
	local cursor = uci.cursor()
	if not firewall_find_zone(zone) then
		logger("before create firewallzone")
		local stat = cursor:section("firewall", "zone", "zone_"..zone, {
			input = input,
			output = output,
			forward = forward,
			masq = masq and "1",
			name = zone
		})
		cursor:save("firewall")
		return stat
	else
		--logger("zone "..zone.." alread exists")
	end
end


function statistics_interface_add(mod, interface)
	local c = uci.cursor()
	local old = c:get("luci_statistics", mod, "Interfaces") or ""
	c:set("luci_statistics", mod, "Interfaces", old .. " " .. interface)
	c:save("luci_statistics")
end

-- Adds interface to zone, creates zone on-demand
function firewall_zone_add_interface(name, interface)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	local net = cursor:get("firewall", zone, "network")
	local old = net or (cursor:get("network", name) and name)
	cursor:set("firewall", zone, "network", (old and old .. " " or "") .. interface)
	cursor:save("firewall")
end


-- Adds masq src net to zone
function firewall_zone_add_masq_src(name, src)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	local old = cursor:get("firewall", zone, "masq_src") or {}
	table.insert(old,src)
	cursor:set_list("firewall", zone, "masq_src", old)
	cursor:save("firewall")
end


-- Removes interface from zone
function firewall_zone_remove_interface(name, interface)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	if zone then
		local net = cursor:get("firewall", zone, "network")
		local new = remove_list_entry(net, interface)
		if new then
			if #new > 0 then
				cursor:set("firewall", zone, "network", new)
			else
				cursor:delete("firewall", zone, "network")
			end
			cursor:save("firewall")
		end
	end
end


-- Finds the firewall zone with given name
function firewall_find_zone(name)
	local find

	uci.cursor():foreach("firewall", "zone",
		function (section)
			if section.name == name then
				find = section[".name"]
			end
		end)

	return find
end


-- Helpers --
-- Removes a listentry, handles real and pseduo lists transparently
function remove_list_entry(value, entry)
	if type(value) == "nil" then
		return nil
	end

	local result = type(value) == "table" and value or util.split(value, " ")
	local key = util.contains(result, entry)

	while key do
		table.remove(result, key)
		key = util.contains(result, entry)
	end

	result = type(value) == "table" and result or table.concat(result, " ")
	return result ~= value and result
end


function logger(msg)
        sys.exec("logger -t ffwizard -p 5 '"..msg.."'")
end
