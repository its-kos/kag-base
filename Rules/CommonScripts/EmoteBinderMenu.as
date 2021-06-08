//TODO: display emote names when hovered (would require a complete list which EmoteEntries.cfg is not)
//		update emotes instantly

#include "EmotesCommon.as";

const u8 MENU_WIDTH = 9;
const string SELECTED_PROP = "selected emote: ";

const string EMOTE_CMD = "emote command";
enum EMOTE_SUBCMD {
	BIND_EMOTE,
	SELECT_KEYBIND,
	CLOSE_MENU,
	EMOTE_SUBCMD_COUNT
};

void onInit(CRules@ this)
{
	this.addCommandID(EMOTE_CMD);
	this.addCommandID("display taunt");
}

void NewEmotesMenu()
{
	CRules@ rules = getRules();
	CPlayer@ player = getLocalPlayer();
	if (player !is null && player.isMyPlayer())
	{
		//select first keybind to begin with
		string propname = SELECTED_PROP + player.getUsername();
		rules.set_u8(propname, 0);

		LoadIcons(player);
		ShowEmotesMenu(player);
	}
}

void LoadIcons(CPlayer@ player)
{
	dictionary emotes;
	getRules().get("emotes", emotes);
	string[] tokens = emotes.getKeys();

	for (u16 i = 0; i < tokens.size(); i++)
	{
		Emote@ emote;
		emotes.get(tokens[i], @emote);

		AddIconToken(getIconName(emote.token), emote.pack.filePath, Vec2f(32, 32), emote.index, player.getTeamNum());
	}
}

void ShowEmotesMenu(CPlayer@ player)
{
	//hide main menu and other gui
	Menu::CloseAllMenus();
	getHUD().ClearMenus(true);

	CRules@ rules = getRules();
	Vec2f center = getDriver().getScreenCenterPos();
	string description = getTranslatedString("Emote Hotkey Binder");

	string[] emoteBinds = readEmoteBindings(player);

	uint emotesHeight = Maths::Ceil(getUsableEmotes(player).size() / float(MENU_WIDTH));
	uint bindsHeight = Maths::Ceil(emoteBinds.size() / float(MENU_WIDTH));
	uint menuHeight = emotesHeight + bindsHeight + 1;

	//display main grid menu
	CGridMenu@ menu = CreateGridMenu(center, null, Vec2f(MENU_WIDTH, menuHeight), description);
	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		//press escape to close
		CBitStream params;

		params.write_u8(CLOSE_MENU);
		params.write_string(player.getUsername());

		menu.AddKeyCommand(KEY_ESCAPE, rules.getCommandID(EMOTE_CMD), params);
		menu.SetDefaultCommand(rules.getCommandID(EMOTE_CMD), params);

		dictionary packs;
		rules.get("emote packs", packs);
		string[] tokens = packs.getKeys();

		//display emote grid
		for (int i = 0; i < tokens.size(); i++)
		{
			EmotePack@ pack;
			packs.get(tokens[i], @pack);

			for (int j = 0; j < pack.emotes.size(); j++)
			{
				Emote@ emote = pack.emotes[j];

				if (!canUseEmote(player, emote))
				{
					continue;
				}

				CBitStream params;
				params.write_u8(BIND_EMOTE);
				params.write_string(player.getUsername());
				params.write_string(emote.token);
				CGridButton@ button = menu.AddButton(getIconName(emote.token), getTranslatedString(emote.name), rules.getCommandID(EMOTE_CMD), Vec2f(1, 1), params);
			}
		}

		//fill in extra slots in emote grid
		if (menu.getButtonsCount() % MENU_WIDTH != 0)
		{
			menu.FillUpRow();
		}

		//separator with info
		CGridButton@ separator = menu.AddTextButton(getTranslatedString("Select a keybind below, then select the emote you want"), Vec2f(MENU_WIDTH, 1));
		separator.SetEnabled(false);

		string propname = SELECTED_PROP + player.getUsername();
		u8 selected = rules.get_u8(propname);

		//display row of current emote keybinds
		for (int i = 0; i < emoteBinds.size(); i++)
		{
			string text = i < 9 ? "Select key {KEY_NUM}" : "Select numpad key {KEY_NUM}";
			u8 keyNum = (i < 9 ? i : i - 9) + 1;

			CBitStream params;
			params.write_u8(SELECT_KEYBIND);
			params.write_string(player.getUsername());
			params.write_u8(i);
			CGridButton@ button = menu.AddButton(getIconName(emoteBinds[i]), getTranslatedString(text).replace("{KEY_NUM}", keyNum + ""), rules.getCommandID(EMOTE_CMD), Vec2f(1, 1), params);
			button.selectOneOnClick = true;
			// button.hoverText = "     Key " + (i + 1) + "\n";

			//reselect keybind if one was selected before
			if (selected == i)
			{
				button.SetSelected(1);
			}
		}
	}
}

void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
	if(cmd == this.getCommandID(EMOTE_CMD))
	{
		string name;
		u8 subcmd;

		if(!params.saferead_u8(subcmd)) return;
		if(!params.saferead_string(name)) return;

		CPlayer@ caller = getPlayerByUsername(name);

		//check validity so far
		if (caller is null || !caller.isMyPlayer() || subcmd >= EMOTE_SUBCMD_COUNT)
		{
			return;
		}

		if (subcmd == BIND_EMOTE)
		{
			string propname = SELECTED_PROP + caller.getUsername();
			u8 selected = this.get_u8(propname);

			//must select keybind first
			if (selected == -1)
			{
				return;
			}

			string token;
			if(!params.saferead_string(token)) return;

			string key = "emote_" + (selected + 1);

			//get emote bindings cfg file
			ConfigFile@ cfg = openEmoteBindingsConfig();

			//bind emote
			cfg.add_string(key, token);
			cfg.saveFile("EmoteBindings.cfg");

			//update keybinds in menu
			ShowEmotesMenu(caller);
		}
		else if (subcmd == SELECT_KEYBIND)
		{
			u8 emote;
			if(!params.saferead_u8(emote)) return;

			string propname = SELECTED_PROP + caller.getUsername();
			this.set_u8(propname, emote);
		}
		else if (subcmd == CLOSE_MENU)
		{
			getHUD().ClearMenus(true);
		}

		//trigger a reload of the blob's emote bindings either way
		CBlob@ cblob = caller.getBlob();
		if (cblob !is null)
		{
			cblob.Tag("reload emotes");
		}
	}
	
}

string getIconName(string token)
{
	return "$EMOTE" + token + "$";
}
