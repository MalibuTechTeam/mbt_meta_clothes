<div id="header" align="center">
  <img src="https://dunb17ur4ymx4.cloudfront.net/wysiwyg/1131066/1fe58a9651a48982397fb7d9ec82bfd4aa26d036.png" width="500"/>
</div>

MBT Meta Clothes take advantage of ox_inventory metadata feature giving you the possibility to turn your clothes into unique items. Undress yourself using a clean and simple NUI and have fun swapping your outfits with your friends!

### Dependencies:
* [ox_inventory](https://github.com/overextended/ox_inventory)
* [ox_lib](https://github.com/overextended/ox_lib)

### ⚠️Important:
Add to your items the following ones (customize the settings to fit your needs) DO NOT CHANGE THE ITEMS NAME!
<br/>
The resource has been tested ONLY on Ox Core and ESX
<br />
Remember to check and change if needed the ```Default``` clothes in ```MBT.Drawables``` and ```MBT.Props ```


## ox_inventory/data/items.lua

```
['topdress'] = {
		label 		= 'Top Dress',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d', flag = 51 },
			usetime = 1200,
		}
	},
  ['jacket'] = {
		label 		= 'Jacket',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d', flag = 51 },
			usetime = 1200,
		}
	},
  ['trousers'] = {
		label 		= 'Trousers',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 're@construction', clip = 'out_of_breath', flag = 51 },
			usetime = 1200,
		}
	},
  ['shoes'] = {
		label 		= 'Shoes',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'random@domestic', clip = 'pickup_low', flag = 0 },
			usetime = 1200,
		}
	},
  ['hat'] = {
		label 		= 'Hat',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'missheist_agency2ahelmet', clip = 'take_off_helmet_stand', flag = 51 },
			usetime = 1200,
		}
	},
  ['glasses'] = {
		label 		= 'Glasses',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'clothingspecs', clip = 'take_off', flag = 51 },
			usetime = 1200,
		}
	},
  ['earaccess'] = {
		label 		= 'Ear Accessories',
		description = 'YOUR_DESCRIPTION',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'mp_cp_stolen_tut', clip = 'b_think', flag = 51 },
			usetime = 1200,
		}
	},
  ['chain'] = {
		label 		= 'Torso Accessories',
		description     = 'Torso Accessories',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'clothingtie', clip = 'try_tie_positive_a', flag = 51 },
			usetime = 2500,
		}
	},
  ['watch'] = {
		label 		= 'Watch',
		description     = 'Watch',
		weight 		= 100,
		stack 		= true,
		close 		= true,
		client = {
			anim = { dict = 'nmt_3_rcm-10', clip = 'cs_nigel_dual-10', flag = 51 },
			usetime = 900,
		}
	},
  
```
## ox_inventory/modules/items/client.lua

```
Item('topdress', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then 
    		-- Trigger your notify here
    		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]
	end

	ox_inventory:useItem(data, function(data)
		if data then
			TriggerEvent("mbt_metaclothes:applyKitDress", slot.metadata)
		end
	end)
end)

Item('trousers', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
	  	-- Trigger your notify here
    		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]     
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			TriggerEvent("mbt_metaclothes:applyDress", slot.metadata)
		end
	end)
end)

Item('shoes', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
		-- Trigger your notify here
    		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]    
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			TriggerEvent("mbt_metaclothes:applyDress", slot.metadata)
		end
	end)
end)

Item('chain', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
	  	-- Trigger your notify here
    		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]     
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			TriggerEvent("mbt_metaclothes:applyDress", slot.metadata)
		end
	end)
end)

Item('watch', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
		-- Trigger your notify here
   		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]   
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			TriggerEvent("mbt_metaclothes:applyProps", slot.metadata)
		end
	end)
end)

Item('hat', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
		-- Trigger your notify here
   		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]   
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			TriggerEvent("mbt_metaclothes:applyProps", slot.metadata)
		end
	end)
end)

Item('glasses', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
		-- Trigger your notify here
    		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]      
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			-- print(slot.metadata.drawable)
			TriggerEvent("mbt_metaclothes:applyProps", slot.metadata)
		end
	end)
end)

Item('earaccess', function(data, slot)
	local sexLabel = { ["m"] = "man", ["f"] = "woman"}
	if PlayerData.sex ~= slot.metadata.sex then
		-- Trigger your notify here
    		-- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]      
	end
  
	ox_inventory:useItem(data, function(data)
		if data then
			-- print(slot.metadata.drawable)
			TriggerEvent("mbt_metaclothes:applyProps", slot.metadata)
		end
	end)
end)


```



## Features

- Turn clothes into items and swap them with your friends
- ESX compatible (Tested with ESX Legacy)
- Ox Core compatible
- QB Core compatible
- Optimized for low CPU usage
- Customizable labels
- Customizable notify system

### Media:
- Showcase:  [Click Here](https://www.youtube.com/watch?v=TSCrxiJaWdg)
- Cfx : [Click Here](https://forum.cfx.re/t/free-esx-qb-ox-mbt-meta-clothes/4961827)

## DMCA Protection Certificate
![image](https://media.discordapp.net/attachments/1045063739738705940/1049386591359074354/image.png)

##### Copyright © 2022 Malibú Tech. All rights reserved.
