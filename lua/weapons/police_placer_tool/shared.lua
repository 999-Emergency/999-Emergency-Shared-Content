if SERVER then
    AddCSLuaFile( "shared.lua" )
    util.AddNetworkString( "Police.Props.Deploy" )
    util.AddNetworkString( "Police.Props.Holster" )
    util.AddNetworkString( "Police.Props.Skin" )
    util.AddNetworkString( "Police.Props.Notify" )
    util.AddNetworkString( "Police.Props.Spawn" )
end

local propList = {
    "models/999pack/traffic_cone/traffic_cone.mdl",
    "models/999pack/police_sign/police_sign.mdl"
}
local maxDistance = 275625
local PoliceSelectedProp = 1
--local policePropPreview
if SERVER then
    CreateConVar( "sbox_maxpoliceprops", 15, FVAR_ARCHIVE, "Sets the maximum amount of spawnables per player.", 0, 50 )
end

if CLIENT then
    SWEP.PrintName = "Police Prop Placer"
    SWEP.Slot = 0
    SWEP.SlotPos = 4
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false 
end

SWEP.Author         = "Sir Zac"
SWEP.Instructions   = "Hosen prop \nRight Click: Delete target prop \nT: Cycles to next prop \nShift: Resets rotation \nE/R: Rotates and changes skins of target entities"
SWEP.Contact        = ""
SWEP.Purpose        = ""
SWEP.Category       = "999Emergency"

SWEP.ViewModelFOV   = 62
SWEP.ViewModelFlip  = false
SWEP.UseHands       = false
SWEP.AnimPrefix     = "rpg"

SWEP.Spawnable          = true
SWEP.AdminSpawnable     = false

SWEP.ViewModel = ""
SWEP.WorldModel = ""

SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = 0
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo           = ""

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = 0
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = ""

function SWEP:Initialize()
    self:SetHoldType( "normal" )

    if CLIENT then
        self:LoadHooks()
    end
end

function SWEP:LoadHooks()
    self.switchCoolDown = CurTime() + 1.5
    CreateBuildPreview( propList[ PoliceSelectedProp ] )
    hook.Add( "PostDrawOpaqueRenderables", "PolicePropPreview", DrawPolicePropHook )
    hook.Add( "HUDPaint", "PolicePropPreview", DrawPolicePropInfo )
end

function SWEP:Deploy()
    if SERVER then
        net.Start( "Police.Props.Deploy" )
        net.Send( self:GetOwner() )
    end
end

function SWEP:Holster( switchTo )
    if SERVER then
        net.Start( "Police.Props.Holster" )
        net.Send( self:GetOwner() )
        return true
    end
end

function SWEP:PrimaryAttack()
    return false
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local trace = owner:GetEyeTrace()
    if not trace then return end

    local traceEnt = trace.Entity
    if not IsValid( traceEnt ) then return end
    if not traceEnt:GetNWBool( "IsPoliceProp", false ) then return end

    local distance = traceEnt:GetPos():DistToSqr( owner:GetPos() )
    if ( distance > maxDistance ) then return end

    self:SetNextSecondaryFire( CurTime() + 0.5 )
    SafeRemoveEntity( traceEnt )
end

