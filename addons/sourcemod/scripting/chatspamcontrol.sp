/** =============================================================================
 * Chat Spam Punishment - Main Plugin
 * Core plugin
 *
 * Plugin developed by Peter Brev.
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

/******************************
INCLUDE ALL THE NECESSARY FILES
******************************/

#include <sourcemod>
#include <basecomm>
#undef REQUIRE_PLUGIN
#include <sourcecomms>
#include <sourcebanspp>
#include <updater>

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Info*/
#define PLUGIN_NAME								"Chat Spam Punishment"
#define PLUGIN_AUTHOR							"Peter Brev"
#define PLUGIN_VERSION							"1.0.2"
#define PLUGIN_DESCRIPTION						"Punishes players who spam the chat"

/*Plugin Updater*/
#define UPDATE_URL    "https://raw.githubusercontent.com/speedvoltage/sourcemod/master/addons/sourcemod/chatspamcontrol.upd"

/******************************
PLUGIN CONVARS
******************************/

ConVar g_cEnabled, 
g_cThreshold = null, 
g_cThresholdWarningEnable = null, 
g_cThresholdWarning = null, 
g_cPunishmentType = null, 
g_cPunishmentGagTime = null, 
g_cPunishmentBanTime = null, 
g_cPunishmentTimeSC = null, 
g_cTimer = null;

/******************************
PLUGIN HANDLES
******************************/

Handle g_hTimer[MAXPLAYERS + 1], 
g_hTimerGag[MAXPLAYERS + 1];

/******************************
PLUGIN INTEGERS
******************************/

int g_iThreshold[MAXPLAYERS + 1];

/******************************
PLUGIN INFO
******************************/

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "", 
};

/******************************
INITIATE THE PLUGIN
******************************/

public void OnPluginStart()
{
	/*Updater*/
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	/*Get ourselves the chat*/
	
	AddCommandListener(cmd_say, "say");
	AddCommandListener(cmd_say, "say_team");
	
	/***COMMANDS SETUP***/
	
	/*Plugin version*/
	
	CreateConVar("sm_chat_spam_punishment_version", PLUGIN_VERSION, "Plugin Version", FCVAR_NOTIFY | FCVAR_SPONLY);
	
	/*ConVar*/
	
	g_cEnabled = CreateConVar("sm_chat_spam_enable", "1", "Enable/Disable Plugin", 0, true, 0.0, true, 1.0);
	g_cThreshold = CreateConVar("sm_chat_spam_punishment_threshold", "8", "The maximum number of messages in a given time at which it will gag, kick or ban the player.", 0, true, 8.0);
	g_cThresholdWarningEnable = CreateConVar("sm_chat_spam_punishment_warning_enable", "1", "Should the player see a warning before their impending doom.", 0, true, 0.0, true, 1.0);
	g_cThresholdWarning = CreateConVar("sm_chat_spam_punishment_warning", "1", "How close to the threshold should it warn the player of an impending action.", 0, true, 0.0);
	g_cPunishmentType = CreateConVar("sm_chat_spam_punishment_type", "0", "Type of punishment to apply (0: gag, 1: kick, 2: ban).", 0, true, 0.0, true, 2.0);
	g_cPunishmentGagTime = CreateConVar("sm_chat_spam_punishment_gag_time", "5", "How long to apply a gag for (time in minutes). [Use \"sm_chat_spam_punishment_time_sc\" if you have Sourcecomms].", 0, true, 1.0);
	g_cPunishmentBanTime = CreateConVar("sm_chat_spam_punishment_ban_time", "5", "How long to apply a ban for (time in minutes). [Use \"sm_chat_spam_punishment_time_sc\" if you have Sourcecomms].", 0, true, 1.0);
	g_cTimer = CreateConVar("sm_chat_spam_punishment_timer", "15", "The time at which the player's threshold will reset (time in seconds)", 0, true, 15.0);
	if (FindPluginByFile("sbpp_comms.smx"))
	{
		g_cPunishmentTimeSC = CreateConVar("sm_chat_spam_punishment_time_sb", "5", "How long to apply a gag or a ban (time in minutes).", 0, true, 1.0);
	}
	
	/*Hooking ConVars*/
	
	HookConVarChange(g_cEnabled, OnConVarChanged_Enabled);
	HookConVarChange(g_cThreshold, OnConVarChanged_Threshold);
	HookConVarChange(g_cThresholdWarningEnable, OnConVarChanged_ThresholdWarningEnable);
	HookConVarChange(g_cThresholdWarning, OnConVarChanged_ThresholdWarning);
	HookConVarChange(g_cPunishmentType, OnConVarChanged_PunishmentType);
	HookConVarChange(g_cPunishmentGagTime, OnConVarChanged_GagTime);
	HookConVarChange(g_cPunishmentBanTime, OnConVarChanged_BanTime);
	HookConVarChange(g_cTimer, OnConVarChanged_ThresholdTimer);
	if (FindPluginByFile("sbpp_comms.smx"))
		HookConVarChange(g_cPunishmentTimeSC, OnConVarChanged_PunishmentTimeSC);
	
	AutoExecConfig(true, "plugin.chatspampunishment");
	
	PrintToServer("\"Chat Spam Punishment\" plugin loaded.");
}

