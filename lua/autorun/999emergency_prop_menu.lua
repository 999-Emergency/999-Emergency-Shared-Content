hook.Add( "PopulatePropMenu", "999emergency_prop_menu", function()

    local contents = {}
    
    function addProp(model,width,height)
        table.insert( contents, {
            type = "model",
            model = model,
            wide = width,
            tall = height
        } )
    end

	table.insert( contents, {
		type = "header",
		text = "LightBars"
    } )
  
    addProp("models/999pack/ambulance_lights/irulights.mdl",  60, 60)
    addProp("models/999pack/ambulance_lights/irulightsfront.mdl",  60, 60)
    addProp("models/999pack/ambulance_lights/irulightsrear.mdl",  60, 60)
    addProp("models/999pack/lightbars/premier_hazard_sovereign_large.mdl",  60, 60)
    addProp("models/999pack/whelen/liberty_ii.mdl",  60, 60)
    addProp("models/supermighty/british_firetruck_lightbar.mdl",  60, 60)
       
	table.insert( contents, {
		type = "header",
		text = "Interior Equipment"
    } )
    
    addProp("models/999pack/genysis/genysis.mdl", 60, 60)
    addProp("models/999pack/multivan/boot.mdl", 60, 60)
    addProp("models/999pack/cage/cagelwb.mdl", 60, 60)
    addProp("models/999pack/sprinter/chair.mdl", 60, 60)

	table.insert( contents, {
		type = "header",
		text = "Exterior Lighting"
    } )

    addProp("models/999pack/hella/hellalight.mdl", 60, 60)
    addProp("models/999pack/m7/m7-1.mdl", 60, 60)
    addProp("models/999pack/m7/m7.mdl", 60, 60)
    addProp("models/999pack/whelen/whelentir.mdl", 60, 60)
    addProp("models/creator_2013/woodway_perimeter_scene_light.mdl", 60, 60)
    addProp("models/noble/whelen_m9/whelen_m9.mdl", 60, 60)
    addProp("models/sentry/props/briishalley.mdl", 60, 60)
    addProp("models/supermighty/photon/whelen_ion.mdl", 60, 60)

    table.insert( contents, {
		type = "header",
		text = "Exterior Equipment"
    } )

    addProp("models/999pack/anpr_camera.mdl", 60, 60)
    addProp("models/999pack/ion/mount.mdl", 60, 60)
    addProp("models/999pack/sprinter/step.mdl", 60, 60)
    addProp("models/supermighty/shield_down.mdl", 60, 60)
    addProp("models/supermighty/shield_up.mdl", 60, 60)
    addProp("models/supermighty/emergency999_badge.mdl", 60, 60)

     table.insert( contents, {
		type = "header",
		text = "Props"
    } )

    addProp("models/999pack/police_sign/police_sign.mdl", 60, 60)
    addProp("models/999pack/traffic_cone/traffic_cone.mdl", 60, 60)

	spawnmenu.AddPropCategory( "999emergency_prop_menu", "999Emergency Props", contents, "icon16/box.png" )
end )