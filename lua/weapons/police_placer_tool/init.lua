AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

util.AddNetworkString( "Police.Props.Deploy" )
util.AddNetworkString( "Police.Props.Holster" )
util.AddNetworkString( "Police.Props.Skin" )
util.AddNetworkString( "Police.Props.Notify" )
util.AddNetworkString( "Police.Props.Spawn" )
CreateConVar( "sbox_maxpolice_props", 15, FVAR_ARCHIVE, "Sets the maximum amount of spawnable police props per player.", 0, 50 )

local maxDistance = 275625
local PoliceSelectedProp = 1

function SWEP:Initialize()
    self:SetHoldType( "normal" )
end

function SWEP:Deploy()
	net.Start( "Police.Props.Deploy" )
	net.Send( self:GetOwner() )
end

function SWEP:Holster( switchTo )
	net.Start( "Police.Props.Holster" )
	net.Send( self:GetOwner() )
	return true
end

function SWEP:PrimaryAttack()
	return false
end

function SWEP:SecondaryAttack()
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

function PoliceNotify( ply, msg )
    net.Start( "Police.Props.Notify" )
        net.WriteString( msg )
    net.Send( ply )
end

-- Credit to Xavier for creating this function for XLib
local function traceEntityOBB( tracedata, ent, quick, verbose )
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

local function HasEntityCollisions( ent, pos )
    local tr = traceEntityOBB( { start = pos, endpos = pos, filter = ent }, ent, true )
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

    if not ply:CheckLimit( "police_props" ) then
        PoliceNotify( ply, "You've hit the limit for how many police props you can spawn." )
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

    ply:AddCount( "police_props", propSpawn )
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

    if ply.SpawnedPoliceProps and not table.IsEmpty( ply.SpawnedPoliceProps ) then
        for k, v in pairs( ply.SpawnedPoliceProps ) do
            if IsValid( v ) then v:Remove() end
        end
    end
end )