if CLIENT then
    local fallbackModel = "models/hunter/blocks/cube025x025x025.mdl"
    local drawColor = Color( 255, 255, 255, alpha )
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
                if nextInt > #propList then
                    nextProp = propList[ 1 ]
                    PoliceSelectedProp = 1
                else
                    nextProp = propList[ nextInt ]
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

    local ang = Angle()
    local targetPos = Vector()
    local defaultColor = Color( 0, 255, 255, 100 )
    local noBuildColor = Color( 255, 0, 0, 50 )
    local hideColor = Color( 0, 0, 0, 0 )
    local haloColor = Color( 44, 191, 83 )
    local canBuild = false
    local tracingMultSkinEnt = false
    local haloDrawing = false
    function DrawPolicePropHook()
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
        if ( ply:GetActiveWeapon().switchCoolDown and ply:GetActiveWeapon().switchCoolDown < CurTime() ) and gui.MouseX() == 0 and input.IsMouseDown( MOUSE_FIRST ) and placeTime + 1 < CurTime() then
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
    function CreateBuildPreview( mdl )
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

    function RemoveBuildPreview()
        if IsValid( policePropPreview ) then
            policePropPreview:Remove()
        end
    end

    RemoveBuildPreview()

    local checkTime = CurTime()
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

    function DrawPolicePropInfo()
        if not IsValid( policePropPreview ) then return end
        if tracingMultSkinEnt or haloDrawing then return end

        local ply = LocalPlayer()
        local scrw, scrh = ScrW(), ScrH()
        
        local groundPos = ply:GetEyeTrace().HitPos:ToScreen()
        local titleText = ""
        titleText = titleText .. math.abs( policePropPreview:GetAngles().y % 360 ) .. " Degrees"
        
        addNamePlate( policePropPreview, titleText )
    end

    net.Receive( "Police.Props.Deploy", function()
        timer.Simple( 0.1, function()
            local weapon = LocalPlayer():GetActiveWeapon()
            if not IsValid( weapon ) then return end
			if ( weapon:GetClass() ~= "police_placer_tool" ) then return end

            if weapon.LoadHooks then weapon:LoadHooks() end
		end )
    end )

    net.Receive( "Police.Props.Holster", function()
        hook.Remove( "PostDrawOpaqueRenderables", "PolicePropPreview" )
        hook.Remove( "PreDrawHalos", "Police.Props.Halo" )
        hook.Remove( "HUDPaint", "PolicePropPreview" )
        haloDrawing = false
		tracingMultSkinEnt = false
        timer.Simple( 0.01, function()
            RemoveBuildPreview()
        end )
    end )
