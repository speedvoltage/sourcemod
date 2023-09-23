/******************************
INCLUDE ALL THE NECESSARY FILES
******************************/

#include <sourcemod>
#include <basecomm>
#include <unixtime_sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <updater>

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Updater*/
#define UPDATE_URL    "https://raw.githubusercontent.com/speedvoltage/sourcemod/master/addons/sourcemod/name_hl2dm.upd"

/*Plugin Info*/
#define PLUGIN_NAME								"Set My Name"
#define PLUGIN_AUTHOR							"Peter Brev (Base code provided by Harper)"
#define PLUGIN_VERSION							"1.7.0.1960" //Build number since 05/12/18
#define PLUGIN_DESCRIPTION						"Complete plugin allowing name changes for players + administration tools for admins"
#define PLUGIN_URL								"N/A"

/*Plugin defines for messages*/
#define TAG									"[NAME]"
#define CTAG 									"\x0729e313"
#define CUSAGE 								"\x0700ace6"
#define CERROR 								"\x07ff2700"
#define CLIME									"\x0700ff15"
#define CPLAYER								"\x07ffb200"
#define REBELS								"\x07ff4347"
#define COMBINE								"\x0743b0ff"
#define SPEC								"\x07ff811c"
#define UNASSIGNED							"\x07f7ff7f"

/*Logging*/
#define LOGTAG									"[NAME DEBUG]"
#define CLOGTAG								"\x078e8888"
#define LOGPATH								"addons/sourcemod/logs/NameChanger/NameChanger.log"
#define SND_DEBUG_ON						"hl1/fvox/bell.wav"
#define SND_DEBUG_OFF						"hl1/fvox/beep.wav"

/*Sound*/
#define MAX_FILE_LEN							80

/*Boolean for EventHook*/

bool EventsHook = false;

bool g_bMapReload;
bool g_bMapReloadClient[MAXPLAYERS + 1] =  { true, ... };
bool g_bClientAuthorized[MAXPLAYERS + 1] =  { true, ... };
bool g_bForcedName[MAXPLAYERS + 1] =  { true, ... };
bool g_bAdminRenamed[MAXPLAYERS + 1] =  { true, ... };

/******************************
PLUGIN STRINGMAPS
******************************/

StringMap g_names;
StringMap g_bannednames;
StringMap g_bannedids;

/******************************
PLUGIN HANDLES
******************************/

Handle changename_help;
Handle steamname_enable;
Handle changename_version;
Handle changename_enable_global;
Handle changename_enable;
Handle originalname_enable;
Handle changename_debug;
Handle changename_steamreset;
Handle changename_bantime;
Handle changename_banreason;
Handle changename_cooldown = INVALID_HANDLE;
Handle changename_adminrename_cooldown = INVALID_HANDLE;
Handle changename_checkbadnames;
Handle changename_checkbannedids;

Handle g_hTimer[MAXPLAYERS + 1];
Handle g_hForceLockSteamCheck[MAXPLAYERS + 1];

Handle g_hPluginReload[MAXPLAYERS + 1];

//Sound Handles
Handle changename_debug_snd;

Handle changename_debug_snd_warn_on = INVALID_HANDLE;
Handle changename_debug_snd_warn_off = INVALID_HANDLE;

/******************************
PLUGIN INTEGERS
******************************/

int g_iLastUsed[MAXPLAYERS + 1];

//Track the number of times names were changed through this plugin (for statistic purposes "nameadmin plugin stats")
int g_iNameChangeTracker;
int g_iNameResetTracker;
int g_iRenameTracker;
int g_iOnameTracker;
int g_iSnameTracker;
int g_iSrnameTracker;
int g_iSteamQueryFail;
int g_iForcedNames;

//Same, but per player
int g_iChangedMyName[MAXPLAYERS + 1]; //!name <new name> usage tracker
int g_iResetMyName[MAXPLAYERS + 1]; //!name with no argument usage tracker
int g_iWasRenamed[MAXPLAYERS + 1]; //!rename
int g_iResetToSteam[MAXPLAYERS + 1]; //!srname
int g_iCheckedOname[MAXPLAYERS + 1]; //!oname
int g_iCheckedSname[MAXPLAYERS + 1]; //!sname
int g_iCouldNotQuery[MAXPLAYERS + 1];
int g_iWasForcedNamed[MAXPLAYERS + 1];

int g_iTargetWasSteamChecked[MAXPLAYERS + 1]; //Tracking how many times this player was checked by another
int g_iTargetWasOnameChecked[MAXPLAYERS + 1]; //Same with oname

//We will want the date and time information as well. If the plugin gets reloaded by any means (server restart or whatnot), dump all the statistics info into Sourcemod logs.

int iYear, iMonth, iDay, iHour, iMinute, iSecond;

int g_iClients[MAXPLAYERS + 1], g_iTimeTotal[MAXPLAYERS + 1];

/******************************
PLUGIN STRINGS
******************************/

char g_SoundName_On[MAX_FILE_LEN];
char g_SoundName_Off[MAX_FILE_LEN];

char BadNames[255][64];
char fileName[PLATFORM_MAX_PATH];
char lines;

char bannedsteamids[255][64];
char bannedidfile[PLATFORM_MAX_PATH];
char bannedlines;

char g_targetnewname[MAXPLAYERS + 1][MAX_NAME_LENGTH];

char ModelsHuman[45][70] =  {
	"models/humans/group01/female_01.mdl", 
	"models/humans/group01/female_02.mdl", 
	"models/humans/group01/female_03.mdl", 
	"models/humans/group01/female_04.mdl", 
	"models/humans/group01/female_06.mdl", 
	"models/humans/group01/female_07.mdl", 
	"models/humans/group01/male_01.mdl", 
	"models/humans/group01/male_02.mdl", 
	"models/humans/group01/male_03.mdl", 
	"models/humans/group01/male_04.mdl", 
	"models/humans/group01/male_05.mdl", 
	"models/humans/group01/male_06.mdl", 
	"models/humans/group01/male_07.mdl", 
	"models/humans/group01/male_08.mdl", 
	"models/humans/group01/male_09.mdl", 
	"models/humans/group02/female_01.mdl", 
	"models/humans/group02/female_02.mdl", 
	"models/humans/group02/female_03.mdl", 
	"models/humans/group02/female_04.mdl", 
	"models/humans/group02/female_06.mdl", 
	"models/humans/group02/female_07.mdl", 
	"models/humans/group02/male_01.mdl", 
	"models/humans/group02/male_02.mdl", 
	"models/humans/group02/male_03.mdl", 
	"models/humans/group02/male_04.mdl", 
	"models/humans/group02/male_05.mdl", 
	"models/humans/group02/male_06.mdl", 
	"models/humans/group02/male_07.mdl", 
	"models/humans/group02/male_08.mdl", 
	"models/humans/group02/male_09.mdl", 
	"models/humans/group03/female_01.mdl", 
	"models/humans/group03female_02.mdl", 
	"models/humans/group03/female_03.mdl", 
	"models/humans/group03/female_04.mdl", 
	"models/humans/group03/female_06.mdl", 
	"models/humans/group03/female_07.mdl", 
	"models/humans/group03/male_01.mdl", 
	"models/humans/group03/male_02.mdl", 
	"models/humans/group03/male_03.mdl", 
	"models/humans/group03/male_04.mdl", 
	"models/humans/group03/male_05.mdl", 
	"models/humans/group03/male_06.mdl", 
	"models/humans/group03/male_07.mdl", 
	"models/humans/group03/male_08.mdl", 
	"models/humans/group03/male_09.mdl"
};

/******************************
PLUGIN INFO
******************************/

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL, 
};

