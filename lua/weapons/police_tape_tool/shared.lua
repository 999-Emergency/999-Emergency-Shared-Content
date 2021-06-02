if SERVER then
    AddCSLuaFile( "shared.lua" )
    util.AddNetworkString( "Police.Tape.Clear" )
    util.AddNetworkString( "Police.Tape.First" )
    util.AddNetworkString( "Police.Tape.Switch.Mat" )
    util.AddNetworkString( "Police.Tape.Cancel" )
end

local tapeList = {
    { Name = "Police", Material = "999pack/tape/police_tape" },
    { Name = "Cordon", Material = "999pack/tape/cordon_tape" },
    { Name = "Fire", Material = "999pack/tape/fire_tape" }
}

list.Add( "RopeMaterials", "999pack/tape/police_tape" )
list.Add( "RopeMaterials", "999pack/tape/cordon_tape" )
list.Add( "RopeMaterials", "999pack/tape/fire_tape" )

if SERVER then
    CreateConVar( "PoliceTapeMax", 15, FCVAR_NONE, "Sets the maximum amount of spawnable tape per player.", 0, 50 )
end

if CLIENT then
    SWEP.PrintName = "Police Tape"
    SWEP.Slot = 0
    SWEP.SlotPos = 4
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false 
end

SWEP.Author         = "Sir Zac"
SWEP.Instructions   = "Left Click: Place first point and press again to set finale point\n Right Click: Delete the last spawned tape\n R: Cancels rope"
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
end

function SWEP:Deploy()
    if not self.selectedMaterial then
        self.selectedMaterial = tapeList[ 1 ].Material
    end
end

function SWEP:Holster( switchTo )
    if SERVER then
        self.firstPoint, self.secondPoint = nil, nil
        tapeClear( self:GetOwner() )
        return true
    end
end

local maxDistance = 1000
local maxDistanceSqrd = maxDistance * maxDistance
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    self:SetNextPrimaryFire( CurTime() + 0.5 )

    if SERVER then
        local maxTapes = GetConVar( "PoliceTapeMax" ):GetInt()
        if not maxTapes then return end

        if owner.SpawnedPoliceTape and table.Count( owner.SpawnedPoliceTape[ 2 ] ) >= maxTapes then
            tapeClear( owner )
            PoliceNotify( owner, "You've hit the limit for how many police tapes you can spawn ( " .. maxTapes .. " )." )
            return
        end
    end

    local trace = owner:GetEyeTrace()
    if not trace then return end


    if ( owner:GetPos():DistToSqr( trace.HitPos ) > maxDistanceSqrd ) then
        if SERVER then PoliceNotify( owner, "You're looking too far." ) end
        return
    end

    if ( IsValid( trace.Entity ) and ( trace.Entity:IsPlayer() or trace.Entity:IsVehicle() ) ) then return end
    if ( SERVER and not util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) ) then return false end


    if not self.firstPoint then
        self.firstPoint = trace.HitPos
--        self.firstPointData = { ent = trace.Entity, wpos = trace.HitPos }
        if SERVER then
            if game.SinglePlayer() then
                net.Start( "Police.Tape.First" )
                    net.WriteVector( self.firstPoint )
                net.Send( owner )
            end
            PoliceNotify( owner, "First point chosen. Left click again to finalise the tape." )
        end
    else
        self.secondPoint = trace.HitPos

        local distance = self.firstPoint:Distance( self.secondPoint )
        if ( distance > maxDistance ) then
            if SERVER then PoliceNotify( owner, "The tapes length is too long." ) end
            return
        end

        if SERVER then
            local traceEnt = trace.Entity
--            local length = ( self.firstPointData.wpos - self.secondPoint ):Length()
            local tape = constraint.Rope( game.GetWorld(), game.GetWorld(), 0, 0, self.firstPoint, self.secondPoint, distance, 0, 0, 4, self.selectedMaterial, true )
            tape.owner = owner

            owner.SpawnedPoliceTape = owner.SpawnedPoliceTape or {}
            owner.SpawnedPoliceTape[ 1 ] = owner.SpawnedPoliceTape[ 1 ] or {}
            owner.SpawnedPoliceTape[ 2 ] = owner.SpawnedPoliceTape[ 2 ] or {}
            owner.SpawnedPoliceTape[ 1 ][ table.Count( owner.SpawnedPoliceTape[ 1 ] ) + 1 or 1 ] = tape:EntIndex()
            owner.SpawnedPoliceTape[ 2 ][ tape:EntIndex() ] = tape

            PoliceNotify( owner, "The tape has been strung up." )
        end

        self.firstPoint, self.secondPoint = nil, nil
        if SERVER and game.SinglePlayer() then
            tapeClear( owner )
        end
    end
end

