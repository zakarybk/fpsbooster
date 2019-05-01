--[[

	FPS Booster by Hackcraft @ 2019

	Version 1

	This is a little more than just an FPS booster. It allows you to create config
	files to run a set of console commands when the script loads, or when you
	tell it to run. Everything has an autocomplete to help with typing commands.

--]]

if SERVER then return end


print( "FPS BOOST LOADED!\nType fpsbooster_help for a list of all the commands!" )

local autofpsboost = CreateClientConVar( "auto_fpsboost", "0", true, false )

--cvarlist log fpsbooster_cvarlist.txt -- -condebug

local directory = "fpsbooster" -- For save/read

local configIdentifier = "[fpsbooster]"
local autorunIdentifier = "[autorun]"
local configFiles = {}
local autorunFiles = {}

local defaultConfigPath = "fpsbooster/default_configs"
local cvarsFile = "fpsbooster/allcvars1.5.2019.txt"
local cvarsTable = "fpsbooster_cvars"
local blockedCommandsFile = "fpsbooster/blockedcommands.1.5.2019.txt"

local autoFirstArg = {}
local autoFunctions = {}

local currentValues = {}
local backedUpValues = {}

local blockedCommands = {}

local function toArgs(argsStr)
	return string.Split(argsStr, " ")
end

local function stripQuotes(word)
	return string.Replace(word, "\"", "")
end

local function trimElements(tab)
	for index, word in pairs(tab) do
		tab[index] = string.Trim(word)
	end

	return tab
end

local function splitLines(str)
	local delim = "\n"
	local res = {}
	local pattern = string.format("([^%s]+)%s", delim, delim)
	for line in str:gmatch(pattern) do
		table.insert(res, line)
	end
	return res
end

local function firstLine(str)
	local delim = "\n"
	local pattern = string.format("([^%s]+)%s", delim, delim)
	local out = string.gmatch(str, pattern)
	return out()
end

local function isCommand(command)
	return cvars.String(command, nil) != nil
end

local function isBlockedCommand(command)
	return table.HasValue(blockedCommands, command)
end

local function addAutoComplete(command, values, functions)
	autoFirstArg[command] = values

	if functions == nil then
		return
	end

	for i, val in pairs(values) do
		if functions[i] != nil then
			autoFunctions[command .. val] = functions[i]
		end
	end
end

local function runAutoComplete(command, argsStr)
	-- Keep consistency
	argsStr = argsStr or ""
	argsStr = string.Trim(argsStr)
	argsStr = string.lower(argsStr)

	local args = toArgs(argsStr)
	local tag = args[1]
	local output = {}

	if autoFirstArg[command] then

		if table.HasValue(autoFirstArg[command], tag) then
			if autoFunctions[command .. tag] then
				output = autoFunctions[command .. tag](command, args)
			end
		else
			for i, val in ipairs(autoFirstArg[command]) do
				table.insert(output, command .. " " .. val)
			end
		end

	end
	
	return output
end

