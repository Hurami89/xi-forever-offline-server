-----------------------------------
-- Squad mate dialogue
--
-- Everything your squad mates say lives in this file, so edit it freely. Save it, restart the servers, done.
--
-- Each mate has a "voice" (bold, calm, cheerful or gruff). A mate's voice is picked from their name, so it never
-- changes. To choose one yourself, add the name to voiceByName below, for example:  Kurami = 'gruff'
--
-- In a line you can use:  {name} (the squad mate)   {master} (you)   {item} (a piece of gear)   {level} (a new level)
-- Each mate's own lines (when called, level up, knocked out, weaponskill) are edited in the launcher's Squad tab;
-- it writes squad_greetings_data.lua, which is loaded below. The voice lines are the fallback for everyone else.
-----------------------------------
local dialogue = {}

-- Turn kinds of speech on or off
dialogue.speakOnSpawn   = true  -- when they join you
dialogue.speakOnDespawn = false -- when they leave (this also happens every time you zone, so it is off by default)
dialogue.speakOnDeath   = true
dialogue.speakOnLevelUp = true
dialogue.wsShoutChance  = 20    -- percent chance to call out a weaponskill. 0 = never

dialogue.voiceOrder  = { 'bold', 'calm', 'cheerful', 'gruff' }
dialogue.voiceByName = {}

dialogue.voices =
{
    bold =
    {
        eat         = { 'A {food} before the fight. Now I am ready.', 'Eating a {food}. Strength for the next one!', 'Mmm, {food}. Let us go.' },
        spawn       = { 'Ready when you are, {master}.', 'Point me at something dangerous.', 'Lead on. I have your back.', 'Let us show them what we are made of.' },
        despawn     = { 'Call me when the next fight comes.', 'Until next time.' },
        death       = { 'No... not like this...', 'Tell them... I did not run...', 'I will be back on my feet soon...' },
        levelup     = { 'Level {level}! Now we are getting somewhere.', 'Stronger already. Level {level}!', 'Level {level}. Bring on the next one.' },
        weaponskill = { 'Take this!', 'Here I come!', 'Feel that!', 'Hold still!' },
        thanks      = { 'A fine {item}! You will not regret this.', 'The {item} will serve us well.', 'We will put this {item} to good use.' },
        alreadyhave = { 'We already have the {item}. Keep it, {master}.', 'Our collection has the {item} already.' },
        cannotuse   = { 'That is of no use to us.', 'I cannot make use of that.' },
        closer      = { 'Step closer, {master}.', 'Come over here first.' },
        failed      = { 'Something went wrong. I could not take that.' },
    },
    calm =
    {
        eat         = { 'I will have a {food} first.', 'A {food}, to keep my strength up.', 'Just a moment... {food}. There.' },
        spawn       = { 'I am here, {master}.', 'Whenever you are ready.', 'Steady now. We will manage.', 'Let us proceed carefully.' },
        despawn     = { 'Take care, {master}.', 'I will be waiting.' },
        death       = { 'I am sorry... I could not hold...', 'Forgive me, {master}...', 'Please... carry on...' },
        levelup     = { 'Level {level}. A little wiser today.', 'I feel steadier now. Level {level}.', 'Level {level}, thanks to you.' },
        weaponskill = { 'Now.', 'Here.', 'Stay focused.', 'Watch closely.' },
        thanks      = { 'That is very kind. The {item} is ours now.', 'Thank you, {master}. We will take good care of the {item}.', 'A thoughtful gift. Thank you for the {item}.' },
        alreadyhave = { 'We already have the {item}, but thank you.', 'The {item} is in our keeping already.' },
        cannotuse   = { 'I am afraid that is not something I can use.', 'Thank you, but that would not help us.' },
        closer      = { 'Could you come a little closer?', 'Please step nearer, {master}.' },
        failed      = { 'I am sorry, I could not accept that just now.' },
    },
    cheerful =
    {
        eat         = { 'Snack time! {food}!', 'Mmm, {food}! Yum!', 'Ooh, {food}. Best part of the day!' },
        spawn       = { 'Hi, {master}! Ready for an adventure?', 'Here I am! Where to?', 'Yay, we are going out!', 'Let us go have some fun!' },
        despawn     = { 'See you soon!', 'Bye for now, {master}!' },
        death       = { 'Ow... that did not go as planned...', 'Oh no... I tripped...', 'Little help... please...' },
        levelup     = { 'Level {level}! I did it!', 'Look at me, level {level}!', 'Level {level}! That was fun!' },
        weaponskill = { 'Hiya!', 'Here we go!', 'Watch this!', 'Whee!' },
        thanks      = { 'Wow, a {item}! Thank you so much!', 'For us? The {item} is wonderful!', 'Thank you, {master}! We love the {item}!' },
        alreadyhave = { 'We already have the {item}, silly!', 'Thanks, but the {item} is already in our collection!' },
        cannotuse   = { 'Hmm, I do not think we can use that.', 'Aww, that is not for us.' },
        closer      = { 'Come a bit closer, I cannot reach!', 'Over here, {master}!' },
        failed      = { 'Oops! I could not take that.' },
    },
    gruff =
    {
        eat         = { '{food}. Good enough.', 'Hold on. Eating. {food}.', 'Nothing like a {food} before a brawl.' },
        spawn       = { 'Let us get on with it.', 'Hmph. Where to?', 'Do not slow down on my account.', 'Fine. I am here.' },
        despawn     = { 'Hmph.', 'Fine. Be quick about it.' },
        death       = { 'Damn... not yet...', 'Hmph... lucky blow...', 'Get me... up...' },
        levelup     = { 'Level {level}. About time.', 'Level {level}. Not bad.', 'Level {level}. Do not get used to it.' },
        weaponskill = { 'Hah!', 'Out of my way!', 'Take that!', 'Grr!' },
        thanks      = { 'Hmph. A decent {item}. Thanks.', 'Better than nothing. The {item} will do.', 'The {item}, eh? Fine. We will use it.' },
        alreadyhave = { 'We have the {item} already. Keep it.', 'Already got the {item}.' },
        cannotuse   = { 'No use to us.', 'Do not waste my time with that.' },
        closer      = { 'Come here, I am not walking over.', 'Closer.' },
        failed      = { 'Hmph. Could not take it.' },
    },
}