local redCol = Color( 235, 52, 52 )
local greenCol = Color( 70, 149, 189 )
local selectedTape = 1
local keyControls
if CLIENT then
    keyControls = {
        ["Change Tape"] = {
            key = KEY_T,
            cooldown = 1,
            presstime = CurTime(),
            callback = function()
                local nextTape = selectedTape + 1
                if not tapeList[ nextTape ] then
                    selectedTape = 1
                else
                    selectedTape = nextTape
                end
            
                net.Start( "Police.Tape.Switch.Mat" )
                    net.WriteUInt( selectedTape, 6 )
                net.SendToServer()
            end
        },
        ["Reset Data"] = {
            key = KEY_R,
            cooldown = 1,
            presstime = CurTime(),
            callback = function()
                local weapon = LocalPlayer():GetActiveWeapon()
                if not IsValid( weapon ) then return end
                if ( weapon:GetClass() ~= "police_tape_tool" ) then return end
                if not weapon.firstPoint then return end

                weapon.firstPoint, weapon.secondPoint = nil, nil

                net.Start( "Police.Tape.Cancel" )
                    net.WriteUInt( selectedTape, 6 )
                net.SendToServer()
            end
        },
    }
end
function SWEP:DrawHUD()
    local hitTrace = LocalPlayer():GetEyeTrace().HitPos
    local vectorTarget
    if self.firstPoint then
        vectorTarget = self.firstPoint
    else
        vectorTarget = LocalPlayer():GetPos()
    end

    local ballColour
    if ( vectorTarget:DistToSqr( hitTrace ) < maxDistanceSqrd ) then
        ballColour = greenCol
    else
        ballColour = redCol
    end

    for k, v in pairs( keyControls ) do
        if v.presstime + v.cooldown < CurTime() and input.IsKeyDown( v.key ) then
            v.callback()
            v.presstime = CurTime()
        end
    end

    cam.Start3D()
        self:DrawPoint( hitTrace, ballColour, 3 )

        if self.firstPoint then
            self:DrawPoint( self.firstPoint, redCol )
            
            render.DrawLine( self.firstPoint, hitTrace, color_white, true )
        end
    cam.End3D()
end

function SWEP:DrawPoint( pos, col, size )
    if not pos then return end

    render.SetColorMaterial()
    render.DrawWireframeSphere( pos, size or 1, 8, 8, col, true )
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    self:SetNextSecondaryFire( CurTime() + 0.5 )

    if not owner.SpawnedPoliceTape then return end
    if not owner.SpawnedPoliceTape[ 1 ] then return end

    local lastInsert = table.Count( owner.SpawnedPoliceTape[ 1 ] )
    if not lastInsert then return end

    local lastEntIndex = owner.SpawnedPoliceTape[ 1 ][ lastInsert ]
    if not lastEntIndex then return end

    local actEnt = owner.SpawnedPoliceTape[ 2 ][ lastEntIndex ]
    if IsValid( actEnt ) then
        actEnt:Remove()
        PoliceNotify( owner, "The last tape put up has been remove." )
    end

    owner.SpawnedPoliceTape[ 1 ][ lastInsert ] = nil
    owner.SpawnedPoliceTape[ 2 ][ lastEntIndex ] = nil
end

if SERVER then
    function tapeClear( ply )
        if not IsValid( ply ) then return end

        net.Start( "Police.Tape.Clear" )
        net.Send( ply )
    end

    net.Receive( "Police.Tape.Switch.Mat", function( len, ply )
        if not IsValid( ply ) then return end

        local weapon = ply:GetActiveWeapon()
        if not IsValid( weapon ) then return end
        if ( weapon:GetClass() ~= "police_tape_tool" ) then return end

        local selectedTape = net.ReadUInt( 6 )
        local data = tapeList[ selectedTape ]
        if not data then return end

        weapon.selectedMaterial = data.Material
        PoliceNotify( ply, "Tape switched to " .. data.Name .. " version." )
    end )

    net.Receive( "Police.Tape.Cancel", function( len, ply )
        if not IsValid( ply ) then return end

        local weapon = ply:GetActiveWeapon()
        if not IsValid( weapon ) then return end
        if ( weapon:GetClass() ~= "police_tape_tool" ) then return end
        if not weapon.firstPoint then return end

        weapon.firstPoint, weapon.secondPoint = nil, nil
    end )

    hook.Add( "PlayerDisconnected", "DeletePoliceTape", function( ply )
        if not IsValid( ply ) then return end

        if ply.SpawnedPoliceTape then
            for k, v in pairs( ply.SpawnedPoliceTape[ 2 ] ) do
                if IsValid( v ) then v:Remove() end
            end
        end
        ply.SpawnedPoliceTape = nil
    end )
else
    net.Receive( "Police.Tape.Clear", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if not IsValid( weapon ) then return end
        if ( weapon:GetClass() ~= "police_tape_tool" ) then weapon = LocalPlayer():GetWeapon( "police_tape_tool" ) if not weapon then return end end

        weapon.firstPoint, weapon.secondPoint = nil, nil
    end )

    net.Receive( "Police.Tape.First", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if not IsValid( weapon ) then return end
        if ( weapon:GetClass() ~= "police_tape_tool" ) then return end

        weapon.firstPoint = net.ReadVector()
    end )
end
