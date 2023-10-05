/** =============================================================================
 * Change Your Name - Functionality related to changing and resetting your name.
 * Change and reset your name at will.
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

public Action Command_Name(int client, int args)
{
	//char buffer[128]; /*For translation files*/
	
	if (!GetConVarBool(changename_enable_global))
	{
		ReplyToCommand(client, "[SM] This plugin is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!GetConVarBool(changename_enable))
	{
		ReplyToCommand(client, "[SM] You cannot change your name (ability disabled by server).");
		return Plugin_Handled;
	}
	
	if (!client)
	{
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}
	
	if (IsFakeClient(client))
		return Plugin_Handled;
	
	if (g_bMapReload)
	{
		ReplyToCommand(client, "[SM] This plugin was restarted. Please wait for the next map or reconnect.");
		return Plugin_Handled;
	}
	
	if (g_bClientAuthorized[client])
	{
		ReplyToCommand(client, "[SM] Your Steam ID was not yet authorized.");
		return Plugin_Handled;
	}
	
	bool gag = BaseComm_IsClientGagged(client);
	
	if (gag)
	{
		ReplyToCommand(client, "[SM] You are gagged and cannot change your name right now.");
		return Plugin_Handled;
	}
	
	char currentname[MAX_NAME_LENGTH], buffer[MAX_NAME_LENGTH], id[32], filebuffer[MAX_NAME_LENGTH], bantime = GetConVarInt(changename_bantime);
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	for (int i, num = hBannedSteamId.Length; i < num; i++)
	{
		if (hBannedSteamId.GetString(i, buffer, sizeof(buffer)) && StrContains(id, buffer, false) != -1)
		{
			if (bantime == -2)
			{
				ReplyToCommand(client, "[SM] Your Steam ID is banned from changing names.");
				return Plugin_Handled;
			}
		}
	}
	
	if (g_bAdminRenamed[client])
	{
		ReplyToCommand(client, "[SM] An admin renamed you. You cannot change your name until the cooldown is over.");
		return Plugin_Handled;
	}
	
	if (g_bForcedName[client])
	{
		ReplyToCommand(client, "[SM] A name force lock is in effect. You cannot change your name.");
		return Plugin_Handled;
	}
	
	GetClientName(client, currentname, sizeof(currentname));
	
	if (!args)
	{
		g_names.GetString(id, buffer, sizeof(buffer));
		
		for (int i, num = hBadNames.Length; i < num; i++)
		{
			if (!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
			{
				if (hBadNames.GetString(i, filebuffer, sizeof(filebuffer)) && StrContains(buffer, filebuffer, false) != -1)
				{
					if (bantime == -2)
					{
						ReplyToCommand(client, "[SM] Your name was not restored, because it is banned.");
						return Plugin_Handled;
					}
				}
			}
		}
		
		if (strcmp(buffer, "") == 0)
		{
			ReplyToCommand(client, "[SM] Error: name not stored in memory. Please reconnect.");
			LogError("%L could not reset their name. No name stored in memory.", client);
			return Plugin_Handled;
		}
		
		if (strcmp(currentname, buffer) == 0)
		{
			ReplyToCommand(client, "[SM] Your name is already set to %s.", currentname);
			return Plugin_Stop;
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
				ReplyToCommand(client, "[SM] You must wait %d:%02d before changing your name again.", mins, secs);
				return Plugin_Handled;
			}
		}
		
		g_iLastUsed[client] = iNow;
		
		g_iNameResetTracker++;
		g_iResetMyName[client]++;
		
		DataPack pack;
		g_hNameReset[client] = CreateDataTimer(0.1, ResetNameTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(client);
		pack.WriteString(currentname);
		pack.WriteString(buffer);
		pack.WriteString(id);
		
		return Plugin_Handled;
	}
	
	char newname[MAX_NAME_LENGTH];
	
	GetCmdArgString(newname, sizeof(newname));
	
	for (int i, num = hBadNames.Length; i < num; i++)
	{
		if (!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
		{
			if (hBadNames.GetString(i, buffer, sizeof(buffer)) && StrContains(newname, buffer, false) != -1)
			{
				if (bantime == -2)
				{
					ReplyToCommand(client, "[SM] %s is banned from being used.", newname);
					return Plugin_Handled;
				}
			}
		}
	}
	
	if (strcmp(currentname, newname) == 0)
	{
		ReplyToCommand(client, "[SM] Your name is already set to %s.", newname);
		return Plugin_Handled;
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
			ReplyToCommand(client, "[SM] You must wait %d:%02d before changing your name again.", mins, secs);
			return Plugin_Handled;
		}
	}
	
	g_iLastUsed[client] = iNow;
	
	g_iNameChangeTracker++;
	g_iChangedMyName[client]++;
	
	DataPack pack;
	g_hNameChange[client] = CreateDataTimer(0.1, ChangeNameTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(client);
	pack.WriteString(newname);
	pack.WriteString(currentname);
	pack.WriteString(id);
	
	return Plugin_Handled;
}

public Action ChangeNameTimer(Handle timer, DataPack pack)
{
	char newname[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH], id[32], id64[64], time[55];
	int client;
	FormatTime(time, sizeof(time), NULL_STRING);
	pack.Reset();
	client = pack.ReadCell();
	pack.ReadString(newname, sizeof(newname));
	pack.ReadString(currentname, sizeof(currentname));
	pack.ReadString(id, sizeof(id));
	
	GetClientAuthId(client, AuthId_SteamID64, id64, sizeof(id64));
	BuildPath(Path_SM, g_sPlayerNameHistory, sizeof(g_sPlayerNameHistory), "Name/%s.txt", id64);
	Handle NameHistory = OpenFile(g_sPlayerNameHistory, "a+");
	WriteFileLine(NameHistory, "[%s] %s", time, newname);
	CloseHandle(NameHistory);
	SetClientName(client, newname);
	PrintToChatAll("[SM] %s has changed their name to %s.", currentname, newname);
	LogMessage("%s [%s] changed name to %s.", currentname, id, newname);
	
	g_hNameChange[client] = null;
	return Plugin_Stop;
}

public Action ResetNameTimer(Handle timer, DataPack pack)
{
	int client;
	char currentname[MAX_NAME_LENGTH], buffer[MAX_NAME_LENGTH], id[32], id64[64], time[55];
	FormatTime(time, sizeof(time), NULL_STRING);
	pack.Reset();
	client = pack.ReadCell();
	pack.ReadString(currentname, sizeof(currentname));
	pack.ReadString(buffer, sizeof(buffer));
	pack.ReadString(id, sizeof(id));
	
	GetClientAuthId(client, AuthId_SteamID64, id64, sizeof(id64));
	BuildPath(Path_SM, g_sPlayerNameHistory, sizeof(g_sPlayerNameHistory), "Name/%s.txt", id64);
	Handle NameHistory = OpenFile(g_sPlayerNameHistory, "a+");
	WriteFileLine(NameHistory, "[%s] %s", time, buffer);
	CloseHandle(NameHistory);
	
	SetClientName(client, buffer);
	PrintToChatAll("[SM] %s has reset their name to %s.", currentname, buffer);
	LogMessage("%s [%s] reset name to %s.", currentname, id, buffer);
	
	g_hNameReset[client] = null;
	return Plugin_Stop;
} 