/******************************
INITIATE THE PLUGIN
******************************/
public void OnPluginStart()
{
	/***STOP PLUGIN IF USED ON CS:GO***/
	
	EngineVersion engine = GetEngineVersion();
	
	if (engine != Engine_HL2DM)
	{
		SetFailState("%s This version is intended for Half-Life 2: Deathmatch. You must use the version for the game you play.", TAG);
	}
	
	/***STOP PLUGIN IF OTHER NAME PLUGIN IS FOUND***/
	
	if (FindPluginByFile("sm_name.smx") != null)
	{
		ThrowError("%s You are using a plugin from Eyal282 that delivers the same function. You cannot run both at once!", TAG);
		LogError("Attempted to load both \"sm_name.smx\" and \"name.smx\". This is invalid!");
	}
	
	/***PRE-SETUP***/
	
	g_names = CreateTrie();
	g_bannednames = CreateTrie();
	g_bannedids = CreateTrie();
	
	//We want to hook player_changename in order to block the default message from showing.
	
	bool exists = HookEventEx("player_changename", namechange_callback, EventHookMode_Pre);
	if (!exists)
	{
		SetFailState("Event player_changename does not exist. Unloading...");
	}
	
	HookEvent("player_team", playerteam_callback, EventHookMode_Pre); // To fix death when names get changed through SM commands
	HookUserMessage(GetUserMessageId("TextMsg"),  dfltmsg,  true); // To get rid of default engine messages
	
	//Never thought I would be doing such "for" loop on plugin start, but it is what it is.
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			g_iClients[i] = GetClientUserId(i);
		}
	}
	
	//PrecacheModel("models/humans/group03/female_04.mdl");
	for (int i; i < sizeof(ModelsHuman); i++)
	{
		PrecacheModel(ModelsHuman[i]);
	}
	
	//Updater
	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
        PrintToServer("%s Updater found and ready to rock.");
    }
	
	//Finally, load the translations
	
	LoadTranslations("common.phrases");
	
	BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	BuildPath(Path_SM, bannedidfile, sizeof(bannedidfile), "configs/banned_id.ini");
	
	/***PLUGIN STATISTICS STUFF***/
	
	//Initialize the name tracking counter
	g_iNameChangeTracker = 0;
	g_iNameResetTracker = 0;
	g_iRenameTracker = 0;
	g_iOnameTracker = 0;
	g_iSnameTracker = 0;
	g_iSrnameTracker = 0;
	g_iSteamQueryFail = 0;
	g_iForcedNames = 0;
	
	UnixToTime(GetTime(), iYear, iMonth, iDay, iHour, iMinute, iSecond, UT_TIMEZONE_CET + 1);
	
	/***COMMANDS SETUP***/
	
	//Create a convar for plugin version & with the help of the handle, go ahead and put the proper version
	
	changename_version = CreateConVar("sm_name_version", PLUGIN_VERSION, "Plugin Version (DO NOT CHANGE)", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_SPONLY);
	
	SetConVarString(changename_version, PLUGIN_VERSION);
	
	//Create ConVars
	
	//General
	changename_help = CreateConVar("sm_name_help_enable", "1", "Controls whether the plugin should print a help message when clients join", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_enable_global = CreateConVar("sm_name_enable", "1", "Controls whether the plugin should be enabled or disabled", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_enable = CreateConVar("sm_cname_enable", "1", "Controls whether players can change their name", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	originalname_enable = CreateConVar("sm_oname_enable", "1", "Controls whether players can check original name of players", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	steamname_enable = CreateConVar("sm_sname_enable", "1", "Controls whether players can check Steam name of players", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_steamreset = CreateConVar("sm_srname_enable", "1", "Controls whether players can reset their name to their Steam name", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_bantime = CreateConVar("sm_name_ban_time", "-2", "Controls the length of the ban. Use \"-1\" to kick, \"-2\" to display a message to the player.", FCVAR_NOTIFY, true, -2.0);
	changename_banreason = CreateConVar("sm_name_ban_reason", "[AUTO-DISCONNECT] This name is banned from being used. Please change it.", "What message to display on kick/ban.");
	changename_cooldown = CreateConVar("sm_name_cooldown", "30", "Time before letting players change their name again.", FCVAR_NOTIFY);
	changename_checkbadnames = CreateConVar("sm_name_bannednames_checker", "1", "Controls whether banned names should be filtered.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_checkbannedids = CreateConVar("sm_name_bannedids_checker", "1", "Controls whether banned Steam IDs should be checked.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_adminrename_cooldown = CreateConVar("sm_rename_cooldown", "600", "Controls how long a player needs to wait before changing their name again after an admin renamed them.", FCVAR_NOTIFY);
	
	//Technical
	changename_debug = CreateConVar("sm_name_debug", "0", "Toggles logging for debugging purposes (Only use this if you are experiencing weird issues)", 0, true, 0.0, true, 1.0); //Allows us to debug in case of an issue with the plugin
	changename_debug_snd = CreateConVar("sm_name_debug_snd", "1", "Sets whether to play a sound when debug mode is toggle on or off", 0, true, 0.0, false, 1.0);
	changename_debug_snd_warn_on = CreateConVar("sm_name_debug_snd_on", SND_DEBUG_ON, "Sets the sound to let admins know debug mode has been turned on");
	changename_debug_snd_warn_off = CreateConVar("sm_name_debug_snd_off", SND_DEBUG_OFF, "Sets the sound to let admins know debug mode has been turned off");
	
	
	//Hooking Cvars
	HookConVarChange(changename_debug, OnConVarChanged_Debug); //If debug value was changed, let the server operator know
	HookConVarChange(changename_enable_global, OnConVarChanged_Global);
	HookConVarChange(changename_enable, OnConVarChanged_Name);
	HookConVarChange(originalname_enable, OnConVarChanged_Oname);
	HookConVarChange(steamname_enable, OnConVarChanged_Sname);
	HookConVarChange(changename_debug_snd, OnConVarChanged_Snd);
	HookConVarChange(changename_debug_snd_warn_on, OnConVarChanged_SndOn);
	HookConVarChange(changename_debug_snd_warn_off, OnConVarChanged_SndOff);
	HookConVarChange(changename_steamreset, OnConVarChanged_Srname);
	HookConVarChange(changename_checkbadnames, OnConVarChanged_NameCheck);
	HookConVarChange(changename_checkbannedids, OnConVarChanged_IdCheck);
	
	parseList_Name(false);
	parseList_id(false);
	
	//Create the admin commands
	RegAdminCmd("sm_name_ban", Command_NameBan, ADMFLAG_BAN, "sm_name_ban <name to ban (NO SPACES)> - Bans a name from being used");
	RegAdminCmd("sm_name_unban", Command_NameUnban, ADMFLAG_BAN, "sm_name_unban <name to unban (NO SPACES)> - Unbans a previously banned name");
	RegAdminCmd("sm_name_banid", Command_SteamidBan, ADMFLAG_BAN, "sm_name_banid <SteamID to ban> - Ban a player from changing their name");
	RegAdminCmd("sm_name_unbanid", Command_SteamidUnban, ADMFLAG_BAN, "sm_name_unbanid <SteamID to unban> - Unbans a player from changing their name");
	RegAdminCmd("sm_name_reload", Command_FilesRefresh, ADMFLAG_BAN, "Reloads banned_names.ini and banned_id.ini");
	RegAdminCmd("sm_rename", Command_Rename, ADMFLAG_SLAY, "sm_rename <#userid|name> <new name> - Renames a player manually and apply a temporary cooldown before being able to change names again");
	RegAdminCmd("sm_name_random", Command_RenameRandom, ADMFLAG_SLAY, "sm_name_random <#userid|name> - Randomly generates a name on the selected target");
	RegAdminCmd("sm_name_force", Command_NameForce, ADMFLAG_SLAY, "sm_name_force <#userid|name> <name to force> - Forces a client to keep a name");
	RegAdminCmd("sm_name_unforce", Command_NameUnforce, ADMFLAG_SLAY, "sm_name_unforce <#userid|name> - Removes forced name restrictions on a player");
	RegAdminCmd("nameadmin", Command_NameAdmin, ADMFLAG_ROOT, "nameadmin <command> [arguments] - Administration system for the name plugin");
	
	//Create the public commands
	RegConsoleCmd("sm_name", Command_Name, "sm_name <new name> (Leave blank to reset to join name or Steam name)");
	RegConsoleCmd("sm_oname", Command_Oname, "sm_oname <#userid|name> - Find the original name of a player upon connection");
	RegConsoleCmd("sm_sname", Command_Sname, "sm_sname <#userid|name> - Find the Steam name of a player");
	RegConsoleCmd("sm_srname", Command_Srname, "sm_srname - Resets the player's name to their Steam name");
	RegConsoleCmd("sm_nhelp", Command_Hname, "sm_name_help - Prints commands to the clients console");
	RegConsoleCmd("sm_name_credits", Command_Credits, "sm_name_credits - Display credits listing");
	
	//Configs
	AutoExecConfig(true, "sm_name");
	
	/***DEBUGGING SETUP***/
	
	//We are just creating a directory for our log files to be stored in instead of using Sourcemod's logging system, so that it is easier to debug
	
	if (GetConVarBool(changename_debug))
	{
		Debug_Path();
	}
	
	//Are we done here? Can we move to coding the real thing?
}

/******************************
PUBLIC CALLBACKS
******************************/

public void OnLibraryAdded(const char[] sName)
{
    if (StrEqual(sName, "updater")) 
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public Action ConVarChecker_Callback(Handle timer, any data)
{
	if (!GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable) && !GetConVarBool(changename_steamreset))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_steamreset, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" were set to 0. This is the same behavior as setting ConVar \"sm_name_enable\" to 0. All three ConVars were set to 1 and \"sm_name_enable\" was set to 0. Use 1 to enable the plugin again.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" being turned off.", LOGTAG);
		}
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	PrecacheSound(SND_DEBUG_ON, true);
	PrecacheSound(SND_DEBUG_OFF, true);
	
	for (int i = 0; i < lines; i++)
	{
		BadNames[i] = "";
	}
	
	lines = 0;
	
	for (int y = 0; y < bannedlines; y++)
	{
		bannedsteamids[y] = "";
	}
	
	bannedlines = 0;
	
	if (ReadConfig() && !EventsHook)
	{
		HookEvent("player_changename", checkName);
		EventsHook = true;
	}
	
	if (ReadBannedId() && !EventsHook)
	{
		HookEvent("player_changename", checkId);
		EventsHook = true;
	}
	
	if (changename_cooldown == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid value for \"sm_name_cooldown\".", TAG);
	}
	
	if (changename_adminrename_cooldown == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid value for \"sm_rename_cooldown\".", TAG);
	}
	
	if (GetConVarInt(changename_cooldown) < 1)
	{
		SetConVarInt(changename_cooldown, 30, _, true);
		PrintToServer("%s Cooldown value cannot be less than 1 second. Value reset to default (30 seconds).", TAG);
	}
	
	if (GetConVarInt(changename_adminrename_cooldown) < 1)
	{
		SetConVarInt(changename_adminrename_cooldown, 600, _, true);
		PrintToServer("%s Rename cooldown value cannot be less than 1 second. Value reset to default (30 seconds).", TAG);
	}
	
	if (!GetConVarBool(changename_enable_global))
	{
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable))
	{
		PrintToServer("%s Name changing is disabled. To turn it on, use \"sm_cname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Name changing disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(originalname_enable))
	{
		PrintToServer("%s Fetching original names is disabled. To turn it on, use \"sm_oname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Fetching original names disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(steamname_enable))
	{
		PrintToServer("%s Fetching Steam names is disabled. To turn it on, use \"sm_sname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Fetching Steam names disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_steamreset))
	{
		PrintToServer("%s Steam name reset ability is disabled. To turn it on, use \"sm_srname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Reset to Steam name ability disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable) && !GetConVarBool(changename_steamreset))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_steamreset, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" were set to 0. This is the same behavior as setting ConVar \"sm_name_enable\" to 0. All three ConVars values were set to 1 and ConVar value \"sm_name_enable\" was set to 0. Use 1 to enable the plugin again.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to ConVars values \"sm_cname_enable\", \"sm_oname_enable\", \"sm_sname_enable\", and \"sm_srname_enable\" being set to 0.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable_global) && !GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable) && !GetConVarBool(changename_steamreset))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_steamreset, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s All ConVars values were set to 0. ConVar \"sm_cname_enable\", \"sm_oname_enable\", \"sm_sname_enable\", and \"sm_srname_enable\" values were set to 0 and ConVar \"sm_name_enable\" was set to 1.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to all ConVars values being set to 0. Setting \"sm_name_enable\" to 1.", LOGTAG);
		}
	}
	
	if (changename_debug_snd_warn_on == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid sound file path for debug sound warn ON.");
	} else if (changename_debug_snd_warn_off == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid sound file path for debug sound warn OFF.");
	}
	
	// Reset the value of this boolean whenever "nameadmin plugin reload map_reload" is used.
	g_bMapReload = false;
	
	ConVarCheck();
}

public bool ReadConfig()
{
	//BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	Handle file = OpenFile(fileName, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("%s Banned names file could not be opened.", TAG, fileName);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned names file could not be opened. Check that the file is placed in the \"configs\" folder.", LOGTAG);
		}
		return false;
	}
	
	if (file != INVALID_HANDLE)
	{
		PrintToServer("%s Successfully loaded banned_names.ini", TAG, fileName);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned names file loaded.", LOGTAG);
		}
	}
	
	while (!IsEndOfFile(file))
	{
		char line[64];
		
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, 64, " ", "");
		
		if (strlen(line) == 0 || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}
		strcopy(BadNames[lines], sizeof(BadNames[]), line);
		lines++;
	}
	
	CloseHandle(file);
	return true;
}

public void OnClientPostAdminCheck(int client)
{
	char PlayerName[64];
	char getsteamid[64];
	
	if (!GetClientName(client, PlayerName, 64))
	{
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Could not acquire a client name (on post admin check).", LOGTAG);
		}
		return;
	}
	
	if (!GetClientAuthId(client, AuthId_Steam2, getsteamid, 64))
	{
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Could not acquire a client SteamID.", LOGTAG);
		}
		return;
	}
	
	NameCheck(PlayerName, client);
	IdCheck(getsteamid, client);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s Performed name, and SteamID checks on %s (%s)).", LOGTAG, PlayerName, getsteamid);
	}
}

void NameCheck(char clientName[64], char player)
{
	//char PlayerID = GetClientUserId(player);
	AdminId playerAdmin = GetUserAdmin(player);
	
	if (GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		return;
	}
	
	ReplaceString(clientName, 64, " ", "");
	
	for (int i = 0; i < lines; i++)
	{
		if (StrContains(clientName, BadNames[i], false) != -1)
		{
			char bantime = GetConVarInt(changename_bantime);
			char reason[128];
			GetConVarString(changename_banreason, reason, 128);
			if (GetConVarBool(changename_checkbadnames))
			{
				if (bantime > -1)
				{
					BanClient(player, bantime, BANFLAG_AUTO, reason, reason);
					//ServerCommand("sm_ban #%i %i %s", PlayerID, bantime, reason);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s was banned for using a banned name.", LOGTAG, clientName);
					}
				}
				if (bantime == -2)
				{
					SetClientName(player, "<NAME REMOVED>");
					PrintToChat(player, "%s%s %sYour name has been removed, because it is banned on this server.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s's name removed (banned name).", LOGTAG, clientName);
					}
				}
				if (bantime == -1)
				{
					//ServerCommand("sm_kick #%i %s", PlayerID, reason);
					KickClient(player, reason);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s was kicked for using a banned name.", LOGTAG, clientName);
					}
				}
			}
		}
	}
	return;
}

public Action checkName(Event event, const char[] name, bool dontBroadcast)
{
	char PlayerName[64];
	GetEventString(event, "newname", PlayerName, 64);
	NameCheck(PlayerName, GetClientOfUserId(GetEventInt(event, "userid")));
	return Plugin_Handled;
}

public bool ReadBannedId()
{
	//BuildPath(Path_SM, bannedidfile, sizeof(bannedidfile), "configs/banned_id.ini");
	Handle file = OpenFile(bannedidfile, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("%s Banned IDs file could not be opened.", TAG, bannedidfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned IDs file could not be opened. Check that the file is placed in the \"configs\" folder.", LOGTAG);
		}
		return false;
	}
	
	if (file != INVALID_HANDLE)
	{
		PrintToServer("%s Successfully loaded banned_id.ini", TAG, bannedidfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned Steam IDs file loaded.", LOGTAG);
		}
	}
	
	while (!IsEndOfFile(file))
	{
		char line[64];
		
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, 64, " ", "");
		
		if (strlen(line) == 0 || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}
		strcopy(bannedsteamids[bannedlines], sizeof(bannedsteamids[]), line);
		bannedlines++;
	}
	
	CloseHandle(file);
	return true;
}

void IdCheck(char getsteamid[64], char client)
{
	AdminId clientAdmin = GetUserAdmin(client);
	
	if (GetAdminFlag(clientAdmin, Admin_Generic, Access_Effective))
	{
		return;
	}
	
	ReplaceString(getsteamid, 64, " ", "");
	
	for (int i = 0; i < bannedlines; i++)
	{
		if (StrContains(getsteamid, bannedsteamids[i], false) != -1)
		{
			char bantime = GetConVarInt(changename_bantime);
			if (GetConVarBool(changename_checkbannedids))
			{
				if (bantime == -2)
				{
					PrintToChat(client, "%s%s %sYour Steam ID is banned from changing names.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s attempted to change their name, but they are banned from doing so.", LOGTAG, client);
					}
				}
			}
		}
	}
	return;
}

public Action checkId(Event event, const char[] name, bool dontBroadcast)
{
	char PlayerName[64];
	GetEventString(event, "steamid2", PlayerName, 64);
	IdCheck(PlayerName, GetClientOfUserId(GetEventInt(event, "userid")));
	return Plugin_Handled;
}

