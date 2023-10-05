/** =============================================================================
 * Change Your Name - Functionality related to listing public name commands
 * Prints available public commands related to using change your name plugin.
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

public Action Command_Hname(int client, int args)
{
	if (!GetConVarBool(changename_enable_global))
	{
		ReplyToCommand(client, "[SM] This plugin is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!GetConVarBool(changename_help))
	{
		ReplyToCommand(client, "[SM] You cannot view public commands (ability disabled by server).");
		return Plugin_Handled;
	}
	
	if (!args) if (GetCmdReplySource() == SM_REPLY_TO_CHAT) ReplyToCommand(client, "[SM] See console for details.");
	
	PrintToConsole(client, "[SM] Available commands are:\n \
	sm_name <new name> || \
	Leave blank - Change your name or if no name is specified, it will revert to the name you had when joining\n \
	sm_oname <#userid|name> - Shows the join name of a user\n \
	sm_sname <#userid|name> - Shows the Steam name of a user\n \
	sm_srname - Reset your name to your Steam name\n \
	NOTE: Not all commands may be available. It is up to the server operator to decide what you have access to.");
	
	return Plugin_Handled;
} 