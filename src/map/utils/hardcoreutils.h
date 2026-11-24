/*
===========================================================================

  XI: Forever Offline (2026-11-23): hardcore modes (Iron / Steel / Silver).

  A hardcore character carries the char var "[HC]Mode" (1 = Iron, 2 = Steel, 3 = Silver). Its rates come from the
  mode's profile, which modules/custom/late/hardcore.lua keeps in xi.hardcore.rates[mode]["map.EXP_RATE"] and so on.
  Any key the profile does not list (and every character without a mode) uses the world's own setting, so this
  header changes nothing at all until hardcore.lua is loaded and a character has a mode.

  Header only on purpose: the core does not depend on the hardcore module being in modules/init.txt.

===========================================================================
*/

#pragma once

#include "common/lua.h"
#include "common/settings.h"
#include "entities/char_entity.h"
#include "utils/charutils.h"

#include <string>

namespace hardcoreutils
{
    inline const std::string ModeVar = "[HC]Mode";

    inline auto cleanMode(int32 value) -> int32
    {
        return (value >= 1 && value <= 3) ? value : 0;
    }

    // 0 = a normal character, 1 = Iron, 2 = Steel, 3 = Silver
    inline auto mode(const CCharEntity* PChar) -> int32
    {
        if (PChar == nullptr)
        {
            return 0;
        }

        return cleanMode(PChar->getCharVar(ModeVar));
    }

    // the same for a character that may not be loaded in this zone (reads the database)
    inline auto modeOf(uint32 charId) -> int32
    {
        if (charId == 0)
        {
            return 0;
        }

        return cleanMode(charutils::FetchCharVar(charId, ModeVar).first);
    }

    // Iron parties with anyone; Steel and Silver only with other hardcore characters (Iron, Steel, Silver).
    // Bot players have no mode, so they never join a Steel or Silver party.
    inline auto canGroup(int32 a, int32 b) -> bool
    {
        if (a >= 2 || b >= 2)
        {
            return a > 0 && b > 0;
        }

        return true;
    }

    // The rate for this character: its mode's value for the key when the profile has one, else the world's setting.
    inline auto rate(const CCharEntity* PChar, const std::string& key) -> double
    {
        const double base = settings::get<double>(key);
        const int32  m    = mode(PChar);
        if (m == 0)
        {
            return base;
        }

        const sol::optional<sol::table> xiTable = ::lua["xi"].get<sol::optional<sol::table>>();
        if (!xiTable)
        {
            return base;
        }

        const sol::optional<sol::table> hcTable = (*xiTable)["hardcore"].get<sol::optional<sol::table>>();
        if (!hcTable)
        {
            return base;
        }

        const sol::optional<sol::table> rates = (*hcTable)["rates"].get<sol::optional<sol::table>>();
        if (!rates)
        {
            return base;
        }

        const sol::optional<sol::table> row = (*rates)[m].get<sol::optional<sol::table>>();
        if (!row)
        {
            return base;
        }

        const sol::optional<double> value = (*row)[key].get<sol::optional<double>>();
        return value ? *value : base;
    }
} // namespace hardcoreutils
