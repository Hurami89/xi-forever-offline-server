//
// XI: Forever Offline (2026-11-23): hardcore modes, the packet side.
//
//   A hardcore character carries the char var "[HC]Mode": 1 = Iron, 2 = Steel, 3 = Silver
//   (src/map/utils/hardcoreutils.h; the rules and the rates are in modules/custom/late/hardcore.lua).
//
//   Here, for every mode:
//     * no auction house (packet 0x04E), no buying from bazaars (0x106)
//     * no trades with other characters (0x032 request, 0x033 accepting), either way round
//     * no delivery box sending (0x04D), neither from a hardcore character nor to one. Items the server sends (the
//       milestone rewards) still arrive: they do not come through this packet.
//   And the party rule, with a message: Iron parties with anyone; Steel and Silver only with hardcore characters
//   (0x06E invite, 0x074 accepting). The core refuses any other way in (party.cpp AddMember).
//
//   Lua:
//     HardcoreResetJob(charId) -> bool   Steel: the main job back to level 1 with 0 exp (an online character)
//
//   GMs are held to the same rules (step the character down to test without them).
//

#include "map/utils/moduleutils.h"

#include "common/database.h"
#include "common/lua.h"

#include "map/enums/chat_message_type.h"
#include "map/entities/char_entity.h"
#include "map/lua/lua_base_entity.h"
#include "map/map_session.h"
#include "map/packets/basic.h"
#include "map/packets/c2s/0x032_trade_req.h"
#include "map/packets/c2s/0x033_trade_res.h"
#include "map/packets/c2s/0x04d_pbx.h"
#include "map/packets/c2s/0x04e_auc.h"
#include "map/packets/c2s/0x06e_group_solicit_req.h"
#include "map/packets/c2s/0x074_group_solicit_res.h"
#include "map/packets/s2c/0x017_chat_std.h"
#include "map/packets/s2c/0x061_clistatus.h"
#include "map/party.h"
#include "map/utils/charutils.h"
#include "map/utils/hardcoreutils.h"
#include "map/utils/zoneutils.h"

#include <cstring>
#include <string>

namespace
{
    const char* modeName(int32 mode)
    {
        switch (mode)
        {
            case 1:
                return "Iron";
            case 2:
                return "Steel";
            case 3:
                return "Silver";
            default:
                return "normal";
        }
    }

    void tell(CCharEntity* PChar, const std::string& text)
    {
        if (PChar != nullptr)
        {
            PChar->pushPacket<GP_SERV_COMMAND_CHAT_STD>(PChar, MESSAGE_SYSTEM_3, text);
        }
    }

    // a character's mode by name (for the delivery box: the recipient is usually not online)
    auto modeByName(const std::string& name) -> int32
    {
        if (name.empty())
        {
            return 0;
        }

        if (auto rset = db::preparedStmt("SELECT charid FROM chars WHERE charname = ? LIMIT 1", name); rset && rset->next())
        {
            return hardcoreutils::modeOf(rset->get<uint32>("charid"));
        }

        return 0;
    }

    auto modeById(uint32 charId) -> int32
    {
        if (CCharEntity* PChar = zoneutils::GetChar(charId))
        {
            return hardcoreutils::mode(PChar);
        }

        return hardcoreutils::modeOf(charId);
    }

    auto exempt(const CCharEntity* PChar) -> bool
    {
        return PChar == nullptr;
    }

    // true when PChar may join the party PLeader is in (or start one with PLeader); else names who is in the way
    auto partyAllows(const CCharEntity* PChar, CCharEntity* PLeader, std::string& blocker) -> bool
    {
        const int32 mine = hardcoreutils::mode(PChar);
        if (PLeader == nullptr)
        {
            return true;
        }

        if (PLeader->PParty == nullptr)
        {
            if (!hardcoreutils::canGroup(mine, hardcoreutils::mode(PLeader)))
            {
                blocker = PLeader->getName();
                return false;
            }

            return true;
        }

        for (const auto* PMember : PLeader->PParty->members)
        {
            if (const auto* POther = dynamic_cast<const CCharEntity*>(PMember); POther != nullptr && POther != PChar &&
                                                                               !hardcoreutils::canGroup(mine, hardcoreutils::mode(POther)))
            {
                blocker = POther->getName();
                return false;
            }
        }

        return true;
    }
} // namespace

class HardcoreModule : public CPPModule
{
    void OnInit() override
    {
        TracyZoneScoped;

        ::lua.set_function("HardcoreResetJob", [](uint32 charId) -> bool
                           {
                               CCharEntity* PChar = zoneutils::GetChar(charId);
                               if (PChar == nullptr || PChar->isDead())
                               {
                                   return false;
                               }

                               const auto job = PChar->GetMJob();
                               CLuaBaseEntity(PChar).setLevel(1); // stats, skills, abilities, traits, gear check, packets
                               PChar->jobs.exp[static_cast<uint8>(job)] = 0;
                               charutils::SaveCharExp(PChar, job);
                               PChar->pushPacket<GP_SERV_COMMAND_CLISTATUS>(PChar);
                               ShowInfoFmt("[hardcore] {}: {} is back to level 1 (Steel)", PChar->getName(), static_cast<int>(job));
                               return true;
                           });

        ShowInfo("[hardcore] hardcore modes loaded (Iron / Steel / Silver)");
    }

