/*
===========================================================================

  Copyright (c) 2026 LandSandBoat Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#pragma once

#include "common/macros.h"
#include "common/mmo.h"

#include <common/types/flag.h>
#include <common/types/maybe.h>
#include <algorithm>
#include <cmath>
#include <vector>

// isPartial marks a path that stopped short of `end` because the poly buffer ran out, so callers can chunk.
struct PathResult
{
    std::vector<pathpoint_t> points;
    bool                     isPartial{ false };
};

using AvoidLinks = xi::Flag<struct AvoidLinksTag>;

class NavMesh
{
public:
    NavMesh()          = default;
    virtual ~NavMesh() = default;

    DISALLOW_COPY_AND_MOVE(NavMesh);

    virtual auto findPath(const position_t& start, const position_t& end, float clearance, AvoidLinks avoidLinks) -> Maybe<PathResult> = 0;
    virtual auto findRandomPosition(const position_t& start, float maxRadius) const -> Maybe<position_t>                               = 0;
    virtual auto validPosition(const position_t& position) const -> bool                                                               = 0;
    virtual auto findClosestValidPoint(const position_t& position) const -> Maybe<position_t>                                          = 0;
    virtual auto findFurthestValidPoint(const position_t& startPosition, const position_t& endPosition) const -> Maybe<position_t>     = 0;
    virtual auto snapToValidPosition(position_t& position) const -> void                                                               = 0;
    virtual auto moveAlongSurface(const position_t& start, const position_t& end, position_t& result) const -> bool                    = 0;
};

// Walks the navmesh from `from` toward `to` and stops at the first wall. When a wall stopped it, the spot is pulled back
// `margin` yalms toward `from`, because the navmesh runs right up to the wall and a body standing on its very edge would
// be half inside it. Used for spawns and warps. nullopt when `from` is not on the mesh (a zone with no navmesh).
inline auto walkTowardsWithMargin(const NavMesh& navMesh, const position_t& from, const position_t& to, const float margin) -> Maybe<position_t>
{
    position_t slid{};
    if (!navMesh.moveAlongSurface(from, to, slid))
    {
        return std::nullopt;
    }

    const float shortX = to.x - slid.x;
    const float shortZ = to.z - slid.z;
    if (shortX * shortX + shortZ * shortZ > 0.04f) // stopped more than 0.2 yalm short: a wall is in the way
    {
        const float runX = slid.x - from.x;
        const float runZ = slid.z - from.z;
        const float run  = std::sqrt(runX * runX + runZ * runZ);
        if (run > 0.01f)
        {
            const float back = std::min(margin, run);
            position_t  pulled = slid;
            pulled.x           = slid.x - runX / run * back;
            pulled.z           = slid.z - runZ / run * back;

            position_t checked{};
            if (navMesh.moveAlongSurface(from, pulled, checked))
            {
                return checked;
            }
        }
    }

    return slid;
}
