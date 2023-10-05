/** =============================================================================
 * Change Your Name - Functionality related to restting name to Steam name
 * Let's a player reset their name to their current Steam name.
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

public Action Command_Srname(int client, int args)
{
	if (!GetConVarBool(changename_enable_global))
	{
		ReplyToCommand(client, "[SM] This plugin is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!GetConVarBool(changename_steamreset))
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
	
	if (g_bClientAuthorized[client])
	{
		ReplyToCommand(client, "[SM] Your Steam ID was not yet authorized.");
		return Plugin_Handled;
	}
	
	if (g_bForcedName[client])
	{
		ReplyToCommand(client, "[SM] A name force lock is in effect. You cannot change your name.");
		return Plugin_Handled;
	}
	
	bool gag = BaseComm_IsClientGagged(client);
	
	if (gag)
	{
		ReplyToCommand(client, "[SM] You are gagged and cannot change your name right now.");
		return Plugin_Handled;
	}
	
	if (!args)
	{
		QueryClientConVar(client, "name", ChangeNameToSteamName);
	}
	
	else
	{
		ReplyToCommand(client, "[SM] Only type the command.");
	}
	
	return Plugin_Handled;
}

public void ChangeNameToSteamName(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char id[32], name[MAX_NAME_LENGTH], time[55];
	FormatTime(time, sizeof(time), NULL_STRING);
	
	GetClientName(client, name, sizeof(name));
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "[SM] Could not retrieve your Steam name.");
		/*g_iSteamQueryFail++;*/
		LogError("%L's Steam name could not be fetched.", client);
		return;
	}
	
	char buffer[MAX_NAME_LENGTH], filebuffer[MAX_NAME_LENGTH], id64[64], bantime = GetConVarInt(changename_bantime);
	
	for (int i, num = hBannedSteamId.Length; i < num; i++)
	{
		if (hBannedSteamId.GetString(i, buffer, sizeof(buffer)) && StrContains(id, buffer, false) != -1)
		{
			if (bantime == -2)
			{
				PrintToChat(client, "[SM] Your Steam ID is banned from changing names.");
				return;
			}
		}
	}
	
	if (g_bAdminRenamed[client])
	{
		PrintToChat(client, "[SM] An admin renamed you. You cannot change your name until the cooldown is over.");
		return;
	}
	
	for (int i, num = hBadNames.Length; i < num; i++)
	{
		if (!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
		{
			if (hBadNames.GetString(i, filebuffer, sizeof(filebuffer)) && StrContains(cvarValue, filebuffer, false) != -1)
			{
				if (bantime == -2)
				{
					PrintToChat(client, "[SM] Your name was not restored, because it is banned.");
					return;
				}
			}
		}
	}
	
	if (strcmp(name, cvarValue) == 0)
	{
		PrintToChat(client, "[SM] Your name is already your Steam name.");
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
				PrintToChat(client, "[SM] You must wait %d:%02d before changing your name again.", mins, secs);
				return;
			}
		}
		g_iLastUsed[client] = iNow;
		
		GetClientAuthId(client, AuthId_SteamID64, id64, sizeof(id64));
		BuildPath(Path_SM, g_sPlayerNameHistory, sizeof(g_sPlayerNameHistory), "Name/%s.txt", id64);
		Handle NameHistory = OpenFile(g_sPlayerNameHistory, "a+");
		WriteFileLine(NameHistory, "[%s] %s", time, cvarValue);
		CloseHandle(NameHistory);
		
		SetClientInfo(client, "name", cvarValue);
		g_iSrnameTracker++;
		g_iResetToSteam[client]++;
		PrintToChatAll("[SM] %s has restored their Steam name: %s.", name, cvarValue);
		PrintToChat(client, "[SM] Your Steam name may take a few seconds to show.");
		LogMessage("%s [%s] restored their Steam name: %s.", name, id, cvarValue);
	}
	return;
} 