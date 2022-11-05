# TF2 RegenThink Hook

The topic of hooking medics health regenration came up recently and I was kinda surprised nobody did a proper hook for this yet.
I think nosoop brought up RegenThink in relation to that on the SM Discord, so thank you nosoop.

As I didn't want this to be a "stupid" OnRegenThink hook, I dug into the decompile and reversed the function to give the most control possible.
Since this plugin superceds the original function, I'm currently not sure how well this works with other RegenThink hooks, if at all.

## Forward Summary

The forwards are documented in the include.

```c
Action TF2_OnRegenThinkPre(int client);
Action TF2_OnRegenThinkHealth(int client, float& regenHealthClass, float& regenHealthAttribs);
Action TF2_OnRegenThinkAmmo(int client, float& regenAmmoPercent, int& regenMetal);
void TF2_OnRegenThinkPost(int client, int regenHealth, float regenAmmo, int regenMetal);
```

## Dependencies

Requires [TF2 Attributes](https://github.com/FlaminSarge/tf2attributes)

## Module Plugins

* [TF2 ClassRegenConfig](ClassRegenConfig.md)   
  Configure health, ammo and metal regeneration for every player class using a config or third party plugins

## Credits

I want to thank nosoop for always having some insights or helpful reference code withing TF2 in their plugins.
Also thanks to who ever asked for this in the SM Discord, I actually needed this for a personal project, but was too lazy to properly do this until now.
Please open an issue if I forgot anyone :)
