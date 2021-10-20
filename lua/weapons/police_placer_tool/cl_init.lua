include( "shared.lua" )
language.Add( "sboxlimit_police_props", "You've hit the limit for how many police props you can spawn!" )

local policePropList = {
    "models/999pack/traffic_cone/traffic_cone.mdl",
    "models/999pack/police_sign/police_sign.mdl"
}
local maxDistance = 275625
local PoliceSelectedProp = 1

local function CreateBuildPreview( mdl )
    if not IsValid( policePropPreview ) then
        policePropPreview = ents.CreateClientProp( "prop_physics" )
        policePropPreview:SetModel( mdl )
        policePropPreview:Spawn()
    else
        policePropPreview:SetModel( mdl )
    end

    hook.Add( "CreateMove", policePropPreview, function( ent, cmd )
        cmd:RemoveKey( IN_ATTACK )
        cmd:RemoveKey( IN_RELOAD )
    end )
end

local fallbackModel = "models/hunter/blocks/cube025x025x025.mdl"
local drawColor = Color( 255, 255, 255, 255 )
local hideColor = Color( 255, 255, 255, 0 )
local time = 0.1
local keyControls = {
    ["Rotate Forwards"] = {
        key = KEY_R,
        cooldown = time,
        presstime = CurTime(),
        callback = function( ang, pos )
            ang.yaw = ang.yaw + math.Round( 15 )
            return ang
        end,
        callbackEnt = function( ent )
            local skinCount = ent:SkinCount() - 1
            local currentSkin = ent:GetSkin()
            local newSkin = currentSkin + 1
            if newSkin > skinCount then
                newSkin = 0
            end
            net.Start( "Police.Props.Skin" )
                net.WriteUInt( newSkin, 6 )
                net.WriteEntity( ent )
            net.SendToServer()
        end
    },
    ["Rotate Backwards"] = {
        key = KEY_E,
        cooldown = time,
        presstime = CurTime(),
        callback = function( ang, pos )
            ang.yaw = ang.yaw - math.Round( 15 )
            return ang
        end,
        callbackEnt = function( ent )
            local skinCount = ent:SkinCount() - 1
            local currentSkin = ent:GetSkin()
            local newSkin = currentSkin - 1
            if newSkin < 0 then
                newSkin = skinCount
            end
            net.Start( "Police.Props.Skin" )
                net.WriteUInt( newSkin, 6 )
                net.WriteEntity( ent )
            net.SendToServer()
        end
    },
    ["Change Model"] = {
        key = KEY_T,
        cooldown = 1,
        presstime = CurTime(),
        callback = function( ang, pos )
            local nextInt = PoliceSelectedProp + 1
            local nextProp
            if nextInt > #policePropList then
                nextProp = policePropList[ 1 ]
                PoliceSelectedProp = 1
            else
                nextProp = policePropList[ nextInt ]
                PoliceSelectedProp = nextInt
            end
            CreateBuildPreview( nextProp )
            return ang
        end
    },
    ["Reset Angles"] = {
        key = KEY_LSHIFT,
        cooldown = time,
        presstime = CurTime(),
        callback = function( ang, pos )
            return Angle()
        end
    }
}

