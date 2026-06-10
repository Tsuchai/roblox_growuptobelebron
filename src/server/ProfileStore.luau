--[[
MAD STUDIO (by loleris)

-[ProfileStore]---------------------------------------

	Periodic DataStore saving solution with session locking
	
	WARNINGS FOR "Profile.Data" VALUES:
	 	! Do not create numeric tables with gaps - attempting to store such tables will result in an error.
		! Do not create mixed tables (some values indexed by number and others by a string key)
			- only numerically indexed  data will be stored.
		! Do not index tables by anything other than numbers and strings.
		! Do not reference Roblox Instances
		! Do not reference userdata (Vector3, Color3, CFrame...) - Serialize userdata before referencing
		! Do not reference functions
		
	Members:
	
		ProfileStore.IsClosing          [bool]
			-- Set to true after a game:BindToClose() trigger
			
		ProfileStore.IsCriticalState    [bool]
			-- Set to true when ProfileStore experiences too many consecutive errors
		
		ProfileStore.OnError            [Signal] (message, store_name, profile_key)
			-- Most ProfileStore errors will be caught and passed to this signal
			
		ProfileStore.OnOverwrite        [Signal] (store_name, profile_key)
			-- Triggered when a DataStore key was likely used to store data that wasn't
			a ProfileStore profile or the ProfileStore structure was invalidly manually
			altered for that DataStore key
			
		ProfileStore.OnCriticalToggle   [Signal] (is_critical)
			-- Triggered when ProfileStore experiences too many consecutive errors
		
		ProfileStore.DataStoreState     [string] ("NotReady", "NoInternet", "NoAccess", "Access")
			-- This value resembles ProfileStore's access to the DataStore; The value starts
			as "NotReady" and will eventually change to one of the other 3 possible values.
	
	Functions:
	
		ProfileStore.New(store_name, template?) --> [ProfileStore]
			store_name   [string] -- DataStore name
			template     [table] or nil -- Profiles will default to given table (hard-copy) when no data was saved previously
			
		ProfileStore.SetConstant(name, value)
			name    [string]
			value   [number]
				
	Members [ProfileStore]:
	
		ProfileStore.Mock   [ProfileStore]
			-- Reflection of ProfileStore methods, but the methods will now query a mock
			DataStore with no relation to the real DataStore
			
		ProfileStore.Name   [string]
		
	Methods [ProfileStore]:
	
		ProfileStore:StartSessionAsync(profile_key, params?) --> [Profile] or nil
			profile_key [string] -- DataStore key
			params      nil or [table]: -- Custom params; E.g. {Steal = true}
				{
					Steal = true, -- Pass this to disregard an existing session lock
					Cancel = fn() -> (boolean), -- Pass this to create a request cancel condition.
						-- If the cancel function returns true, ProfileStore will stop trying to
						-- start the session and return nil
				}
			
		ProfileStore:MessageAsync(profile_key, message) --> is_success [bool]
			profile_key [string] -- DataStore key
			message     [table] -- Data to be messaged to the profile
			
		ProfileStore:GetAsync(profile_key, version?) --> [Profile] or nil
			-- Reads a profile without starting a session - will not autosave
			profile_key   [string] -- DataStore key
			version       nil or [string] -- DataStore key version

		ProfileStore:VersionQuery(profile_key, sort_direction?, min_date?, max_date?) --> [VersionQuery]
			profile_key      [string]
			sort_direction   nil or [Enum.SortDirection]
			min_date         nil or [DateTime]
			max_date         nil or [DateTime]
			
		ProfileStore:RemoveAsync(profile_key) --> is_success [bool]
			-- Completely removes profile data from the DataStore / mock DataStore with no way to recover it.

	Methods [VersionQuery]:

		VersionQuery:NextAsync() --> [Profile] or nil -- (Yields)
			-- Returned profile is similar to profiles returned by ProfileStore:GetAsync()
		
	Members [Profile]:
	
		Profile.Data               [table]
			-- When the profile is active changes to this table are guaranteed to be saved
		Profile.LastSavedData      [table] (Read-only)
			-- Last snapshot of "Profile.Data" that has been successfully saved to the DataStore;
			Useful for proper developer product purchase receipt handling
		
		Profile.FirstSessionTime   [number] (Read-only)
			-- os.time() timestamp of the first profile session
			
		Profile.SessionLoadCount   [number] (Read-only) -- Amount of times a session was started for this profile
			
		Profile.Session            [table] (Read-only) {PlaceId = number, JobId = string} / nil
			-- Set to a table if this profile is in use by a server; nil if released

		Profile.RobloxMetaData     [table] -- Writable table that gets saved automatically and once the profile is released
		Profile.UserIds            [table] -- (Read-only) -- {user_id [number], ...} -- User ids associated with this profile

		Profile.KeyInfo            [DataStoreKeyInfo] -- Changes before OnAfterSave signal
		
		Profile.OnSave             [Signal] ()
			-- Triggered right before changes to Profile.Data are saved to the DataStore
			
		Profile.OnLastSave         [Signal] (reason [string]: "Manual", "External", "Shutdown")
			-- Triggered right before changes to Profile.Data are saved to the DataStore
			for the last time; A reason is provided for the last save:
				- "Manual"   - Profile:EndSession() was called
				- "Shutdown" - The server that has ownership of this profile is shutting down
				- "External" - Another server has started a session for this profile
			Note that this event will not trigger for when a profile session is ended by
			another server trying to take ownership of the session - this is impossible to
			do without compromising on ProfileStore's speed.
			
		Profile.OnSessionEnd       [Signal] ()
			-- Triggered when the profile session is terminated on this server
		
		Profile.OnAfterSave        [Signal] (last_saved_data)
			-- Triggered after a successful save
			last_saved_data [table] -- Profile.LastSavedData
			
		Profile.ProfileStore       [ProfileStore] -- ProfileStore object this profile belongs to
		Profile.Key                [string] -- DataStore key
		
	Methods [Profile]:
	
		Profile:IsActive() --> [bool] -- If "true" is returned, changes to Profile.Data are guaranteed to save;
			This guarantee is only valid until code yields (e.g. task.wait() is used).
			
		Profile:Reconcile() -- Fills in missing (nil) [string_key] = [value] pairs to the Profile.Data structure
			from the "template" argument that was passed to "ProfileStore.New()"
			
		Profile:EndSession() -- Call after the server has finished working with this profile
			e.g., after the player leaves (Profile object will become inactive)

		Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)
			user_id   [number]

		Profile:RemoveUserId(user_id) -- Removes user_id association with profile (safe function)
			user_id   [number]
			
		Profile:MessageHandler(fn) -- Sets a message handler for this profile
			fn [function] (message [table], processed [function]())
			-- The handler function receives a message table and a callback function;
			The callback function is to be called when a message has been processed
			- this will discard the message from the profile message cache; If the
			callback function is not called, other message handlers will also be triggered
			with unprocessed message data.
			
		Profile:Save() -- If the profile session is still active makes an UpdateAsync call
			to the DataStore to immediately save profile data

		Profile:SetAsync() -- Forcefully saves changes to the profile; Only for profiles
			loaded with ProfileStore:GetAsync() or ProfileStore:VersionQuery()
		
--]]