public void OnMapEnd()
{
	if (GetConVarBool(changename_debug))
	{
		ResetConVar(changename_debug, false, false);
		char map[64];
		GetCurrentMap(map, sizeof(map));
		LogToFile(LOGPATH, "%s The map is ending (%s). Debug mode turned off.", LOGTAG, map);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hTimer[i] = null;
	}
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s One or more players were still under cooldown following an admin rename. Due to the map ending, their cooldown has been removed.", LOGTAG);
	}
}

public void OnPluginEnd()
{
	LogMessage("Plugin was unloaded. Dumping latest information to the Sourcemod logs:\nNumber of name changes: %i\nNumber of name resets: %i\nNumber of admin renames: %i\nNumber of forced names set: %i\nNumber of Steam name resets: %i\nNumber of join names checked: %i\nNumber of Steam names checked: %i\n", g_iNameChangeTracker, g_iNameResetTracker, g_iRenameTracker, g_iForcedNames, g_iSrnameTracker, g_iOnameTracker, g_iSnameTracker, g_iSrnameTracker);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
		{
			LogMessage("No players were connected at this time.");
			return;
		}
		char name[MAX_NAME_LENGTH], id[32];
		GetClientName(i, name, sizeof(name));
		GetClientAuthId(i, AuthId_Steam2, id, sizeof(id));
		LogMessage("Dumping per player information to the Sourcemod logs:\nPlayer: %s - %s\nNumber of name changes: %i\nNumber of name resets: %i\nNumber of admin renames: %i\nNumber of forced names set: %i\nNumber of Steam name resets: %i\nNumber of !oname usage: %i\nNumber of !sname usage: %i\nNumber of failed queries: %i\nNumber of times player was checked by another player for Steam name: %i\nNumber of times player was checked by another player for join name: %i\n", name, id, g_iChangedMyName[i], g_iResetMyName[i], g_iWasRenamed[i], g_iWasForcedNamed[i], g_iResetToSteam[i], g_iCheckedOname[i], g_iCheckedSname[i], g_iCouldNotQuery[i], g_iTargetWasSteamChecked[i], g_iTargetWasOnameChecked[i]);
		g_hTimer[i] = null;
		return;
	}
}

public Action namechange_callback(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_enable))
		{
			SetEventBroadcast(event, true);
			int client = GetClientOfUserId(GetEventInt(event, "userid"));
			if (!client || IsFakeClient(client))
				return Plugin_Continue;
			
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, " % s Default player name change messages suppressed.", LOGTAG);
			}
			return Plugin_Changed; // avoid printing the change to the chat 
		}
	} else {
		SetEventBroadcast(event, false);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, " % s Default player name change messages was not suppressed due to ConVar\"sm_cname_enable\" being set to 0.", LOGTAG);
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action playerteam_callback(Event event, const char[] name, bool dontBroadcast) // HL2DM: Fixes death when name gets changed through a command
{
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_enable))
		{
			SetEventBroadcast(event, true);
			int client = GetClientOfUserId(GetEventInt(event, "userid"));
			int team = GetEventInt(event, "team");
			int silent = GetEventBool(event, "silent");
			int auto = GetEventBool(event, "autoteam");
			if (!client || IsFakeClient(client))
				return Plugin_Handled;
			
			if (team == 3)
			{
				ClientCommand(client, "cl_playermodel models/humans/group03/female_04.mdl");
				SetEntityRenderColor(client, 255, 255, 255, 255);
				PrintToChat(client, "Adjusting your cl_playermodel setting to match your team.");
				PrintToChatAll("%s%N %shas joined team: %sRebels", REBELS, client, CPLAYER, REBELS);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", LOGTAG, client, REBELS);
				}
				
				if (silent == 1 || auto == 1)
				{
					return Plugin_Handled;
				}
				return Plugin_Handled;
			}
			
			if (team == 2)
			{
				ClientCommand(client, "cl_playermodel models/police.mdl");
				SetEntityRenderColor(client, 255, 255, 255, 255);
				PrintToChat(client, "Adjusting your cl_playermodel setting to match your team.");
				PrintToChatAll("%s%N %shas joined team: %sCombine", COMBINE, client, CPLAYER, COMBINE);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", LOGTAG, client, COMBINE);
				}
				if (silent == 1 || auto == 1)
				{
					return Plugin_Handled;
				}
				return Plugin_Handled;
			}
			
			if (team == 1)
			{
				PrintToChatAll("%s%N %shas joined team: %sSpectators", SPEC, client, CPLAYER, SPEC);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", LOGTAG, client, SPEC);
				}
				if (silent == 1 || auto == 1)
				{
					return Plugin_Handled;
				}
				return Plugin_Handled;
			}
			
			if (team == 0)
			{
				PrintToChatAll("%s%N %shas joined team: %sPlayers", UNASSIGNED, client, CPLAYER, UNASSIGNED);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", LOGTAG, client, UNASSIGNED);
				}
				if (silent == 1 || auto == 1)
				{
					return Plugin_Handled;
				}
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action dfltmsg(UserMsg msg, Handle hMsg, const int[] iPlayers, int iNumPlayers, bool bReliable, bool bInit)
{
    char sMessage[70];

    BfReadString(hMsg, sMessage, sizeof(sMessage), true);
    if (StrContains(sMessage, "more seconds before trying to switch") != -1 || StrContains(sMessage, "Your player model is") != -1 || StrContains(sMessage, "You are on team") != -1)
    {
        return Plugin_Handled; // Get rid of those crap messages
    }

    return Plugin_Continue;
}

