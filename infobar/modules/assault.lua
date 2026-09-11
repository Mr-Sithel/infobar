local assaults = {
    -- LEUJAOAM SANCTUM (Azouph Isle Staging Point)
    { zone = "Leujaoam Sanctum", name = "Leujaoam Cleansing",           rank = "Private Second Class", time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Orichalcum Survey",            rank = "Private First Class",  time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Escort Professor Chanoix",     rank = "Superior Private",     time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Shanarha Grass Conservation",  rank = "Lance Corporal",       time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Counting Sheep",               rank = "Corporal",             time_limit = 15 },
    { zone = "Leujaoam Sanctum", name = "Supplies Recovery",            rank = "Sergeant",             time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Azure Experiments",            rank = "Sergeant Major",       time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Imperial Code",                rank = "Chief Sergeant",       time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Red Versus Blue",              rank = "Second Lieutenant",    time_limit = 30 },
    { zone = "Leujaoam Sanctum", name = "Bloody Rondo",                 rank = "First Lieutenant",     time_limit = 30 },

    -- MAMOOL JA TRAINING GROUNDS (Mamool Ja Staging Point)
    { zone = "Mamool Ja Training Grounds", name = "Imperial Agent Rescue",       rank = "Private Second Class", time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "Preemptive Strike",           rank = "Private First Class",  time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "Sagelord Elimination",        rank = "Superior Private",     time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "Breaking Morale",             rank = "Lance Corporal",       time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "The Double Agent",            rank = "Corporal",             time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "Imperial Treasure Retrieval", rank = "Sergeant",             time_limit = 15 },
    { zone = "Mamool Ja Training Grounds", name = "Blitzkrieg",                  rank = "Sergeant Major",       time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "Marids in the Mist",          rank = "Chief Sergeant",       time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "Azure Ailments",              rank = "Second Lieutenant",    time_limit = 30 },
    { zone = "Mamool Ja Training Grounds", name = "The Susanoo Shuffle",         rank = "First Lieutenant",     time_limit = 30 },

    -- LEBROS CAVERN (Halvung Staging Point)
    { zone = "Lebros Cavern", name = "Excavation Duty",               rank = "Private Second Class", time_limit = 30 },
    { zone = "Lebros Cavern", name = "Lebros Supplies",               rank = "Private First Class",  time_limit = 30 },
    { zone = "Lebros Cavern", name = "Troll Fugitives",               rank = "Superior Private",     time_limit = 30 },
    { zone = "Lebros Cavern", name = "Evade and Escape",              rank = "Lance Corporal",       time_limit = 30 },
    { zone = "Lebros Cavern", name = "Siegemaster Assassination",     rank = "Corporal",             time_limit = 30 },
    { zone = "Lebros Cavern", name = "Apkallu Breeding",              rank = "Sergeant",             time_limit = 15 },
    { zone = "Lebros Cavern", name = "Wamoura Farm Raid",             rank = "Sergeant Major",       time_limit = 30 },
    { zone = "Lebros Cavern", name = "Egg Conservation",              rank = "Chief Sergeant",       time_limit = 30 },
    { zone = "Lebros Cavern", name = "Operation: Black Pearl",        rank = "Second Lieutenant",    time_limit = 30 },
    { zone = "Lebros Cavern", name = "Better Than One",               rank = "First Lieutenant",     time_limit = 30 },

    -- PERIQIA (Dvucca Isle Staging Point)
    { zone = "Periqia", name = "Seagull Grounded",         rank = "Private Second Class", time_limit = 30 },
    { zone = "Periqia", name = "Requiem",                  rank = "Private First Class",  time_limit = 30 },
    { zone = "Periqia", name = "Saving Private Ryaaf",     rank = "Superior Private",     time_limit = 30 },
    { zone = "Periqia", name = "Shooting Down the Baron",  rank = "Lance Corporal",       time_limit = 15 },
    { zone = "Periqia", name = "Building Bridges",         rank = "Corporal",             time_limit = 15 },
    { zone = "Periqia", name = "Stop the Bloodshed",       rank = "Sergeant",             time_limit = 30 },
    { zone = "Periqia", name = "Defuse the Threat",        rank = "Sergeant Major",       time_limit = 30 },
    { zone = "Periqia", name = "Operation: Snake Eyes",    rank = "Chief Sergeant",       time_limit = 30 },
    { zone = "Periqia", name = "Wake the Puppet",          rank = "Second Lieutenant",    time_limit = 30 },
    { zone = "Periqia", name = "The Price is Right",       rank = "First Lieutenant",     time_limit = 30 },

    -- ILRUSI ATOLL (Ilrusi Atoll Staging Point)
    { zone = "Ilrusi Atoll", name = "Golden Salvage",                  rank = "Private Second Class", time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Lamia No.13",                     rank = "Private First Class",  time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Extermination",                   rank = "Superior Private",     time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Demolition Duty",                 rank = "Lance Corporal",       time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Searat Salvation",                rank = "Corporal",             time_limit = 15 },
    { zone = "Ilrusi Atoll", name = "Apkallu Seizure",                 rank = "Sergeant",             time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Lost and Found",                  rank = "Sergeant Major",       time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Deserter",                        rank = "Chief Sergeant",       time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Desperately Seeking Cephalopods", rank = "Second Lieutenant",    time_limit = 30 },
    { zone = "Ilrusi Atoll", name = "Bellerophon's Bliss",             rank = "First Lieutenant",     time_limit = 30 },

    -- NYZUL ISLE
    { zone = "Nyzul Isle", name = "Nyzul Isle Investigation",      rank = "N/A", time_limit = 30 },

    -- SALVAGE
    { zone = "Arrapago Remnants",   name = "Salvage", trigger = "Arrapago Remnants",   portal = "Northwest Portal", time_limit = 100 },
    { zone = "Bhaflau Remnants",    name = "Salvage", trigger = "Bhaflau Remnants",    portal = "Southeast Portal", time_limit = 100 },
    { zone = "Silver Sea Remnants", name = "Salvage", trigger = "Silver Sea Remnants", portal = "Northeast Portal", time_limit = 100 },
    { zone = "Zhayolm Remnants",    name = "Salvage", trigger = "Zhayolm Remnants",    portal = "Southwest Portal", time_limit = 100 },
    }

return assaults