local switchCoolDown
local ang = Angle()
local targetPos = Vector()
local defaultColor = Color( 0, 255, 255, 100 )
local noBuildColor = Color( 255, 0, 0, 50 )
local hideColor = Color( 0, 0, 0, 0 )
local haloColor = Color( 44, 191, 83 )
local canBuild = false
local tracingMultSkinEnt = false
local haloDrawing = false
local function DrawPolicePropHook()
    local ply = LocalPlayer()
    if not IsValid( ply:GetActiveWeapon() ) then return end
    if ( ply:GetActiveWeapon():GetClass() ~= "police_placer_tool" ) then return end
    if not IsValid( policePropPreview ) then return end

    local preview = policePropPreview
    if preview:GetModel() == fallbackModel then
        preview:SetColor( hideColor )
        return
    else
        preview:SetColor( drawColor )
    end

    local shootPos = ply:GetShootPos()
    local aimForward = ply:GetAimVector()

    local trace = {}
    trace.start = shootPos
    trace.endpos = shootPos + ( aimForward * 2048 )
    trace.filter = ply

    local tr = util.TraceLine( trace )
    local clampPos = tr.HitPos
    targetPos = clampPos - ( tr.HitNormal * 512 )
    preview:SetPos( clampPos )
    targetPos = preview:NearestPoint( targetPos )
    targetPos = preview:GetPos() - targetPos
    targetPos = clampPos + targetPos
    targetPos.z = math.Clamp( targetPos.z, clampPos.z, 100000 )

    local traceEnt = tr.Entity
    if IsValid( traceEnt ) and traceEnt:GetNWBool( "IsPoliceProp", false ) then
        if ( traceEnt:SkinCount() and traceEnt:SkinCount() > 1 ) then
            tracingMultSkinEnt = true
        end

        preview:SetNoDraw( true )

        if not haloDrawing then
            haloDrawing = true
            hook.Add( "PreDrawHalos", "Police.Props.Halo", function()
                halo.Add( { tr.Entity }, haloColor, 5, 5, 2 )
            end )
        end
    elseif tracingMultSkinEnt or haloDrawing then
        if tracingMultSkinEnt then tracingMultSkinEnt = false end
        if haloDrawing then
            haloDrawing = false
            hook.Remove( "PreDrawHalos", "Police.Props.Halo" )
        end
    end

    for k, v in pairs( keyControls ) do
        if v.presstime + ( tracingMultSkinEnt and 0.5 or v.cooldown ) < CurTime() and input.IsKeyDown( v.key ) then
            if tracingMultSkinEnt and v.callbackEnt then
                v.callbackEnt( traceEnt )
            else
                ang = v.callback( ang )
            end
            v.presstime = CurTime()
        end
    end
    if tracingMultSkinEnt or haloDrawing then return end

    preview:SetPos( targetPos )
    preview:SetAngles( ang )
    preview:SetRenderMode( RENDERGROUP_TRANSLUCENT )

    if ( targetPos:DistToSqr( LocalPlayer():GetPos() ) > maxDistance ) then
        preview:SetColor( noBuildColor )
        canBuild = false
    else
        preview:SetColor( defaultColor )
        canBuild = true
    end
    preview:SetNoDraw( false )

    placeTime = placeTime or CurTime()
    print( switchCoolDown )
    if ( switchCoolDown and switchCoolDown < CurTime() ) and gui.MouseX() == 0 and input.IsMouseDown( MOUSE_FIRST ) and placeTime + 1 < CurTime() then
        holdTime = holdTime + 10 * FrameTime()
        if holdTime < 2 then return end
        if not canBuild then return end

        placeTime = CurTime()

        net.Start( "Police.Props.Spawn" )
            net.WriteString( policePropPreview:GetModel() )
            net.WriteVector( targetPos )
            net.WriteAngle( ang )
        net.SendToServer()
    else
        holdTime = 0
    end
end

local function RemoveBuildPreview()
    if IsValid( policePropPreview ) then
        policePropPreview:Remove()
    end
end

RemoveBuildPreview()

local colOne = Color( 0, 0, 0, 200 )
local tipW, tipH = 0, 25
local function addNamePlate( ent, text )
    local ply = LocalPlayer()
    
    if ( ent:GetPos():DistToSqr( ply:GetPos() ) < maxDistance ) then
        local max = ent:OBBMaxs()
        local pos = ent:GetPos()
        pos = Vector( pos.x, pos.y, pos.z + max.z / 2 )
        pos = pos:ToScreen()
        pos.y = pos.y + 10 * math.sin( CurTime() * 1.5 )

        local textFont = "Trebuchet24"
        local textStr = text
        
        surface.SetDrawColor( colOne )
        surface.SetFont( textFont )
        
        local textW, textH = surface.GetTextSize( textStr )
        tipW = textW + 20
        surface.DrawRect( pos.x - tipW * 0.5, pos.y - tipH * 0.5, tipW, tipH )
        draw.SimpleText( textStr, textFont, pos.x, pos.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
        
        surface.SetDrawColor( color_white )
        surface.DrawLine( pos.x - tipW * 0.5, pos.y + tipH * 0.5, pos.x + tipW * 0.5, pos.y + tipH * 0.5 )
    end
end

local function DrawPolicePropInfo()
    if not IsValid( policePropPreview ) then return end
    if tracingMultSkinEnt or haloDrawing then return end

    local ply = LocalPlayer()
    local scrw, scrh = ScrW(), ScrH()
    
    local groundPos = ply:GetEyeTrace().HitPos:ToScreen()
    local titleText = math.abs( policePropPreview:GetAngles().y % 360 ) .. " Degrees"
    
    addNamePlate( policePropPreview, titleText )
end

local function policePropsLoadHooks()
    switchCoolDown = CurTime() + 1.5
    CreateBuildPreview( policePropList[ PoliceSelectedProp ] )
    hook.Add( "PostDrawOpaqueRenderables", "PolicePropPreview", DrawPolicePropHook )
    hook.Add( "HUDPaint", "PolicePropPreview", DrawPolicePropInfo )
end

net.Receive( "Police.Props.Deploy", function()
    policePropsLoadHooks()
end )

net.Receive( "Police.Props.Holster", function()
    hook.Remove( "PostDrawOpaqueRenderables", "PolicePropPreview" )
    hook.Remove( "PreDrawHalos", "Police.Props.Halo" )
    hook.Remove( "HUDPaint", "PolicePropPreview" )
    haloDrawing = false
    tracingMultSkinEnt = false
    RemoveBuildPreview()
end )

net.Receive( "Police.Props.Notify", function()
    local msg = net.ReadString()
    if not msg or ( msg == "" ) then return end

    notification.AddLegacy( msg, 0, 5 )
end )


function SWEP:Initialize()
	self:SetHoldType( "normal" )
	policePropsLoadHooks()
end

function SWEP:PrimaryAttack()
    return false
end

function SWEP:SecondaryAttack()
    return false
end