//public void CheckCommands(int client, char[] string)
public Action Command_Srname(int client, int args)
{
	if (g_bClientAuthorized[client])
	{
		PrintToChat(client, "%s%s %sYour SteamID was not verified yet. Please wait before trying to change your name.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to reset their name to their Steam name but their SteamID was not yet verified.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (g_bMapReloadClient[client])
	{
		PrintToChat(client, "%s%s %sYou cannot fetch another player's name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to change their name pending plugin restart.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bMapReload)
	{
		PrintToChat(client, "%s%s %sYou cannot fetch another player's name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to change their name pending plugin restart.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bForcedName[client])
	{
		PrintToChat(client, "%s%s %sYour name is being forced locked. You cannot change your name.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N name is forced locked, but still tried to change their name.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	bool gag = BaseComm_IsClientGagged(client);
	
	if (gag)
	{
		PrintToChat(client, "%s%s %sYou are gagged and cannot change your name right now.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
	
	if (IsFakeClient(client))
	{
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N: name change attempted on a fake client.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_steamreset))
		{
			if (args > 0)
			{
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N improperly formatted the command by including arguments.", LOGTAG, client);
				}
				return Plugin_Handled;
			}
			
			if (!args)
			{
				QueryClientConVar(client, "name", ChangeNameToSteamName);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has attempted a Steam name reset.", LOGTAG, client);
				}
				return Plugin_Handled;
			}
		}
		else
		{
			PrintToChat(client, "%s%s %sResetting to Steam name ability has been disabled.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Steam name reset ability disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted a Steam name reset but ability is disabled.", LOGTAG, client);
			}
			return Plugin_Handled;
		}
	}
	else
	{
		PrintToChat(client, "%s%s %sPlugin is currently disabled.", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
			LogToFile(LOGPATH, "%s %N attempted a Steam name reset but plugin is disabled.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	
	g_bMapReloadClient[client] = false;
	g_bForcedName[client] = false;
	g_bAdminRenamed[client] = false;
	
	if (IsFakeClient(client))
	{
		return;
	}
	
	if (GetConVarBool(changename_help))
	{
		PrintToChat(client, "%s%s %sThis server allows name changes. Type %s!nhelp %sfor more information.", CTAG, TAG, CUSAGE, CLIME, CUSAGE);
	}
	else
	{
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Server does not provide help message.", LOGTAG);
		}
	}
	
	char PlayerName[64], id[32];
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	
	if (!GetClientName(client, PlayerName, 64))
	{
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Could not find player name (on client put in server).", LOGTAG);
		}
		return;
	}
	
	// Player joins => Total time played is obviously 0:00:00
	if (g_iClients[client] != GetClientUserId(client))
	{
		g_iClients[client] = GetClientUserId(client);
		if (!IsFakeClient(client))
		{
			g_iTimeTotal[client] = RoundToZero(GetClientTime(client));
		}
	}
}

public void OnClientConnected(int client)
{
	g_bClientAuthorized[client] = true;
}

public void OnClientDisconnect(int client)
{
	if (g_hTimer[client])
	{
		delete g_hTimer[client];
	}
	
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %N left the server while a cooldown was in effect following an admin rename. Cooldown removed.", LOGTAG);
	}
}

/*public Action OnClientCommands(int client, char[] command, int argc)
{
	char text[32];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	
	CheckCommands(client, text);
	return Plugin_Continue;
}*/

public void OnClientAuthorized(int client)
{
	//Let us grab the SteamID and the name of the connecting players and save them
	g_bClientAuthorized[client] = false; //Making sure they are fully authorized before letting them change their name (to avoid exploits in case of pending STEAM IDs)
	char id[32], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	GetClientName(client, name, sizeof(name));
	g_names.SetString(id, name);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s SetString has been executed successfully on %s.", LOGTAG, name);
	}
	
	g_iChangedMyName[client] = 0;
	g_iResetMyName[client] = 0;
	g_iResetToSteam[client] = 0;
	g_iCheckedOname[client] = 0;
	g_iCheckedSname[client] = 0;
	g_iWasRenamed[client] = 0;
	g_iCouldNotQuery[client] = 0;
	g_iWasForcedNamed[client] = 0;
}

public Action Command_NameAdmin(int client, int args) //Useful for non server operators aka server admins who would like similar access to sm cmds without the need of sm_rcon.
{
	char cmd[32];
	GetCmdArg(1, cmd, sizeof(cmd));
	
	if (!client)
	{
		PrintToServer("%s This command is intended for admins without SRCDS access to facilitate the listing of plugin commands. Use \"sm_name_version\", or the default Sourcemod commands instead.", TAG);
		return Plugin_Handled;
	}
	
	/*1 argument (nameadmin)*/
	
	if (!args)
	{
		ReplyToCommand(client, "%s Usage: nameadmin <command> [arguments]", TAG);
		ReplyToCommand(client, "Check your console for available commands.", CUSAGE);
		PrintToConsole(client, "Available commands are:\n cmd 				- Provide infomation on a cmd or provide a full list of public and admin commands.\n plugin				- Manage the plugin.\n player				- Player information\n cvar				- Manage the plugin's console variables.\n version			- Display version information.\n credits			- Display credits listing.");
		return Plugin_Handled;
	}
	
	/*2 arguments (nameadmin <command>)*/
	
	if (strcmp(cmd, "cmd") == 0)
	{
		char cmd2[32];
		GetCmdArg(2, cmd2, sizeof(cmd2));
		
		if (strcmp(cmd2, "list") == 0)
		{
			ReplyToCommand(client, "%s Check your console for details.", TAG);
			PrintToConsole(client, "%s Available admin commands are:\n 01. nameadmin\n 02. sm_name_ban\n 03. sm_namebanid\n 04. sm_name_reload\n 05. sm_name_unban\n 06. sm_name_unbanid\n 07. sm_rename\n\nAvailable public commands:\n 08. sm_name\n 09. sm_name_credits\n 10. sm_nhelp\n 11. sm_oname\n 12. sm_sname\n 13. sm_srname\n 14. sm_name_random\n 15. sm_name_force\n 16. sm_name_unforce", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "nameadmin") == 0 || (strcmp(cmd2, "01")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n nameadmin <command> [argument]\n Access to various plugin administration tools, such as viewing technical plugin information, statistics, restoring settings and more. Use with caution!", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_ban") == 0 || (strcmp(cmd2, "02")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_ban <name to ban (do not put white spaces anywhere)>\n Adds a name to the banned names list.\nNOTE: Admins are immune.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_namebanid") == 0 || (strcmp(cmd2, "03")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_banid <Steam ID to ban(Steam 2 ID format -- STEAM_)>\n Adds a Steam ID to the banned ID list.\nNOTE: Admins are immune.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_reload") == 0 || (strcmp(cmd2, "04")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_reload\n Reloads banned names and Steam IDs files.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_unban") == 0 || (strcmp(cmd2, "05")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_unban <name to ban (do not put white spaces anywhere)>\n Removes a name from the banned names list.\nNOTE: Admins are immune.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_unbanid") == 0 || (strcmp(cmd2, "06")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_unbanid <Steam ID to unban(Steam 2 ID format -- STEAM_)>\n Removes a Steam ID from the banned ID list.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_rename") == 0 || (strcmp(cmd2, "07")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_rename <#userid|name> <new name>\n Renames a player and applies a temporary name change cooldown.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name") == 0 || (strcmp(cmd2, "08")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name <new name> (leave blank to reset to the name set upon server connection).", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_credits") == 0 || (strcmp(cmd2, "09")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_credits\n Display plugin credits.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_nhelp") == 0 || (strcmp(cmd2, "10")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_nhelp\n Display public commands and usage to players.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_oname") == 0 || (strcmp(cmd2, "11")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_oname <#userid|name>\n Displays the name a user had upon server connection.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_sname") == 0 || (strcmp(cmd2, "12")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_sname <#userid|name>\n Displays the Steam name of a user.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_srname") == 0 || (strcmp(cmd2, "13")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_srname\n Restore a player's name to their Steam name.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_random") == 0 || (strcmp(cmd2, "14")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_random <#userid|name>\n Scrambles the player's name.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_force") == 0 || (strcmp(cmd2, "15")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_force <#userid|name> <new name>\n Forcibly set a name on a player without the possibility of changing it.", TAG);
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_unforce") == 0 || (strcmp(cmd2, "16")) == 0)
		{
			ReplyToCommand(client, "%s Check your console for details", TAG);
			PrintToConsole(client, "%s Command description:\n sm_name_force <#userid|name>\n Removes a forced locked name on a player.", TAG);
			return Plugin_Handled;
		}
		
		ReplyToCommand(client, "%s Usage: nameadmin cmd [arguments]", TAG);
		ReplyToCommand(client, "Check your console for available commands.");
		PrintToConsole(client, "Available commands are:\n list 		- Provide a full list of public and admin commands.\n <cmd name> 	- Provide information on a command.");
		return Plugin_Handled;
	}
	
	if (strcmp(cmd, "plugin") == 0)
	{
		if (args == 2)
		{
			/*3 arguments (nameadmin <command> [argument])*/
			char cmd2[32];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			
			if (strcmp(cmd2, "info") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Technical plugin information:\n Number of cvars: 17\n Number of admin cmds: 7\n Number of public cmds: 6\n Build: 1938\n Latest compile: 09/14/23", TAG);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "stats") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Plugin statistics:\n Number of names changed: %i\n Number of name resets: %i\n Number of Steam name resets: %i\n Number of original names fetched: %i\n Number of Steam names fetched: %i\n Number of admin renames: %i\n Number of forced names set: %i\n Number of failed Steam names fetches: %i\nStatistics printed on: %02d/%02d/%02d at %02d:%02d:%02d", TAG, g_iNameChangeTracker, g_iNameResetTracker, g_iSrnameTracker, g_iOnameTracker, g_iSnameTracker, g_iRenameTracker, g_iForcedNames, g_iSteamQueryFail, iMonth, iDay, iYear, iHour, iMinute, iSecond);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "reload") == 0)
			{
				ReplyToCommand(client, "%s Reloading plugin... please wait.", TAG);
				for (int i = 1; i <= MaxClients; i++)
				{
					g_bMapReloadClient[client] = true;
				}
				DataPack pack;
				g_hPluginReload[client] = CreateDataTimer(5.0, PluginReloadTimer, pack);
				pack.WriteCell(client);
				LogAction(client, -1, "%s %N has restarted the plugin through \"nameadmin plugin reload\".", TAG, client);
				char Message[128];
				Format(Message, sizeof(Message), "%s%s %s%N%s is restarting the plugin.", CTAG, TAG, CPLAYER, client, CUSAGE);
				PrintToAdmins(Message);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has restarted the plugin through \"nameadmin plugin reload\".", LOGTAG);
				}
				return Plugin_Handled;
			}
		}
		
		else if (args > 1)
		{
			char cmd2[32], cmd3[32];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			GetCmdArg(3, cmd3, sizeof(cmd3));
			
			if (strcmp(cmd2, "reload") == 0 && strcmp(cmd3, "map_reload") == 0)
			{
				ReplyToCommand(client, "%s Reloading plugin... please wait.", TAG);
				PrintToChatAll("%s An admin has reloaded the plugin. The current map will now be reloaded!", TAG);
				g_bMapReload = true;
				DataPack pack;
				g_hPluginReload[client] = CreateDataTimer(5.0, PluginReloadTimer, pack);
				pack.WriteCell(client);
				LogAction(client, -1, "%s %N has restarted the plugin through \"nameadmin plugin reload map_reload\".", TAG, client);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has restarted the plugin through \"nameadmin plugin reload map_reload\".", LOGTAG);
				}
				return Plugin_Handled;
			}
		}
		
		ReplyToCommand(client, "%s Usage: nameadmin plugin [arguments]", TAG);
		ReplyToCommand(client, "Check your console for available commands.");
		PrintToConsole(client, "Available commands are:\n reload [map_reload]	- Reloads the plugin. WARNING: Doing so will lose stored data in memory. Add \"map_reload\" to reload the current map to store players names upon server connection again.\n info			- Plugin information.\n stats			- Display plugin statistics");
		return Plugin_Handled;
	}
	
	if (strcmp(cmd, "player") == 0)
	{
		if (args == 2)
		{
			/*3 arguments (nameadmin <command> [argument])*/
			char cmd2[32];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			
			if (strcmp(cmd2, "status") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				char sName[MAX_NAME_LENGTH], id[32];
				int count = 0;
				bool bIdfound;
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i)/*&& !IsFakeClient(i)*/)
					{
						count++;
						GetClientName(i, sName, sizeof(sName));
						bIdfound = GetClientAuthId(i, AuthId_Steam2, id, sizeof(id));
						
						if (!bIdfound)
						{
							PrintToConsole(client, "%d. %s - UNVERIFIED STEAM ID", count, sName);
						}
						
						else
						{
							PrintToConsole(client, "%d. %s - %s", count, sName, id);
						}
					}
				}
				return Plugin_Handled;
			}
		}
		else if (args > 1)
		{
			char cmd2[32], cmd3[MAX_NAME_LENGTH];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			GetCmdArg(3, cmd3, sizeof(cmd3));
			
			if (strcmp(cmd2, "status") == 0 && strlen(cmd3) > 0)
			{
				int Target = FindTarget(client, cmd3, true, false);
				
				if (Target == -1)
				{
					return Plugin_Handled;
				}
				
				if (Target == 0 || IsFakeClient(Target))
				{
					ReplyToCommand(client, "%s This player is a bot or not a valid player.", TAG);
					return Plugin_Handled;
				}
				
				if (Target && g_iClients[Target] == GetClientUserId(Target))
				{
					char buffer[70], seconds = RoundToZero(GetClientTime(client));
					SecondsToTime(seconds, buffer);
					char targetname[MAX_TARGET_LENGTH], id[32];
					GetClientName(Target, targetname, sizeof(targetname));
					bool bIdfound = GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
					
					if (!bIdfound)
					{
						ReplyToCommand(client, "%s Check your console for details.", TAG);
						PrintToConsole(client, "%s Player status:\n Current name: %s\n SteamID: UNVERIFIED STEAM ID\n Name changes performed: %i\n Name resets performed: %i\n Steam name resets: %i\n Original name checks: %i\n Steam name checks: %i\n Number of admin renames: %i\n Failed query attempts: %i\n\nAdditional information:\n Player's name upon server connect was queried %i time%s.\n Player's Steam name was queried %i time%s.\n", TAG, targetname, g_iChangedMyName[Target], g_iResetMyName[Target], g_iResetToSteam[Target], g_iCheckedOname[Target], g_iCheckedSname[Target], g_iWasRenamed[Target], g_iCouldNotQuery[Target], g_iTargetWasOnameChecked[Target], g_iTargetWasOnameChecked[Target] <= 1 ? "" : "s", g_iTargetWasSteamChecked[Target], g_iTargetWasSteamChecked[Target] <= 1 ? "" : "s");
						PrintToConsole(client, "Warning! SteamID of %s could not be found. Name changes are not allowed for this player!", targetname);
					}
					
					else
					{
						ReplyToCommand(client, "%s Check your console for details.", TAG);
						PrintToConsole(client, "%s Player status:\n Current name: %s\n SteamID: %s\n Name changes performed: %i\n Name resets performed: %i\n Steam name resets: %i\n Original name checks: %i\n Steam name checks: %i\n Number of admin renames: %i\n Number of forced names set: %i\n Failed query attempts: %i\n\nAdditional information:\n Player's name upon server connect was queried %i time%s.\n Player's Steam name was queried %i time%s.\n", TAG, targetname, id, g_iChangedMyName[Target], g_iResetMyName[Target], g_iResetToSteam[Target], g_iCheckedOname[Target], g_iCheckedSname[Target], g_iWasRenamed[Target], g_iWasForcedNamed[Target], g_iCouldNotQuery[Target], g_iTargetWasOnameChecked[Target], g_iTargetWasOnameChecked[Target] <= 1 ? "" : "s", g_iTargetWasSteamChecked[Target], g_iTargetWasSteamChecked[Target] <= 1 ? "" : "s");
					}
					
					return Plugin_Handled;
				}
			}
		}
		ReplyToCommand(client, "%s Usage: nameadmin player [arguments]", TAG);
		ReplyToCommand(client, "Check your console for available commands.");
		PrintToConsole(client, "Available commands are: status [#userid|name]	- Acquire technical player information (leave blank after \"status\" to list all players).");
		return Plugin_Handled;
	}
	
	if (strcmp(cmd, "cvar") == 0)
	{
		if (args > 1)
		{
			/*3 arguments (nameadmin <command> [argument])*/
			char cmd2[32];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			
			if (strcmp(cmd2, "list") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s List of cvars:\n Number of cvars: 17\n 01. sm_name_ban_reason\n 02. sm_name_ban_time\n 03. sm_name_bannedids_checker\n 04. sm_name_bannednames_checker\n 05. sm_name_cooldown\n 06. sm_name_debug\n 07. sm_name_debug_snd\n 08. sm_name_debug_snd_on\n 09. sm_name_debug_snd_off\n 10. sm_name_enable\n 11. sm_cname_enable\n 12. sm_sname_enable\n 13. sm_oname_enable\n 14. sm_srname_enable\n 15. sm_name_help_enable\n 16. sm_name_version\n 17. sm_rename_cooldown", TAG);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_ban_reason") == 0 || strcmp(cmd2, "01") == 0)
			{
				char buffer[128];
				GetConVarString(changename_banreason, buffer, sizeof(buffer));
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_ban_reason: %s\n Sets the ban reason if a banned name is found in banned_names.ini", TAG, buffer);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_ban_time") == 0 || strcmp(cmd2, "02") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_ban_time: %i\n Sets the ban time when kicking a player if their name is found in banned_names.ini\n -2 -> Simply remove their name\n -1 -> Simply kick the player\n 0 and above -> Ban the player for this amount of time (0 = Permanent ban)\nNOTE: Admins are immune.", TAG, GetConVarInt(changename_bantime));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_bannedids_checker") == 0 || strcmp(cmd2, "03") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_bannedids_checker: %i\n Determines if banned players in banned_id.ini can change their name.", TAG, GetConVarBool(changename_checkbannedids));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_bannednames_checker") == 0 || strcmp(cmd2, "04") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_bannednames_checker: %i\n Determines if players can change their name to a banned names listed in banned_names.ini.", TAG, GetConVarBool(changename_checkbadnames));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_cooldown") == 0 || strcmp(cmd2, "05") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_cooldown: %i\n Determines how long a player has to wait before performing another name change.", TAG, GetConVarInt(changename_cooldown));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_debug") == 0 || strcmp(cmd2, "06") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_debug: %i\n Determines if debug mode is enabled and will log actions to a separate file. This mode is only available to admins with ROOT access.", TAG, GetConVarBool(changename_debug));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_debug_snd") == 0 || strcmp(cmd2, "07") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_debug_snd: %i\n Determines if debug sounds are turned on.", TAG, GetConVarBool(changename_debug_snd));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_debug_snd_off") == 0 || strcmp(cmd2, "09") == 0)
			{
				char buffer[128];
				GetConVarString(changename_debug_snd_warn_off, buffer, sizeof(buffer));
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_debug_snd_off: %s\n Determines what debug sound to use when debug mode is turned off.\n", TAG, buffer);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_debug_snd_on") == 0 || strcmp(cmd2, "08") == 0)
			{
				char buffer[128];
				GetConVarString(changename_debug_snd_warn_on, buffer, sizeof(buffer));
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_debug_snd_on: %s\n Determines what debug sound to use when debug mode is turned on.\n", TAG, buffer);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_enable") == 0 || strcmp(cmd2, "10") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_enable: %i\n Determines if the full plugin is enabled.", TAG, GetConVarBool(changename_enable_global));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_help_enable") == 0 || strcmp(cmd2, "15") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_help_enable: %i\n Determines if players are greeted with a message upon connection with available public commands.", TAG, GetConVarBool(changename_help));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_name_version") == 0 || strcmp(cmd2, "16") == 0 || strcmp(cmd2, "16") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_name_version: %s\n Prints plugin version.", TAG, PLUGIN_VERSION);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_oname_enable") == 0 || strcmp(cmd2, "13") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_oname_enable: %i\n Determines if fetching players names upon server connect is enabled.", TAG, GetConVarBool(originalname_enable));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_rename_cooldown") == 0 || strcmp(cmd2, "17") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_rename_cooldown: %i\n Determines how long a player has to wait before performing another name change after an admin renamed them.", TAG, GetConVarInt(changename_adminrename_cooldown));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_sname_enable") == 0 || strcmp(cmd2, "12") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_sname_enable: %i\n Determines if fetching players Steam names is enabled.", TAG, GetConVarBool(steamname_enable));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_srname_enable") == 0 || strcmp(cmd2, "14") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_srname_enable: %i\n Determines if a player can reset their name to their Steam name.", TAG, GetConVarBool(changename_steamreset));
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "sm_cname_enable") == 0 || strcmp(cmd2, "11") == 0)
			{
				ReplyToCommand(client, "%s Check your console for details.", TAG);
				PrintToConsole(client, "%s Command description:\n sm_cname_enable: %i\n Determines if players can change their name.", TAG, GetConVarBool(changename_enable));
				return Plugin_Handled;
			}
		}
		PrintToChat(client, "%s Usage: nameadmin cvar [arguments]", TAG);
		PrintToChat(client, "Check your console for available commands.");
		PrintToConsole(client, "Available commands are:\n list 		- Provide a full list of cvars.\n <cvar name>	- Provide information on a cvar.");
		return Plugin_Handled;
	}
	
	else if (strcmp(cmd, "credits") == 0)
	{
		ReplyToCommand(client, "%s Check your console for credits listing.", TAG);
		PrintToConsole(client, "\"Set My name\" was developed by Peter Brev.\nThanks to the following people that made this plugin possible:\n Harper			- 	For providing the base code that allowed players to change their name.\n eyal282		-	For providing feedback and exposing plugin's issues.\n Grey83			-	For providing help and re-writing the entire plugin in a much more professional code.\n Humam			-	For providing testing and providing feedback.\n Alienmario		-	For providing testing and providing feedback.\n Alliedmodders		-	For providing Sourcemod and the tools to create plugins.");
		return Plugin_Handled;
	}
	
	else if (strcmp(cmd, "version") == 0)
	{
		ReplyToCommand(client, "%s Check your console for version information.", TAG);
		PrintToConsole(client, "\"Set My name\" version information:\n Version: 1.7.0.1938\n Compiled for Sourcemod 1.11.0.6936 and later\n Your current version of Sourcemod is: %s", SOURCEMOD_VERSION);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "%s Usage: nameadmin <command> [arguments]", TAG);
	ReplyToCommand(client, "Check your console for available commands.");
	PrintToConsole(client, "Available commands are:\n cmd 				- Provide infomation on a cmd or provide a full list of public and admin commands.\n plugin				- Manage the plugin.\n player				- Player information\n cvar				- Manage the plugin's console variables.\n version			- Display version information.\n credits			- Display credits listing.");
	return Plugin_Handled;
}