/******************************
PLUGIN FUNCTIONS
******************************/

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public void OnClientPutInServer(int client)
{
	g_iThreshold[client] = 0;
}

public void OnClientDisconnect(int client)
{
	delete g_hTimer[client];
	delete g_hTimerGag[client];
}

public Action cmd_say(int client, const char[] cmd, int argc)
{
	if (!GetConVarBool(g_cEnabled))return Plugin_Continue;
	if (CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))return Plugin_Continue;
	bool gag = BaseComm_IsClientGagged(client);
	if (gag)return Plugin_Continue;
	g_iThreshold[client]++;
	if (g_iThreshold[client] == 1)
	{
		DataPack pack;
		g_hTimer[client] = CreateDataTimer(GetConVarFloat(g_cTimer), t_ThresholdReset, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
		pack.WriteCell(client);
	}
	if (GetConVarBool(g_cThresholdWarningEnable))if (g_iThreshold[client] == GetConVarInt(g_cThreshold) - GetConVarInt(g_cThresholdWarning))
		PrintToChat(client, "[SM] Warning: You have sent too many messages in a short amount of time. Stop or you will be %s.", GetConVarInt(g_cPunishmentType) > 0 ? "kicked" : "gagged");
	
	if (g_iThreshold[client] == GetConVarInt(g_cThreshold))
	{
		if (GetConVarInt(g_cPunishmentType) == 0)
		{
			if (FindPluginByFile("sbpp_comms.smx"))/*Perhaps it would be better if I included the library rather than checking for file presence*/
			{
				SourceComms_SetClientGag(client, true, GetConVarInt(g_cPunishmentTimeSC), true, "Auto-gagged for spamming chat.");
				ShowActivity2(client, "\x04[SourceComms++]\x01 ", "Gagged %N for %i minute%s \x04[Chat Spam]\x01.", client, GetConVarInt(g_cPunishmentTimeSC), GetConVarInt(g_cPunishmentTimeSC) <= 1 ? "" : "s");
				LogMessage("%L was auto-gagged %i minute%s for spamming the chat.", client, GetConVarInt(g_cPunishmentTimeSC), GetConVarInt(g_cPunishmentTimeSC) <= 1 ? "" : "s");
				
				g_iThreshold[client] = 0;
				delete g_hTimer[client];
				
				return Plugin_Handled;
			}
			
			else
			{
				float f_total;
				f_total = GetConVarFloat(g_cPunishmentGagTime) * 60;
				DataPack pack;
				g_hTimerGag[client] = CreateDataTimer(f_total, t_ThresholdPunishment, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
				pack.WriteCell(client);
				
				delete g_hTimer[client];
				g_iThreshold[client] = 0;
				BaseComm_SetClientGag(client, true);
				
				ShowActivity2(client, "[SM] ", "Gagged %N for %d minute%s for chat spam.", client, GetConVarInt(g_cPunishmentGagTime), GetConVarInt(g_cPunishmentGagTime) <= 1 ? "" : "s");
				LogMessage("%L was auto-gagged for %d minute%s for spamming the chat.", client, GetConVarInt(g_cPunishmentGagTime), GetConVarInt(g_cPunishmentGagTime) <= 1 ? "" : "s");
				
				return Plugin_Handled;
			}
		}
		
		else if (GetConVarInt(g_cPunishmentType) == 1)
		{
			ShowActivity2(client, "[SM] ", "Auto-kicked %N for spamming chat.", client);
			LogMessage("%L was auto-kicked for spamming the chat.", client);
			KickClient(client, "Auto-kick: You have sent too many messages in a short time");
			return Plugin_Handled;
		}
		
		else
		{
			
			if (FindPluginByFile("sbpp_main.smx"))
			{
				ShowActivity2(client, "[SM] ", "Auto-banned %N for %i minute%s for spamming chat.", client, GetConVarInt(g_cPunishmentTimeSC), GetConVarInt(g_cPunishmentTimeSC) <= 1 ? "" : "s");
				LogMessage("%L was auto-banned %i minute%s for spamming the chat.", client, GetConVarInt(g_cPunishmentTimeSC), GetConVarInt(g_cPunishmentTimeSC) <= 1 ? "" : "s");
				SBPP_BanPlayer(0, client, GetConVarInt(g_cPunishmentTimeSC), "Auto-ban: Spamming chat");
				return Plugin_Handled;
			}
			
			else
			{
				ShowActivity2(client, "[SM] ", "Auto-banned %N for %i minute%s for spamming chat.", client, GetConVarInt(g_cPunishmentBanTime), GetConVarInt(g_cPunishmentBanTime) <= 1 ? "" : "s");
				BanClient(client, GetConVarInt(g_cPunishmentBanTime), BANFLAG_AUTO, "Auto-ban: Spamming chat", "Auto-ban: You have sent too many messages in a short time");
				LogMessage("%L was auto-banned %i minute%s for spamming the chat.", client, GetConVarInt(g_cPunishmentBanTime), GetConVarInt(g_cPunishmentBanTime) <= 1 ? "" : "s");
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action t_ThresholdReset(Handle timer, DataPack pack)
{
	int client;
	pack.Reset();
	client = pack.ReadCell();
	g_iThreshold[client] = 0;
	LogMessage("%L's threshold reset.", client);
	g_hTimer[client] = null;
	return Plugin_Stop;
}

public Action t_ThresholdPunishment(Handle timer, DataPack pack)
{
	int client;
	pack.Reset();
	client = pack.ReadCell();
	g_iThreshold[client] = 0;
	BaseComm_SetClientGag(client, false);
	ShowActivity2(client, "[SM] ", "Gag for chat spam removed.");
	LogMessage("%L's gag for chat spam removed.", client);
	g_hTimerGag[client] = null;
	return Plugin_Stop;
}

public void OnConVarChanged_GagTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (FindPluginByFile("sbpp_comms.smx"))
	{
		PrintToServer("[SM] Your server uses Sourcebans++. Use cvar \"sm_chat_spam_punishment_time_sb\" to adjust gag and ban times.");
		return;
	}
	
	else
	{
		if (GetConVarInt(g_cPunishmentGagTime) < 1)
		{
			PrintToServer("[SM] Gag time cannot be less than 1 minute.");
			return;
		}
		
		PrintToServer("[SM] Gag time adjusted to %d minute%s.", GetConVarInt(g_cPunishmentGagTime), GetConVarInt(g_cPunishmentGagTime) <= 1 ? "" : "s");
	}
	
	return;
}

public void OnConVarChanged_BanTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (FindPluginByFile("sbpp_comms.smx"))
	{
		PrintToServer("[SM] Your server uses Sourcebans++. Use cvar \"sm_chat_spam_punishment_time_sb\" to adjust gag and ban times.");
		return;
	}
	
	else
	{
		if (GetConVarInt(g_cPunishmentBanTime) < 1)
		{
			PrintToServer("[SM] Ban time cannot be less than 1 minute.");
			return;
		}
		
		PrintToServer("[SM] Ban time adjusted to %i minute%s.", GetConVarInt(g_cPunishmentBanTime), GetConVarInt(g_cPunishmentBanTime) <= 1 ? "" : "s");
	}
	
	return;
}

public void OnConVarChanged_Enabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)PrintToServer("[SM] Chat spam punishment plugin enabled.");
	if (strcmp(newValue, "0") == 0)PrintToServer("[SM] Chat spam punishment plugin disabled.");
	return;
}

public void OnConVarChanged_Threshold(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarInt(g_cThreshold) < 8)
	{
		PrintToServer("[SM] Value cannot be fewer than 8.");
		return;
	}
	
	PrintToServer("[SM] threshold at which to punish players set to %i.", GetConVarInt(g_cThreshold));
	return;
}

