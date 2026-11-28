/************************************************************************
 * Hardcore cosmetic wardrobe (XI: Forever Offline, 2026-11-27, the user: "hardcore players have an unlocked mog
 * wardrobe ... only for cosmetic armor ... use one that isn't unlocked in any of the quests")
 *
 * With classic bags a hardcore character (Iron, Steel, Silver, Randomized) gets Mog Wardrobe 8 open at 80 slots
 * from the start (custom/late/hardcore_wardrobe.lua). No mission or quest opens Wardrobe 8 (Phoenix's unlocks open
 * 1-4), so it costs nothing that the game would hand out anyway. It only takes costumes and event gear: the list
 * is xi.hardcore.cosmeticWardrobe, published by the Lua half. No list (full bags, or the Lua half is not loaded)
 * means this does nothing. Items already inside stay; taking items out is never restricted.
 *
 * Same approach as Phoenix's cosmetic_wardrobe.cpp: the client has drawn the move already, so a refused move
 * resends the source slot and the item snaps back.
 ************************************************************************/
#include "common/logging.h"
#include "map/entities/char_entity.h"
#include "map/enums/chat_message_type.h"
#include "map/item_container.h"
#include "map/items/item.h"
#include "map/packets/basic.h"
#include "map/packets/c2s/0x029_item_move.h"
#include "map/packets/s2c/0x017_chat_std.h"
#include "map/packets/s2c/0x01d_item_same.h"
#include "map/packets/s2c/0x020_item_attr.h"
#include "map/utils/hardcoreutils.h"
#include "map/utils/moduleutils.h"

namespace
{

class HardcoreWardrobe : public CPPModule
{
    void OnInit() override
    {
    }

    auto OnIncomingPacket(MapSession* PSession, CCharEntity* PChar, CBasicPacket& data) -> bool override
    {
        if (data.getType() != static_cast<uint16>(GP_CLI_COMMAND_ITEM_MOVE::packetId))
        {
            return false;
        }

        const auto* packet = data.as<GP_CLI_COMMAND_ITEM_MOVE>();
        if (static_cast<CONTAINER_ID>(packet->Category2) != LOC_WARDROBE8 || packet->Category1 == packet->Category2 ||
            packet->Category1 >= MAX_CONTAINER_ID)
        {
            return false;
        }

        if (hardcoreutils::mode(PChar) == 0)
        {
            return false;
        }

        const auto maybeList = ::lua["xi"]["hardcore"]["cosmeticWardrobe"].get<sol::optional<sol::table>>();
        if (!maybeList)
        {
            return false; // full bags: Wardrobe 8 is an ordinary wardrobe
        }

        CItem* PItem = PChar->getStorage(packet->Category1)->GetItem(packet->ItemIndex1);
        if (!PItem || maybeList->get_or(PItem->getID(), false))
        {
            return false;
        }

        PChar->pushPacket<GP_SERV_COMMAND_ITEM_ATTR>(PItem, static_cast<CONTAINER_ID>(packet->Category1), packet->ItemIndex1);
        PChar->pushPacket<GP_SERV_COMMAND_ITEM_SAME>(PChar);
        PChar->pushPacket<GP_SERV_COMMAND_CHAT_STD>(PChar, MESSAGE_SYSTEM_3,
                                                    "Mog Wardrobe 8 is your cosmetic wardrobe: only costumes and event gear can be stored in it.");
        return true;
    }
};

} // namespace

REGISTER_CPP_MODULE(HardcoreWardrobe);