void SecondsToTime(int seconds, char buffer[70])
{
	int days, hour, mins, secs;
	if (seconds >= 86400)
	{
		days = RoundToFloor(float(seconds / 86400));
		seconds = seconds % 86400;
	}
	if (seconds >= 3600)
	{
		hour = RoundToFloor(float(seconds / 3600));
		seconds = seconds % 3600;
	}
	if (seconds >= 60)
	{
		mins = RoundToFloor(float(seconds / 60));
		seconds = seconds % 60;
	}
	secs = RoundToFloor(float(seconds));
	
	if (days)
		Format(buffer, 70, "%s%d days, ", buffer, days);
	if (hour)
		Format(buffer, 70, "%s%d hours, ", buffer, hour);
	Format(buffer, 70, "%s%d mins, ", buffer, mins);
	Format(buffer, 70, "%s%d secs", buffer, secs);
}

public Action PluginReloadTimer(Handle timer, DataPack pack)
{
	pack.Reset();
	
	if (g_bMapReload)
	{
		char map[64];
		GetCurrentMap(map, sizeof(map));
		ForceChangeLevel(map, "Plugin restart by admin [nameadmin plugin reload map_reload]");
		return Plugin_Stop;
	}
	
	else
	{
		ServerCommand("sm plugins reload name.smx");
		char Message[128];
		Format(Message, sizeof(Message), "%s%s %sPlugin has been reloaded.", CTAG, TAG, CUSAGE);
		PrintToAdmins(Message);
		return Plugin_Stop;
	}
}

public Action Command_NameBan(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	if (args < 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_ban <name to ban (NO SPACES)>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	if (args > 1)
	{
		PrintToChat(client, "%s%s %sOnly use one word with no spaces.", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32];
	
	GetCmdArgString(arg1, sizeof(arg1));
	
	StripQuotes(arg1);
	TrimString(arg1);
	
	if (args == 1)
	{
		Handle nfile = OpenFile(fileName, "a+");
		for (int i = 0; i < lines; i++)
		{
			if (StrContains(arg1, BadNames[i], false) != -1)
			{
				PrintToChat(client, "%s%s %sThis name is already banned.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
		}
		WriteFileLine(nfile, arg1);
		PrintToChat(client, "%s%s %sThis name has been added to the banned names list.", CTAG, TAG, CUSAGE);
		parseList_Name(false);
		CloseHandle(nfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s has been banned from being used in names.", LOGTAG, arg1);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_SteamidBan(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_banid <SteamID to ban>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32];
	
	GetCmdArgString(arg1, sizeof(arg1));
	
	StripQuotes(arg1);
	TrimString(arg1);
	
	if (StrContains(arg1, "STEAM_", false) == -1)
	{
		PrintToChat(client, "%s%s %sThis is not a Steam 2 ID (STEAM_0:X:XXXX).", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < bannedlines; i++)
	{
		if (StrEqual(arg1, bannedsteamids[i], false))
		{
			PrintToChat(client, "%s%s %sThis SteamID is already banned.", CTAG, TAG, CUSAGE);
			return Plugin_Handled;
		}
	}
	
	Handle nfile = OpenFile(bannedidfile, "a+");
	WriteFileLine(nfile, arg1);
	PrintToChat(client, "%s%s %s%s %shas been added to the banned SteamIDs list.", CTAG, TAG, CPLAYER, arg1, CUSAGE);
	parseList_id(false);
	CloseHandle(nfile);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %s has been banned from changing names.", LOGTAG, arg1);
	}
	
	return Plugin_Handled;
}

public Action Command_SteamidUnban(int client, int args)
{
	File nfile = OpenFile(bannedidfile, "a+");
	
	if (nfile == null)
	{
		LogError("%s Could not open banned_id.ini", TAG);
		PrintToChat(client, "%s%s %sCould not open banned_id.ini", CTAG, TAG, CERROR);
	}
	
	if (client == 0)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_unbanid <SteamID to unban (NO SPACES)>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32];
	
	GetCmdArgString(arg2, sizeof(arg2));
	
	StripQuotes(arg2);
	TrimString(arg2);
	
	bool found = false;
	ArrayList fileArray = CreateArray(32);
	
	while (!nfile.EndOfFile() && nfile.ReadLine(arg1, sizeof(arg1)))
	{
		if (strlen(arg1) < 1 || IsCharSpace(arg1[0]))continue;
		ReplaceString(arg1, sizeof(arg1), "\n", "", false);
		if (!StrEqual(arg1, arg2, false))
		{
			fileArray.PushString(arg1);
		}
		else
		{
			found = true;
		}
	}
	
	delete nfile;
	
	if (found)
	{
		DeleteFile(bannedidfile);
		File newFile = OpenFile(bannedidfile, "a+");
		
		if (newFile == null)
		{
			LogError("%s Could not open banned_id.ini", TAG);
			PrintToChat(client, "%s%s %sCould not open banned_id.ini", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
		
		PrintToChat(client, "%s%s %s%s %shas been removed from the banned SteamIDs list.", CTAG, TAG, CPLAYER, arg2, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s removed from banned SteamIDs list.", TAG, arg2);
		}
		
		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s added to the list.", TAG, writeLine);
			}
		}
		
		delete newFile;
		delete fileArray;
		parseList_id(false);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "%s%s %sThis SteamID could not be found.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
}

public Action Command_NameUnban(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game", TAG);
		return Plugin_Handled;
	}
	File nfile = OpenFile(fileName, "a+");
	
	if (nfile == null)
	{
		LogError("%s Could not open banned_names.ini", TAG);
		PrintToChat(client, "%s%s %sCould not open banned_names.ini", CTAG, TAG, CERROR);
	}
	
	if (args == 0)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_unban <name to unban (NO SPACES)>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32];
	
	GetCmdArgString(arg2, sizeof(arg2));
	
	StripQuotes(arg2);
	TrimString(arg2);
	
	bool found = false;
	ArrayList fileArray = CreateArray(32);
	
	while (!nfile.EndOfFile() && nfile.ReadLine(arg1, sizeof(arg1)))
	{
		if (strlen(arg1) < 1 || IsCharSpace(arg1[0]))continue;
		ReplaceString(arg1, sizeof(arg1), "\n", "", false);
		if (!StrEqual(arg1, arg2, false))
		{
			fileArray.PushString(arg1);
		}
		else
		{
			found = true;
		}
	}
	
	delete nfile;
	
	if (found)
	{
		DeleteFile(fileName);
		File newFile = OpenFile(fileName, "a+");
		
		if (newFile == null)
		{
			LogError("%s Could not open banned_names.ini", TAG);
			PrintToChat(client, "%s%s %sCould not open banned_names.ini", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
		
		PrintToChat(client, "%s%s %s%s %shas been removed from the banned name list.", CTAG, TAG, CPLAYER, arg2, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s removed from banned names list.", TAG, arg2);
		}
		
		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s removed from banned names list.", TAG, arg2);
			}
		}
		
		delete newFile;
		delete fileArray;
		parseList_Name(false);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "%s%s %sThe name could not be found.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
}
public Action Command_FilesRefresh(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Files have been refreshed.", LOGTAG);
		}
		return Plugin_Handled;
	}
	PrintToChat(client, "%s%s %sFiles have been refreshed.", CTAG, TAG, CUSAGE);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %N refreshed the files.", LOGTAG, client);
	}
	parseList_Name(true, client);
	parseList_id(true, client);
	OnMapStart();
	return Plugin_Handled;
}

public Action Command_Credits(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s \"Set My Name\" created by Peter Brev. Special thanks to harper, eyal282 and Grey83.", TAG);
	}
	
	if (!args || args > 0)
	{
		PrintToChat(client, "%s%s %s\"Set My Name\" %screated by %sPeter Brev. %sSpecial thanks to %sharper%s, %seyal282 %sand %sGrey83%s.", CTAG, TAG, CPLAYER, CUSAGE, CPLAYER, CUSAGE, CPLAYER, CUSAGE, CPLAYER, CUSAGE, CPLAYER, CUSAGE);
	}
	return Plugin_Handled;
}

public Action Command_Hname(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game", TAG);
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		PrintToChat(client, "%s%s %sPlease see the console for available commands.", CTAG, TAG, CUSAGE);
		PrintToConsole(client, "%s Available commands are:\nsm_name <new name> || Leave blank - Change your name or if no name is specified, it will revert to the name you had when joining\nsm_oname <#userid|name> - Shows the join name of a user\nsm_sname <#userid|name> - Shows the Steam name of a user\nsm_srname - Reset your name to your Steam name\nNOTE: Not all commands may be available. It is up to the server operator to decide what you have access to", TAG);
	}
	return Plugin_Handled;
}