public void OnConVarChanged_ThresholdWarningEnable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)PrintToServer("[SM] threshold warning enabled.");
	if (strcmp(newValue, "0") == 0)PrintToServer("[SM] threshold warning disabled.");
	return;
}

public void OnConVarChanged_ThresholdWarning(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PrintToServer("[SM] threshold at which to warn players of an upcoming punishment set to %i.", GetConVarInt(g_cThresholdWarning));
	return;
}

public void OnConVarChanged_PunishmentType(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "0") == 0)PrintToServer("[SM] Punishment for chat spam: Gag.");
	if (strcmp(newValue, "1") == 0)PrintToServer("[SM] Punishment for chat spam: Kick.");
	if (strcmp(newValue, "2") == 0)PrintToServer("[SM] Punishment for chat spam: Ban.");
	return;
}

public void OnConVarChanged_ThresholdTimer(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarInt(g_cTimer) < 15)
	{
		PrintToServer("[SM] Minimum time is 15 seconds.");
		return;
	}
	
	int timeleft = GetConVarInt(g_cTimer);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
	}
	PrintToServer("[SM] Player chat spam tokens will reset after %d:%02d.", mins, secs);
	return;
}

public void OnConVarChanged_PunishmentTimeSC(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarInt(g_cPunishmentTimeSC) < 1)
	{
		PrintToServer("[SM] Gag and ban time cannot be less than 1 minute.");
		return;
	}
	
	PrintToServer("[SM] Gag and ban time adjusted to %i minute%s.", GetConVarInt(g_cPunishmentTimeSC), GetConVarInt(g_cPunishmentTimeSC) <= 1 ? "" : "s");
	return;
} 