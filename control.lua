

--[[
local function _log_keys(prefix,object)
	for _, __ in pairs(object) do
		log( prefix.._.."="..tostring(__) );
	--if( type(__)=="string" or type(__)=="number" or type(__)=="function" or type(__)=="boolean" or type(__)=="nil"or type(__)=="thread") then
	if( type(__)=="userdata" ) then
		local meta = getmetatable(__) ;
		if meta then
			_log_keys( prefix.."  ", getmetatable(__) );
		else
			log( "NIL Userdata?" );
		end
	elseif type(__) == "table" then
		_log_keys( prefix.."  ", __ );
	end
	end

end

local function log_keys(object)
	_log_keys( "", object )
end
]]

function count_item_type( allItems, itemName, at_item )
	local count = 0;
	-- count all in this level....
	for name,missing in pairs(allItems) do
		if( name == itemName ) then
			count = count + missing.need;
		end
	end
	for name,missing in pairs(allItems) do
		if missing == at_item then 
			--log( "Got back to this item we're checking" );
			return count;
		end
		if #missing.subItems then
			count = count + count_item_type( missing.subItems, itemName, at_item );			
		end
	end
	return count;
end

function enough_items( items, itemName, n, player, allItems ) 
	--log( "Check if enough items for a product of recipe:".. itemName );
	for rname,recipe in pairs( game.recipe_prototypes ) do
		if( recipe.category == "crafting" or recipe.category=="electronics" ) then
			if not recipe.hidden then
				for num,product in pairs(recipe.products) do
					--log( "is "..product.name.."=="..itemName );
					if( product.name == itemName ) then		
						local pamount = product.amount;
						if( not pamount ) then
							pamount = product.max;
						end
						--log( "Recipe cat:"..recipe.category.. " "..recipe.name .. " is ".. itemName);
						for _,ingred in pairs( recipe.ingredients ) do	
							--log( "   Ingredient:".. ingred.name );
							local pcount = player.get_item_count( ingred.name );
							local needed = count_item_type( allItems, ingred.name, items );
							--log( "needed to this point:".. needed .. " and ".. ingred.amount*n/pamount  );
							--if  pcount < (needed + ingred.amount*n) then
								--local ingredItem = game.item_prototypes[ingred.name];
							if pcount > needed then
								--log( "Remaining is:".. (pcount-needed).. "and this itself needs:"..(ingred.amount*n/pamount) );
								items[ingred.name] = { count= ((ingred.amount*n/pamount)-(pcount-needed)), need=(ingred.amount*n/pamount), subItems={} };
							else
								items[ingred.name] = { count= (ingred.amount*n/pamount), need=(ingred.amount*n), subItems={} };
							end
							--log( "Count required:".. items[ingred.name].count);
							enough_items( items[ingred.name].subItems, ingred.name, items[ingred.name].count, player, allItems );  -- get possible componets of this component
							--end
						end
					end
				end
			else
				--log( "Skipping recipe:"..recipe.name );
			end
		else
			--for num,product in pairs(recipe.products) do
			--	if( product.name == itemName ) then
			--		log( "Skipped Otherwise good recipe!"..itemName .. " ".. recipe.category );
			--	end
			--end
			
			--log( "Skipped Recipe cat:"..recipe.category.. " "..recipe.name );
		end
	end	
end

function resolve_needs( allItems ) 
	local enough = true;
	--log( "resolve all items in:".. tostring(allItems ) );
	for itemName, missing in pairs( allItems ) do
		--log( "missing: "..itemName .. " #:"..missing.count);
		if( missing.count > 0 )	 then
			local hadOne = false;
			--log( "Missing:".. itemName.. tostring(missing.subItems).."  ".. tostring(next(missing.subItems)));
			if  next(missing.subItems) ~= nil then
				--log( "Had subitems that could make it?" );
				if not resolve_needs( missing.subItems ) then	
					--log( " Was still missing sub items" );
					enough=false;
					--break;
				else
					--log( "Had enough items for it?" );
					missing.subItems = {};
					missing.count = 0;
				end
			else
				enough = false;
				--break;
			end
		end
	end
	--log( "Return enough:"..tostring(enough));
	return enough;
end