public Action Command_Rename(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game", TAG);
		return Plugin_Handled;
	}
	
	if (args < 2)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_rename <#userid|name> <new name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	
	// If we are only going to allow one player to be renamed at a time, using ProcessTargetString might be useless. Oh well...
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
				arg, 
				client, 
				target_list, 
				MAXPLAYERS, 
				COMMAND_TARGET_NONE, 
				target_name, 
				sizeof(target_name), 
				tn_is_ml)) > 0)
	{
		
		for (int i = 0; i < target_count; i++)
		{
			if (target_count > 1)
			{
				PrintToChat(client, "%s%s %sOnly one player can be renamed at a time.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			
			if (IsFakeClient(target_list[i]))
			{
				PrintToChat(client, "%s%s %sYou cannot target a bot.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			
			if (g_bForcedName[target_list[i]])
			{
				PrintToChat(client, "%s%s %sA forced locked name is in effect on %s%s%s. Remove it first before attempting to rename this player.", CTAG, TAG, CUSAGE, CPLAYER, target_name, CUSAGE);
				return Plugin_Handled;
			}
			
			if (g_bAdminRenamed[target_list[i]])
			{
				PrintToChat(client, "%s%s %s%s %swas recently renamed and is under cooldown. You must wait until the cooldown is over to rename this player again.", CTAG, TAG, CPLAYER, target_name, CUSAGE);
				return Plugin_Handled;
			}
			
			if (CheckCommandAccess(target_list[i], "sm_kick", ADMFLAG_GENERIC, false))
			{
				PrintToChat(client, "%s%s %sYou cannot target an admin.", CTAG, TAG, CUSAGE);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N attempted to rename an admin.", LOGTAG, client);
				}
				return Plugin_Handled;
			}
			
			if (GetConVarBool(changename_checkbadnames))
			{
				for (int x = 0; x < lines; x++)
				{
					if (StrContains(arg2, BadNames[x], false) != -1)
					{
						PrintToChat(client, "%s%s %sCannot rename player because %s%s %sis a banned name.", CTAG, TAG, CUSAGE, CPLAYER, arg2, CUSAGE);
						return Plugin_Handled;
					}
				}
			}
			
			PrintToChatAll("%s%s %s%s %shas been renamed by an admin to %s%s%s.", CTAG, TAG, CPLAYER, target_name, CUSAGE, CPLAYER, arg2, CUSAGE);
			Format(g_targetnewname[target_list[i]], MAX_NAME_LENGTH, "%s", arg2);
			RenamePlayer(target_list[i]);
			g_bAdminRenamed[target_list[i]] = true;
			g_iRenameTracker++;
			g_iWasRenamed[target_list[i]]++;
			
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s has been renamed by %s to %s.", LOGTAG, target_name, client, arg2);
			}
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	
	return Plugin_Handled;
}

void RenamePlayer(int target)
{
	SetClientName(target, g_targetnewname[target]);
	g_targetnewname[target][0] = '\0';
	
	/*I probably should have created a function for the cooldown function*/
	int timeleft = GetConVarInt(changename_adminrename_cooldown);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
		PrintToChat(target, "%s%s %sAn admin has renamed you. You have been temporarily banned from changing names for %s%d:%02d%s.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
		CheckTimer(target);
	}
	
	Handle DP = CreateDataPack();
	WritePackCell(DP, GetClientUserId(target));
	g_hTimer[target] = CreateTimer(GetConVarFloat(changename_adminrename_cooldown), name_temp_ban, DP);
	
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %s temporarily banned from changing names.", LOGTAG, target);
	}
	return;
}

public Action name_temp_ban(Handle timer, any DP)
{
	ResetPack(DP);
	
	int target = GetClientOfUserId(ReadPackCell(DP));
	
	CloseHandle(DP);
	
	if (!target)
	{
		PrintToServer("%s The target was not found.", TAG);
		return Plugin_Stop;
	}
	
	g_bAdminRenamed[target] = false;
	g_hTimer[target] = null;
	return Plugin_Stop;
}

public Action Command_RenameRandom(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (!args || args > 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_random <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
				arg, 
				client, 
				target_list, 
				MAXPLAYERS, 
				COMMAND_TARGET_NONE, 
				target_name, 
				sizeof(target_name), 
				tn_is_ml)) > 0)
	{
		
		for (int i = 0; i < target_count; i++)
		{
			if (target_count > 1)
			{
				PrintToChat(client, "%s%s %sOnly one player can be renamed at a time.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			
			if (IsFakeClient(target_list[i]))
			{
				PrintToChat(client, "%s%s %sYou cannot target a bot.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			
			if (g_bForcedName[target_list[i]])
			{
				PrintToChat(client, "%s%s %sA forced locked name is in effect on %s%s%s. Remove it first before attempting to rename this player.", CTAG, TAG, CUSAGE, CPLAYER, target_name, CUSAGE);
				return Plugin_Handled;
			}
			
			if (g_bAdminRenamed[target_list[i]])
			{
				PrintToChat(client, "%s%s %s%s %swas recently renamed and is under cooldown. You must wait until the cooldown is over to rename this player again.", CTAG, TAG, CPLAYER, target_name, CUSAGE);
				return Plugin_Handled;
			}
			
			if (CheckCommandAccess(target_list[i], "sm_kick", ADMFLAG_GENERIC, false))
			{
				PrintToChat(client, "%s%s %sYou cannot target an admin.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			PerformRandomizedName(target_list[i]);
			PrintToChat(client, "%s%s %sPlayer renamed.", CTAG, TAG, CUSAGE);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s name randomized.", LOGTAG, target_list[i]);
			}
			g_iRenameTracker++;
			g_iWasRenamed[target_list[i]]++;
		}
	}
	return Plugin_Handled;
}

void PerformRandomizedName(int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	
	int len = strlen(name);
	g_targetnewname[target][0] = '\0';
	
	for (int i = 0; i < len; i++)
	{
		g_targetnewname[target][i] = name[GetRandomInt(0, len - 1)];
	}
	g_targetnewname[target][len] = '\0';
	SetClientName(target, g_targetnewname[target]);
	PrintToChat(target, "%s%s %sYour name was scrambled by an admin.", CTAG, TAG, CUSAGE);
	PrintToChatAll("%s%s %s%s %shas had their name destroyed to %s%s%s.", CTAG, TAG, CPLAYER, name, CUSAGE, CPLAYER, g_targetnewname[target], CUSAGE);
	g_iWasRenamed[target]++;
}

public Action Command_Oname(int client, int args)
{
	//Check whether the plugin is enabled
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(originalname_enable))
		{
			//I have no idea why this is here (this was from the first 2018 release)
		} else
		{
			if (client == 0)
			{
				PrintToServer("%s Fetching original names has been disabled.", TAG);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Fetching original disabled due to ConVar \"sm_oname\" being set to 0.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch an original name but ability is disabled.", LOGTAG, client);
				}
				return Plugin_Handled;
			} else {
				ReplyToCommand(client, "%s%s %sFetching original names has been disabled by an administrator.", CTAG, TAG, CERROR);
				return Plugin_Handled;
			}
		}
	} else
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled.", TAG);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted to fetch an original name but plugin is disabled.", LOGTAG, client);
			}
			return Plugin_Handled;
		} else {
			ReplyToCommand(client, "%s%s %sThis plugin is currently disabled.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted to fetch an original name but plugin is disabled.", LOGTAG, client);
			}
			return Plugin_Handled;
		}
	}
	//Just provide the command usage
	
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (g_bClientAuthorized[client]) //Hopefully, this does not cause issues in the long run
	{
		PrintToChat(client, "%s%s %sYour SteamID was not verified yet. Please wait before trying to fetch a player's name.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N SteamID not verified. Attempted to fetch another player's join name.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		//Oname usage
		PrintToChat(client, "%s%s %sUsage: %ssm_oname <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	if (g_bMapReloadClient[client])
	{
		PrintToChat(client, "%s%s %sYou cannot fetch another player's name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to fetch a player's join name pending plugin restart.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bMapReload)
	{
		PrintToChat(client, "%s%s %sYou cannot fetch another player's name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to fetch a player's join name pending plugin restart.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	char arg1[64];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int Target = FindTarget(client, arg1, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled; //If the client is not found, go ahead and return an error
	}
	
	char targetname[MAX_TARGET_LENGTH], buffer[MAX_NAME_LENGTH], id[32];
	
	GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
	g_names.GetString(id, buffer, sizeof(buffer));
	
	if (StrEqual(buffer, ""))
	{
		PrintToChat(client, "%s%s %sCould not find the player's' original name (name was not stored in memory).", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to fetch %s's name that was not stored in memory (was there a plugin restart?).", LOGTAG, client, Target);
		}
		return Plugin_Handled;
	}
	
	GetClientName(Target, targetname, sizeof(targetname));
	g_iOnameTracker++;
	g_iCheckedOname[client]++;
	g_iTargetWasOnameChecked[Target]++;
	
	if (strcmp(targetname, buffer)) //We are now going to check whether the name == Original name upon connection
	{
		//Show orginal name if name was changed
		PrintToChat(client, "%s%s %sJoin name of %s%s %sis %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, targetname, CUSAGE, CPLAYER, buffer, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Showing join name of %s (%s).", LOGTAG, targetname, buffer);
			LogToFile(LOGPATH, "%s %N executed sm_oname on %s (Join name: %s).", LOGTAG, client, targetname, buffer);
		}
	} else {
		//Name was not changed, then it must be their original name
		PrintToChat(client, "%s%s %s%s %sis the name they had when joining the server.", CTAG, TAG, CPLAYER, targetname, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s is the name they had when they joined the server.", LOGTAG, targetname);
			LogToFile(LOGPATH, "%s %N executed sm_oname on %s but is their original name.", LOGTAG, client, targetname);
		}
	}
	return Plugin_Handled;
}
public void CheckTimer(int client)
{
	int iNow = GetTime(), iCooldown = GetConVarInt(changename_adminrename_cooldown);
	
	if (iCooldown > 0)
	{
		int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
		int mins, secs;
		if (iTimeLeft > 0)
		{
			mins = iTimeLeft / 60;
			secs = iTimeLeft % 60;
			//char timeleftbuffer[128];
			PrintToChat(client, "%s%s %sAn admin recently renamed you. You will only be able to change your name in %s%d:%02d%s.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
			return;
		}
	}
	
	g_iLastUsed[client] = iNow;
	
}

public Action Command_NameForce(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (args < 2)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_force <#userid|name> <name to force>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
				arg, 
				client, 
				target_list, 
				MAXPLAYERS, 
				COMMAND_TARGET_NONE, 
				target_name, 
				sizeof(target_name), 
				tn_is_ml)) > 0)
	{
		
		for (int i = 0; i < target_count; i++)
		{
			if (target_count > 1)
			{
				PrintToChat(client, "%s%s %sOnly one player can be renamed at a time.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			
			if (IsFakeClient(target_list[i]))
			{
				PrintToChat(client, "%s%s %sYou cannot target a bot.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			
			if (CheckCommandAccess(target_list[i], "sm_kick", ADMFLAG_GENERIC, false))
			{
				PrintToChat(client, "%s%s %sYou cannot target an admin.", CTAG, TAG, CUSAGE);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N attempted to rename an admin.", LOGTAG, client);
				}
				return Plugin_Handled;
			}
			
			if (g_bAdminRenamed[target_list[i]])
			{
				PrintToChat(client, "%s%s %s%s %swas recently renamed and is under cooldown. You must wait until the cooldown is over to rename this player again.", CTAG, TAG, CPLAYER, target_name, CUSAGE);
				return Plugin_Handled;
			}
			
			if (GetConVarBool(changename_checkbadnames))
			{
				for (int x = 0; x < lines; x++)
				{
					if (StrContains(arg2, BadNames[x], false) != -1)
					{
						PrintToChat(client, "%s%s %sCannot rename player because %s%s %sis a banned name.", CTAG, TAG, CUSAGE, CPLAYER, arg2, CUSAGE);
						return Plugin_Handled;
					}
				}
			}
			
			Format(g_targetnewname[target_list[i]], MAX_NAME_LENGTH, "%s", arg2);
			PrintToChat(client, "%s%s %sForced locked name %s%s %son %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, arg2, CUSAGE, CPLAYER, target_name, CUSAGE);
			ForceRenamePlayer(target_list[i]);
			g_iWasForcedNamed[target_list[i]]++;
			g_iForcedNames++;
			
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s has been forced locked renamed by %N to %s.", LOGTAG, target_name, client, arg2);
			}
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	
	return Plugin_Handled;
}

void ForceRenamePlayer(int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	if (strcmp(name, g_targetnewname[target]) == 0)
	{
		PrintToChat(target, "%s%s %sYour name has been forced locked. You can no longer change your name.", CTAG, TAG, CUSAGE);
		g_bForcedName[target] = true;
		DataPack pack;
		g_hForceLockSteamCheck[target] = CreateDataTimer(5.0, NoSteamNameChange, pack, TIMER_REPEAT);
		pack.WriteCell(target);
		pack.WriteString(name);
		
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s name forced locked.", LOGTAG, target);
		}
		return;
	}
	else
	{
		SetClientName(target, g_targetnewname[target]);
		PrintToChat(target, "%s%s %sYou have been forced locked the name %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, g_targetnewname[target], CUSAGE);
		DataPack pack;
		g_hForceLockSteamCheck[target] = CreateDataTimer(5.0, NoSteamNameChange, pack, TIMER_REPEAT);
		pack.WriteCell(target);
		pack.WriteString(name);
		g_bForcedName[target] = true;
		
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s name forced locked to %s.", LOGTAG, target, g_targetnewname[target]);
		}
		return;
	}
}

public Action NoSteamNameChange(Handle timer, DataPack pack)
{
	char name[MAX_NAME_LENGTH];
	int target;
	
	pack.Reset();
	target = pack.ReadCell();
	pack.ReadString(name, sizeof(name));
	if (!g_bForcedName[target])
	{
		g_hForceLockSteamCheck[target] = null;
		return Plugin_Stop;
	}
	
	char currentname[MAX_NAME_LENGTH];
	GetClientName(target, currentname, sizeof(currentname));
	if (strcmp(currentname, g_targetnewname[target]))
	{
		SetClientName(target, g_targetnewname[target]);
		PrintToChat(target, "%s%s %sDue to an active name force-lock, your Steam name change has been ignored on this server.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s attempted to change their name through Steam.", LOGTAG, target);
		}
	}
	
	return Plugin_Continue;
}

public Action Command_NameUnforce(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (!args)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_unforce <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char Argument[65];
	GetCmdArgString(Argument, sizeof(Argument));
	
	int Target = FindTarget(client, Argument, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled;
	}
	
	if (Target == 0 || IsFakeClient(Target)) // I think using this is useless as Sourcemod takes over if target is invalid or a bot.
	{
		ReplyToCommand(client, "%s This player is a bot or not a valid player.", TAG);
		return Plugin_Handled;
	}
	
	char targetname[MAX_NAME_LENGTH];
	GetClientName(Target, targetname, sizeof(targetname));
	
	if (g_bForcedName[Target] == false)
	{
		PrintToChat(client, "%s%s %sNo forced locked name active on %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, targetname, CUSAGE);
		return Plugin_Handled;
	}
	
	g_bForcedName[Target] = false;
	PrintToChat(client, "%s%s %sForced locked name removed on %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, targetname, CUSAGE);
	PrintToChat(Target, "%s%s %sForced locked name lifted. Ability to change name restored.", CTAG, TAG, CUSAGE);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s Forced locked name on %s lifted.", LOGTAG, Target);
	}
	return Plugin_Handled;
}

public Action Command_Name(int client, int args)
{
	if (g_bMapReloadClient[client])
	{
		PrintToChat(client, "%s%s %sYou cannot change your name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to change their name pending plugin restart.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bMapReload)
	{
		PrintToChat(client, "%s%s %sYou cannot change your name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N attempted to change their name pending plugin restart.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bClientAuthorized[client])
	{
		PrintToChat(client, "%s%s %sYour SteamID was not verified yet. Please wait before trying to change your name.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N SteamID not verified. Attempted to change their name.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bForcedName[client])
	{
		PrintToChat(client, "%s%s %sYour name is being forced locked. You cannot change your name.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N name is forced locked, but still tried to change their name.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (g_bAdminRenamed[client])
	{
		CheckTimer(client);
		return Plugin_Handled;
	}
	
	bool gag = BaseComm_IsClientGagged(client);
	
	if (gag)
	{
		PrintToChat(client, "%s%s %sYou are gagged and cannot change your name right now.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
	
	//Check whether the plugin is enabled
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_enable))
		{
			//Again, probably did this while I was still learning Sourcemod. If update, switch this code block to if (!GetConVarBool(changename_enable))
		} else
		{
			if (client == 0)
			{
				PrintToServer("%s Name changing has been disabled by an administrator.", TAG);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Name change disabled due to ConVar \"sm_cname_enable\" being set to 0.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted a name change but ability is disabled.", LOGTAG, client);
				}
				return Plugin_Handled;
			} else {
				ReplyToCommand(client, "%s%s %sName changing has been disabled by an administrator.", CTAG, TAG, CERROR);
				return Plugin_Handled;
			}
		}
	} else
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled.", TAG);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted a name change but plugin is disabled.", LOGTAG, client);
			}
			return Plugin_Handled;
		} else
		{
			ReplyToCommand(client, "%s%s %sThis plugin is currently disabled.", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
	}
	
	//Let us just make sure to let the server operators know this is an in-game only command
	if (client == 0)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	//With the saved player information, let us prepare the reset name stage
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if (args == 0)
	{
		char id[32], buffer[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
		
		bool bFound = GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
		
		if (!bFound)
		{
			PrintToChat(client, "%s%s %sYour SteamID was not authorized yet. You cannot change your name.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %N does not have a verified SteamID, yet attempted to reset their name.", LOGTAG, client);
			}
			return Plugin_Handled;
		}
		
		g_names.GetString(id, buffer, sizeof(buffer));
		
		if (StrEqual(buffer, ""))
		{
			PrintToChat(client, "%s%s %sCould not restore your original name (name was not stored in memory).", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %N attempted to reset their name, but their join name was not saved (was there a plugin restart?).", LOGTAG, client);
			}
			return Plugin_Handled;
		}
		
		GetClientName(client, currentname, sizeof(currentname));
		
		if (strcmp(buffer, currentname, false))
		{
			if (GetConVarBool(changename_checkbadnames))
			{
				if (!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
				{
					for (int x = 0; x < lines; x++)
					{
						if (StrContains(buffer, BadNames[x], false) != -1)
						{
							char bantime = GetConVarInt(changename_bantime);
							
							if (bantime == -2)
							{
								PrintToChat(client, "%s%s %sYou cannot restore your name, because it is banned.", CTAG, TAG, CUSAGE);
								
								if (GetConVarBool(changename_debug))
								{
									LogToFile(LOGPATH, "%s %s attempted to change their name to a banned name.", LOGTAG, client);
								}
								return Plugin_Handled;
							}
						}
					}
				}
			}
			
			int iNow = GetTime(), iCooldown = GetConVarInt(changename_cooldown);
			
			if (iCooldown > 0)
			{
				int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
				int mins, secs;
				if (iTimeLeft > 0)
				{
					mins = iTimeLeft / 60;
					secs = iTimeLeft % 60;
					//char timeleftbuffer[128];
					PrintToChat(client, "%s%s %sYou must wait %s%d:%02d %sbefore changing your name again.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
					return Plugin_Handled;
				}
			}
			
			g_iLastUsed[client] = iNow;
			
			g_iNameResetTracker++;
			g_iResetMyName[client]++;
			
			SetClientName(client, buffer);
			
			//He reset his name
			PrintToChatAll("%s%s %s%s %shas reset their name to %s%s.", CTAG, TAG, CPLAYER, currentname, CUSAGE, CPLAYER, buffer);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Player %s has reset their name to %s", LOGTAG, currentname, buffer);
			}
		}
		else
		{
			//Or the name is already set to original name
			PrintToChat(client, "%s%s %sYour name is already set to %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, currentname, CUSAGE);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Player %s has not changed their name from their original one (name on connection) but has still attempted to reset their name to the one they had on server connection.", LOGTAG, currentname);
			}
		}
		return Plugin_Handled;
	}
	
	if (args > 0)
	{
		char sName[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH], steamid[32];
		
		GetClientName(client, currentname, sizeof(currentname));
		
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		
		GetCmdArgString(sName, sizeof(sName));
		
		/*if (StrContains(sName, "@", false) == -1 || StrContains(sName, "/", false) == -1)
		{
			PrintToChat(client, "%s%s %sYou have used an illegal character.", CTAG, TAG, CUSAGE);
			return Plugin_Handled;
		}*/
		
		if (strcmp(sName, currentname))
		{
			if (GetConVarBool(changename_checkbadnames))
			{
				if (!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
				{
					for (int i = 0; i < lines; i++)
					{
						if (StrContains(sName, BadNames[i], false) != -1)
						{
							char bantime = GetConVarInt(changename_bantime);
							
							if (bantime == -2)
							{
								PrintToChat(client, "%s%s %sThis name is banned from being used.", CTAG, TAG, CUSAGE);
								
								if (GetConVarBool(changename_debug))
								{
									LogToFile(LOGPATH, "%s %s attempted to change their name to a banned name.", LOGTAG, client);
								}
								return Plugin_Handled;
							}
						}
						
					}
				}
			}
			if (!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
			{
				for (int y = 0; y < bannedlines; y++)
				{
					if (StrContains(steamid, bannedsteamids[y], false) != -1)
					{
						char bantime = GetConVarInt(changename_bantime);
						if (GetConVarBool(changename_checkbannedids))
						{
							if (bantime == -2)
							{
								PrintToChat(client, "%s%s %sYou cannot change your name due to an active name ban.", CTAG, TAG, CERROR);
								if (GetConVarBool(changename_debug))
								{
									LogToFile(LOGPATH, "%s %s attempted to change their name, but their Steam ID is banned from doing so.", LOGTAG, client);
								}
								return Plugin_Handled;
							}
						}
					}
				}
			}
			
			int iNow = GetTime(), iCooldown = GetConVarInt(changename_cooldown);
			
			if (iCooldown > 0)
			{
				int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
				int mins, secs;
				if (iTimeLeft > 0)
				{
					mins = iTimeLeft / 60;
					secs = iTimeLeft % 60;
					//char timeleftbuffer[128];
					PrintToChat(client, "%s%s %sYou must wait %s%d:%02d %sbefore changing your name again.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
					return Plugin_Handled;
				}
			}
			
			g_iLastUsed[client] = iNow;
			
			//He changed his name
			g_iNameChangeTracker++;
			g_iChangedMyName[client]++;
			Handle DP = CreateDataPack();
			
			RequestFrame(TwoTotalFrames, DP); // Probably could use a timer like Grey did in the plugin re-write instead of this "Request frame" thing. Doing this to get around a bug with chat processors where names would get stripped of their team color
			WritePackCell(DP, GetClientUserId(client));
			WritePackString(DP, sName);
		}
		else
		{
			//Name already set to the one he wants to set it to?
			PrintToChat(client, "%s%s %sYour name is already set to %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, currentname, CUSAGE);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s has initiated an sm_name usage using a name that was already identical to the one they have.", LOGTAG, currentname);
			}
		}
		
	}
	
	return Plugin_Handled;
}

void TwoTotalFrames(Handle DP)
{
	RequestFrame(ChangeName, DP); //Request a second frame. Could really have done with a timer :/
}

void ChangeName(Handle DP)
{
	ResetPack(DP);
	
	int client = GetClientOfUserId(ReadPackCell(DP));
	
	if (client <= 0 || client > MaxClients)
		return;
	
	else if (!IsClientInGame(client))
		return;
	
	char currentname[MAX_NAME_LENGTH];
	GetClientName(client, currentname, sizeof(currentname));
	char NewName[64];
	ReadPackString(DP, NewName, sizeof(NewName));
	CloseHandle(DP);
	SetClientInfo(client, "name", NewName);
	PrintToChatAll("%s%s %s%s %shas changed their name to %s%s%s.", CTAG, TAG, CPLAYER, currentname, CUSAGE, CPLAYER, NewName, CUSAGE);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %s has changed their name to %s.", LOGTAG, currentname, NewName);
	}
	return;
}

public Action Command_Sname(int client, int args)
{
	
	if (g_bClientAuthorized[client])
	{
		PrintToChat(client, "%s%s %sYour SteamID was not verified yet. Please wait before trying to fetch a player's name.", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %N SteamID not verified. Attempted to fetch another player's Steam name.", LOGTAG, client);
		}
		return Plugin_Handled;
	}
	
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(steamname_enable))
		{
			
		} else
		{
			if (client == 0)
			{
				PrintToServer("%s Fetching Steam names has been disabled by an administrator.", TAG);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Fetching Steam name disabled due to ConVar \"sm_sname_enable\" being set to 0.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch a Steam name but ability is disabled.", LOGTAG, client);
				}
				return Plugin_Handled;
			} else {
				ReplyToCommand(client, "%s%s %sFetching Steam names has been disabled by an administrator.", CTAG, TAG, CERROR);
				return Plugin_Handled;
			}
		}
	} else
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled.", TAG);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted to fetch a Steam name but plugin is disabled.", LOGTAG, client);
			}
			return Plugin_Handled;
		} else {
			ReplyToCommand(client, "%s%s %sThis plugin is currently disabled.", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
	}
	
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_sname <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	if (g_bMapReloadClient[client])
	{
		PrintToChat(client, "%s%s %sYou cannot fetch another player's name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
	
	if (g_bMapReload)
	{
		PrintToChat(client, "%s%s %sYou cannot fetch another player's name due to an ongoing plugin restart. Please wait for the next map change or reconnect.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
	
	char arg1[64];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int Target = FindTarget(client, arg1, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled; //If the client is not found, go ahead and return an error
	}
	
	QueryClientConVar(Target, "name", OnSteamNameQueried, GetClientUserId(client));
	
	g_iSnameTracker++;
	g_iCheckedSname[client]++;
	g_iTargetWasSteamChecked[Target]++;
	
	return Plugin_Handled;
}

public void OnSteamNameQueried(QueryCookie cookie, int targetclient, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any UserId)
{
	int client = GetClientOfUserId(UserId);
	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sError: Couldn't retrieve %s%N%s's Steam name.", CTAG, TAG, CERROR, CPLAYER, targetclient, CERROR);
		g_iSteamQueryFail++;
		g_iCouldNotQuery[targetclient]++;
		
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s An error occured during query of Steam name.", LOGTAG);
		}
		return;
	}
	
	if (client <= 0 || client > MaxClients)
		return;
	
	else if (!IsClientInGame(client))
		return;
	
	char steamname[MAX_NAME_LENGTH];
	GetClientName(targetclient, steamname, sizeof(steamname));
	/*Now properly says if current name == Steam name already. Much prettier now in chat.*/
	if (strcmp(steamname, cvarValue) == 0)
	{
		PrintToChat(client, "%s%s %s%N%s is their Steam name.", CTAG, TAG, CPLAYER, targetclient, CUSAGE);
	}
	else
	{
		PrintToChat(client, "%s%s %s%N%s's Steam name is %s%s.", CTAG, TAG, CPLAYER, targetclient, CUSAGE, CPLAYER, cvarValue);
	}
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s Steam name queried.", LOGTAG);
	}
}

public void ChangeNameToSteamName(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char steamid[32];
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sCould not retrieve your Steam name.", CTAG, TAG, CERROR);
		g_iSteamQueryFail++;
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name not retrieved.", LOGTAG, client);
		}
		return;
	}
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if (!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		for (int i = 0; i < lines; i++)
		{
			if (StrContains(cvarValue, BadNames[i], false) != -1)
			{
				int bantime = GetConVarInt(changename_bantime);
				
				if (bantime == -2)
				{
					PrintToChat(client, "%s%s %sYou cannot use your Steam name, because it is banned.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s attempted to reset their name to their Steam name, but it is part of the banned names list.", LOGTAG, client);
					}
				}
				
				// name is naughty so we do not proceed further.
				return;
			}
		}
		
		for (int y = 0; y < bannedlines; y++)
		{
			if (StrContains(steamid, bannedsteamids[y], false) != -1)
			{
				char bantime = GetConVarInt(changename_bantime);
				
				if (bantime == -2)
				{
					PrintToChat(client, "%s%s %sYou cannot change your name due to an active name ban.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s attempted to reset their name, but their Steam ID is banned from doing so.", LOGTAG, client);
					}
					return;
				}
			}
		}
	}
	
	// steam name has passed the naughty check, now we can change it.
	if (!strcmp(name, cvarValue))
	{
		PrintToChat(client, "%s%s %sYour name is already your Steam name.", CTAG, TAG, CUSAGE);
		return;
	}
	else
	{
		int iNow = GetTime(), iCooldown = GetConVarInt(changename_cooldown);
		
		if (iCooldown > 0)
		{
			int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
			int mins, secs;
			if (iTimeLeft > 0)
			{
				mins = iTimeLeft / 60;
				secs = iTimeLeft % 60;
				//char timeleftbuffer[128];
				PrintToChat(client, "%s%s %sYou must wait %s%d:%02d %sbefore changing your name again.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
				return;
			}
		}
		g_iLastUsed[client] = iNow;
		
		SetClientInfo(client, "name", cvarValue);
		g_iSrnameTracker++;
		g_iResetToSteam[client]++;
		PrintToChatAll("%s%s %s%s %shas restored their Steam name: %s%s%s.", CTAG, TAG, CPLAYER, name, CUSAGE, CPLAYER, cvarValue, CUSAGE);
		PrintToChat(client, "%sYour Steam name may take a few seconds to show.", CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s restored their Steam name to %s.", LOGTAG, name, cvarValue);
		}
	}
	
	// as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
}

/*Below is making sure banned names and IDs are enforced should the commands for checking names and IDs get enabled during game session after being disabled*/
public void ChangeNameToSteamNameRenameDisabled(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sCould not retrieve your Steam name.", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name not retrieved and restored. Changing names ability disabled.", LOGTAG, client);
		}
		return;
	}
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if (!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		for (int i = 0; i < lines; i++)
		{
			if (StrContains(cvarValue, BadNames[i], false) != -1)
			{
				int bantime = GetConVarInt(changename_bantime);
				
				if (bantime == -2)
				{
					PrintToChat(client, "%s%s %sThe ability to change names has now been disabled. Your Steam name was not restored, because it is banned on this server.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s's Steam name was not restored despite \"sm_cname_enable\" set to 0, because their Steam name is banned.", LOGTAG, client);
					}
				}
				
				// name is naughty so we do not proceed further.
				return;
			}
		}
	}
	
	// steam name has passed the naughty check, now we can change it.
	if (!strcmp(name, cvarValue))
	{
		return;
	}
	else
	{
		SetClientInfo(client, "name", cvarValue);
		PrintToChat(client, "%s%s %sThe ability to change names has now been disabled. Restoring your Steam name...", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name restored due to name changing ability being disabled.", LOGTAG, client);
		}
	}
	
	// as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
}

