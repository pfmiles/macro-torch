<font style="color:rgb(31, 35, 40);">SuperWoW features list as of 15/07/2026:</font>

+ <font style="color:rgb(31, 35, 40);">Healing appears on floating combat text. HealingText CVar to toggle Floating Healing Text.</font>
+ <font style="color:rgb(31, 35, 40);">New ChatBubbleCvars: ChatBubbleRange (10-200 yards), ChatBubblesRaid, ChatBubblesBattleground, ChatBubblesWhisper, ChatBubblesCreatures</font>
+ <font style="color:rgb(31, 35, 40);">Chat links of spells & crafting recipes now supported by client, can be grabbed directly from wowhead.</font>
+ <font style="color:rgb(31, 35, 40);">Fully absorbed damage is now correctly shown in combat log instead of saying "unit absorbs the attack".</font>
+ <font style="color:rgb(31, 35, 40);">Macros character limit increased from 255 to 510.</font>
+ <font style="color:rgb(31, 35, 40);">Your personal buff bar now shows all your buffs including ones that don't normally have an icon.</font>
+ <font style="color:rgb(31, 35, 40);">Added "UNIT_CASTEVENT" event that tracks units cast starts, finishes, interrupts, channels, and swings (differentiates mainhand & offhand) arg1: casterGUID. arg2: targetGUID. arg3: event type ("START", "CAST", "FAIL", "CHANNEL", "MAINHAND", "OFFHAND"). arg4: spell id. arg5: cast duration.</font>
+ <font style="color:rgb(31, 35, 40);">Added "RAW_COMBATLOG" event that signals the RAW version of all combat log events. arg1: original event name. arg2: event text with GUIDs</font>
+ <font style="color:rgb(31, 35, 40);">Added "CREATE_CHATBUBBLE" event. arg1 = chatbubble frame, arg2 = unit GUID.</font>
+ <font style="color:rgb(31, 35, 40);">Raw combat log events are logged into WoWRawCombatLog.txt concurrently with original WoWCombatLog.txt if logging is enabled.</font>
+ <font style="color:rgb(31, 35, 40);">Combat log now appends owner name to combat log messages that have a owned unit such as a pet or totem.</font>
+ <font style="color:rgb(31, 35, 40);">The default event SPELLCAST_START now triggers on ranged weapon abilities like Aimed Shot & Multishot.</font>
+ <font style="color:rgb(31, 35, 40);">Removed range limit on seeing friendly players equipped items. This is to allow addons such as AdvancedVanillaCombatLog to build profiles of raid members without requiring every individual raid member to download a helper addon and communicate the information to each other.</font>
+ <font style="color:rgb(31, 35, 40);">Targeting circle spells such as Blizzard or Flamestrike no longer show the "I can't cast this ability while moving error" to stop from entering their targeting circle mode.</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "BackgroundSound" to enable or disable background sound while tabbed out (default = "0", can be "0" or "1")</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "UncapSounds". set to "1" to remove the hardcoded soundchannels limit. If you want true uncapped sound experience you still have accompany this CVAR with setting "SoundSoftwareChannels" and "SoundMaxHardwareChannels" to a high number (either by lua function, config.wtf edit or using VanillaTweaks)</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "FoV" to set camera field of view (default = "1.57", can be any value from "0.1" to "3.14")</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "SelectionCircleStyle" to set a</font><font style="color:rgb(31, 35, 40);"> </font>[<font style="color:rgb(9, 105, 218);">different appearance</font>](https://github.com/balakethelock/SuperWoW/wiki/Changelog#14042024--110)<font style="color:rgb(31, 35, 40);"> </font><font style="color:rgb(31, 35, 40);">for the target circle.</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "LootSparkle" to toggle Sparkling effect on lootable treasure.</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "NameplateRange" (10-80 yards). This takes precedance over all client modifications for Nameplate range.</font>
+ <font style="color:rgb(31, 35, 40);">New CVar "NameplateMotion": 0 = Overlap. 1 = Default spread. 2 = Smart spread.</font>

<font style="color:rgb(31, 35, 40);">Function changes:</font>

+ <font style="color:rgb(31, 35, 40);">CastSpellByName function now can take unit as 2nd argument in addition to true/false OnSelf. It can also take "CLICK" to instantly cast reticle spells on mouseover location (bypassing targeting circle mode)</font>
+ <font style="color:rgb(31, 35, 40);">UnitExists now also returns GUID of unit</font>
+ <font style="color:rgb(31, 35, 40);">UnitDebuff and UnitBuff now additionally return the id of the aura</font>
+ <font style="color:rgb(31, 35, 40);">Using UnitMana("player") as a druid now always returns your current form power and caster form mana at the same time.</font>
+ <font style="color:rgb(31, 35, 40);">frame:GetName(1) can now be used on nameplate frames to return the GUID of the attached unit.</font>
+ <font style="color:rgb(31, 35, 40);">SetRaidTarget now accepts 3rd argument "local" flag to assign a mark to your own client. This allows using target markers while solo.</font>
+ <font style="color:rgb(31, 35, 40);">LootSlot(slotid) that was previously used only to confirm "are you sure you want to loot this item" now has the usage format LootSlot(slotid [, forceloot]). LootSlot(slotid, 1) can now be used to actually loot a slot.</font>
+ <font style="color:rgb(31, 35, 40);">GetContainerItemInfo now returns item's charges instead of stacks if the item is not stackable & has charges. Charges are given as a negative number.</font>
+ <font style="color:rgb(31, 35, 40);">GetWeaponEnchantInfo() now can accept a friendly player (ex: party1) as argument. If used in this way, it gives the name of the temporary enchant on that player's mainhand & offhand. Old functionality is preserved for own player's enchant duration & stacks.</font>
+ <font style="color:rgb(31, 35, 40);">Added GetWeaponEnchantID(unit). Returns mainhand and offhand temporary enchant ID.</font>
+ <font style="color:rgb(31, 35, 40);">Macros can now be treated by the game as an item or a spell action by starting the macro with: "/tooltip spell:spellid" or "/tooltip item:itemid" respectively.</font>
+ <font style="color:rgb(31, 35, 40);">GetActionCount, GetActionCooldown, and ActionIsConsumable now work for macros returning the result of the linked spell or item. For example, you can create a macro that starts with "/tooltip item:18641" and all of these functions will treat it as if it's the item 18641 (dense dynamite), even if the macro will cast a different action on press.</font>
+ <font style="color:rgb(31, 35, 40);">GetActionText(actionButton) now additionally returns action type ("MACRO", "ITEM", "SPELL") and its id, or for macro, its index. a macro's index is the value used by GetMacroInfo(index). This allows you to differentiate between two macros on your actionbar that have the same name, or to find the id of an item or spell that is on your bar.</font>

<font style="color:rgb(31, 35, 40);">New functions:</font>

+ <font style="color:rgb(31, 35, 40);">GetPlayerBuffID(buffindex) function that returns id of the aura.</font>
+ <font style="color:rgb(31, 35, 40);">CombatLogAdd("text"[, addToRawLog]) function that prints a message directly to the combatlog file. If flag is set, prints the message to the raw combatlog file instead.</font>
+ <font style="color:rgb(31, 35, 40);">SpellInfo(spellid) function that returns information about a spell id (name, rank, texture file, minrange, max range to target).</font>
+ <font style="color:rgb(31, 35, 40);">TrackUnit(unitid) function that adds a</font><font style="color:rgb(31, 35, 40);"> </font>**<font style="color:rgb(31, 35, 40);">friendly</font>**<font style="color:rgb(31, 35, 40);"> </font><font style="color:rgb(31, 35, 40);">unit to the minimap.</font>
+ <font style="color:rgb(31, 35, 40);">TrackUnit(unitid) function that removes tracking. UntrackUnit("all") can be used remove tracking from all units.</font>
+ <font style="color:rgb(31, 35, 40);">UnitPosition(unitid) function that returns coordinates of a</font><font style="color:rgb(31, 35, 40);"> </font>**<font style="color:rgb(31, 35, 40);">friendly</font>**<font style="color:rgb(31, 35, 40);"> </font><font style="color:rgb(31, 35, 40);">unit.</font>
+ <font style="color:rgb(31, 35, 40);">SetMouseoverUnit(unitid) function that sets as current hovered unit. Usage for unitframe addon makers: do SetMouseoverUnit(frameUnit) on enter, and SetMouseoverUnit() on leave to clear. This allows "mouseover" of other functions to work on that currently hovered frame's unit.</font>
+ <font style="color:rgb(31, 35, 40);">Clickthrough(0/1) to turn off/on Clickthrough mode, Clickthrough() to simply return whether it's on. Clickthrough mode allows you to click through creature corpses that have no loot, to loot the creatures that are under them & covered by them.</font>
+ <font style="color:rgb(31, 35, 40);">SetAutoloot(0/1) to turn off/on autoloot, SetAutoloot() to simply return whether it's on. The hardcoded activation of autoloot by holding shift has been removed. You now turn it on or off through this function).</font>
+ <font style="color:rgb(31, 35, 40);">ImportFile("filename") reads a txt file in gamedirectory\imports and returns a string of its contents.</font>
+ <font style="color:rgb(31, 35, 40);">ExportFile("filename", "text") creates a txt file in gamedirectory\imports and writes text in it.</font>
+ <font style="color:rgb(31, 35, 40);">UnitNameplate("unit") function that returns Nameplate frame.</font>
+ <font style="color:rgb(31, 35, 40);">CanLootUnit("unit") function that returns whether a unit has loot inside.</font>
+ <font style="color:rgb(31, 35, 40);">CursorPosition() function that returns world XYZ coordinates of mouseover.</font>
+ <font style="color:rgb(31, 35, 40);">GetWorldLocMapPosition(continent, x, y) that returns map XY coordinates from a world XYZ coordinate and continent index.</font>
+ <font style="color:rgb(31, 35, 40);">GetMapPositionWorldLoc(continentIndex, zoneIndex, mapX, mapY) that returns world XYZ coordinates from map XY coordinates.</font>
+ <font style="color:rgb(31, 35, 40);">GetMapBoundaries(continentIndex, zoneIndex) that returns left, right, top and bottom boundaries of a map.</font>
+ <font style="color:rgb(31, 35, 40);">IsSwimming(), IsMounted(), isIndoors() functions to return the status of the player.</font>
+ <font style="color:rgb(31, 35, 40);">GetSpeed() function to return runSpeed, swimSpeed of the player in yards per second (7 yards = 100% movement speed)</font>
+ <font style="color:rgb(31, 35, 40);">GetSendMailItemLink(). Returns Hyperlink for the item in Sending Mail slot.</font>
+ <font style="color:rgb(31, 35, 40);">GetInboxItemLink(itemIndex). Returns Hyperlink for the item in Mailbox slot.</font>
+ <font style="color:rgb(31, 35, 40);">GetQuestIDForLogIndex(questIndex). Returns ID for the quest index in your questlog</font>
+ <font style="color:rgb(31, 35, 40);">GetQuestLinkForLogIndex(questIndex). Returns Hyperlink for the quest index in your questlog</font>
+ <font style="color:rgb(31, 35, 40);">GetQuestLinkForID(questID). Returns Hyperlink for the quest ID from client cache. If no entry in cache, returns nil and fills the cache from server (fires event QUEST_LOG_UPDATE)</font>
+ <font style="color:rgb(31, 35, 40);">Tooltip SetHyperlink now supports quest hyperlinks with information from client cache. If no entry in cache, fills the cache from server. Generate Hyperlinks with GetQuestLink or get them directly from Wowhead.</font>
+ <font style="color:rgb(31, 35, 40);">all functions that accept a unit as argument ("player", "target", "mouseover") now can accept an additional suffix "owner" which returns the owner of the unit (example, if you target a totem and do UnitName("targetowner") you'll get the name of the shaman).</font>
+ <font style="color:rgb(31, 35, 40);">all functions taht accept a unit as argument ("player, "target", "mouseover") now can accept "mark1" to "mark8" as argument which returns the unit with the corresponding marker index.</font>
+ <font style="color:rgb(31, 35, 40);">all functions that accept a unit as argument ("player", "target", "mouseover") now can accept the GUID of the unit, which can be obtained from UnitExists or GetName(1) on its nameplate. Suffixes can still be appended at the end of that string.</font>
+ <font style="color:rgb(31, 35, 40);">Global variables SUPERWOW_STRING and SUPERWOW_VERSION give mod info for addons.</font>
