-- Capability Probe is intentionally a small, complete preview SDK example.
-- @include "@cubacadabra/shared-state-v1.luau"
-- @include "@cubacadabra/disclosure-v1.luau"

local Game = {}

local state_store
local objective
local visits = 0
local last_sensor = "none"
local slider_value = 0.5

local function initial_state()
    return { version = 1, visits = 0, lastSensor = "none" }
end

local function validate_state(value)
    if type(value) ~= "table"
        or value.version ~= 1
        or type(value.visits) ~= "number"
        or value.visits < 0
        or type(value.lastSensor) ~= "string"
    then
        return nil
    end
    return {
        version = 1,
        visits = math.floor(value.visits),
        lastSensor = string.sub(value.lastSensor, 1, 32),
    }
end

local function reduce_state(state, intent)
    if intent.type ~= "visit"
        or type(intent.sensor) ~= "string"
        or type(intent.expectedVisits) ~= "number"
        or intent.expectedVisits ~= math.floor(intent.expectedVisits)
    then
        return nil
    end
    -- A queued intent is complete once an authoritative snapshot advances the
    -- counter from the value observed when this visit was dispatched. This is
    -- required because the shared-state helper retries compare-and-set calls.
    if state.visits ~= intent.expectedVisits then
        return nil
    end
    return {
        version = 1,
        visits = state.visits + 1,
        lastSensor = intent.sensor,
    }
end

local function set_status(api, text)
    api.ui:set_text("probe-status", text)
    api.ui:set_text("probe-count", string.format("SHARED VISITS  %d", visits))
    api.ui:set_text("probe-sensor", "LAST SENSOR  " .. last_sensor)
    api.ui:set_value("probe-slider", slider_value)
end

local function on_state_change(api, state, previous)
    visits = state.visits
    last_sensor = state.lastSensor
    api.effects:set_state("probe-left", last_sensor == "probe-left" and "visited" or "default")
    api.effects:set_state("probe-right", last_sensor == "probe-right" and "visited" or "default")
    api.effects:set_state("probe-finish", last_sensor == "probe-finish" and "visited" or "default")
    if previous ~= nil and state.visits > previous.visits then
        api.effects:play("probe-pulse", { position = { 0, 0, 0 } })
        api.audio:play("probe-ping")
    end
    set_status(api, "ACCEPTED  " .. last_sensor)
end

state_store = CubaSharedState.create({
    channel = "probe-shared-state",
    initial = initial_state,
    validate = validate_state,
    reduce = reduce_state,
    onChange = on_state_change,
})

objective = CubaDisclosure.create({
    action = "probe.objective.toggle",
    triggerId = "probe-objective",
    nodeIds = { "probe-detail" },
})

local function document()
    return {
        nodes = {
            {
                id = "probe-title",
                kind = "text",
                text = "CAPABILITY PROBE",
                layout = { anchor = "top", width = 260, height = 32, offset = { 20, 20 } },
                style = { color = "#173B43", fontSize = 20 },
            },
            {
                id = "probe-status",
                kind = "text",
                text = "CONNECTING TO SHARED STATE",
                layout = { anchor = "top", width = 330, height = 28, offset = { 20, 55 } },
                style = { color = "#47766F", fontSize = 14 },
            },
            {
                id = "probe-count",
                kind = "text",
                text = "SHARED VISITS  0",
                layout = { anchor = "top", width = 220, height = 24, offset = { 20, 86 } },
                style = { color = "#173B43", fontSize = 12 },
            },
            {
                id = "probe-sensor",
                kind = "text",
                text = "LAST SENSOR  none",
                layout = { anchor = "top", width = 260, height = 24, offset = { 20, 111 } },
                style = { color = "#173B43", fontSize = 12 },
            },
            {
                id = "probe-slider-label",
                kind = "text",
                text = "LOCAL SLIDER",
                layout = { anchor = "top", width = 160, height = 22, offset = { 20, 148 } },
                style = { color = "#47766F", fontSize = 12 },
            },
            {
                id = "probe-slider",
                kind = "slider",
                value = 0.5,
                min = 0,
                max = 1,
                step = 0.05,
                action = "probe.slider",
                layout = { anchor = "top", width = 210, height = 36, offset = { 20, 170 } },
            },
            {
                id = "probe-objective",
                kind = "toggle",
                text = "SHOW OBJECTIVE",
                checked = false,
                action = "probe.objective.toggle",
                layout = { anchor = "top", width = 210, height = 44, offset = { 20, 214 } },
            },
            {
                id = "probe-detail",
                kind = "text",
                text = "Walk through all three sensors. Open this panel, move the slider, then clear the UI.",
                visible = false,
                layout = { anchor = "top", width = 330, height = 54, offset = { 20, 260 } },
                style = { color = "#47766F", fontSize = 12 },
            },
            {
                id = "probe-clear",
                kind = "button",
                text = "CLEAR UI",
                action = "probe.clear",
                layout = { anchor = "bottom", width = 150, height = 44, offset = { 20, 20 } },
            },
        },
    }
end

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.lobby:set_status("Capability probe ready")
    api.session:start("capability-probe", { mode = "preview" })
    api.ui:set_document(document())
    objective:sync(api)
    objective:set_open(api, false)
    state_store:start(api)
    set_status(api, "WAITING FOR A SENSOR")
end

function Game.on_launch(api, launch)
    api.session:start("capability-probe:" .. launch.pad_id, {})
end

function Game.on_interaction(api, event)
    if event.phase ~= "enter" then
        return
    end
    api.network:publish("probe-events", { sensor = event.id, players = event.players })
    api.network:set_state("probe-last-event", { sensor = event.id })
    state_store:dispatch(api, {
        type = "visit",
        sensor = event.id,
        expectedVisits = visits,
    })
end

function Game.on_network_message(api, event)
    if event.channel == "probe-shared-state" then
        state_store:receive(api, event)
    elseif event.channel == "probe-events" then
        api.ui:set_text("probe-status", "EVENT  " .. event.payload.sensor)
    end
end

function Game.on_ui_event(api, event)
    if objective:handle(api, event) then
        return
    end
    if event.action == "probe.slider" and type(event.value) == "number" then
        slider_value = event.value
        api.ui:set_text("probe-status", string.format("LOCAL SLIDER  %.2f", slider_value))
        api.ui:set_checked("probe-objective", slider_value > 0.5)
    elseif event.action == "probe.clear" then
        api.ui:clear()
    end
end

function Game.on_tick(api, delta_seconds)
    state_store:update(api, delta_seconds)
    local state = api.interactions:get_state()
    for id, zone in pairs(state.zones) do
        if zone.inside then
            last_sensor = id
        end
    end
end

return Game
