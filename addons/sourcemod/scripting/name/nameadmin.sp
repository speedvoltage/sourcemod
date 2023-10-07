/** =============================================================================
 * Change Your Name - Administration System
 * Main administration interface for server admins
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

public Action Command_NameAdmin(int client, int args)
{
	char cmd[32];
	GetCmdArg(1, cmd, sizeof(cmd));
	
	if (!client)
	{
		PrintToServer("[SM] This command is intended for admins without SRCDS access to facilitate the listing of plugin commands. \
		Use \"sm_name_version\", or the default Sourcemod commands instead (\"sm cvars <plugin #>\", sm cmds <plugin #>) to list commands.");
		return Plugin_Handled;
	}
	
	if (strcmp(cmd, "cmd") == 0)
	{
		char cmd2[32];
		GetCmdArg(2, cmd2, sizeof(cmd2));
		
		if (strcmp(cmd2, "list") == 0)
		{
			int iCount;
			iCount = 0;
			for (int i; i < sizeof(g_sAllCommands); i++)
			{
				iCount++;
				ReplyToCommand(client, "%i. %s", iCount, g_sAllCommands[i]);
			}
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "nameadmin") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n nameadmin <command> [argument]\n Access to various plugin administration tools, such as viewing technical plugin information, statistics, restoring settings and more. Use with caution!");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_ban") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_ban <name to ban (do not put white spaces anywhere)>\n Adds a name to the banned names list.\nNOTE: Admins are immune.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_namebanid") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_banid <Steam ID to ban(Steam 2 ID format -- STEAM_)>\n Adds a Steam ID to the banned ID list.\nNOTE: Admins are immune.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_reload") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_reload\n Reloads banned names and Steam IDs files.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_unban") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_unban <name to ban (do not put white spaces anywhere)>\n Removes a name from the banned names list.\nNOTE: Admins are immune.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_unbanid") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_unbanid <Steam ID to unban(Steam 2 ID format -- STEAM_)>\n Removes a Steam ID from the banned ID list.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_rename") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_rename <#userid|name> <new name>\n Renames a player and applies a temporary name change cooldown.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name <new name> (leave blank to reset to the name set upon server connection).");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "setinfo permaname") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n setinfo permaname <new name> - Sets a name a player will conect with. Quotes are required around the new name.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_credits") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_credits\n Display plugin credits.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_help") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_nhelp\n Display public commands and usage to players.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_oname") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_oname <#userid|name>\n Displays the name a user had upon server connection.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_sname") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_sname <#userid|name>\n Displays the Steam name of a user.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_srname") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_srname\n Restore a player's name to their Steam name.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_rename_random") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_random <#userid|name>\n Scrambles the player's name.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_rename_force") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_force <#userid|name> <new name>\n Forcibly set a name on a player without the possibility of changing it.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_rename_unforce") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_force <#userid|name>\n Removes a forced locked name on a player.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_name_history") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_history <#userid|name>\n Displays the last 10 names used by a player.");
			return Plugin_Handled;
		}
		
		else if (strcmp(cmd2, "sm_rename_reset") == 0)
		{
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output");
			PrintToConsole(client, "[SM] Command description:\n sm_name_reset <#userid|name>\n Resets a player's name.");
			return Plugin_Handled;
		}
		
		ReplyToCommand(client, "[SM] Usage: nameadmin cmd [arguments]");
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for available commands.");
		PrintToConsole(client, "Available commands are:\n list 		- Provide a full list of public and admin commands.\n <cmd name> 	- Provide information on a command.");
		return Plugin_Handled;
	}
	
	if (strcmp(cmd, "plugin") == 0)
	{
		if (args == 2)
		{
			char cmd2[32];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			
			if (strcmp(cmd2, "stats") == 0)
			{
				char time[55];
				FormatTime(time, sizeof(time), NULL_STRING);
				PrintToServer("%s", time);
				if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output.");
				PrintToConsole(client, "[SM] Plugin statistics:\n Number of names changed: %i\n \
				Number of name resets: %i\n \
				Number of Steam name resets: %i\n \
				Number of original names fetched: %i\n \
				Number of Steam name fetched: %i\n \
				Number of admin renames: %i\n \
				Number of forced names set: %i\n \
				Number of failed Steam names fetches: %i\n\
				Statistics printed on: %s", g_iNameChangeTracker, g_iNameResetTracker, g_iSrnameTracker, g_iOnameTracker, g_iSnameTracker, g_iRenameTracker, g_iForcedNames, g_iSteamQueryFail, time);
				return Plugin_Handled;
			}
			
			else if (strcmp(cmd2, "reload") == 0)
			{
				g_bMapReload = true;
				DataPack pack;
				g_hPluginReload[client] = CreateDataTimer(3.0, PluginReloadTimer, pack);
				pack.WriteCell(client);
				ShowActivity2(client, "[SM] ", "Plugin \"Change My Name\" reloaded. The current map will now be reloaded!");
				LogMessage("%L has restarted the plugin through \"nameadmin plugin reload\".", client);
				return Plugin_Handled;
			}
		}
		
		ReplyToCommand(client, "[SM] Usage: nameadmin plugin [arguments]");
		ReplyToCommand(client, "Check your console for available commands.");
		PrintToConsole(client, "Available commands are:\n reload		- Reloads the plugin and the current map.\n \
		stats			- Display plugin statistics");
		return Plugin_Handled;
	}
	
	if (strcmp(cmd, "player") == 0)
	{
		if (args == 2)
		{
			char cmd2[32];
			GetCmdArg(2, cmd2, sizeof(cmd2));
			
			if (strcmp(cmd2, "status") == 0)
			{
				if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output.");
				char sName[MAX_NAME_LENGTH], id[32];
				int count = 0;
				bool bIdfound;
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i))
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
				
				if (Target && g_iClients[Target] == GetClientUserId(Target))
				{
					char buffer[70], seconds = RoundToZero(GetClientTime(client));
					SecondsToTime(seconds, buffer);
					char targetname[MAX_TARGET_LENGTH], id[32];
					GetClientName(Target, targetname, sizeof(targetname));
					bool bIdfound = GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
					
					if (!bIdfound)
					{
						if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output.");
						PrintToConsole(client, "[SM] Player status:\n Current name: %s\n \
						SteamID: UNVERIFIED STEAM ID\n \
						Name changes performed: %i\n \
						Name resets performed: %i\n \
						Steam name resets: %i\n \
						Original name checks: %i\n \
						Steam name checks: %i\n \
						Number of admin renames: %i\n \
						Failed query attempts: %i\n\n\
						Additional information:\n \
						Player's name upon server connect was queried %i time%s.\n \
						Player's Steam name was queried %i time%s.\n", 
						targetname, 
						g_iChangedMyName[Target], 
						g_iResetMyName[Target], 
						g_iResetToSteam[Target], 
						g_iCheckedOname[Target], 
						g_iCheckedSname[Target], 
						g_iWasRenamed[Target], 
						g_iCouldNotQuery[Target], 
						g_iTargetWasOnameChecked[Target], 
						g_iTargetWasOnameChecked[Target] <= 1 ? "" : "s", 
						g_iTargetWasSteamChecked[Target], 
						g_iTargetWasSteamChecked[Target] <= 1 ? "" : "s");
						PrintToConsole(client, "Warning! SteamID of %s could not be found. Name changes are not allowed for this player!", targetname);
					}
					
					else
					{
						if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for output.");
						PrintToConsole(client, "[SM] Player status:\n \
						Current name: %s\n \
						SteamID: %s\n \
						Name changes performed: %i\n \
						Name resets performed: %i\n \
						Steam name resets: %i\n \
						Original name checks: %i\n \
						Steam name checks: %i\n \
						Number of admin renames: %i\n \
						Number of forced names set: %i\n \
						Failed query attempts: %i\n\n\
						Additional information:\n \
						Player's name upon server connect was queried %i time%s.\n \
						Player's Steam name was queried %i time%s.\n", 
						targetname, 
						id, 
						g_iChangedMyName[Target], 
						g_iResetMyName[Target], 
						g_iResetToSteam[Target], 
						g_iCheckedOname[Target], 
						g_iCheckedSname[Target], 
						g_iWasRenamed[Target], 
						g_iWasForcedNamed[Target], 
						g_iCouldNotQuery[Target], 
						g_iTargetWasOnameChecked[Target],
						g_iTargetWasOnameChecked[Target] <= 1 ? "" : "s", 
						g_iTargetWasSteamChecked[Target], 
						g_iTargetWasSteamChecked[Target] <= 1 ? "" : "s");
					}
					
					return Plugin_Handled;
				}
			}
		}
		ReplyToCommand(client, "[SM] Usage: nameadmin player [arguments]");
		ReplyToCommand(client, "Check your console for available commands.");
		PrintToConsole(client, "Available commands are:\n status [#userid|name]	- Acquire technical player information (leave blank after \"status\" to list all players).");
		return Plugin_Handled;
	}
	
	else if (strcmp(cmd, "credits") == 0)
	{
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for credits listing.");
		PrintToConsole(client, "\"Set My name\" was developed by Peter Brev.\nThanks to the following people that made this plugin possible:\n Harper			- 	For providing the base code that allowed players to change their name.\n eyal282		-	For providing feedback and exposing plugin's issues.\n Grey83			-	For providing help on the forums.\n Humam			-	For testing and providing feedback.\n Alienmario		-	For testing and providing feedback.\n Alliedmodders		-	For providing Sourcemod and the tools to create plugins.");
		return Plugin_Handled;
	}
	
	else if (strcmp(cmd, "version") == 0)
	{
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for version information.");
		PrintToConsole(client, "\"Set My name\" version information:\n \
		Version: %s\n \
		Compiled for Sourcemod 1.11.0.6936 and later\n \
		Your current version of Sourcemod is: %s", 
		PLUGIN_VERSION, 
		SOURCEMOD_VERSION);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "[SM] Usage: nameadmin <command> [arguments]");
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)ReplyToCommand(client, "[SM] Check your console for available commands.");
	PrintToConsole(client, "Available commands are:\n cmd 				- Provide infomation on a cmd or provide a full list of all available commands.\n \
	plugin				- Manage the plugin.\n player				- Player information\n \
	version			- Display version information.\n \
	credits			- Display credits listing.");
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
	int client;
	pack.Reset();
	client = pack.ReadCell();
	
	if (g_bMapReload)
	{
		char map[64];
		GetCurrentMap(map, sizeof(map));
		ForceChangeLevel(map, "Plugin restart by admin [nameadmin plugin reload]");
		return Plugin_Stop;
	}

	else
	{
		PrintToChat(client, "[SM] Already an ongoing plugin restart.");
	}
	
	return Plugin_Continue;
} 