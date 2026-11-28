-----------------------------------
-- XI: Forever Offline: what squad mates and bot players say while you court them (2026-11-27, written for the
-- players who play without the AI chat; with it, these are the AI's examples of the feel). Used by wedding_romance.lua.
-- Every line is gender-neutral and kept sweet: flirting, blushing, dates and vows, never more than FFXI shows.
-- {name} = you, {spot} = the date spot, {item} = the gift. Plain ASCII only (the game's chat).
-----------------------------------
return {
    -- !date > Chat, and now and then by themselves. [stage] = { common, quick, slow, never }
    chat =
    {
        [0] = -- acquaintance
        {
            common =
            {
                "Hello there.",
                "Oh, it's you. Good to see you.",
                "Nice weather for an adventure, isn't it?",
                "I don't think we've really talked before. I'm glad we are now.",
                "You fight well. I noticed.",
                "Where are you headed today?",
                "Careful out there. The monsters don't care how nice you are.",
                "Is there something you need?",
            },
            quick = { "I have a feeling we're going to get along, {name}.", "You have a nice way about you, you know that?",
                      "Stick around, I like the company.", "Hey! I was hoping I'd see you." },
            slow = { "...Hello.", "Mm. Good day.", "I don't usually talk much. Don't take it personally.",
                     "I'm still getting used to having company." },
            never = { "Hey, {name}. Ready when you are.", "Good to have you along.", "Let's get to work.",
                      "Another day, another hunt." },
        },
        [1] = -- friend
        {
            common =
            {
                "Hey, partner! Ready for another day out there?",
                "You always know where the good camps are.",
                "I had fun last time. Let's do it again.",
                "Did you see that last fight? We make a good team.",
                "I bought too many Distilled Waters again. Don't tell anyone.",
                "If you ever need someone to watch your back, you know where I am.",
                "You're easy to talk to, {name}.",
                "I told a moogle about you. It said 'kupo'. I think that's a good sign.",
            },
            quick = { "I look forward to our hunts more than I should.", "You make the long roads feel short.",
                      "Is it just me, or do we always end up laughing?", "I saved you a seat by the fire. Just in case." },
            slow = { "It's... nice, having a friend out here.", "I don't say it often, but thanks for bringing me along.",
                     "You're all right, {name}. More than all right.", "I've started to trust you. That's rare for me." },
            never = { "You're a good friend, {name}. The best kind.", "Friends like you are hard to find in Vana'diel.",
                      "Whatever comes, I've got your back. Always.", "Let's grab a bite after this. Friends' treat." },
        },
        [2] = -- close
        {
            common =
            {
                "I was hoping you'd come by.",
                "Is it strange that I look forward to our hunts?",
                "You've been on my mind lately. Just... in a good way.",
                "When you're around, the bad days don't feel so bad.",
                "I could listen to you talk about anything.",
                "You have a nice laugh. I don't think I've told you that.",
                "I kept a lookout for you the whole way here.",
                "Sometimes I wonder what you think about, on the long walks.",
            },
            quick = { "Do you ever feel like this is more than just adventuring?", "I keep finding reasons to stand next to you.",
                      "If you asked me somewhere, I think I'd say yes. Just so you know.", "My heart does a silly thing when you wave at me." },
            slow = { "I don't let many people this close. You're one of them.", "I feel... calm, with you. I'm not used to that.",
                     "Give me time, {name}. I'm worth it, I think.", "I wrote your name in my journal today. Only once. Twice, maybe." },
            never = { "You're like family to me now, {name}.", "I'd follow you anywhere. As your best friend.",
                      "Whoever ends up with you will be very lucky. I mean that.", "Let's always be like this. Friends, through everything." },
        },
        [3] = -- dating
        {
            common =
            {
                "I missed you. Is that silly?",
                "Every adventure is better with you.",
                "Hold still... there. You had a leaf in your hair.",
                "Walk with me a little slower today?",
                "I keep smiling for no reason. Well, for one reason.",
                "Where should we go on our next date?",
                "I told the moogle we're together. It was very happy about it. Kupo.",
                "Be careful in this next fight. I want you around for a long time.",
                "You look good today. You look good every day, actually.",
                "Is it my turn to pick the next date spot?",
            },
            quick = { "I think about you all the time. All. The. Time.", "Don't let go of my hand on the way back, all right?",
                      "Every day with you feels like the start of something.", "I'm the luckiest adventurer in Vana'diel." },
            slow = { "I'm not good with words. But I'm glad it's you.", "This is new for me. I like it. I like you.",
                     "Thank you for being patient with me.", "I feel safe with you. That means everything." },
            never = { "We're still friends, right? Good.", "Thanks for being such a good friend, {name}.",
                      "I'm happy we're close. Truly.", "You and me, the best of friends." },
        },
        [4] = -- engaged
        {
            common =
            {
                "I keep looking at this ring and smiling.",
                "Our wedding... I still can't believe it.",
                "Have you thought about which palace?",
                "Chateau d'Oraguille, the Metalworks or Heavens Tower... where do you see us?",
                "I practiced my vows. Don't laugh!",
                "Do you think the Wedding Master will cry? I might.",
                "I told everyone I know. Even the gobbies.",
                "Soon it will be 'us' for good.",
            },
            quick = { "Can we have fireworks? Lots of fireworks?", "I'd marry you today if you asked. Right now.",
                      "I'm counting the days. All of them.", "My heart's already said yes a hundred times." },
            slow = { "I never thought I'd be wearing a ring like this.", "I'm nervous. The good kind of nervous.",
                     "I'm ready. I didn't know I would be, but I am.", "Thank you for choosing me, {name}." },
            never = { "Still friends, always.", "You'll find the right one, {name}.", "I'll dance at your wedding, I promise.",
                      "Friends forever. That's a promise too." },
        },
        [5] = -- married
        {
            common =
            {
                "There you are, my dear.",
                "Home is wherever you are.",
                "Every day with you is my favorite day.",
                "Shall we go somewhere nice later? Just the two of us?",
                "I still keep our certificate on the wall at home.",
                "Married life suits us, don't you think?",
                "I'll always watch your back. That was the deal, wasn't it?",
                "Sometimes I still can't believe you're mine.",
                "Let's grow old together. Adventurers can do that, right?",
                "You, me, and the open road. That's all I need.",
            },
            quick = { "I love you. That's it, that's the whole message.", "Married or not, you still make my heart race.",
                      "Kiss for luck before the next fight? Fine, a wave will do.", "Best decision I ever made." },
            slow = { "I'm happy. Truly happy. I wanted you to know.", "I didn't know life could feel this steady.",
                     "Thank you for every day, {name}.", "My quiet heart is very loud about you." },
            never = { "Partner for life.", "Always by your side.", "Together, always.", "Here for you, always." },
        },
    },

    -- asking them out
    askYes =
    {
        quick = { "Yes! I was hoping you would ask!", "Finally! I thought you'd never ask!", "Yes, yes, a hundred times yes!",
                  "I was going to ask you if you didn't ask me first!", "Yes! Where are you taking me first?" },
        most = { "I... yes. I'd really like that.", "Yes. I think I've wanted this for a while.", "You mean it? Then yes.",
                 "I'd love to, {name}.", "Yes. Let's see where this goes, together." },
        slow = { "...Yes. Yes, I think I'm ready.", "I've been hoping, quietly. Yes.", "It took me a while to know. But I do. Yes.",
                 "Yes. Be gentle with my heart, all right?", "I'd like that. Very much." },
    },
    notYet =
    {
        quick = { "Oh! Ask me again soon. Very soon.", "Not yet, but... don't stop trying, okay?", "Almost! Spend a little more time with me first?",
                  "My heart's halfway there already.", "Soon, {name}. Really soon." },
        most = { "Oh! I... I don't know you well enough yet. Ask me again someday?", "That's sweet of you. Let's get to know each other a little more first.",
                 "Maybe... not yet. But don't give up on me.", "I'm flattered! Give it a little time?", "Let's have a few more adventures first." },
        slow = { "I need more time. I'm sorry.", "I'm not ready yet. But I'm not saying never.", "Slowly, {name}. Please.",
                 "I like being around you. Let's leave it at that, for now.", "Ask me again when we've been through more together." },
    },
    never =
    {
        "You mean a lot to me, truly... but as a friend. I hope that's all right.",
        "I'm flattered, I really am. But my heart doesn't work that way. Friends?",
        "You're one of my dearest friends. Let's keep it that way, please.",
        "I care about you so much, {name}. Just not like that. I'm sorry.",
        "If I could choose, it would be you. But I can't. Friends forever?",
        "I'm not the one for you. But I'll always be your friend.",
        "Please don't be sad. You'll always have me in your corner.",
        "I think you deserve someone who feels it back. I'm your friend, always.",
        "My heart belongs to the road, I think. But you have a friend for life.",
        "Thank you for asking. It means a lot. But we're better as friends.",
    },

    -- proposing
    proposeYes =
    {
        "Yes! Yes, a thousand times yes!",
        "I'll wear it always. Yes!",
        "...I'm crying. Of course I will marry you!",
        "Is this real? Yes! Yes!",
        "I was hoping you'd ask. Yes, {name}. Yes.",
        "It's beautiful. You're beautiful. Yes!",
        "I don't need to think about it. Yes.",
        "Every road led here. Yes, with all my heart.",
        "Yes! Let's tell the whole of Vana'diel!",
        "I'll marry you on any day, in any palace. Yes!",
        "My answer was always going to be yes.",
        "Yes... I'll never take it off.",
    },
    proposeSoon =
    {
        "It's beautiful... but it's too soon. Keep it for me, and ask me again?",
        "My heart says yes, but let's have a few more days like the good ones first.",
        "Not yet, {name}. Take me somewhere special a few more times?",
        "I want to be sure. Ask me again after a few more dates?",
        "Oh! I... it's too soon. Please don't be hurt.",
        "Hold on to it for me. I want to say yes when I'm ready.",
        "I want this, I really do. Just not quite yet.",
        "Give me a little more time to fall all the way.",
        "That's the sweetest thing... but we've only just started.",
        "Ask me again under the stars sometime. Not yet.",
    },
    -- the ceremony: their own vow
    vows =
    {
        "I do. Today, tomorrow, and every day after.",
        "I do. With all my heart.",
        "I do. I always will.",
        "I do. Wherever the road takes us.",
        "I do... I really, really do.",
        "I do. Through every storm and every sunrise.",
        "I do. You're my home.",
        "I do. Forever, by the light of the Crystals.",
        "I do. I'll never leave your side.",
        "I do. I was always going to.",
    },
    afterWedding =
    {
        "We're married! I can't stop smiling!",
        "Partner for life. I like how that sounds.",
        "That was the best day of my life.",
        "Did you see everyone cheering? For us!",
        "Let's go home. Our home.",
        "I'll treasure this day forever.",
    },

    -- gifts: [taste][kind] (plain has no kinds)
    gift =
    {
        loved =
        {
            flowers = { "Flowers! For me? They're lovely. You're lovely.", "Oh, {item}! I'll keep them by my bed.",
                        "How did you know I love flowers? Thank you!", "They smell like spring. Thank you, {name}.",
                        "I'll press one in my journal so I never forget today." },
            gems = { "It sparkles! Oh, {name}, I love it!", "A gemstone? You really shouldn't have. I'm so glad you did.",
                     "I'll have it set in something special. Thank you!", "It's beautiful... like the way you smile.",
                     "{item}! I've always loved these." },
            crystals = { "A crystal! Do you know how much I love these?", "It hums when I hold it. Thank you!",
                         "I'll keep it close. It feels like a little piece of you.", "The light inside is so pretty. Thank you, {name}.",
                         "Crystals always make me think of home. Now they'll make me think of you." },
            cloth = { "This cloth is so soft! I'll make something beautiful with it.", "{item}? Oh, I love fine cloth. Thank you!",
                      "I could make us matching scarves. Would you wear one?", "It's lovely. You have such good taste.",
                      "I'll treasure it. Thank you, {name}." },
            feathers = { "A feather! I collect these, you know.", "It's so light... like I feel around you.",
                         "I'll wear it in my hair. Thank you!", "How pretty! Thank you, {name}.",
                         "{item}! You remembered." },
            sweets = { "Sweets! You know the way to my heart.", "Mmm! You remembered I have a sweet tooth.",
                       "I'll share it with you. Just a little. Maybe.", "This is my favorite! Thank you!",
                       "You spoil me, {name}. Don't stop." },
        },
        disliked =
        {
            flowers = { "Flowers... they make me sneeze. But thank you.", "Oh. Flowers. Thank you, I suppose.",
                        "That's... sweet. I'm just not a flower person.", "Hm. They'll wilt by tomorrow, you know." },
            gems = { "A rock? Er... a shiny rock. Thank you?", "Gems aren't really my thing. But it's the thought that counts.",
                     "Oh. That's... valuable, I'm sure.", "I'll... find a place for it." },
            crystals = { "A crystal? I have plenty, but thanks.", "Oh. For synthesis, I guess?",
                         "That's... practical. Thank you.", "Hm. I'm not really one for crystals." },
            cloth = { "Cloth? I don't sew, but... thank you.", "That's a lot of fabric. What do I do with it?",
                      "Oh. Er. It's very... cloth-like.", "Thanks. I'll find someone who sews." },
            feathers = { "A feather? Atchoo! Sorry. Thank you.", "Oh. A feather. From a bird. Thank you.",
                         "That's... ticklish. Thanks, I guess.", "Hm. I'm not one for feathers." },
            sweets = { "Sweets? I'm trying to cut back... thank you, though.", "Oh. Too sweet for me, but thanks.",
                       "I'll give this to someone who likes sugar.", "That's... very sugary. Thank you." },
        },
        plain =
        {
            "Thank you, that's kind of you.",
            "Oh, a present? Thanks!",
            "I'll keep it safe.",
            "For me? You didn't have to. Thank you.",
            "That's thoughtful of you, {name}.",
            "A gift! You're sweet.",
            "Thank you. I'll find a good use for it.",
            "You always think of me. Thank you.",
            "Oh! Thanks, {name}.",
            "How nice of you. Thank you.",
            "I'll put it somewhere special.",
            "Thank you! That made my day a little brighter.",
        },
        enough =
        {
            "You're spoiling me! Save some for another day.",
            "No more today, really! You've given me plenty.",
            "Any more and I'll need a bigger bag!",
            "That's enough for one day, you sweetheart.",
            "Keep it for tomorrow. I'll still be here.",
            "I can't carry another thing! Thank you, though.",
        },
    },

    -- date spots: any time, and Vana'diel night (20:00-5:59) or day versions
    spots =
    {
        SELBINA = { any = { "The sea breeze, the gulls... and you. I could stay here all day.", "Listen to the waves. I feel like we're the only ones here.",
                            "Let's sit on the pier and watch the boats." },
                    night = { "The lighthouse looks so romantic at night.", "The stars over the water... I'll remember this." },
                    day = { "The sun on the harbor is so bright today!", "Let's get some fish from the market and eat on the dock." } },
        MHAURA = { any = { "Look at the ships coming in. Where would you sail, if we could go anywhere?", "Mhaura is so quiet. I like quiet, with you.",
                           "The sea smells like adventure. And a little like fish." },
                   night = { "The lanterns along the harbor... it's beautiful.", "Let's wait here for the night ferry, just to watch it go." },
                   day = { "Let's watch the ferry come in.", "The sunlight on the water is dazzling." } },
        LOWER_JEUNO = { any = { "The lanterns are lovely. Thank you for bringing me.", "Jeuno always feels alive. Like my heart right now.",
                                "Let's get something warm at the tavern." },
                        night = { "The city lights at night are something else.", "Even this late, Jeuno hums. Walk me home?" },
                        day = { "So many people! Hold my hand so I don't lose you.", "Let's look at the shops. Just looking. Probably." } },
        UPPER_JEUNO = { any = { "Shall we walk by the cathedral? I like how quiet it is up here.", "The clock tower... let's make time stop, just for a bit.",
                                "Up here, the whole city feels far away." },
                        night = { "The cathedral glows at night. It's beautiful.", "Let's sit on the steps and talk until morning." },
                        day = { "The light through the cathedral windows is so pretty.", "Let's walk the terraces. Slowly." } },
        PORT_JEUNO = { any = { "Every airship leaving makes me want to take one with you.", "Someday let's fly somewhere far, just us.",
                               "I love watching the airships. They look so free." },
                       night = { "The airships' lights in the dark... like moving stars.", "Night flights look so romantic." },
                       day = { "Look, an airship to Bastok! Shall we wave?", "The docks are so busy today. I don't mind, I'm with you." } },
        RULUDE_GARDENS = { any = { "All these flowers... none of them as nice as today.", "The Archduke's gardens. Fancy! I feel like royalty.",
                                   "It's so calm here. Let's stay a while." },
                           night = { "The palace under the moon... it's like a fairy tale.", "So quiet at night. Just us and the fountains." },
                           day = { "The flowers are all open today!", "Look at the gardens. Everything is in bloom." } },
        WINDURST_WALLS = { any = { "The stars look so close from here. Make a wish with me?", "The Star Tree watches over us. I like that.",
                                   "Windurst always feels like magic." },
                           night = { "Look up. Every star is out tonight.", "The Walls at night... I could cry, it's so pretty." },
                           day = { "The breeze through the Walls is so fresh.", "Let's visit the Heavens Tower later. Or just stay here." } },
        WINDURST_WOODS = { any = { "Everything smells of rain and flowers here. I love it.", "The Woods feel like a storybook.",
                                   "Let's get a Tarutaru treat and wander." },
                           night = { "The fireflies are out! Look!", "The trees whisper at night. Do you hear it?" },
                           day = { "The sun through the leaves is so soft.", "Look at all the little shops in the trees!" } },
        NORTHERN_SAN_DORIA = { any = { "The fountain, the old stones... it feels like a story, being here with you.", "San d'Oria is so grand. And so are you.",
                                       "Let's throw a coin in the fountain. I know what I'll wish for." },
                               night = { "The castle under the stars... how romantic.", "The streets are quiet. It's just us and the knights." },
                               day = { "The banners look so bright today.", "Let's see the cathedral. It's beautiful in the daylight." } },
        BASTOK_MARKETS = { any = { "Let's get something warm to eat and just watch the city go by.", "Bastok's busy, but you're all I see.",
                                   "The smell of the forges and fresh bread... that's Bastok." },
                           night = { "The furnace glow at night is kind of beautiful, isn't it?", "Bastok never sleeps. Neither will I, after a date like this." },
                           day = { "Let's look at the market stalls.", "So many people today! Stay close." } },
        KAZHAM = { any = { "Pineapples, sunshine and you. Is this a dream?", "Kazham feels like a holiday.",
                           "Let's sit by the water and do nothing at all." },
                   night = { "The jungle sounds at night are like music.", "The torches by the water... so pretty." },
                   day = { "It's so warm! Let's find some shade together.", "Look at the colors! Everything is so bright here." } },
        NORG = { any = { "A pirate hideout for a date? I think I like the way you think.", "Norg is a little dangerous. I like it, with you.",
                         "Shh. If anyone asks, we're smugglers." },
                 night = { "The cave glows at night. Spooky and lovely.", "Pirates sing at night here. Dance with me?" },
                 day = { "Even by day, it's mysterious here.", "Let's see what the merchants are hiding." } },
        RABAO = { any = { "Out here in the desert, it feels like we are the only two in the world.", "Rabao is rough, but there's something honest about it.",
                          "Let's share a drink from the oasis." },
                  night = { "The desert stars are the brightest anywhere.", "The sand is cool at night. Let's walk a bit." },
                  day = { "It's hot! Good thing I have you to complain to.", "The sun's so bright on the sand. Shade, quick!" } },
        AHT_URHGAN_WHITEGATE = { any = { "The smell of spice, the music... Aht Urhgan suits us, don't you think?", "Whitegate is so far from home. And yet it feels right, with you.",
                                         "Let's get some of those sweets from the market." },
                                 night = { "The city lights over the sea... like a dream.", "The palace glows at night. Let's walk there." },
                                 day = { "The colors here are incredible!", "Let's get lost in the markets for a while." } },
        BUBURIMU_PENINSULA = { any = { "The view from these cliffs... I'm glad it is you I'm seeing it with.", "The sea wind up here is wonderful.",
                                       "Let's sit on the cliffs and watch the waves." },
                               night = { "The ocean at night is so peaceful.", "I can hear the waves below. And your heartbeat. Is that weird?" },
                               day = { "Look how far the sea goes!", "The sunlight on the water from up here..." } },
        LA_THEINE_PLATEAU = { any = { "The waterfalls, the open sky... let's just sit for a while.", "La Theine feels so wide and open.",
                                      "Let's find a rainbow by the falls." },
                              night = { "The plateau under the stars... I could stay here forever.", "Listen. Just the waterfall and us." },
                              day = { "Look, a rainbow over the falls!", "It's such a beautiful day for this." } },
    },
    spotRepeat =
    {
        "We were just here! Let's find somewhere new, or come back another day.",
        "This again? I love it, but surprise me next time!",
        "We came here yesterday, silly. Somewhere new?",
        "Same place, same smile. But let's explore somewhere else too.",
        "I'll never tire of this place... but Vana'diel is big!",
        "Again? You're sweet. But take me somewhere new next.",
    },

    -- by themselves, now and then (dating and after)
    idle =
    {
        [3] = { "Just waving at you. Because I can.", "When's our next date?", "I like fighting next to you. A lot.",
                "You're doing great, by the way.", "I thought about you during that last fight. Is that bad?",
                "Let's go somewhere nice after this.", "Don't get hurt. I mean it.", "You look happy today. I like it.",
                "Hey. I'm glad it's you.", "I could get used to this." },
        [4] = { "I'm counting the days until the wedding.", "Have you thought about the music?",
                "I keep practicing my vows when you're not looking.", "Soon, {name}. Soon.",
                "I wonder what the Wedding Master will say.", "Our names on a certificate... it's going to be real.",
                "Let's not wait too long, all right?", "I've never been so happy." },
        [5] = { "Love you.", "Still the best decision I ever made.", "Let's go home after this one?",
                "You fight like a hero. My hero.", "I'm proud of you, you know.", "We make a good team, don't we?",
                "I'll cover you. Always.", "Partner for life. I keep saying it because I like it.",
                "Do you remember our wedding day? I do, every day.", "One more fight, then a quiet evening?",
                "I'll make dinner tonight. Don't make that face.", "Every road is better with you." },
    },
    -- married life
    married =
    {
        greet = { "There you are, my love.", "Good to have you back, dear.", "I missed you while you were away.",
                  "You're here! Now it's a good day.", "Welcome back. I kept your spot warm.", "Hello, my partner for life.",
                  "There's my favorite person.", "Back at last! Let's have an adventure.", "I was just thinking about you.",
                  "Ready when you are, love." },
        hurt = { "Hang on! I'm right here!", "Don't you dare fall on me!", "Careful, love!", "Stay with me! I've got you.",
                 "Back off, you brute! That's my partner!", "Breathe! We'll get through this.", "No, no, no... hold on!",
                 "Not today. I'm not losing you today.", "I'm coming!", "Stay behind me for a moment!" },
        levelup = { "Look at you! I'm so proud!", "Stronger every day. That's my partner.", "You did it! Let's celebrate later.",
                    "Another step on the road. Together.", "I knew you could do it!", "You're amazing. Have I told you that today?",
                    "Level up! Hug later, fight now.", "My hero just got stronger." },
    },
    -- back after a long time apart
    missed =
    {
        "It's been a while... I missed you.",
        "Where have you been? I was starting to worry.",
        "You're back! I thought you'd forgotten me.",
        "It's been so long. Don't stay away like that again, okay?",
        "I counted the days. Too many days.",
        "Welcome back. My heart's been waiting.",
    },
    notPlace =
    {
        "This isn't really a place for a date... Selbina, maybe? Or Jeuno?",
        "Here? Let's go somewhere nicer. Windurst Walls, maybe?",
        "A date here? Let's find somewhere with a view.",
    },
}