public void ChangeNameToSteamNamePluginDisabled(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sThis plugin has now been disabled. However, your Steam name could not be retrieved and restored.", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name not retrieved and restored. Plugin disabled.", LOGTAG, client);
		}
		return;
	}
	
	if (!strcmp(name, cvarValue))
	{
		return;
	}
	else
	{
		SetClientInfo(client, "name", cvarValue);
		PrintToChat(client, "%s%s %sThis plugin has now been disabled. Restoring your Steam name...", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name restored due to plugin being disabled.", LOGTAG, client);
		}
	}
	
	// as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
}

public void ChangeNameToSteamNameIdBanned(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if (!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		if (result != ConVarQuery_Okay)
		{
			PrintToChat(client, "%s%s %sAn active name ban has been detected. However, your Steam name could not be retrieved and restored.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s's Steam name not retrieved and restored. Active SteamID name ban.", LOGTAG, client);
			}
			return;
		}
		
		if (!strcmp(name, cvarValue))
		{
			return;
		}
		else
		{
			SetClientInfo(client, "name", cvarValue);
			PrintToChat(client, "%s%s %sAn active name ban has been detected. Restoring your Steam name...", CTAG, TAG, CUSAGE);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s's Steam name restored due to SteamID name ban.", LOGTAG, client);
			}
		}
	}
	
	// as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
}

