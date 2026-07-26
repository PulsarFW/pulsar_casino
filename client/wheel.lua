_casinoWheel = nil
_casinoWheelRotation = vec3(-0.000000, 9.000000, -31.843399)


_spinningWheel = false

AddEventHandler("Casino:Client:Startup", function()
    plsr.Targeting.Zones:AddBox("casino-wheelspin", "arrows-spin", vector3(989.45, 42.64, 71.27), 1.0, 1.2, {
        heading = 330,
        --debugPoly=true,
        minZ = 70.47,
        maxZ = 73.27
    }, {
        {
            icon = "face-tongue-money",
            text = "Spin the Wheel! ($1,500)",
            event = "Casino:Client:StartSpin",
            isEnabled = function()
                return GlobalState["CasinoOpen"] and not GlobalState["Casino:WheelStarted"] and not GlobalState["Casino:WheelSpinning"] and not GlobalState["Casino:WheelLocked"]
            end,
        },
        {
            icon = "gift-card",
            text = "VIP Turbo Spin ($7,500)",
            event = "Casino:Client:StartSpin",
            data = { turbo = true },
            isEnabled = function()
                return GlobalState["CasinoOpen"] and not GlobalState["Casino:WheelStarted"] and not GlobalState["Casino:WheelSpinning"] and not GlobalState["Casino:WheelLocked"]
            end,
        },
        {
            icon = "unlock",
            text = "Unlock Wheel",
            event = "Casino:Client:UnlockWheel",
            jobPerms = {
                {
                    job = "casino",
                    reqDuty = true,
                }
            },
            isEnabled = function()
                return GlobalState["Casino:WheelLocked"]
            end,
        },
    }, 2.0, true)
end)

AddEventHandler("Casino:Client:UnlockWheel", function()
    plsr.Callbacks:ServerCallback("Casino:UnlockWheel", {}, function(success)
        if success then
            plsr.Notification:Success("Wheel Unlocked")
        else
            plsr.Notification:Error("Error")
        end
    end)
end)

AddEventHandler("Casino:Client:StartSpin", function(_, data)
    plsr.Callbacks:ServerCallback("Casino:WheelStart", data, function(success, tooPoor)
        if success then
            plsr.State.flags.playingCasino = true

            plsr.Animations.Emotes:ForceCancel()
            plsr.Weapons:UnequipIfEquippedNoAnim()

            local _lib = "anim_casino_a@amb@casino@games@lucky7wheel@male"
            -- if IsPedMale(playerPed) then
            --     _lib = "anim_casino_a@amb@casino@games@lucky7wheel@female"
            -- end

            local lib, anim = _lib, "enter_right_to_baseidle"
            loadAnim(lib)

            local _movePos = vector3(989.009155, 42.640945, 71.265236)
            TaskGoStraightToCoord(PlayerPedId(), _movePos.x, _movePos.y, _movePos.z, 1.0, -1, 34.52, 0.0)

            while #(GetEntityCoords(PlayerPedId()) - _movePos) > 0.1 do
                Wait(10)
            end

            SetEntityHeading(PlayerPedId(), 327.937)
            TaskPlayAnim(PlayerPedId(), lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)

            while IsEntityPlayingAnim(PlayerPedId(), lib, anim, 3) do
                Wait(1)
                DisableAllControlActions(0)
            end

            TaskPlayAnim(PlayerPedId(), lib, "enter_to_armraisedidle", 8.0, -8.0, -1, 0, 0, false, false, false)

            while IsEntityPlayingAnim(PlayerPedId(), lib, "enter_to_armraisedidle", 3) do
                Wait(1)
                DisableAllControlActions(0)
            end

            plsr.Callbacks:ServerCallback("Casino:WheelSpin", {})

            TaskPlayAnim(PlayerPedId(), lib, "armraisedidle_to_spinningidle_high", 8.0, -8.0, -1, 0, 0, false, false, false)

            plsr.State.flags.playingCasino = false
        else
            if tooPoor then
                if data.turbo then
                    plsr.Notification:Error("Not Enough Cash or No VIP Card")
                else
                    plsr.Notification:Error("Not Enough Cash")
                end
            end
        end
    end)
end)

function CreateCasinoWheel()
    DeleteCasinoWheel()

    loadModel(`vw_prop_vw_luckywheel_02a`)
    _casinoWheel = CreateObject(`vw_prop_vw_luckywheel_02a`, vec3(990.276062, 42.839146, 70.52), false, false)
    --SetEntityHeading(_casinoWheel, 328.15661621094)
    FreezeEntityPosition(_casinoWheel, true)

    local lastSpinRotation = GlobalState["Casino:WheelLastRotation"] or 0.0
    SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - lastSpinRotation, _casinoWheelRotation.z, 2, true)
end

function DeleteCasinoWheel()
    if _casinoWheel then
        DeleteEntity(_casinoWheel)
        _casinoWheel = nil
    end
end

RegisterNetEvent("Casino:Client:SpinWheel", function(target, spins, offset)
    if _insideCasino then
        if _spinningWheel then
            _spinningWheel = false
        end

        Wait(10)

        _spinningWheel = true
        CreateThread(function()
            -- local sliceWidth = 360.0 / 20
            -- local finalRotation = (sliceWidth * target) - offset
    
            -- if finalRotation < 40.0 then
            --     minWheelSpeed = 1
            -- end
    
            -- --SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - finalRotation, _casinoWheelRotation.z, 2, true)
    
            -- local spinning = true
            -- local doneSpins = 0
            local addedRotation = 0.0
    
            while _insideCasino and _spinningWheel do
                addedRotation += 25.0
                --print(addedRotation, wheelSpeed)
    
                if addedRotation >= 360.0 then
                    addedRotation = 0.0
                end
    
                SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - addedRotation, _casinoWheelRotation.z, 2, true)
                Wait(1)
            end
    
            -- wheelSpeed = 1.75
    
            -- while addedRotation < finalRotation do
            --     addedRotation += wheelSpeed
    
            --     local diff = finalRotation - addedRotation
    
            --     if diff <= 100.0 and diff >= 40.0 then
            --         wheelSpeed = 1.0
            --     elseif diff <= 40.0 and diff >= 20.0 then
            --         wheelSpeed = 0.5
            --     elseif diff < 20.0 and diff >= 10.0 then
            --         wheelSpeed = 0.35
            --     end
    
            --     SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - addedRotation, _casinoWheelRotation.z, 2, true)
            --     Wait(5)
            -- end
    
            -- SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - finalRotation, _casinoWheelRotation.z, 2, true)
        end)
    end
end)

AddEventHandler("Casino:Client:Enter", function()
    CreateCasinoWheel()
end)

AddEventHandler("Casino:Client:Exit", function()
    DeleteCasinoWheel()
end)

-- AddStateBagChangeHandler("Casino:WheelLastRotation", nil, function(bagName, key, value, _unused, replicated)
--     if _insideCasino and _casinoWheel then
--         _spinningWheel = false
--         Wait(10)

--         SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - value, _casinoWheelRotation.z, 2, true)
--     end
-- end)

RegisterNetEvent("Casino:Client:WheelLastRotation", function(value)
    if _insideCasino and _casinoWheel then
        _spinningWheel = false
        Wait(10)

        SetEntityRotation(_casinoWheel, _casinoWheelRotation.x, _casinoWheelRotation.y - value, _casinoWheelRotation.z, 2, true)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        DeleteCasinoWheel()
    end
end)