-- Per-mate lines written by the launcher's Squad tab (Greetings), in squad-data/squad_greetings_default.json and
-- squad_greetings_user.json. If the file is absent, each mate falls back to their voice pool above.
local customLoaded, custom = pcall(require, 'modules/custom/lua/squad_greetings_data')
if customLoaded and type(custom) == 'table' then
    dialogue.linesByName = custom
end

-- Remembers the last few lines of each kind of speech, so a mate called twice in a row - or two mates who happen
-- to share a voice - never repeat a line. Old entries fall out after eight lines of that kind.
local recentLines = {}

function dialogue.pickLine(name, event, voiceName)
    local lines = dialogue.linesByName and dialogue.linesByName[name] and dialogue.linesByName[name][event]
    if lines == nil or #lines == 0 then
        local voice = dialogue.voices[voiceName or '']
        lines = voice and voice[event] or nil
    end

    if lines == nil or #lines == 0 then
        return nil
    end

    local recent = recentLines[event]
    if recent == nil then
        recent = {}
        recentLines[event] = recent
    end

    local fresh = {}
    for _, line in ipairs(lines) do
        local used = false
        for _, old in ipairs(recent) do
            if old == line then
                used = true
                break
            end
        end
        if not used then
            fresh[#fresh + 1] = line
        end
    end

    if #fresh == 0 then
        -- Every line in this pool is still warm; forget just this pool rather than say nothing. Lines used by
        -- other mates stay in the window, so two mates who share a voice still cannot echo each other.
        local keep = {}
        for _, old in ipairs(recent) do
            local mine = false
            for _, line in ipairs(lines) do
                if line == old then
                    mine = true
                    break
                end
            end
            if not mine then
                keep[#keep + 1] = old
            end
        end
        recent = keep
        recentLines[event] = recent
        fresh = lines
    end

    local text = fresh[math.random(#fresh)]
    recent[#recent + 1] = text
    if #recent > 8 then
        table.remove(recent, 1)
    end

    return text
end

return dialogue