/*Below is HookConVar stuff*/
public void OnConVarChanged_Debug(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Debug mode has been enabled. Independant logs will be created in logs/NameLogs", LOGTAG);
					Debug_Path();
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					char xbuffer[128];
					Format(xbuffer, sizeof(xbuffer), "%s%s Debug mode has been enabled. Independant logs will be created in logs/NameLogs", CLOGTAG, LOGTAG);
					PrintToChat(x, xbuffer);
					if (GetConVarBool(changename_debug_snd))
					{
						EmitSoundToClient(x, g_SoundName_On);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Debug mode has been disabled. Logging terminated.", LOGTAG);
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					char cbuffer[128];
					Format(cbuffer, sizeof(cbuffer), "%s%s Debug mode has been disabled. Logging terminated.", CLOGTAG, LOGTAG);
					PrintToChat(x, cbuffer);
					if (GetConVarBool(changename_debug_snd))
					{
						EmitSoundToClient(x, g_SoundName_Off);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Global(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Name plugin is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name plugin enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Name plugin enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Name plugin is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name plugin disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					QueryClientConVar(x, "name", ChangeNameToSteamNamePluginDisabled);
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Name plugin disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
						QueryClientConVar(x, "name", ChangeNameToSteamNamePluginDisabled);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Name(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Name change ability is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name change ability enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Name change enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Name change ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name change ability disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					QueryClientConVar(x, "name", ChangeNameToSteamNameRenameDisabled);
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Name change ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
						QueryClientConVar(x, "name", ChangeNameToSteamNameRenameDisabled);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Oname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Fetching original names ability is now enabled..", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching original names ability enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Fetching original names enabled..", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Fetching original names ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching original names ability disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Fetching original names ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Sname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Fetching Steam names ability is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching Steam names ability enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Fetching Steam names enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Fetching Steam names ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching Steam names ability disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Fetching Steam names ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Snd(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Debug sounds are now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Debug sounds enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Debug sounds enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Debug sounds are now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Debug sounds disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Debug sounds disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_SndOn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "\0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s No sound file was set for \"sm_name_snd_warn_on\"! Setting default value.", TAG);
					ResetConVar(changename_debug_snd_warn_off, false, false);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s No sound file was set for \"sm_name_snd_warn_on\"! Setting default value.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s No sound file was set for \"sm_name_snd_warn_on\"! Setting default value.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_SndOff(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "\0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s No sound file was set for \"sm_name_snd_warn_off\"! Setting default value.", TAG);
					ResetConVar(changename_debug_snd_warn_off, false, false);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s No sound file was set for \"sm_name_snd_warn_off\"! Setting default value.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s No sound file was set for \"sm_name_snd_warn_off\"! Setting default value.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Srname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Steam name reset ability is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Steam name reset ability is now enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Steam name reset ability enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Steam name reset ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Steam name reset ability is now disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Steam name reset ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_NameCheck(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Names will now be checked against banned_names.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned names enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					if (GetAdminFlag(GetUserAdmin(x), Admin_Root))
					{
						if (GetConVarBool(changename_debug))
						{
							char xbuffer[128];
							Format(xbuffer, sizeof(xbuffer), "%s%s Checking for banned names enabled. Reading banned_names.ini", CLOGTAG, LOGTAG);
							PrintToChat(x, xbuffer);
						}
						return;
					}
					
					char playerName[64];
					GetClientName(x, playerName, sizeof(playerName));
					NameCheck(playerName, x);
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Names will no longer be checked against banned_names.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned names disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s No longer checking for banned names.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_IdCheck(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s SteamIDs will now be checked against banned_id.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned SteamIDs enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					if (GetAdminFlag(GetUserAdmin(x), Admin_Root))
					{
						if (GetConVarBool(changename_debug))
						{
							char xbuffer[128];
							Format(xbuffer, sizeof(xbuffer), "%s%s Checking for banned SteamIDs enabled. Reading banned_id.ini", CLOGTAG, LOGTAG);
							PrintToChat(x, xbuffer);
						}
						return;
					}
					
					char playerId[64];
					char playerName[64];
					GetClientName(x, playerName, sizeof(playerName));
					GetClientAuthId(x, AuthId_Steam2, playerId, 64);
					for (int i = 0; i < bannedlines; i++)
					{
						if (StrContains(playerId, bannedsteamids[i], false) != -1)
						{
							QueryClientConVar(x, "name", ChangeNameToSteamNameIdBanned);
						}
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s SteamIDs will no longer be checked against banned_id.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned SteamIDs disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s No longer checking for SteamIDs names.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

/******************************
PLUGIN FUNCTIONS
******************************/
void Debug_Path() //Sets the debug log path
{
	//Setting up the directory for the log file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/NameChanger");
	
	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
}

void ConVarCheck()
{
	CreateTimer(15.0, ConVarChecker_Callback, _, TIMER_REPEAT); // Maybe rather than having a timer, it checks everytime one of the name function is disabled whether all of them are and reset commands like the timer is doing
}

/*Is this useful anyway?*/
void parseList_Name(bool rebuild, int client = 0)
{
	char arg1[32];
	File hFile = OpenFile(fileName, "a+");
	
	if (hFile == INVALID_HANDLE)
	{
		PrintToServer("%s An error was encountered opening the file banned_names.ini", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s banned_names.ini could not be opened.", LOGTAG);
		}
		return;
	}
	
	while (!hFile.EndOfFile() && hFile.ReadLine(arg1, sizeof(arg1)))
	{
		TrimString(arg1);
		StripQuotes(arg1);
		
		if (strlen(arg1) < 1)continue;
		
		if (StrContains(arg1, "STEAM_", false) != -1)
		{
			g_bannednames.SetString(arg1, arg1, true);
		}
	}
	if (rebuild && client && GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s%s banned_names.ini rebuilt.", LOGTAG);
	}
	delete hFile;
}

void parseList_id(bool rebuild, int client = 0)
{
	char arg1[32];
	File nFile = OpenFile(bannedidfile, "a+");
	
	if (nFile == INVALID_HANDLE)
	{
		PrintToServer("%s An error was encountered opening the file banned_id.ini", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s banned_id.ini could not be opened.", LOGTAG);
		}
		return;
	}
	
	while (!nFile.EndOfFile() && nFile.ReadLine(arg1, sizeof(arg1)))
	{
		TrimString(arg1);
		StripQuotes(arg1);
		
		if (strlen(arg1) < 1)continue;
		
		if (StrContains(arg1, "STEAM_", false) != -1)
		{
			g_bannedids.SetString(arg1, arg1, true);
		}
	}
	if (rebuild && client && GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s banned_id.ini rebuilt.", LOGTAG);
	}
	delete nFile;
}

/******************************
PLUGIN STOCKS (Printing to admins whenever the plugin gets reloaded through "nameadmin plugin reload [map_reload]")
******************************/

int PrintToAdmins(char[] format)
{
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 2);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			int admin = GetUserFlagBits(i);
			if (admin != 0 && admin > 1)
			{
				
				PrintToChat(i, "%s", buffer);
			}
		}
	}
	return 0;
}
//PETER BREV, SIGNING OFF

/*************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/