else
    local function HasEntityCollisions( ent, pos )
        local tr = util.TraceEntityOBB( { start = pos, endpos = pos, filter = ent }, ent, true )
        return tr.Hit
    end

    local function HasModelCollisions( ent, classname )
        local min, max = ent:GetModelBounds()
        min = ent:LocalToWorld( min )
        max = ent:LocalToWorld( max )

        local collided = false
        for k, v in pairs( ents.FindInBox( min, max ) ) do
            if classname and ( v ~= ent ) and ( v:GetClass() == classname ) then
                collided = true
                break
            end
            if not classname and ( v ~= ent ) then
                collided = true
                break
            end
            if v:IsPlayer() or v:IsVehicle() then
                collided = true
                break
            end
        end
        return collided
    end

    -- Credit to Xavier for creating this function for XLib
    function util.TraceEntityOBB( tracedata, ent, quick, verbose )
        local mins, maxs = ent:GetCollisionBounds()
        mins = mins + (tracedata.mins or Vector())
        maxs = maxs + (tracedata.maxs or Vector())
        local corners = {
            mins, --back left bottom
            Vector(mins[1], maxs[2], mins[3]), --back right bottom
            Vector(maxs[1], maxs[2], mins[3]), --front right bottom
            Vector(maxs[1], mins[2], mins[3]), --front left bottom
            Vector(mins[1], mins[2], maxs[3]), --back left top
            Vector(mins[1], maxs[2], maxs[3]), --back right top
            maxs, --front right top
            Vector(maxs[1], mins[2], maxs[3]), --front left top
        }
        local out = {}
        local tr = {}
        for i = 1, #corners do
            if quick then
                util.TraceLine{
                    start = LocalToWorld(corners[i], Angle(), tracedata.start or ent:GetPos(), ent:GetAngles()),
                    endpos = LocalToWorld(corners[i], Angle(), tracedata.endpos or ent:GetPos(), ent:GetAngles()),
                    mask = tracedata.mask,
                    filter = tracedata.filter,
                    ignoreworld = tracedata.ignoreworld,
                    output = tr,
                }
                if verbose then
                    out[#out + 1] = {}
                    table.CopyFromTo(tr, out[#out])
                else
                    if tr.Hit then
                        if tracedata.output then
                            table.CopyFromTo(tr, tracedata.output)
                            break
                        end
                        return tr
                    end
                end
            else
                for j = 1, #corners do
                    if corners[i] == corners[j] then continue end
                    util.TraceLine{
                        start = LocalToWorld(corners[i], Angle(), tracedata.start or ent:GetPos(), ent:GetAngles()),
                        endpos = LocalToWorld(corners[j], Angle(), tracedata.endpos or ent:GetPos(), ent:GetAngles()),
                        mask = tracedata.mask,
                        filter = tracedata.filter,
                        ignoreworld = tracedata.ignoreworld,
                        output = tr,
                    }
                    if verbose then
                        out[#out + 1] = {}
                        table.CopyFromTo(tr, out[#out])
                    else
                        if tr.Hit then
                            if tracedata.output then
                                table.CopyFromTo(tr, tracedata.output)
                                break
                            end
                            return tr
                        end
                    end
                end
            end
        end
        for i = 1, #out do
            if out[i].Hit then
                return tr, out
            end
        end
        return tr
    end

    net.Receive( "Police.Props.Skin", function( len, ply )
    	if not IsValid( ply ) then return end

        local skin = net.ReadUInt( 6 )
        local ent = net.ReadEntity()
        if not IsValid( ent ) then return end

        ent:SetSkin( skin )
    end )

    net.Receive( "Police.Props.Spawn", function( len, ply )
        if not IsValid( ply ) then return end

        local model = net.ReadString()
        local pos = net.ReadVector()
        local ang = net.ReadAngle()

        local maxNumberPoliceProps = GetConVar( "sbox_maxpoliceprops" ):GetInt()
        if not maxNumberPoliceProps then return end
        
        if ply.SpawnedPoliceProps and Player:CheckLimit( "policeprops" ) then
            PoliceNotify( ply, "You've hit the limit for how many police props you can spawn ( " .. maxNumberPoliceProps .. " )." )
            return
        end

        if not ( pos:DistToSqr( ply:GetPos() ) < maxDistance ) then 
            PoliceNotify( ply, "The prop you're trying to place is too far away from you." )
            return
        end

        local propSpawn = ents.Create( "prop_physics" )
        propSpawn:SetPos( pos )
        propSpawn:SetAngles( ang )
        propSpawn:SetModel( model )

        if CPPI then
            propSpawn:CPPISetOwner( ply )
        else
            propSpawn:SetNWEntity( "SpawnedOwner", ply )
        end

        propSpawn:Spawn()
        propSpawn:Activate()
        propSpawn:SetNWBool( "IsPoliceProp", true )

        ply:AddCount( "policetape", propSpawn )
        ply.SpawnedPoliceProps = ply.SpawnedPoliceProps or {}
        ply.SpawnedPoliceProps[ propSpawn:EntIndex() ] = propSpawn

        if HasModelCollisions( propSpawn, "prop_physics" ) then
            PoliceNotify( ply, "Failed to place the item due to collision issues." )
            propSpawn:Remove()
            return
        end

        local shouldRemove = true
        for i = 0, 4 do
            local lpos = pos + Vector( 0, 0, i )
            local hit = HasEntityCollisions( propSpawn, lpos )
            if not hit then
                propSpawn:SetPos( lpos )
                shouldRemove = false
                break
            end
        end

        if shouldRemove then
            PoliceNotify( ply, "Failed to place the item due to collision issues." )
            propSpawn:Remove()
            return
        end
    end )

    hook.Add( "EntityRemoved", "LookForPoliceEnts", function( ent )
        if not IsValid( ent ) then return end
        if not ent:GetNWBool( "IsPoliceProp", false ) then return end
        
        local owner
        if CPPI then
            owner = ent:CPPIGetOwner()
        else
            owner = ent:GetNWEntity( "SpawnedOwner", nil )
        end
        if not IsValid( owner ) then return end

        if owner.SpawnedPoliceProps then
            owner.SpawnedPoliceProps[ ent:EntIndex() ] = nil
        end
    end )

    hook.Add( "PlayerDisconnected", "DeletePoliceEnts", function( ply )
        if not IsValid( ply ) then return end

        if ply.SpawnedPoliceProps then
            for k, v in pairs( ply.SpawnedPoliceProps ) do
                if IsValid( v ) then v:Remove() end
            end
        end
    end )
end