function _formatMissing( lines, missing, player, sub )
	--if not resolve_needs( missing ) then
		for item,desc in pairs(missing) do
			if desc.count > 0 then
				local line = { "" };
				local n;
				for n = 1, sub do
					line[#line+1] = "--+";
				end
				--log( "formatting missing: "..item );
				line[#line+1] = {"item-name."..item};
				line[#line+1] = {"times_x"};
				line[#line+1] = desc.count;
				lines[#lines+1] = line;
				_formatMissing( lines, desc.subItems, player, sub + 1 );
			end
		end
	--end
	--log( "result line:".. #lines );
	if #lines > 0 then
		return lines;
	end
	return nil;
end

function formatMissing( missing, player, sub )
	local lines = {};
	_formatMissing( lines, missing, player, sub );
	return lines;
end

function findRecipe( findname, n, player ) 
	local missing_items={};
	--log( "SEARCH for"  .. findname )
--[[
	local recipe = game.recipe_prototypes[findname];
	if recipe then
		if recipe.hidden and not recipe.hidden then
			log( "Skipping recipe:"..recipe.name );
			log( "Hidden recipe" );
			return nil;
		end
		for _,ingred in pairs( recipe.ingredients ) do
			if( ingred.fluid ) then
				player.print( { "cannot-craft-fluid" } );
				return nil;
			end
			local pcount = player.get_item_count( ingred.name );	
			--if pcount < (ingred.amount*n) then
			missing_items[ingred.name] = { count= pcount-(ingred.amount*n), needed=(ingred.amount*n), subItems={} };
		end



		if #missing_items then
			for name,missing in pairs( missing_items ) do
				enough_items( missing.subItems, name, missing.count, player, missing_items );
			end
			player.print( { "missing-ingredient" } );
			local items = formatMissing( missing_items, player );
			log_keys( { "missing-item", {"item-name.".."rail"}, " x", 1,"\n" } );
	                log_keys(items);
			log( " got "..#items );
			player.print( items );
			return nil;
		end
		log( "return found name as original" );
		return findname;
	end
]]
	local finditem = nil;
	
	if game.entity_prototypes[findname].items_to_place_this then
		for _,item in pairs( game.entity_prototypes[findname].items_to_place_this ) do
				--log( "Item Tier:"..item.name.." T:"..tostring(item.tier) );
				for rname,recipe in pairs( game.recipe_prototypes ) do
					--log( "CHeck recipe:"..rname );
					if not recipe.hidden and ( recipe.category=="crafting" or recipe.category=="advanced-crafting") then						
						for num,product in pairs(recipe.products) do
							if( product.name == item.name ) then
								local pamount = product.amount;
								if( not pamount ) then
									pamount = product.max;
								end
								--log( "Found item : ".. item.name );
								local failed = false;
								for _,ingred in pairs( recipe.ingredients ) do	
									if( ingred.fluid ) then
										player.print( { "cannot-craft-fluid" } );
										return nil;
									end
									--local pcount = player.get_item_count( ingred.name );
									--if pcount < (ingred.amount*n) then
									missing_items[ingred.name] = { count= (ingred.amount*n)-player.get_item_count( ingred.name ), need=(ingred.amount*n), subItems={} };									
									--end
								end
								if next(missing_items) then
									for name,missing in pairs( missing_items ) do
										--log( "See if we have enough items for:".. name.. " ".. missing.count );
										enough_items( missing.subItems, name, missing.count, player, missing_items );
									end
								end
								--log_keys( missing_items );
								if not resolve_needs( missing_items ) then
									local items = formatMissing( missing_items, player, 0 );
									if( items ) then
										player.print( { "missing-ingredient" } );
										local n;
										for n=1,#items do
											--log_keys( items[n] );
											player.print( items[n] );
										end
										return nil;
									end
								end
								--log( "product:"..num.."  "..product.name .. " item:".. item.name.. " place:"..item.place_result.name );
								
								return rname;
							end
						end
					else
						for num,product in pairs(recipe.products) do
							if( product.name == item.name ) then
								player.print( { "cannot-hand-craft" } );
								return nil;
							end
						end
						--log( "Skipping recipe:"..recipe.name.. " cat:".. recipe.category );
					end
				end
		end
	else
		player.print( { "cannot-hand-craft" } );
	end
	return nil;
end

script.on_event("key-point-and-craft", function(event)
  local player = game.players[event.player_index]
  local entity = player.selected
  if not entity then
     return;
  end
  if player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read then
     --log( "Have a stack in hand?".. player.cursor_stack.name );
    player.print( { "must-be-empty" } );
    return;
  end
  if( entity.name == "item-on-ground" ) then
    player.print( { "must-be-built" } );
    return;
  end
  --log( "craft a thing?".. entity.name );
  if entity then
	local recipe = findRecipe( entity.name, 1, player );
	if recipe then
		--log( "craft... ".. recipe );
		player.begin_crafting{ count=1, recipe=recipe, silent=false };
	end
  end
end)

script.on_event("key-point-and-craft-5", function(event)
  local player = game.players[event.player_index]
  local entity = player.selected
  if not entity then
     return;
  end
  if player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read then
     --log( "Have a stack in hand?".. player.cursor_stack.name );     
    player.print( { "must-be-empty" } );
     return;
  end
  if( entity.name == "item-on-ground" ) then
    player.print( { "must-be-built" } );
    return;
  end
  if entity then
	local recipe = findRecipe( entity.name, 5, player );
        if recipe then
		--log( "craft... 5x".. recipe );
		player.begin_crafting{ count=5, recipe=recipe, silent=false };
	end
  end
end)
