
local item_recipe = {};

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

function init_item_recipe_map() 
	--log( "Init item_recipe map" );
	for rname,recipe in pairs( game.recipe_prototypes ) do
		if( recipe.category == "crafting" or recipe.category=="electronics" ) then
			--log( "Storing recipe:"..recipe.name .. " type:".. recipe.category);
			--log_keys( recipe );
			if not recipe.hidden then
				for num,product in pairs(recipe.products) do
					if item_recipe[product.name] then
						--log( "Duplicate recipe for the item.".. product.name.. " to be "..recipe.name .. " was "..item_recipe[product.name] );
						item_recipe[product.name][#item_recipe[product.name]+1] = recipe;
					else
						item_recipe[product.name] = { recipe };
					end
				end
			else
				--log( "Skipping recipe hidden:"..recipe.name);
			end
		else
			--log( "Skipping recipe:"..recipe.name .. " type:".. recipe.category);
		end
	end
end

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
	local recipes = item_recipe[itemName];
	local i;
	local result;
	if not recipes then
		--log( "Failed to get recipes for item:"..itemName );
		return {error="cannot-hand-craft", recipe=nil};
	end
	for i=1,#recipes do
		local recipe = recipes[i]
			--log( "recipe:".. recipe.name.. " cat:".. recipe.category.." enable:"..tostring(recipe.hidden))
			if player.force.recipes[recipe.name].enabled then
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
							--log( "is all items the same as items?".. tostring(allItems == items) );
							if allItems == items then pamount = 1 end -- override pcount for root item
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
				return { error=nil, recipe=recipe };
			else
				--log( "Skipping recipe:"..recipe.name );
				return { error="recipe-locked" };
			end
		--end
	end
end

function resolve_needs( allItems ) 
	local enough = true;
	--log( "resolve all items in:".. tostring(allItems ).. "first:"..tostring(next(allItems)) );
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

function doWork( findname, n, player )
	local missing_items={};
	--log( "Find if I can make a "..findname );
	local result = enough_items( missing_items, findname, n, player, missing_items );
	if result.error then
		--log( "enough Items return error:"..result.error );
		--player.print( { "cannot-hand-craft" } );
		return result;
	end
	if not resolve_needs( missing_items ) then
		local items = formatMissing( missing_items, player, 0 );
		if( items ) then
			--player.print( { "missing-ingredient" } );
			return { error = "missing-ingredient", detail=items, recipe=nil };
		end
	end
	return result;
end  

function findRecipe( findname, n, player ) 
	local missing_items={};
	--log( "SEARCH for"  .. findname )
	local result;
	if game.entity_prototypes[findname].items_to_place_this then
		--log( "More than one??" );
		--for _,item in pairs( game.entity_prototypes[findname].items_to_place_this ) do
		--	log( " item to place:".._.." it:"..item.name );
		--end
		for _,item in pairs( game.entity_prototypes[findname].items_to_place_this ) do
			result = doWork( item.name, n, player );
			if result.error then return result end;
		end
	else
		--player.print( { "cannot-hand-craft" } );
		return { error = "cannot-hand-craft", recipe=nil };
	end
	return result;
end

function craftThing( entity, count, player ) 
	if not next( item_recipe ) then
		init_item_recipe_map();
	end

	local result = nil;
	if not entity then
		 return;
	end

	if player.cursor_stack and player.cursor_stack.valid and player.cursor_stack.valid_for_read then
		 --log( "Have a stack in hand?".. player.cursor_stack.name );
		player.print( { "must-be-empty" } );
		return;
	end

	local entName = entity.name;
	if( entity.name == "item-on-ground" ) then
		local stack = entity.stack;
		if stack.valid_for_read then 
			--log( " item stack name:"..stack.name.. " has ".. stack.count.." type?"..stack.type .. " pro:"..stack.prototype.name);
			result = doWork( stack.name, count, player );
			
			if result.error then
				player.print( {"",{ result.error }," ",stack.prototype.localised_name } );
				if result.detail then
					local items = result.detail;
					local n;
					for n=1,#items do
						--log_keys( items[n] );
						player.print( items[n] );
					end
				end
				return;
			end
			--if result.recipe then
			--	log( "on-ground recipe name:"..tostring(result.recipe.name) );
			--end
		else			
			player.print( { "fault-identifying-ground-item" } );
			return;
		end
		--	 player.print( { "must-be-built" } );
		--return;
	else 
		if( entity.name == "entity-ghost" ) then
			--log( "type:"..entity.ghost_type );
			entName = entity.ghost_name;
		end
		if entName then
			--log( "craft a thing?".. tostring( entName ) );
			result = findRecipe( entName, count, player );
			if not result then
				player.print( {"",{ "cannot-hand-craft" }," ",{"entity-name."..entName} } );
			end
		end
	end
	--log( "result:".. tostring(result.error).. " r:".. tostring(result.recipe ) );

	if result.recipe then
		--log( "craft... ".. recipe );
		player.begin_crafting{ count=count, recipe=result.recipe.name, silent=false };
	else
		player.print( {"",{ result.error }," ",{"entity-name."..entName} } );
		if result.detail then
			local items = result.detail;
			local n;
			for n=1,#items do
				--log_keys( items[n] );
				player.print( items[n] );
			end
		end
	end
end


script.on_event("key-point-and-craft", function(event)
	local player = game.players[event.player_index]
	local entity = player.selected
	craftThing( entity, 1, player );
end)

script.on_event("key-point-and-craft-5", function(event)
	local player = game.players[event.player_index]
	local entity = player.selected
	craftThing( entity, 5, player );
end)

