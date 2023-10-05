/** =============================================================================
 * Change Your Name - Functionality related to fetching players join name.
 * Fetch players name they had when they joined the server (!= Steam name).
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

public Action Command_Oname(int client, int args)
{
	if (!GetConVarBool(changename_enable_global))
	{
		ReplyToCommand(client, "[SM] This plugin is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!GetConVarBool(originalname_enable))
	{
		ReplyToCommand(client, "[SM] You cannot fetch join names (ability disabled by server).");
		return Plugin_Handled;
	}
	
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_oname <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH];
	GetCmdArgString(arg, sizeof(arg)); /*Allows for searching names with white spaces in case of multiple people with similar names*/
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1) /*Since we do not need players to use @all or similar, we are limiting it to one player at a time*/
	{
		return Plugin_Handled;
	}
	
	char targetname[MAX_TARGET_LENGTH], buffer[MAX_NAME_LENGTH], id[32];
	
	GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
	g_names.GetString(id, buffer, sizeof(buffer));
	
	if (StrEqual(buffer, ""))
	{
		ReplyToCommand(client, "[SM] Error: name not stored in memory.");
		LogMessage("%L could not fetch %s's join name. No stored name in memory.", client, targetname);
		return Plugin_Handled;
	}
	
	GetClientName(Target, targetname, sizeof(targetname));
	
	g_iOnameTracker++;
	g_iCheckedOname[client]++;
	g_iTargetWasOnameChecked[Target]++;
	
	if (strcmp(targetname, buffer)) /*We are now going to check whether the name == Original name upon connection*/
	{
		/*The name was changed, show the stored name*/
		ReplyToCommand(client, "[SM] %s joined the game with the name %s.", targetname, buffer);
		LogAction(client, Target, "%L checked %L's join name. Current name: %s. Join name: %s", client, Target, targetname, buffer);
		return Plugin_Handled;
	} 
	
	else 
	{
		/*Else, their name has not changed*/
		ReplyToCommand(client, "[SM] %s is the name they had when joining the server.", targetname);
		LogAction(client, Target, "%L checked %L's join name, which is their join name.", client, Target);
		return Plugin_Handled;
	}
}