local function isConfigFile(path)
	if path == nil then
		return false, "No file provided!"
	elseif not file.Exists(path, "DATA") then
		return false, "File does not exist!"
	end

	local data = file.Read(path, "DATA")
	local isValid = string.Left(data, #configIdentifier) == configIdentifier

	if isValid then
		return true
	else
		return false, "File does not contain fpsboost identifier!"
	end
end

local function isAutorunFile(path)
	if isConfigFile(path) then
		local data = file.Read(path, "DATA")
		local tags = string.Split(firstLine(data), " ")

		return table.HasValue(tags, autorunIdentifier)
	end
end

local function removeFirstLine(firstLine, data)
	return string.Right(data, #data - #firstLine)
end

local function enableAutorun(path)
	if isConfigFile(path) and not isAutorunFile(path) then
		local data = file.Read(path, "DATA")
		local fl = firstLine(data)
		local tags = string.Split(fl, " ")

		table.insert(tags, autorunIdentifier)

		local newFirst = table.concat(tags, " ")
		local newData = newFirst .. removeFirstLine(fl, data)

		file.Write(path, newData)
	end
end

local function disableAutorun(path)
	if isConfigFile(path) and isAutorunFile(path) then
		local data = file.Read(path, "DATA")
		local fl = firstLine(data)
		local tags = string.Split(fl, " ")

		table.RemoveByValue(tags, autorunIdentifier)

		local newFirst = table.concat(tags, " ")
		local newData = newFirst .. removeFirstLine(fl, data)

		file.Write(path, newData)
	end
end

local function findConfigFiles(path)
	local files, folders = file.Find(path .. "*", "DATA")
	local found = {}

	for i, fil in ipairs(files) do
		if isConfigFile(path .. fil) then
			table.insert(found, path .. fil)
		end
	end

	for i, fol in ipairs(folders) do
		findConfigFiles(path .. fol .. "/")
	end

	return found
end

-- Need to call refreshConfigFiles first -- uses configFiles table
local function findAutorunFiles()
	local files = {}

	for index, fil in ipairs(configFiles) do
		if isAutorunFile(directory .. "/" .. fil) then
			table.insert(files, fil)
		end
	end

	return files
end

local function refreshConfigFiles(dir)
	temp = findConfigFiles(dir .. "/") -- dir .. "/"
	for i, fil in ipairs(temp) do
		temp[i] = string.TrimLeft(fil, directory .. "/") 
	end
	configFiles = temp -- dir .. "/"
end

local function refreshAutorunFiles(dir)
	temp = findAutorunFiles(dir .. "/") -- dir .. "/"
	for i, fil in ipairs(temp) do
		temp[i] = string.TrimLeft(fil, directory .. "/") 
	end
	autorunFiles = temp -- dir .. "/"
end

local function stringLikeness(str1, str2)
	local score = 0
	local str1Letters = {}
	local str2Letters = {}

	str1 = string.ToTable(str1)
	str2 = string.ToTable(str2)

	-- Score+ for same chars at index
	for index, char in pairs(str1) do
		-- Identical spots
		if char == str2[index] then
			score = score + 1
		end

		-- Number of each char in string
		if str1Letters[char] == nil then
			str1Letters[char] = 1
		else
			str1Letters[char] = str1Letters[char] + 1
		end
	end

	-- Number of each char in string
	for index, char in pairs(str2) do
		if str2Letters[char] == nil then
			str2Letters[char] = 1
		else
			str2Letters[char] = str2Letters[char] + 1
		end
	end

	-- Compare char counts
	for char, count in pairs(str1Letters) do
		if str2Letters[char] != nil then
			local diff = count - str2Letters[char]
			diff = 1 - math.abs(diff / str2Letters[char])
			score = score + 1
		end
	end

	return score
end

local function fileAutoComplete(command, args)
	local tag = args[1]
	local path = args[2] or ""

	if #path > 0 then
		table.sort(configFiles, function(a, b) return stringLikeness(a, path) > stringLikeness(b, path) end)
	end
	output = table.Copy(configFiles)

	-- Add the command prefix and stuff before each possible file to allow items to be correctly selected
	for i, f in ipairs(output) do
		output[i] = command .. " " .. tag .. " " .. f
	end

	if #output < 1 and (tag == "run" or tag == "forcerun" or tag == "delete") then
		output[1] = "No config files with the name: " + path
	end

	return output
end

local function autorunAutoComplete(command, args)
	local tag = args[1]
	local path = args[2] or ""
	local output = {}

	if tag == "enable" then
		output = table.Copy(configFiles)

		for index, con in pairs(output) do
			if table.HasValue(autorunFiles, con) then
				output[index] = nil
			end
		end
	elseif tag == "disable" then
		output = table.Copy(autorunFiles)
	end

	if #path > 0 then
		table.sort(configFiles, function(a, b) return stringLikeness(a, path) > stringLikeness(b, path) end)
	end

	-- Add the command prefix and stuff before each possible file to allow items to be correctly selected
	for i, f in ipairs(output) do
		output[i] = command .. " " .. tag .. " " .. f
	end

	if #output < 1 then
		if tag == "enable" then
			output[1] = "There are no config files! Save one with 'fpsbooster_file save filename.txt'"
		elseif tag == "disable" then
			output[1] = "There are no files set to autorun!"
		end
	end

	return output
end

local function commandAutoComplete(command, args)
	local tag = args[1]
	local cvar = args[2] or ""

	local output = {}

	if #cvar > 0 then
		
		-- Cvar list
		local tab = sql.Query(string.format("SELECT * FROM %s WHERE cvar LIKE '%s'", cvarsTable, cvar .. "%"))

		local isSinglePlayer = game.SinglePlayer()
		local cheats = GetConVar("sv_cheats"):GetBool()

		-- Add to putput if we got a result
		if tab then
			for index, results in ipairs(tab) do

				local shouldAdd = true

				if not isSinglePlayer and results["serverSide"] then
					shouldAdd = false
				elseif not isSinglePlayer and results["requiresCheats"] and not cheats then
					shouldAdd = false
				end

				if shouldAdd then
					if isCommand(results["cvar"]) then
						table.insert(output, results["cvar"] .. " " .. cvars.String(results["cvar"]))
					else
						table.insert(output, results["cvar"])
					end
				end

			end
		end

		-- Console command list
		local commandList, completeList = concommand.GetTable()

		-- Add all the possible command together
		table.Merge(commandList, completeList)
		table.Merge(output, commandList)

		-- Sort commands by the closest to the input
		table.sort(output, function(a, b) return stringLikeness(a, cvar) > stringLikeness(b, cvar) end)
	end

	-- Add the command prefix and stuff before each possible cvar to allow items to be correctly selected
	for i, f in ipairs(output) do
		output[i] = command .. " " .. tag .. " " .. f
	end

	return output
end

local function currentCommandsAutoComplete(command, args)
	local tag = args[1]
	local cvar = args[2] or ""

	local output = {}

	for con, val in pairs(currentValues) do
		table.insert(output, con .. " " .. val)
	end

	if #cvar > 1 then
		table.sort(output, function(a, b) return stringLikeness(a, cvar) > stringLikeness(b, cvar) end)
	end

	-- Add the command prefix and stuff before each possible cvar to allow items to be correctly selected
	for i, f in pairs(output) do
		output[i] = command .. " " .. args[1] .. " " .. f
	end

	return output
end

local helpText = {
	["_file"] = {
		["run"] = {
			argsStr = "<filename.txt>",
			help = "Executes the commands in the file."
		},
		["save"] = {
			argsStr = "<filename.txt>",
			help = "Saves the added commands from 'fpsbooster_command add', and the active ones from any recently executed configs, to a file."
		},
		["delete"] = {
			argsStr = "<filename.txt>",
			help = "Deletes the config file specified."
		},
		["refresh"] = {
			help = "Refreshes the files shown in the auto complete in 'fpsbooster_file', adding any new files to the list."
		},
		["forcerun"] = {
			argsStr = "<filename.txt>",
			help = "Same as 'run' but doesn't check if a command exists. Useful for running source engine commands. However 'fpsbooster_revert' will not be able to revert the source engine commands run with this."
		},
		["help"] = {
			help = "Print help for the _file command"
		},
	},
	["_command"] = {
		["add"] = {
			argsStr = "<command> <arg>",
			help = "Adds and executes the command and any arguements to a temporary list. You will need to use 'fpsbooster_save' after, to save them permanently."
		},
		["remove"] = {
			argsStr = "<command>",
			help = "Removes the command from the temporary list. Again, 'fpsbooster_save' will need to be used to make the change permanent. Type 'fpsbooster_remove *' to clear the command list."
		},
		["print"] = {
			help = "Prints the active commands in the temporary list. Includes ones you have added yourself, and any added by 'fpsbooster_run'. This is the list which will be saved when you run 'fpsbooster_save'."
		},
		["forceadd"] = {
			argsStr = "<command> <arg>",
			help = "Same as 'add' but doesn't check if a command exists. Useful for running source engine commands. However 'fpsbooster_revert' will not be able to revert the source engine commands run with this."
		},
		["help"] = {
			help = "Print help for the _command command"
		}
	},
	["_autorun"] = {
		["enable"] = {
			argsStr = "<filename.txt>",
			help = "When in singleplayer or running the script in multiplayer, the set file will be run automatically."
		},
		["disable"] = {
			argsStr = "<filename.txt>",
			help = "Stop fpsbooster from loading the file when it launches."
		},
		["status"] = {
			argsStr = "<filename.txt>",
			help = "See which files have autorun enabled."
		},
		["help"] = {
			argsStr = "<filename.txt>",
			help = "Print help for the _autorun command"
		}
	},
	["_revert"] = {
		help = "Standalone command. Whenever a config is loaded with 'fpsbooster_run', a backup of the previous values is made. Running this command will load the backup."
	},
	["_help"] = {
		help = "Prints help for all commands at once."
	}
}

local function printHelpText(index)
	for key, tab in pairs(helpText[index]) do
		-- Special case
		if key == "help" and not istable(tab) then
			print("fpsbooster" .. index)
			print(tab)
			print()
		-- Normal case
		else
			print("fpsbooster_" .. index .. " " .. key .. " " .. (tab["argsStr"] or ""))
			print(tab["help"])
			print()
		end
	end
end

-- File format
-- [fpsbooster]\n

-- Commands
-- fpsbooster_file run/save/delete/refresh (name.txt)

-- fpsbooster_command add/remove/print -- no command verification checking

-- fpsbooster_autorun enable/disable/status/name.txt

-- fpsbooster_help all/file/command/autorun

-- Future
-- fpsbooster_revert
-- fpsbooster_web www.pastebin.com/raw ?

-- Convar
-- fpsbooster_allowserveroverride

local function executeCommand(command, arg, reverting, noCommandCheck)
	-- Run each command
	if command != nil and arg != nil then

		-- Verify command
		if noCommandCheck == nil and not isCommand(command) then
			print("Unable to run command. " .. command)
			print("Command may not exists or it's an interal/source command which means that we cannot save the value in case you need to revert back.")
			print("If you are not worried about not being able to revert the command without restarting your game. Then use 'fpsbooster_file forcerun filename.txt'")
			return
		end

		-- Blocked
		if isBlockedCommand(command) then
			print("Command: " .. command .. " cannot be executed by a script. It can only be executed directly from console!")
			return
		end

		-- Backup values before setting
		if not reverting and isCommand(command) then
			table.insert(backedUpValues, command .. " " .. cvars.String(command, ""))
		end

		-- Local save
		currentValues[command] = arg
		-- Execute
--		print(command, arg)
		RunConsoleCommand(command, arg)
	else
		print(command .. " is missing arguements!")
	end
end


local function loadValues(lines, reverting, noCommandCheck)
	-- No point in backing up the values we're changing to
	if reverting then
		lines = table.Copy(backedUpValues)
		backedUpValues = {}
	end

	for i, line in ipairs(lines) do

		-- Split up command and arg
		split = toArgs(line)
		command = split[1]
		arg = split[2] or ""

		executeCommand(command, arg, reverting, noCommandCheck)
	end
end

local function loadValuesFromFile(fil, noCommandCheck)
	fil = file.Read(fil, "DATA")

	-- Split up by lines
	lines = splitLines(fil)
	table.remove(lines, 1) -- Remove header

	loadValues(lines, false, noCommandCheck)
end

-- Create inital config file references
refreshConfigFiles(directory .. "/")
refreshAutorunFiles(directory .. "/")

--
-- Startup/setup - move over defaults
--

local function setup()
	-- Load blocked cvars
	blockedCommands = splitLines(file.Read("lua/" .. blockedCommandsFile, "GAME"))

	-- Put cvars into sql
	if not file.IsDir(directory, "DATA")  then
		file.CreateDir(directory)
	end

	local configLock = "do_not_re_add_default_configs.txt"

	if not file.Exists(directory .. "/" .. configLock, "DATA") then
		
		-- Add lock - stop config files from being moved over again!
		file.Write(directory .. "/" .. configLock, [[[placeholder] Remove me if you want the default fpsbooster config files to be added into this directory again! Make sure to restart GMod.]])

		local path = "lua/"..defaultConfigPath.."/"
		local defaultConfigs = file.Find(path .. "*", "GAME")
		-- Move the config files over
		for i, config in ipairs(defaultConfigs) do

			local dcp = path .. config
			
			if file.Exists(dcp, "GAME") then
				if not file.Exists(directory .. "/" .. config, "DATA") then
					-- Read the hard copy
					local data = file.Read(dcp, "GAME")
					-- Create a copy in /data
					file.Write(directory .. "/" .. config, data)
					-- Update autocomplete
					table.insert(configFiles, config)
				else
					print("Skipping existing file: " .. config)
				end
			else
				print("Config not found: " .. config)
			end

		end

	end
end
setup()
--
-- fpsbooster_file
--

local function dictToString(dict)
	local str = ""

	for key, val in pairs(dict) do
		str = str .. key .. " " .. val .. "\n"
	end

	return str
end

addAutoComplete("fpsbooster_file", 
	{"run", "save", "delete", "refresh", "forcerun", "help"}, 
	{fileAutoComplete, fileAutoComplete, fileAutoComplete, fileAutoComplete, fileAutoComplete}
)

concommand.Add("fpsbooster_file", function(ply, cmd, args, argStr) -- fpsbooster_file help?
	-- Cleanup
	for index, word in ipairs(args) do
		args[index] = stripQuotes(word)
	end
	
	local tag = args[1]

	-- Refresh first - no arguement processing
	if tag == "refresh" then
		refreshConfigFiles(directory .. "/")
		refreshAutorunFiles(directory .. "/")
		print("Refreshed config files list. New ones should now show in auto complete!")
		return
	elseif tag == "help" then
		printHelpText("_file")
		return
	end

	-- File validity
	local fil = args[2]
	local path = directory .. "/" .. fil
	local isValid, reason = isConfigFile(path)

	-- Attempt to save to the file
	if tag == "save" then
		-- Save
		print(directory .. "/" .. fil)
		file.Write(directory .. "/" .. fil, configIdentifier .. "\n" .. dictToString(currentValues))
		-- Update autocomplete
		table.insert(configFiles, fil)
		print("Saved settings to " .. fil)
		return
	end

	-- run and delete need a file to work with
	if not isValid then
		print(reason)
		return
	end

	-- Other commands
	if tag == "run" then

		loadValuesFromFile(path)

		print("Running " .. fil)

	elseif tag == "forcerun" then

		loadValuesFromFile(path, true)

		print("Running " .. fil)

	elseif tag == "delete" then
		-- Delete
		file.Delete(path)
		-- Update autocomplete
		table.RemoveByValue(configFiles, fil) 

		print("Deleted " .. fil)
		
	end
end,
runAutoComplete,
"Run any text file in the data folder to apply settings (run console commands)")

addAutoComplete("fpsbooster_revert", 
	{"", "help"}
)
concommand.Add("fpsbooster_revert", function(ply, cmd, args, argStr)
	-- Cleanup
	for index, word in ipairs(args) do
		args[index] = stripQuotes(word)
	end
	
	local tag = args[1]

	if tag == "help" then
		printHelpText("_revert")
		return
	end

	if #backedUpValues < 1 then
		print("No values to revert to!")
	else
		loadValues("", true)
	end
end,
nil,
"Sets everything back to their values before loading the last file.")

concommand.Add("fpsbooster_help", function(ply, cmd, args, argStr)
	printHelpText("_file")
	printHelpText("_command")
	printHelpText("_autorun")
	printHelpText("_revert")
end,
nil,
"Print help.")


--
-- fpsbooster_command -- another go at list but only keep ones with values?
--

-- Use SQL for autocomplete as the cvars list is really long

local function addCVarsToSQL()
	if sql.TableExists("fpsbooster_cvars") then
		return
--		print("Table already exists")
--		sql.Query("DROP TABLE fpsbooster_cvars")
	end

	-- Create a table with the console variable and whether it can be executed in multiplayer
	sql.Query(string.format("CREATE TABLE %s(cvar TEXT, serverSide BIT, requiresCheats BIT)", cvarsTable))

	-- File location of cvars list
	local fil = "lua/" .. cvarsFile

	if not file.Exists(fil, "GAME") then
		print("Cvars list is missing from the addon!")
		return
	end

	-- Load and add to sql
	local data = file.Read(fil, "GAME")
	local lines = splitLines(data)
	local cvar, serverSide, requiresCheats, sections, tags

	local cvarIndex = 1
	local valuesIndex = 2
	local tagIndex = 3
	local descIndex = 4

	local boolNum = {
		[true] = 1,
		[false] = 0
	}

	sql.Begin()

	for index, line in ipairs(lines) do

		sections = string.Split(line, ":")

		cvar = string.Trim(sections[cvarIndex])
		tags = sections[tagIndex] != nil and string.Split(stripQuotes(sections[tagIndex]), ",") or {}
		trimElements(tags)

		serverSide = boolNum[table.HasValue(tags, "sv")]
		requiresCheats = boolNum[table.HasValue(tags, "cheat")]

		print(cvar, serverSide, requiresCheats)

		sql.Query(string.format("INSERT INTO %s(cvar, serverSide, requiresCheats) VALUES(%s, %d, %d)",
			cvarsTable,
			sql.SQLStr(cvar),
			serverSide,
			requiresCheats
		))

	end

	sql.Commit()

/*
	local tab = sql.Query("SELECT * FROM " .. cvarsTable)

	if not tab then
		print("ERROR")
		print(sql.LastError())
	else
		PrintTable(tab)
	end
*/

end
addCVarsToSQL()

addAutoComplete("fpsbooster_command", 
	{"add", "remove", "print", "forceadd", "help"},
	{commandAutoComplete, currentCommandsAutoComplete, nil, commandAutoComplete}
)

concommand.Add("fpsbooster_command",function(ply, cmd, args, argStr)
	-- Cleanup
	for index, word in ipairs(args) do
		args[index] = stripQuotes(word)
	end
	
	local tag = args[1]
	local command = args[2]

	if tag == "print" then
		PrintTable(currentValues)
		return
	elseif tag == "help" then
		printHelpText("_command")
		return
	end

	if command == nil then
		print("No command input!")
		return
	end

	if tag == "add" then
		-- Valid command check
		if not isCommand(command) then
			print("Command not found. Use fpsbooster_command forceadd if this is wrong!")
		else
			-- Save
			local val = args[3] or ""
			currentValues[command] = val

			print(command, val)

			-- Execute
			executeCommand(command, val, false, false)
		end

	elseif tag == "forceadd" then
		-- Save
		local val = args[3] or ""
		currentValues[command] = val

		-- Execute
		executeCommand(command, val, false, true)
		
	elseif tag == "remove" then
		if currentValues[command] == nil then
			print("Command was not in list")
		else
			currentValues[command] = nil
		end
	end


end,
runAutoComplete,
"Add commands to be executed...")

--
-- fpsbooster_autorun
--

addAutoComplete("fpsbooster_autorun",
	{"enable", "disable", "status", "help"}, 
	{autorunAutoComplete, autorunAutoComplete, nil}
)

concommand.Add("fpsbooster_autorun",function(ply, cmd, args, argStr)
	-- Cleanup
	for index, word in ipairs(args) do
		args[index] = stripQuotes(word)
	end
	
	local tag = args[1]
	local command = args[2]

	if tag == "status" then
		if #autorunFiles > 0 then
			print("The following files have autorun enabled:")
			PrintTable(autorunFiles)
		else
			print("No files are currently set to autorun.")
		end
		return
	elseif tag == "help" then
		printHelpText("_autorun")
		return
	end

	-- File validity
	local fil = args[2]
	local path = directory .. "/" .. fil
	local isValid, reason = isConfigFile(path)

	if tag == "enable" then
		
		enableAutorun(path)
		print("Enabled autorun for: " .. fil)

	elseif tag == "disable" then

		disableAutorun(path)
		print("Disabled autorun for: " .. fil)

	end

end,
runAutoComplete,
"Allows files to be executed on start...")


--
-- Depricated commands
--

-- Changed command - keep old to stop confusion
concommand.Add("fpsboost", function()
	print("This command is depricated.")
	print("Please use 'fpsbooster_file run fpsboost.txt' instead!")

	RunConsoleCommand("fpsbooster_file", "run", "fpsboost.txt")
end,
nil,
"Please use fpsbooster_boost instead!")

concommand.Add( "horid_textures", function( ply )
	print("This command is depricated.")
	print("Please use 'fpsbooster_file run horrid_textures.txt' instead!")

	RunConsoleCommand("fpsbooster_file", "run", "horrid_textures.txt")
end)

concommand.Add( "fps_help", function( ply )
	print("This command is depricated.")
	print("Please use 'fpsbooster_help' instead!")

	RunConsoleCommand("fpsbooster_help")
end)


--
-- Autorun
--
local function autorun()
	-- Run any files set to autorun
	for index, fil in pairs(autorunFiles) do
		RunConsoleCommand("fpsbooster_file", "run", fil)
	end

	-- Backwards compatibility with previous version
	if autofpsboost:GetBool() then
		RunConsoleCommand("fpsbooster_file", "run", "fpsboost.txt") 
	end
end
autorun()


-- No longer in use -- cannot get default values for values which only appear in cvarlist anyway
-- Thing -- Run cvarlist log with -condebug and pass the section with cvars through this
-- to only save engine only commands

/*
local extraCvars = "fpsbooster/cvars.1.5.2019.txt" -- For Lua/hard data
local function isHiddenCommand(command)
	local fil = file.Read(extraCvars, "LUA")
	local lines = splitLines(fil)
	
	if table.HasValue(lines, command) then
		return true
	else
		return false
	end
end

local cvarFile = file.Read("fpsbooster/default_configs/fpsboost.txt", "LUA")

local lines = splitLines(cvarFile)

for i, line in pairs(lines) do
	command = toArgs(line)[1]

	print(command, isCommand(command), isHiddenCommand(command))

	if not isCommand(command) then

--		print(command, isCommand(command), isHiddenCommand(command))

--		print(isHiddenCommand(command))

--		file.Append("newlistthing.txt", command .. "\n")
		
--		print(command)

	end
end
*/
/*
--view-source:http://wiki.garrysmod.com/page/Blocked_ConCommands
--http://www.convertcsv.com/html-table-to-csv.htm
local csvFile = file.Read("lua/fpsbooster/blockedcommands.1.5.2019.txt", "GAME")
print(csvFile)
local lines = splitLines(csvFile)

for i, line in pairs(lines) do
	command = string.Split(line, ",")[1]
	file.Append("newlistthing2.txt", command .. "\n")
end
*/