local AUTO_SAVE_PERIOD = 300 -- (Seconds) Time between when changes to a profile are saved to the DataStore
local LOAD_REPEAT_PERIOD = 10 -- (Seconds) Time between successive profile reads when handling a session conflict
local FIRST_LOAD_REPEAT = 5 -- (Seconds) Time between first and second profile read when handling a session conflict
local SESSION_STEAL = 40 -- (Seconds) Time until a session conflict is resolved with the waiting server stealing the session
local ASSUME_DEAD = 630 -- (Seconds) If a profile hasn't had updates for this long, quickly assume an active session belongs to a crashed server
local START_SESSION_TIMEOUT = 120 -- (Seconds) If a session can't be started for a profile for this long, stop repeating calls to the DataStore

local CRITICAL_STATE_ERROR_COUNT = 5 -- Assume critical state if this many issues happen in a short amount of time
local CRITICAL_STATE_ERROR_EXPIRE = 120 -- (Seconds) Individual issue expiration
local CRITICAL_STATE_EXPIRE = 120 -- (Seconds) Critical state expiration

local MAX_MESSAGE_QUEUE = 1000 -- Max messages saved in a profile that were sent using "ProfileStore:MessageAsync()"

----- Dependencies -----

-- local Util = require(game.ReplicatedStorage.Shared.Util)
-- local Signal = Util.Signal

