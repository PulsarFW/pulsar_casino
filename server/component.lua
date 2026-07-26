_casinoConfig = {}

_casinoConfigLoaded = false

CreateThread(function()
		TriggerEvent("Casino:Server:Startup")

		if GetConvar("casino_open", "false") == "true" then
			GlobalState["CasinoOpen"] = true
		else
			GlobalState["CasinoOpen"] = false
		end

		plsr.Callbacks:RegisterServerCallback("Casino:OpenClose", function(source, data, cb)
			if plsr.State:Player(source).onDuty == "casino" and data.state ~= GlobalState["CasinoOpen"] then
				GlobalState["CasinoOpen"] = data.state

				if GlobalState["CasinoOpen"] then
					plsr.Execute:Client(source, "Notification", "Success", "Casino Opened")
				else
					plsr.Execute:Client(source, "Notification", "Error", "Casino Closed")
				end
			else
				plsr.Execute:Client(source, "Notification", "Error", "Error Opening/Closing Casino")
			end
		end)

		plsr.Callbacks:RegisterServerCallback("Casino:BuyChips", function(source, amount, cb)
			local char = plsr.Fetch:CharacterSource(source)
			if char and amount and amount > 0 then
				local amount = math.floor(amount)
				if plsr.Wallet:Modify(source, -amount) then
					local total = plsr.Casino.Chips:Modify(source, amount)
					if total then
						SendCasinoPhoneNotification(
							source,
							string.format("Purchased $%s in Chips", formatNumberToCurrency(amount)),
							string.format("You now have a chip balance of $%s", formatNumberToCurrency(total))
						)

						return cb(true)
					end
				end
			end

			cb(false)
		end)

		plsr.Callbacks:RegisterServerCallback("Casino:SellChips", function(source, amount, cb)
			local char = plsr.Fetch:CharacterSource(source)
			if char and amount and amount > 0 then
				local amount = math.floor(amount)
				local chipTotal = plsr.Casino.Chips:Modify(source, -amount)
				if chipTotal then
					if plsr.Wallet:Modify(source, amount) then
						SendCasinoPhoneNotification(
							source,
							string.format("Cashed Out $%s of Chips", formatNumberToCurrency(amount)),
							string.format("You now have a chip balance of $%s", formatNumberToCurrency(chipTotal))
						)

						return cb(true)
					end
				end
			end

			cb(false)
		end)

		plsr.Callbacks:RegisterServerCallback("Casino:PurchaseVIP", function(source, amount, cb)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				if plsr.Wallet:Modify(source, -10000) then
					plsr.Inventory:AddItem(char:GetData("SID"), "diamond_vip", 1, {}, 1)
					GiveCasinoFuckingMoney(source, "VIP Card", 10000)
				else
					plsr.Execute:Client(source, "Notification", "Error", "Not Enough Cash")
				end
			end

			cb(true)
		end)

		plsr.Callbacks:RegisterServerCallback("Casino:GetBigWins", function(source, data, cb)
			if plsr.State:Player(source).onDuty == "casino" then
				EnsureCasinoTables(function()
					plsr.Database:Query("SELECT `data` FROM `casino_bigwins`", nil, function(success, rows)
						if not success or #rows == 0 then
							cb(false)
							return
						end
						local results = {}
						for k, row in ipairs(rows) do
							local ok, v = pcall(json.decode, row.data)
							if ok and type(v) == "table" then
								table.insert(results, v)
							end
						end
						cb(#results > 0 and results or false)
					end)
				end)
			else
				cb(false)
			end
		end)

		plsr.Chat:RegisterCommand("chips", function(source, args, rawCommand)
			local chipTotal = plsr.Casino.Chips:Get(source)

			SendCasinoPhoneNotification(
				source,
				"Current Chip Balance",
				string.format("Your current balance is $%s", formatNumberToCurrency(chipTotal))
			)
		end, {
			help = "Show Casino Chip Balance",
		})

		RunConfigStartup()
end)

local _configStartup = false
function RunConfigStartup()
	if not _configStartup then
		_configStartup = true

		EnsureCasinoTables(function()
			plsr.Database:Query("SELECT `key`, `data` FROM `casino_config`", nil, function(success, results)
				if success and #results > 0 then
					for k, row in ipairs(results) do
						local ok, decoded = pcall(json.decode, row.data)
						_casinoConfig[row.key] = (ok and decoded) or nil
					end
				end

				_casinoConfigLoaded = true
			end)
		end)
	end
end

_CASINO = {
	Chips = {
		Get = function(self, source)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				return char:GetData("CasinoChips") or 0
			end
			return 0
		end,
		Has = function(self, source, amount)
			local char = plsr.Fetch:CharacterSource(source)
			if char and amount > 0 then
				local currentChips = char:GetData("CasinoChips") or 0
				if currentChips >= amount then
					return true
				end
			end
			return false
		end,
		Modify = function(self, source, amount)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local currentChips = char:GetData("CasinoChips") or 0
				local newChipBalance = math.floor(currentChips + amount)
				if newChipBalance >= 0 then
					char:SetData("CasinoChips", newChipBalance)
					return newChipBalance
				end
			end
			return false
		end,
	},
	Config = {
		Set = function(self, key, data)
			local p = promise.new()

			EnsureCasinoTables(function()
				plsr.Database:Update(
					"INSERT INTO `casino_config` (`key`, `data`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)",
					{ key, json.encode(data) },
					function(success)
						if success then
							_casinoConfig[key] = data
							p:resolve(true)
						else
							p:resolve(false)
						end

						_casinoConfigLoaded = true
					end
				)
			end)

			local res = Citizen.Await(p)
			return res
		end,
		Get = function(self, key)
			return _casinoConfig[key]
		end,
	},
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Casino", _CASINO)
end)

function SendCasinoWonChipsPhoneNotification(source, amount)
	local chipTotal = plsr.Casino.Chips:Get(source)
	SendCasinoPhoneNotification(
		source,
		string.format("You Won $%s in Chips!", formatNumberToCurrency(amount)),
		string.format("Your balance is now $%s", formatNumberToCurrency(chipTotal))
	)
end

function SendCasinoSpentChipsPhoneNotification(source, amount)
	local chipTotal = plsr.Casino.Chips:Get(source)
	SendCasinoPhoneNotification(
		source,
		string.format("You Paid $%s in Chips!", formatNumberToCurrency(amount)),
		string.format("Your balance is now $%s", formatNumberToCurrency(chipTotal))
	)
end

function SendCasinoPhoneNotification(source, title, description, time)
	plsr.Phone.Notification:Add(source, title, description, os.time(), time or 7500, {
		color = "#18191e",
		label = "Casino",
		icon = "credit-card",
	}, {}, nil)
end

function GiveCasinoFuckingMoney(source, game, amount)
	local charInfo = "Unknown"
	local char = plsr.Fetch:CharacterSource(source)
	if char then
		charInfo = string.format("%s %s [%s]", char:GetData("First"), char:GetData("Last"), char:GetData("SID"))
	end

	local f = plsr.Banking.Accounts:GetOrganization("dgang")
	plsr.Banking.Balance:Deposit(f.Account, amount, {
		type = "deposit",
		title = game,
		description = string.format("%s Profit From %s", game, charInfo),
		data = {},
	}, true)

	if game == "Lucky Wheel" then
		amount = 100
		local f = plsr.Banking.Accounts:GetOrganization("casino")
		plsr.Banking.Balance:Deposit(f.Account, amount, {
			type = "deposit",
			title = game,
			description = string.format("%s Profit From %s", game, charInfo),
			data = {},
		}, true)
	end
end
