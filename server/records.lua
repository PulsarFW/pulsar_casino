local _casinoTablesReady = false
function EnsureCasinoTables(callback)
    if _casinoTablesReady then
        if callback then
            callback()
        end
        return
    end
    plsr.Database:Query(
        "CREATE TABLE IF NOT EXISTS `casino_statistics` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `sid` BIGINT UNSIGNED NOT NULL, `data` JSON NOT NULL, UNIQUE INDEX `idx_sid` (`sid`))",
        nil,
        function()
            plsr.Database:Query(
                "CREATE TABLE IF NOT EXISTS `casino_bigwins` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `data` JSON NOT NULL)",
                nil,
                function()
                    plsr.Database:Query(
                        "CREATE TABLE IF NOT EXISTS `casino_config` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `key` VARCHAR(191) NOT NULL, `data` JSON NULL, UNIQUE INDEX `idx_key` (`key`))",
                        nil,
                        function()
                            _casinoTablesReady = true
                            if callback then
                                callback()
                            end
                        end
                    )
                end
            )
        end
    )
end

function UpdateCharacterCasinoStats(source, statType, isWin, amount)
    local char = plsr.Fetch:CharacterSource(source)
    if char then
        local p = promise.new()
        local sid = char:GetData("SID")

        EnsureCasinoTables(function()
            plsr.Database:Single("SELECT `id`, `data` FROM `casino_statistics` WHERE `sid` = ?", { sid }, function(success, row)
                local stats = { SID = sid }
                local rowId = nil
                if success and row ~= nil then
                    rowId = row.id
                    local ok, decoded = pcall(json.decode, row.data)
                    if ok and type(decoded) == "table" then
                        stats = decoded
                    end
                end

                if not stats[statType] then
                    stats[statType] = {}
                end
                table.insert(stats[statType], { Win = isWin, Amount = amount })

                if isWin then
                    stats.TotalAmountWon = (stats.TotalAmountWon or 0) + amount
                    if not stats.AmountWon then
                        stats.AmountWon = {}
                    end
                    stats.AmountWon[statType] = (stats.AmountWon[statType] or 0) + amount
                else
                    stats.TotalAmountLost = (stats.TotalAmountLost or 0) + amount
                    if not stats.AmountLost then
                        stats.AmountLost = {}
                    end
                    stats.AmountLost[statType] = (stats.AmountLost[statType] or 0) + amount
                end

                if rowId then
                    plsr.Database:Update("UPDATE `casino_statistics` SET `data` = ? WHERE `id` = ?", { json.encode(stats), rowId }, function(updateSuccess)
                        p:resolve(updateSuccess and stats or false)
                    end)
                else
                    plsr.Database:Insert("INSERT INTO `casino_statistics` (`sid`, `data`) VALUES (?, ?)", { sid, json.encode(stats) }, function(insertSuccess)
                        p:resolve(insertSuccess and stats or false)
                    end)
                end
            end)
        end)

        local res = Citizen.Await(p)
        return res
    end
    return false
end

function SaveCasinoBigWin(source, machine, prize, data)
    local char = plsr.Fetch:CharacterSource(source)
    if char then
        local p = promise.new()

        local doc = {
            Type = machine,
            Time = os.time(),
            Winner = {
                SID = char:GetData("SID"),
                First = char:GetData("First"),
                Last = char:GetData("Last"),
                ID = char:GetData("ID"),
            },
            Prize = prize,
            MetaData = data,
        }

        EnsureCasinoTables(function()
            plsr.Database:Insert("INSERT INTO `casino_bigwins` (`data`) VALUES (?)", { json.encode(doc) }, function(success)
                p:resolve(success)
            end)
        end)

        local res = Citizen.Await(p)
        return res
    end
    return false
end
