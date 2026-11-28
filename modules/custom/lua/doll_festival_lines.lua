-----------------------------------
-- Doll Festival: what people say (XI: Forever Offline)
-----------------------------------
-- Written for this server (no retail captures of the moogles' event text could be checked against this client).
-- {name} = the adventurer, {city} = the town, {cake} = a rice cake's name, {mate} = a squad mate.
-----------------------------------
return
{
    -- the festival moogles
    moogle =
    {
        intro =
        {
            'Master, have you ever heard of the Doll Festival, kupo?',
            'It is a Far Eastern celebration where everyone prays for the health and happiness of young girls, kupo.',
            'The girls eat rice treats and set out dolls dressed like nobles: an emperor and empress on top, three ladies-in-waiting, and five musicians at the bottom!',
            'The Culinarians\' Guild and the Rhinostery made these rice cakes with a little moogle magic, kupo. Green, white and pink, for grass, snow and peach blossoms.',
            'One bite and you will feel like a little girl again... in mind AND body, kupo! Even the gentlemen. That part was an accident. Mostly.',
            'Come and see me once a day, kupo. And if you bring a party of ten, I have something extra!',
        },
        hello    = { 'Happy Doll Festival, kupo!', 'The blossoms are lovely this year, kupo!', 'Kupo! Here for a rice cake?' },
        given    = { 'Here you are, kupo! A {cake}, fresh from the guild!', 'One {cake} for you, kupo! Eat it somewhere pretty.' },
        party    = { 'A party of ten, kupo! That is a proper festival. Take an extra one!' },
        stage    = { 'Six gentlemen and four ladies... just like the doll stage, kupo! The emperor, the empress, the ladies-in-waiting and the musicians! One rice cake of every kind for you!' },
        already  = { 'You already had your rice cake today, kupo. Come back tomorrow!', 'Kupo! No second helpings until tomorrow. The guild only makes so many.' },
        newbie   = { 'You only just arrived in Vana\'diel, kupo! Settle in for a day, then come back for your rice cake.' },
        full     = { 'Your bags are stuffed, kupo! Make a little room and come back.' },
        tenHint  = { 'Bring nine friends here with you, kupo, and I will have something extra. Six gentlemen and four ladies would make the moogles very happy...' },
    },

    -- town chatter during the festival (crowds and bot players in the nation cities)
    say =
    {
        'the cherry trees are out, so pretty',
        'did you get your rice cake from the moogle yet?',
        'happy doll festival!',
        'anyone else turned into a little girl? lol',
        'ate a tarutaru rice cake by mistake, now everyone is taller than me... wait',
        'the moogle said bring ten people for extra cakes',
        'my LS is doing a doll stage screenshot later',
        'need 4 ladies and 6 guys for the doll stage, anyone?',
        'free rice cakes, gotta love the moogles',
        'these screens and parasols make the whole town look different',
        'saving my rice cakes for the screenshot',
        'peach blossom pink is the best one',
        'went from galka to tiny hume girl. my linkshell will never let me forget it',
        'the mithran rice cake ears are so cute',
        'one rice cake a day, the moogle is strict',
        'my party all ate elvaan cakes, we look like a school trip',
        'festival is only a couple weeks, enjoy it',
        'picnic under the cherry tree after this?',
    },
    pairs =
    {
        { 'got a rice cake yet?', 'ya, the moogle by the gate' },
        { 'why are you so small?', 'rice cake. dont ask' },
        { 'doll stage photo later?', 'sure, I can be a musician' },
        { 'which cake did you get?', 'mithran, kinda cute tbh' },
        { 'need one more lady for 10', 'my alt can come' },
        { 'are the cakes tradeable?', 'ya, I traded my hume one for elvaan' },
        { 'happy doll festival!', 'happy festival o/' },
        { 'the trees are so pink', 'best part of the year' },
    },

    -- a squad mate in a decorated town (said when the squad chat AI is not answering)
    mate =
    {
        'The whole of {city} is in bloom! Is it the Doll Festival already?',
        'Look at the blossoms, {name}. Let\'s get a rice cake from the moogle before we go.',
        'Screens, parasols, cherry trees... {city} goes all out for the Doll Festival.',
        'I ate a rice cake last year and turned into a little girl for an hour. Best hour of my life.',
        'If we find six gentlemen and four ladies, the moogle gives a cake of every kind. Just saying.',
        'Peach blossoms and rice cakes. I could get used to this.',
    },

    -- the system notice, once a day in the festival towns
    notice = 'The Doll Festival is here! Festival moogles in Southern and Northern San d\'Oria, Bastok Mines and Markets, and Windurst Waters and Woods hand out rice cakes once a Vana\'diel day. A party of ten gets more.',

    -- the 2007 present in the delivery box
    boxNote = 'The Mog House Management Union sent you {count} {cake}s for the Doll Festival. They are in your delivery box.',
    furnNote = 'The moogles also sent a set of Festival Dolls and a Bonbori lantern for your Mog House. They are in your delivery box.',
}
