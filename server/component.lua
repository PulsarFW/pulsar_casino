_casinoConfig = {}

_casinoConfigLoaded = false

AddEventHandler('onResourceStart', function(resource)
  if resource == GetCurrentResourceName() then
    Wait(1000)
    exports['pulsar-core']:VersionCheck('PulsarFW/pulsar-casino')

    TriggerEvent("Casino:Server:Startup")
    if GetConvar("casino_open", "false") == "true" then
      GlobalState["CasinoOpen"] = true
    else
      GlobalState["CasinoOpen"] = false
    end

    exports["pulsar-core"]:RegisterServerCallback("Casino:OpenClose", function(source, data, cb)
      if Player(source).state.onDuty == "casino" and data.state ~= GlobalState["CasinoOpen"] then
        GlobalState["CasinoOpen"] = data.state

        if GlobalState["CasinoOpen"] then
          exports['pulsar-hud']:Notification(source, "success", "Casino Opened")
        else
          exports['pulsar-hud']:Notification(source, "error", "Casino Closed")
        end
      else
        exports['pulsar-hud']:Notification(source, "error", "Error Opening/Closing Casino")
      end
    end)

    exports["pulsar-core"]:RegisterServerCallback("Casino:BuyChips", function(source, amount, cb)
      local char = exports['pulsar-characters']:FetchCharacterSource(source)
      if char and amount and amount > 0 then
        local amount = math.floor(amount)
        if exports['pulsar-finance']:WalletModify(source, -amount) then
          local total = exports['pulsar-casino']:ChipsModify(source, amount)
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

    exports["pulsar-core"]:RegisterServerCallback("Casino:SellChips", function(source, amount, cb)
      local char = exports['pulsar-characters']:FetchCharacterSource(source)
      if char and amount and amount > 0 then
        local amount = math.floor(amount)
        local chipTotal = exports['pulsar-casino']:ChipsModify(source, -amount)
        if chipTotal then
          if exports['pulsar-finance']:WalletModify(source, amount) then
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

    exports["pulsar-core"]:RegisterServerCallback("Casino:PurchaseVIP", function(source, amount, cb)
      local char = exports['pulsar-characters']:FetchCharacterSource(source)
      if char then
        if exports['pulsar-finance']:WalletModify(source, -10000) then
          exports.ox_inventory:AddItem(source, "diamond_vip", 1, {}, 1)
          DepositCasinoProfit(source, "VIP Card", 10000)
        else
          exports['pulsar-hud']:Notification(source, "error", "Not Enough Cash")
        end
      end

      cb(true)
    end)

    exports["pulsar-core"]:RegisterServerCallback("Casino:GetBigWins", function(source, data, cb)
      if Player(source).state.onDuty == "casino" then
        exports.oxmysql:execute('SELECT * FROM casino_bigwins', {}, function(results)
          if results and #results > 0 then
            cb(results)
          else
            cb(false)
          end
        end)
      else
        cb(false)
      end
    end)

    exports["pulsar-chat"]:RegisterCommand("chips", function(source, args, rawCommand)
      local chipTotal = exports['pulsar-casino']:ChipsGet(source)

      SendCasinoPhoneNotification(
        source,
        "Current Chip Balance",
        string.format("Your current balance is $%s", formatNumberToCurrency(chipTotal))
      )
    end, {
      help = "Show Casino Chip Balance",
    })

    RunConfigStartup()
  end
end)

local _configStartup = false
function RunConfigStartup()
  if not _configStartup then
    _configStartup = true

    exports.oxmysql:execute('SELECT * FROM casino_config', {}, function(results)
      if results and #results > 0 then
        for k, v in ipairs(results) do
          _casinoConfig[v.key] = v.data
        end
      end

      _casinoConfigLoaded = true
    end)
  end
end

exports("ChipsGet", function(source)
  local char = exports['pulsar-characters']:FetchCharacterSource(source)
  if char then
    return char:GetData("CasinoChips") or 0
  end
  return 0
end)

exports("ChipsHas", function(source, amount)
  local char = exports['pulsar-characters']:FetchCharacterSource(source)
  if char and amount > 0 then
    local currentChips = char:GetData("CasinoChips") or 0
    if currentChips >= amount then
      return true
    end
  end
  return false
end)

exports("ChipsModify", function(source, amount)
  local char = exports['pulsar-characters']:FetchCharacterSource(source)
  if char then
    local currentChips = char:GetData("CasinoChips") or 0
    local newChipBalance = math.floor(currentChips + amount)
    if newChipBalance >= 0 then
      char:SetData("CasinoChips", newChipBalance)
      return newChipBalance
    end
  end
  return false
end)

exports("ConfigSet", function(key, data)
  local p = promise.new()

  exports.oxmysql:execute(
    'INSERT INTO casino_config (`key`, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = ?',
    { key, json.encode(data), json.encode(data) },
    function(affectedRows)
      local success = affectedRows > 0
      if success then
        _casinoConfig[key] = data
        p:resolve(true)
      else
        p:resolve(false)
      end

      _casinoConfigLoaded = true
    end)

  local res = Citizen.Await(p)
  return res
end)

exports("ConfigGet", function(key)
  return _casinoConfig[key]
end)

function SendCasinoWonChipsPhoneNotification(source, amount)
  local chipTotal = exports['pulsar-casino']:ChipsGet(source)
  SendCasinoPhoneNotification(
    source,
    string.format("You Won $%s in Chips!", formatNumberToCurrency(amount)),
    string.format("Your balance is now $%s", formatNumberToCurrency(chipTotal))
  )
end

function SendCasinoSpentChipsPhoneNotification(source, amount)
  local chipTotal = exports['pulsar-casino']:ChipsGet(source)
  SendCasinoPhoneNotification(
    source,
    string.format("You Paid $%s in Chips!", formatNumberToCurrency(amount)),
    string.format("Your balance is now $%s", formatNumberToCurrency(chipTotal))
  )
end

function SendCasinoPhoneNotification(source, title, description, time)
  exports['pulsar-phone']:NotificationAdd(source, title, description, os.time(), time or 7500, {
    color = "#18191e",
    label = "Casino",
    icon = "cards",
  }, {}, nil)
end

function DepositCasinoProfit(source, game, amount)
  local charInfo = "Unknown"
  local char = exports['pulsar-characters']:FetchCharacterSource(source)
  if char then
    charInfo = string.format("%s %s [%s]", char:GetData("First"), char:GetData("Last"), char:GetData("SID"))
  end

  local f = exports['pulsar-finance']:AccountsGetOrganization("dgang")
  exports['pulsar-finance']:BalanceDeposit(f.Account, amount, {
    type = "deposit",
    title = game,
    description = string.format("%s Profit From %s", game, charInfo),
    data = {},
  }, true)

  if game == "Lucky Wheel" then
    amount = 100
    local f = exports['pulsar-finance']:AccountsGetOrganization("casino")
    exports['pulsar-finance']:BalanceDeposit(f.Account, amount, {
      type = "deposit",
      title = game,
      description = string.format("%s Profit From %s", game, charInfo),
      data = {},
    }, true)
  end
end