local Signal do

	local FreeRunnerThread

	--[[
		Yield-safe coroutine reusing by stravant;
		Sources:
		https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063
		https://gist.github.com/stravant/b75a322e0919d60dde8a0316d1f09d2f
	--]]

	local function AcquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquired_runner_thread = FreeRunnerThread
		FreeRunnerThread = nil
		fn(...)
		-- The handler finished running, this runner thread is free again.
		FreeRunnerThread = acquired_runner_thread
	end

	local function RunEventHandlerInFreeThread(...)
		AcquireRunnerThreadAndCallEventHandler(...)
		while true do
			AcquireRunnerThreadAndCallEventHandler(coroutine.yield())
		end
	end

	local Connection = {}
	Connection.__index = Connection

	local SignalClass = {}
	SignalClass.__index = SignalClass

	function Connection:Disconnect()

		if self.is_connected == false then
			return
		end

		local signal = self.signal
		self.is_connected = false
		signal.listener_count -= 1

		if signal.head == self then
			signal.head = self.next
		else
			local prev = signal.head
			while prev ~= nil and prev.next ~= self do
				prev = prev.next
			end
			if prev ~= nil then
				prev.next = self.next
			end
		end

	end

	function SignalClass.New()

		local self = {
			head = nil,
			listener_count = 0,
		}
		setmetatable(self, SignalClass)

		return self

	end

	function SignalClass:Connect(listener: (...any) -> ())

		if type(listener) ~= "function" then
			error(`[{script.Name}]: \"listener\" must be a function; Received {typeof(listener)}`)
		end

		local connection = {
			listener = listener,
			signal = self,
			next = self.head,
			is_connected = true,
		}
		setmetatable(connection, Connection)

		self.head = connection
		self.listener_count += 1

		return connection

	end

	function SignalClass:GetListenerCount(): number
		return self.listener_count
	end

	function SignalClass:Fire(...)
		local item = self.head
		while item ~= nil do
			if item.is_connected == true then
				if not FreeRunnerThread then
					FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
				end
				task.spawn(FreeRunnerThread, item.listener, ...)
			end
			item = item.next
		end
	end

	function SignalClass:Wait()
		local co = coroutine.running()
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			task.spawn(co, ...)
		end)
		return coroutine.yield()
	end

	Signal = table.freeze({
		New = SignalClass.New,
	})

end

----- Private -----

local ActiveSessionCheck = {} -- {[session_token] = profile, ...}
local AutoSaveList = {} -- {profile, ...} -- Loaded profile table which will be circularly auto-saved
local IssueQueue = {} -- {issue_time, ...}

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PlaceId = game.PlaceId
local JobId = game.JobId

local AutoSaveIndex = 1 -- Next profile to auto save
local LastAutoSave = os.clock()

local LoadIndex = 0

local ActiveProfileLoadJobs = 0 -- Number of active threads that are loading in profiles
local ActiveProfileSaveJobs = 0 -- Number of active threads that are saving profiles

local CriticalStateStart = 0 -- os.clock()

local IsStudio = RunService:IsStudio()
local DataStoreState: "NotReady" | "NoInternet" | "NoAccess" | "Access" = "NotReady"

local MockStore = {}
local UserMockStore = {}
local MockFlag = false

local OnError = Signal.New() -- (message, store_name, profile_key)
local OnOverwrite = Signal.New() -- (store_name, profile_key)

local UpdateQueue = { -- For stability sake, we won't do UpdateAsync calls for the same key until all previous calls finish
	--[[
		[session_token] = {
			coroutine, ...
		},
		...
	--]]
}

local function WaitInUpdateQueue(session_token) --> next_in_queue()

	local is_first = false

	if UpdateQueue[session_token] == nil then
		is_first = true
		UpdateQueue[session_token] = {}
	end

	local queue = UpdateQueue[session_token]

	if is_first == false then
		table.insert(queue, coroutine.running())
		coroutine.yield()
	end

	return function()
		local next_co = table.remove(queue, 1)
		if next_co ~= nil then
			coroutine.resume(next_co)
		else
			UpdateQueue[session_token] = nil
		end
	end

end

local function SessionToken(store_name, profile_key, is_mock)

	local session_token = "L_" -- Live

	if is_mock == true then
		session_token = "U_" -- User mock
	elseif DataStoreState ~= "Access" then
		session_token = "M_" -- Mock, cause no DataStore access
	end

	session_token ..= store_name .. "\0" .. profile_key

	return session_token

end

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function ReconcileTable(target, template)
	for k, v in pairs(template) do
		if type(k) == "string" then -- Only string keys will be reconciled
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = DeepCopyTable(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				ReconcileTable(target[k], v)
			end
		end
	end
end

local function RegisterError(error_message, store_name, profile_key) -- Called when a DataStore API call errors
	warn(`[{script.Name}]: DataStore API error (STORE:{store_name}; KEY:{profile_key}) - {tostring(error_message)}`)
	table.insert(IssueQueue, os.clock()) -- Adding issue time to queue
	OnError:Fire(tostring(error_message), store_name, profile_key)
end

local function RegisterOverwrite(store_name, profile_key) -- Called when a corrupted profile is loaded
	warn(`[{script.Name}]: Invalid profile was overwritten (STORE:{store_name}; KEY:{profile_key})`)
	OnOverwrite:Fire(store_name, profile_key)
end

local function NewMockDataStoreKeyInfo(params)

	local version_id_string = tostring(params.VersionId or 0)
	local meta_data = params.MetaData or {}
	local user_ids = params.UserIds or {}

	return {
		CreatedTime = params.CreatedTime,
		UpdatedTime = params.UpdatedTime,
		Version = string.rep("0", 16) .. "."
			.. string.rep("0", 10 - string.len(version_id_string)) .. version_id_string
			.. "." .. string.rep("0", 16) .. "." .. "01",

		GetMetadata = function()
			return DeepCopyTable(meta_data)
		end,

		GetUserIds = function()
			return