    auto OnIncomingPacket(MapSession* session, CCharEntity* PChar, CBasicPacket& packet) -> bool override
    {
        if (exempt(PChar))
        {
            return false;
        }

        const uint16 type = packet.getType();
        const int32  mine = hardcoreutils::mode(PChar);

        // auction house
        if (type == 0x04E && mine > 0)
        {
            const auto* auc = packet.as<GP_CLI_COMMAND_AUC>();
            if (auc->Command == GP_CLI_COMMAND_AUC_COMMAND::AskCommit || auc->Command == GP_CLI_COMMAND_AUC_COMMAND::LotIn ||
                auc->Command == GP_CLI_COMMAND_AUC_COMMAND::Bid || auc->Command == GP_CLI_COMMAND_AUC_COMMAND::WorkCheck)
            {
                tell(PChar, fmt::format("{} characters can't use the auction house. Everything you have, you found yourself.", modeName(mine)));
                return true;
            }

            return false;
        }

        // buying from a bazaar
        if (type == 0x106 && mine > 0)
        {
            tell(PChar, fmt::format("{} characters can't buy from bazaars.", modeName(mine)));
            return true;
        }

        // trading with another character
        if (type == 0x032)
        {
            const auto* req     = packet.as<GP_CLI_COMMAND_TRADE_REQ>();
            const int32 theirs  = modeById(req->UniqueNo);
            if (mine > 0 || theirs > 0)
            {
                tell(PChar, mine > 0 ? fmt::format("{} characters can't trade with other characters.", modeName(mine))
                                     : fmt::format("That character is {} hardcore and can't trade with anyone.", modeName(theirs)));
                return true;
            }

            return false;
        }

        if (type == 0x033 && mine > 0)
        {
            const auto* res  = packet.as<GP_CLI_COMMAND_TRADE_RES>();
            const auto  kind = static_cast<GP_CLI_COMMAND_TRADE_RES_KIND>(res->Kind);
            if (kind == GP_CLI_COMMAND_TRADE_RES_KIND::Start || kind == GP_CLI_COMMAND_TRADE_RES_KIND::Make)
            {
                tell(PChar, fmt::format("{} characters can't trade with other characters. Cancel the trade.", modeName(mine)));
                return true;
            }

            return false;
        }

        // delivery box: sending
        if (type == 0x04D)
        {
            const auto* pbx = packet.as<GP_CLI_COMMAND_PBX>();
            const auto  cmd = static_cast<GP_CLI_COMMAND_PBX_COMMAND>(pbx->Command);
            if (cmd != GP_CLI_COMMAND_PBX_COMMAND::Set && cmd != GP_CLI_COMMAND_PBX_COMMAND::Send)
            {
                return false;
            }

            if (mine > 0)
            {
                tell(PChar, fmt::format("{} characters can't send items through the delivery box.", modeName(mine)));
                return true;
            }

            std::string target(reinterpret_cast<const char*>(pbx->TargetName), strnlen(reinterpret_cast<const char*>(pbx->TargetName), sizeof(pbx->TargetName)));
            if (const int32 theirs = modeByName(target); theirs > 0)
            {
                tell(PChar, fmt::format("{} is a {} hardcore character and can't receive items from other characters.", target, modeName(theirs)));
                return true;
            }

            return false;
        }

        // party invite: the inviter's party (or the inviter) and the one invited
        if (type == 0x06E)
        {
            const auto* inv    = packet.as<GP_CLI_COMMAND_GROUP_SOLICIT_REQ>();
            const int32 theirs = modeById(inv->UniqueNo);
            if (!hardcoreutils::canGroup(mine, theirs))
            {
                tell(PChar, theirs >= 2 ? fmt::format("That character is {} hardcore: they only party with Iron, Steel and Silver characters.", modeName(theirs))
                                        : fmt::format("{} characters only party with Iron, Steel and Silver characters.", modeName(mine)));
                return true;
            }

            if (PChar->PParty != nullptr && theirs > 0)
            {
                for (const auto* PMember : PChar->PParty->members)
                {
                    if (const auto* POther = dynamic_cast<const CCharEntity*>(PMember); POther != nullptr && POther != PChar &&
                                                                                       !hardcoreutils::canGroup(theirs, hardcoreutils::mode(POther)))
                    {
                        tell(PChar, fmt::format("That character is {} hardcore and can't share a party with {}.", modeName(theirs), POther->getName()));
                        return true;
                    }
                }
            }

            return false;
        }

        // accepting an invite
        if (type == 0x074)
        {
            const auto* res = packet.as<GP_CLI_COMMAND_GROUP_SOLICIT_RES>();
            if (static_cast<GP_CLI_COMMAND_GROUP_SOLICIT_RES_RES>(res->Res) != GP_CLI_COMMAND_GROUP_SOLICIT_RES_RES::Accept)
            {
                return false;
            }

            CCharEntity* PInviter = zoneutils::GetCharFromWorld(PChar->InvitePending.entity.UniqueNo, PChar->InvitePending.entity.ActIndex);
            std::string  blocker;
            if (PInviter != nullptr && !partyAllows(PChar, PInviter, blocker))
            {
                tell(PChar, mine >= 2 ? fmt::format("{} characters only party with Iron, Steel and Silver characters ({} is not one).", modeName(mine), blocker)
                                      : fmt::format("{} is a Steel or Silver hardcore character: they only party with hardcore characters.", blocker));
                tell(PInviter, fmt::format("{} could not join: Steel and Silver characters only party with hardcore characters.", PChar->getName()));
                PChar->InvitePending.clean();
                return true;
            }

            return false;
        }

        return false;
    }
};

REGISTER_CPP_MODULE(HardcoreModule);
