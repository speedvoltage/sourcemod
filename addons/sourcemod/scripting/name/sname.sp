/** =============================================================================
 * Change Your Name - Functionality related to fetching players Steam name.
 * Prints players Steam name.
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

public Action Command_Sname(int client, int args)
{
	if (!GetConVarBool(changename_enable_global))
	{
		ReplyToCommand(client, "[SM] This plugin is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!GetConVarBool(steamname_enable))
	{
		ReplyToCommand(client, "[SM] You cannot fetch Steam names (ability disabled by server).");
		return Plugin_Handled;
	}
	
	if (!client)
	{
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}
	
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_sname <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH];
	GetCmdArgString(arg, sizeof(arg)); /*Allows for searching names with white spaces in case of multiple people with similar names*/
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1) /*Since we do not need players to use @all or similar, we are limiting it to one player at a time*/
	{
		return Plugin_Handled;
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
		PrintToChat(client, "[SM] Error: Couldn't retrieve %N's Steam name.", targetclient);
		LogAction(client, targetclient, "%L attempted to fetch %L's Steam name, but the query failed.", client, targetclient);
		g_iSteamQueryFail++;
		g_iCouldNotQuery[targetclient]++;
		
		return;
	}
	
	if (client <= 0 || client > MaxClients)
		return;
	
	else if (!IsClientInGame(client))
		return;
	
	char steamname[MAX_NAME_LENGTH];
	GetClientName(targetclient, steamname, sizeof(steamname));
	
	/*Now properly says if current name == Steam name already. Much prettier now.*/
	
	if (strcmp(steamname, cvarValue) == 0)
	{
		PrintToChat(client, "[SM] %N is their Steam name.", targetclient);
		LogAction(client, targetclient, "%L checked %L's Steam name. Their in-game name is their Steam name.", client, targetclient);
	}
	else
	{
		PrintToChat(client, "[SM] %N's Steam name is %s.", targetclient, cvarValue);
		LogAction(client, targetclient, "%L checked %L's Steam name. Their Steam name is %s.", client, targetclient, cvarValue);
	}
	
	return;
}